defmodule SpotifyService do
  def fetch_artist(artist_name) do
    config = spotify_config()
    client_id = config[:client_id]
    client_secret = config[:client_secret]

    with {:ok, token} <- get_access_token(client_id, client_secret),
         {:ok, artist_data} <- get_artist_data(artist_name, token) do
      {:ok, artist_data}
    else
      error -> {:error, error}
    end
  end

  def get_current_user_profile(access_token) do
    config = spotify_config()
    api_url = config[:api_url]

    headers = [Authorization: "Bearer #{access_token}"]
    url = "#{api_url}/me"

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        user_data = decode_artist_data(body)
        {:ok, user_data}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "Failed to fetch user profile. Status: #{status_code}. Response: #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def exchange_code_for_token(code) do
    config = spotify_config()
    client_id = config[:client_id]
    client_secret = config[:client_secret]
    token_url = config[:token_url]

    basic_auth = Base.encode64("#{client_id}:#{client_secret}")

    headers = [
      {"Authorization", "Basic #{basic_auth}"},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    # TODO: add env vars for this
    body =
      "grant_type=authorization_code&code=#{code}&redirect_uri=http://localhost:4000/auth/spotify/callback"

    case HTTPoison.post(token_url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, access_token} = parse_access_token(response_body)
        {:ok, access_token}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Failed to exchange code for token. Status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Failed to exchange code for token. Reason: #{reason}"}
    end
  end

  defp get_access_token(client_id, client_secret) do
    config = spotify_config()
    token_url = config[:token_url]

    basic_auth = Base.encode64("#{client_id}:#{client_secret}")

    headers = [
      {"Authorization", "Basic #{basic_auth}"},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    body = "grant_type=client_credentials"

    case HTTPoison.post(token_url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, access_token} = parse_access_token(response_body)
        {:ok, access_token}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "Failed to authenticate with Spotify. Status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Failed to authenticate with Spotify. Reason: #{reason}"}
    end
  end

  defp parse_access_token(response_body) do
    response_body
    |> Jason.decode!()
    |> Map.fetch("access_token")
  end

  defp get_artist_data(artist_name, access_token) do
    config = spotify_config()
    api_url = config[:api_url]

    headers = [Authorization: "Bearer #{access_token}"]
    search_params = URI.encode_query(%{q: artist_name, type: "artist", limit: 5})
    url = "#{api_url}/search?#{search_params}"

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        artist_data = decode_artist_data(body)

        {:ok, artist_data}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "Failed to fetch artist. Status: #{status_code}. Response: #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp decode_artist_data(body) do
    with {:ok, decoded} <- Jason.decode(body),
         %{"artists" => %{"items" => artists}} <- decoded do
      Enum.map(artists, fn artist ->
        name = artist["name"]
        id = artist["id"]
        {name, id}
      end)
    else
      _ -> {:error, "Failed to decode artist data"}
    end
  end

  defp spotify_config do
    Application.get_env(:mic, :spotify)
  end
end
