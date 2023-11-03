defmodule MicWeb.ProfileLiveTest do
  use MicWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mic.ArtistsFixtures
  import Mic.AccountsFixtures

  @create_attrs %{artist_name: "some artist_name", genre: "some genre", influences: "some influences", aspirations: "some aspirations", short_bio: "some short_bio", country: "some country", dob: "2023-11-01", spotify_name: "some spotify_name", youtube_name: "some youtube_name", tiktok_name: "some tiktok_name", instagram_name: "some instagram_name", facebook_name: "some facebook_name", twitter_name: "some twitter_name", website_url: "some website_url"}
  @update_attrs %{artist_name: "some updated artist_name", genre: "some updated genre", influences: "some updated influences", aspirations: "some updated aspirations", short_bio: "some updated short_bio", country: "some updated country", dob: "2023-11-02", spotify_name: "some updated spotify_name", youtube_name: "some updated youtube_name", tiktok_name: "some updated tiktok_name", instagram_name: "some updated instagram_name", facebook_name: "some updated facebook_name", twitter_name: "some updated twitter_name", website_url: "some updated website_url"}
  @invalid_attrs %{artist_name: nil, genre: nil, influences: nil, aspirations: nil, short_bio: nil, country: nil, dob: nil, spotify_name: nil, youtube_name: nil, tiktok_name: nil, instagram_name: nil, facebook_name: nil, twitter_name: nil, website_url: nil}

  defp create_profile(_) do
    user = user_fixture()
    profile = profile_fixture(user)
    %{profile: profile}
  end

  describe "Index" do
    setup [:create_profile]

    test "lists all profiles", %{conn: conn, profile: profile} do
      {:ok, _index_live, html} = live(conn, ~p"/profiles")

      assert html =~ "Listing Profiles"
      assert html =~ profile.artist_name
    end

    test "saves new profile", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/profiles")

      assert index_live |> element("a", "New Profile") |> render_click() =~
               "New Profile"

      assert_patch(index_live, ~p"/profiles/new")

      assert index_live
             |> form("#profile-form", profile: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#profile-form", profile: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/profiles")

      html = render(index_live)
      assert html =~ "Profile created successfully"
      assert html =~ "some artist_name"
    end

    test "updates profile in listing", %{conn: conn, profile: profile} do
      {:ok, index_live, _html} = live(conn, ~p"/profiles")

      assert index_live |> element("#profiles-#{profile.id} a", "Edit") |> render_click() =~
               "Edit Profile"

      assert_patch(index_live, ~p"/profiles/#{profile}/edit")

      assert index_live
             |> form("#profile-form", profile: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#profile-form", profile: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/profiles")

      html = render(index_live)
      assert html =~ "Profile updated successfully"
      assert html =~ "some updated artist_name"
    end

    test "deletes profile in listing", %{conn: conn, profile: profile} do
      {:ok, index_live, _html} = live(conn, ~p"/profiles")

      assert index_live |> element("#profiles-#{profile.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#profiles-#{profile.id}")
    end
  end

  describe "Show" do
    setup [:create_profile]

    test "displays profile", %{conn: conn, profile: profile} do
      {:ok, _show_live, html} = live(conn, ~p"/profiles/#{profile}")

      assert html =~ "Show Profile"
      assert html =~ profile.artist_name
    end

    test "updates profile within modal", %{conn: conn, profile: profile} do
      {:ok, show_live, _html} = live(conn, ~p"/profiles/#{profile}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Profile"

      assert_patch(show_live, ~p"/profiles/#{profile}/show/edit")

      assert show_live
             |> form("#profile-form", profile: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#profile-form", profile: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/profiles/#{profile}")

      html = render(show_live)
      assert html =~ "Profile updated successfully"
      assert html =~ "some updated artist_name"
    end
  end
end
