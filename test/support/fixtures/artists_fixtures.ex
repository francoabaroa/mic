defmodule Mic.ArtistsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mic.Artists` context.
  """

  @doc """
  Generate a profile.
  """
  def profile_fixture(attrs \\ %{}) do
    {:ok, profile} =
      attrs
      |> Enum.into(%{
        artist_name: "some artist_name",
        aspirations: "some aspirations",
        country: "some country",
        dob: ~D[2023-11-01],
        facebook_name: "some facebook_name",
        genre: "some genre",
        influences: "some influences",
        instagram_name: "some instagram_name",
        short_bio: "some short_bio",
        spotify_name: "some spotify_name",
        tiktok_name: "some tiktok_name",
        twitter_name: "some twitter_name",
        website_url: "some website_url",
        youtube_name: "some youtube_name"
      })
      |> Mic.Artists.create_profile()

    profile
  end
end
