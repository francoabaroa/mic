defmodule Mic.Chat.TextExtractorV2 do
  require Logger

  def extract_text_from_document(file_path, original_file_name) do
    with {:ok, binary} <- File.read(file_path),
         {:ok, file_id} <- upload_file(binary, original_file_name),
         # TODO: create one assistant per user (to avoid leaking), same for vector stores,
         # TODO: eventually save the users asssitants so we dont have to re-create them elsewhere (for longer context, etc)
         # TODO: what is the policy on max number of created assistants? do they charge for assistants active?
         # TODO: if there is some sort of error, the file and assistant and thread will stay on openai. need a daily cron job that removes these
         {:ok, assistant_response} =
           HTTPoison.post(
             "https://api.openai.com/v1/assistants",
             Jason.encode!(%{
               "name" => "TextExtractorAndAnalyzer",
               "description" => "Extracts text from files like pdf, doc/x, etc.",
               "instructions" =>
                 "You are a helpful assistant who extracts the full text from documents or files provided to you and returns it to the user. Extract the full text from the attached file. Only reply with the full text of the file and nothing else.",
               "model" => Application.get_env(:mic, :model) || "gpt-4o",
               "tools" => [%{"type" => "code_interpreter"}],
               "tool_resources" => %{
                 "code_interpreter" => %{
                   "file_ids" => [file_id]
                 }
               }
             }),
             [
               {"Authorization", "Bearer #{System.get_env("OPENAI_API_KEY")}"},
               {"Content-Type", "application/json"},
               {"OpenAI-Beta", "assistants=v2"}
             ]
           ),
         assistant_id <- Jason.decode!(assistant_response.body)["id"],
         {:ok, thread} <-
           ExOpenAI.Threads.create_thread(
             messages: [
               %{
                 role: "user",
                 content:
                   "Extract the full text from the attached file. Only reply with the full text of the file and nothing else.",
                 attachments: [
                   %{
                     file_id: file_id,
                     tools: [%{type: "code_interpreter"}]
                   }
                 ]
               }
             ]
           ),
         thread_id <- thread.id,
         {:ok, run} <-
           ExOpenAI.Threads.create_run(thread_id, assistant_id,
             instructions:
               "Extract the full text from file ID: #{file_id}. Only reply with the full text of the file and nothing else."
           ),
         run_id <- run.id,
         extracted_text <-
           wait_for_run_completion(
             thread_id,
             run_id,
             assistant_id,
             file_id
           ) do
      extracted_text
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp retrieve_file(file_id) do
    ExOpenAI.Files.retrieve_file(file_id)
  end

  defp upload_file(binary, original_file_name) do
    ExOpenAI.Files.create_file(
      {original_file_name, binary},
      "assistants"
    )
    |> case do
      {:ok, %{id: file_id}} ->
        case retrieve_file(file_id) do
          {:ok, file} ->
            Logger.info("File retrieved successfully: #{inspect(file)}")
            {:ok, file.id}

          {:error, reason} ->
            Logger.error("Error retrieving file from OpenAI: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Error uploading file to OpenAI: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_extracted_text(thread_id, _run_id) do
    Logger.info("Thread ID: #{thread_id}")

    ExOpenAI.Threads.list_messages(thread_id)
    |> case do
      {:ok, %{data: messages}} ->
        Logger.info("Messages: #{inspect(messages)}")

        case Enum.find(messages, fn message -> message.role == "assistant" end) do
          nil ->
            {:error, "No message with role 'assistant' found"}

          assistant_message ->
            extracted_text =
              assistant_message
              |> Map.get(:content)
              |> List.first()
              |> Map.get(:text)
              |> Map.get(:value)

            {:ok, extracted_text}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp wait_for_run_completion(
         thread_id,
         run_id,
         max_retries \\ 5,
         retry_delay \\ 3000,
         attempt \\ 0,
         assistant_id,
         file_id
       ) do
    Logger.info("Waiting for run completion: #{run_id}")

    case ExOpenAI.Threads.get_run(thread_id, run_id) do
      {:ok, %ExOpenAI.Components.RunObject{status: "completed"} = run} ->
        Logger.info("Run status complete: #{run.status}")

        case get_extracted_text(thread_id, run_id) do
          {:ok, extracted_text} ->
            try do
              case Mic.Jobs.DeleteDocumentMetadataJob.new(%{
                     "assistant_id" => assistant_id,
                     "file_id" => file_id,
                     "thread_id" => thread_id
                   })
                   |> Oban.insert() do
                {:ok, _job} ->
                  {:ok, extracted_text}
              end
            rescue
              exception ->
                Logger.error(
                  "Exception occurred while enqueuing DeleteDocumentMetadataJob: #{inspect(exception)}"
                )

                {:error, exception}
            end
        end

      {:ok, %ExOpenAI.Components.RunObject{status: status}}
      when status in ["in_progress", "queued"] ->
        if attempt < max_retries do
          Logger.info("Run status: #{status}. Attempt #{attempt + 1} of #{max_retries}")
          # Wait for an incrementally longer duration before checking the status again
          sleep_time = round(:math.pow(2, attempt)) * retry_delay
          Process.sleep(sleep_time)

          wait_for_run_completion(
            thread_id,
            run_id,
            max_retries,
            retry_delay,
            attempt + 1,
            assistant_id,
            file_id
          )
        else
          {:error, "Run did not complete in a reasonable amount of time"}
        end

      {:ok, %ExOpenAI.Components.RunObject{status: status}} ->
        Logger.error("Run ended with non-completion status: #{status}")
        {:error, "Run ended with non-completion status: #{status}"}

      {:error, reason} ->
        if attempt < max_retries do
          Logger.error("Failed to retrieve run status: #{inspect(reason)}. Retrying...")
          sleep_time = round(:math.pow(2, attempt)) * retry_delay
          Process.sleep(sleep_time)

          wait_for_run_completion(
            thread_id,
            run_id,
            max_retries,
            retry_delay,
            attempt + 1,
            assistant_id,
            file_id
          )
        else
          {:error, reason}
        end
    end
  end
end
