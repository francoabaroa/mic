defmodule MicWeb.ChatLive.Index do
  use MicWeb, :live_view
  alias MicWeb.Message
  alias MicWeb.LoadingIndicatorComponent
  alias MicWeb.AlertComponent
  use ExOpenAI.StreamingClient

  @type state :: %{messages: [Message.t()], loading: boolean(), streaming_message: Message.t()}

  @spec initial_messages(String.t() | nil) :: [Message.t()]
  defp initial_messages(nil) do
    [%Message{content: "Hi there! How can I assist you today?", sender: :assistant, id: 0}]
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

  def mount(params, session, socket) do
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
       openai_pid: openai_pid,
       model: model,
       models: models,
       scenarios: scenarios,
       mode: mode,
       scenario: scenario
     )}
  end

  # Fetches the scenario based on the scenario_id
  defp fetch_scenario(scenario_id) do
    MicWeb.Scenario.default_scenarios()
    |> Enum.find(fn sc -> sc.id == scenario_id end)
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

  def handle_data(%{id: _id, choices: choices}, state) do
    streamed_text = parse_choices(choices)

    streaming_message =
      state.assigns.streaming_message
      |> Map.put(:content, state.assigns.streaming_message.content <> streamed_text)

    {:noreply,
     state
     |> assign(streaming_message: streaming_message)}
  end

  def handle_error(e, state) do
    IO.puts("got error: #{inspect(e)}")
    Process.send(self(), {:set_error, "#{inspect(e)}"}, [])
    Process.send(self(), :stop_loading, [])

    {:noreply, state}
  end

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

    # insert into stateful openai container so we have history
    Mic.Chat.OpenAI.insert_message(socket.assigns.openai_pid, msg)

    Process.send(self(), :stop_loading, [])

    {:noreply,
     socket
     |> assign(%{
       messages: socket.assigns.messages ++ [msg],
       streaming_message: %Message{content: "", sender: :assistant, id: -1}
     })
     |> push_event("newmessage", %{})}
  end

  def handle_info({:update_messages, msgs}, socket) do
    {:noreply, assign(socket, %{messages: msgs})}
  end

  def handle_info(:stop_loading, socket) do
    {:noreply, assign(socket, %{loading: false})}
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
