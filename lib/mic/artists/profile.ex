defmodule Mic.Artists.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(
    artist_name
    genre
    influences
    aspirations
    short_bio
    country
    dob
    spotify_name
    youtube_name
    tiktok_name
    instagram_name
    facebook_name
    twitter_name
    website_url
  )a
  @required ~w(
    artist_name
    genre
    influences
    aspirations
    country
  )a

  schema "profiles" do
    field :artist_name, :string
    field :genre, :string
    field :influences, :string
    field :aspirations, :string
    field :short_bio, :string
    field :country, :string
    field :dob, :date
    field :spotify_name, :string
    field :youtube_name, :string
    field :tiktok_name, :string
    field :instagram_name, :string
    field :facebook_name, :string
    field :twitter_name, :string
    field :website_url, :string

    belongs_to :user, Mic.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def user_changeset(profile, %Mic.Accounts.User{} = user, attrs) do
    profile
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> put_assoc(:user, user)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> assoc_constraint(:user)
  end
end
