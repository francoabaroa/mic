defmodule MicWeb.WhatsAppController do
  use MicWeb, :controller
  require Logger

  # For this we heavily need to have FunctionsCalling from OpenAI -> signup, ask, tools, etc
  # We need a user in the database
  # We need to create a user if they don't exist
  # We need to send a welcome message
  # We need to send a message to the user if they don't have a user
  def receive_message(conn, params) do
    Logger.debug("Received params: #{inspect(params)}")

    case params do
      %{"entry" => entries} when is_list(entries) ->
        conn =
          Enum.reduce(entries, conn, fn entry, acc ->
            process_entry(acc, entry)
          end)

        respond(conn, "Handled incoming message.")

      _ ->
        Logger.error("Invalid request format. The 'entry' parameter is not a list.")
        respond(conn, "Invalid request format.")
    end
  end

  defp process_entry(conn, %{"changes" => changes}) when is_list(changes) do
    Enum.reduce(changes, conn, fn change, acc ->
      process_change(acc, change)
    end)
  end

  defp process_change(conn, %{"field" => "messages", "value" => value}) do
    case Map.has_key?(value, "messages") do
      true -> handle_incoming_messages(conn, value)
      false -> handle_status_update(conn, value)
    end
  end

  defp process_change(conn, change) do
    Logger.debug("Unhandled change type: #{inspect(change)}")
    conn
  end

  defp handle_incoming_messages(conn, value) do
    # TODO: what to do with contacts?
    contacts = Map.get(value, "contacts")
    messages = Map.get(value, "messages")

    # 1) Check our user db to see if someone with that phonenumber is already signed up
    # use wa_id
    # 2a) If they are signed up, handle regular message
    # use wa_id
    # 2b) If not, ask them for email, sign up user with email/number (need to add column for phone to db (wa_id, country code, phone number, phone type?))

    Enum.each(messages, fn message ->
      # TODO: maybe we use wa_id instead of from number
      from_number = message |> Map.get("from")

      case message do
        %{"text" => %{"body" => text}} ->
          handle_text_message(conn, from_number, text)

        %{"audio" => audio} ->
          handle_audio_message(conn, from_number, audio)

        _ ->
          Logger.debug("Unhandled message type: #{inspect(message)}")

          send_message(
            conn,
            from_number,
            "Sorry, I can only handle text and audio messages at the moment."
          )
      end
    end)

    conn
  end

  defp handle_status_update(conn, value) do
    statuses = Map.get(value, "statuses")

    Enum.each(statuses, fn status ->
      recipient_id = status |> Map.get("recipient_id")
      message_status = status |> Map.get("status")

      Logger.info("Status update for #{recipient_id}: #{message_status}")
    end)

    conn
  end

  defp handle_text_message(conn, from_number, text) do
    case String.split(text) do
      ["sign", "up" | email_parts] ->
        email = Enum.join(email_parts, " ")
        email_regex = ~r/^[^@\s]+@([^@\s]+\.)+[^@\s]+$/
        match_result = Regex.match?(email_regex, email)

        if match_result do
          # Initiate the signup process
          user_attrs = %{
            email: email,
            name: "New User"
          }

          Logger.info("New User: #{inspect(user_attrs)}")
          send_message(conn, from_number, "Welcome to Mic!")
        else
          send_message(
            conn,
            from_number,
            "Invalid email format. Please send 'sign up' followed by a valid email to register."
          )
        end

      ["help"] ->
        help_message =
          "To sign up, send 'sign up' followed by your email. For example: 'sign up example@email.com'."

        send_message(conn, from_number, help_message)

      _ ->
        Logger.debug("Unhandled text received: #{inspect(text)}")

        send_message(
          conn,
          from_number,
          "Sorry, I didn't understand that. Please send 'sign up' followed by your email to register."
        )
    end

    conn
  end

  # New function to handle audio messages (download and transcribe)
  defp handle_audio_message(conn, from_number, audio) do
    error_message =
      "Sorry, I couldn't download and transcribe your audio message. Please try again later."

    Logger.info("Received audio message from #{from_number}: #{inspect(audio)}")

    # Extract the media ID from the audio message
    media_id = audio["id"]

    # Retrieve the media URL from the WhatsApp API
    media_url = get_media_url(media_id)

    case media_url do
      {:ok, url} ->
        # Download the media file
        file_path = download_media(url, media_id)

        if file_path != nil do
          Logger.info("File path: #{file_path}")

          case transcribe_voice_note(file_path, conn, from_number) do
            {:ok, temporary_reply} ->
              send_audio_message(conn, from_number, temporary_reply)

              File.rm(file_path)

            {:error, reason} ->
              Logger.error("Transcription Error: #{inspect(reason)}")
              File.rm(file_path)

              send_message(
                conn,
                from_number,
                error_message
              )
          end
        else
          File.rm(file_path)

          send_message(
            conn,
            from_number,
            error_message
          )
        end

      {:error, reason} ->
        Logger.error("Failed to retrieve media URL: #{inspect(reason)}")

        send_message(
          conn,
          from_number,
          error_message
        )
    end

    conn
  end

  defp get_media_url(media_id) do
    config = Application.get_env(:mic, :whatsapp)
    access_token = config[:whatsapp_temporary_access_token]
    # TODO: env vars
    url = "https://graph.facebook.com/v19.0/#{media_id}/"

    headers = [
      {"Authorization", "Bearer #{access_token}"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        response = Jason.decode!(body)
        {:ok, response["url"]}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Unexpected status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp download_media(url, media_id) do
    config = Application.get_env(:mic, :whatsapp)
    access_token = config[:whatsapp_temporary_access_token]

    headers = [
      {"Authorization", "Bearer #{access_token}"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        # Save the downloaded media file
        # TODO: ALL OF THE INSTANCES WHERE I WRITE A FILE, NED TO MAKE SURE I DELETE IT IN CASE OF ERROR. IS THERE A BETTER WAY TO DO THIS?
        # TODO: will it always be .ogg? mae sure to save this and mp3 to enum or vars.
        File.write!("#{media_id}.ogg", body)
        Logger.info("Media downloaded successfully: #{media_id}.ogg")
        "#{media_id}.ogg"

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("Failed to download media. Status code: #{status_code}")
        nil

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Failed to download media: #{inspect(reason)}")
        nil
    end
  end

  def send_message(conn, recipient, message_text) do
    config = Application.get_env(:mic, :whatsapp)
    # Use the WhatsApp API endpoint to send messages
    api_url = config[:whatsapp_messages_api_url]
    access_token = config[:whatsapp_temporary_access_token]

    # Construct the payload for the WhatsApp message
    payload = %{
      "messaging_product" => "whatsapp",
      "to" => recipient,
      "type" => "text",
      "text" => %{
        "body" => message_text
      }
    }

    # Set the headers for the request
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    # Send the POST request to the WhatsApp API
    case HTTPoison.post(api_url, Jason.encode!(payload), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Logger.info("Message sent successfully: #{response_body}")
        {:ok, response_body}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Failed to send message: #{reason}")
        {:error, reason}
    end
  end

  def receive_verification(conn, %{
        "hub.challenge" => challenge,
        "hub.mode" => "subscribe",
        "hub.verify_token" => verify_token
      }) do
    config = Application.get_env(:mic, :whatsapp)
    whatsapp_verify_token = config[:whatsapp_verify_token]

    if verify_token == whatsapp_verify_token do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, challenge)
    else
      conn
      |> put_status(:forbidden)
      |> text("Invalid verify token.")
    end
  end

  defp send_audio_message(conn, from_number, temporary_reply) do
    config = Application.get_env(:mic, :whatsapp)
    api_url = config[:whatsapp_messages_api_url]
    access_token = config[:whatsapp_temporary_access_token]

    case create_voice_note_from_text(temporary_reply) do
      {:ok, audio_data} ->
        # Upload the audio file to WhatsApp
        case upload_media(audio_data) do
          {:ok, media_id} ->
            # Send the audio message to the user
            # Construct the payload for the audio message
            payload = %{
              "messaging_product" => "whatsapp",
              "recipient_type" => "individual",
              "to" => from_number,
              "type" => "audio",
              "audio" => %{
                "id" => media_id
              }
            }

            # Set the headers for the request
            headers = [
              {"Authorization", "Bearer #{access_token}"},
              {"Content-Type", "application/json"}
            ]

            # Send the POST request to the WhatsApp API
            case HTTPoison.post(api_url, Jason.encode!(payload), headers) do
              {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
                Logger.info("Audio message sent successfully: #{response_body}")
                {:ok, response_body}

              {:error, %HTTPoison.Error{reason: reason}} ->
                Logger.error("Failed to send audio message: #{reason}")
                {:error, reason}
            end

          {:error, reason} ->
            Logger.error("Failed to upload audio: #{inspect(reason)}")

            send_message(
              conn,
              from_number,
              "Sorry, an error occurred while processing your request."
            )
        end

      {:error, reason} ->
        Logger.error("Failed to generate voice note: #{inspect(reason)}")
        send_message(conn, from_number, "Sorry, an error occurred while processing your request.")
    end
  end

  defp upload_media(audio_data) do
    config = Application.get_env(:mic, :whatsapp)
    api_url = config[:whatsapp_media_upload_api_url]
    access_token = config[:whatsapp_temporary_access_token]

    # Create a temporary file with a shorter filename
    # TODO: do we need to use temp?
    {:ok, file_path} = Temp.path(%{prefix: "tmp", suffix: ".mp3"})
    Logger.debug("File path: #{file_path}")
    File.write!(file_path, audio_data)

    # Determine the correct MIME type based on file extension
    mime_type = "audio/mpeg"

    # Prepare the multipart form data
    form =
      {:multipart,
       [
         {:file, file_path,
          [
            {"Content-Disposition",
             ~s(form-data; name="file"; filename="#{Path.basename(file_path)}")},
            {"Content-Type", mime_type}
          ]},
         {"messaging_product", "whatsapp"},
         {"type", mime_type}
       ]}

    headers = [{"Authorization", "Bearer #{access_token}"}]

    # Send the POST request
    case HTTPoison.post(api_url, form, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        response = Jason.decode!(response_body)
        Logger.info("Response: " <> inspect(response))
        # Clean up after uploading
        File.rm(file_path)
        {:ok, response["id"]}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error: #{reason}")
        File.rm(file_path)
        {:error, reason}
    end
  end

  defp transcribe_voice_note(file_path, conn, from_number) do
    case Mic.Chat.OpenAI.transcribe_voice_using_written_file_name(file_path) do
      {:ok, text} ->
        Logger.info("Transcribed text: #{text}")

        {:ok, text}

      {:error, reason} ->
        Logger.error("Transcription Error: #{inspect(reason)}")
        File.rm(file_path)
        {:error, reason}
    end
  end

  defp create_voice_note_from_text(text) do
    case Mic.Chat.OpenAI.generate_speech_no_streaming_no_encoding(text) do
      {:ok, speech} when is_binary(speech) ->
        {:ok, speech}

      {:error, reason} ->
        Logger.error("TTS Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_signup_email(user) do
    # Simulate sending a signup email
    # In a real application, you would integrate with an email service here
    IO.puts("Sending signup email to #{user.email}")
    {:ok, user}
  end

  defp respond(conn, text) do
    # Send a response back to the user
    # TODO: halt is not the best thing to use here? do I need it?
    conn
    |> put_status(:ok)
    |> json(%{response: text})

    # |> halt()
  end
end
