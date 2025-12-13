defmodule CodeIntelligenceTracer.SpecExtractor do
  alias CodeIntelligenceTracer.StringFormatting

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

  # =============================================================================
  # Type String Formatting (T020)
  # =============================================================================

  @type formatted_clause :: %{
          inputs: [type_ast()],
          return: type_ast(),
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
    inputs_string = Enum.map(parsed.inputs, &format_type_string/1)
    return_string = format_type_string(parsed.return)

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

  Converts the structured type map back into Elixir type syntax.

  ## Examples

      iex> format_type_string(%{type: :builtin, name: :integer})
      "integer()"

      iex> format_type_string(%{type: :type_ref, module: "String", name: :t, args: []})
      "String.t()"

  """
  @spec format_type_string(type_ast()) :: String.t()
  def format_type_string(%{type: :builtin, name: name, args: args}) do
    args_str = StringFormatting.join_map(args, ", ", &format_type_string/1)
    "#{name}(#{args_str})"
  end

  def format_type_string(%{type: :builtin, name: name}) do
    "#{name}()"
  end

  def format_type_string(%{type: :literal, kind: :atom, value: value}) do
    inspect(value)
  end

  def format_type_string(%{type: :literal, kind: :integer, value: value}) do
    Integer.to_string(value)
  end

  def format_type_string(%{type: :literal, kind: :list, value: []}) do
    "[]"
  end

  def format_type_string(%{type: :type_ref, module: nil, name: name, args: []}) do
    "#{name}()"
  end

  def format_type_string(%{type: :type_ref, module: nil, name: name, args: args}) do
    args_str = StringFormatting.join_map(args, ", ", &format_type_string/1)
    "#{name}(#{args_str})"
  end

  def format_type_string(%{type: :type_ref, module: module, name: name, args: []}) do
    "#{module}.#{name}()"
  end

  def format_type_string(%{type: :type_ref, module: module, name: name, args: args}) do
    args_str = StringFormatting.join_map(args, ", ", &format_type_string/1)
    "#{module}.#{name}(#{args_str})"
  end

  def format_type_string(%{type: :union, types: types}) do
    StringFormatting.join_map(types, " | ", &format_type_string/1)
  end

  def format_type_string(%{type: :tuple, elements: :any}) do
    "tuple()"
  end

  def format_type_string(%{type: :tuple, elements: elements}) do
    elements_str = StringFormatting.join_map(elements, ", ", &format_type_string/1)
    "{#{elements_str}}"
  end

  def format_type_string(%{type: :list, element_type: nil}) do
    "list()"
  end

  def format_type_string(%{type: :list, element_type: element_type}) do
    "[#{format_type_string(element_type)}]"
  end

  def format_type_string(%{type: :map, fields: :any}) do
    "map()"
  end

  def format_type_string(%{type: :map, fields: fields}) do
    fields_str = StringFormatting.join_map(fields, ", ", &format_map_field/1)
    "%{#{fields_str}}"
  end

  def format_type_string(%{type: :fun, inputs: :any, return: _return}) do
    "fun()"
  end

  def format_type_string(%{type: :fun, inputs: inputs, return: return}) do
    inputs_str = StringFormatting.join_map(inputs, ", ", &format_type_string/1)
    return_str = format_type_string(return)
    "(#{inputs_str} -> #{return_str})"
  end

  def format_type_string(%{type: :var, name: name}) do
    Atom.to_string(name)
  end

  def format_type_string(%{type: :any}) do
    "any()"
  end

  def format_type_string(_) do
    "term()"
  end

  defp format_map_field(%{kind: :exact, key: key, value: value}) do
    key_str = format_type_string(key)
    value_str = format_type_string(value)

    # Use atom shorthand for atom keys
    case key do
      %{type: :literal, kind: :atom, value: atom_key} ->
        "#{atom_key}: #{value_str}"

      _ ->
        "#{key_str} => #{value_str}"
    end
  end

  defp format_map_field(%{kind: :assoc, key: key, value: value}) do
    key_str = format_type_string(key)
    value_str = format_type_string(value)
    "optional(#{key_str}) => #{value_str}"
  end

  defp format_map_field(_) do
    "term() => term()"
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

  # =============================================================================
  # Type Extraction (T022)
  # =============================================================================

  @type type_record :: %{
          name: atom(),
          kind: :type | :opaque,
          params: [atom()],
          line: non_neg_integer(),
          definition: String.t()
        }

  @doc """
  Extract @type and @opaque definitions from BEAM chunks.

  Parses the `:abstract_code` chunk to find type and opaque type definitions.

  Returns a list of type records with:
  - `:name` - type name as atom
  - `:kind` - `:type` or `:opaque`
  - `:params` - list of type parameter names (atoms)
  - `:line` - source line number
  - `:definition` - formatted definition string like `@type t :: integer()`

  Returns an empty list if no abstract_code chunk is available.

  ## Examples

      iex> {:ok, {_mod, chunks}} = BeamReader.read_chunks("path/to/Module.beam")
      iex> extract_types(chunks)
      [%{name: :t, kind: :type, params: [], line: 5, definition: "@type t :: integer()"}]

  """
  @spec extract_types(map()) :: [type_record()]
  def extract_types(chunks) do
    case chunks[:abstract_code] do
      {:raw_abstract_v1, forms} ->
        extract_types_from_forms(forms)

      nil ->
        []

      _other ->
        []
    end
  end

  defp extract_types_from_forms(forms) do
    forms
    |> Enum.filter(&type_or_opaque?/1)
    |> Enum.map(&parse_type_attribute/1)
    |> Enum.reject(&is_nil/1)
  end

  defp type_or_opaque?({:attribute, _, :type, _}), do: true
  defp type_or_opaque?({:attribute, _, :opaque, _}), do: true
  defp type_or_opaque?(_), do: false

  defp parse_type_attribute({:attribute, line, kind, {name, type_ast, params}})
       when kind in [:type, :opaque] do
    param_names = extract_param_names(params)
    definition = format_type_definition(name, kind, param_names, type_ast)

    %{
      name: name,
      kind: kind,
      params: param_names,
      line: line,
      definition: definition
    }
  end

  defp parse_type_attribute(_), do: nil

  defp extract_param_names(params) when is_list(params) do
    Enum.map(params, fn
      {:var, _, name} -> name
      _ -> :_
    end)
  end

  defp extract_param_names(_), do: []

  defp format_type_definition(name, kind, params, type_ast) do
    prefix = if kind == :opaque, do: "@opaque", else: "@type"
    type_string = format_type_string(parse_type_ast(type_ast))

    if params == [] do
      "#{prefix} #{name}() :: #{type_string}"
    else
      params_str = Enum.join(params, ", ")
      "#{prefix} #{name}(#{params_str}) :: #{type_string}"
    end
  end
end
