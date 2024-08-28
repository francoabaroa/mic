defmodule MicWeb.OnboardingLive.Index do
  require Logger
  use MicWeb, :live_view
  alias MicWeb.OnboardingLive.{State, Helpers, MessageHandler, QuestionFlow}
  alias MicWeb.{Message, LoadingIndicatorComponent, AlertComponent}

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    default_model = Application.get_env(:mic, :default_model, :"gpt-4o")
    model = Map.get(session, "model", default_model)

    user_settings =
      Mic.Accounts.get_settings_by_user(socket.assigns.current_user)
      |> case do
        nil -> %Mic.Accounts.Settings{response_language: :english}
        settings -> settings
      end

    # Subscribe to a topic for this user's profile generation
    Phoenix.PubSub.subscribe(
      Mic.PubSub,
      "profile_generation:#{socket.assigns.current_user.id}"
    )

    {:ok,
     socket
     |> assign(State.initial_state())
     |> assign(
       openai_pid: Helpers.start_openai_process(),
       model: model,
       language_preference: nil,
       saved_language_preference: user_settings.response_language,
       response_answer_detail: user_settings.response_answer_detail,
       current_question: nil,
       profile_data: %{},
       profile_generating: false,
       text: ""
     )
     |> allow_upload(:file,
       accept: ~w(.pdf .md .html .doc .docx .txt),
       max_entries: 1,
       max_file_size: 2_000_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  defp handle_progress(:file, entry, socket) do
    case Helpers.handle_progress(:file, entry, socket, &consume_uploaded_entries/3) do
      {:ok, changes} -> {:noreply, assign(socket, changes)}
      _ -> {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("english_interaction", _params, socket),
    do: QuestionFlow.handle_language_selection(socket, :english)

  def handle_event("spanish_interaction", _params, socket),
    do: QuestionFlow.handle_language_selection(socket, :spanish)

  def handle_event("portuguese_interaction", _params, socket),
    do: QuestionFlow.handle_language_selection(socket, :portuguese)

  def handle_event("text_interaction", _params, socket) do
    {:noreply, socket, changes} = QuestionFlow.handle_communication_preference(socket, :text)
    {:noreply, assign(socket, changes)}
  end

  def handle_event("voice_interaction", _params, socket) do
    {:noreply, socket, changes} = QuestionFlow.handle_communication_preference(socket, :voice)
    {:noreply, assign(socket, changes)}
  end

  def handle_event("initiate_voice_transcription", _params, socket) do
    case Helpers.initiate_voice_transcription() do
      {:ok, %{event: event, params: params}} -> {:noreply, push_event(socket, event, params)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("stop_voice_transcription", _params, socket) do
    case Helpers.stop_voice_transcription() do
      {:ok, %{event: event, params: params}} -> {:noreply, push_event(socket, event, params)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("transcribe_voice", %{"audio" => audio_data_base64}, socket) do
    case Helpers.handle_transcribed_chat_message(audio_data_base64) do
      {:ok, changes} -> {:noreply, assign(socket, changes)}
      {:error, %{event: event, params: params}} -> {:noreply, push_event(socket, event, params)}
    end
  end

  @impl true
  def handle_info({:msg_submit, text, _is_contract, _contract_name}, socket) do
    {:noreply, socket, changes} = QuestionFlow.handle_user_response(socket, text)
    updated_socket = assign(socket, changes)

    # Handle Spotify link separately
    # Use the ai_instruction for the AI, not for the user message
    ai_instruction = Map.get(changes, :ai_instruction, "")

    # Save the Spotify link to the profile data if it's the Spotify link question
    updated_socket =
      if updated_socket.assigns.current_question == :spotify_link do
        updated_profile_data = Map.put(updated_socket.assigns.profile_data, :website_url, text)
        assign(updated_socket, profile_data: updated_profile_data)
      else
        updated_socket
      end

    spawn(fn ->
      case Mic.Chat.OpenAI.send(
             updated_socket.assigns.openai_pid,
             ai_instruction,
             updated_socket.assigns.model,
             self()
           ) do
        {:ok, result} when is_reference(result) ->
          nil

        {:ok, result} ->
          Process.send(self(), {:add_message, result}, [])
          Process.send(self(), :stop_loading, [])

          if updated_socket.assigns.current_question == :spotify_link do
            {next_question, next_question_to_set} =
              QuestionFlow.get_next_question(
                :spotify_link,
                updated_socket.assigns.profile_data.artist_name
              )

            translated_question =
              QuestionFlow.translate_question(
                next_question,
                updated_socket.assigns.language_preference ||
                  updated_socket.assigns.saved_language_preference
              )

            Process.send(
              self(),
              {:add_message, %Message{content: translated_question, sender: :assistant, id: 0}},
              []
            )

            Process.send(self(), {:update_question, next_question_to_set}, [])
          end

        {:error, e} ->
          IO.puts("error")
          IO.inspect(e)

          Process.send(self(), {:set_error, "#{inspect(e)}"}, [])
          Process.send(self(), :stop_loading, [])
      end
    end)

    {:noreply, assign(updated_socket, loading: true)}
  end

  def handle_info({:set_prefers_voice_chat, prefers_voice_chat}, socket) do
    case Helpers.set_prefers_voice_chat(socket, prefers_voice_chat) do
      {:ok, changes} -> {:noreply, assign(socket, changes)}
      _ -> {:noreply, socket}
    end
  end

  def handle_info({:set_language_preference, language_preference}, socket) do
    case Helpers.set_language_preference(socket, language_preference) do
      {:ok, changes} ->
        updated_socket = assign(socket, changes)
        {:noreply, assign(updated_socket, :language_preference, language_preference)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info(:generate_profile, socket) do
    profile_data = socket.assigns.profile_data

    spotify_bio_text =
      if profile_data.spotify_bio && profile_data.spotify_bio != "no",
        do: "Their Spotify biography states: #{profile_data.spotify_bio}",
        else: ""

    profile_description = """
    #{profile_data.artist_name} is a #{profile_data.genre} artist from #{profile_data.country}.
    Their musical journey began #{profile_data.musical_beginnings}.
    Influenced by artists like #{profile_data.influences}, #{profile_data.artist_name} aspires to #{profile_data.aspirations}.
    #{profile_data.artist_name} plays #{profile_data.instruments_played} and has #{profile_data.music_education} in music.
    Some of their notable achievements include #{profile_data.significant_milestones}.
    #{spotify_bio_text}
    Their live performance experience: #{profile_data.live_performances}.
    """

    case Mic.Jobs.GenerateArtistProfileJob.new(%{
           "current_user" => socket.assigns.current_user,
           "profile_data" => socket.assigns.profile_data,
           "profile_description" => profile_description,
           "language_preference" => socket.assigns.language_preference
         })
         |> Oban.insert() do
      {:ok, _job} ->
        settings_attrs = %{
          response_language: socket.assigns.language_preference,
          response_answer_detail: :brief,
          response_answer_style: :normal,
          response_medium:
            if(Mic.Chat.OpenAI.get_prefers_voice_chat(socket.assigns.openai_pid),
              do: :voice,
              else: :text
            )
        }

        case Mic.Accounts.update_settings(socket.assigns.current_user, settings_attrs) do
          {:ok, _settings} ->
            Logger.info("User settings updated successfully.")

          {:error, changeset} ->
            Logger.error("Failed to update user settings: #{inspect(changeset)}")
        end

        {:noreply, assign(socket, profile_generating: true)}

      {:error, error} ->
        Logger.error("Failed to enqueue GenerateArtistProfileJob: #{inspect(error)}")

        {:noreply,
         put_flash(socket, :error, "Failed to generate profile. Please try again later.")}
    end
  end

  def handle_info({:profile_generation_complete}, socket) do
    case Helpers.handle_profile_generation_complete() do
      {:ok, %{redirect: to}} -> {:noreply, push_redirect(socket, to: to)}
      _ -> {:noreply, socket}
    end
  end

  def handle_info({:set_error, msg}, socket) do
    case Helpers.set_error(msg) do
      {:ok, %{flash: {key, value}, event: event, params: params}} ->
        {:noreply, socket |> put_flash(key, value) |> push_event(event, params)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info(:unset_error, socket) do
    case Helpers.unset_error() do
      {:ok, %{clear_flash: key, event: event, params: params}} ->
        {:noreply, socket |> clear_flash(key) |> push_event(event, params)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info({:add_message, msg}, socket) do
    case MessageHandler.add_message(socket, msg) do
      {:ok, %{messages: messages, event: event, params: params}} ->
        {:noreply, assign(socket, messages: messages) |> push_event(event, params)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info({:commit_streaming_message, msg}, socket) do
    case MessageHandler.commit_streaming_message(socket, msg) do
      {:ok,
       %{messages: messages, streaming_message: streaming_message, event: event, params: params}} ->
        {:noreply,
         assign(socket, messages: messages, streaming_message: streaming_message)
         |> push_event(event, params)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info({:audio_chunk, %{chunk: base64_audio, socket_id: socket_id}}, socket) do
    case MessageHandler.send_audio_chunk(base64_audio, socket_id) do
      {:ok, %{event: event, params: params}} ->
        {:noreply, push_event(socket, event, params)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info({:update_messages, msgs}, socket) do
    case MessageHandler.update_messages(msgs) do
      {:ok, %{messages: messages}} ->
        {:noreply, assign(socket, messages: messages)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info(:stop_loading, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div
      id="chatgpt"
      class="flex"
      style="height: calc(100vh - 64px); flex-direction: column"
      phx-hook="VoiceAudioHandlers"
    >
      <%= if @profile_generating do %>
        <div class="loading-overlay">
          <div class="loading-spinner"></div>
          <p>Generating your profile...</p>
        </div>
      <% end %>

      <div class="mb-32" style="flex-grow: 1;">
        <div>
          <.live_component
            module={MicWeb.MessageListComponent}
            messages={@messages ++ [@streaming_message]}
            language_preference={@language_preference}
            id="myid"
          />

          <%= if Phoenix.Flash.get(@flash, :error) do %>
            <div class="container mx-auto p-4">
              <AlertComponent.render text={Phoenix.Flash.get(@flash, :error)} />
            </div>
          <% end %>

          <%= if @loading do %>
            <div class="container mx-auto p-4">
              <LoadingIndicatorComponent.render />
            </div>
          <% end %>
        </div>
      </div>

      <div class="sticky bottom-4 w-full border-t md:border-t-0 dark:border-white/20 md:border-transparent md:dark:border-transparent md:bg-vert-light-gradient bg-white dark:bg-gray-800 md:!bg-transparent dark:md:bg-vert-dark-gradient pt-2">
        <.live_component
          on_submit={fn val -> Process.send(self(), {:msg_submit, val, false, nil}, []) end}
          module={MicWeb.TextboxComponent}
          current_question={@current_question}
          uploads={@uploads}
          text={@text}
          disabled={@loading}
          id="textbox"
          assistant_scenario_id={nil}
        />
      </div>
    </div>
    """
  end
end
