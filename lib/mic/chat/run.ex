defmodule Mic.Chat.Run do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(thread_id assistant_id status model instructions openai_run_id created_at started_at cancelled_at failed_at completed_at expires_at metadata tools file_ids last_error)a
  @required ~w(thread_id assistant_id status model instructions openai_run_id created_at)a

  schema "runs" do
    field :status, :string
    field :model, :string
    field :instructions, :string
    field :openai_run_id, Ecto.UUID
    field :created_at, :integer
    field :started_at, :integer
    field :cancelled_at, :integer
    field :failed_at, :integer
    field :completed_at, :integer
    field :expires_at, :integer
    field :metadata, :map
    field :tools, {:array, :map}
    field :file_ids, {:array, :string}
    field :last_error, :map

    belongs_to :thread, Mic.Chat.Thread
    belongs_to :assistant, Mic.Chat.Assistant

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> assoc_constraint(:thread)
    |> assoc_constraint(:assistant)
  end

  @doc false
  def thread_changeset(run, %Mic.Chat.Thread{} = thread, attrs) do
    run
    |> changeset(attrs)
    |> put_assoc(:thread, thread)
  end

  @doc false
  def assistant_changeset(run, %Mic.Chat.Assistant{} = assistant, attrs) do
    run
    |> changeset(attrs)
    |> put_assoc(:assistant, assistant)
  end
end
