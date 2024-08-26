defmodule MicWeb.UserSettingsLive do
  use MicWeb, :live_view

  alias Mic.Accounts

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>Manage your account email address, password, and response settings</:subtitle>
    </.header>

    <div class="space-y-12 divide-y">
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Current password"
            value={@email_form_current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Email</.button>
          </:actions>
        </.simple_form>
      </div>
      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            field={@password_form[:email]}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input field={@password_form[:password]} type="password" label="New password" required />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Password</.button>
          </:actions>
        </.simple_form>
      </div>
      <div>
        <.simple_form
          for={@settings_form}
          id="settings_form"
          phx-submit="update_settings"
          phx-change="validate_settings"
        >
          <.input
            field={@settings_form[:response_language]}
            type="select"
            label="Response language"
            options={[{"English", :english}, {"Spanish", :spanish}, {"Portuguese", :portuguese}]}
            value={@current_settings.response_language}
            required
          />
          <.input
            field={@settings_form[:response_answer_detail]}
            type="select"
            label="Response answer detail"
            options={[
              {"Brief", :brief},
              {"Super Brief", :super_brief},
              {"Detailed", :detailed},
              {"Normal", :normal}
            ]}
            value={@current_settings.response_answer_detail}
            required
          />
          <%!-- <.input
            field={@settings_form[:response_answer_style]}
            type="select"
            label="Response answer style"
            options={[{"Bullet Points", :bullet_points}, {"Normal", :normal}]}
            value={@current_settings.response_answer_style}
            required
          /> --%>
          <.input
            field={@settings_form[:response_medium]}
            type="select"
            label="Response medium"
            options={[{"Text", :text}, {"Voice", :voice}]}
            value={@current_settings.response_medium}
            required
          />
          <:actions>
            <.button phx-disable-with="Saving...">Change Response Settings</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)

    settings_changeset =
      Accounts.change_settings(%Mic.Accounts.Settings{}, %{"user_id" => user.id})

    # Fetch current settings from the database
    current_settings = Accounts.get_settings_by_user(user)
    IO.inspect(current_settings, label: "Current User Settings")

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:settings_form, to_form(settings_changeset))
      |> assign(:current_settings, current_settings)
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event(
        "validate_email",
        %{"current_password" => password, "user" => user_params},
        socket
      ) do
    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event(
        "update_email",
        %{"current_password" => password, "user" => user_params},
        socket
      ) do
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event(
        "validate_password",
        %{"current_password" => password, "user" => user_params},
        socket
      ) do
    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event(
        "update_password",
        %{"current_password" => password, "user" => user_params},
        socket
      ) do
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event("validate_settings", %{"settings" => user_params}, socket) do
    settings = Accounts.get_settings_by_user(socket.assigns.current_user)

    settings_form =
      settings
      |> Accounts.change_settings(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, settings_form: settings_form)}
  end

  def handle_event("update_settings", %{"settings" => user_params}, socket) do
    user = socket.assigns.current_user

    case Accounts.update_settings(user, user_params) do
      {:ok, _user} ->
        {:noreply, put_flash(socket, :info, "Settings updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, settings_form: to_form(changeset))}
    end
  end
end
