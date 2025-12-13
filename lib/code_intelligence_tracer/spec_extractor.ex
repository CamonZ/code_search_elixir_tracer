defmodule CodeIntelligenceTracer.SpecExtractor do
  alias CodeIntelligenceTracer.StringFormatting
  alias CodeIntelligenceTracer.TypeAst
  alias CodeIntelligenceTracer.TypeDefinitionExtractor

  @moduledoc """
  Extracts @spec and @callback definitions from BEAM file abstract_code chunks.

  Parses the Erlang abstract format to find spec and callback attributes,
  extracting function name, arity, kind, line number, and raw clause data
  for further processing.

  Delegates type AST parsing and formatting to `TypeAst`, and type definition
  extraction to `TypeDefinitionExtractor`.
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

  @type parsed_clause :: %{
          inputs: [TypeAst.type_ast()],
          return: TypeAst.type_ast()
        }

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

  @doc """
  Parse a type AST node into structured type data.

  This is a delegation to `TypeAst.parse/1` for backward compatibility.
  New code should use `TypeAst.parse/1` directly.

  See `TypeAst.parse/1` for documentation on type categories.
  """
  @spec parse_type_ast(tuple()) :: TypeAst.type_ast()
  def parse_type_ast(ast) do
    TypeAst.parse(ast)
  end

  @type formatted_clause :: %{
          inputs: [TypeAst.type_ast()],
          return: TypeAst.type_ast(),
          inputs_string: [String.t()],
          return_string: String.t(),
          full: String.t()
        }

  @doc """
  Format a parsed spec into human-readable strings.

  Takes a spec record (from extract_specs/1) and returns a formatted version
  with string representations of types.

  ## Examples

      iex> spec = %{name: :foo, arity: 1, clauses: [...], kind: :spec, line: 10}
      iex> format_spec(spec)
      %{
        name: :foo,
        arity: 1,
        kind: :spec,
        line: 10,
        clauses: [
          %{
            inputs: [...],
            return: ...,
            inputs_string: ["integer()"],
            return_string: "atom()",
            full: "@spec foo(integer()) :: atom()"
          }
        ]
      }

  """
  @spec format_spec(spec_record()) :: map()
  def format_spec(%{name: name, arity: arity, kind: kind, line: line, clauses: clauses}) do
    formatted_clauses =
      Enum.map(clauses, fn clause ->
        format_clause(clause, name, kind)
      end)

    %{
      name: name,
      arity: arity,
      kind: kind,
      line: line,
      clauses: formatted_clauses
    }
  end

  @doc """
  Format a single spec clause into human-readable strings.

  ## Parameters

    - `clause` - Raw clause from abstract format
    - `name` - Function name
    - `kind` - :spec or :callback

  """
  @spec format_clause(tuple(), atom(), :spec | :callback) :: formatted_clause()
  def format_clause(clause, name, kind) do
    parsed = parse_spec_clause(clause)
    inputs_string = Enum.map(parsed.inputs, &TypeAst.format/1)
    return_string = TypeAst.format(parsed.return)

    prefix = if kind == :callback, do: "@callback", else: "@spec"
    inputs_joined = StringFormatting.join_map(inputs_string, ", ", &Function.identity/1)
    full = "#{prefix} #{name}(#{inputs_joined}) :: #{return_string}"

    %{
      inputs: parsed.inputs,
      return: parsed.return,
      inputs_string: inputs_string,
      return_string: return_string,
      full: full
    }
  end

  @doc """
  Format a type AST into a human-readable Elixir type string.

  This is a delegation to `TypeAst.format/1` for backward compatibility.
  New code should use `TypeAst.format/1` directly.

  See `TypeAst.format/1` for documentation on formatting.
  """
  @spec format_type_string(TypeAst.type_ast()) :: String.t()
  def format_type_string(ast) do
    TypeAst.format(ast)
  end

  # =============================================================================
  # Spec-Function Correlation (T021)
  # =============================================================================

  @doc """
  Correlate specs with function locations.

  Takes a map of function locations (from FunctionExtractor) and a list of
  specs (from extract_specs/1), and adds the formatted spec to each matching
  function location.

  Functions without specs will have `spec: nil`.

  ## Parameters

    - `functions` - Map of "name/arity" => function info
    - `specs` - List of spec records from extract_specs/1

  ## Returns

  The functions map with an added `:spec` key containing the formatted spec
  for matching functions.

  ## Examples

      iex> functions = %{"foo/1" => %{start_line: 10, kind: :def, ...}}
      iex> specs = [%{name: :foo, arity: 1, kind: :spec, ...}]
      iex> correlate_specs(functions, specs)
      %{
        "foo/1" => %{
          start_line: 10,
          kind: :def,
          spec: %{
            kind: :spec,
            line: 9,
            inputs_string: ["integer()"],
            return_string: "atom()",
            full: "@spec foo(integer()) :: atom()"
          }
        }
      }

  """
  @spec correlate_specs(map(), [spec_record()]) :: map()
  def correlate_specs(functions, specs) do
    # Build a lookup map of specs by name/arity
    specs_by_key =
      specs
      |> Enum.reject(&(&1.name == :__info__))
      |> Enum.map(fn spec ->
        key = "#{spec.name}/#{spec.arity}"
        formatted = format_spec(spec)
        # Flatten to just the first clause for the function location
        # (most specs have only one clause)
        simplified = simplify_spec_for_function(formatted)
        {key, simplified}
      end)
      |> Map.new()

    # Add specs to matching functions
    # Function keys are now "name/arity:line", we need to extract "name/arity" for matching
    functions
    |> Enum.into(%{}, fn {func_key, func_info} ->
      # Extract name/arity from "name/arity:line"
      base_key = func_key |> String.split(":") |> List.first()
      spec = Map.get(specs_by_key, base_key)
      {func_key, Map.put(func_info, :spec, spec)}
    end)
  end

  # Simplify formatted spec for embedding in function location
  defp simplify_spec_for_function(%{kind: kind, line: line, clauses: [clause | _]}) do
    %{
      kind: kind,
      line: line,
      inputs_string: clause.inputs_string,
      return_string: clause.return_string,
      full: clause.full
    }
  end

  defp simplify_spec_for_function(%{kind: kind, line: line, clauses: []}) do
    %{
      kind: kind,
      line: line,
      inputs_string: [],
      return_string: "any()",
      full: ""
    }
  end

  @doc """
  Extract @type and @opaque definitions from BEAM chunks.

  This is a delegation to `TypeDefinitionExtractor.extract_types/1` for
  backward compatibility. New code should use that module directly.

  See `TypeDefinitionExtractor.extract_types/1` for documentation.
  """
  @spec extract_types(map()) :: [TypeDefinitionExtractor.type_record()]
  def extract_types(chunks) do
    TypeDefinitionExtractor.extract_types(chunks)
  end
end
