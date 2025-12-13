defmodule CodeIntelligenceTracer.CallExtractor do
  @moduledoc """
  Extracts function calls from Elixir AST definitions.

  Walks through function definitions and identifies both remote calls
  (Module.function) and local calls within the module.

  ## Call Types

  - `:remote` - Calls to functions in other modules (e.g., `Enum.map/2`)
  - `:local` - Calls to functions in the same module (e.g., `helper/1`)

  ## Caller Information

  Each call record includes information about the calling function:

  - `module` - The module containing the calling function
  - `function` - The function name and arity (e.g., "process/2")
  - `kind` - The function type: `:def`, `:defp`, `:defmacro`, or `:defmacrop`
  - `file` - Source file path
  - `line` - Line number where the call occurs

  ## Callee Information

  Each call record includes information about the called function:

  - `module` - The target module (same as caller module for local calls)
  - `function` - The function name being called
  - `arity` - The number of arguments in the call
  """

  @type function_kind :: :def | :defp | :defmacro | :defmacrop

  @type call_record :: %{
          type: :remote | :local,
          caller: %{
            module: String.t(),
            function: String.t(),
            kind: function_kind(),
            file: String.t(),
            line: non_neg_integer()
          },
          callee: %{
            module: String.t(),
            function: String.t(),
            arity: non_neg_integer()
          }
        }

  # Special forms, operators, and kernel macros that should not be counted as function calls
  @special_forms [
    :__block__,
    :__aliases__,
    :__MODULE__,
    :__ENV__,
    :__DIR__,
    :__CALLER__,
    :__STACKTRACE__,
    :fn,
    :do,
    :end,
    :case,
    :cond,
    :try,
    :receive,
    :for,
    :with,
    :quote,
    :unquote,
    :unquote_splicing,
    :import,
    :require,
    :alias,
    :use,
    :def,
    :defp,
    :defmacro,
    :defmacrop,
    :defmodule,
    :defstruct,
    :defguard,
    :defguardp,
    :defdelegate,
    :defexception,
    :defoverridable,
    :defimpl,
    :defprotocol,
    :@,
    :&,
    :|>,
    :<<>>,
    :"::",
    :%{},
    :{},
    :when,
    :->,
    :<-,
    # Operators
    :=,
    :==,
    :!=,
    :===,
    :!==,
    :<,
    :>,
    :<=,
    :>=,
    :+,
    :-,
    :*,
    :/,
    :++,
    :--,
    :<>,
    :and,
    :or,
    :not,
    :in,
    :|,
    :^,
    :.,
    :if,
    :unless,
    :raise,
    :reraise,
    :throw,
    :super
  ]

  @doc """
  Extract all function calls from a module's definitions.

  Takes the definitions list from debug info, the module name, and source file path.
  Returns a list of call records with caller and callee information.

  Extracts calls from all function types: public functions (`def`), private functions
  (`defp`), public macros (`defmacro`), and private macros (`defmacrop`). The caller's
  `kind` field indicates which type the calling function is.

  ## Parameters

    - `definitions` - List of function definitions from debug info
    - `module_name` - The module atom (e.g., `MyApp.Foo`)
    - `source_file` - Path to the source file

  ## Examples

      iex> extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")
      [%{type: :remote, caller: %{module: "MyApp.Foo", function: "bar/2", kind: :def, ...}, callee: %{...}}, ...]

  """
  @spec extract_calls(list(), module(), String.t()) :: [call_record()]
  def extract_calls(definitions, module_name, source_file) do
    module_string = module_to_string(module_name)

    definitions
    |> Enum.flat_map(fn definition ->
      extract_calls_from_definition(definition, module_string, source_file)
    end)
  end

  defp extract_calls_from_definition({{func_name, arity}, kind, _meta, clauses}, module_string, source_file) do
    function_string = "#{func_name}/#{arity}"

    clauses
    |> Enum.flat_map(fn {_meta, _args, _guards, body} ->
      extract_calls_from_ast(body, module_string, function_string, kind, source_file)
    end)
  end

  defp extract_calls_from_ast(ast, module_string, function_string, kind, source_file) do
    {_ast, calls} =
      Macro.prewalk(ast, [], fn node, acc ->
        case extract_call(node, module_string) do
          nil ->
            {node, acc}

          {:skip, type, callee, line} ->
            # For function captures, we skip descending into children
            # to avoid double-counting the inner remote call
            call_record = build_call_record(
              type,
              module_string,
              function_string,
              kind,
              source_file,
              line,
              callee
            )

            {:ok, [call_record | acc]}

          {type, callee, line} ->
            call_record = build_call_record(
              type,
              module_string,
              function_string,
              kind,
              source_file,
              line,
              callee
            )

            {node, [call_record | acc]}
        end
      end)

    calls
  end

  # Function capture: &Module.function/arity
  # Pattern: {:&, meta, [{:/, _, [{remote_call}, arity]}]}
  # Returns :skip to prevent walking into nested remote call
  defp extract_call(
         {:&, meta, [{:/, _, [{{:., _, [module, func]}, _, _args}, arity]}]},
         _caller_module
       )
       when is_atom(func) and is_integer(arity) do
    case normalize_module(module) do
      {:ok, module_string} ->
        line = Keyword.get(meta, :line, 0)

        callee = %{
          module: module_string,
          function: to_string(func),
          arity: arity
        }

        {:skip, :remote, callee, line}

      :error ->
        nil
    end
  end

  # Local function capture: &function/arity
  # Pattern: {:&, meta, [{:/, _, [{func_atom, _, _}, arity]}]}
  # Returns :skip to prevent walking into nested nodes
  defp extract_call(
         {:&, meta, [{:/, _, [{func, _, context}, arity]}]},
         caller_module
       )
       when is_atom(func) and is_integer(arity) and is_atom(context) do
    line = Keyword.get(meta, :line, 0)

    callee = %{
      module: caller_module,
      function: to_string(func),
      arity: arity
    }

    {:skip, :local, callee, line}
  end

  # Remote call: Module.function(args)
  defp extract_call({{:., _, [module, func]}, meta, args}, _caller_module) when is_atom(func) do
    case normalize_module(module) do
      {:ok, module_string} ->
        line = Keyword.get(meta, :line, 0)

        callee = %{
          module: module_string,
          function: to_string(func),
          arity: length(args)
        }

        {:remote, callee, line}

      :error ->
        nil
    end
  end

  # Local call: function(args) where function is an atom and args is a list
  # Note: Variables have nil for args, so we must check for is_list(args)
  defp extract_call({func, meta, args}, caller_module)
       when is_atom(func) and is_list(args) do
    # Skip special forms and operators
    if local_function_call?(func) do
      line = Keyword.get(meta, :line, 0)

      callee = %{
        module: caller_module,
        function: to_string(func),
        arity: length(args)
      }

      {:local, callee, line}
    else
      nil
    end
  end

  # Variables have nil context - these are not function calls
  defp extract_call({_name, _meta, nil}, _caller_module), do: nil

  defp extract_call(_node, _caller_module), do: nil

  # Normalize module reference to string
  defp normalize_module(module) when is_atom(module) do
    {:ok, module_to_string(module)}
  end

  defp normalize_module({:__aliases__, _, parts}) when is_list(parts) do
    module_string =
      parts
      |> Enum.map(&to_string/1)
      |> Enum.join(".")

    {:ok, module_string}
  end

  defp normalize_module(_), do: :error

  defp module_to_string(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.replace_leading("Elixir.", "")
  end

  defp local_function_call?(func) do
    func not in @special_forms
  end

  defp build_call_record(type, module_string, function_string, kind, source_file, line, callee) do
    %{
      type: type,
      caller: %{
        module: module_string,
        function: function_string,
        kind: kind,
        file: source_file,
        line: line
      },
      callee: callee
    }
  end
end
