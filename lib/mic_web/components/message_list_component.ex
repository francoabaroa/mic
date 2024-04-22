defmodule MicWeb.MessageListComponent do
  alias MicWeb.MessageComponent
  use MicWeb, :live_component

  attr :messages, :list, required: true
  attr :language_preference, :atom, required: true

  def render(assigns) do
    %{language_preference: language_preference, assistant_scenario_id: assistant_scenario_id} =
      assigns

    ~H"""
    <div class="my-4 relative h-full w-full transition-width flex flex-col items-stretch flex-1">
      <%= for message <- @messages |> Enum.filter(& &1.content != "") do %>
        <.live_component
          module={MessageComponent}
          id={message.id}
          message={message.content}
          sender={message.sender}
          assistant_scenario_id={assistant_scenario_id}
          language_preference={language_preference}
        />
      <% end %>
    </div>
    """
  end
end
