defmodule Mic.ArtistsTest do
  use Mic.DataCase

  alias Mic.Artists

  describe "profiles" do
    alias Mic.Artists.Profile

    import Mic.ArtistsFixtures

    @invalid_attrs %{artist_name: nil, genre: nil, influences: nil, aspirations: nil, short_bio: nil, country: nil, dob: nil, spotify_name: nil, youtube_name: nil, tiktok_name: nil, instagram_name: nil, facebook_name: nil, twitter_name: nil, website_url: nil}

    test "list_profiles/0 returns all profiles" do
      profile = profile_fixture()
      assert Artists.list_profiles() == [profile]
    end

    test "get_profile!/1 returns the profile with given id" do
      profile = profile_fixture()
      assert Artists.get_profile!(profile.id) == profile
    end

    test "create_profile/1 with valid data creates a profile" do
      valid_attrs = %{artist_name: "some artist_name", genre: "some genre", influences: "some influences", aspirations: "some aspirations", short_bio: "some short_bio", country: "some country", dob: ~D[2023-11-01], spotify_name: "some spotify_name", youtube_name: "some youtube_name", tiktok_name: "some tiktok_name", instagram_name: "some instagram_name", facebook_name: "some facebook_name", twitter_name: "some twitter_name", website_url: "some website_url"}

      assert {:ok, %Profile{} = profile} = Artists.create_profile(valid_attrs)
      assert profile.artist_name == "some artist_name"
      assert profile.genre == "some genre"
      assert profile.influences == "some influences"
      assert profile.aspirations == "some aspirations"
      assert profile.short_bio == "some short_bio"
      assert profile.country == "some country"
      assert profile.dob == ~D[2023-11-01]
      assert profile.spotify_name == "some spotify_name"
      assert profile.youtube_name == "some youtube_name"
      assert profile.tiktok_name == "some tiktok_name"
      assert profile.instagram_name == "some instagram_name"
      assert profile.facebook_name == "some facebook_name"
      assert profile.twitter_name == "some twitter_name"
      assert profile.website_url == "some website_url"
    end

    test "create_profile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Artists.create_profile(@invalid_attrs)
    end

    test "update_profile/2 with valid data updates the profile" do
      profile = profile_fixture()
      update_attrs = %{artist_name: "some updated artist_name", genre: "some updated genre", influences: "some updated influences", aspirations: "some updated aspirations", short_bio: "some updated short_bio", country: "some updated country", dob: ~D[2023-11-02], spotify_name: "some updated spotify_name", youtube_name: "some updated youtube_name", tiktok_name: "some updated tiktok_name", instagram_name: "some updated instagram_name", facebook_name: "some updated facebook_name", twitter_name: "some updated twitter_name", website_url: "some updated website_url"}

      assert {:ok, %Profile{} = profile} = Artists.update_profile(profile, update_attrs)
      assert profile.artist_name == "some updated artist_name"
      assert profile.genre == "some updated genre"
      assert profile.influences == "some updated influences"
      assert profile.aspirations == "some updated aspirations"
      assert profile.short_bio == "some updated short_bio"
      assert profile.country == "some updated country"
      assert profile.dob == ~D[2023-11-02]
      assert profile.spotify_name == "some updated spotify_name"
      assert profile.youtube_name == "some updated youtube_name"
      assert profile.tiktok_name == "some updated tiktok_name"
      assert profile.instagram_name == "some updated instagram_name"
      assert profile.facebook_name == "some updated facebook_name"
      assert profile.twitter_name == "some updated twitter_name"
      assert profile.website_url == "some updated website_url"
    end

    test "update_profile/2 with invalid data returns error changeset" do
      profile = profile_fixture()
      assert {:error, %Ecto.Changeset{}} = Artists.update_profile(profile, @invalid_attrs)
      assert profile == Artists.get_profile!(profile.id)
    end

    test "delete_profile/1 deletes the profile" do
      profile = profile_fixture()
      assert {:ok, %Profile{}} = Artists.delete_profile(profile)
      assert_raise Ecto.NoResultsError, fn -> Artists.get_profile!(profile.id) end
    end

    test "change_profile/1 returns a profile changeset" do
      profile = profile_fixture()
      assert %Ecto.Changeset{} = Artists.change_profile(profile)
    end
  end
end
