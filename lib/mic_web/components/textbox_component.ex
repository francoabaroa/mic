defmodule MicWeb.TextboxComponent do
  use MicWeb, :live_component

  defp new_form(), do: to_form(%{"text" => "", "rand" => UUID.uuid4()}, as: :main)

  def mount(socket) do
    {:ok,
     socket
     |> assign(form: new_form(), text: "")}
  end

  # def update(assigns, new_text) do
  #   updated_assigns = assign(assigns, :text, new_text)
  #   {:ok, updated_assigns}
  # end

  @spec handle_event(<<_::64>>, map(), any()) :: {:noreply, any()}
  def handle_event("onsubmit", %{"main" => %{"text" => text}}, socket) do
    if String.length(text) >= 1 and socket.assigns.disabled == false do
      socket.assigns.on_submit.(text)
      {:noreply, socket |> assign(form: new_form())}
    else
      {:noreply, socket}
    end
  end

  attr :field, Phoenix.HTML.FormField
  attr :text, :string
  attr :myself, :any
  attr :disabled, :boolean

  def textarea(assigns) do
    assigns =
      assign(assigns, :onkeydown, """
      if(event.keyCode == 13 && event.shiftKey == false) {
      		document.getElementById('submitbtn').click();
      	 return false;}
      """)

    ~H"""
    <textarea
      tabindex="0"
      style="max-height: 200px; height: 96px;"
      class="m-0 w-full resize-none border-0 bg-transparent p-0 pr-7 focus:ring-0 focus-visible:ring-0 dark:bg-transparent pl-2 md:pl-0"
      placeholder="Enter your message..."
      id={@field.id}
      name={@field.name}
      phx-target={@myself}
      onkeydown={@onkeydown}
    ><%= @text %></textarea>
    """
  end

  attr :on_submit, :any, required: true
  attr :disabled, :boolean, required: true

  def render(assigns) do
    ~H"""
    <div id="textbox" class="">
      <.form
        class="stretch mx-2 flex flex-row gap-3 last:mb-2 md:mx-4 md:last:mb-6 lg:mx-auto lg:max-w-3xl"
        phx-target={@myself}
        phx-submit="onsubmit"
        for={@form}
      >
        <div class="flex flex-col w-full py-2 flex-grow md:py-3 md:pl-4 relative border border-black/10 bg-white dark:border-gray-900/50 dark:text-white dark:bg-gray-700 rounded-md shadow-[0_0_10px_rgba(0,0,0,0.10)] dark:shadow-[0_0_15px_rgba(0,0,0,0.10)]">
          <.textarea disabled={@disabled} field={@form[:text]} myself={@myself} text={@text} />
          <button
            id="submitbtn"
            class="absolute p-1 rounded-md text-gray-500 bottom-1.5 right-10 hover:bg-gray-100 dark:hover:text-gray-400 dark:hover:bg-gray-900 disabled:hover:bg-transparent dark:disabled:hover:bg-transparent md:right-20 md:bottom-2.5"
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
              class="lucide lucide-send-horizontal"
            >
              <path d="m3 3 3 9-3 9 19-9Z" /><path d="M6 12h16" />
            </svg>
          </button>
          <button
            id="transcriptionbtn"
            class="absolute p-1 rounded-md text-gray-500 bottom-1.5 right-20 hover:bg-gray-100 dark:hover:text-gray-400 dark:hover:bg-gray-900 disabled:hover:bg-transparent dark:disabled:hover:bg-transparent md:right-10 md:bottom-2.5"
            phx-click="initiate_voice_transcription"
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
              class="lucide lucide-audio-lines"
            >
              <path d="M2 10v3" /><path d="M6 6v11" /><path d="M10 3v18" /><path d="M14 8v7" /><path d="M18 5v13" /><path d="M22 10v3" />
            </svg>
          </button>
          <button
            id="transcriptionstopbtn"
            class="absolute p-1 rounded-md text-gray-500 bottom-1.5 right-15 hover:bg-gray-100 dark:hover:text-gray-400 dark:hover:bg-gray-900 disabled:hover:bg-transparent dark:disabled:hover:bg-transparent md:right-2.5 md:bottom-2.5"
            phx-click="stop_voice_transcription"
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
              class="lucide lucide-octagon"
            >
              <polygon points="7.86 2 16.14 2 22 7.86 22 16.14 16.14 22 7.86 22 2 16.14 2 7.86 7.86 2" />
            </svg>
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
