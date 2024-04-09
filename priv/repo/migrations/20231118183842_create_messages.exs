defmodule Mic.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE role AS ENUM ('assistant', 'user', 'system')"

    create table(:messages) do
      add :role, :role, null: false
      add :content, :jsonb, null: false
      add :model_id, :string, null: false
      add :assistant_id, references(:assistants, on_delete: :nothing), null: false
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :thread_id, references(:threads, on_delete: :nothing)
      add :run_id, references(:runs, on_delete: :nothing)
      add :metadata, :map
      add :file_ids, {:array, :string}
      add :created_at, :integer
      add :openai_message_id, :uuid

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:user_id])
    create index(:messages, [:assistant_id])
    create index(:messages, [:thread_id])
  end

  def down do
    drop table(:messages)
    execute "DROP TYPE role"
  end
end
