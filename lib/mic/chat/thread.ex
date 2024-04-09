defmodule Mic.Chat.Thread do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(openai_thread_id metadata thread_category)a
  @required ~w(thread_category)a

  schema "threads" do
    field :openai_thread_id, Ecto.UUID
    field :metadata, :map

    field :thread_category, Ecto.Enum,
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

    belongs_to :user, Mic.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(thread, attrs) do
    thread
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> assoc_constraint(:user)
  end

  @doc false
  def user_changeset(thread, %Mic.Accounts.User{} = user, attrs) do
    thread
    |> changeset(attrs)
    |> put_assoc(:user, user)
  end
end
