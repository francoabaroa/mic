defmodule Mic.Jobs.DeleteDocumentMetadataJob do
  use Oban.Worker, queue: :default, max_attempts: 1

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "assistant_id" => assistant_id,
          "file_id" => file_id,
          "thread_id" => thread_id
        }
      }) do
    case HTTPoison.delete(
           "https://api.openai.com/v1/assistants/#{assistant_id}",
           [
             {"Authorization", "Bearer #{System.get_env("OPENAI_API_KEY")}"},
             {"Content-Type", "application/json"},
             {"OpenAI-Beta", "assistants=v2"}
           ]
         ) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Assistant deleted successfully")

        case HTTPoison.delete(
               "https://api.openai.com/v1/files/#{file_id}",
               [
                 {"Authorization", "Bearer #{System.get_env("OPENAI_API_KEY")}"},
                 {"Content-Type", "application/json"}
               ]
             ) do
          {:ok, %HTTPoison.Response{status_code: 200}} ->
            Logger.info("File deleted successfully")

            case HTTPoison.delete(
                   "https://api.openai.com/v1/threads/#{thread_id}",
                   [
                     {"Authorization", "Bearer #{System.get_env("OPENAI_API_KEY")}"},
                     {"Content-Type", "application/json"},
                     {"OpenAI-Beta", "assistants=v2"}
                   ]
                 ) do
              {:ok, %HTTPoison.Response{status_code: 200}} ->
                Logger.info("Thread deleted successfully")
                {:ok, "All metadata deleted successfully"}

              {:ok, %HTTPoison.Response{status_code: status_code}} ->
                Logger.error("Failed to delete thread. Status code: #{status_code}")
                {:error, "Failed to delete thread"}

              {:error, %HTTPoison.Error{reason: reason}} ->
                Logger.error("HTTPoison error while deleting thread: #{inspect(reason)}")
                {:error, reason}
            end

          {:ok, %HTTPoison.Response{status_code: status_code}} ->
            Logger.error("Failed to delete file. Status code: #{status_code}")
            {:error, "Failed to delete file"}

          {:error, %HTTPoison.Error{reason: reason}} ->
            Logger.error("HTTPoison error while deleting file: #{inspect(reason)}")
            {:error, reason}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("Failed to delete assistant. Status code: #{status_code}")
        {:error, "Failed to delete assistant"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTPoison error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
