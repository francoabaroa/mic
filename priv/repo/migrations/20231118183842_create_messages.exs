defmodule Mic.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE role AS ENUM ('assistant', 'user')"

    create table(:messages) do
      add :thread_id, references(:threads, on_delete: :nothing), null: false

      # could be the assistant this message was directed to, or the assistant authored this message. check role for more clarification
      add :assistant_id, references(:assistants, on_delete: :nothing), null: false
      add :run_id, references(:runs, on_delete: :nothing)
      add :content, :jsonb
      add :role, :role, null: false
      add :metadata, :map
      add :file_ids, {:array, :string}
      add :created_at, :integer
      add :openai_message_id, :uuid

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:assistant_id])
    create index(:messages, [:thread_id])
  end

  def down do
    drop table(:messages)
    execute "DROP TYPE role"
  end
end
