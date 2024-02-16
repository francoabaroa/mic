defmodule MicWeb.ProfileLive.Show do
  use MicWeb, :live_view

  alias Mic.Artists

  on_mount {MicWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:current_user, current_user)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    current_user = socket.assigns.current_user

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:artist_options, %{})
     |> assign(:current_user, current_user)
     |> assign(:profile, Artists.get_profile!(id))}
  end

  defp page_title(:show), do: "Show Profile"
  defp page_title(:edit), do: "Edit Profile"
end
