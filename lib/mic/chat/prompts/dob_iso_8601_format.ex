defmodule Mic.Chat.Prompts.DobIso8601Format do
  def content(input_text) do
    """
    Please format the given DOB as ISO-8601 YYYY-MM-DD. DOB: #{input_text} ONLY RETURN THE ISO-8601 STRING, NOTHING ELSE.
    """
  end
end
