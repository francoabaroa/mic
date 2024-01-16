defmodule Mic.ChatTest do
  use Mic.DataCase

  alias Mic.Chat

  describe "messages" do
    alias Mic.Chat.Message

    import Mic.ChatFixtures

    @invalid_attrs %{metadata: nil, role: nil, assistant_id: nil, thread_id: nil, content: nil}

    test "list_messages/0 returns all messages" do
      message = message_fixture()
      assert Chat.list_messages() == [message]
    end

    test "get_message!/1 returns the message with given id" do
      message = message_fixture()
      assert Chat.get_message!(message.id) == message
    end

    test "create_message/1 with valid data creates a message" do
      valid_attrs = %{metadata: %{}, role: "some role", assistant_id: "7488a646-e31f-11e4-aace-600308960662", thread_id: "7488a646-e31f-11e4-aace-600308960662", content: "some content"}

      assert {:ok, %Message{} = message} = Chat.create_message(valid_attrs)
      assert message.metadata == %{}
      assert message.role == "some role"
      assert message.assistant_id == "7488a646-e31f-11e4-aace-600308960662"
      assert message.thread_id == "7488a646-e31f-11e4-aace-600308960662"
      assert message.content == "some content"
    end

    test "create_message/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_message(@invalid_attrs)
    end

    test "update_message/2 with valid data updates the message" do
      message = message_fixture()
      update_attrs = %{metadata: %{}, role: "some updated role", assistant_id: "7488a646-e31f-11e4-aace-600308960668", thread_id: "7488a646-e31f-11e4-aace-600308960668", content: "some updated content"}

      assert {:ok, %Message{} = message} = Chat.update_message(message, update_attrs)
      assert message.metadata == %{}
      assert message.role == "some updated role"
      assert message.assistant_id == "7488a646-e31f-11e4-aace-600308960668"
      assert message.thread_id == "7488a646-e31f-11e4-aace-600308960668"
      assert message.content == "some updated content"
    end

    test "update_message/2 with invalid data returns error changeset" do
      message = message_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_message(message, @invalid_attrs)
      assert message == Chat.get_message!(message.id)
    end

    test "delete_message/1 deletes the message" do
      message = message_fixture()
      assert {:ok, %Message{}} = Chat.delete_message(message)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_message!(message.id) end
    end

    test "change_message/1 returns a message changeset" do
      message = message_fixture()
      assert %Ecto.Changeset{} = Chat.change_message(message)
    end
  end

  describe "threads" do
    alias Mic.Chat.Thread

    import Mic.ChatFixtures

    @invalid_attrs %{metadata: nil, user_id: nil, assistant_id: nil, created_at: nil}

    test "list_threads/0 returns all threads" do
      thread = thread_fixture()
      assert Chat.list_threads() == [thread]
    end

    test "get_thread!/1 returns the thread with given id" do
      thread = thread_fixture()
      assert Chat.get_thread!(thread.id) == thread
    end

    test "create_thread/1 with valid data creates a thread" do
      valid_attrs = %{metadata: %{}, user_id: "7488a646-e31f-11e4-aace-600308960662", assistant_id: "7488a646-e31f-11e4-aace-600308960662", created_at: ~U[2023-11-17 00:53:00Z]}

      assert {:ok, %Thread{} = thread} = Chat.create_thread(valid_attrs)
      assert thread.metadata == %{}
      assert thread.user_id == "7488a646-e31f-11e4-aace-600308960662"
      assert thread.assistant_id == "7488a646-e31f-11e4-aace-600308960662"
      assert thread.created_at == ~U[2023-11-17 00:53:00Z]
    end

    test "create_thread/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_thread(@invalid_attrs)
    end

    test "update_thread/2 with valid data updates the thread" do
      thread = thread_fixture()
      update_attrs = %{metadata: %{}, user_id: "7488a646-e31f-11e4-aace-600308960668", assistant_id: "7488a646-e31f-11e4-aace-600308960668", created_at: ~U[2023-11-18 00:53:00Z]}

      assert {:ok, %Thread{} = thread} = Chat.update_thread(thread, update_attrs)
      assert thread.metadata == %{}
      assert thread.user_id == "7488a646-e31f-11e4-aace-600308960668"
      assert thread.assistant_id == "7488a646-e31f-11e4-aace-600308960668"
      assert thread.created_at == ~U[2023-11-18 00:53:00Z]
    end

    test "update_thread/2 with invalid data returns error changeset" do
      thread = thread_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_thread(thread, @invalid_attrs)
      assert thread == Chat.get_thread!(thread.id)
    end

    test "delete_thread/1 deletes the thread" do
      thread = thread_fixture()
      assert {:ok, %Thread{}} = Chat.delete_thread(thread)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_thread!(thread.id) end
    end

    test "change_thread/1 returns a thread changeset" do
      thread = thread_fixture()
      assert %Ecto.Changeset{} = Chat.change_thread(thread)
    end
  end

  describe "assistants" do
    alias Mic.Chat.Assistant

    import Mic.ChatFixtures

    @invalid_attrs %{name: nil, instructions: nil, description: nil, metadata: nil, user_id: nil, model: nil}

    test "list_assistants/0 returns all assistants" do
      assistant = assistant_fixture()
      assert Chat.list_assistants() == [assistant]
    end

    test "get_assistant!/1 returns the assistant with given id" do
      assistant = assistant_fixture()
      assert Chat.get_assistant!(assistant.id) == assistant
    end

    test "create_assistant/1 with valid data creates a assistant" do
      valid_attrs = %{name: "some name", instructions: "some instructions", description: "some description", metadata: %{}, user_id: "7488a646-e31f-11e4-aace-600308960662", model: "some model"}

      assert {:ok, %Assistant{} = assistant} = Chat.create_assistant(valid_attrs)
      assert assistant.name == "some name"
      assert assistant.instructions == "some instructions"
      assert assistant.description == "some description"
      assert assistant.metadata == %{}
      assert assistant.user_id == "7488a646-e31f-11e4-aace-600308960662"
      assert assistant.model == "some model"
    end

    test "create_assistant/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_assistant(@invalid_attrs)
    end

    test "update_assistant/2 with valid data updates the assistant" do
      assistant = assistant_fixture()
      update_attrs = %{name: "some updated name", instructions: "some updated instructions", description: "some updated description", metadata: %{}, user_id: "7488a646-e31f-11e4-aace-600308960668", model: "some updated model"}

      assert {:ok, %Assistant{} = assistant} = Chat.update_assistant(assistant, update_attrs)
      assert assistant.name == "some updated name"
      assert assistant.instructions == "some updated instructions"
      assert assistant.description == "some updated description"
      assert assistant.metadata == %{}
      assert assistant.user_id == "7488a646-e31f-11e4-aace-600308960668"
      assert assistant.model == "some updated model"
    end

    test "update_assistant/2 with invalid data returns error changeset" do
      assistant = assistant_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_assistant(assistant, @invalid_attrs)
      assert assistant == Chat.get_assistant!(assistant.id)
    end

    test "delete_assistant/1 deletes the assistant" do
      assistant = assistant_fixture()
      assert {:ok, %Assistant{}} = Chat.delete_assistant(assistant)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_assistant!(assistant.id) end
    end

    test "change_assistant/1 returns a assistant changeset" do
      assistant = assistant_fixture()
      assert %Ecto.Changeset{} = Chat.change_assistant(assistant)
    end
  end

  describe "files" do
    alias Mic.Chat.File

    import Mic.ChatFixtures

    @invalid_attrs %{user_id: nil, purpose: nil}

    test "list_files/0 returns all files" do
      file = file_fixture()
      assert Chat.list_files() == [file]
    end

    test "get_file!/1 returns the file with given id" do
      file = file_fixture()
      assert Chat.get_file!(file.id) == file
    end

    test "create_file/1 with valid data creates a file" do
      valid_attrs = %{user_id: "7488a646-e31f-11e4-aace-600308960662", purpose: "some purpose"}

      assert {:ok, %File{} = file} = Chat.create_file(valid_attrs)
      assert file.user_id == "7488a646-e31f-11e4-aace-600308960662"
      assert file.purpose == "some purpose"
    end

    test "create_file/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_file(@invalid_attrs)
    end

    test "update_file/2 with valid data updates the file" do
      file = file_fixture()
      update_attrs = %{user_id: "7488a646-e31f-11e4-aace-600308960668", purpose: "some updated purpose"}

      assert {:ok, %File{} = file} = Chat.update_file(file, update_attrs)
      assert file.user_id == "7488a646-e31f-11e4-aace-600308960668"
      assert file.purpose == "some updated purpose"
    end

    test "update_file/2 with invalid data returns error changeset" do
      file = file_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_file(file, @invalid_attrs)
      assert file == Chat.get_file!(file.id)
    end

    test "delete_file/1 deletes the file" do
      file = file_fixture()
      assert {:ok, %File{}} = Chat.delete_file(file)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_file!(file.id) end
    end

    test "change_file/1 returns a file changeset" do
      file = file_fixture()
      assert %Ecto.Changeset{} = Chat.change_file(file)
    end
  end

  describe "runs" do
    alias Mic.Chat.Run

    import Mic.ChatFixtures

    @invalid_attrs %{status: nil, instructions: nil, started_at: nil, metadata: nil, thread_id: nil, assistant_id: nil, model: nil, created_at: nil, cancelled_at: nil, failed_at: nil, completed_at: nil, expires_at: nil}

    test "list_runs/0 returns all runs" do
      run = run_fixture()
      assert Chat.list_runs() == [run]
    end

    test "get_run!/1 returns the run with given id" do
      run = run_fixture()
      assert Chat.get_run!(run.id) == run
    end

    test "create_run/1 with valid data creates a run" do
      valid_attrs = %{status: "some status", instructions: "some instructions", started_at: 42, metadata: %{}, thread_id: "7488a646-e31f-11e4-aace-600308960662", assistant_id: "7488a646-e31f-11e4-aace-600308960662", model: "some model", created_at: 42, cancelled_at: 42, failed_at: 42, completed_at: 42, expires_at: 42}

      assert {:ok, %Run{} = run} = Chat.create_run(valid_attrs)
      assert run.status == "some status"
      assert run.instructions == "some instructions"
      assert run.started_at == 42
      assert run.metadata == %{}
      assert run.thread_id == "7488a646-e31f-11e4-aace-600308960662"
      assert run.assistant_id == "7488a646-e31f-11e4-aace-600308960662"
      assert run.model == "some model"
      assert run.created_at == 42
      assert run.cancelled_at == 42
      assert run.failed_at == 42
      assert run.completed_at == 42
      assert run.expires_at == 42
    end

    test "create_run/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_run(@invalid_attrs)
    end

    test "update_run/2 with valid data updates the run" do
      run = run_fixture()
      update_attrs = %{status: "some updated status", instructions: "some updated instructions", started_at: 43, metadata: %{}, thread_id: "7488a646-e31f-11e4-aace-600308960668", assistant_id: "7488a646-e31f-11e4-aace-600308960668", model: "some updated model", created_at: 43, cancelled_at: 43, failed_at: 43, completed_at: 43, expires_at: 43}

      assert {:ok, %Run{} = run} = Chat.update_run(run, update_attrs)
      assert run.status == "some updated status"
      assert run.instructions == "some updated instructions"
      assert run.started_at == 43
      assert run.metadata == %{}
      assert run.thread_id == "7488a646-e31f-11e4-aace-600308960668"
      assert run.assistant_id == "7488a646-e31f-11e4-aace-600308960668"
      assert run.model == "some updated model"
      assert run.created_at == 43
      assert run.cancelled_at == 43
      assert run.failed_at == 43
      assert run.completed_at == 43
      assert run.expires_at == 43
    end

    test "update_run/2 with invalid data returns error changeset" do
      run = run_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_run(run, @invalid_attrs)
      assert run == Chat.get_run!(run.id)
    end

    test "delete_run/1 deletes the run" do
      run = run_fixture()
      assert {:ok, %Run{}} = Chat.delete_run(run)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_run!(run.id) end
    end

    test "change_run/1 returns a run changeset" do
      run = run_fixture()
      assert %Ecto.Changeset{} = Chat.change_run(run)
    end
  end

  describe "run_steps" do
    alias Mic.Chat.RunStep

    import Mic.ChatFixtures

    @invalid_attrs %{status: nil, type: nil, metadata: nil, run_id: nil, created_at: nil, completed_at: nil, failed_at: nil, step_details: nil}

    test "list_run_steps/0 returns all run_steps" do
      run_step = run_step_fixture()
      assert Chat.list_run_steps() == [run_step]
    end

    test "get_run_step!/1 returns the run_step with given id" do
      run_step = run_step_fixture()
      assert Chat.get_run_step!(run_step.id) == run_step
    end

    test "create_run_step/1 with valid data creates a run_step" do
      valid_attrs = %{status: "some status", type: "some type", metadata: %{}, run_id: "7488a646-e31f-11e4-aace-600308960662", created_at: 42, completed_at: 42, failed_at: 42, step_details: %{}}

      assert {:ok, %RunStep{} = run_step} = Chat.create_run_step(valid_attrs)
      assert run_step.status == "some status"
      assert run_step.type == "some type"
      assert run_step.metadata == %{}
      assert run_step.run_id == "7488a646-e31f-11e4-aace-600308960662"
      assert run_step.created_at == 42
      assert run_step.completed_at == 42
      assert run_step.failed_at == 42
      assert run_step.step_details == %{}
    end

    test "create_run_step/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_run_step(@invalid_attrs)
    end

    test "update_run_step/2 with valid data updates the run_step" do
      run_step = run_step_fixture()
      update_attrs = %{status: "some updated status", type: "some updated type", metadata: %{}, run_id: "7488a646-e31f-11e4-aace-600308960668", created_at: 43, completed_at: 43, failed_at: 43, step_details: %{}}

      assert {:ok, %RunStep{} = run_step} = Chat.update_run_step(run_step, update_attrs)
      assert run_step.status == "some updated status"
      assert run_step.type == "some updated type"
      assert run_step.metadata == %{}
      assert run_step.run_id == "7488a646-e31f-11e4-aace-600308960668"
      assert run_step.created_at == 43
      assert run_step.completed_at == 43
      assert run_step.failed_at == 43
      assert run_step.step_details == %{}
    end

    test "update_run_step/2 with invalid data returns error changeset" do
      run_step = run_step_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_run_step(run_step, @invalid_attrs)
      assert run_step == Chat.get_run_step!(run_step.id)
    end

    test "delete_run_step/1 deletes the run_step" do
      run_step = run_step_fixture()
      assert {:ok, %RunStep{}} = Chat.delete_run_step(run_step)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_run_step!(run_step.id) end
    end

    test "change_run_step/1 returns a run_step changeset" do
      run_step = run_step_fixture()
      assert %Ecto.Changeset{} = Chat.change_run_step(run_step)
    end
  end
end
