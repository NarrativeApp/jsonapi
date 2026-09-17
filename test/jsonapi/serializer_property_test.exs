defmodule JSONAPI.SerializerPropertyTest do
  @moduledoc """
  Properties of `JSONAPI.Serializer.serialize/5` for collections.

  The list clause of `encode_data/5` must behave exactly like serializing
  each element on its own and concatenating: same resources, same order,
  same `included`. These pin that down for arbitrary lists, including the
  degenerate cases (empty list, duplicate resources, duplicate includes)
  that a hand-written example test tends to miss.
  """

  # Not async: the views read process-global Application env
  # (:remove_links, :field_transformation, :namespace, ...) that other test
  # modules mutate with put_env/delete_env.
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias JSONAPI.Serializer

  @max_runs 25

  defmodule UserView do
    use JSONAPI.View, type: "user"

    def fields, do: [:username]
  end

  defmodule CommentView do
    use JSONAPI.View, type: "comment"

    def fields, do: [:text]
    def relationships, do: [user: {JSONAPI.SerializerPropertyTest.UserView, :include}]
  end

  defmodule PostView do
    use JSONAPI.View, type: "post"

    def fields, do: [:title, :body]
    def meta(data, _conn), do: %{title_length: String.length(data.title)}

    def relationships do
      [
        author: {JSONAPI.SerializerPropertyTest.UserView, :include},
        comments: {JSONAPI.SerializerPropertyTest.CommentView, :include}
      ]
    end
  end

  # Small id space on purpose so that lists routinely contain repeated
  # resources; `included` must still be deduplicated in first-seen order.
  defp id, do: integer(1..20)

  # Users and comments are drawn from small fixed pools rather than generated
  # with random attributes, so that structurally identical includes recur and
  # the dedup path in `flatten_included/1` is actually exercised.
  @users for i <- 1..5, do: %{id: i, username: "user#{i}"}
  @comments for i <- 1..8, u <- @users, do: %{id: i, text: "comment #{i}", user: u}

  defp user, do: member_of(@users)
  defp comment, do: member_of(@comments)

  defp post do
    gen all(
          id <- id(),
          title <- string(:printable, max_length: 20),
          body <- string(:printable, max_length: 40),
          author <- one_of([constant(nil), user()]),
          comments <- list_of(comment(), max_length: 4)
        ) do
      %{id: id, title: title, body: body, author: author, comments: comments}
    end
  end

  defp conn, do: Plug.Conn.fetch_query_params(%Plug.Conn{host: "example.com"})

  defp expected_included(posts, conn) do
    posts
    |> Enum.map(&Serializer.serialize(PostView, &1, conn)[:included])
    |> Serializer.flatten_included()
  end

  property "serializing a list yields each element's resource, in order" do
    check all(posts <- list_of(post(), max_length: 30), max_runs: @max_runs) do
      conn = conn()
      encoded = Serializer.serialize(PostView, posts, conn)

      expected = Enum.map(posts, &Serializer.serialize(PostView, &1, conn)[:data])

      assert encoded[:data] == expected
    end
  end

  property "included for a list is the deduplicated, in-order union of each element's included" do
    check all(posts <- list_of(post(), max_length: 30), max_runs: @max_runs) do
      conn = conn()
      encoded = Serializer.serialize(PostView, posts, conn)

      assert encoded[:included] == expected_included(posts, conn)
    end
  end

  property "serializing a list is invariant to how it is split into chunks" do
    check all(
            posts <- list_of(post(), min_length: 1, max_length: 30),
            chunk <- integer(1..30),
            max_runs: @max_runs
          ) do
      conn = conn()
      whole = Serializer.serialize(PostView, posts, conn)

      chunked =
        Enum.map(Enum.chunk_every(posts, chunk), &Serializer.serialize(PostView, &1, conn))

      assert whole[:data] == Enum.flat_map(chunked, & &1[:data])

      assert whole[:included] ==
               chunked |> Enum.map(& &1[:included]) |> Serializer.flatten_included()
    end
  end
end
