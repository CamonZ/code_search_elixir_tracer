defmodule CodeIntelligenceTracer.CLI do
  @moduledoc """
  Command-line interface for the code intelligence tracer.
  """

  alias CodeIntelligenceTracer.BuildDiscovery
  alias CodeIntelligenceTracer.RunResult

  @switches [
    output: :string,
    format: :string,
    include_deps: :boolean,
    deps: :string,
    env: :string,
    help: :boolean
  ]

  @aliases [
    o: :output,
    f: :format,
    d: :include_deps,
    e: :env,
    h: :help
  ]

  @default_options %{
    output: "call_graph.json",
    format: "json",
    include_deps: false,
    deps: [],
    env: "dev",
    path: "."
  }

  @valid_formats ~w(toon json)

  def main(args) do
    with {:ok, options} <- parse_args(args),
         :ok <- check_help(options),
         {:ok, result} <- run(options) do
      RunResult.print(result)
    else
      :help ->
        print_help()

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{reason}")
        System.halt(1)
    end
  end

  defp check_help(%{help: true}), do: :help
  defp check_help(_options), do: :ok

  @doc """
  Run the call graph extraction with the given options.

  Returns `{:ok, RunResult.t()}` on success or `{:error, reason}` on failure.
  """
  def run(options) do
    with {:ok, build_lib_path} <- BuildDiscovery.find_build_dir(options.path, options.env),
         {:ok, project_apps} <- BuildDiscovery.find_project_apps(options.path) do
      apps = BuildDiscovery.list_app_directories(build_lib_path)
      project_type = BuildDiscovery.detect_project_type(options.path)

      result =
        RunResult.new(
          project_type: project_type,
          project_apps: project_apps,
          build_dir: build_lib_path,
          apps: apps
        )

      # TODO: Continue with BEAM file processing in later tickets
      {:ok, result}
    end
  end

  @doc """
  Parse command-line arguments into a structured options map.

  Returns `{:ok, options}` on success or `{:error, reason}` on failure.
  """
  def parse_args(args) do
    case OptionParser.parse(args, strict: @switches, aliases: @aliases) do
      {opts, rest, []} ->
        build_options(opts, rest)

      {_opts, _rest, invalid} ->
        {:error, format_invalid_options(invalid)}
    end
  end

  defp build_options(opts, rest) do
    options =
      @default_options
      |> apply_parsed_options(opts)
      |> apply_path(rest)

    validate_options(options)
  end

  defp apply_parsed_options(options, opts) do
    Enum.reduce(opts, options, fn
      {:deps, deps_string}, acc ->
        deps = deps_string |> String.split(",") |> Enum.map(&String.trim/1)
        %{acc | deps: deps}

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  defp apply_path(options, []), do: options
  defp apply_path(options, [path | _]), do: %{options | path: path}

  defp validate_options(options) do
    with :ok <- validate_format(options),
         :ok <- validate_deps_exclusivity(options) do
      {:ok, options}
    end
  end

  defp validate_format(%{format: format}) when format in @valid_formats, do: :ok

  defp validate_format(%{format: format}) do
    {:error, "Invalid format '#{format}'. Must be 'json' or 'toon'."}
  end

  defp validate_deps_exclusivity(%{include_deps: true, deps: deps}) when deps != [] do
    {:error, "--include-deps and --deps are mutually exclusive"}
  end

  defp validate_deps_exclusivity(_options), do: :ok

  defp format_invalid_options(invalid) do
    invalid
    |> Enum.map(fn {opt, _} -> opt end)
    |> Enum.join(", ")
    |> then(&"Invalid option(s): #{&1}")
  end

  def print_help do
    IO.puts("""
    Usage: call_graph [OPTIONS] [PATH]

    Extracts call graph information from an Elixir project.

    Arguments:
      PATH                    Path to the Elixir project (default: ".")

    Options:
      -o, --output FILE       Output file path (default: "call_graph.json")
      -f, --format FORMAT     Output format: "json" or "toon" (default: "json")
      -d, --include-deps      Include all dependencies in analysis
          --deps DEPS         Include specific dependencies (comma-separated)
      -e, --env ENV           Mix environment to use (default: "dev")
      -h, --help              Show this help message

    Examples:
      call_graph                          Analyze current directory
      call_graph /path/to/project         Analyze specific project
      call_graph -o output.json           Custom output file
      call_graph --include-deps           Include all dependencies
      call_graph --deps phoenix,ecto      Include specific dependencies
    """)
  end
end
