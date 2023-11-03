defmodule Mic.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles) do
      add :artist_name, :string, null: false
      add :genre, :string, null: false
      add :influences, :string, null: false
      add :aspirations, :string, null: false
      add :short_bio, :text
      add :country, :string, null: false
      add :dob, :date
      add :spotify_name, :string
      add :youtube_name, :string
      add :tiktok_name, :string
      add :instagram_name, :string
      add :facebook_name, :string
      add :twitter_name, :string
      add :website_url, :string
      add :user_id, references(:users, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:profiles, [:user_id], unique: true)
  end

  def down do
    drop table(:profiles)
  end
end
