defmodule ExAst.CallExtractor do
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
  - `args` - Arguments as human-readable string (e.g., "list, &transform/1")

  ## Data Format Conventions

  This module works with data structures following conventions documented in:
  - `docs/conventions/PARAMETER_FORMATTING.md` - Parameter naming and formatting
  - `docs/conventions/DATA_STRUCTURES.md` - Standard data structure definitions
  """

  alias ExAst.Utils

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
    module_string = Utils.module_to_string(module_name)

    definitions
    |> Enum.flat_map(fn definition ->
      extract_calls_from_definition(definition, module_string, source_file)
    end)
  end

  @spec extract_calls_from_definition(tuple(), String.t(), String.t()) :: [map()]
  defp extract_calls_from_definition({{func_name, arity}, kind, _meta, clauses}, module_string, source_file) do
    function_string = "#{func_name}/#{arity}"

    clauses
    |> Enum.flat_map(fn {_meta, _args, _guards, body} ->
      extract_calls_from_ast(body, module_string, function_string, kind, source_file)
    end)
  end

  @spec extract_calls_from_ast(term(), String.t(), String.t(), atom(), String.t()) :: [map()]
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
  @spec extract_call(term(), String.t()) ::
          {:remote, map(), non_neg_integer()}
          | {:local, map(), non_neg_integer()}
          | {:skip, :remote | :local, map(), non_neg_integer()}
          | nil
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

  # ============================================================================
  # Guard Helper Functions
  # ============================================================================

  # These helper functions provide reusable pattern matching checks for different
  # call types. They improve code readability and documentation by making the intent
  # of each guard condition explicit. Though not currently used inline in pattern
  # matching, they serve as documentation for the call patterns and can be used
  # if the extract_call implementation is refactored to use cond blocks.

  @dialyzer :no_unused
  @doc false
  @spec remote_function_capture?(node :: tuple()) :: boolean()
  defp remote_function_capture?(
    {:&, _, [{:/, _, [{{:., _, [_module, func]}, _, _args}, arity]}]}
  ) when is_atom(func) and is_integer(arity),
  do: true

  defp remote_function_capture?(_), do: false

  @doc false
  @spec local_function_capture?(node :: tuple()) :: boolean()
  defp local_function_capture?(
    {:&, _, [{:/, _, [{func, _, context}, arity]}]}
  ) when is_atom(func) and is_integer(arity) and is_atom(context),
  do: true

  defp local_function_capture?(_), do: false

  @doc false
  @spec remote_call?(node :: tuple()) :: boolean()
  defp remote_call?({{:., _, [_module, func]}, _meta, _args}) when is_atom(func),
    do: true

  defp remote_call?(_), do: false

  @doc false
  @spec local_call?(node :: tuple()) :: boolean()
  defp local_call?({func, _meta, args}) when is_atom(func) and is_list(args),
    do: true

  defp local_call?(_), do: false

  @doc false
  @spec variable_reference?(node :: tuple()) :: boolean()
  defp variable_reference?({_name, _meta, nil}), do: true
  defp variable_reference?(_), do: false

  # Normalize module reference to string
  @spec normalize_module(term()) :: {:ok, String.t()} | :error
  defp normalize_module(module) when is_atom(module) do
    {:ok, Utils.module_to_string(module)}
  end

  defp normalize_module({:__aliases__, _, parts}) when is_list(parts) do
    module_string =
      parts
      |> Enum.map(&to_string/1)
      |> Enum.join(".")

    {:ok, module_string}
  end

  defp normalize_module(_), do: :error

  @spec local_function_call?(atom()) :: boolean()
  defp local_function_call?(func) do
    func not in @special_forms
  end

  @spec build_call_record(atom(), String.t(), String.t(), atom(), String.t(), non_neg_integer(), map()) :: map()
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
