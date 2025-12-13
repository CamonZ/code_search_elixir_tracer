defmodule CodeIntelligenceTracer.StringFormatting do
  @moduledoc """
  Utilities for consistent string formatting and composition.

  Provides reusable functions for common string formatting patterns
  like joining lists with separators, mapping and joining, and handling
  empty/non-empty cases consistently.
  """

  @doc """
  Join a list of items with a separator, applying a formatter to each item.

  This is a convenience wrapper around Enum.map_join that improves readability
  for common formatting patterns.

  ## Examples

      iex> join_map(["a", "b", "c"], ", ", &String.upcase/1)
      "A, B, C"

      iex> join_map([], ", ", &String.upcase/1)
      ""

  """
  @spec join_map(list(), String.t(), (term() -> String.t())) :: String.t()
  def join_map(items, separator, formatter) do
    Enum.map_join(items, separator, formatter)
  end

  @doc """
  Format a list and join with a separator, or return default for empty list.

  Useful for patterns where empty lists should return a specific value
  like an empty string or nil.

  ## Examples

      iex> join_map_or([1, 2, 3], ", ", &to_string/1, "")
      "1, 2, 3"

      iex> join_map_or([], ", ", &to_string/1, "")
      ""

      iex> join_map_or([], ", ", &to_string/1, "nil")
      "nil"

  """
  @spec join_map_or(list(), String.t(), (term() -> String.t()), String.t()) :: String.t()
  def join_map_or([], _separator, _formatter, default), do: default
  def join_map_or(items, separator, formatter, _default) do
    join_map(items, separator, formatter)
  end

  @doc """
  Join items with a separator, handling single item and empty list cases.

  Useful for patterns where single items and multiple items need different handling.

  ## Examples

      iex> join_with_separator([1], " and ", &to_string/1)
      "1"

      iex> join_with_separator([1, 2], " and ", &to_string/1)
      "1 and 2"

      iex> join_with_separator([], " and ", &to_string/1)
      ""

  """
  @spec join_with_separator(list(), String.t(), (term() -> String.t())) :: String.t()
  def join_with_separator([], _separator, _formatter), do: ""
  def join_with_separator([single], _separator, formatter), do: formatter.(single)
  def join_with_separator(items, separator, formatter) do
    join_map(items, separator, formatter)
  end

  @doc """
  Wrap a value with prefix and suffix strings.

  Useful for formatting with parentheses, brackets, etc.

  ## Examples

      iex> wrap("int", "(", ")")
      "(int)"

      iex> wrap("", "(", ")")
      "()"

  """
  @spec wrap(String.t(), String.t(), String.t()) :: String.t()
  def wrap(value, prefix, suffix) do
    "#{prefix}#{value}#{suffix}"
  end

  @doc """
  Conditionally wrap a value based on a predicate.

  Useful for conditionally adding parentheses or other wrappers.

  ## Examples

      iex> wrap_if("int", "(", ")", &String.starts_with?(&1, ":"))
      "int"

      iex> wrap_if(":ok", "(", ")", &String.starts_with?(&1, ":"))
      "(:ok)"

  """
  @spec wrap_if(String.t(), String.t(), String.t(), (String.t() -> boolean())) :: String.t()
  def wrap_if(value, prefix, suffix, predicate) do
    if predicate.(value) do
      wrap(value, prefix, suffix)
    else
      value
    end
  end

  @doc """
  Join formatted items, with custom handling for empty list.

  Combines list formatting with a custom fallback for empty lists.

  ## Examples

      iex> format_list(["a", "b"], ", ", &String.upcase/1, "empty")
      "A, B"

      iex> format_list([], ", ", &String.upcase/1, "empty")
      "empty"

  """
  @spec format_list(list(), String.t(), (term() -> String.t()), String.t()) :: String.t()
  def format_list([], _separator, _formatter, empty_default), do: empty_default
  def format_list(items, separator, formatter, _empty_default) do
    join_map(items, separator, formatter)
  end

end
