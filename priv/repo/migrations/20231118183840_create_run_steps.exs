defmodule Mic.Repo.Migrations.CreateRunSteps do
  use Ecto.Migration

  def change do
    create table(:run_steps) do
      add :run_id, references(:runs, on_delete: :nothing), null: false
      add :type, :string
      add :status, :string
      add :openai_run_step_id, :uuid
      add :created_at, :integer
      add :completed_at, :integer
      add :failed_at, :integer
      add :expired_at, :integer
      add :last_error, :map
      add :metadata, :map
      add :step_details, :map

      timestamps(type: :utc_datetime)
    end

    create index(:run_steps, [:run_id])
  end

  def down do
    drop table(:run_steps)
  end
end
