defmodule Mic.Artists.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(content subject)a
  @required ~w(subject)a

  schema "resources" do
    field :content, {:array, :map}

    field :subject, Ecto.Enum,
      values: [
        :distribution,
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
  def user_changeset(resource, %Mic.Accounts.User{} = user, attrs) do
    resource
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> put_assoc(:user, user)
  end

  @doc false
  def changeset(resource, attrs) do
    resource
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> assoc_constraint(:user)
  end
end
