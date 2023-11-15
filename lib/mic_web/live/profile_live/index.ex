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
      |> assign(:spotify_data, %{})

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
    {:noreply, assign(socket, :spotify_data, SpotifyService.fetch_artist(artist_name))}
  end
end
