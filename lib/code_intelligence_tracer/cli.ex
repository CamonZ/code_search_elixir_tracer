defmodule CodeIntelligenceTracer.CLI do
  @moduledoc """
  Command-line interface for the code intelligence tracer.
  """

  alias CodeIntelligenceTracer.BeamReader
  alias CodeIntelligenceTracer.BuildDiscovery
  alias CodeIntelligenceTracer.CallExtractor
  alias CodeIntelligenceTracer.CallFilter
  alias CodeIntelligenceTracer.FunctionExtractor
  alias CodeIntelligenceTracer.Output
  alias CodeIntelligenceTracer.RunResult
  alias CodeIntelligenceTracer.SpecExtractor
  alias CodeIntelligenceTracer.Stats
  alias CodeIntelligenceTracer.StructExtractor

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
      project_path = Path.expand(options.path)
      apps = BuildDiscovery.list_app_directories(build_lib_path)
      project_type = BuildDiscovery.detect_project_type(options.path)

      # Determine which apps to process based on options
      apps_to_process = select_apps_to_process(apps, project_apps, options)

      # Collect known modules for filtering
      known_modules = BeamReader.collect_modules_from_apps(apps_to_process)

      # Extract calls, function locations, specs, types, and structs from all BEAM files
      {calls, function_locations, specs, types, structs, stats} =
        extract_from_apps(apps_to_process, known_modules)

      # Generate and write output
      output_path = resolve_output_path(options.output, project_path)

      extraction_results = %{
        calls: calls,
        function_locations: function_locations,
        specs: specs,
        types: types,
        structs: structs,
        project_path: project_path,
        environment: options.env,
        stats: stats
      }

      json_string = Output.JSON.generate(extraction_results)
      :ok = Output.JSON.write_file(json_string, output_path)

      result =
        RunResult.new(
          project_type: project_type,
          project_apps: project_apps,
          project_path: project_path,
          build_dir: build_lib_path,
          environment: options.env,
          apps: apps,
          calls: calls,
          function_locations: function_locations,
          stats: stats,
          output_file: output_path
        )

      {:ok, result}
    end
  end

  # Select which apps to process based on CLI options
  defp select_apps_to_process(all_apps, project_apps, options) do
    cond do
      options.include_deps ->
        # Include all apps
        all_apps

      options.deps != [] ->
        # Include project apps + specified deps
        project_apps_set = MapSet.new(project_apps)
        deps_set = MapSet.new(options.deps)

        Enum.filter(all_apps, fn {app_name, _path} ->
          MapSet.member?(project_apps_set, app_name) or MapSet.member?(deps_set, app_name)
        end)

      true ->
        # Only project apps
        project_apps_set = MapSet.new(project_apps)

        Enum.filter(all_apps, fn {app_name, _path} ->
          MapSet.member?(project_apps_set, app_name)
        end)
    end
  end

  # Extract calls, function locations, specs, types, and structs from all apps
  defp extract_from_apps(apps, known_modules) do
    apps
    |> Enum.flat_map(fn {_app_name, ebin_path} ->
      BuildDiscovery.find_beam_files(ebin_path)
    end)
    |> Enum.reduce({[], %{}, %{}, %{}, %{}, Stats.new()}, fn beam_path,
                                                             {calls_acc, locations_acc, specs_acc,
                                                              types_acc, structs_acc, stats} ->
      case process_beam_file(beam_path, known_modules) do
        {:ok, {module_name, new_calls, new_locations, new_specs, new_types, new_struct}} ->
          merged_locations = Map.merge(locations_acc, new_locations)
          merged_specs = Map.put(specs_acc, module_name, new_specs)
          merged_types = Map.put(types_acc, module_name, new_types)
          merged_structs = Map.put(structs_acc, module_name, new_struct)
          structs_count = if new_struct, do: 1, else: 0

          updated_stats =
            Stats.record_success(
              stats,
              length(new_calls),
              map_size(new_locations),
              length(new_specs),
              length(new_types),
              structs_count
            )

          {calls_acc ++ new_calls, merged_locations, merged_specs, merged_types, merged_structs,
           updated_stats}

        {:error, _reason} ->
          # Skip files that can't be processed
          updated_stats = Stats.record_failure(stats)
          {calls_acc, locations_acc, specs_acc, types_acc, structs_acc, updated_stats}
      end
    end)
  end

  # Process a single BEAM file to extract calls, function locations, specs, types, and structs
  defp process_beam_file(beam_path, known_modules) do
    with {:ok, {module, chunks}} <- BeamReader.read_chunks(beam_path),
         {:ok, debug_info} <- BeamReader.extract_debug_info(chunks, module) do
      source_file = debug_info[:file] || ""
      module_name = module_to_string(module)

      # Extract function calls
      calls =
        debug_info.definitions
        |> CallExtractor.extract_calls(module, source_file)
        |> CallFilter.filter_calls(known_modules: known_modules)

      # Extract function locations with module info
      functions =
        debug_info.definitions
        |> FunctionExtractor.extract_functions(source_file)
        |> add_module_to_locations(module)

      # Extract specs and format them
      specs =
        chunks
        |> SpecExtractor.extract_specs()
        |> Enum.map(&SpecExtractor.format_spec/1)

      # Extract types
      types = SpecExtractor.extract_types(chunks)

      # Extract struct definition
      struct_info = StructExtractor.extract_struct(debug_info)

      {:ok, {module_name, calls, functions, specs, types, struct_info}}
    end
  end

  # Add module name to each function location for grouping in output
  defp add_module_to_locations(functions, module) do
    module_string = module_to_string(module)

    functions
    |> Enum.into(%{}, fn {func_key, info} ->
      {func_key, Map.put(info, :module, module_string)}
    end)
  end

  defp module_to_string(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.replace_leading("Elixir.", "")
  end

  # Resolve output path relative to project or as absolute
  defp resolve_output_path(output, project_path) do
    if Path.type(output) == :absolute do
      output
    else
      Path.join(project_path, output)
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
