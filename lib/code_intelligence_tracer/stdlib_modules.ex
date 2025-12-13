defmodule CodeIntelligenceTracer.StdlibModules do
  @moduledoc """
  Defines Erlang/Elixir standard library modules.

  Used for filtering out internal/stdlib calls from extraction results.
  These modules are part of the Elixir core library and OTP.
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
  Get the MapSet of all standard library modules.

  ## Examples

      iex> modules = StdlibModules.stdlib_modules()
      iex> is_struct(modules, MapSet)
      true

  """
  @spec stdlib_modules() :: MapSet.t()
  def stdlib_modules, do: @stdlib_modules

  @doc """
  Check if a module is a standard library module.

  ## Parameters

    - `module_name` - Module name as a string

  ## Examples

      iex> StdlibModules.stdlib_module?("List")
      true

      iex> StdlibModules.stdlib_module?("MyApp.Utils")
      false

  """
  @spec stdlib_module?(String.t()) :: boolean()
  def stdlib_module?(module_name) do
    MapSet.member?(@stdlib_modules, module_name)
  end
end
