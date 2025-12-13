defmodule ExAst.TypeAst do
  alias ExAst.StringFormatting
  alias ExAst.Utils

  @moduledoc """
  Parse and format Elixir type AST nodes.

  Provides functions to convert between Erlang abstract format type AST
  (from BEAM bytecode) and structured type maps, as well as formatting
  type maps back to human-readable Elixir type syntax.

  This module is reusable for both spec type parsing and type definition parsing.
  """

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
  @spec parse(tuple()) :: type_ast()
  # Union types
  def parse({:type, _, :union, types}) do
    %{type: :union, types: Enum.map(types, &parse/1)}
  end

  # Tuple types
  def parse({:type, _, :tuple, :any}) do
    %{type: :tuple, elements: :any}
  end

  def parse({:type, _, :tuple, elements}) do
    %{type: :tuple, elements: Enum.map(elements, &parse/1)}
  end

  # List types
  def parse({:type, _, :list, []}) do
    %{type: :list, element_type: nil}
  end

  def parse({:type, _, :list, [element_type]}) do
    %{type: :list, element_type: parse(element_type)}
  end

  def parse({:type, _, nil, []}) do
    # Empty list literal type []
    %{type: :literal, kind: :list, value: []}
  end

  # Map types
  def parse({:type, _, :map, :any}) do
    %{type: :map, fields: :any}
  end

  def parse({:type, _, :map, fields}) when is_list(fields) do
    %{type: :map, fields: Enum.map(fields, &parse_map_field/1)}
  end

  # Function types (for function type specs, not spec clauses)
  def parse({:type, _, :fun, [{:type, _, :product, inputs}, return]}) do
    %{
      type: :fun,
      inputs: Enum.map(inputs, &parse/1),
      return: parse(return)
    }
  end

  def parse({:type, _, :fun, []}) do
    %{type: :fun, inputs: :any, return: %{type: :any}}
  end

  # Remote type references (e.g., String.t())
  def parse({:remote_type, _, [{:atom, _, module}, {:atom, _, name}, args]}) do
    module_string = Utils.module_to_string(module)

    %{
      type: :type_ref,
      module: module_string,
      name: name,
      args: Enum.map(args, &parse/1)
    }
  end

  # Local user type references (e.g., t())
  def parse({:user_type, _, name, args}) do
    %{
      type: :type_ref,
      module: nil,
      name: name,
      args: Enum.map(args, &parse/1)
    }
  end

  # Atom literals
  def parse({:atom, _, value}) do
    %{type: :literal, kind: :atom, value: value}
  end

  # Integer literals
  def parse({:integer, _, value}) do
    %{type: :literal, kind: :integer, value: value}
  end

  # Type variables
  def parse({:var, _, name}) do
    %{type: :var, name: name}
  end

  # Built-in types (integer, binary, atom, term, any, etc.)
  def parse({:type, _, name, []}) when is_atom(name) do
    %{type: :builtin, name: name}
  end

  # Built-in types with args (e.g., nonempty_list(integer))
  def parse({:type, _, name, args}) when is_atom(name) and is_list(args) do
    %{type: :builtin, name: name, args: Enum.map(args, &parse/1)}
  end

  # Annotated types (e.g., name :: type in specs)
  def parse({:ann_type, _, [{:var, _, _name}, type]}) do
    parse(type)
  end

  # Fallback for unknown structures
  def parse(_) do
    %{type: :any}
  end

  @doc """
  Format a type AST into a human-readable Elixir type string.

  Converts the structured type map back into Elixir type syntax.

  ## Examples

      iex> format(%{type: :builtin, name: :integer})
      "integer()"

      iex> format(%{type: :type_ref, module: "String", name: :t, args: []})
      "String.t()"

  """
  @spec format(type_ast()) :: String.t()
  def format(%{type: :builtin, name: name, args: args}) do
    args_str = StringFormatting.join_map(args, ", ", &format/1)
    "#{name}(#{args_str})"
  end

  def format(%{type: :builtin, name: name}) do
    "#{name}()"
  end

  def format(%{type: :literal, kind: :atom, value: value}) do
    inspect(value)
  end

  def format(%{type: :literal, kind: :integer, value: value}) do
    Integer.to_string(value)
  end

  def format(%{type: :literal, kind: :list, value: []}) do
    "[]"
  end

  def format(%{type: :type_ref, module: nil, name: name, args: []}) do
    "#{name}()"
  end

  def format(%{type: :type_ref, module: nil, name: name, args: args}) do
    args_str = StringFormatting.join_map(args, ", ", &format/1)
    "#{name}(#{args_str})"
  end

  def format(%{type: :type_ref, module: module, name: name, args: []}) do
    "#{module}.#{name}()"
  end

  def format(%{type: :type_ref, module: module, name: name, args: args}) do
    args_str = StringFormatting.join_map(args, ", ", &format/1)
    "#{module}.#{name}(#{args_str})"
  end

  def format(%{type: :union, types: types}) do
    StringFormatting.join_map(types, " | ", &format/1)
  end

  def format(%{type: :tuple, elements: :any}) do
    "tuple()"
  end

  def format(%{type: :tuple, elements: elements}) do
    elements_str = StringFormatting.join_map(elements, ", ", &format/1)
    "{#{elements_str}}"
  end

  def format(%{type: :list, element_type: nil}) do
    "list()"
  end

  def format(%{type: :list, element_type: element_type}) do
    "[#{format(element_type)}]"
  end

  def format(%{type: :map, fields: :any}) do
    "map()"
  end

  def format(%{type: :map, fields: fields}) do
    fields_str = StringFormatting.join_map(fields, ", ", &format_map_field/1)
    "%{#{fields_str}}"
  end

  def format(%{type: :fun, inputs: :any, return: _return}) do
    "fun()"
  end

  def format(%{type: :fun, inputs: inputs, return: return}) do
    inputs_str = StringFormatting.join_map(inputs, ", ", &format/1)
    return_str = format(return)
    "(#{inputs_str} -> #{return_str})"
  end

  def format(%{type: :var, name: name}) do
    Atom.to_string(name)
  end

  def format(%{type: :any}) do
    "any()"
  end

  def format(_) do
    "term()"
  end

  # Parse map field associations
  @spec parse_map_field(term()) :: map()
  defp parse_map_field({:type, _, :map_field_exact, [key, value]}) do
    %{kind: :exact, key: parse(key), value: parse(value)}
  end

  defp parse_map_field({:type, _, :map_field_assoc, [key, value]}) do
    %{kind: :assoc, key: parse(key), value: parse(value)}
  end

  defp parse_map_field(_) do
    %{kind: :unknown, key: %{type: :any}, value: %{type: :any}}
  end

  @spec format_map_field(map()) :: String.t()
  defp format_map_field(%{kind: :exact, key: key, value: value}) do
    key_str = format(key)
    value_str = format(value)

    # Use atom shorthand for atom keys
    case key do
      %{type: :literal, kind: :atom, value: atom_key} ->
        "#{atom_key}: #{value_str}"

      _ ->
        "#{key_str} => #{value_str}"
    end
  end

  defp format_map_field(%{kind: :assoc, key: key, value: value}) do
    key_str = format(key)
    value_str = format(value)
    "optional(#{key_str}) => #{value_str}"
  end

  defp format_map_field(_) do
    "term() => term()"
  end
end
