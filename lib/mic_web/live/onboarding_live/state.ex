defmodule MicWeb.OnboardingLive.State do
  alias MicWeb.Message

  def initial_state do
    %{
      messages: initial_messages(),
      loading: false,
      streaming_message: %Message{content: "", sender: :assistant, id: -1}
    }
  end

  defp initial_messages do
    [
      %Message{
        content:
          "Hi! I'm here to onboard you to Incurator.\n\nYou will be able to change your preferences later on.\n\nDo you prefer we talk in English, Spanish or Portuguese?",
        sender: :assistant,
        id: 0
      }
    ]
  end
end
