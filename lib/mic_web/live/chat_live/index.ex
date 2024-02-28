defmodule MicWeb.ChatLive.Index do
  require Logger
  use MicWeb, :live_view
  alias MicWeb.Message
  alias MicWeb.LoadingIndicatorComponent
  alias MicWeb.AlertComponent
  use ExOpenAI.StreamingClient

  @type state :: %{messages: [Message.t()], loading: boolean(), streaming_message: Message.t()}

  @spec initial_messages(String.t() | nil) :: [Message.t()]
  defp initial_messages(nil) do
    [
      %Message{
        content:
          "Hi! I'm here to onboard you to Incurator.\n\nYou will be able to change your preferences later on.\n\nDo you prefer we talk in English, Spanish or Portuguese?",
        sender: :assistant,
        id: 0
      }
    ]
  end

  defp initial_messages(scenario_description) when is_binary(scenario_description) do
    [%Message{content: scenario_description, sender: :assistant, id: 0}]
  end

  @spec initial_state(String.t() | nil) :: state
  defp initial_state(scenario_description) do
    %{
      messages: initial_messages(scenario_description),
      loading: false,
      streaming_message: %Message{content: "", sender: :assistant, id: -1}
    }
  end

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    Phoenix.PubSub.subscribe(Mic.PubSub, "audio:topic")
    default_model = Application.get_env(:mic, :default_model, :"gpt-3.5-turbo")
    session_model = session |> Map.get("model", default_model)
    model = Map.get(params, "model", session_model)
    models = Application.get_env(:mic, :models, [model])

    artist_ai_description =
      try do
        profile = Mic.Artists.get_profile_by_user_id!(socket.assigns.current_user.id)
        profile.artist_ai_description
      rescue
        Ecto.NoResultsError ->
          # This block executes if no profile is found, returning a default or nil
          Logger.debug("No profile found for user.")
          nil
      end

    instructions_to_append =
      if artist_ai_description != nil do
        "Here is a biography of the artist who you will be assisting today: " <>
          artist_ai_description <>
          " Always use their biography to give them personalized and useful responses tailored to them and their history."
      else
        ""
      end

    scenarios = MicWeb.Scenario.default_scenarios(instructions_to_append)

    # Determine the mode based on the presence of a scenario_id in the params
    mode = if scenario_id = Map.get(params, "scenario_id"), do: :scenario, else: :chat

    # Fetch the scenario if in scenario mode
    scenario =
      if mode == :scenario, do: fetch_scenario(scenario_id, instructions_to_append), else: nil

    scenario_description = if mode == :scenario, do: scenario.description, else: nil

    openai_pid =
      if mode == :scenario do
        init_settings = %{
          messages: scenario.messages,
          keep_context: Map.get(scenario, "keep_context", false)
        }

        {:ok, pid} = Mic.Chat.OpenAI.start_link(init_settings)
        pid
      else
        init_settings = %{}
        {:ok, pid} = Mic.Chat.OpenAI.start_link(init_settings)
        pid
      end

    {:ok,
     socket
     |> assign(initial_state(scenario_description))
     |> assign(
       assistant_type: scenario_id,
       openai_pid: openai_pid,
       model: model,
       models: models,
       scenarios: scenarios,
       mode: mode,
       scenario: scenario,
       text: "",
       language_preference: :english,
       current_question: nil,
       profile_data: %{}
     )}
  end

  # Fetches the scenario based on the scenario_id
  defp fetch_scenario(scenario_id, instructions_to_append) do
    MicWeb.Scenario.default_scenarios(instructions_to_append)
    |> Enum.find(fn sc -> sc.id == scenario_id end)
  end

  @impl Phoenix.LiveView
  def handle_event("text_interaction", _params, socket) do
    send(self(), {:set_prefers_voice_chat, false})
    language_preference = Mic.Chat.OpenAI.get_language_preference(socket.assigns.openai_pid)

    {message_content, prepended_user_message} =
      case language_preference do
        :english ->
          {"I'll communicate through text, thanks! What is your artist name?", "Text"}

        :spanish ->
          {"Me comunicaré por texto, ¡gracias! ¿Cuál es tu nombre de artista?", "Texto"}

        :portuguese ->
          {"Vou me comunicar por texto, obrigado! Qual é o seu nome artístico?", "Texto"}

        # Default message
        _ ->
          {"I'll communicate through text, thanks! What is your artist name?", "Text"}
      end

    new_message = %Message{
      content: prepended_user_message,
      sender: :user,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    new_message = %Message{
      content: message_content,
      sender: :assistant,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    {:noreply, assign(socket, current_question: :artist_name)}
  end

  def handle_event("voice_interaction", _params, socket) do
    send(self(), {:set_prefers_voice_chat, true})
    language_preference = Mic.Chat.OpenAI.get_language_preference(socket.assigns.openai_pid)

    {message_content, prepended_user_message} =
      case language_preference do
        :english ->
          {"I'll communicate through voice, thanks! What is your artist name?", "Voice"}

        :spanish ->
          {"Me comunicaré por voz, ¡gracias! ¿Cuál es tu nombre de artista?", "Voz"}

        :portuguese ->
          {"Vou me comunicar por voz, obrigado! Qual é o seu nome artístico?", "Voz"}

        # Default message
        _ ->
          {"I'll communicate through voice, thanks! What is your artist name?", "Voice"}
      end

    case Mic.Chat.OpenAI.generate_speech(message_content) do
      {:ok, speech} when is_binary(speech) ->
        Phoenix.PubSub.broadcast(
          Mic.PubSub,
          "audio:topic",
          {:audio_chunk, %{chunk: speech}}
        )

      {:error, reason} ->
        Logger.error("TTS Error: #{inspect(reason)}")
    end

    new_message = %Message{
      content: prepended_user_message,
      sender: :user,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    new_message = %Message{
      content: message_content,
      sender: :assistant,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    {:noreply, assign(socket, current_question: :artist_name)}
  end

  @impl Phoenix.LiveView
  def handle_event("english_interaction", _params, socket) do
    send(self(), {:set_language_preference, :english})

    new_message = %Message{
      content: "English",
      sender: :user,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    new_message = %Message{
      content: "Perfect. Do you want me to communicate with you via text or voice?",
      sender: :assistant,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("spanish_interaction", _params, socket) do
    send(self(), {:set_language_preference, :spanish})

    new_message = %Message{
      content: "Spanish",
      sender: :user,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    new_message = %Message{
      content: "Perfecto. ¿Quieres que me comunique contigo por texto o voz?",
      sender: :assistant,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("portuguese_interaction", _params, socket) do
    send(self(), {:set_language_preference, :portuguese})

    new_message = %Message{
      content: "Portugese",
      sender: :user,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    new_message = %Message{
      content: "Perfeito. Você quer que eu me comunique com você por texto ou voz?",
      sender: :assistant,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    {:noreply, socket}
  end

  def handle_event("initiate_voice_transcription", _params, socket) do
    {:noreply, push_event(socket, "start_recording", %{record: true})}
  end

  def handle_event("stop_voice_transcription", _params, socket) do
    {:noreply, push_event(socket, "stop_recording", %{record: true})}
  end

  @impl true
  def handle_event("transcribe_voice", %{"audio" => audio_data_base64}, socket) do
    # Decode the base64 audio data to its original binary form
    {:ok, audio_data_binary} = Base.decode64(audio_data_base64)

    case Mic.Chat.OpenAI.transcribe_voice(audio_data_binary) do
      {:ok, text} ->
        updated_socket = handle_transcribed_chat_message(text, socket)

        {:noreply, updated_socket}

      {:error, reason} ->
        Logger.error("Transcription Error: #{inspect(reason)}")
        push_event(socket, "transcription_error", %{error: "Voice transcription failed"})
        {:noreply, socket}
    end
  end

  defp handle_transcribed_chat_message(text, socket) do
    # Check if text is not empty and the socket is not disabled before submitting
    if String.length(text) >= 1 do
      # Send the message to the LiveView process to be handled in handle_info/2
      Process.send(self(), {:msg_submit, text}, [])
    end

    # Return just the socket, not {:noreply, socket}
    socket
  end

  defp generate_profile_description(profile_data) do
    query_string =
      profile_data
      |> Map.to_list()
      |> Enum.map(fn {key, value} ->
        value_string =
          case value do
            # Correctly checks if the value is a Date struct
            %Date{} = date -> Date.to_string(date)
            # Handles all other types by converting them to string
            _ -> to_string(value)
          end

        "#{String.upcase(to_string(key))}: #{value_string}"
      end)
      |> Enum.join(". ")

    case Mic.Chat.OpenAI.generate_artist_profile_description(query_string) do
      {:ok, response} ->
        response

      {:error, reason} ->
        Logger.error("Chat Completions Generate Profile Description Error: #{inspect(reason)}")
    end
  end

  defp generate_tailored_content(artist_description, resource_subject) do
    case Mic.Chat.OpenAI.generate_artist_tailored_content(artist_description, resource_subject) do
      {:ok, response} ->
        # return it in the correct Resource object
        # check if Resource already exists for subject, if so update resource content, if not create resource
        %{
          subject: resource_subject,
          # Assuming content is a list of maps
          content: [%{title: "#{resource_subject}", content: response.content}]
        }

      {:error, reason} ->
        Logger.error("Chat Completions Generate Tailored Content Error: #{inspect(reason)}")
    end
  end

  defp generate_valid_dob_struct(text) do
    case Mic.Chat.OpenAI.generate_iso_8601_date_string(text) do
      {:ok, response} ->
        case Date.from_iso8601(response.content) do
          {:ok, date_struct} ->
            date_struct

          {:error, reason} ->
            Logger.error("Chat Completions DOB Struct Error: #{inspect(reason)}")
        end
    end
  end

  def handle_event(ev, params, socket) do
    IO.puts("handle event")
    IO.inspect(ev)
    IO.inspect(params)
    IO.inspect(socket)

    {:noreply, socket}
  end

  # -- sse client

  @spec parse_choices(any) :: String.t()
  defp parse_choices(%{text: content}) do
    content
  end

  defp parse_choices(%{delta: %{content: content}}) do
    content
  end

  defp parse_choices(choices) when is_list(choices) do
    List.first(choices)
    |> parse_choices()
  end

  defp parse_choices(_) do
    ""
  end

  defp split_at_first_punctuation(text, punctuations) do
    case Enum.reduce(punctuations, {nil, nil}, fn punct, acc ->
           if acc == {nil, nil} and String.contains?(text, punct) do
             [first_part | remaining] = String.split(text, punct, parts: 2)
             {first_part <> punct, Enum.join(remaining, punct)}
           else
             acc
           end
         end) do
      {nil, nil} -> {text, ""}
      result -> result
    end
  end

  @impl ExOpenAI.StreamingClient
  def handle_data(%{id: _id, choices: choices}, state) do
    characters = [".", "?"]
    prefers_voice_chat = Mic.Chat.OpenAI.get_prefers_voice_chat(state.assigns.openai_pid)
    streamed_text = parse_choices(choices)

    # Accumulate the streamed text
    new_streaming_message_content = state.assigns.streaming_message.content <> streamed_text

    # TODO: delete unused logic below
    if prefers_voice_chat == true &&
         Enum.any?(characters, &String.contains?(new_streaming_message_content, &1)) do
      {first_sentence, remaining_text} =
        split_at_first_punctuation(new_streaming_message_content, characters)

      streaming_message =
        Map.put(state.assigns.streaming_message, :content, new_streaming_message_content)

      {:noreply, assign(state, streaming_message: streaming_message)}
    else
      streaming_message =
        Map.put(state.assigns.streaming_message, :content, new_streaming_message_content)

      {:noreply, assign(state, streaming_message: streaming_message)}
    end
  end

  @impl ExOpenAI.StreamingClient
  def handle_error(e, state) do
    IO.puts("got error: #{inspect(e)}")
    Process.send(self(), {:set_error, "#{inspect(e)}"}, [])
    Process.send(self(), :stop_loading, [])

    {:noreply, state}
  end

  @impl ExOpenAI.StreamingClient
  def handle_finish(state) do
    # swap streaming message into a real message
    Process.send(
      self(),
      {:commit_streaming_message, state.assigns.streaming_message},
      []
    )

    {:noreply, state}
  end

  # -- sse client

  def handle_info({:set_error, msg}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, msg)
     |> push_event("newmessage", %{})}
  end

  def handle_info(:unset_error, socket) do
    {:noreply,
     socket
     |> clear_flash(:error)
     |> push_event("newmessage", %{})}
  end

  def handle_info({:add_message, msg}, socket) do
    new_id = Enum.count(socket.assigns.messages) + 1
    msg = Map.put(msg, :id, new_id)

    {:noreply,
     socket
     |> assign(%{messages: socket.assigns.messages ++ [msg]})
     |> push_event("newmessage", %{})}
  end

  def handle_info({:commit_streaming_message, msg}, socket) do
    new_id = Enum.count(socket.assigns.messages) + 1
    msg = Map.put(msg, :id, new_id)
    prefers_voice_chat = Mic.Chat.OpenAI.get_prefers_voice_chat(socket.assigns.openai_pid)

    # insert into stateful openai container so we have history
    Mic.Chat.OpenAI.insert_message(socket.assigns.openai_pid, msg)

    if prefers_voice_chat do
      case Mic.Chat.OpenAI.generate_speech(msg.content) do
        {:ok, speech} when is_binary(speech) ->
          Phoenix.PubSub.broadcast(
            Mic.PubSub,
            "audio:topic",
            {:audio_chunk, %{chunk: speech}}
          )

        {:error, reason} ->
          Logger.error("TTS Error: #{inspect(reason)}")
      end
    end

    Process.send(self(), :stop_loading, [])

    {:noreply,
     socket
     |> assign(%{
       messages: socket.assigns.messages ++ [msg],
       streaming_message: %Message{content: "", sender: :assistant, id: -1}
     })
     |> push_event("newmessage", %{})}
  end

  def handle_info({:audio_chunk, %{chunk: base64_audio}}, socket) do
    # Push the audio_chunk event to the client
    {:noreply, push_event(socket, "audio_chunk", %{chunk: base64_audio})}
  end

  def handle_info({:update_messages, msgs}, socket) do
    {:noreply, assign(socket, %{messages: msgs})}
  end

  def handle_info(:stop_loading, socket) do
    if socket.assigns.current_question == :end do
      has_profile =
        try do
          Mic.Artists.get_profile_by_user_id!(socket.assigns.current_user.id)
          # If the function succeeds, return true
          true
        rescue
          Ecto.NoResultsError ->
            # This block executes if no profile is found, returning a default or nil
            Logger.debug("No profile found for user.")
            nil
        end

      if has_profile == nil do
        profile_data = socket.assigns.profile_data
        # Generate ai description
        description = generate_profile_description(profile_data)

        # Generate initial tailored resources for distribution
        # TODO: eventually add more subjects with for loop
        distribution_resource = generate_tailored_content(description.content, :distribution)

        # Update profile_data object and pass that to create_profile
        updated_profile_data = Map.put(profile_data, :artist_ai_description, description.content)

        has_subject_resource =
          try do
            Mic.Artists.get_resource_by_user_id_and_subject!(
              socket.assigns.current_user.id,
              :distribution
            )

            true
          rescue
            Ecto.NoResultsError ->
              # This block executes if no resource is found, returning a default or nil
              Logger.debug("No subject resource found for user.")
              nil
          end

        if has_subject_resource == nil do
          # TODO: eventually need to add line for updating resource when subject already exists
          case Mic.Artists.create_resource(socket.assigns.current_user, distribution_resource) do
            {:ok, _resource} ->
              # Once onboarding questionnare is done, save profile
              case Mic.Artists.create_profile(socket.assigns.current_user, updated_profile_data) do
                {:ok, profile} ->
                  # Handle success, e.g., assign the profile to the socket or redirect to home
                  updated_socket =
                    socket
                    |> assign(:profile, profile)
                    |> assign(:loading, false)

                  # Redirect to the root path
                  {:noreply, push_redirect(updated_socket, to: "/")}

                {:error, changeset} ->
                  # Handle error, e.g., assign the error to the socket for display
                  {:noreply, assign(socket, error: changeset)}
              end

            {:error, changeset} ->
              # Handle error, e.g., assign the error to the socket for display
              {:noreply, assign(socket, error: changeset)}
          end
        end
      end
    else
      {:noreply, assign(socket, %{loading: false})}
    end
  end

  @impl true
  def handle_info({:set_prefers_voice_chat, prefers_voice_chat}, socket) do
    # Update the GenServer state that manages the OpenAI interaction
    Mic.Chat.OpenAI.set_prefers_voice_chat(socket.assigns.openai_pid, prefers_voice_chat)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:set_language_preference, language_preference}, socket) do
    # Update the GenServer state that manages the OpenAI interaction
    Mic.Chat.OpenAI.set_language_preference(socket.assigns.openai_pid, language_preference)

    # Assign the language_preference to the socket's assigns
    {:noreply, assign(socket, :language_preference, language_preference)}
  end

  def handle_info({:msg_submit, text}, socket) do
    self = self()

    model = Map.get(socket.assigns, :model)

    Process.send(
      self,
      {:add_message, %Message{content: text, sender: :user, id: 0}},
      []
    )

    # TODO: this is hacky - maybe make own onboarding liveview where all of this is abstracted there. look at other TODOs in CurrentFixes
    must_ask =
      ". Be friendly, curious and use their artist name to talk to them. You MUST now ask the artist this question: "

    do_not_acknowledge =
      " Do NOT acknowledge that you were told to ask a question, simply ask the question: "

    artist_llm_intro =
      "You will be helping a music artist build their profile by asking them questions I will give you and tell you to ask. Only ask these questions that I give you. Right now, the user is entering what their artist name is. "

    # Extract the profile data from the socket assigns
    profile_data = socket.assigns.profile_data

    # Update the profile data based on the current question
    updated_profile_data =
      case socket.assigns.current_question do
        :artist_name ->
          Map.put(profile_data, :artist_name, text)

        :genre ->
          Map.put(profile_data, :genre, text)

        :influences ->
          Map.put(profile_data, :influences, text)

        # TODO: maybe dont save short_bio under this? save it under :music_beginnings
        # :short_bio ->
        #   Map.put(profile_data, :short_bio, text)

        :aspirations ->
          Map.put(profile_data, :aspirations, text)

        :musical_beginnings ->
          Map.put(profile_data, :musical_beginnings, text)

        :artist_ai_description ->
          Map.put(profile_data, :artist_ai_description, text)

        :spotify_bio ->
          Map.put(profile_data, :spotify_bio, text)

        :music_education ->
          Map.put(profile_data, :music_education, text)

        :instruments_played ->
          Map.put(profile_data, :instruments_played, text)

        :significant_milestones ->
          Map.put(profile_data, :significant_milestones, text)

        :spotify_bio ->
          Map.put(profile_data, :spotify_bio, text)

        :live_performances ->
          Map.put(profile_data, :live_performances, text)

        :country ->
          Map.put(profile_data, :country, text)

        :dob ->
          valid_date_struct = generate_valid_dob_struct(text)
          Map.put(profile_data, :dob, valid_date_struct)

        _ ->
          profile_data
      end

    artist_name = Map.get(updated_profile_data, :artist_name)

    {appended_question, next_question_to_set} =
      case socket.assigns.current_question do
        :artist_name ->
          {must_ask <> do_not_acknowledge <> "What's your music genre, #{artist_name}?", :genre}

        :genre ->
          {must_ask <>
             do_not_acknowledge <>
             "Are there any specific musicians or artists who have inspired or influenced your musical style, #{artist_name}?",
           :influences}

        :influences ->
          {must_ask <>
             do_not_acknowledge <> "When did your passion for music first begin, #{artist_name}?",
           :musical_beginnings}

        :musical_beginnings ->
          {must_ask <>
             do_not_acknowledge <>
             "What are your future goals or aspirations in music, #{artist_name}?", :aspirations}

        :aspirations ->
          {must_ask <>
             do_not_acknowledge <>
             "Did you have any formal training or education in music or are you self-taught, #{artist_name}?",
           :music_education}

        :music_education ->
          {must_ask <>
             do_not_acknowledge <>
             "What instruments do you play, and how did you learn to play them, #{artist_name}?",
           :instruments_played}

        :instruments_played ->
          {must_ask <>
             do_not_acknowledge <>
             "Can you share any significant milestones or achievements in your musical career so far, #{artist_name}?",
           :significant_milestones}

        :significant_milestones ->
          {must_ask <>
             do_not_acknowledge <>
             "If you have a biography in your Spotify page, can you copy and paste it here please #{artist_name}, if not just type no",
           :spotify_bio}

        :spotify_bio ->
          {must_ask <>
             do_not_acknowledge <>
             "Have you ever performed in front of an audience? If yes, what was that experience like, #{artist_name}?",
           :live_performances}

        :live_performances ->
          {must_ask <> do_not_acknowledge <> "Which country are you from, #{artist_name}?",
           :country}

        :country ->
          {must_ask <> do_not_acknowledge <> "What's your date of birth, #{artist_name}?", :dob}

        :dob ->
          {"Please end this interaction by telling saying thank you to #{artist_name} for creating their profile and that they will be routed to the home page shortly.",
           :end}

        # Handle unexpected cases
        _ ->
          {"", nil}
      end

    # If it's artist_name, need to give the LLM context about what is going on since its the first one
    text_to_pass =
      if socket.assigns.current_question == :artist_name do
        artist_llm_intro <> text
      else
        text
      end

    # Need to respect user language preference
    language_to_speak =
      case socket.assigns.language_preference do
        :spanish -> "Remember to talk to the user in Spanish. "
        :portuguese -> "Remember to talk to the user in Portugese. "
        _ -> "Remember to talk to the user in English. "
      end

    spawn(fn ->
      case Mic.Chat.OpenAI.send(
             socket.assigns.openai_pid,
             language_to_speak <> text_to_pass <> appended_question,
             model,
             self
           ) do
        {:ok, result} when is_reference(result) ->
          nil

        {:ok, result} ->
          Process.send(self, {:add_message, result}, [])
          Process.send(self, :stop_loading, [])

        {:error, e} ->
          IO.puts("error")
          IO.inspect(e)

          Process.send(self, {:set_error, "#{inspect(e)}"}, [])
          Process.send(self, :stop_loading, [])
      end
    end)

    {:noreply,
     socket
     |> assign(:loading, true)
     |> assign(:current_question, next_question_to_set)
     |> assign(:profile_data, updated_profile_data)
     |> clear_flash()}
  end
end
