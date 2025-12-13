defmodule TestSupport.GuardedFunctions do
  @moduledoc """
  Test fixture module with guarded functions for testing guard extraction.
  """

  # Single clause, no guard
  def no_guard(x), do: x

  # Single clause with guard
  def single_guard(x) when is_binary(x), do: "string: #{x}"

  # Multiple clauses with guards
  def multi_guard(x) when is_binary(x), do: "string"
  def multi_guard(x) when is_number(x), do: "number"
  def multi_guard(_x), do: "other"

  # Compound guard
  def compound_guard(x) when is_integer(x) and x > 0, do: "positive integer"
  def compound_guard(x) when is_integer(x) and x < 0, do: "negative integer"
  def compound_guard(_x), do: "zero or not integer"

  # Multiple guards with `or`
  def or_guard(x) when is_binary(x) or is_atom(x), do: "string or atom"
  def or_guard(_x), do: "other"

  # Pattern matching with guards
  def pattern_with_guard({:ok, value}) when is_list(value), do: {:ok, length(value)}
  def pattern_with_guard({:ok, value}), do: {:ok, value}
  def pattern_with_guard({:error, _} = err), do: err

  # Mixed guard with both and/or operators
  def mixed_guard(x) when (is_integer(x) or is_float(x)) and x > 0, do: "positive number"
  def mixed_guard(_), do: "other"
end
