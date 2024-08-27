defmodule MicWeb.OnboardingLive.MessageHandler do
  use ExOpenAI.StreamingClient
  require Logger
  alias MicWeb.Message

  def add_message(socket, msg) do
    new_id = Enum.count(socket.assigns.messages) + 1
    msg = Map.put(msg, :id, new_id)
    {:ok, %{messages: socket.assigns.messages ++ [msg], event: "newmessage", params: %{}}}
  end

  def commit_streaming_message(socket, msg) do
    new_id = Enum.count(socket.assigns.messages) + 1
    msg = Map.put(msg, :id, new_id)
    prefers_voice_chat = Mic.Chat.OpenAI.get_prefers_voice_chat(socket.assigns.openai_pid)

    if prefers_voice_chat do
      case Mic.Chat.OpenAI.generate_speech(msg.content) do
        {:ok, speech} when is_binary(speech) ->
          send(self(), {:audio_chunk, %{chunk: speech, socket_id: socket.id}})

        {:error, reason} ->
          Logger.error("TTS Error: #{inspect(reason)}")
      end
    end

    Process.send(self(), :stop_loading, [])

    {:ok,
     %{
       messages: socket.assigns.messages ++ [msg],
       streaming_message: %Message{content: "", sender: :assistant, id: -1},
       event: "newmessage",
       params: %{}
     }}
  end

  def send_audio_chunk(base64_audio, socket_id) do
    {:ok, %{event: "audio_chunk", params: %{chunk: base64_audio, to: socket_id}}}
  end

  def update_messages(msgs) do
    {:ok, %{messages: msgs}}
  end

  @impl ExOpenAI.StreamingClient
  def handle_data(%{id: _id, choices: choices}, state) do
    characters = [".", "?"]
    prefers_voice_chat = Mic.Chat.OpenAI.get_prefers_voice_chat(state.assigns.openai_pid)
    streamed_text = parse_choices(choices)

    new_streaming_message_content = state.assigns.streaming_message.content <> streamed_text

    streaming_message =
      Map.put(state.assigns.streaming_message, :content, new_streaming_message_content)

    if prefers_voice_chat == true &&
         Enum.any?(characters, &String.contains?(new_streaming_message_content, &1)) do
      {first_sentence, _remaining_text} =
        split_at_first_punctuation(new_streaming_message_content, characters)

      # You might want to handle the audio generation here or send a message to do so
    end

    {:noreply, %{state | assigns: %{state.assigns | streaming_message: streaming_message}}}
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
    Process.send(
      self(),
      {:commit_streaming_message, state.assigns.streaming_message},
      []
    )

    {:noreply, state}
  end

  # Helper functions for streaming
  defp parse_choices(%{text: content}), do: content
  defp parse_choices(%{delta: %{content: content}}), do: content
  defp parse_choices([choice | _]), do: parse_choices(choice)
  defp parse_choices(_), do: ""

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
end
