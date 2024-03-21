defmodule MicWeb.DashboardLive.Index do
  use MicWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    profile = Mic.Artists.get_profile_by_user_id!(user_id)
    artist_name = profile.artist_name

    socket =
      assign(socket,
        profile: profile,
        artist_name: artist_name,
        listeners: nil,
        likes: nil,
        comments: nil,
        followers: nil,
        loading: true,
        error: nil
      )

    {:ok, socket, temporary_assigns: [loading: true]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("nextListeners", _, socket) do
    {:noreply, send_metrics(socket)}
  end

  @impl true
  def handle_event("nextLikes", _, socket) do
    {:noreply, send_metrics(socket)}
  end

  @impl true
  def handle_event("nextComments", _, socket) do
    {:noreply, send_metrics(socket)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Dashboard")
    |> assign(:metrics, [])
    |> send_metrics()
  end

  defp send_metrics(socket) do
    # artist_id = socket.assigns.profile.artist_id
    # TODO: TEMPORARY hardcoded -> need to save chartmetric artist_id to profile
    artist_id = 3963

    case Mic.Artists.get_artist_metrics(artist_id) do
      {:ok, metrics} ->
        socket
        |> assign(
          listeners: metrics.listeners,
          likes: metrics.likes,
          comments: metrics.comments,
          followers: metrics.followers,
          loading: false,
          error: nil
        )

      {:error, reason} ->
        socket
        |> assign(loading: false, error: reason)
    end
  end
end
