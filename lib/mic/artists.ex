defmodule Mic.Artists do
  @moduledoc """
  The Artists context.
  """

  import Ecto.Query, warn: false
  alias Mic.Repo

  alias Mic.Artists.Chartmetric
  alias Mic.Artists.Profile
  alias Mic.Artists.Resource
  alias Mic.Accounts.User

  def get_artist_metrics(artist_id) do
    with {:ok, spotify_stats} <- Chartmetric.get_artist_spotify_stats(artist_id),
         {:ok, instagram_stats} <- Chartmetric.get_artist_instagram_stats(artist_id),
         {:ok, youtube_stats} <- Chartmetric.get_artist_youtube_stats(artist_id) do
      metrics = %{
        listeners: extract_listeners(spotify_stats),
        likes: extract_likes(instagram_stats),
        comments: extract_comments(youtube_stats),
        followers: extract_followers(spotify_stats, instagram_stats, youtube_stats)
      }

      {:ok, metrics}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_listeners(spotify_stats) do
    spotify_stats["listeners"]
    |> Enum.map(fn %{"value" => value} -> value end)
  end

  defp extract_likes(instagram_stats) do
    instagram_stats["followers"]
    |> Enum.map(fn %{"value" => value} -> value end)
  end

  defp extract_comments(youtube_stats) do
    youtube_stats["daily_views"]
    |> Enum.map(fn %{"value" => value} -> value end)
  end

  defp extract_followers(spotify_stats, instagram_stats, youtube_stats) do
    spotify_followers = get_value(spotify_stats, ["followers"])
    instagram_followers = get_value(instagram_stats, ["followers"])
    youtube_subscribers = get_value(youtube_stats, ["subscribers"])

    (spotify_followers || 0) + (instagram_followers || 0) + (youtube_subscribers || 0)
  end

  defp get_value(stats, keys) do
    case get_in(stats, keys) do
      nil -> nil
      followers -> followers |> List.last() |> Map.get("value")
    end
  end

  @doc """
  Returns the list of profiles.

  ## Examples

      iex> list_profiles()
      [%Profile{}, ...]

  """
  def list_profiles do
    Repo.all(Profile)
  end

  @doc """
  Gets a single profile.

  Raises `Ecto.NoResultsError` if the Profile does not exist.

  ## Examples

      iex> get_profile!(123)
      %Profile{}

      iex> get_profile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_profile!(id), do: Repo.get!(Profile, id)

  @doc """
  Gets a single profile by user ID.

  Raises `Ecto.NoResultsError` if the Profile does not exist.

  ## Examples

      iex> get_profile_by_user_id!(user_id)
      %Profile{}

  """
  def get_profile_by_user_id!(user_id) do
    Repo.one!(from p in Profile, where: p.user_id == ^user_id)
  end

  @doc """
  Creates a profile.

  ## Examples

      iex> create_profile(%{field: value})
      {:ok, %Profile{}}

      iex> create_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_profile(%User{} = user, attrs \\ %{}) do
    %Profile{}
    |> Profile.user_changeset(user, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a profile.

  ## Examples

      iex> update_profile(profile, %{field: new_value})
      {:ok, %Profile{}}

      iex> update_profile(profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_profile(%Profile{} = profile, attrs) do
    profile
    |> Profile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a profile.

  ## Examples

      iex> delete_profile(profile)
      {:ok, %Profile{}}

      iex> delete_profile(profile)
      {:error, %Ecto.Changeset{}}

  """
  def delete_profile(%Profile{} = profile) do
    Repo.delete(profile)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking profile changes.

  ## Examples

      iex> change_profile(profile)
      %Ecto.Changeset{data: %Profile{}}

  """
  def change_profile(%Profile{} = profile, attrs \\ %{}) do
    Profile.changeset(profile, attrs)
  end

  @doc """
  Returns the list of resources.

  ## Examples

      iex> list_resources()
      [%Resource{}, ...]
  """
  def list_resources do
    Repo.all(Resource)
  end

  @doc """
  Gets a single resource by ID.

  Raises `Ecto.NoResultsError` if the Resource does not exist.

  ## Examples

      iex> get_resource!(123)
      %Resource{}

      iex> get_resource!(456)
      ** (Ecto.NoResultsError)
  """
  def get_resource!(id), do: Repo.get!(Resource, id)

  @doc """
  Gets a single resource by user ID.

  Raises `Ecto.NoResultsError` if the Resource does not exist.

  ## Examples

      iex> get_resource_by_user_id!(user_id)
      %Resource{}
  """
  def get_resource_by_user_id!(user_id) do
    Repo.one!(from r in Resource, where: r.user_id == ^user_id)
  end

  @doc """
  Gets a single resource by user ID and subject.

  Raises `Ecto.NoResultsError` if the Resource does not exist.

  ## Examples

      iex> get_resource_by_user_id_and_subject!(user_id, :distribution)
      %Resource{}

  """
  def get_resource_by_user_id_and_subject!(user_id, subject) do
    Repo.one!(
      from r in Resource,
        where: r.user_id == ^user_id and r.subject == ^subject
    )
  end

  @doc """
  Creates a resource.

  ## Examples

      iex> create_resource(%{field: value})
      {:ok, %Resource{}}

      iex> create_resource(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource(%User{} = user, attrs \\ %{}) do
    %Resource{}
    |> Resource.user_changeset(user, attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource.

  ## Examples

      iex> update_resource(resource, %{field: new_value})
      {:ok, %Resource{}}

      iex> update_resource(resource, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource(%Resource{} = resource, attrs) do
    resource
    |> Resource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resource.

  ## Examples

      iex> delete_resource(resource)
      {:ok, %Resource{}}

      iex> delete_resource(resource)
      {:error, %Ecto.Changeset{}}
  """
  def delete_resource(%Resource{} = resource) do
    Repo.delete(resource)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource changes.

  ## Examples

      iex> change_resource(resource)
      %Ecto.Changeset{data: %Resource{}}
  """
  def change_resource(%Resource{} = resource, attrs \\ %{}) do
    Resource.changeset(resource, attrs)
  end
end
