defmodule Mic.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(assistant_id thread_id run_id content role metadata file_ids created_at openai_message_id)a
  @required ~w(assistant_id thread_id content role openai_message_id)a

  schema "messages" do
    field :content, {:array, :map}
    field :role, Ecto.Enum, values: [:assistant, :user]
    field :metadata, :map
    field :file_ids, {:array, :string}
    field :created_at, :integer
    field :openai_message_id, Ecto.UUID

    # could be the assistant this message was directed to, or the assistant authored this message. check role for more clarification
    belongs_to :assistant, Mic.Chat.Assistant
    belongs_to :thread, Mic.Chat.Thread
    belongs_to :run, Mic.Chat.Run

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> assoc_constraint(:assistant)
    |> assoc_constraint(:thread)
    |> assoc_constraint(:run)
  end

  @doc false
  def assistant_changeset(message, %Mic.Chat.Assistant{} = assistant, attrs) do
    message
    |> changeset(attrs)
    |> put_assoc(:assistant, assistant)
  end

  @doc false
  def thread_changeset(message, %Mic.Chat.Thread{} = thread, attrs) do
    message
    |> changeset(attrs)
    |> put_assoc(:thread, thread)
  end

  @doc false
  def run_changeset(message, %Mic.Chat.Run{} = run, attrs) do
    message
    |> changeset(attrs)
    |> put_assoc(:run, run)
  end
end
