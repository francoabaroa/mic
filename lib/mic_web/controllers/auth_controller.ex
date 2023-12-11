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
end
