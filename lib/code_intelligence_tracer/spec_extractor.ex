defmodule CodeIntelligenceTracer.SpecExtractor do
  @moduledoc """
  Extracts @spec and @callback definitions from BEAM file abstract_code chunks.

  Parses the Erlang abstract format to find spec and callback attributes,
  extracting function name, arity, kind, line number, and raw clause data
  for further processing.
  """

  @type spec_record :: %{
          name: atom(),
          arity: non_neg_integer(),
          kind: :spec | :callback,
          line: non_neg_integer(),
          clauses: [tuple()]
        }

  @doc """
  Extract specs and callbacks from BEAM chunks.

  Parses the `:abstract_code` chunk to find `@spec` and `@callback` definitions.

  Returns a list of spec records with:
  - `:name` - function name as atom
  - `:arity` - function arity
  - `:kind` - `:spec` or `:callback`
  - `:line` - source line number
  - `:clauses` - raw type clause data for parsing

  Returns an empty list if no abstract_code chunk is available.

  ## Examples

      iex> {:ok, {_mod, chunks}} = BeamReader.read_chunks("path/to/Module.beam")
      iex> extract_specs(chunks)
      [%{name: :my_func, arity: 2, kind: :spec, line: 10, clauses: [...]}]

  """
  @spec extract_specs(map()) :: [spec_record()]
  def extract_specs(chunks) do
    case chunks[:abstract_code] do
      {:raw_abstract_v1, forms} ->
        extract_from_forms(forms)

      nil ->
        []

      _other ->
        []
    end
  end

  defp extract_from_forms(forms) do
    forms
    |> Enum.filter(&spec_or_callback?/1)
    |> Enum.map(&parse_spec_attribute/1)
    |> Enum.reject(&is_nil/1)
  end

  defp spec_or_callback?({:attribute, _, :spec, _}), do: true
  defp spec_or_callback?({:attribute, _, :callback, _}), do: true
  defp spec_or_callback?(_), do: false

  defp parse_spec_attribute({:attribute, line, kind, {{name, arity}, clauses}})
       when kind in [:spec, :callback] do
    %{
      name: name,
      arity: arity,
      kind: kind,
      line: line,
      clauses: clauses
    }
  end

  # Handle edge cases with unexpected format
  defp parse_spec_attribute(_), do: nil
end
