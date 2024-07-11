defmodule Mic.Jobs.GenerateArtistTailoredResourcesJob do
  require Logger

  alias Mic.Repo

  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "current_user" => current_user,
          "description_content" => description_content,
          "subject" => subject,
          "response_language" => response_language
        }
      }) do
    resource = generate_tailored_content(description_content, subject, response_language)
    create_or_update_resource(current_user["id"], resource)
    :ok
  end

  defp create_or_update_resource(user_id, resource) do
    try do
      model = Repo.get(Mic.Accounts.User, user_id)

      if model.__struct__ == Mic.Accounts.User do
        case Mic.Artists.create_resource(model, resource) do
          {:ok, resource} ->
            Logger.debug("Resource created: #{inspect(resource)}")

          {:error, changeset} ->
            Logger.error("Resource creation failed: #{inspect(changeset)}")
            {:error, changeset}
        end
      else
        Logger.error("User struct failed: not equal to Mic.Accounts.User")
        nil
      end
    rescue
      Ecto.NoResultsError ->
        Logger.error("User not found with ID: #{user_id}")
        nil
    end
  end

  defp generate_tailored_content(artist_description, resource_subject, response_language) do
    resource_subject = String.to_existing_atom(resource_subject)

    case Mic.Chat.OpenAI.generate_artist_tailored_content(
           artist_description,
           resource_subject,
           response_language
         ) do
      {:ok, response} ->
        build_resource(resource_subject, response.content)

      {:error, reason} ->
        Logger.error("Chat Completions Generate Tailored Content Error: #{inspect(reason)}")
        nil
    end
  end

  defp build_resource(subject, content) do
    # TODO: remove this
    # return it in the correct Resource object
    # check if Resource already exists for subject, if so update resource content, if not create resource
    %{
      subject: subject,
      # Assuming content is a list of maps
      content: [%{title: "#{subject}", content: content}]
    }
  end
end
