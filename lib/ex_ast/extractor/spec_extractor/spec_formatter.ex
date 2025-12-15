defmodule ExAst.Extractor.SpecExtractor.SpecFormatter do
  alias ExAst.Extractor.SpecExtractor.SpecParser
  alias ExAst.Extractor.TypeAst
  alias ExAst.Utils.StringFormatting

  @moduledoc """
  Format parsed spec clauses into human-readable strings.

  Converts parsed spec data into formatted strings suitable for output,
  including full spec declarations and individual type strings.
  """

  @type formatted_clause :: %{
          inputs: [TypeAst.type_ast()],
          return: TypeAst.type_ast(),
          input_strings: [String.t()],
          return_strings: [String.t()],
          full: String.t()
        }

  @doc """
  Format a parsed spec into human-readable strings.

  Takes a spec record (from SpecParser.extract_specs/1) and returns a formatted version
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
            input_strings: ["integer()"],
            return_strings: ["atom()"],
            full: "@spec foo(integer()) :: atom()"
          }
        ]
      }

  """
  @spec format_spec(SpecParser.spec_record()) :: map()
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
    parsed = SpecParser.parse_spec_clause(clause)
    input_strings = Enum.map(parsed.inputs, &TypeAst.format/1)

    return_strings =
      case parsed.return do
        %{type: :union, types: types} -> Enum.map(types, &TypeAst.format/1)
        other -> [TypeAst.format(other)]
      end

    prefix = if kind == :callback, do: "@callback", else: "@spec"
    inputs_joined = StringFormatting.join_map(input_strings, ", ", &Function.identity/1)
    return_joined = Enum.join(return_strings, " | ")
    full = "#{prefix} #{name}(#{inputs_joined}) :: #{return_joined}"

    %{
      inputs: parsed.inputs,
      return: parsed.return,
      input_strings: input_strings,
      return_strings: return_strings,
      full: full
    }
  end

  @doc false
  @spec simplify_spec_for_function(map(), non_neg_integer()) :: map()
  def simplify_spec_for_function(%{kind: kind, line: line, clauses: [clause | _]}, _arity) do
    %{
      kind: kind,
      line: line,
      input_strings: clause.input_strings,
      return_strings: clause.return_strings,
      full: clause.full
    }
  end

  def simplify_spec_for_function(%{kind: kind, line: line, clauses: []}, _arity) do
    %{
      kind: kind,
      line: line,
      input_strings: [],
      return_strings: ["any()"],
      full: ""
    }
  end
end
