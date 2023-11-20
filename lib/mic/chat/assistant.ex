defmodule Mic.Chat.Assistant do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(name description openai_assistant_id)a
  @required ~w(name description openai_assistant_id)a

  schema "assistants" do
    field :name, :string
    field :description, :string
    field :openai_assistant_id, Ecto.UUID

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(assistant, attrs) do
    assistant
    |> cast(attrs, @cast)
    |> validate_required(@required)
  end
end
