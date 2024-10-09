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

  attr :on_submit, :any, required: true
  attr :disabled, :boolean, required: true
  attr :current_question, :atom, required: true
  attr :uploads, :map, required: true
  attr :text, :string, required: true
  attr :assistant_scenario_id, :string, default: nil

  def render(assigns) do
    ~H"""
    <div id="textbox" class="relative">
      <.form
        class="flex items-center"
        phx-target={@myself}
        phx-submit="onsubmit"
        phx-change="validate"
        for={@form}
      >
        <div class="flex-grow relative">
          <textarea
            class="w-full px-4 py-2 bg-white bg-opacity-10 border border-white border-opacity-20 rounded-lg focus:outline-none focus:ring-2 focus:ring-yellow-400 text-white placeholder-white placeholder-opacity-50 resize-none"
            style="min-height: 48px; max-height: 200px;"
            placeholder="Enter your message..."
            id={@form[:text].id}
            name={@form[:text].name}
            phx-target={@myself}
            onkeydown="if(event.keyCode == 13 && event.shiftKey == false) { event.preventDefault(); document.getElementById('submitbtn').click(); }"
            disabled={@current_question == nil}
          ><%= @text %></textarea>
          <div class="absolute right-2 bottom-2 flex space-x-2">
            <%= if @assistant_scenario_id == "analyze-contract" do %>
              <.live_file_input upload={@uploads.file} class="hidden" />
              <button
                type="button"
                id="upload-button"
                onclick={"document.getElementById('#{@uploads.file.ref}').click()"}
                class="p-1 rounded-full text-white hover:bg-white hover:bg-opacity-10 transition-colors duration-200"
                disabled={@current_question == nil}
              >
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
                  <path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z" /><path d="M14 2v4a2 2 0 0 0 2 2h4" /><path d="M12 12v6" /><path d="m15 15-3-3-3 3" />
                </svg>
              </button>
            <% end %>
            <button
              id="transcriptionbtn"
              class="p-1 rounded-full text-white hover:bg-white hover:bg-opacity-10 transition-colors duration-200"
              phx-click="initiate_voice_transcription"
              disabled={@current_question == nil}
            >
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
              class="p-1 rounded-full text-white hover:bg-white hover:bg-opacity-10 transition-colors duration-200"
              phx-click="stop_voice_transcription"
              disabled={@current_question == nil}
            >
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
              class="p-1 rounded-full text-white hover:bg-white hover:bg-opacity-10 transition-colors duration-200"
              disabled={@current_question == nil}
            >
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
