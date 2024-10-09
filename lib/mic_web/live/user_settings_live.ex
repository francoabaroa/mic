defmodule MicWeb.UserSettingsLive do
  use MicWeb, :live_view

  alias Mic.Accounts

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto">
      <h1 class="text-3xl font-bold text-white mb-8 text-center">Account Settings</h1>
      <p class="text-xl text-white mb-12 text-center">
        Manage your account email address, password, and response settings
      </p>

      <div class="space-y-12">
        <div class="bg-white bg-opacity-10 rounded-xl p-6 shadow-lg">
          <h2 class="text-2xl font-semibold text-white mb-6">Change Email</h2>
          <.form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
            class="space-y-4"
          >
            <div>
              <label for="email" class="block text-sm font-medium text-white">Email</label>
              <input
                type="email"
                name="user[email]"
                id="email"
                required
                class="mt-1 block w-full rounded-md bg-white bg-opacity-20 border-transparent focus:border-white focus:bg-opacity-30 focus:ring-0 text-white"
              />
            </div>
            <div>
              <label for="current_password_for_email" class="block text-sm font-medium text-white">
                Current password
              </label>
              <input
                type="password"
                name="current_password"
                id="current_password_for_email"
                required
                class="mt-1 block w-full rounded-md bg-white bg-opacity-20 border-transparent focus:border-white focus:bg-opacity-30 focus:ring-0 text-white"
              />
            </div>
            <button
              type="submit"
              class="w-full py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-indigo-900 bg-yellow-400 hover:bg-yellow-300 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500"
            >
              Change Email
            </button>
          </.form>
        </div>

        <div class="bg-white bg-opacity-10 rounded-xl p-6 shadow-lg">
          <h2 class="text-2xl font-semibold text-white mb-6">Change Password</h2>
          <.form
            for={@password_form}
            id="password_form"
            action={~p"/users/log_in?_action=password_updated"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-4"
          >
            <input type="hidden" name="user[email]" id="hidden_user_email" value={@current_email} />
            <div>
              <label for="password" class="block text-sm font-medium text-white">
                New password
              </label>
              <input
                type="password"
                name="user[password]"
                id="password"
                required
                class="mt-1 block w-full rounded-md bg-white bg-opacity-20 border-transparent focus:border-white focus:bg-opacity-30 focus:ring-0 text-white"
              />
            </div>
            <div>
              <label for="password_confirmation" class="block text-sm font-medium text-white">
                Confirm new password
              </label>
              <input
                type="password"
                name="user[password_confirmation]"
                id="password_confirmation"
                required
                class="mt-1 block w-full rounded-md bg-white bg-opacity-20 border-transparent focus:border-white focus:bg-opacity-30 focus:ring-0 text-white"
              />
            </div>
            <div>
              <label for="current_password_for_password" class="block text-sm font-medium text-white">
                Current password
              </label>
              <input
                type="password"
                name="current_password"
                id="current_password_for_password"
                required
                class="mt-1 block w-full rounded-md bg-white bg-opacity-20 border-transparent focus:border-white focus:bg-opacity-30 focus:ring-0 text-white"
              />
            </div>
            <button
              type="submit"
              class="w-full py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-indigo-900 bg-yellow-400 hover:bg-yellow-300 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500"
            >
              Change Password
            </button>
          </.form>
        </div>

        <div class="bg-white bg-opacity-10 rounded-xl p-6 shadow-lg">
          <h2 class="text-2xl font-semibold text-white mb-6">Response Settings</h2>
          <.form
            for={@settings_form}
            id="settings_form"
            phx-submit="update_settings"
            phx-change="validate_settings"
            class="space-y-4"
          >
            <div>
              <label for="response_language" class="block text-sm font-medium text-white">
                Response language
              </label>
              <select
                name="settings[response_language]"
                id="response_language"
                required
                class="mt-1 block w-full rounded-md bg-white bg-opacity-20 border-transparent focus:border-white focus:bg-opacity-30 focus:ring-0 text-white"
              >
                <option value="english" selected={@current_settings.response_language == :english}>
                  English
                </option>
                <option value="spanish" selected={@current_settings.response_language == :spanish}>
                  Spanish
                </option>
                <option
                  value="portuguese"
                  selected={@current_settings.response_language == :portuguese}
                >
                  Portuguese
                </option>
              </select>
            </div>
            <div>
              <label for="response_answer_detail" class="block text-sm font-medium text-white">
                Response answer detail
              </label>
              <select
                name="settings[response_answer_detail]"
                id="response_answer_detail"
                required
                class="mt-1 block w-full rounded-md bg-white bg-opacity-20 border-transparent focus:border-white focus:bg-opacity-30 focus:ring-0 text-white"
              >
                <option value="brief" selected={@current_settings.response_answer_detail == :brief}>
                  Brief
                </option>
                <option
                  value="super_brief"
                  selected={@current_settings.response_answer_detail == :super_brief}
                >
                  Super Brief
                </option>
                <option
                  value="detailed"
                  selected={@current_settings.response_answer_detail == :detailed}
                >
                  Detailed
                </option>
                <option value="normal" selected={@current_settings.response_answer_detail == :normal}>
                  Normal
                </option>
              </select>
            </div>
            <%!-- <.input
            field={@settings_form[:response_answer_style]}
            type="select"
            label="Response answer style"
            options={[{"Bullet Points", :bullet_points}, {"Normal", :normal}]}
            value={@current_settings.response_answer_style}
            required
          /> --%>
            <div>
              <label for="response_medium" class="block text-sm font-medium text-white">
                Response medium
              </label>
              <select
                name="settings[response_medium]"
                id="response_medium"
                required
                class="mt-1 block w-full rounded-md bg-white bg-opacity-20 border-transparent focus:border-white focus:bg-opacity-30 focus:ring-0 text-white"
              >
                <option value="text" selected={@current_settings.response_medium == :text}>
                  Text
                </option>
                <option value="voice" selected={@current_settings.response_medium == :voice}>
                  Voice
                </option>
              </select>
            </div>
            <button
              type="submit"
              class="w-full py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-indigo-900 bg-yellow-400 hover:bg-yellow-300 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500"
            >
              Change Response Settings
            </button>
          </.form>
        </div>
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
