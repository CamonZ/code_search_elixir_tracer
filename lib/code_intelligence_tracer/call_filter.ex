defmodule CodeIntelligenceTracer.CallFilter do
  @moduledoc """
  Filters function calls to exclude stdlib and Erlang modules.

  Used to reduce noise in call graphs by filtering out ubiquitous calls
  to standard library functions that don't provide insight into application
  architecture.

  ## Filtering Modes

  - `should_include?/1` - Checks if a callee module should be included based
    on whether it's a stdlib or Erlang module
  - `should_include?/2` - Additionally filters to only include modules in a
    provided set of known project modules
  """

  # Elixir standard library modules that are typically filtered out
  @stdlib_modules MapSet.new([
    # Core data types and collections
    "Enum",
    "Map",
    "List",
    "Keyword",
    "String",
    "Integer",
    "Float",
    "Tuple",
    "MapSet",
    "Range",
    "Stream",
    "Bitwise",
    "Binary",

    # IO and File operations
    "File",
    "IO",
    "Path",
    "StringIO",

    # String/Data processing
    "Regex",
    "URI",
    "Base",
    "Inspect",
    "Calendar",
    "Version",

    # Date/Time
    "Date",
    "DateTime",
    "Time",
    "NaiveDateTime",
    "Calendar.ISO",

    # Data access
    "Access",

    # Concurrency
    "Agent",
    "Task",
    "Task.Supervisor",
    "GenServer",
    "Supervisor",
    "DynamicSupervisor",
    "Registry",
    "Process",
    "Node",
    "Port",

    # System/Runtime
    "System",
    "Code",
    "Macro",
    "Module",
    "Application",
    "Config",
    "Config.Provider",
    "Config.Reader",

    # Core language
    "Kernel",
    "Kernel.SpecialForms",
    "Protocol",
    "Exception",
    "Function",
    "Atom",

    # Protocols
    "Collectable",
    "Enumerable",
    "Inspect",
    "List.Chars",
    "String.Chars",

    # EEx templating
    "EEx",
    "EEx.Engine",

    # Logging
    "Logger",
    "Logger.Formatter",

    # Mix (build tool)
    "Mix",
    "Mix.Config",
    "Mix.Project",
    "Mix.Task",
    "Mix.Shell",

    # ExUnit (testing)
    "ExUnit",
    "ExUnit.Case",
    "ExUnit.Assertions",
    "ExUnit.Callbacks",

    # IEx (interactive shell)
    "IEx",
    "IEx.Helpers",

    # OptionParser
    "OptionParser",

    # Struct
    "Struct"
  ])

  @doc """
  Check if a callee module should be included in the call graph.

  Returns `true` if the module is not a stdlib or Erlang module.

  ## Examples

      iex> should_include?(%{module: "MyApp.Foo", function: "bar", arity: 1})
      true

      iex> should_include?(%{module: "Enum", function: "map", arity: 2})
      false

      iex> should_include?(%{module: "erlang", function: "self", arity: 0})
      false

  """
  @spec should_include?(map()) :: boolean()
  def should_include?(callee) do
    module = callee.module
    not (stdlib_module?(module) or erlang_module?(module))
  end

  @doc """
  Check if a callee module should be included, filtering to known modules.

  When `known_modules` is provided, only includes calls to modules in that set.
  This is useful for filtering to only project-internal calls.

  ## Examples

      iex> known = MapSet.new(["MyApp.Foo", "MyApp.Bar"])
      iex> should_include?(%{module: "MyApp.Foo", function: "bar", arity: 1}, known)
      true

      iex> known = MapSet.new(["MyApp.Foo", "MyApp.Bar"])
      iex> should_include?(%{module: "SomeLib.Thing", function: "call", arity: 0}, known)
      false

  """
  @spec should_include?(map(), MapSet.t()) :: boolean()
  def should_include?(callee, known_modules) do
    MapSet.member?(known_modules, callee.module)
  end

  @doc """
  Filter a list of call records to only include relevant calls.

  ## Options

    * `:known_modules` - When provided, only include calls to these modules.
      When `nil`, filters out stdlib and Erlang modules but keeps all others.

  ## Examples

      iex> calls = [
      ...>   %{callee: %{module: "MyApp.Foo", function: "bar", arity: 1}},
      ...>   %{callee: %{module: "Enum", function: "map", arity: 2}}
      ...> ]
      iex> filter_calls(calls)
      [%{callee: %{module: "MyApp.Foo", function: "bar", arity: 1}}]

  """
  @spec filter_calls([map()], keyword()) :: [map()]
  def filter_calls(calls, opts \\ []) do
    known_modules = Keyword.get(opts, :known_modules)

    if known_modules do
      Enum.filter(calls, &should_include?(&1.callee, known_modules))
    else
      Enum.filter(calls, &should_include?(&1.callee))
    end
  end

  @doc """
  Check if a module name is an Elixir stdlib module.

  ## Examples

      iex> stdlib_module?("Enum")
      true

      iex> stdlib_module?("MyApp.Foo")
      false

  """
  @spec stdlib_module?(String.t()) :: boolean()
  def stdlib_module?(module_name) do
    MapSet.member?(@stdlib_modules, module_name)
  end

  @doc """
  Check if a module name is an Erlang module.

  Erlang modules are identified by being lowercase (no "Elixir." prefix)
  and not containing a dot (which would indicate an Elixir submodule).

  ## Examples

      iex> erlang_module?("erlang")
      true

      iex> erlang_module?("lists")
      true

      iex> erlang_module?("Enum")
      false

      iex> erlang_module?("MyApp.Foo")
      false

  """
  @spec erlang_module?(String.t()) :: boolean()
  def erlang_module?(module_name) do
    # Erlang modules are lowercase and don't contain dots
    # (Elixir modules are PascalCase and may contain dots for namespacing)
    first_char = String.first(module_name)

    first_char != nil and
      first_char == String.downcase(first_char) and
      not String.contains?(module_name, ".")
  end

  @doc """
  Returns the set of stdlib module names.

  Useful for inspection or extending the filter list.
  """
  @spec stdlib_modules() :: MapSet.t()
  def stdlib_modules, do: @stdlib_modules
end
