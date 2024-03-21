defmodule Mic.Artists.Chartmetric do
  require Logger
  use HTTPoison.Base

  @base_url "https://api.chartmetric.com/api"

  def process_request_headers(headers) do
    config = chartmetric_config()
    access_token = config[:access_token]
    [{"Authorization", "Bearer #{access_token}"} | headers]
  end

  def process_request_url(url) do
    @base_url <> url
  end

  def process_response_body(body) do
    body
    |> Jason.decode!()
  end

  def get_artist_id(artist_name) do
    case get("/search", [], params: [q: artist_name, limit: 1]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"obj" => %{"artists" => [%{"id" => artist_id} | _]}}} ->
            {:ok, artist_id}

          {:ok, _} ->
            {:error, "Artist not found"}

          {:error, reason} ->
            {:error, "Failed to parse response: #{inspect(reason)}"}
        end

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "Unexpected status code: #{status}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def get_artist_spotify_stats(artist_id) do
    case get("/artist/#{artist_id}/stat/spotify") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body["obj"]}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.error("in get_artist_spotify_stats error #{inspect(status)}")
        {:error, "Unexpected status code: #{status}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("in get_artist_spotify_stats error #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_artist_instagram_stats(artist_id) do
    case get("/artist/#{artist_id}/stat/instagram") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body["obj"]}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "Unexpected status code: #{status}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  def get_artist_youtube_stats(artist_id) do
    case get("/artist/#{artist_id}/stat/youtube_artist") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body["obj"]}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "Unexpected status code: #{status}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp chartmetric_config do
    Application.get_env(:mic, :chartmetric)
  end

  # Add more functions for other Chartmetric API endpoints as needed
end
