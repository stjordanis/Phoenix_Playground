defmodule Rumbl.Multimedia do
  @moduledoc """
  The Multimedia context.
  """

  import Ecto.Query, warn: false

  alias Rumbl.Repo
  alias Rumbl.Multimedia.Video
  alias Rumbl.Multimedia.Category

  def list_user_videos(user) do
    Video
    |> user_videos_query(user)
    |> Repo.all()
    |> preload_user()
    |> preload_category()
  end

  def get_user_video!(%Rumbl.Accounts.User{} = user, id) do
    from(v in Video, where: v.id == ^id)
    |> user_videos_query(user)
    |> Repo.one!()
    |> preload_user()
  end

  def create_video(%Rumbl.Accounts.User{} = user, attrs \\ %{}) do
    %Video{}
    |> Video.changeset(attrs)
    |> put_assoc(user)
    |> Repo.insert()
  end

  def update_video(%Video{} = video, attrs) do
    video
    |> Video.changeset(attrs)
    |> Repo.update()
  end

  def delete_video(%Video{} = video) do
    Repo.delete(video)
  end

  def change_video(%Rumbl.Accounts.User{} = user, %Video{} = video) do
    Video.changeset(video, %{})
    |> put_assoc(user)
  end

  defp put_assoc(changeset, user) do
    changeset
    |> Ecto.Changeset.put_assoc(:user, user)
  end

  defp user_videos_query(query, %Rumbl.Accounts.User{id: user_id}) do
    from(v in query, where: v.user_id == ^user_id)
  end

  defp preload_user(videos) do
    Repo.preload(videos, :user)
  end

  defp preload_category(videos) do
    Repo.preload(videos, :category)
  end

  def create_category(name) do
    Repo.get_by(Category, name: name) || Repo.insert!(%Category{name: name})
  end

  def list_alphabetical_categories() do
    Category
    |> Category.alphabetical()
    |> Repo.all()
  end
end