defmodule Mic.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias Mic.Repo

  alias Mic.Accounts.User
  alias Mic.Chat.Assistant
  alias Mic.Chat.Message
  alias Mic.Chat.Thread

  @doc """
  Returns the list of messages.

  ## Examples

      iex> list_messages()
      [%Message{}, ...]

  """
  def list_messages do
    Repo.all(Message)
  end

  @doc """
  Gets a single message.

  Raises `Ecto.NoResultsError` if the Message does not exist.

  ## Examples

      iex> get_message!(123)
      %Message{}

      iex> get_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Gets all messages for a given user ID where the assistant associated with the message is of a specific assistant type.
  The messages are sorted by inserted_at from oldest to newest.

  ## Examples

      iex> get_messages_by_user_id_and_assistant_type(user_id, :general)
      [%Message{}, ...]

      iex> get_messages_by_user_id_and_assistant_type(user_id, :nonexistent)
      []

  """
  def get_messages_by_user_id_and_assistant_type(user_id, assistant_type) do
    Repo.all(
      from m in Message,
        join: a in assoc(m, :assistant),
        where: m.user_id == ^user_id and a.assistant_type == ^assistant_type,
        order_by: [asc: m.inserted_at],
        preload: [:assistant]
    )
  end

  @doc """
  Creates a message.

  ## Examples

      iex> create_message(%{field: value})
      {:ok, %Message{}}

      iex> create_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(%Assistant{} = assistant, %User{} = user, attrs \\ %{}) do
    message = %Message{}

    message
    |> Message.assistant_changeset(assistant, attrs)
    |> Message.user_changeset(user, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a message.

  ## Examples

      iex> update_message(message, %{field: new_value})
      {:ok, %Message{}}

      iex> update_message(message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a message.

  ## Examples

      iex> delete_message(message)
      {:ok, %Message{}}

      iex> delete_message(message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(message)
      %Ecto.Changeset{data: %Message{}}

  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  alias Mic.Chat.Thread

  @doc """
  Returns the list of threads.

  ## Examples

      iex> list_threads()
      [%Thread{}, ...]

  """
  def list_threads do
    Repo.all(Thread)
  end

  @doc """
  Gets a single thread.

  Raises `Ecto.NoResultsError` if the Thread does not exist.

  ## Examples

      iex> get_thread!(123)
      %Thread{}

      iex> get_thread!(456)
      ** (Ecto.NoResultsError)

  """
  def get_thread!(id), do: Repo.get!(Thread, id)

  @doc """
  Creates a thread.

  ## Examples

      iex> create_thread(%{field: value})
      {:ok, %Thread{}}

      iex> create_thread(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_thread(%User{} = user, attrs \\ %{}) do
    %Thread{}
    |> Thread.user_changeset(user, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a thread.

  ## Examples

      iex> update_thread(thread, %{field: new_value})
      {:ok, %Thread{}}

      iex> update_thread(thread, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_thread(%Thread{} = thread, attrs) do
    thread
    # TODO: remove
    # |> Thread.user_changeset(attrs)
    # |> Thread.assistant_changeset(attrs)
    |> Thread.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a thread.

  ## Examples

      iex> delete_thread(thread)
      {:ok, %Thread{}}

      iex> delete_thread(thread)
      {:error, %Ecto.Changeset{}}

  """
  def delete_thread(%Thread{} = thread) do
    Repo.delete(thread)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking thread changes.

  ## Examples

      iex> change_thread(thread)
      %Ecto.Changeset{data: %Thread{}}

  """
  def change_thread(%Thread{} = thread, attrs \\ %{}) do
    Thread.changeset(thread, attrs)
  end

  alias Mic.Chat.Assistant

  @doc """
  Returns the list of assistants.

  ## Examples

      iex> list_assistants()
      [%Assistant{}, ...]

  """
  def list_assistants do
    Repo.all(Assistant)
  end

  @doc """
  Gets a single assistant.

  Raises `Ecto.NoResultsError` if the Assistant does not exist.

  ## Examples

      iex> get_assistant!(123)
      %Assistant{}

      iex> get_assistant!(456)
      ** (Ecto.NoResultsError)

  """
  def get_assistant!(id), do: Repo.get!(Assistant, id)

  @doc """
  Gets a single assistant by user ID and assistant type.

  Raises `Ecto.NoResultsError` if the Assistant does not exist.

  ## Examples

      iex> get_assistant_by_user_id_and_assistant_type!(user_id, "default")
      %Assistant{}

      iex> get_assistant_by_user_id_and_assistant_type!(user_id, "invalid_type")
      ** (Ecto.NoResultsError)

  """
  def get_assistant_by_user_id_and_assistant_type!(user_id, assistant_type) do
    Repo.one!(
      from a in Assistant,
        where: a.user_id == ^user_id and a.assistant_type == ^assistant_type
    )
  end

  @doc """
  Creates a assistant.

  ## Examples

      iex> create_assistant(%{field: value})
      {:ok, %Assistant{}}

      iex> create_assistant(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_assistant(attrs \\ %{}) do
    %Assistant{}
    |> build_changeset(attrs)
    |> Repo.insert()
  end

  defp build_changeset(assistant, attrs) do
    case Map.has_key?(attrs, "user_id") or Map.has_key?(attrs, :user_id) do
      true ->
        user = Mic.Accounts.get_user!(attrs["user_id"] || attrs[:user_id])
        Assistant.user_changeset(assistant, user, attrs)

      false ->
        Assistant.changeset(assistant, attrs)
    end
  end

  @doc """
  Updates a assistant.

  ## Examples

      iex> update_assistant(assistant, %{field: new_value})
      {:ok, %Assistant{}}

      iex> update_assistant(assistant, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_assistant(%Assistant{} = assistant, attrs) do
    assistant
    |> Assistant.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a assistant.

  ## Examples

      iex> delete_assistant(assistant)
      {:ok, %Assistant{}}

      iex> delete_assistant(assistant)
      {:error, %Ecto.Changeset{}}

  """
  def delete_assistant(%Assistant{} = assistant) do
    Repo.delete(assistant)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking assistant changes.

  ## Examples

      iex> change_assistant(assistant)
      %Ecto.Changeset{data: %Assistant{}}

  """
  def change_assistant(%Assistant{} = assistant, attrs \\ %{}) do
    Assistant.changeset(assistant, attrs)
  end

  alias Mic.Chat.File

  @doc """
  Returns the list of files.

  ## Examples

      iex> list_files()
      [%File{}, ...]

  """
  def list_files do
    Repo.all(File)
  end

  @doc """
  Gets a single file.

  Raises `Ecto.NoResultsError` if the File does not exist.

  ## Examples

      iex> get_file!(123)
      %File{}

      iex> get_file!(456)
      ** (Ecto.NoResultsError)

  """
  def get_file!(id), do: Repo.get!(File, id)

  @doc """
  Creates a file.

  ## Examples

      iex> create_file(%{field: value})
      {:ok, %File{}}

      iex> create_file(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_file(%Message{} = message, %User{} = user, attrs \\ %{}) do
    %File{}
    |> File.user_changeset(user, attrs)
    |> File.message_changeset(message, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a file.

  ## Examples

      iex> update_file(file, %{field: new_value})
      {:ok, %File{}}

      iex> update_file(file, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_file(%File{} = file, attrs) do
    file
    |> File.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a file.

  ## Examples

      iex> delete_file(file)
      {:ok, %File{}}

      iex> delete_file(file)
      {:error, %Ecto.Changeset{}}

  """
  def delete_file(%File{} = file) do
    Repo.delete(file)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking file changes.

  ## Examples

      iex> change_file(file)
      %Ecto.Changeset{data: %File{}}

  """
  def change_file(%File{} = file, attrs \\ %{}) do
    File.changeset(file, attrs)
  end

  alias Mic.Chat.Run

  @doc """
  Returns the list of runs.

  ## Examples

      iex> list_runs()
      [%Run{}, ...]

  """
  def list_runs do
    Repo.all(Run)
  end

  @doc """
  Gets a single run.

  Raises `Ecto.NoResultsError` if the Run does not exist.

  ## Examples

      iex> get_run!(123)
      %Run{}

      iex> get_run!(456)
      ** (Ecto.NoResultsError)

  """
  def get_run!(id), do: Repo.get!(Run, id)

  @doc """
  Creates a run.

  ## Examples

      iex> create_run(%{field: value})
      {:ok, %Run{}}

      iex> create_run(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_run(%Assistant{} = assistant, %Thread{} = thread, attrs \\ %{}) do
    %Run{}
    |> Run.assistant_changeset(assistant, attrs)
    |> Run.thread_changeset(thread, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a run.

  ## Examples

      iex> update_run(run, %{field: new_value})
      {:ok, %Run{}}

      iex> update_run(run, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_run(%Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a run.

  ## Examples

      iex> delete_run(run)
      {:ok, %Run{}}

      iex> delete_run(run)
      {:error, %Ecto.Changeset{}}

  """
  def delete_run(%Run{} = run) do
    Repo.delete(run)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking run changes.

  ## Examples

      iex> change_run(run)
      %Ecto.Changeset{data: %Run{}}

  """
  def change_run(%Run{} = run, attrs \\ %{}) do
    Run.changeset(run, attrs)
  end

  alias Mic.Chat.RunStep

  @doc """
  Returns the list of run_steps.

  ## Examples

      iex> list_run_steps()
      [%RunStep{}, ...]

  """
  def list_run_steps do
    Repo.all(RunStep)
  end

  @doc """
  Gets a single run_step.

  Raises `Ecto.NoResultsError` if the Run step does not exist.

  ## Examples

      iex> get_run_step!(123)
      %RunStep{}

      iex> get_run_step!(456)
      ** (Ecto.NoResultsError)

  """
  def get_run_step!(id), do: Repo.get!(RunStep, id)

  @doc """
  Creates a run_step.

  ## Examples

      iex> create_run_step(%{field: value})
      {:ok, %RunStep{}}

      iex> create_run_step(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_run_step(%Run{} = run, attrs \\ %{}) do
    %RunStep{}
    |> RunStep.run_changeset(run, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a run_step.

  ## Examples

      iex> update_run_step(run_step, %{field: new_value})
      {:ok, %RunStep{}}

      iex> update_run_step(run_step, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_run_step(%RunStep{} = run_step, attrs) do
    run_step
    |> RunStep.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a run_step.

  ## Examples

      iex> delete_run_step(run_step)
      {:ok, %RunStep{}}

      iex> delete_run_step(run_step)
      {:error, %Ecto.Changeset{}}

  """
  def delete_run_step(%RunStep{} = run_step) do
    Repo.delete(run_step)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking run_step changes.

  ## Examples

      iex> change_run_step(run_step)
      %Ecto.Changeset{data: %RunStep{}}

  """
  def change_run_step(%RunStep{} = run_step, attrs \\ %{}) do
    RunStep.changeset(run_step, attrs)
  end
end
