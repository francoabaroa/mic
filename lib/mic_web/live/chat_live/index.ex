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
    scenarios = MicWeb.Scenario.default_scenarios()

    # Determine the mode based on the presence of a scenario_id in the params
    mode = if scenario_id = Map.get(params, "scenario_id"), do: :scenario, else: :chat

    # Fetch the scenario if in scenario mode
    scenario = if mode == :scenario, do: fetch_scenario(scenario_id), else: nil
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
       language_preference: :english
     )}
  end

  # Fetches the scenario based on the scenario_id
  defp fetch_scenario(scenario_id) do
    MicWeb.Scenario.default_scenarios()
    |> Enum.find(fn sc -> sc.id == scenario_id end)
  end

  @impl Phoenix.LiveView
  def handle_event("text_interaction", _params, socket) do
    send(self(), {:set_prefers_voice_chat, false})
    language_preference = Mic.Chat.OpenAI.get_language_preference(socket.assigns.openai_pid)

    message_content =
      case language_preference do
        :english -> "I'll communicate through text, thanks! What is your artist name?"
        :spanish -> "Me comunicaré por texto, ¡gracias! ¿Cuál es tu nombre de artista?"
        :portuguese -> "Vou me comunicar por texto, obrigado! Qual é o seu nome artístico?"
        # Default message
        _ -> "I'll communicate through text, thanks! What is your artist name?"
      end

    new_message = %Message{
      content: message_content,
      sender: :assistant,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    {:noreply, socket}
  end

  def handle_event("voice_interaction", _params, socket) do
    send(self(), {:set_prefers_voice_chat, true})
    language_preference = Mic.Chat.OpenAI.get_language_preference(socket.assigns.openai_pid)

    message_content =
      case language_preference do
        :english ->
          "I'll communicate through voice, thanks! What is your artist name?"

        :spanish ->
          "Me comunicaré por voz, ¡gracias! ¿Cuál es tu nombre de artista?"

        :portuguese ->
          "Vou me comunicar por voz, obrigado! Qual é o seu nome artístico?"

        # Default message
        _ ->
          "I'll communicate through voice after this message, thanks! What is your artist name?"
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
      content: message_content,
      sender: :assistant,
      # The ID will be updated in handle_info
      id: 0
    }

    send(self(), {:add_message, new_message})

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("english_interaction", _params, socket) do
    send(self(), {:set_language_preference, :english})

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
    {:noreply, assign(socket, %{loading: false})}
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

    spawn(fn ->
      case Mic.Chat.OpenAI.send(socket.assigns.openai_pid, text, model, self) do
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

    {:noreply, socket |> assign(:loading, true) |> clear_flash()}
  end
end
