defmodule ExAst.SpecFormatter do
  alias ExAst.StringFormatting
  alias ExAst.SpecParser
  alias ExAst.TypeAst

  @moduledoc """
  Format parsed spec clauses into human-readable strings.

  Converts parsed spec data into formatted strings suitable for output,
  including full spec declarations and individual type strings.
  """

  @type formatted_clause :: %{
          inputs: [TypeAst.type_ast()],
          return: TypeAst.type_ast(),
          inputs_string: [String.t()],
          return_string: String.t(),
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
            inputs_string: ["integer()"],
            return_string: "atom()",
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

  @doc false
  @spec simplify_spec_for_function(map(), non_neg_integer()) :: map()
  def simplify_spec_for_function(%{kind: kind, line: line, clauses: [clause | _]}, _arity) do
    %{
      kind: kind,
      line: line,
      inputs_string: clause.inputs_string,
      return_string: clause.return_string,
      full: clause.full
    }
  end

  def simplify_spec_for_function(%{kind: kind, line: line, clauses: []}, _arity) do
    %{
      kind: kind,
      line: line,
      inputs_string: [],
      return_string: "any()",
      full: ""
    }
  end
end
