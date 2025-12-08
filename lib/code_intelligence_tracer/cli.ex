defmodule CodeIntelligenceTracer.CLI do
  @moduledoc """
  Command-line interface for the code intelligence tracer.
  """

  alias CodeIntelligenceTracer.Extractor
  alias CodeIntelligenceTracer.Output

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
         {:ok, extractor} <- Extractor.run(options) do
      output_path = resolve_output_path(options.output, extractor.project_path)
      :ok = write_output(extractor, output_path, options.format)

      print_result(extractor, output_path)
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

  defp resolve_output_path(output, project_path) do
    if Path.type(output) == :absolute do
      output
    else
      Path.join(project_path, output)
    end
  end

  defp write_output(extractor, output_path, "json") do
    json_string = Output.JSON.generate(extractor)
    Output.JSON.write_file(json_string, output_path)
  end

  defp write_output(extractor, output_path, "toon") do
    toon_string = Output.TOON.generate(extractor)
    Output.TOON.write_file(toon_string, output_path)
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

  defp print_result(%Extractor{} = result, output_path) do
    result
    |> format_result(output_path)
    |> Enum.each(&IO.puts/1)
  end

  defp format_result(%Extractor{stats: stats} = result, output_path) do
    [
      "Project type: #{result.project_type}",
      "Project apps: #{Enum.join(result.project_apps || [], ", ")}",
      "Environment: #{result.environment}",
      "Modules processed: #{stats.modules_processed}",
      "  - With debug info: #{stats.modules_with_debug_info}",
      "  - Without debug info: #{stats.modules_without_debug_info}",
      "Calls extracted: #{stats.total_calls}",
      "Functions indexed: #{stats.total_functions}"
    ]
    |> add_timing(stats.extraction_time_ms)
    |> add_output_file(output_path)
  end

  defp add_timing(lines, nil), do: lines

  defp add_timing(lines, time_ms) when time_ms < 1000 do
    lines ++ ["Extraction time: #{time_ms}ms"]
  end

  defp add_timing(lines, time_ms) do
    seconds = Float.round(time_ms / 1000, 2)
    lines ++ ["Extraction time: #{seconds}s"]
  end

  defp add_output_file(lines, nil), do: lines
  defp add_output_file(lines, output_file), do: lines ++ ["Output written to: #{output_file}"]
end
