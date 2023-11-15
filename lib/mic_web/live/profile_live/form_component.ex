defmodule MicWeb.ProfileLive.FormComponent do
  use MicWeb, :live_component

  alias Mic.Artists

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage profile records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="profile-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:artist_name]} type="text" label="Artist name" phx-blur="fetch_artist" />
        <.input field={@form[:country]} type="text" label="Country" />
        <.input field={@form[:genre]} type="text" label="Genre" />
        <.input field={@form[:influences]} type="text" label="Influences" />
        <.input field={@form[:aspirations]} type="text" label="Aspirations" />
        <.input field={@form[:short_bio]} type="text" label="Short bio" />
        <.input field={@form[:dob]} type="date" label="Dob" />
        <.input field={@form[:spotify_name]} type="text" label="Spotify name" value="" />
        <.input field={@form[:youtube_name]} type="text" label="Youtube name" />
        <.input field={@form[:tiktok_name]} type="text" label="Tiktok name" />
        <.input field={@form[:instagram_name]} type="text" label="Instagram name" />
        <.input field={@form[:facebook_name]} type="text" label="Facebook name" />
        <.input field={@form[:twitter_name]} type="text" label="Twitter name" />
        <.input field={@form[:website_url]} type="text" label="Website url" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Profile</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{profile: profile} = assigns, socket) do
    changeset = Artists.change_profile(profile)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"profile" => profile_params}, socket) do
    changeset =
      socket.assigns.profile
      |> Artists.change_profile(profile_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"profile" => profile_params}, socket) do
    save_profile(socket, socket.assigns.action, profile_params)
  end

  defp save_profile(socket, :edit, profile_params) do
    case Artists.update_profile(socket.assigns.profile, profile_params) do
      {:ok, profile} ->
        notify_parent({:saved, profile})

        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_profile(socket, :new, profile_params) do
    user = socket.assigns.current_user

    case Artists.create_profile(user, profile_params) do
      {:ok, profile} ->
        notify_parent({:saved, profile})

        {:noreply,
         socket
         |> put_flash(:info, "Profile created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
