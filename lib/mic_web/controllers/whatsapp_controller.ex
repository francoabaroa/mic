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
    # 2a) If they are signed up, handle regular message
    # 2b) If not, ask them for email, sign up user with email/number (need to add column for phone to db (country code, phone number, phone type?))

    Enum.each(messages, fn message ->
      text_received = message |> Map.get("text") |> Map.get("body")
      from_number = message |> Map.get("from")

      handle_message(conn, from_number, text_received)
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

  defp handle_message(conn, from_number, text) do
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

  defp send_signup_email(user) do
    # Simulate sending a signup email
    # In a real application, you would integrate with an email service here
    IO.puts("Sending signup email to #{user.email}")
    {:ok, user}
  end

  defp respond(conn, text) do
    # Send a response back to the user
    # TODO: halt is not the best thing to use here
    conn
    |> put_status(:ok)
    |> json(%{response: text})
    |> halt()
  end
end
