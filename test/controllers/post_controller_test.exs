defmodule Pxblog.PostControllerTest do
  use Pxblog.ConnCase

  alias Pxblog.Post
  alias Pxblog.TestHelper
  alias Pxblog.Factory

  @valid_attrs %{body: "some content", title: "some content"}
  @invalid_attrs %{}

  setup do
    role = Factory.create(:role)
    user = Factory.create(:user, role: role)
    post = Factory.create(:post, user: user)

    admin_role = Factory.create(:role, admin: true)
    admin_user = Factory.create(:user, role: admin_role)

    other_user = Factory.create(:user, role: role)

    conn = conn() |> login_user(user)
    {:ok, conn: conn, user: user, role: role, post: post, admin: admin_user, other_user: other_user}
  end

  defp login_user(conn, user) do
    post conn, session_path(conn, :create), user: %{
      username: user.username,
      password: user.password
    }
  end

  defp logout_user(conn, user) do
    delete conn, session_path(conn, :delete, user)
  end

  defp build_post(user) do
    changeset = user
    |> build_assoc(:posts)
    |> Post.changeset(@valid_attrs)
    Repo.insert!(changeset)
  end

  test "lists all entries on index", %{conn: conn, user: user} do
    conn = get conn, user_post_path(conn, :index, user)
    assert html_response(conn, 200) =~ "Posts"
  end

  test "renders form for new resources", %{conn: conn, user: user} do
    conn = get conn, user_post_path(conn, :new, user)
    assert html_response(conn, 200) =~ "New post"
  end

  test "creates resource and redirects when data is valid", %{conn: conn, user: user} do
    conn = post conn, user_post_path(conn, :create,user), post: @valid_attrs
    assert redirected_to(conn) == user_post_path(conn, :index, user)
    assert Repo.get_by(assoc(user,:posts), @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn, user: user} do
    conn = post conn, user_post_path(conn, :create, user), post: @invalid_attrs
    assert html_response(conn, 200) =~ "New post"
  end

  test "when logged in as the author, shows chosen resource with author flag set to true", %{conn: conn, user: user} do
    post = build_post(user)
    conn = login_user(conn, user) |> get(user_post_path(conn, :show, user, post))
    assert html_response(conn, 200) =~ "Show post"
    assert conn.assigns[:author_or_admin]
  end

  test "when logged in as an admin, shows chosen resource with author flag set to true", %{conn: conn, user: user, admin: admin} do
    post = build_post(user)
    conn = login_user(conn, admin) |> get(user_post_path(conn, :show, user, post))
    assert html_response(conn, 200) =~ "Show post"
    assert conn.assigns[:author_or_admin]
  end

  test "when not logged in, shows chosen resource with author flag set to false", %{conn: conn, user: user} do
    post = build_post(user)
    conn = logout_user(conn, user) |> get(user_post_path(conn, :show, user, post))
    assert html_response(conn, 200) =~ "Show post"
    refute conn.assigns[:author_or_admin]
  end

  test "when logged in as a different user, shows chosen resource with author flag set to false", %{conn: conn, user: user, other_user: other_user} do
    post = build_post(user)
    conn = login_user(conn, other_user) |> get(user_post_path(conn, :show, user, post))
    assert html_response(conn, 200) =~ "Show post"
    refute conn.assigns[:author_or_admin]
  end

  test "renders page not found when id is nonexistent", %{conn: conn, user: user} do
    assert_raise Ecto.NoResultsError, fn ->
      get conn, user_post_path(conn, :show, user, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn, user: user, post: post} do
    conn = get conn, user_post_path(conn, :edit, user, post)
    assert html_response(conn, 200) =~ "Edit post"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn, user: user, post: post} do
    conn = put conn, user_post_path(conn, :update,user, post), post: @valid_attrs
    assert redirected_to(conn) == user_post_path(conn, :show, user, post)
    assert Repo.get_by(Post, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn, user: user,post: post} do
    conn = put conn, user_post_path(conn, :update, user, post), post: %{"body" => nil}
    assert html_response(conn, 200) =~ "Edit post"
  end

  test "deletes chosen resource", %{conn: conn, user: user, post: post} do
    conn = delete conn, user_post_path(conn, :delete, user, post)
    assert redirected_to(conn) == user_post_path(conn, :index, user)
    refute Repo.get(Post, post.id)
  end

  test "redirects when the specified user does not exist", %{conn: conn} do
    conn = get conn, user_post_path(conn, :index, -1)
    assert get_flash(conn,:error) == "Invalid user!"
    assert redirected_to(conn) == page_path(conn, :index)
    assert conn.halted
  end

  test "redirets when trying to edit a post for a different user", %{conn: conn, user: _user, role: role, post: _post} do
    {:ok, other_user} = TestHelper.create_user(role, %{email: "test2@test.com",
                                                      username: "test2",
                                                      password: "test",
                                                      password_confirmation: "test"})
    {:ok, other_post} = TestHelper.create_post(other_user,%{title: "Test Title", body: "Test Body"})
    conn = get conn, user_post_path(conn, :edit, other_user, other_post)
    assert get_flash(conn, :error) == "You are not authorized to modify that post!"
    assert redirected_to(conn) == page_path(conn, :index)
    assert conn.halted

    # other_user = User.changeset(%User{},
    #   %{email: "test2@test.com",
    #     username: "test2",
    #     password: "test",
    #     password_confirmation: "test"})
    # |> Repo.insert!
    # post = build_post(other_user)
    # conn = get conn, user_post_path(conn, :edit, other_user, post)
    # assert get_flash(conn, :error) == "You are not authorized to modify that post!"
    # assert redirected_to(conn) == page_path(conn, :index)
    # assert conn.halted
  end

  test "redirects when trying to update a post for a different user", %{conn: conn, role: role, post: post} do
    {:ok, other_user} = TestHelper.create_user(role, %{email: "test2@test.com", username: "test2", password: "test", password_confirmation: "test"})
    conn = put conn, user_post_path(conn, :update, other_user, post), %{"post" => @valid_attrs}
    assert get_flash(conn, :error) == "You are not authorized to modify that post!"
    assert redirected_to(conn) == page_path(conn, :index)
    assert conn.halted
  end

  test "redirects when trying to delete a post for a different user", %{conn: conn, role: role, post: post} do
    {:ok, other_user} = TestHelper.create_user(role, %{email: "test2@test.com", username: "test2", password: "test", password_confirmation: "test"})
    conn = delete conn, user_post_path(conn, :delete, other_user, post)
    assert get_flash(conn, :error) == "You are not authorized to modify that post!"
    assert redirected_to(conn) == page_path(conn, :index)
    assert conn.halted
  end

  test "renders form for editing chosen resource when logged in as admin", %{conn: conn, user: user, post: post} do
    {:ok, role}  = TestHelper.create_role(%{name: "Admin", admin: true})
    {:ok, admin} = TestHelper.create_user(role, %{username: "admin", email: "admin@test.com", password: "test", password_confirmation: "test"})
    conn =
      login_user(conn, admin)
      |> get(user_post_path(conn, :edit, user, post))
    assert html_response(conn, 200) =~ "Edit post"
  end

  test "updates chosen resource and redirects when data is valid when logged in as admin", %{conn: conn, user: user, post: post} do
    {:ok, role}  = TestHelper.create_role(%{name: "Admin", admin: true})
    {:ok, admin} = TestHelper.create_user(role, %{username: "admin", email: "admin@test.com", password: "test", password_confirmation: "test"})
    conn =
      login_user(conn, admin)
      |> put(user_post_path(conn, :update, user, post), post: @valid_attrs)
    assert redirected_to(conn) == user_post_path(conn, :show, user, post)
    assert Repo.get_by(Post, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid when logged in as admin", %{conn: conn, user: user, post: post} do
    {:ok, role}  = TestHelper.create_role(%{name: "Admin", admin: true})
    {:ok, admin} = TestHelper.create_user(role, %{username: "admin", email: "admin@test.com", password: "test", password_confirmation: "test"})
    conn =
      login_user(conn, admin)
      |> put(user_post_path(conn, :update, user, post), post: %{"body" => nil})
    assert html_response(conn, 200) =~ "Edit post"
  end

  test "deletes chosen resource when logged in as admin", %{conn: conn, user: user, post: post} do
    {:ok, role}  = TestHelper.create_role(%{name: "Admin", admin: true})
    {:ok, admin} = TestHelper.create_user(role, %{username: "admin", email: "admin@test.com", password: "test", password_confirmation: "test"})
    conn =
      login_user(conn, admin)
      |> delete(user_post_path(conn, :delete, user, post))
    assert redirected_to(conn) == user_post_path(conn, :index, user)
    refute Repo.get(Post, post.id)
  end
end
