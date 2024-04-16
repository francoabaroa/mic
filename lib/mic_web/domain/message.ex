defmodule MicWeb.Message do
  defstruct [:sender, :content, :id]
  @enforce_keys [:sender, :content]

  # TODO: reconcile MicWeb.Message and Mic.Chat.Message?

  @type t :: %__MODULE__{
          sender: :user | :assistant | :system,
          content: String.t(),
          id: integer()
        }
end
