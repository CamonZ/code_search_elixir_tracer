defmodule CodeIntelligenceTracer.Extractor do
  @moduledoc """
  Extracts call graph information from BEAM files.

  This module handles the core extraction pipeline:
  - Selecting which apps to process based on options
  - Parallel processing of BEAM files
  - Extracting calls, function locations, specs, types, and structs
  """

  alias CodeIntelligenceTracer.BeamReader
  alias CodeIntelligenceTracer.BuildDiscovery
  alias CodeIntelligenceTracer.CallExtractor
  alias CodeIntelligenceTracer.CallFilter
  alias CodeIntelligenceTracer.Extractor.Stats
  alias CodeIntelligenceTracer.FunctionExtractor
  alias CodeIntelligenceTracer.SpecExtractor
  alias CodeIntelligenceTracer.StructExtractor

  defstruct [
    :project_type,
    :project_apps,
    :project_path,
    :build_dir,
    :environment,
    :apps,
    :calls,
    :function_locations,
    :specs,
    :types,
    :structs,
    :stats
  ]

  @type t :: %__MODULE__{
          project_type: :regular | :umbrella,
          project_apps: [String.t()],
          project_path: String.t(),
          build_dir: String.t(),
          environment: String.t(),
          apps: [{String.t(), String.t()}],
          calls: [map()],
          function_locations: %{String.t() => map()},
          specs: map(),
          types: map(),
          structs: map(),
          stats: Stats.t() | nil
        }

  @doc """
  Run the extraction pipeline for an Elixir project.

  Takes an options map with:
  - `path` - Path to the project
  - `env` - Mix environment (e.g., "dev")
  - `include_deps` - Whether to include all dependencies
  - `deps` - List of specific dependencies to include

  Returns `{:ok, %Extractor{}}` on success or `{:error, reason}` on failure.
  """
  @spec run(options :: map()) :: {:ok, t()} | {:error, String.t()}
  def run(options) do
    with {:ok, build_lib_path} <- BuildDiscovery.find_build_dir(options.path, options.env),
         {:ok, project_apps} <- BuildDiscovery.find_project_apps(options.path) do
      project_path = Path.expand(options.path)
      apps = BuildDiscovery.list_app_directories(build_lib_path)
      project_type = BuildDiscovery.detect_project_type(options.path)

      apps_to_process = select_apps_to_process(apps, project_apps, options)
      known_modules = BeamReader.collect_modules_from_apps(apps_to_process)

      {extraction_time_ms, {calls, function_locations, specs, types, structs, stats}} =
        :timer.tc(fn -> extract_from_apps(apps_to_process, known_modules) end, :millisecond)

      stats = Stats.set_extraction_time(stats, extraction_time_ms)

      result = %__MODULE__{
        project_type: project_type,
        project_apps: project_apps,
        project_path: project_path,
        build_dir: build_lib_path,
        environment: options.env,
        apps: apps,
        calls: calls,
        function_locations: function_locations,
        specs: specs,
        types: types,
        structs: structs,
        stats: stats
      }

      {:ok, result}
    end
  end

  # Select which apps to process based on options
  defp select_apps_to_process(all_apps, project_apps, options) do
    cond do
      options.include_deps ->
        all_apps

      options.deps != [] ->
        project_apps_set = MapSet.new(project_apps)
        deps_set = MapSet.new(options.deps)

        Enum.filter(all_apps, fn {app_name, _path} ->
          MapSet.member?(project_apps_set, app_name) or MapSet.member?(deps_set, app_name)
        end)

      true ->
        project_apps_set = MapSet.new(project_apps)

        Enum.filter(all_apps, fn {app_name, _path} ->
          MapSet.member?(project_apps_set, app_name)
        end)
    end
  end

  # Extract calls, function locations, specs, types, and structs from all apps
  # Uses parallel processing for BEAM file extraction
  defp extract_from_apps(apps, known_modules) do
    beam_files =
      apps
      |> Enum.flat_map(fn {_app_name, ebin_path} ->
        BuildDiscovery.find_beam_files(ebin_path)
      end)

    # Process BEAM files in parallel
    results =
      beam_files
      |> Task.async_stream(
        &process_beam_file(&1, known_modules),
        max_concurrency: System.schedulers_online(),
        ordered: false
      )
      |> Enum.map(fn {:ok, result} -> result end)

    # Merge results sequentially
    Enum.reduce(results, {[], %{}, %{}, %{}, %{}, Stats.new()}, fn result,
                                                                   {calls_acc, locations_acc,
                                                                    specs_acc, types_acc,
                                                                    structs_acc, stats} ->
      case result do
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
end
