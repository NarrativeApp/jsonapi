defmodule JSONAPI.Utils.String do
  @moduledoc """
  String manipulation helpers.
  """

  @allowed_transformations [:camelize, :dasherize, :underscore]

  defguardp is_alnum(c) when c in ?a..?z or c in ?A..?Z or c in ?0..?9

  @doc """
  Replace dashes between words in `value` with underscores

  Ignores dashes that are not between letters/numbers

  ## Examples

      iex> underscore("top-posts")
      "top_posts"

      iex> underscore(:top_posts)
      "top_posts"

      iex> underscore("-top-posts")
      "-top_posts"

      iex> underscore("-top--posts-")
      "-top--posts-"

      iex> underscore("corgiAge")
      "corgi_age"

  """
  @spec underscore(atom) :: String.t()
  def underscore(value) when is_atom(value) do
    value
    |> to_string()
    |> underscore()
  end

  @spec underscore(String.t()) :: String.t()
  def underscore(<<>>), do: <<>>
  def underscore(value) when is_binary(value), do: underscore_scan(value, value, 0, nil)

  # Both transformations below are byte walks rather than the regexes they
  # replace, because Regex.replace/3 re-checks the PCRE version and
  # re-parses its replacement string on every call, which dominated the
  # cost of serialising large collections. Each reproduces its regexes
  # exactly, including that a regex consumes the byte after a match, so
  # that byte can never start another match.
  #
  # The walk first scans for the first byte that would change; if there is
  # none the input is returned as-is, with no allocation. Otherwise the
  # untouched prefix is kept as a sub-binary and only the rest is rebuilt.
  #
  # For underscore/1 the two regexes ran as separate passes, so two
  # "previous byte" values are carried: `dash` is what the dash pass last
  # saw and `camel` what the camel-case pass last saw. Lower-casing is done
  # inline for ASCII; String.downcase/1 runs at the end only if a non-ASCII
  # byte was seen, since only then can it differ.
  defp underscore_scan(value, <<>>, _i, _prev), do: value

  defp underscore_scan(value, <<c, _::binary>>, i, prev)
       when c in ?A..?Z or c > 127 or (c == ?- and is_alnum(prev)) do
    rest = binary_part(value, i, byte_size(value) - i)
    underscore_walk(rest, prev, prev, [binary_part(value, 0, i)], true)
  end

  defp underscore_scan(value, <<c, rest::binary>>, i, _prev),
    do: underscore_scan(value, rest, i + 1, c)

  defp underscore_walk(<<>>, _dash, _camel, acc, true),
    do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp underscore_walk(<<>>, _dash, _camel, acc, false),
    do: acc |> Enum.reverse() |> IO.iodata_to_binary() |> String.downcase()

  defp underscore_walk(<<?-, next, rest::binary>>, dash, _camel, acc, ascii?)
       when is_alnum(dash) and is_alnum(next) do
    underscore_walk(rest, nil, next, [lower(next), ?_ | acc], ascii?)
  end

  defp underscore_walk(<<c, rest::binary>>, _dash, camel, acc, ascii?)
       when c in ?A..?Z and (camel in ?a..?z or camel in ?0..?9) do
    underscore_walk(rest, c, nil, [c + 32, ?_ | acc], ascii?)
  end

  defp underscore_walk(<<c, rest::binary>>, _dash, _camel, acc, ascii?) when c < 128,
    do: underscore_walk(rest, c, c, [lower(c) | acc], ascii?)

  defp underscore_walk(<<c, rest::binary>>, _dash, _camel, acc, _ascii?),
    do: underscore_walk(rest, c, c, [c | acc], false)

  defp lower(c) when c in ?A..?Z, do: c + 32
  defp lower(c), do: c

  @doc """
  Replace underscores between words in `value` with dashes

  Ignores underscores that are not between letters/numbers

  ## Examples

      iex> dasherize("top_posts")
      "top-posts"

      iex> dasherize("_top_posts")
      "_top-posts"

      iex> dasherize("_top__posts_")
      "_top__posts_"

  """
  @spec dasherize(atom) :: String.t()
  def dasherize(value) when is_atom(value) do
    value
    |> to_string()
    |> dasherize()
  end

  @spec dasherize(String.t()) :: String.t()
  def dasherize(<<>>), do: <<>>
  def dasherize(value) when is_binary(value), do: dasherize_scan(value, value, 0, nil)

  # An underscore between two alphanumerics becomes a dash. See
  # underscore_scan/4 for the scan-then-walk shape.
  defp dasherize_scan(value, <<>>, _i, _prev), do: value

  defp dasherize_scan(value, <<?_, next, rest::binary>>, i, prev)
       when is_alnum(prev) and is_alnum(next) do
    dasherize_walk(rest, nil, [next, ?-, binary_part(value, 0, i)])
  end

  defp dasherize_scan(value, <<c, rest::binary>>, i, _prev),
    do: dasherize_scan(value, rest, i + 1, c)

  defp dasherize_walk(<<>>, _prev, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp dasherize_walk(<<?_, next, rest::binary>>, prev, acc)
       when is_alnum(prev) and is_alnum(next) do
    dasherize_walk(rest, nil, [next, ?- | acc])
  end

  defp dasherize_walk(<<c, rest::binary>>, _prev, acc), do: dasherize_walk(rest, c, [c | acc])

  @doc """
  Replace underscores or dashes between words in `value` with camelCasing

  Ignores underscores or dashes that are not between letters/numbers

  ## Examples

      iex> camelize("top_posts")
      "topPosts"

      iex> camelize(:top_posts)
      "topPosts"

      iex> camelize("_top_posts")
      "_topPosts"

      iex> camelize("_top__posts_")
      "_top__posts_"

  """
  @spec camelize(atom) :: String.t()
  def camelize(value) when is_atom(value) do
    value
    |> to_string()
    |> camelize()
  end

  @spec camelize(String.t()) :: String.t()
  def camelize(value) when is_binary(value) do
    with words <-
           Regex.split(
             ~r{(?<=[a-zA-Z0-9])[-_](?=[a-zA-Z0-9])},
             to_string(value)
           ) do
      [h | t] = words |> Enum.filter(&(&1 != ""))

      [String.downcase(h) | camelize_list(t)]
      |> Enum.join()
    end
  end

  defp camelize_list([]), do: []

  defp camelize_list([h | t]) do
    [String.capitalize(h)] ++ camelize_list(t)
  end

  @doc """

  ## Examples

      iex> expand_fields(%{"foo-bar" => "baz"}, &underscore/1)
      %{"foo_bar" => "baz"}

      iex> expand_fields(%{"foo_bar" => "baz"}, &dasherize/1)
      %{"foo-bar" => "baz"}

      iex> expand_fields(%{"foo-bar" => "baz"}, &camelize/1)
      %{"fooBar" => "baz"}

      iex> expand_fields({"foo-bar", "dollar-sol"}, &underscore/1)
      {"foo_bar", "dollar-sol"}

      iex> expand_fields({"foo-bar", %{"a-d" => "z-8"}}, &underscore/1)
      {"foo_bar", %{"a_d" => "z-8"}}

      iex> expand_fields(%{"f-b" => %{"a-d" => "z"}, "c-d" => "e"}, &underscore/1)
      %{"f_b" => %{"a_d" => "z"}, "c_d" => "e"}

      iex> expand_fields(%{"f-b" => %{"a-d" => %{"z-w" => "z"}}, "c-d" => "e"}, &underscore/1)
      %{"f_b" => %{"a_d" => %{"z_w" => "z"}}, "c_d" => "e"}

      iex> expand_fields(:"foo-bar", &underscore/1)
      "foo_bar"

      iex> expand_fields(:foo_bar, &dasherize/1)
      "foo-bar"

      iex> expand_fields(:"foo-bar", &camelize/1)
      "fooBar"

      iex> expand_fields(%{"f-b" => "a-d"}, &underscore/1)
      %{"f_b" => "a-d"}

      iex> expand_fields(%{"inserted-at" => ~N[2019-01-17 03:27:24.776957]}, &underscore/1)
      %{"inserted_at" => ~N[2019-01-17 03:27:24.776957]}

      iex> expand_fields(%{"xValue" => 123}, &underscore/1)
      %{"x_value" => 123}

      iex> expand_fields(%{"attributes" => %{"corgiName" => "Wardel"}}, &underscore/1)
      %{"attributes" => %{"corgi_name" => "Wardel"}}

      iex> expand_fields(%{"attributes" => %{"corgiName" => ["Wardel"]}}, &underscore/1)
      %{"attributes" => %{"corgi_name" => ["Wardel"]}}

      iex> expand_fields(%{"attributes" => %{"someField" => ["SomeValue", %{"nestedField" => "Value"}]}}, &underscore/1)
      %{"attributes" => %{"some_field" => ["SomeValue", %{"nested_field" => "Value"}]}}

      iex> expand_fields([%{"fooBar" => "a"}, %{"fooBar" => "b"}], &underscore/1)
      [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]

      iex> expand_fields([%{"foo_bar" => "a"}, %{"foo_bar" => "b"}], &camelize/1)
      [%{"fooBar" => "a"}, %{"fooBar" => "b"}]

      iex> expand_fields(%{"fooAttributes" => [%{"fooBar" => "a"}, %{"fooBar" => "b"}]}, &underscore/1)
      %{"foo_attributes" => [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]}

      iex> expand_fields(%{"foo_attributes" => [%{"foo_bar" => "a"}, %{"foo_bar" => "b"}]}, &camelize/1)
      %{"fooAttributes" => [%{"fooBar" => "a"}, %{"fooBar" => "b"}]}
  """
  @spec expand_fields(map, function) :: map
  def expand_fields(%{__struct__: _} = value, _fun), do: value

  def expand_fields(map, fun) when is_map(map) do
    Enum.into(map, %{}, &expand_fields(&1, fun))
  end

  @spec expand_fields(list, function) :: list
  def expand_fields(values, fun) when is_list(values) do
    Enum.map(values, &expand_fields(&1, fun))
  end

  @spec expand_fields(tuple, function) :: tuple
  def expand_fields({key, value}, fun) when is_map(value) do
    {fun.(key), expand_fields(value, fun)}
  end

  def expand_fields({key, value}, fun) when is_list(value) do
    {fun.(key), maybe_expand_fields(value, fun)}
  end

  def expand_fields({key, value}, fun) do
    {fun.(key), value}
  end

  @spec expand_fields(String.t(), function) :: map
  def expand_fields(value, fun) when is_binary(value) or is_atom(value) do
    fun.(value)
  end

  def expand_fields(value, _fun) do
    value
  end

  defp maybe_expand_fields(values, fun) when is_list(values) do
    Enum.map(values, fn
      string when is_binary(string) -> string
      value -> expand_fields(value, fun)
    end)
  end

  @doc """
  The configured transformation for the API's fields. JSON:API v1.1 recommends
  using camlized fields (e.g. "goodDog", versus "good_dog").  However, we don't hold a strong
  opinion, so feel free to customize it how you would like (e.g. "good-dog", versus "good_dog").

  This library currently supports camelized, dashed and underscored fields.

  ## Configuration examples

  camelCase fields:

  ```
  config :jsonapi, field_transformation: :camelize
  ```

  Dashed fields:

  ```
  config :jsonapi, field_transformation: :dasherize
  ```

  Underscored fields:

  ```
  config :jsonapi, field_transformation: :underscore
  ```
  """
  def field_transformation do
    field_transformation(Application.get_env(:jsonapi, :field_transformation))
  end

  @doc false
  def field_transformation(nil), do: nil

  def field_transformation(transformation) when transformation in @allowed_transformations,
    do: transformation
end
