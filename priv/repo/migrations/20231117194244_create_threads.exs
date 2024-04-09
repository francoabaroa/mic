defmodule Mic.Repo.Migrations.CreateThreads do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE thread_category AS ENUM ('onboarding',
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

    create table(:threads) do
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :thread_category, :thread_category, null: false
      add :openai_thread_id, :uuid
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:threads, [:user_id])
  end

  def down do
    drop table(:threads)
    execute "DROP TYPE thread_category"
  end
end
