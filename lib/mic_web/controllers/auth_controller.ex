defmodule MicWeb.AuthController do
  use MicWeb, :controller

  # TODO: uncomment
  def spotify_callback(_conn, %{"code" => _code}) do
    # Exchange the code for an access token
    # case SpotifyService.exchange_code_for_token(code) do
    #   {:ok, access_token} ->
    #     # Store the access token in the session or database
    #     # Redirect the user to another page, e.g., user dashboard
    #     conn
    #     |> put_flash(:info, "Successfully authenticated with Spotify.")
    #     |> redirect(to: Routes.dashboard_path(conn, :index))

    #   {:error, reason} ->
    #     conn
    #     |> put_flash(:error, "Failed to authenticate with Spotify: #{reason}")
    #     |> redirect(to: Routes.page_path(conn, :index))
    # end
  end
end
