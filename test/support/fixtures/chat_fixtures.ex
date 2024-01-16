defmodule Mic.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mic.Chat` context.
  """

  @doc """
  Generate a message.
  """
  def message_fixture(attrs \\ %{}) do
    {:ok, message} =
      attrs
      |> Enum.into(%{
        assistant_id: "7488a646-e31f-11e4-aace-600308960662",
        content: "some content",
        metadata: %{},
        role: "some role",
        thread_id: "7488a646-e31f-11e4-aace-600308960662"
      })
      |> Mic.Chat.create_message()

    message
  end

  @doc """
  Generate a thread.
  """
  def thread_fixture(attrs \\ %{}) do
    {:ok, thread} =
      attrs
      |> Enum.into(%{
        assistant_id: "7488a646-e31f-11e4-aace-600308960662",
        created_at: ~U[2023-11-17 00:53:00Z],
        metadata: %{},
        user_id: "7488a646-e31f-11e4-aace-600308960662"
      })
      |> Mic.Chat.create_thread()

    thread
  end

  @doc """
  Generate a assistant.
  """
  def assistant_fixture(attrs \\ %{}) do
    {:ok, assistant} =
      attrs
      |> Enum.into(%{
        description: "some description",
        instructions: "some instructions",
        metadata: %{},
        model: "some model",
        name: "some name",
        user_id: "7488a646-e31f-11e4-aace-600308960662"
      })
      |> Mic.Chat.create_assistant()

    assistant
  end

  @doc """
  Generate a file.
  """
  def file_fixture(attrs \\ %{}) do
    {:ok, file} =
      attrs
      |> Enum.into(%{
        purpose: "some purpose",
        user_id: "7488a646-e31f-11e4-aace-600308960662"
      })
      |> Mic.Chat.create_file()

    file
  end

  @doc """
  Generate a run.
  """
  def run_fixture(attrs \\ %{}) do
    {:ok, run} =
      attrs
      |> Enum.into(%{
        assistant_id: "7488a646-e31f-11e4-aace-600308960662",
        cancelled_at: 42,
        completed_at: 42,
        created_at: 42,
        expires_at: 42,
        failed_at: 42,
        instructions: "some instructions",
        metadata: %{},
        model: "some model",
        started_at: 42,
        status: "some status",
        thread_id: "7488a646-e31f-11e4-aace-600308960662"
      })
      |> Mic.Chat.create_run()

    run
  end

  @doc """
  Generate a run_step.
  """
  def run_step_fixture(attrs \\ %{}) do
    {:ok, run_step} =
      attrs
      |> Enum.into(%{
        completed_at: 42,
        created_at: 42,
        failed_at: 42,
        metadata: %{},
        run_id: "7488a646-e31f-11e4-aace-600308960662",
        status: "some status",
        step_details: %{},
        type: "some type"
      })
      |> Mic.Chat.create_run_step()

    run_step
  end
end
