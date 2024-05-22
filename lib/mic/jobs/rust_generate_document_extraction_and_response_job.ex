defmodule Mic.Jobs.RustGenerateDocumentExtractionAndResponseJob do
  require Logger
  alias MicWeb.WhatsAppController

  use Oban.Worker, queue: :default, max_attempts: 1

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "file_path" => file_path,
          "original_file_name" => original_file_name,
          "from_number" => from_number
        }
      }) do
    extension = Path.extname(original_file_name)

    text =
      case extension do
        ".pdf" -> Mic.Chat.DocumentParser.parse_pdf(file_path)
        ".txt" -> Mic.Chat.DocumentParser.parse_txt(file_path)
        _ -> {:error, "Unsupported file format"}
      end

    case text do
      {:ok, extracted_text} ->
        # TODO: delete file from openai after extracting text
        Logger.info("Extracted text: #{inspect(extracted_text)}")

        case generate_response_and_send_message(extracted_text, from_number, file_path) do
          :ok ->
            # TODO: fix this
            remove_file(file_path)
            :ok

          {:error, reason} ->
            remove_file(file_path)
            Logger.error("Error in generate_response_and_send_message: #{inspect(reason)}")

            send_message(
              from_number,
              "Sorry, an error occurred while processing your document."
            )

            {:error, reason}
        end

      {:error, reason} ->
        remove_file(file_path)
        Logger.error("Error in extract_text_from_document: #{inspect(reason)}")

        send_message(
          from_number,
          "Sorry, an error occurred while processing your document."
        )

        {:error, reason}
    end
  end

  defp generate_response_and_send_message(text, from_number, file_path) do
    case WhatsAppController.generate_openai_response(text) do
      {:ok, response} ->
        Logger.info("OpenAI response: #{response}")
        remove_file(file_path)
        send_message(response, from_number)

      {:error, reason} ->
        remove_file(file_path)
        Logger.error("Error in generate_openai_response: #{inspect(reason)}")
    end
  end

  defp send_message(response, from_number) do
    # Assuming `conn` and `from_number` are available in the context
    WhatsAppController.send_message(from_number, response)
  end

  defp remove_file(file_path) do
    case File.rm(file_path) do
      :ok -> Logger.info("File removed successfully: #{file_path}")
      {:error, reason} -> Logger.error("Failed to remove file: #{inspect(reason)}")
    end
  end
end
