defmodule ExAst.Extractor.SpecExtractor do
  alias ExAst.Extractor.SpecExtractor.SpecFormatter
  alias ExAst.Extractor.SpecExtractor.SpecParser
  alias ExAst.Extractor.SpecExtractor.TypeDefinitionExtractor
  alias ExAst.Extractor.TypeAst

  @moduledoc """
  Extract and format specs and callbacks from BEAM file abstract_code chunks.

  High-level API that delegates to focused modules:
  - `SpecParser` for extraction and parsing
  - `SpecFormatter` for formatting output
  - `TypeAst` for type AST parsing and formatting
  - `TypeDefinitionExtractor` for type definitions

  Also provides correlation of specs with function locations.

  ## Data Format Conventions

  This module works with data structures following conventions documented in:
  - `docs/conventions/PARAMETER_FORMATTING.md` - Parameter naming and formatting
  - `docs/conventions/DATA_STRUCTURES.md` - Standard data structure definitions
  """

  @type spec_record :: SpecParser.spec_record()

  @doc """
  Extract specs and callbacks from BEAM chunks.

  Delegates to `SpecParser.extract_specs/1`.

  See `SpecParser.extract_specs/1` for documentation.
  """
  @spec extract_specs(map()) :: [spec_record()]
  def extract_specs(chunks) do
    SpecParser.extract_specs(chunks)
  end

  @doc """
  Parse a spec clause into structured type data.

  Delegates to `SpecParser.parse_spec_clause/1`.

  See `SpecParser.parse_spec_clause/1` for documentation.
  """
  @spec parse_spec_clause(tuple()) :: SpecParser.parsed_clause()
  def parse_spec_clause(clause) do
    SpecParser.parse_spec_clause(clause)
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

  @doc """
  Format a parsed spec into human-readable strings.

  Delegates to `SpecFormatter.format_spec/1`.

  See `SpecFormatter.format_spec/1` for documentation.
  """
  @spec format_spec(spec_record()) :: map()
  def format_spec(spec) do
    SpecFormatter.format_spec(spec)
  end

  @doc """
  Format a single spec clause into human-readable strings.

  Delegates to `SpecFormatter.format_clause/3`.

  See `SpecFormatter.format_clause/3` for documentation.
  """
  @spec format_clause(tuple(), atom(), :spec | :callback) :: SpecFormatter.formatted_clause()
  def format_clause(clause, name, kind) do
    SpecFormatter.format_clause(clause, name, kind)
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
  @spec simplify_spec_for_function(map()) :: map()
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
