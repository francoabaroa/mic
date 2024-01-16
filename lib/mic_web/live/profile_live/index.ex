defmodule MicWeb.ProfileLive.Index do
  use MicWeb, :live_view

  alias Mic.Artists
  alias Mic.Artists.Profile

  on_mount {MicWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:artist_options, %{})

    {:ok, stream(socket, :profiles, Artists.list_profiles())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Profile")
    |> assign(:profile, Artists.get_profile!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Profile")
    |> assign(:profile, %Profile{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Profiles")
    |> assign(:profile, nil)
  end

  @impl true
  def handle_info({MicWeb.ProfileLive.FormComponent, {:saved, profile}}, socket) do
    {:noreply, stream_insert(socket, :profiles, profile)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    profile = Artists.get_profile!(id)
    {:ok, _} = Artists.delete_profile(profile)

    {:noreply, stream_delete(socket, :profiles, profile)}
  end

  def handle_event("fetch_artist", %{"value" => artist_name}, socket) do
    artists =
      case SpotifyService.fetch_artist(artist_name) do
        {:ok, artist_data} -> artist_data
        {:error, _} -> []
      end

    {:noreply, assign(socket, :artist_options, artists)}
  end

  def handle_event("auth_spotify", _params, socket) do
    config = Application.get_env(:mic, :spotify)
    client_id = config[:client_id]
    redirect_uri = config[:redirect_uri]
    auth_url = config[:auth_url]

    full_auth_url =
      auth_url <>
        URI.encode_query(%{
          client_id: client_id,
          response_type: "code",
          redirect_uri: redirect_uri,
          scope: "user-read-private user-read-email",
          show_dialog: true
        })

    {:noreply, push_event(socket, "redirect_to_spotify", %{url: full_auth_url})}
  end

  def handle_event("auth_instagram", _params, socket) do
    config = Application.get_env(:mic, :instagram)
    client_id = config[:client_id]
    redirect_uri = config[:redirect_uri]
    auth_url = config[:auth_url]
    full_auth_url = InstagramService.get_auth_url(client_id, redirect_uri, auth_url)

    {:noreply, push_event(socket, "redirect_to_instagram", %{url: full_auth_url})}
  end
end
