defmodule Mic.Repo.Migrations.CreateAssistants do
  use Ecto.Migration

  def change do
    create table(:assistants) do
      add :name, :string
      add :description, :string
      add :openai_assistant_id, :uuid

      timestamps(type: :utc_datetime)
    end
  end

  def down do
    drop table(:assistants)
  end
end
