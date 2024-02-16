defmodule Mic.Repo.Migrations.AddFieldsToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :musical_beginnings, :string, null: false
      add :artist_ai_description, :text
      add :spotify_bio, :text
      add :music_education, :string
      add :instruments_played, :string
      add :significant_milestones, :string
      add :live_performances, :string
    end
  end
end
