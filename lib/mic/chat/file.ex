defmodule Mic.Chat.File do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(user_id message_id purpose openai_file_id)a
  @required ~w(user_id message_id purpose openai_file_id)a

  schema "files" do
    field :purpose, Ecto.Enum, values: [:assistant, :user]
    field :openai_file_id, Ecto.UUID

    belongs_to :user, Mic.Accounts.User
    belongs_to :message, Mic.Chat.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def message_changeset(file, %Mic.Chat.Message{} = message, attrs) do
    file
    |> changeset(attrs)
    |> put_assoc(:message, message)
  end

  @doc false
  def user_changeset(file, %Mic.Accounts.User{} = user, attrs) do
    file
    |> changeset(attrs)
    |> put_assoc(:user, user)
  end

  @doc false
  def changeset(file, attrs) do
    file
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> assoc_constraint(:user)
    |> assoc_constraint(:message)
  end
end
