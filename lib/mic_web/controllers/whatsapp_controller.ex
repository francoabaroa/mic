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

  def send_message(recipient, message_text) do
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

  def generate_openai_response(msg) do
    initial_msg = [
      %ExOpenAI.Components.ChatCompletionRequestUserMessage{
        role: :user,
        content: """
          I need you to identify two things: 1) What aspect of a music artist's career does this message pertain to (which category does it fit best under)? distribution, finance, mental wellness, contract analysis, production, or other? 2) the language of the message. The values should always be in lowercase. Always respond in JSON like these examples:

          1. If the message pertains to distribution and is in english, respond with:
          ```json
          { "aspect": "distribution", "language": "english" }
          ```

          2. If the message pertains to finance and is in spanish, respond with:
          ```json
          { "aspect": "finance", "language": "spanish" }
          ```

          3. If the message pertains to mental wellness and is in portuguese, respond with:
          ```json
          { "aspect": "mental wellness", "language": "portuguese" }
          ```

          4. If the message pertains to contract analysis and is in english, respond with:
          ```json
          { "aspect": "contract analysis", "language": "english" }
          ```

          5. If the message pertains to production, respond with the <language> it's in and the aspect:
          ```json
          { "aspect": "production", "language": "<language>" }
          ```

          6. If the message pertains to another major category (not directly distribution, finance, mental wellness, contract analysis, or production), respond with the <language> it's in and the aspect:
          ```json
          { "aspect": "other", "language": "<language>" }
          ```
        """
      },
      %ExOpenAI.Components.ChatCompletionRequestUserMessage{
        role: :user,
        content: msg
      }
    ]

    model = Application.get_env(:mic, :model) || "gpt-4o"

    opts = [
      response_format: %{
        type: "json_object"
      }
    ]

    case ExOpenAI.Chat.create_chat_completion(initial_msg, model, opts) do
      {:ok, res} ->
        first = List.first(res.choices)

        case Jason.decode(first.message.content) do
          {:ok, parsed_content} ->
            aspect = parsed_content["aspect"]
            language = parsed_content["language"]
            Logger.info("Identified aspect: #{inspect(aspect)}")
            Logger.info("Identified language: #{inspect(language)}")

            brief_answers =
              "\n\nKeep your answers extremely brief, extremely personalized and to the point. Your user is a music artist who is trying to navigate the intricacies of music industry contracts. Your answers should be focused on music biz/industry topics and should not engage in discussions outside of this domain. Keep your answers extremely brief and to the point unless they ask for more detail. Its EXTREMELY IMPORTANT TO KEEP YOUR ANSWERS AS BRIEF AS POSSIBLE AND TO THE POINT. THE USER READING THEM WANTS SHORT, BRIEF, SIMPLE ANSWERS."

            artist_info =
              "You are giving a music artist advice on specific aspects of the music industry."

            # TODO: this routing engine needs to be more sophisticated and robust. asking about the legal aspect of royalties, results in the finance one being triggered.
            # TODO: need to combine this with the scenario prompt so its consistent across platforms. need hotkeys, context follow up questions and same prompt for same results
            response_text =
              case aspect do
                "contract analysis" ->
                  "You are the Music Contract Analyzer, a specialist in deciphering music industry contracts. Your primary function is to summarize these contracts, highlight any predatory terms or red flags, and explain how these red flags are problematic for the artist (how it will limit them financially or creatively). Assist in identifying various potential red flags and predatory terms such as unfair royalty splits, excessive length, hidden costs, creative control issues, rights ownership, recoupment terms, 360 deals, perpetuity rights, exclusivity restrictions, termination penalties, cross-collateralization, and more.\n\nProvide high-level contract summaries, identify red flags and potentially predatory clauses, offer personalized analysis of specific contract excerpts, share comparative examples, and engage in focused Q&A. Suggest strategies for protection, such as seeking legal counsel, education on terms, fair negotiations, networking for insights, and staying informed on industry practices. Always remind users to consult with a lawyer for comprehensive advice on any contract-related matters. To help users navigate your vast knowledge more efficiently, present 2-4 relevant suggestions of follow up questions they can ask YOU based on the current context of the conversation. Include these suggestions at the end of your responses and preface them with 'Follow up questions:'.\n\nIn regards to the document the artist is submitting, first, analyze it and if it is a contract/agreement of any sort (including distribution agreements, management agreements, publishing agreements, collaboration agreements, endorsement agreements, performance contracts, merchandising agreements, equipment leases, studio recording agreements, and licensing agreements), proceed with the analysis in your instructions (high-level summary, red flags/predatory terms, how this is problematic for the artist (how it will limit them financially or creatively), suggestions for protection, etc).\n\nIf it is not a contract/agreement (such as song lyrics, press releases, bios, marketing plans, royalty statements, copyright registrations, tour itineraries, grant applications, promotional materials, tour riders, non-disclosure agreements (NDAs), social media strategy documents, financial statements, health and safety plans), then analyze it, try to interpret what the artist needs for you regarding this document and provide a high-level summary and analysis of the document.\n\nRemember to end saying 'this is not legal advice. always consult with a lawyer.'"

                "mental wellness" ->
                  "You are the Mental Wellness Bot for Music Artists, designed to provide emotional support and maintain the mental well-being of artists within the music industry. Your conversations will be compassionate and reassuring, conducting check-ins that feel personal and delivering thoughtful resources depending on the artist's emotional state. Your responses should also maintain privacy and confidentiality, ensuring a safe space for artists to express themselves.\n\nEmploy a friendly and supportive tone, conduct regular check-ins, provide coping mechanisms, offer guidance to professional mental health services when needed, demonstrate empathy and understanding, and ensure the highest levels of privacy. To help users navigate your vast knowledge more efficiently, present 2-4 relevant suggestions of follow up questions they can ask YOU based on the current context of the conversation. Include these suggestions at the end of your responses and preface them with 'Follow up questions:'. Always remind users to consult with a professional for comprehensive advice on mental health matters."

                "distribution" ->
                  "You are the Music Distribution Expert, a knowledgeable guide in navigating the complex landscape of music distribution. Your mission is to empower artists by providing expert advice on distributing their work effectively. Assist them in areas such as digital distribution platforms, physical distribution tactics, music video distribution, social media strategies, collaboration techniques, streaming platforms and playlists, live performance opportunities, engaging with media, radio/podcast outreach, licensing, networking, email marketing, analytics, merchandising, fan engagement, and staying updated with industry trends.\n\nOffer tailored, practical guidance aimed at maximizing reach and exposure. Provide clear summaries and actionable insights, and remind artists to consult with professionals for specific needs. To help users navigate your vast knowledge more efficiently, present 2-4 relevant suggestions of follow up questions they can ask YOU based on the current context of the conversation. Include these suggestions at the end of your responses and preface them with 'Follow up questions:'."

                "production" ->
                  "You are the Music Production Advisor, an expert in guiding aspiring producers and artists through the music creation process. Your primary function is to provide actionable advice, share industry insights, and offer inspiration to help users elevate their music production skills. Assist users with various aspects of music production, including recording techniques, studio setup, production techniques, software & technology, mixing & mastering, collaboration strategies, and additional topics like music theory, workflows, and live performance techniques.\n\nProvide concrete examples, actionable steps, and relevant anecdotes to illustrate key points and inspire users. Tailor responses to the user's specific needs and goals, and offer words of encouragement to keep them motivated. To help users navigate your vast knowledge more efficiently, present 2-4 relevant suggestions of follow up questions they can ask YOU based on the current context of the conversation. Include these suggestions at the end of your responses and preface them with 'Follow up questions:'."

                "finance" ->
                  "You are the Finance Tips Assistant, a knowledgeable guide dedicated to helping music artists navigate financial management and develop strategies for long-term success. Your primary function is to provide artists with tools, insights, and guidance to take control of their financial future and build sustainable, thriving music careers.\n\nAssist artists in developing financial literacy and management skills across key areas including financial foundations, revenue optimization, budgeting & planning, long-term strategies, tax navigation, financial health check-ups, and further learning. Tailor responses to the artist's specific needs, provide actionable advice and resources, and remind them to consult with licensed financial professionals for personalized advice. To help users navigate your vast knowledge more efficiently, present 2-4 relevant suggestions of follow up questions they can ask YOU based on the current context of the conversation. Include these suggestions at the end of your responses and preface them with 'Follow up questions:'."

                _ ->
                  "You are the Ultimate Music Career Advisor, a highly knowledgeable and experienced expert in all aspects of the music industry. Your role is to provide comprehensive guidance and support to aspiring and established music professionals, helping them navigate the complexities of the industry and achieve their career goals.\n\nYour expertise spans a wide range of areas, including discovery, talent development, music education, songwriting, artist management, A&R, record labels, independent artists, recording, production, mastering, music technology, marketing, promotion, PR, social media, music videos, music publishing, licensing, sync rights, distribution, streaming platforms, radio airplay, live performances, touring, music festivals, events, merchandising, collaborations, charts, industry metrics, royalties, revenue collection, music law, contracts, music therapy, and social impact.\n\nWhen assisting users, always strive to provide clear, concise, and actionable advice tailored to their specific needs and goals. Share relevant insights, strategies, and best practices based on your deep understanding of the music industry landscape. Offer encouraging words and practical tips to help users overcome challenges and seize opportunities in their music careers.\n\nIn your responses, aim to cover the most important aspects of the user's question while maintaining a friendly and supportive tone. Break down complex topics into easily digestible points, and provide examples or case studies to illustrate key concepts whenever possible. Encourage users to ask follow-up questions and explore topics further, as your knowledge base covers the entire spectrum of the music industry.\n\nRemember to prioritize the user's privacy and confidentiality, and refrain from sharing any personal information or experiences without their explicit consent. If a user seeks advice on sensitive topics such as legal matters, mental health, or financial decisions, always recommend that they consult with qualified professionals in those fields for personalized guidance.\n\nTo help users navigate your vast knowledge more efficiently, present 2-4 relevant suggestions of follow up questions they can ask YOU based on the current context of the conversation. Include these suggestions at the end of your responses and preface them with 'Follow up questions:'.\n\nBy offering expert guidance, practical strategies, and ongoing support, your goal is to empower music professionals at all levels to thrive in their careers and make a meaningful impact in the industry. Always strive to be a reliable, knowledgeable, and inspiring resource for anyone seeking to navigate the exciting and ever-evolving world of music."
              end

            Logger.info("Response text: #{response_text}")

            message_content =
              artist_info <>
                "\n\n This is who you are and what you'll do:#{response_text}.\n\nThis is the artist's message:" <>
                msg <>
                "\n\n Keep it as brief and to the point. If any parts of your answer require bullet points (when giving a list of things), please format it as so." <>
                "\n\nYour response MUST be in #{language} language." <> brief_answers

            Logger.info("Message content: #{message_content}")

            msg = [
              %ExOpenAI.Components.ChatCompletionRequestUserMessage{
                role: :user,
                content: message_content
              }
            ]

            case ExOpenAI.Chat.create_chat_completion(msg, model) do
              {:ok, res} ->
                Logger.info("OpenAI received response: #{inspect(res)}")
                first = List.first(res.choices)
                Logger.info("OpenAI first response: #{inspect(first.message)}")

                case first.message.content do
                  {:ok, content} -> {:ok, content}
                  content -> {:ok, content}
                end

              {:error, reason} ->
                Logger.error("Error in generate_openai_response request: #{inspect(reason)}")
                {:error, reason}
            end
        end

      {:error, reason} ->
        Logger.error("Error in initial aspect identification request: #{inspect(reason)}")
        {:error, reason}

      _ ->
        Logger.error("Unexpected return value from initial Chat Completions")
        {:error, :unexpected_return_value}
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
    # TODO: contacts has wa_id and name, if not used remove
    _contacts = Map.get(value, "contacts")
    messages = Map.get(value, "messages")
    Logger.debug("messages: #{inspect(messages)}")

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

        %{"document" => document} ->
          handle_document_message(conn, from_number, document)

        _ ->
          Logger.debug("Unhandled message type: #{inspect(message)}")

          send_message(
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
          send_message(from_number, "Welcome to Mic!")
        else
          send_message(
            from_number,
            "Invalid email format. Please send 'sign up' followed by a valid email to register."
          )
        end

      ["help"] ->
        help_message =
          "To sign up, send 'sign up' followed by your email. For example: 'sign up example@email.com'."

        send_message(from_number, help_message)

      _ ->
        Logger.debug("Unhandled text received: #{inspect(text)}")

        case generate_openai_response(text) do
          {:ok, response} ->
            Logger.info("OpenAI response: #{response}")

            send_message(
              from_number,
              response
            )

          {:error, reason} ->
            Logger.error("Error in generate_openai_response: #{inspect(reason)}")
            {:error, reason}
        end
    end

    conn
  end

  defp handle_document_message(conn, from_number, document) do
    Logger.info("Received document message from #{from_number}: #{inspect(document)}")

    # Extract the media ID from the document message
    media_id = document["id"]
    mime_type = document["mime_type"]
    original_file_name = document["filename"]

    # TODO: NEED TO LET ASSISTANT DO EVERYTHING IN ONE, WITHOUT HAVING THE ADDITIONAL CALLS TO CHAT COMPLETIONS BELOW
    # TODO: also unsure if this method of extracting text will work for long contracts, clearly already running into issues
    #           I use Ghostscript to convert the PDF to a txt file then attempt to parse it.

    # System.cmd("gs", ["-sDEVICE=txtwrite", "-o#{txt_path}", pdf_path])
    # Parsing this resulting text file can be difficult if the PDFs are not of consistent format but at least you have text to work with.
    # There is no library that converts pdf to text, as far as I can say. Your best bet is to use something like "pdftotext" with System.cmd. Optionally you can wrap it in
    # GenServer.

    # Check if media_id is already being processed
    if :ets.lookup(:media_processing_table, media_id) == [] do
      :ets.insert(:media_processing_table, {media_id, true})
      # Insert media_id into ETS to mark as being processed

      # Retrieve the media URL from the WhatsApp API
      Logger.info("Retrieving media URL for media_id #{media_id} hjtri14")
      media_url = get_media_url(media_id)

      case media_url do
        {:ok, url} ->
          # Download the document file
          case download_document_media(url, media_id, mime_type) do
            file_path ->
              if file_path != nil do
                Logger.info("File path: #{file_path}")

                try do
                  send_message(from_number, "Processing your document. This may take a moment.")

                  Mic.Jobs.RustGenerateDocumentExtractionAndResponseJob.new(%{
                    "file_path" => file_path,
                    "original_file_name" => original_file_name,
                    "from_number" => from_number
                  })
                  |> Oban.insert()
                rescue
                  exception ->
                    Logger.error(
                      "Failed to enqueue RustGenerateDocumentExtractionAndResponseJob: #{inspect(exception)}"
                    )

                    {:error, exception}
                end
              else
                File.rm(file_path)

                send_message(
                  from_number,
                  "Sorry, an error occurred while downloading your document."
                )
              end

            {:error, reason} ->
              Logger.error("Failed to download document media: #{inspect(reason)}")

              send_message(
                from_number,
                "Sorry, an error occurred while downloading your document."
              )
          end

        {:error, reason} ->
          Logger.error("Failed to retrieve media URL: #{inspect(reason)}")

          send_message(
            from_number,
            "Sorry, an error occurred while processing your document."
          )
      end
    else
      # TODO: what to do if its already being processed?
      Logger.info("Document with media_id #{media_id} is already being processed.")
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
    mime_type = audio["mime_type"]

    # Retrieve the media URL from the WhatsApp API
    media_url = get_media_url(media_id)

    case media_url do
      {:ok, url} ->
        # Download the media file
        file_path = download_audio_media(url, media_id)

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
                from_number,
                error_message
              )
          end
        else
          File.rm(file_path)

          send_message(
            from_number,
            error_message
          )
        end

      {:error, reason} ->
        Logger.error("Failed to retrieve media URL: #{inspect(reason)}")

        send_message(
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

  defp download_audio_media(url, media_id) do
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
        {:ok, file_path} = Temp.path(%{prefix: "#{media_id}", suffix: ".ogg"})
        File.write!(file_path, body)
        Logger.info("Audio downloaded successfully: #{media_id}.ogg")
        file_path

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("Failed to download media. Status code: #{status_code}")
        nil

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Failed to download media: #{inspect(reason)}")
        nil
    end
  end

  defp download_document_media(url, media_id, mime_type) do
    config = Application.get_env(:mic, :whatsapp)
    access_token = config[:whatsapp_temporary_access_token]

    headers = [
      {"Authorization", "Bearer #{access_token}"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        # Determine the file extension based on the MIME type
        extension = get_file_extension(mime_type)

        if extension do
          {:ok, file_path} = Temp.path(%{prefix: "#{media_id}", suffix: ".#{extension}"})
          File.write!(file_path, body)
          Logger.info("Document downloaded successfully: #{file_path}")
          file_path
        else
          Logger.error("Unsupported MIME type: #{mime_type}")
          nil
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("Failed to download media. Status code: #{status_code}")
        nil

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Failed to download media: #{inspect(reason)}")
        nil
    end
  end

  defp get_file_extension(mime_type) do
    case mime_type do
      "text/plain" -> "txt"
      "application/pdf" -> "pdf"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "docx"
      "application/msword" -> "doc"
      _ -> nil
    end
  end

  defp send_audio_message(_conn, from_number, temporary_reply) do
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
              from_number,
              "Sorry, an error occurred while processing your request."
            )
        end

      {:error, reason} ->
        Logger.error("Failed to generate voice note: #{inspect(reason)}")
        send_message(from_number, "Sorry, an error occurred while processing your request.")
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

        case generate_openai_response(text) do
          {:ok, response} ->
            Logger.info("OpenAI response: #{response}")
            {:ok, response}

          {:error, reason} ->
            Logger.error("Error in generate_openai_response: #{inspect(reason)}")
            {:error, reason}
        end

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
