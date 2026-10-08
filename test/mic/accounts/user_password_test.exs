defmodule Mic.Accounts.UserPasswordTest do
  use ExUnit.Case, async: true

  alias Mic.Accounts.User
  import Ecto.Changeset, only: [get_change: 2]

  test "registration rejects multibyte passwords exceeding 72 bytes before hashing" do
    changeset =
      User.registration_changeset(
        %User{},
        %{email: "artist@example.com", password: String.duplicate("é", 37)},
        validate_email: false
      )

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :password)
    assert get_change(changeset, :hashed_password) == nil
  end

  test "password change and validation-only forms enforce the same byte limit" do
    password = String.duplicate("é", 37)

    for opts <- [[], [hash_password: false]] do
      changeset = User.password_changeset(%User{}, %{password: password}, opts)
      refute changeset.valid?
      assert get_change(changeset, :hashed_password) == nil
    end

    changeset =
      User.registration_changeset(%User{}, %{email: "artist@example.com", password: password},
        hash_password: false,
        validate_email: false
      )

    refute changeset.valid?
  end

  test "72-byte ASCII and multibyte passwords still hash and authenticate" do
    for password <- [String.duplicate("a", 72), String.duplicate("é", 36)] do
      changeset = User.password_changeset(%User{}, %{password: password})
      assert changeset.valid?
      assert get_change(changeset, :password) == nil
      user = Ecto.Changeset.apply_changes(changeset)
      assert User.valid_password?(user, password)
      refute User.valid_password?(user, password <> "extra")
      refute User.valid_password?(user, "wrong password")
    end
  end
end
