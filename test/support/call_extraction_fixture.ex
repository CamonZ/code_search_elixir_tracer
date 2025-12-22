defmodule CallExtractionFixture do
  @moduledoc """
  Test fixture for verifying call extraction from individual BEAM files.
  Contains both local (internal) and remote (external) function calls.
  """

  @doc """
  Public function that makes a remote call to String.upcase/1
  and a local call to format_greeting/1.
  """
  def greet(name) do
    uppercased = String.upcase(name)
    format_greeting(uppercased)
  end

  @doc """
  Public function that makes remote calls to Enum functions
  and a local call to sum_helper/1.
  """
  def process_list(items) do
    items
    |> Enum.map(&(&1 * 2))
    |> Enum.filter(&(&1 > 10))
    |> sum_helper()
  end

  @doc """
  Public function with a local recursive call.
  """
  def factorial(0), do: 1

  def factorial(n) when n > 0 do
    n * factorial(n - 1)
  end

  # Private helper function - target of local calls
  defp format_greeting(name) do
    "Hello, #{name}!"
  end

  # Private helper function - target of local calls
  defp sum_helper(list) do
    Enum.sum(list)
  end
end
