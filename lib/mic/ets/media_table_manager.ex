defmodule Mic.MediaTableManager do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :ets.new(:media_processing_table, [:set, :public, :named_table, {:write_concurrency, true}])
    {:ok, %{}}
  end
end
