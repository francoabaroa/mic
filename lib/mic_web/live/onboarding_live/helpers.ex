defmodule MicWeb.OnboardingLive.Helpers do
  require Logger

  def start_openai_process do
    {:ok, pid} = Mic.Chat.OpenAI.start_link(%{})
    pid
  end

  def handle_progress(:file, entry, socket, consume_uploaded_entries_fn) do
    if entry.done? do
      {uploaded_files, client_names} =
        consume_uploaded_entries_fn.(socket, :file, fn %{path: path},
                                                       %{
                                                         client_name: client_name
                                                       } ->
          extension = Path.extname(client_name)

          text =
            case extension do
              ".docx" -> Mic.Chat.DocumentParser.parse_docx(path)
              ".pdf" -> Mic.Chat.DocumentParser.parse_pdf(path)
              ".txt" -> Mic.Chat.DocumentParser.parse_txt(path)
              _ -> {:error, "Unsupported file format"}
            end

          case text do
            {:ok, content} ->
              File.rm!(path)
              {:ok, {content, client_name}}

            {:error, reason} ->
              File.rm!(path)
              Logger.error("Error extracting text: #{inspect(reason)}")
              {:postpone, reason}
          end
        end)
        |> Enum.unzip()

      document_extracted_text = Enum.join(uploaded_files, "")

      if String.length(document_extracted_text) >= 1 and !socket.assigns.disabled do
        # Assuming only one file is uploaded at a time, so we take the first client_name
        client_name = List.first(client_names)
        send(self(), {:msg_submit, document_extracted_text, true, client_name})

        {:ok, %{uploaded_files: socket.assigns.uploaded_files ++ uploaded_files}}
      else
        {:ok, %{uploaded_files: socket.assigns.uploaded_files ++ uploaded_files}}
      end
    else
      {:ok, %{}}
    end
  end

  def initiate_voice_transcription do
    {:ok, %{event: "start_recording", params: %{record: true}}}
  end

  def stop_voice_transcription do
    {:ok, %{event: "stop_recording", params: %{record: true}}}
  end

  def handle_transcribed_chat_message(audio_data_base64) do
    {:ok, audio_data_binary} = Base.decode64(audio_data_base64)

    case Mic.Chat.OpenAI.transcribe_voice(audio_data_binary) do
      {:ok, text} ->
        if String.length(text) >= 1 do
          Process.send(self(), {:msg_submit, text, false, nil}, [])
        end

        {:ok, %{}}

      {:error, reason} ->
        Logger.error("Transcription Error: #{inspect(reason)}")
        {:error, %{event: "transcription_error", params: %{error: "Voice transcription failed"}}}
    end
  end

  def set_prefers_voice_chat(socket, prefers_voice_chat) do
    Mic.Chat.OpenAI.set_prefers_voice_chat(socket.assigns.openai_pid, prefers_voice_chat)
    {:ok, %{}}
  end

  def set_language_preference(socket, language_preference) do
    Mic.Chat.OpenAI.set_language_preference(socket.assigns.openai_pid, language_preference)
    {:ok, %{language_preference: language_preference}}
  end

  def generate_profile(socket) do
    Mic.Jobs.GenerateArtistProfileJob.new(%{
      "current_user" => socket.assigns.current_user,
      "profile_data" => socket.assigns.profile_data,
      "language_preference" => socket.assigns.language_preference
    })
    |> Oban.insert()

    settings_attrs = %{
      response_language: socket.assigns.language_preference,
      response_answer_detail: :brief,
      response_answer_style: :normal,
      response_medium:
        if(Mic.Chat.OpenAI.get_prefers_voice_chat(socket.assigns.openai_pid),
          do: :voice,
          else: :text
        )
    }

    case Mic.Accounts.update_settings(socket.assigns.current_user, settings_attrs) do
      {:ok, _settings} ->
        Logger.info("User settings updated successfully.")

      {:error, changeset} ->
        Logger.error("Failed to update user settings: #{inspect(changeset)}")
    end

    {:ok, %{profile_generating: true}}
  end

  def handle_profile_generation_complete do
    {:ok, %{redirect: "/"}}
  end

  def set_error(msg) do
    {:ok, %{flash: {:error, msg}, event: "newmessage", params: %{}}}
  end

  def unset_error do
    {:ok, %{clear_flash: :error, event: "newmessage", params: %{}}}
  end

  def stop_loading(socket) do
    if socket.assigns.current_question == :end do
      Process.send_after(self(), :generate_profile, 0)
      {:ok, %{profile_generating: true}}
    else
      {:ok, %{loading: false}}
    end
  end

  def generate_valid_dob_struct(text) do
    case Mic.Chat.OpenAI.generate_iso_8601_date_string(text) do
      {:ok, response} ->
        case Date.from_iso8601(response.content) do
          {:ok, date_struct} ->
            date_struct

          {:error, reason} ->
            Logger.error("Chat Completions DOB Struct Error: #{inspect(reason)}")
            nil
        end

      {:error, reason} ->
        Logger.error("Failed to generate ISO 8601 date string: #{inspect(reason)}")
        nil
    end
  end
end
