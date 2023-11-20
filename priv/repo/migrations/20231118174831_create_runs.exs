defmodule Mic.Repo.Migrations.CreateRuns do
  use Ecto.Migration

  def change do
    create table(:runs) do
      add :thread_id, references(:threads, on_delete: :nothing), null: false
      add :assistant_id, references(:assistants, on_delete: :nothing), null: false
      add :status, :string
      add :model, :string
      add :instructions, :text
      add :openai_run_id, :uuid
      add :created_at, :integer
      add :started_at, :integer
      add :cancelled_at, :integer
      add :failed_at, :integer
      add :completed_at, :integer
      add :expires_at, :integer
      add :metadata, :map
      add :tools, :jsonb
      add :file_ids, {:array, :string}
      add :last_error, :map

      timestamps(type: :utc_datetime)
    end

    create index(:runs, [:thread_id])
    create index(:runs, [:assistant_id])
  end

  def down do
    drop table(:runs)
  end
end
