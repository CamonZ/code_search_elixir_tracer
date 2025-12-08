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

  # =============================================================================
  # Spec Clause Parsing (T019)
  # =============================================================================

  @type type_ast ::
          %{type: :union, types: [type_ast()]}
          | %{type: :tuple, elements: [type_ast()]}
          | %{type: :list, element_type: type_ast() | nil}
          | %{type: :map, fields: :any | [map()]}
          | %{type: :fun, inputs: [type_ast()], return: type_ast()}
          | %{type: :type_ref, module: String.t() | nil, name: atom(), args: [type_ast()]}
          | %{type: :literal, kind: :atom | :integer, value: term()}
          | %{type: :builtin, name: atom()}
          | %{type: :var, name: atom()}
          | %{type: :any}

  @type parsed_clause :: %{
          inputs: [type_ast()],
          return: type_ast()
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
      inputs: Enum.map(inputs, &parse_type_ast/1),
      return: parse_type_ast(return)
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

  Converts Erlang abstract format type nodes into a normalized map structure
  that's easier to work with and format.

  ## Type Categories

  - `:union` - Union types like `integer | atom`
  - `:tuple` - Tuple types like `{atom, integer}`
  - `:list` - List types like `[integer]` or `list()`
  - `:map` - Map types like `%{atom => integer}` or `map()`
  - `:fun` - Function types like `(integer -> atom)`
  - `:type_ref` - Type references like `String.t()` or `t()`
  - `:literal` - Literal values like `:ok` or `42`
  - `:builtin` - Built-in types like `integer()`, `binary()`, `term()`
  - `:var` - Type variables like `a` in polymorphic specs
  - `:any` - The any type or unknown structures

  """
  @spec parse_type_ast(tuple()) :: type_ast()
  # Union types
  def parse_type_ast({:type, _, :union, types}) do
    %{type: :union, types: Enum.map(types, &parse_type_ast/1)}
  end

  # Tuple types
  def parse_type_ast({:type, _, :tuple, :any}) do
    %{type: :tuple, elements: :any}
  end

  def parse_type_ast({:type, _, :tuple, elements}) do
    %{type: :tuple, elements: Enum.map(elements, &parse_type_ast/1)}
  end

  # List types
  def parse_type_ast({:type, _, :list, []}) do
    %{type: :list, element_type: nil}
  end

  def parse_type_ast({:type, _, :list, [element_type]}) do
    %{type: :list, element_type: parse_type_ast(element_type)}
  end

  def parse_type_ast({:type, _, nil, []}) do
    # Empty list literal type []
    %{type: :literal, kind: :list, value: []}
  end

  # Map types
  def parse_type_ast({:type, _, :map, :any}) do
    %{type: :map, fields: :any}
  end

  def parse_type_ast({:type, _, :map, fields}) when is_list(fields) do
    %{type: :map, fields: Enum.map(fields, &parse_map_field/1)}
  end

  # Function types (for function type specs, not spec clauses)
  def parse_type_ast({:type, _, :fun, [{:type, _, :product, inputs}, return]}) do
    %{
      type: :fun,
      inputs: Enum.map(inputs, &parse_type_ast/1),
      return: parse_type_ast(return)
    }
  end

  def parse_type_ast({:type, _, :fun, []}) do
    %{type: :fun, inputs: :any, return: %{type: :any}}
  end

  # Remote type references (e.g., String.t())
  def parse_type_ast({:remote_type, _, [{:atom, _, module}, {:atom, _, name}, args]}) do
    module_string = module_to_elixir_string(module)

    %{
      type: :type_ref,
      module: module_string,
      name: name,
      args: Enum.map(args, &parse_type_ast/1)
    }
  end

  # Local user type references (e.g., t())
  def parse_type_ast({:user_type, _, name, args}) do
    %{
      type: :type_ref,
      module: nil,
      name: name,
      args: Enum.map(args, &parse_type_ast/1)
    }
  end

  # Atom literals
  def parse_type_ast({:atom, _, value}) do
    %{type: :literal, kind: :atom, value: value}
  end

  # Integer literals
  def parse_type_ast({:integer, _, value}) do
    %{type: :literal, kind: :integer, value: value}
  end

  # Type variables
  def parse_type_ast({:var, _, name}) do
    %{type: :var, name: name}
  end

  # Built-in types (integer, binary, atom, term, any, etc.)
  def parse_type_ast({:type, _, name, []}) when is_atom(name) do
    %{type: :builtin, name: name}
  end

  # Built-in types with args (e.g., nonempty_list(integer))
  def parse_type_ast({:type, _, name, args}) when is_atom(name) and is_list(args) do
    %{type: :builtin, name: name, args: Enum.map(args, &parse_type_ast/1)}
  end

  # Annotated types (e.g., name :: type in specs)
  def parse_type_ast({:ann_type, _, [{:var, _, _name}, type]}) do
    parse_type_ast(type)
  end

  # Fallback for unknown structures
  def parse_type_ast(_) do
    %{type: :any}
  end

  # Parse map field associations
  defp parse_map_field({:type, _, :map_field_exact, [key, value]}) do
    %{kind: :exact, key: parse_type_ast(key), value: parse_type_ast(value)}
  end

  defp parse_map_field({:type, _, :map_field_assoc, [key, value]}) do
    %{kind: :assoc, key: parse_type_ast(key), value: parse_type_ast(value)}
  end

  defp parse_map_field(_) do
    %{kind: :unknown, key: %{type: :any}, value: %{type: :any}}
  end

  # Convert Erlang module atom to Elixir module string
  defp module_to_elixir_string(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.replace_leading("Elixir.", "")
  end
end
