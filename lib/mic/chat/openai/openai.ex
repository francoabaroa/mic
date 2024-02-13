defmodule Mic.Chat.OpenAI do
  use GenServer
  alias MicWeb.Message
  require Logger

  @type init_settings :: %{messages: [], keep_context: boolean()}
  @type state :: %{messages: [], settings: init_settings()}

  @impl true
  @spec init(state) :: {:ok, any}
  def init(opts) do
    {:ok, opts}
  end

  defp new_msg(m) do
    %ExOpenAI.Components.ChatCompletionRequestUserMessage{
      content: m,
      role: :user
    }
  end

  @spec role(String.t()) :: atom()
  defp role(r) when is_binary(r), do: String.to_atom(r)
  @spec role(atom()) :: atom()
  defp role(r) when is_atom(r), do: r

  @spec to_domain(ExOpenAI.Components.ChatCompletionResponseMessage.t()) :: Message.t()
  defp to_domain(msg) do
    %Message{
      content: msg.content,
      sender: role(msg.role),
      id: 0
    }
  end

  @spec from_domain(Message.t()) ::
          ExOpenAI.Components.ChatCompletionRequestUserMessage.t()
          | ExOpenAI.Components.ChatCompletionRequestAssistantMessage.t()
          | ExOpenAI.Components.ChatCompletionRequestSystemMessage.t()
  defp from_domain(msg) do
    case msg.sender do
      :user ->
        %ExOpenAI.Components.ChatCompletionRequestUserMessage{
          content: msg.content,
          role: :user
        }

      :assistant ->
        %ExOpenAI.Components.ChatCompletionRequestAssistantMessage{
          content: msg.content,
          role: :assistant
        }

      :system ->
        %ExOpenAI.Components.ChatCompletionRequestSystemMessage{
          content: msg.content,
          role: :system
        }

      _ ->
        raise ArgumentError, message: "Invalid sender role: #{inspect(msg.sender)}"
    end
  end

  @spec handle_state_update(state, state) :: state
  defp handle_state_update(state, new_state) do
    case Map.get(state, :keep_context, true) do
      true ->
        new_state

      false ->
        state
    end
  end

  @impl true
  def handle_call({:insertmsg, m}, _from, state) do
    new_msg = from_domain(m)

    {:reply, new_msg,
     handle_state_update(state, state |> Map.put(:messages, state.messages ++ [new_msg]))}
  end

  @impl true
  def handle_call(:get_prefers_voice_chat, _from, state) do
    {:reply, Map.get(state, :prefers_voice_chat, false), state}
  end

  @impl true
  def handle_call(:get_language_preference, _from, state) do
    {:reply, Map.get(state, :language_preference, false), state}
  end

  @impl true
  def handle_call({:msg, m, streamer_pid, "davinci"} = params, from, state) do
    Logger.info("completing with davinci")

    with msgs <- state.messages ++ [new_msg(m)] do
      system_msgs =
        msgs
        |> Enum.filter(fn msg -> msg.role == :system end)
        |> Enum.map(fn msg -> msg.content end)
        |> Enum.join("\n")

      system_prompt =
        case String.length(system_msgs) do
          0 -> ""
          _ -> "Here are additional instructions that 'assistant' HAS TO follow: #{system_msgs}"
        end

      # TODO: Need to edit?
      default_prompt =
        "This is a conversation between the 'user' and a helpful AI assistant called 'assistant'. Only those 2 users are in the conversation. 'assistant' is also very knowledgeable in programming, and provides long replies that go into extensive detail, in a conversational matter. 'assistant' uses markdown in replies.\nThe conversation starts after '-----'\n#{system_prompt}\n-----\n\n"

      default_prompt_tokens = Mic.Chat.Tokenizer.count_tokens!(default_prompt)

      prompt =
        msgs
        |> Enum.filter(fn msg -> msg.role != :system end)
        |> Enum.map(fn msg -> "#{Atom.to_string(msg.role)}: #{msg.content}" end)
        # take the newest messages backwards until hitting the limit
        |> Enum.reverse()
        |> Enum.reduce_while("", fn x, acc ->
          with summarized <- x <> "\n\n" <> acc do
            if Mic.Chat.Tokenizer.count_tokens!(summarized) + default_prompt_tokens >= 2200 do
              {:halt, acc}
            else
              {:cont, summarized}
            end
          end
        end)

      prompt = default_prompt <> prompt <> "\n\nassistant:"
      Logger.debug(prompt)

      Logger.debug(
        "prompt size: #{String.length(prompt)} -- #{Mic.Chat.Tokenizer.count_tokens!(prompt)} tokens"
      )

      case ExOpenAI.Completions.create_completion("text-davinci-003",
             prompt: prompt,
             temperature: 0.7,
             stream: true,
             stream_to: streamer_pid,
             max_tokens: 2048
           ) do
        {:ok, res} when is_reference(res) ->
          {:reply, {:ok, res}, handle_state_update(state, state |> Map.put(:messages, msgs))}

        {:ok, res} ->
          first = List.first(res.choices)
          combined = msgs ++ [first.message]

          {:reply, {:ok, to_domain(first.message)},
           handle_state_update(state, state |> Map.put(:messages, combined))}

        {:error, %{"error" => %{"message" => msg}}} ->
          case(
            # if this specific error, retry
            String.contains?(
              msg,
              "The server had an error while processing your request. Sorry about that!"
            )
          ) do
            true ->
              handle_call(params, from, state)

            false ->
              {:reply, {:error, msg}, state}
          end

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  @spec handle_call({:msg, String.t(), pid(), String.t()}, any(), state) ::
          {:reply, {:ok, ExOpenAI.Components.ChatCompletionResponseMessage.t()} | {:error, any()},
           state}
          | {:reply, {:ok, reference()}, state}
  def handle_call({:msg, m, streamer_pid, model} = params, from, state) do
    Logger.info("completing with #{model}")

    with msgs <- state.messages ++ [new_msg(m)] do
      # strip out things that are over the token limit
      # TODO: need to update this - token limit check
      filtered_msgs =
        msgs
        |> Enum.reverse()
        |> Enum.reduce_while(%{msgs: [], tokens: 0}, fn msg, acc ->
          with msg_tokens <- Mic.Chat.Tokenizer.count_tokens!(msg.content) do
            if msg_tokens + acc.tokens > 4000 do
              {:halt, acc}
            else
              {:cont, %{msgs: acc.msgs ++ [msg], tokens: acc.tokens + msg_tokens}}
            end
          end
        end)

      Logger.debug(filtered_msgs |> Enum.reverse())
      Logger.debug("prompt size: #{filtered_msgs.tokens} tokens")

      filtered_msgs
      |> Map.get(:msgs)
      |> Enum.reverse()
      |> ExOpenAI.Chat.create_chat_completion(model,
        temperature: 0.8,
        stream: true,
        stream_to: streamer_pid
      )
      |> case do
        # is reference == streaming
        {:ok, res} when is_reference(res) ->
          {:reply, {:ok, res}, handle_state_update(state, state |> Map.put(:messages, msgs))}

        # normal res = no streaming
        {:ok, res} ->
          first = List.first(res.choices)
          combined = msgs ++ [first.message]

          {:reply, {:ok, to_domain(first.message)},
           handle_state_update(state, state |> Map.put(:messages, combined))}

        {:error, %{"error" => %{"message" => msg}}} ->
          case(
            # if this specific error, retry
            String.contains?(
              msg,
              "The server had an error while processing your request. Sorry about that!"
            )
          ) do
            # if that specific error, recurse and try again
            true ->
              handle_call(params, from, state)

            false ->
              {:reply, {:error, msg}, state}
          end

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end

  def transcribe_voice(audio_content) do
    # TEMP: Temporary filename
    file_path = "/Users/francoabaroa/Desktop/Hack_Reactor/Repos/career/mic/temp_audio.mp3"

    # Write audio content to a file
    File.write!(file_path, audio_content)

    # Read the content back from the file
    case File.read(file_path) do
      {:ok, file_content} ->
        case ExOpenAI.Audio.create_transcription(
               {"temp_audio.mp3", file_content},
               "whisper-1"
             ) do
          {:ok, %ExOpenAI.Components.CreateTranscriptionResponse{text: transcription_text}} ->
            Logger.debug("transcription_text: #{inspect(transcription_text)}")
            # If the transcription is successful, you get the transcribed text here
            # TODO: delete written file
            File.rm(file_path)
            {:ok, transcription_text}

          {:error, reason} ->
            Logger.error("Error in create_transcription request: #{inspect(reason)}")
            {:error, reason}

          _ ->
            Logger.error("Unexpected return value from ExOpenAI.Audio.create_transcription")
            {:error, :unexpected_return_value}
        end

      {:error, read_error} ->
        # Clean up and error handling
        File.rm(file_path)
        Logger.error("Error reading file: #{inspect(read_error)}")
        {:error, read_error}
    end
  end

  def generate_speech(input_text) do
    case ExOpenAI.Audio.create_speech(input_text, :"tts-1", :onyx, stream: true) do
      {:ok, audio_data} when is_binary(audio_data) ->
        base64_audio = Base.encode64(audio_data)

        {:ok, base64_audio}

      {:error, reason} ->
        Logger.error("Error in create_speech request: #{inspect(reason)}")
        {:error, reason}

      _ ->
        Logger.error("Unexpected return value from ExOpenAI.Audio.create_speech")
        {:error, :unexpected_return_value}
    end
  end

  def set_prefers_voice_chat(pid, prefers_voice_chat) do
    GenServer.cast(pid, {:set_prefers_voice_chat, prefers_voice_chat})
  end

  @impl true
  def handle_cast({:set_prefers_voice_chat, prefers_voice_chat}, state) do
    new_state = Map.put(state, :prefers_voice_chat, prefers_voice_chat)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:set_language_preference, language_preference}, state) do
    new_state = Map.put(state, :language_preference, language_preference)
    {:noreply, new_state}
  end

  def set_language_preference(pid, language_preference) do
    GenServer.cast(pid, {:set_language_preference, language_preference})
  end

  def get_prefers_voice_chat(pid) do
    GenServer.call(pid, :get_prefers_voice_chat)
  end

  def get_language_preference(pid) do
    GenServer.call(pid, :get_language_preference)
  end

  @spec start_link(init_settings) :: {:error, any} | {:ok, pid}
  def start_link(init_settings) do
    Logger.debug("starting OpenAI: #{inspect(init_settings)}")
    msgs = Map.get(init_settings, :messages, []) |> Enum.map(&from_domain/1)

    GenServer.start_link(__MODULE__, %{messages: msgs, settings: init_settings}, [])
  end

  def send(pid, msg, model, streamer_pid) do
    GenServer.call(pid, {:msg, msg, streamer_pid, model}, 100_000)
  end

  def insert_message(pid, msg) do
    GenServer.call(pid, {:insertmsg, msg}, 100_000)
  end
end
