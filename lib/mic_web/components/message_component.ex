defmodule MicWeb.MessageComponent do
  use MicWeb, :live_component

  defp style(:assistant), do: "chat-start "
  defp style(_), do: "chat-end"

  defp bubble_style(:assistant), do: ""
  defp bubble_style(_), do: "bg-[#FFF] text-[#333] dark:text-slate-400 dark:bg-gray-700"

  defp process_markdown(markdown) do
    # add list style
    add_list_disc_class = &Earmark.AstTools.merge_atts_in_node(&1, class: "list-disc ml-4")
    add_rounded_class = &Earmark.AstTools.merge_atts_in_node(&1, class: "rounded")

    tsp =
      Earmark.TagSpecificProcessors.new([
        {"ul", add_list_disc_class},
        {"ol", add_list_disc_class},
        {"code", add_rounded_class}
      ])

    m = Earmark.Options.make_options!(registered_processors: [tsp])

    Earmark.as_html!(markdown, m)
  end

  defp render_user_avatar(%{sender: :user} = assigns) do
    ~H"""
    <div class="w-[30px] flex flex-col relative items-end">
      <div
        style="background-color: rgb(16, 163, 127);"
        class="relative h-[30px] w-[30px] p-1 rounded-sm text-white flex items-center justify-center"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="lucide lucide-circle-user-round"
        >
          <path d="M18 20a6 6 0 0 0-12 0" /><circle cx="12" cy="10" r="4" /><circle
            cx="12"
            cy="12"
            r="10"
          />
        </svg>
      </div>
    </div>
    """
  end

  defp render_assistant_avatar(%{sender: :assistant} = assigns) do
    ~H"""
    <div class="w-[30px] flex flex-col relative items-end">
      <div
        style="background-color: rgb(16, 163, 127);"
        class="relative h-[30px] w-[30px] p-1 rounded-sm text-white flex items-center justify-center"
      >
        <svg
          :if={@assistant_type == "analyze-contract"}
          viewBox="0 0 24 24"
          aria-hidden="true"
          class="h-6 w-6"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="lucide lucide-scroll-text"
          >
            <path d="M8 21h12a2 2 0 0 0 2-2v-2H10v2a2 2 0 1 1-4 0V5a2 2 0 1 0-4 0v3h4" /><path d="M19 17V5a2 2 0 0 0-2-2H4" /><path d="M15 8h-5" /><path d="M15 12h-5" />
          </svg>
        </svg>
        <svg
          :if={@assistant_type == "mental-wellness"}
          viewBox="0 0 24 24"
          aria-hidden="true"
          class="h-6 w-6"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="lucide lucide-message-circle-heart"
          >
            <path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z" /><path d="M15.8 9.2a2.5 2.5 0 0 0-3.5 0l-.3.4-.35-.3a2.42 2.42 0 1 0-3.2 3.6l3.6 3.5 3.6-3.5c1.2-1.2 1.1-2.7.2-3.7" />
          </svg>
        </svg>
        <svg
          :if={@assistant_type == "distribution-guru"}
          viewBox="0 0 24 24"
          aria-hidden="true"
          class="h-6 w-6"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="lucide lucide-radio"
          >
            <path d="M4.9 19.1C1 15.2 1 8.8 4.9 4.9" /><path d="M7.8 16.2c-2.3-2.3-2.3-6.1 0-8.5" /><circle
              cx="12"
              cy="12"
              r="2"
            /><path d="M16.2 7.8c2.3 2.3 2.3 6.1 0 8.5" /><path d="M19.1 4.9C23 8.8 23 15.1 19.1 19" />
          </svg>
        </svg>
        <svg
          :if={
            @assistant_type != "analyze-contract" and @assistant_type != "mental-wellness" and
              @assistant_type != "distribution-guru"
          }
          viewBox="0 0 24 24"
          aria-hidden="true"
          class="h-6 w-6"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="lucide lucide-sparkle"
          >
            <path d="m12 3-1.9 5.8a2 2 0 0 1-1.287 1.288L3 12l5.8 1.9a2 2 0 0 1 1.288 1.287L12 21l1.9-5.8a2 2 0 0 1 1.287-1.288L21 12l-5.8-1.9a2 2 0 0 1-1.288-1.287Z" />
          </svg>
        </svg>
      </div>
    </div>
    """
  end

  attr :message, :string, required: true
  attr :sender, :string, required: true

  # defp parse_content(content), do: Earmark.as_html!(content)
  defp parse_content(content), do: content

  def render(assigns) do
    assigns =
      assigns
      |> assign(:parsed_content, process_markdown(assigns.message))

    ~H"""
    <div class={"chat #{style(@sender)}"}>
      <div class="chat-image avatar">
        <div class="w-10">
          <%= if @sender == :user do %>
            <%= render_user_avatar(assigns) %>
          <% else %>
            <%= render_assistant_avatar(assigns) %>
          <% end %>
        </div>
      </div>
      <div class={"chat-bubble shadow-[0_0_10px_rgba(0,0,0,0.10)] dark:shadow-[0_0_15px_rgba(0,0,0,0.10)] space-y-4 p-4 mb-4 rounded  w-full #{bubble_style(@sender)}"}>
        <%= raw(@parsed_content) %>
        <%= if @id === 0 && @assistant_type === nil do %>
          <button
            phx-click="text_interaction"
            class="px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-indigo-600 shadow-sm hover:bg-indigo-700"
          >
            Text
          </button>
          <button
            phx-click="voice_interaction"
            class="px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-indigo-600 shadow-sm hover:bg-indigo-700"
          >
            Voice
          </button>
        <% end %>
      </div>
    </div>
    """
  end
end
