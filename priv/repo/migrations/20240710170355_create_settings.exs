defmodule Mic.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE response_language AS ENUM ('english', 'spanish', 'portuguese')"

    execute "CREATE TYPE response_answer_detail AS ENUM ('brief', 'super_brief', 'detailed', 'normal')"

    execute "CREATE TYPE response_answer_style AS ENUM ('bullet_points', 'normal')"
    execute "CREATE TYPE response_medium AS ENUM ('text', 'voice', 'mixed')"

    create table(:settings) do
      add :response_language, :response_language, null: false
      add :response_answer_detail, :response_answer_detail, null: false
      add :response_answer_style, :response_answer_style, null: false
      add :response_medium, :response_medium, null: false
      add :user_id, references(:users, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:settings, [:user_id])
  end

  def down do
    drop table(:settings)
    execute "DROP TYPE response_language"
    execute "DROP TYPE response_answer_detail"
    execute "DROP TYPE response_answer_style"
    execute "DROP TYPE response_medium"
  end
end
