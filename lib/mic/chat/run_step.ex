defmodule Mic.Chat.RunStep do
  use Ecto.Schema
  import Ecto.Changeset

  @cast ~w(run_id type status openai_run_step_id created_at completed_at failed_at expired_at metadata step_details last_error)a
  @required ~w(run_id type status openai_run_step_id created_at)a

  schema "run_steps" do
    field :type, :string
    field :status, :string
    field :metadata, :map
    field :openai_run_step_id, Ecto.UUID
    field :created_at, :integer
    field :completed_at, :integer
    field :failed_at, :integer
    field :expired_at, :integer
    field :last_error, :map
    field :step_details, :map

    belongs_to :run, Mic.Chat.Run

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(run_step, attrs) do
    run_step
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> assoc_constraint(:run)
  end

  @doc false
  def run_changeset(run_step, %Mic.Chat.Run{} = run, attrs) do
    run_step
    |> changeset(attrs)
    |> put_assoc(:run, run)
  end
end
