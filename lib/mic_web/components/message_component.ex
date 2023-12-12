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
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class="w-6 h-6"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z"
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
          <svg viewBox="0 0 24 24" aria-hidden="true" class="h-6 w-6">
            <path
              fill-rule="evenodd"
              clip-rule="evenodd"
              d="M27,31.36H8c-0.199,0-0.36-0.161-0.36-0.36v-1.64H6c-0.199,0-0.36-0.161-0.36-0.36v-1.64H5
    c-0.199,0-0.36-0.161-0.36-0.36V3c0-0.199,0.161-0.36,0.36-0.36h4.64V2c0-0.199,0.161-0.36,0.36-0.36h1.64V1
    c0-0.199,0.161-0.36,0.36-0.36h4c0.199,0,0.36,0.161,0.36,0.36v0.64H18c0.199,0,0.36,0.161,0.36,0.36v0.64H23
    c0.199,0,0.36,0.161,0.36,0.36v1.64H25c0.199,0,0.36,0.161,0.36,0.36v1.64H27c0.199,0,0.36,0.161,0.36,0.36v24
    C27.36,31.199,27.199,31.36,27,31.36z M8.36,30.64h18.28V7.36h-1.28V29c0,0.199-0.161,0.36-0.36,0.36H8.36V30.64z M6.36,28.64h18.28
    V5.36h-1.28V27c0,0.199-0.161,0.36-0.36,0.36H6.36V28.64z M5.36,26.64h17.28V3.36h-4.28V4c0,0.199-0.161,0.36-0.36,0.36h-8
    C9.801,4.36,9.64,4.199,9.64,4V3.36H5.36V26.64z M10.36,3.64h7.28V2.36H16c-0.199,0-0.36-0.161-0.36-0.36V1.36h-3.28V2
    c0,0.199-0.161,0.36-0.36,0.36h-1.64C10.36,2.36,10.36,3.64,10.36,3.64z M20.5,21.36h-13v-0.72h13V21.36z M20.5,17.36h-13v-0.72h13
    V17.36z M20.5,13.36h-13v-0.72h13V13.36z M20.5,9.36h-13V8.64h13V9.36z"
              fill="currentColor"
            />
          </svg>
        </svg>
        <svg
          :if={@assistant_type == "mental-wellness"}
          viewBox="0 0 24 24"
          aria-hidden="true"
          class="h-6 w-6"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true" class="h-6 w-6">
            <path
              fill-rule="evenodd"
              clip-rule="evenodd"
              d="M11 2c4.068 0 7.426 3.036 7.934 6.965l2.25 3.539c.148.233.118.58-.225.728L19 14.07V17c0 1.105-.895 2-2 2h-1.999L15 22H6v-3.694c0-1.18-.436-2.297-1.244-3.305C3.657 13.631 3 11.892 3 10c0-4.418 3.582-8 8-8zm0 2c-3.314 0-6 2.686-6 6 0 1.385.468 2.693 1.316 3.75C7.41 15.114 8 16.667 8 18.306V20h5l.002-3H17v-4.248l1.55-.664-1.543-2.425-.057-.442C16.566 6.251 14.024 4 11 4zm-.53 3.763l.53.53.53-.53c.684-.684 1.792-.684 2.475 0 .684.683.684 1.791 0 2.474L11 13.243l-3.005-3.006c-.684-.683-.684-1.791 0-2.474.683-.684 1.791-.684 2.475 0z"
              fill="currentColor"
            />
          </svg>
        </svg>
        <svg
          :if={@assistant_type == "distribution-guru"}
          viewBox="0 0 24 24"
          aria-hidden="true"
          class="h-6 w-6"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true" class="h-6 w-6">
            <g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
              <g
                id="Dribbble-Light-Preview"
                transform="translate(-420.000000, -4199.000000)"
                fill="currentColor"
              >
                <g id="icons" transform="translate(56.000000, 160.000000)">
                  <path
                    d="M382,4045.9997 C382,4046.5517 381.552,4046.9997 381,4046.9997 L377,4046.9997 C376.448,4046.9997 376,4046.5517 376,4045.9997 L376,4042.0007 C376,4041.4477 376.448,4040.9997 377,4040.9997 L381,4040.9997 C381.552,4040.9997 382,4041.4477 382,4042.0007 L382,4045.9997 Z M380,4054.0637 C380,4054.6167 379.351,4054.9997 378.798,4054.9997 L374.798,4054.9997 L374,4054.9997 L374,4051.0647 C374,4049.9597 372.903,4048.9997 371.798,4048.9997 L368,4048.9997 L368,4048.1897 L368,4044.0647 C368,4043.5127 368.246,4042.9997 368.799,4042.9997 L374,4042.9997 L374,4043.1897 L374,4047.0647 C374,4048.1687 374.694,4048.9997 375.798,4048.9997 L380,4048.9997 L380,4054.0637 Z M372,4055.9997 C372,4056.5517 371.552,4056.9997 371,4056.9997 L367,4056.9997 C366.448,4056.9997 366,4056.5517 366,4055.9997 L366,4052.0007 C366,4051.4477 366.448,4050.9997 367,4050.9997 L371,4050.9997 C371.552,4050.9997 372,4051.4477 372,4052.0007 L372,4055.9997 Z M382,4055.0647 L382,4049.0647 C383.105,4049.0647 384,4048.1687 384,4047.0647 L384,4041.0647 C384,4039.9597 382.903,4038.9997 381.798,4038.9997 L375.798,4038.9997 C374.694,4038.9997 373.798,4039.8957 373.798,4040.9997 L367.798,4040.9997 C366.694,4040.9997 366,4041.9597 366,4043.0647 L366,4049.0647 C364.895,4049.0647 364,4049.9597 364,4051.0647 L364,4057.0647 C364,4058.1687 364.694,4058.9997 365.798,4058.9997 L371.798,4058.9997 C372.903,4058.9997 373.798,4058.1047 373.798,4056.9997 L379.798,4056.9997 C380.903,4056.9997 382,4056.1687 382,4055.0647 L382,4055.0647 Z"
                    id="object_distribution_round-[#901]"
                  >
                  </path>
                </g>
              </g>
            </g>
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
          <svg viewBox="0 0 24 24" aria-hidden="true" class="h-6 w-6">
            <path
              fill-rule="evenodd"
              clip-rule="evenodd"
              d="M12 22C17.5228 22 22 17.5228 22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 13.5997 2.37562 15.1116 3.04346 16.4525C3.22094 16.8088 3.28001 17.2161 3.17712 17.6006L2.58151 19.8267C2.32295 20.793 3.20701 21.677 4.17335 21.4185L6.39939 20.8229C6.78393 20.72 7.19121 20.7791 7.54753 20.9565C8.88837 21.6244 10.4003 22 12 22Z"
              fill="currentColor"
            />
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
      </div>
    </div>
    """
  end
end
