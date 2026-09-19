defmodule JSONAPI.Utils.StringTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  import JSONAPI.Utils.String

  doctest JSONAPI.Utils.String

  # The regex implementations these functions replaced. They are the
  # specification: the byte walks must produce identical output for any
  # input, including the regexes' habit of consuming the byte after a match
  # (so "a_a_a" dasherizes to "a-a_a", not "a-a-a").
  defmodule Reference do
    def underscore(value) do
      value
      |> String.replace(~r/([a-zA-Z\d])-([a-zA-Z\d])/, "\\1_\\2")
      |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
      |> String.downcase()
    end

    def dasherize(value) do
      String.replace(value, ~r/([a-zA-Z0-9])_([a-zA-Z0-9])/, "\\1-\\2")
    end
  end

  # Biased towards the bytes the transformations care about (letters of both
  # cases, digits, `_`, `-`) with a few bystanders, then mixed with arbitrary
  # printable strings so multi-byte characters and long runs are covered.
  defp key_string do
    one_of([
      string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ?., ?\s], max_length: 24),
      string(:printable, max_length: 24),
      gen all(
            parts <- list_of(string(:alphanumeric, max_length: 6), max_length: 6),
            sep <- member_of(["_", "-", "__", "--", "_-"])
          ) do
        Enum.join(parts, sep)
      end
    ])
  end

  defp snake_case_key do
    gen all(
          parts <-
            list_of(string([?a..?z, ?0..?9], min_length: 1, max_length: 8),
              min_length: 1,
              max_length: 5
            )
        ) do
      Enum.join(parts, "_")
    end
  end

  describe "dasherize/1" do
    property "matches the regex implementation for any string" do
      check all(value <- key_string(), max_runs: 2_000) do
        assert dasherize(value) == Reference.dasherize(value)
      end
    end

    property "only ever replaces bytes, so length is preserved" do
      check all(value <- key_string()) do
        assert byte_size(dasherize(value)) == byte_size(value)
      end
    end
  end

  describe "underscore/1" do
    property "matches the regex implementation for any string" do
      check all(value <- key_string(), max_runs: 2_000) do
        assert underscore(value) == Reference.underscore(value)
      end
    end

    property "is a left inverse of dasherize/1 on snake_case keys" do
      check all(key <- snake_case_key()) do
        assert key |> dasherize() |> underscore() == key
      end
    end
  end
end
