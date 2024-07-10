defmodule Mic.Accounts.Settings do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(response_language response_answer_detail response_answer_style response_medium)a
  @required ~w(response_language response_answer_detail response_answer_style response_medium)a

  schema "settings" do
    field :response_language, Ecto.Enum,
      values: [
        :english,
        :spanish,
        :portuguese
      ]

    field :response_answer_detail, Ecto.Enum,
      values: [
        :brief,
        :super_brief,
        :detailed,
        :normal
      ]

    field :response_answer_style, Ecto.Enum,
      values: [
        :bullet_points,
        :normal
      ]

    field :response_medium, Ecto.Enum,
      values: [
        :text,
        :voice,
        :mixed
      ]

    belongs_to :user, Mic.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> assoc_constraint(:user)
  end

  @doc false
  def user_changeset(settings, %Mic.Accounts.User{} = user, attrs) do
    settings
    |> changeset(attrs)
    |> put_assoc(:user, user)
  end
end
