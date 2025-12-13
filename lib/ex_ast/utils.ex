defmodule ExAst.Utils do
  @moduledoc """
  Shared utility functions for code extraction.
  """

  @doc """
  Convert a module atom to its Elixir string representation.

  Removes the "Elixir." prefix that Erlang adds to Elixir module names.

  ## Examples

      iex> module_to_string(MyApp.Foo)
      "MyApp.Foo"

      iex> module_to_string(:code)
      "code"

  """
  @spec module_to_string(module()) :: String.t()
  def module_to_string(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.replace_leading("Elixir.", "")
  end
end
