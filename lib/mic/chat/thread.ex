defmodule Mic.Chat.Thread do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(user_id openai_thread_id metadata category)a
  @required ~w(user_id openai_thread_id category)a

  schema "threads" do
    field :openai_thread_id, Ecto.UUID
    field :metadata, :map

    field :category, Ecto.Enum,
      values: [
        :community,
        :distribution,
        :education,
        :finance,
        :general,
        :health,
        :legal,
        :marketing,
        :operational,
        :production,
        :strategy,
        :talent
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
