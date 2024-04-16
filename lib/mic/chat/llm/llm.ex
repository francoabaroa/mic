defmodule Mic.Chat.LLM do
  @type chunk :: {:data, String.t()} | {:error, String.t()} | :finish
  @type handle_chunk_fun :: (chunk -> :ok | {:error, String.t()})

  @callback do_complete(
              list_of_messages :: [MicWeb.Message],
              model :: String.t(),
              callback :: handle_chunk_fun()
            ) ::
              {:ok, MicWeb.Message} | {:error, String.t()}

  @spec get_provider(:anthropic | :google | :openai) ::
          Mic.Chat.Anthropic | Mic.Chat.OpenAI2 | Mic.Chat.Vertex
  def get_provider(:anthropic), do: Mic.Chat.Anthropic
  def get_provider(:openai), do: Mic.Chat.OpenAI2
  def get_provider(:google), do: Mic.Chat.Vertex
  def get_provider(_), do: raise("Unknown provider")
end
