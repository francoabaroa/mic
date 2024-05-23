defmodule MicWeb.TextboxComponent do
  require Logger
  use MicWeb, :live_component

  defp new_form(), do: to_form(%{"text" => "", "rand" => UUID.uuid4()}, as: :main)

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(form: new_form(), text: "", uploaded_files: [])}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :file, ref)}
  end

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
    %{assistant_scenario_id: assistant_scenario_id, uploads: uploads} = assigns

    ~H"""
    <div id="textbox" class="">
      <.form
        class="stretch mx-2 flex flex-row gap-3 last:mb-2 md:mx-4 md:last:mb-6 lg:mx-auto lg:max-w-3xl"
        phx-target={@myself}
        phx-submit="onsubmit"
        phx-change="validate"
        for={@form}
      >
        <div class="flex flex-col w-full py-2 flex-grow md:py-3 md:pl-4 relative border border-black/10 bg-white dark:border-gray-900/50 dark:text-white dark:bg-gray-700 rounded-md shadow-[0_0_10px_rgba(0,0,0,0.10)] dark:shadow-[0_0_15px_rgba(0,0,0,0.10)]">
          <.textarea disabled={@disabled} field={@form[:text]} myself={@myself} text={@text} />
          <div class="absolute bottom-1.5 right-1.5 flex space-x-1 md:bottom-2.5 md:right-2.5">
            <%= if @assistant_scenario_id == "analyze-contract" do %>
              <.live_file_input upload={@uploads.file} />

              <button
                type="button"
                id="upload-button"
                onclick={"document.getElementById('#{@uploads.file.ref}').click()"}
                class="p-1 rounded-md text-gray-500 hover:bg-gray-100 dark:hover:text-gray-400 dark:hover:bg-gray-900 disabled:hover:bg-transparent dark:disabled:hover:bg-transparent"
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
                  class="lucide lucide-file-up"
                >
                  <path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z" /><path d="M14 2v4a2 2 0 0 0 2 2h4" /><path d="M12 12v6" /><path d="m15 15-3-3-3 3" />
                </svg>
              </button>
            <% end %>
            <button
              id="transcriptionbtn"
              class="p-1 rounded-md text-gray-500 hover:bg-gray-100 dark:hover:text-gray-400 dark:hover:bg-gray-900 disabled:hover:bg-transparent dark:disabled:hover:bg-transparent"
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
                class="lucide lucide-mic"
              >
                <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" /><path d="M19 10v2a7 7 0 0 1-14 0v-2" /><line
                  x1="12"
                  x2="12"
                  y1="19"
                  y2="22"
                />
              </svg>
            </button>
            <button
              id="transcriptionstopbtn"
              class="p-1 rounded-md text-gray-500 hover:bg-gray-100 dark:hover:text-gray-400 dark:hover:bg-gray-900 disabled:hover:bg-transparent dark:disabled:hover:bg-transparent"
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
                class="lucide lucide-mic-off"
              >
                <line x1="2" x2="22" y1="2" y2="22" /><path d="M18.89 13.23A7.12 7.12 0 0 0 19 12v-2" /><path d="M5 10v2a7 7 0 0 0 12 5" /><path d="M15 9.34V5a3 3 0 0 0-5.68-1.33" /><path d="M9 9v3a3 3 0 0 0 5.12 2.12" /><line
                  x1="12"
                  x2="12"
                  y1="19"
                  y2="22"
                />
              </svg>
            </button>
            <button
              id="submitbtn"
              class="p-1 rounded-md text-gray-500 hover:bg-gray-100 dark:hover:text-gray-400 dark:hover:bg-gray-900 disabled:hover:bg-transparent dark:disabled:hover:bg-transparent"
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
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
