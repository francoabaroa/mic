defmodule MicWeb.MessageComponent do
  use MicWeb, :live_component

  defp style(:assistant), do: "justify-start"
  defp style(_), do: "justify-end"

  defp bubble_style(:assistant), do: "bg-white bg-opacity-10 text-white"
  defp bubble_style(_), do: "bg-[#f5f5f5] text-indigo-900"

  defp process_markdown(markdown) do
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
    <div class="w-8 h-8 rounded-full bg-[#f5f5f5] flex items-center justify-center text-indigo-900">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="h-5 w-5"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M18 20a6 6 0 0 0-12 0" /><circle cx="12" cy="10" r="4" /><circle
          cx="12"
          cy="12"
          r="10"
        />
      </svg>
    </div>
    """
  end

  defp render_assistant_avatar(
         %{sender: :assistant, assistant_scenario_id: assistant_scenario_id} = assigns
       ) do
    assigns = assign(assigns, :assistant_scenario_id, assistant_scenario_id)

    ~H"""
    <div class="w-8 h-8 rounded-full bg-indigo-600 flex items-center justify-center text-white">
      <%= if @assistant_scenario_id == "analyze-contract" do %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M8 21h12a2 2 0 0 0 2-2v-2H10v2a2 2 0 1 1-4 0V5a2 2 0 1 0-4 0v3h4" /><path d="M19 17V5a2 2 0 0 0-2-2H4" /><path d="M15 8h-5" /><path d="M15 12h-5" />
        </svg>
      <% end %>
      <%= if @assistant_scenario_id == "mental-wellness" do %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z" /><path d="M15.8 9.2a2.5 2.5 0 0 0-3.5 0l-.3.4-.35-.3a2.42 2.42 0 1 0-3.2 3.6l3.6 3.5 3.6-3.5c1.2-1.2 1.1-2.7.2-3.7" />
        </svg>
      <% end %>
      <%= if @assistant_scenario_id == "distribution-guru" do %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M4.9 19.1C1 15.2 1 8.8 4.9 4.9" /><path d="M7.8 16.2c-2.3-2.3-2.3-6.1 0-8.5" /><circle
            cx="12"
            cy="12"
            r="2"
          /><path d="M16.2 7.8c2.3 2.3 2.3 6.1 0 8.5" /><path d="M19.1 4.9C23 8.8 23 15.1 19.1 19" />
        </svg>
      <% end %>
      <%= if @assistant_scenario_id == "production-expert" do %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <rect width="20" height="16" x="2" y="4" rx="2" /><path d="M6 8h4" /><path d="M14 8h.01" /><path d="M18 8h.01" /><path d="M2 12h20" /><path d="M6 12v4" /><path d="M10 12v4" /><path d="M14 12v4" /><path d="M18 12v4" />
        </svg>
      <% end %>
      <%= if @assistant_scenario_id == "finance-tips" do %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1" /><path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4" />
        </svg>
      <% end %>
      <%= if @assistant_scenario_id not in ["analyze-contract", "mental-wellness", "distribution-guru", "production-expert", "finance-tips"] do %>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="m12 3-1.9 5.8a2 2 0 0 1-1.287 1.288L3 12l5.8 1.9a2 2 0 0 1 1.288 1.287L12 21l1.9-5.8a2 2 0 0 1 1.287-1.288L21 12l-5.8-1.9a2 2 0 0 1-1.288-1.287Z" />
        </svg>
      <% end %>
    </div>
    """
  end

  attr :message, :string, required: true
  attr :sender, :string, required: true

  # defp parse_content(content), do: Earmark.as_html!(content)
  defp parse_content(content), do: content

  def render(assigns) do
    # TODO: fix this to use @ eventually
    language_preference = Map.get(assigns, :language_preference, :english)
    message_to_check = Map.get(assigns, :message, "")
    assistant_scenario_id = Map.get(assigns, :assistant_scenario_id, nil)
    id = Map.get(assigns, :id, nil)

    {text_button, voice_button} =
      case language_preference do
        :english -> {"Text", "Voice"}
        :spanish -> {"Texto", "Voz"}
        :portuguese -> {"Texto", "Voz"}
        _ -> {"Text", "Voice"}
      end

    # TODO: change this to use enum or something
    should_show_text_voice_buttons =
      if message_to_check == "Perfect. Do you want me to communicate with you via text or voice?" or
           message_to_check == "Perfecto. ¿Quieres que me comunique contigo por texto o voz?" or
           message_to_check ==
             "Perfeito. Você quer que eu me comunique com você por texto ou voz?" do
        true
      else
        false
      end

    assigns =
      assigns
      |> assign(:parsed_content, process_markdown(assigns.message))
      |> assign(:should_show_text_voice_buttons, should_show_text_voice_buttons)
      |> assign(:language_preference, language_preference)
      |> assign(:message_to_check, message_to_check)
      |> assign(:assistant_scenario_id, assistant_scenario_id)
      |> assign(:id, id)
      |> assign(:text_button, text_button)
      |> assign(:voice_button, voice_button)

    ~H"""
    <div class="message-component">
      <div class={"flex #{style(@sender)} items-end"}>
        <%= if @sender == :assistant do %>
          <div class="flex-shrink-0 mr-2 mb-1">
            <%= render_assistant_avatar(assigns) %>
          </div>
        <% end %>
        <div class={"flex flex-col space-y-2 text-sm max-w-xs mx-2 #{if @sender == :user, do: "items-end", else: "items-start"}"}>
          <div>
            <div class={"px-4 py-2 rounded-lg #{bubble_style(@sender)}"}>
              <%= raw(@parsed_content) %>
            </div>
          </div>
        </div>
        <%= if @sender == :user do %>
          <div class="flex-shrink-0 ml-2 mb-1">
            <%= render_user_avatar(assigns) %>
          </div>
        <% end %>
      </div>
      <%= if @id === 0 && (@assistant_scenario_id in [nil, false, ""]) do %>
        <div class="flex justify-center space-x-2 mt-4">
          <button
            phx-click="english_interaction"
            class="px-4 py-2 bg-yellow-400 text-indigo-900 rounded-full font-medium hover:bg-yellow-300 transition-colors duration-200"
          >
            English
          </button>
          <button
            phx-click="spanish_interaction"
            class="px-4 py-2 bg-yellow-400 text-indigo-900 rounded-full font-medium hover:bg-yellow-300 transition-colors duration-200"
          >
            Spanish
          </button>
          <button
            phx-click="portuguese_interaction"
            class="px-4 py-2 bg-yellow-400 text-indigo-900 rounded-full font-medium hover:bg-yellow-300 transition-colors duration-200"
          >
            Portuguese
          </button>
        </div>
      <% end %>
      <%= if @should_show_text_voice_buttons && (@assistant_scenario_id in [nil, false, ""]) do %>
        <div class="flex justify-center space-x-2 mt-4">
          <button
            phx-click="text_interaction"
            class="px-4 py-2 bg-yellow-400 text-indigo-900 rounded-full font-medium hover:bg-yellow-300 transition-colors duration-200"
          >
            <%= @text_button %>
          </button>
          <button
            phx-click="voice_interaction"
            class="px-4 py-2 bg-yellow-400 text-indigo-900 rounded-full font-medium hover:bg-yellow-300 transition-colors duration-200"
          >
            <%= @voice_button %>
          </button>
        </div>
      <% end %>
    </div>
    """
  end
end
