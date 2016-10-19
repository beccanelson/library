defmodule Bookish.Tagging do
  use Bookish.Web, :controller
  alias Bookish.Tag
  alias Bookish.Book

  def update_tags(book, tags_string) do
    list_from_string(tags_string)
    |> get_or_create_tag
    |> associate_with_resource(book)
  end

  def list_from_string(tags_string) do
    if tags_string do
      String.split(tags_string, ",")
      |> Enum.map(&(String.trim &1))
    else
      []
    end
  end

  def get_or_create_tag(tags_list) do
    tags_list
    |> Enum.map(&(create_or_find_by_text String.downcase(&1)))
  end

  defp create_or_find_by_text(text) do
    try do
      Repo.get_by!(Tag, text: text)
    rescue
      Ecto.NoResultsError -> 
        case Repo.insert %Tag{text: text} do
          {:ok, tag} -> tag
        end
    end
  end

  def associate_with_resource(tag_entries, book) do
    book
    |> Repo.preload(:tags)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, tag_entries)
    |> Repo.update!
  end

  def set_tags_list(book) do
    tags_list = tags_to_string book.tags
    changeset = 
      book
      |> Book.tags(%{"tags_list": tags_list})
    case Repo.update(changeset) do
      {:ok, book} ->
        book
    end
  end

  defp tags_to_string(tags) do
    tags 
    |> Enum.map(&(&1.text))
    |> Enum.join(", ")
  end
end