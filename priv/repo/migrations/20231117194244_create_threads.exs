defmodule Mic.Repo.Migrations.CreateThreads do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE category AS ENUM ('community', 'distribution', 'education', 'finance', 'general', 'health', 'legal', 'marketing', 'operational', 'production', 'strategy', 'talent')"

    create table(:threads) do
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :openai_thread_id, :uuid
      add :metadata, :map
      add :category, :category, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:threads, [:user_id])
  end

  def down do
    drop table(:threads)
    execute "DROP TYPE category"
  end
end
