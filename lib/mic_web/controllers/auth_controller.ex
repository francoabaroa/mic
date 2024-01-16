defmodule MicWeb.AuthController do
  use MicWeb, :controller

  def spotify_callback(conn, %{"code" => code}) do
    case SpotifyService.exchange_code_for_token(code) do
      {:ok, access_token} ->
        # TODO: Store the access token in the session or database

        # Fetch the current user's profile
        case SpotifyService.get_current_user_profile(access_token) do
          {:ok, _user_data} ->
            conn
            |> put_flash(:info, "Successfully authenticated with Spotify.")
            |> redirect(to: "/")

          {:error, _error} ->
            conn
            |> put_flash(:error, "Failed to retrieve user profile from Spotify.")
            |> redirect(to: "/error")
        end

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to authenticate with Spotify: #{reason}")
        |> redirect(to: "/error")
    end
  end

  def instagram_callback(conn, %{"code" => code}) do
    config = Application.get_env(:mic, :instagram)
    client_id = config[:client_id]
    client_secret = config[:client_secret]
    redirect_uri = config[:redirect_uri]
    token_url = config[:token_url]
    api_url = config[:api_url]

    case InstagramService.exchange_code_for_token(
           client_id,
           client_secret,
           redirect_uri,
           code,
           token_url
         ) do
      {:ok, response} ->
        decoded_body = Jason.decode!(response.body)

        if is_map(decoded_body) and is_binary(decoded_body["access_token"]) do
          access_token = decoded_body["access_token"]

          case InstagramService.get_user_data("me", access_token, api_url) do
            {:ok, user_data} ->
              # TODO: delete this after testing
              IO.puts("User data: #{inspect(user_data)}")
              # TODO: Store the access token and user data as needed
              conn
              |> put_flash(:info, "Successfully authenticated with Instagram.")
              |> redirect(to: "/")

            {:error, _error} ->
              conn
              |> put_flash(:error, "Failed to retrieve user profile from Instagram.")
              |> redirect(to: "/error")
          end
        else
          conn
          |> put_flash(:error, "Invalid response from Instagram.")
          |> redirect(to: "/error")
        end

      {:error, _error} ->
        conn
        |> put_flash(:error, "Failed to authenticate with Instagram.")
        |> redirect(to: "/error")
    end
  end
end
