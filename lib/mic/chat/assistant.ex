defmodule Mic.Chat.Assistant do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(name description openai_assistant_id assistant_type)a
  @required ~w(name assistant_type)a

  # TODO: eventually we save the base prompt here?
  schema "assistants" do
    field :name, :string
    field :description, :string

    field :assistant_type, Ecto.Enum,
      values: [
        :onboarding,
        :essentials,
        :distribution,
        :contract_analyzer,
        :mental_wellness,
        :health,
        :general,
        :finance,
        :legal,
        :marketing,
        :operational,
        :production,
        :strategy,
        :talent,
        :education,
        :community,
        :other
      ]

    field :openai_assistant_id, Ecto.UUID

    belongs_to :user, Mic.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(assistant, attrs) do
    assistant
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> assoc_constraint(:user)
  end

  @doc false
  def user_changeset(assistant, %Mic.Accounts.User{} = user, attrs) do
    assistant
    |> changeset(attrs)
    |> put_assoc(:user, user)
  end
end
