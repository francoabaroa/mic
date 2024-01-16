defmodule Mic.Repo.Migrations.CreateFiles do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE purpose AS ENUM ('assistant', 'user')"

    create table(:files) do
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :message_id, references(:messages, on_delete: :nothing), null: false
      add :purpose, :purpose, null: false
      add :openai_file_id, :uuid

      timestamps(type: :utc_datetime)
    end

    create index(:files, [:user_id])
    create index(:files, [:message_id])
  end

  def down do
    drop table(:files)
    execute "DROP TYPE purpose"
  end
end
