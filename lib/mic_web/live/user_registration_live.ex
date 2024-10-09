defmodule MicWeb.UserRegistrationLive do
  use MicWeb, :live_view

  require Logger

  alias Mic.Accounts
  alias Mic.Accounts.User
  alias Mic.Chat

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm bg-white p-8 rounded-lg shadow-md">
      <.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
            Sign in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/users/log_in?_action=registered"}
        method="post"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Create user settings
        settings_attrs = %{
          # Default to English
          response_language: :english,
          response_answer_detail: :brief,
          response_answer_style: :normal,
          # Default to text
          response_medium: :text,
          user_id: user.id
        }

        case Mic.Accounts.create_settings(user, settings_attrs) do
          {:ok, _settings} ->
            Logger.info("User settings created successfully.")

          {:error, changeset} ->
            Logger.error("Failed to create user settings: #{inspect(changeset)}")
        end

        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        # Pre-create 7 assistants for the user
        # TODO: need to create any other addtl assistants
        # Mic.Types.available_subject_and_assistant_types() + :onboarding + :essentials
        # TODO: once these are in sync, we can just use Mic.Types.available_subject_and_assistant_types()
        # Assistants.assistant_types()
        assistant_creation_details = [
          %{name: "Onboardy", assistant_type: :onboarding},
          %{name: "Essentia", assistant_type: :essentials},
          %{name: "Distro", assistant_type: :distribution},
          %{name: "Lyzer", assistant_type: :contract_analyzer},
          %{name: "Welly", assistant_type: :mental_wellness},
          %{name: "Prody", assistant_type: :production},
          %{name: "Finny", assistant_type: :finance}
        ]

        assistant_creation_results =
          Enum.map(assistant_creation_details, fn %{name: name, assistant_type: assistant_type} ->
            case Chat.create_assistant(%{
                   name: name,
                   assistant_type: assistant_type,
                   user_id: user.id
                 }) do
              {:ok, assistant} ->
                # Assistant created successfully
                {:ok, assistant}

              {:error, reason} ->
                # Handle the error case, e.g., log the error, notify the user, etc.
                Logger.error("Error creating assistant: #{inspect(reason)}")
                {:error, reason}
            end
          end)

        # Check if any assistant creation failed
        failed_creations =
          Enum.filter(assistant_creation_results, fn result -> match?({:error, _}, result) end)

        if length(failed_creations) > 0 do
          # Handle the case when one or more assistant creations failed
          error_reasons = Enum.map(failed_creations, fn {_, reason} -> reason end)
          # Log the error and continue without raising an exception
          Logger.error("Failed to create assistants: #{inspect(error_reasons)}")
        end

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
