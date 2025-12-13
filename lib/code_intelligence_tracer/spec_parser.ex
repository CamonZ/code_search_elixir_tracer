defmodule CodeIntelligenceTracer.SpecParser do
  alias CodeIntelligenceTracer.TypeAst

  @moduledoc """
  Parse @spec and @callback definitions from BEAM bytecode.

  Extracts specs and callbacks from BEAM file abstract_code chunks,
  parsing raw Erlang abstract format into structured spec records.
  """

  @type spec_record :: %{
          name: atom(),
          arity: non_neg_integer(),
          kind: :spec | :callback,
          line: non_neg_integer(),
          clauses: [tuple()]
        }

  @type parsed_clause :: %{
          inputs: [TypeAst.type_ast()],
          return: TypeAst.type_ast()
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

  @doc """
  Parse a spec clause into structured type data.

  Takes the raw Erlang abstract format clause and extracts input types
  and return type into a structured map.

  ## Examples

      iex> clause = {:type, {10, 9}, :fun, [{:type, {10, 9}, :product, [{:type, {10, 18}, :integer, []}]}, {:type, {10, 30}, :atom, []}]}
      iex> parse_spec_clause(clause)
      %{inputs: [%{type: :builtin, name: :integer}], return: %{type: :builtin, name: :atom}}

  """
  @spec parse_spec_clause(tuple()) :: parsed_clause()
  def parse_spec_clause({:type, _, :fun, [{:type, _, :product, inputs}, return]}) do
    %{
      inputs: Enum.map(inputs, &TypeAst.parse/1),
      return: TypeAst.parse(return)
    }
  end

  # Handle bounded_fun (specs with when clauses)
  def parse_spec_clause({:type, _, :bounded_fun, [fun_type, _constraints]}) do
    parse_spec_clause(fun_type)
  end

  # Fallback for unexpected formats
  def parse_spec_clause(_) do
    %{inputs: [], return: %{type: :any}}
  end

  # Extract specs from abstract code forms
  defp extract_from_forms(forms) do
    forms
    |> Enum.filter(&spec_or_callback?/1)
    |> Enum.map(&parse_spec_attribute/1)
    |> Enum.reject(&is_nil/1)
  end

  # Check if a form is a spec or callback attribute
  defp spec_or_callback?({:attribute, _, :spec, _}), do: true
  defp spec_or_callback?({:attribute, _, :callback, _}), do: true
  defp spec_or_callback?(_), do: false

  # Parse a spec attribute from abstract format
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
