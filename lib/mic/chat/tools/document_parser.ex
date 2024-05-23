defmodule Mic.Chat.DocumentParser do
  use Rustler, otp_app: :mic, crate: "documentparser_native"

  def parse_docx(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def parse_pdf(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def parse_txt(_file_path), do: :erlang.nif_error(:nif_not_loaded)
end
