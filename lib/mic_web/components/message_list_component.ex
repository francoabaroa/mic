defmodule MicWeb.MessageListComponent do
  alias MicWeb.MessageComponent
  use MicWeb, :live_component

  attr :messages, :list, required: true
  attr :language_preference, :atom, required: true
  attr :assistant_scenario_id, :string, default: nil

  def render(assigns) do
    ~H"""
    <div class="space-y-4 p-">
      <%= for message <- @messages |> Enum.filter(& &1.content != "") do %>
        <.live_component
          module={MessageComponent}
          id={message.id}
          message={message.content}
          sender={message.sender}
          assistant_scenario_id={@assistant_scenario_id}
          language_preference={@language_preference}
        />
      <% end %>
    </div>
    """
  end
end
