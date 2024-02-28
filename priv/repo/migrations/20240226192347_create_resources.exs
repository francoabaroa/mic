defmodule Mic.Repo.Migrations.CreateResources do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE subject AS ENUM ('distribution', 'finance', 'general', 'health', 'legal', 'marketing', 'operational', 'production', 'strategy', 'talent')"

    create table(:resources) do
      add :content, :jsonb
      add :subject, :subject, null: false
      add :user_id, references(:users, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:resources, [:user_id])
  end

  def down do
    drop table(:resources)
    execute "DROP TYPE subject"
  end
end
