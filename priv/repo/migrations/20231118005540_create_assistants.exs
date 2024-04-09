defmodule Mic.Repo.Migrations.CreateAssistants do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE assistant_type AS ENUM ('onboarding',
        'essentials',
        'distribution',
        'contract_analyzer',
        'mental_wellness',
        'health',
        'general',
        'finance',
        'legal',
        'marketing',
        'operational',
        'production',
        'strategy',
        'talent',
        'education',
        'community',
        'other')"

    create table(:assistants) do
      add :name, :string, null: false
      add :assistant_type, :assistant_type, null: false
      add :description, :string
      add :user_id, references(:users, on_delete: :nothing)
      add :openai_assistant_id, :uuid

      timestamps(type: :utc_datetime)
    end
  end

  def down do
    drop table(:assistants)
    execute "DROP TYPE assistant_type"
  end
end
