defmodule MicWeb.DashboardLive.Index do
  use MicWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    profile = Mic.Artists.get_profile_by_user_id!(user_id)
    artist_name = profile.artist_name

    socket =
      assign(socket, :profile, profile)
      |> assign(:artist_name, artist_name)

    send_metrics(socket)
    {:ok, socket}
    profile = Mic.Artists.get_profile_by_user_id!(socket.assigns.current_user.id)
    profile.artist_name
    send_metrics(socket)
    {:ok, socket}
  end

  @impl true
  def handle_event("nextComments", _, socket) do
    {:noreply, socket |> push_event("comments", %{comments: get_comments()})}
  end

  @impl true
  def handle_event("nextLikes", _, socket) do
    {:noreply, socket |> push_event("likes", %{likes: get_likes()})}
  end

  @impl true
  def handle_event("nextStreams", _, socket) do
    {:noreply, socket |> push_event("streams", %{streams: get_streams()})}
  end

  defp send_metrics(socket) do
    metrics = %{
      comments: get_comments(),
      likes: get_likes(),
      streams: get_streams()
    }

    socket |> push_event("metrics", metrics)
  end

  defp get_comments, do: Enum.map(1..7, fn _ -> :rand.uniform(100) end)
  defp get_likes, do: Enum.map(1..7, fn _ -> :rand.uniform(100) end)
  defp get_streams, do: Enum.map(1..7, fn _ -> :rand.uniform(100) end)
end
