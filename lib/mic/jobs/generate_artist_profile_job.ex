defmodule Mic.Jobs.GenerateArtistProfileJob do
  require Logger

  alias Mic.Repo

  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "current_user" => current_user,
          "profile_data" => profile_data,
          "language_preference" => language_preference
        }
      }) do
    query_string = build_query_string(profile_data)

    case Mic.Chat.OpenAI.generate_artist_profile_description(query_string, language_preference) do
      {:ok, response} ->
        description_content = response.content
        updated_profile_data = Map.put(profile_data, :artist_ai_description, description_content)
        process_updated_profile_data(updated_profile_data, current_user, language_preference)
        :ok

      {:error, reason} ->
        Logger.error("Chat Completions Generate Profile Description Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_query_string(profile_data) do
    profile_data
    |> Map.to_list()
    |> Enum.map(fn {key, value} ->
      value_string =
        case value do
          %Date{} = date -> Date.to_string(date)
          _ -> to_string(value)
        end

      "#{String.upcase(to_string(key))}: #{value_string}"
    end)
    |> Enum.join(". ")
  end

  defp process_updated_profile_data(updated_profile_data, current_user, response_language) do
    case Date.from_iso8601(updated_profile_data["dob"]) do
      {:ok, date_struct} ->
        current_user_id = current_user["id"]
        updated_profile_data = Map.put(updated_profile_data, "dob", date_struct)
        updated_profile_data_with_atom_keys = convert_keys_to_atoms(updated_profile_data)

        model = Repo.get(Mic.Accounts.User, current_user_id)

        try do
          if model.__struct__ == Mic.Accounts.User do
            create_profile(
              model,
              updated_profile_data_with_atom_keys,
              current_user_id,
              current_user,
              response_language
            )
          else
            Logger.error("User struct failed: not equal to Mic.Accounts.User")
            nil
          end
        rescue
          Ecto.NoResultsError ->
            Logger.error("User not found with ID: #{current_user_id}")
            nil
        end

      {:error, _reason} ->
        Logger.error("Invalid date format for dob")
        raise "Invalid date format for dob"
    end
  end

  defp create_profile(
         model,
         updated_profile_data_with_atom_keys,
         current_user_id,
         current_user,
         response_language
       ) do
    case Mic.Artists.create_profile(model, updated_profile_data_with_atom_keys) do
      {:ok, profile} ->
        unless check_subject_resource(current_user_id) do
          enqueue_generate_resources_job(
            current_user,
            profile.artist_ai_description,
            response_language
          )
        end

        {:ok, profile}

      {:error, changeset} ->
        Logger.debug("changeset error #{inspect(changeset)}")
    end
  end

  defp check_subject_resource(current_user_id) do
    subjects = Mic.Types.available_subject_and_assistant_types()

    Enum.any?(subjects, fn subject ->
      try do
        Mic.Artists.get_resource_by_user_id_and_subject!(current_user_id, subject)
        true
      rescue
        Ecto.NoResultsError ->
          false
      end
    end)
  end

  defp enqueue_generate_resources_job(current_user, description_content, response_language) do
    subjects = Mic.Types.available_subject_and_assistant_types()

    Enum.each(subjects, fn subject ->
      try do
        Mic.Jobs.GenerateArtistTailoredResourcesJob.new(%{
          "current_user" => current_user,
          "description_content" => description_content,
          "subject" => subject,
          "response_language" => response_language
        })
        |> Oban.insert()
      rescue
        exception ->
          Logger.error(
            "Failed to enqueue GenerateArtistTailoredResourcesJob: #{inspect(exception)}"
          )

          # Handle the error, e.g., retry or notify the user
      end
    end)
  end

  defp convert_keys_to_atoms(map) do
    map
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      atom_key = if is_binary(key), do: String.to_existing_atom(key), else: key

      Map.put(acc, atom_key, value)
    end)
  end
end
