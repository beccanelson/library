defmodule Bookish.BookControllerTest do
  use Bookish.ConnCase

  alias Bookish.Book
  alias Bookish.Tag
  alias Bookish.BookController
  alias Bookish.ResourceController

  @valid_attrs %{author_firstname: "some content", author_lastname: "some content", current_location: "some content", title: "some content", year: 2016, location_id: 1}
  @invalid_attrs %{}
  @user %{id: "email", name: "user"}

  test "index redirects to page 1", %{conn: conn} do
    conn = get conn, book_path(conn, :index)
    assert conn.status == 302
  end

  test "lists all books on index", %{conn: conn} do
    conn = get conn, book_path(conn, :paginate, 1)
    assert conn.status == 200
  end

  test "lists books by letter", %{conn: conn} do
    Repo.insert! %Book{title: "A brief history of programming"}
    Repo.insert! %Book{title: "Something else"}

    conn = get conn, book_path(conn, :index_by_letter, "A")

    assert html_response(conn, 200) =~ "A brief history of programming"
    refute html_response(conn, 200) =~ "Something else"
  end

  test "if a book is checked out, index displays the name of the person who has checked out the book", %{conn: conn} do
    book = Repo.insert! %Book{title: "This book is checked out"}
    Ecto.build_assoc(book, :check_outs, borrower_name: "Becca")
    |> Repo.insert!

    conn = get conn, book_path(conn, :paginate, 1)

    assert html_response(conn, 200) =~ "Becca"
  end

  test "if a book is not checked out, index displays a link to check out the book", %{conn: conn} do
    Repo.insert! %Book{title: "This is my book"}

    conn = get conn, book_path(conn, :paginate, 1)

    assert html_response(conn, 200) =~ "Check out"
    assert html_response(conn, 200) =~ "This is my book"
  end

  test "if a book is checked out, the div has the class 'checked-out", %{conn: conn} do
    book = Repo.insert! %Book{title: "This book is checked out"}
    Ecto.build_assoc(book, :check_outs, borrower_name: "Becca")
    |> Repo.insert!

    conn = get conn, book_path(conn, :paginate, 1)

    assert html_response(conn, 200) =~ "checked-out"
  end

  test "if a book is not checked out, the div has the class 'available'", %{conn: conn} do
    Repo.insert! %Book{title: "This book is not checked out"}

    conn = get conn, book_path(conn, :paginate, 1)

    assert html_response(conn, 200) =~ "available"
  end

  test "given a list of tags, each tag is associated with the book", %{conn: conn} do
    params = %{title: "The book", author_firstname: "first", author_lastname: "last", year: 2016, tags_list: "nice, short, great"}

    conn
    |> assign(:current_user, @user)
    |> post(book_path(conn, :create), book: params)

    assert get_first_book(Repo.get_by(Tag, text: "nice")
                          |> Repo.preload(:books)).title == "The book"
    assert get_first_book(Repo.get_by(Tag, text: "short")
                          |> Repo.preload(:books)).title == "The book"
    assert get_first_book(Repo.get_by(Tag, text: "great")
                          |> Repo.preload(:books)).title == "The book"
  end

  test "the edit page for a book with tags shows the existing tags", %{conn: conn} do

    params = %{title: "The book", author_firstname: "first", author_lastname: "last", year: 2016, tags_list: "nice, short, great"}

    conn
    |> assign(:current_user, @user)
    |> post(book_path(conn, :create), book: params)

    book = List.first(Repo.all(Book))

    conn =
      conn
      |> assign(:current_user, @user)
      |> get(book_path(conn, :edit, book))

    assert html_response(conn, 200) =~ params.tags_list
  end

  test "a list of tags can be updated for a book", %{conn: conn} do
    params = %{title: "The book", author_firstname: "first", author_lastname: "last", year: 2016, tags_list: "nice, short, great"}

    conn
    |> assign(:current_user, @user)
    |> post(book_path(conn, :create), book: params)

    book = List.first(Repo.all(Book))
    updated_params = %{title: "The updated book", author_firstname: "first", author_lastname: "last", year: 2016, tags_list: "good"}

    conn
    |> assign(:current_user, @user)
    |> put(book_path(conn, :update, book), book: updated_params)
    updated_book = List.first(Repo.all(Book)) |> Repo.preload(:tags)

    assert length(updated_book.tags) == 1
  end

  test "when a book is updated with no tags, all tags are removed for that book", %{conn: conn} do
    params = %{title: "The book", author_firstname: "first", author_lastname: "last", year: 2016, tags_list: "nice, short, great"}

    conn
    |> assign(:current_user, @user)
    |> post(book_path(conn, :create), book: params)

    book = List.first(Repo.all(Book))
    updated_params = %{title: "The updated book", author_firstname: "first", author_lastname: "last", year: 2016, tags_list: ""}

    conn
    |> assign(:current_user, @user)
    |> put(book_path(conn, :update, book), book: updated_params)

    updated_book = List.first(Repo.all(Book)) |> Repo.preload(:tags)

    assert length(updated_book.tags) == 0
  end

  test "tags for each book are displayed on the books index page", %{conn: conn} do
    params = %{title: "The book", author_firstname: "first", author_lastname: "last", year: 2016, tags_list: "nice, short, great"}

    conn
    |> assign(:current_user, @user)
    |> post(book_path(conn, :create), book: params)

    conn = get conn, book_path(conn, :paginate, 1)

    assert html_response(conn, 200) =~ "nice"
    assert html_response(conn, 200) =~ "short"
    assert html_response(conn, 200) =~ "great"
  end

  test "each tag displayed on the index page is a link to its show page", %{conn: conn} do
    params = %{title: "The book", author_firstname: "first", author_lastname: "last", year: 2016, tags_list: "nice, short, great"}

    conn
    |> assign(:current_user, @user)
    |> post(book_path(conn, :create), book: params)

    conn = get conn, book_path(conn, :paginate, 1)
    book = List.first(Repo.all(Book)) |> Repo.preload(:tags)

    Enum.each(book.tags, fn(tag) ->
      assert html_response(conn, 200) =~ "/books/tags/#{tag.id}"
    end)
  end

  defp get_first_book(tag) do
    List.first(tag.books)
  end

  test "renders form to add a new book", %{conn: conn} do
    conn =
      conn
      |> assign(:current_user, @user)
      |> get(book_path(conn, :new))

    assert html_response(conn, 200) =~ "New book"
  end

  test "does not allow a non-logged in user to add a new book", %{conn: conn} do
    conn = get conn, book_path(conn, :new)

    assert redirected_to(conn) == "/"
  end

  test "creates new book and redirects when data is valid", %{conn: conn} do
    conn =
      conn
      |> assign(:current_user, @user)
      |> post(book_path(conn, :create), book: @valid_attrs)

    assert redirected_to(conn) == book_path(conn, :index)
    assert Repo.get_by(Book, @valid_attrs)
  end

  test "does not create book and renders errors when data is invalid", %{conn: conn} do
    conn =
      conn
      |> assign(:current_user, @user)
      |> post(book_path(conn, :create), book: @invalid_attrs)

    assert html_response(conn, 200) =~ "New book"
  end

  test "does not allow a non-logged in user to create a book", %{conn: conn} do
    conn = post conn, book_path(conn, :create), book: @valid_attrs

    assert redirected_to(conn) == "/"
  end

  test "renders form for editing a book", %{conn: conn} do
    book = Repo.insert! %Book{}

    conn =
      conn
      |> assign(:current_user, @user)
      |> get(book_path(conn, :edit, book))

    assert html_response(conn, 200) =~ "Edit book"
  end

  test "does not allow a non-logged in user to edit a book", %{conn: conn} do
    book = Repo.insert! %Book{}

    conn = get conn, book_path(conn, :edit, book)

    assert redirected_to(conn) == "/"
  end

  test "updates a book and redirects when data is valid", %{conn: conn} do
    book = Repo.insert! %Book{}

    conn =
      conn
      |> assign(:current_user, @user)
      |> put(book_path(conn, :update, book), book: @valid_attrs)

    assert redirected_to(conn) == book_path(conn, :index)
    assert Repo.get_by(Book, @valid_attrs)
  end

  test "does not update book and renders errors when data is invalid", %{conn: conn} do
    book = Repo.insert! %Book{}

    conn =
      conn
      |> assign(:current_user, @user)
      |> put(book_path(conn, :update, book), book: @invalid_attrs)

    assert html_response(conn, 200) =~ "Edit book"
  end

  test "does not allow a non-logged in user to update a book", %{conn: conn} do
    book = Repo.insert! %Book{}

    conn = put conn, book_path(conn, :delete, book)

    assert redirected_to(conn) == "/"
  end

  test "deletes a book", %{conn: conn} do
    book = Repo.insert! %Book{}

    conn =
      conn
      |> assign(:current_user, @user)
      |> delete(book_path(conn, :delete, book))

    assert redirected_to(conn) == book_path(conn, :index)
    refute Repo.get(Book, book.id)
   end

  test "does not allow a non-logged in user to delete a book", %{conn: conn} do
    book = Repo.insert! %Book{}

    conn = delete conn, book_path(conn, :delete, book)

    assert redirected_to(conn) == "/"
    assert Repo.get(Book, book.id)
  end

  test "renders checked_out page", %{conn: conn} do
    conn = get conn, "/books/checked_out"
    assert conn.status == 200
  end

  test "checked_out renders only books that are checked out", %{conn: conn} do
    checked_out_book = Repo.insert! %Book{title: "This book is checked out"}
    Repo.insert! %Book{title: "This book is not checked out"}

    check_out =
      Ecto.build_assoc(checked_out_book, :check_outs, borrower_name: "Person")
    Repo.insert!(check_out)

    conn = get conn, book_path(conn, :checked_out)
    assert html_response(conn, 200) =~ "This book is checked out"
    refute html_response(conn, 200) =~ "This book is not checked out"
  end

  test "checked_out displays the name of the person who has checked out the book", %{conn: conn} do
    checked_out_book = Repo.insert! %Book{title: "This book is checked out"}

    check_out =
      Ecto.build_assoc(checked_out_book, :check_outs, borrower_name: "Becca")
    Repo.insert!(check_out)

    conn = get conn, book_path(conn, :checked_out)
    assert html_response(conn, 200) =~ "Becca"
    refute html_response(conn, 200) =~ "This book is not checked out"
  end

  test "update_with_location updates the current location and returns the changed book", %{conn: conn} do
    book = Repo.insert! %Book{"current_location": "A place"}
    conn = post conn, book_check_out_path(conn, :create, book), check_out: %{"borrower_name": "Person"}
    updated_book = BookController.update_with_location(conn)

    assert is_nil(updated_book.current_location)
  end

  test "shows a form to return a book", %{conn: conn} do
    book = Repo.insert! %Book{}
    Ecto.build_assoc(book, :check_outs, borrower_name: "Person", borrower_id: @user.id)
    |> Repo.insert!

    conn =
      conn
      |> assign(:current_user, @user)
      |> get(book_path(conn, :return, book))

    assert conn.status == 200
  end

  test "only a user with a matching id can return a book", %{conn: conn} do
    book = Repo.insert! %Book{}
    Ecto.build_assoc(book, :check_outs, borrower_name: "Person", borrower_id: "different email")
    |> Repo.insert!

    conn = 
      conn
      |> assign(:current_user, @user)
      |> get(book_path(conn, :return, book))

     assert redirected_to(conn) == "/books"
  end
   
  test "updates the current location when returning a book with a valid location", %{conn: conn} do
    book = Repo.insert! %Book{}
    location = "Chicago"

    check_out =
      Ecto.build_assoc(book, :check_outs, borrower_name: "Person")
    Repo.insert!(check_out)

    conn =
      conn
      |> assign(:current_user, @user)
      |> post(book_path(conn, :process_return, book), book: %{current_location: location})

    assert redirected_to(conn) == book_path(conn, :index)
    assert Repo.get(Book, book.id).current_location == location
  end

  test "adds a return date to a check_out record when returning a book", %{conn: conn} do
    book = Repo.insert! %Book{}
    location = "Chicago"

    check_out =
      Ecto.build_assoc(book, :check_outs, borrower_name: "Person")
      |> Repo.insert!

    conn
    |> assign(:current_user, @user)
    |> post(book_path(conn, :process_return, book), book: %{current_location: location})

    assert Repo.get(Bookish.CheckOut, check_out.id).return_date
  end

  test "once a book is returned, it is no longer checked out", %{conn: conn} do
    book = Repo.insert! %Book{}
    Ecto.build_assoc(book, :check_outs, borrower_name: "Person")
    |> Repo.insert!

    assert ResourceController.set_attributes(book).checked_out

    conn
    |> assign(:current_user, @user)
    |> post(book_path(conn, :process_return, book), book: %{current_location: "Chicago"})

    refute ResourceController.set_attributes(book).checked_out
  end
end
