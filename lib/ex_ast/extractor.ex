defmodule ExAst.Extractor do
  @moduledoc """
  Extracts call graph information from BEAM files.

  This module handles the core extraction pipeline:
  - Discovering BEAM files from a project or using explicitly provided files
  - Parallel processing of BEAM files
  - Extracting calls, function locations, specs, types, and structs
  """

  alias ExAst.AppSelector
  alias ExAst.BeamReader
  alias ExAst.BuildDiscovery
  alias ExAst.Extractor.CallExtractor
  alias ExAst.CallFilter
  alias ExAst.Extractor.Stats
  alias ExAst.Extractor.FunctionExtractor
  alias ExAst.Extractor.SpecExtractor
  alias ExAst.Extractor.StructExtractor
  alias ExAst.Utils

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
          project_type: :regular | :umbrella | nil,
          project_apps: [String.t()] | nil,
          project_path: String.t(),
          build_dir: String.t() | [String.t()],
          environment: String.t() | nil,
          apps: [{String.t(), String.t()}],
          calls: [map()],
          function_locations: %{String.t() => map()},
          specs: map(),
          types: map(),
          structs: map(),
          stats: Stats.t() | nil
        }

  @doc """
  Run the extraction pipeline.

  ## Options

  When `files` is provided (non-empty list):
  - Validates all files exist and have `.beam` extension
  - Processes only the specified BEAM files
  - Bypasses project discovery

  When `files` is empty or not provided:
  - `path` - Path to the project (required)
  - `env` - Mix environment (e.g., "dev")
  - `include_deps` - Whether to include all dependencies
  - `deps` - List of specific dependencies to include

  Returns `{:ok, %Extractor{}}` on success or `{:error, reason}` on failure.
  """
  @spec run(options :: map()) :: {:ok, t()} | {:error, String.t()}
  def run(%{files: files}) when is_list(files) and files != [] do
    with :ok <- validate_beam_files(files) do
      absolute_paths = Enum.map(files, &Path.expand/1)

      # For display: single file shows path, multiple shows list
      build_dir =
        case absolute_paths do
          [single_path] -> single_path
          paths -> paths
        end

      context = %{
        project_type: nil,
        project_apps: nil,
        project_path: File.cwd!(),
        build_dir: build_dir,
        environment: nil,
        apps: [],
        known_modules: MapSet.new()
      }

      run_extraction(absolute_paths, context)
    end
  end

  def run(options) do
    with {:ok, beam_files, context} <- discover_beam_files(options) do
      run_extraction(beam_files, context)
    end
  end

  # Validate that all provided files exist and have .beam extension
  @spec validate_beam_files([String.t()]) :: :ok | {:error, String.t()}
  defp validate_beam_files(files) do
    Enum.reduce_while(files, :ok, fn file_path, :ok ->
      cond do
        not String.ends_with?(file_path, ".beam") ->
          {:halt, {:error, "File must have .beam extension: #{file_path}"}}

        not File.exists?(file_path) ->
          {:halt, {:error, "BEAM file not found: #{file_path}"}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  # Discover BEAM files from a project
  @spec discover_beam_files(map()) :: {:ok, [String.t()], map()} | {:error, String.t()}
  defp discover_beam_files(options) do
    with {:ok, build_lib_path} <- BuildDiscovery.find_build_dir(options.path, options.env),
         {:ok, project_apps} <- BuildDiscovery.find_project_apps(options.path) do
      apps = BuildDiscovery.list_app_directories(build_lib_path)
      project_type = BuildDiscovery.detect_project_type(options.path)

      apps_to_process = AppSelector.select_apps_to_process(apps, project_apps, options)

      beam_files =
        apps_to_process
        |> Enum.flat_map(fn {_app_name, ebin_path} ->
          BuildDiscovery.find_beam_files(ebin_path)
        end)

      context = %{
        project_type: project_type,
        project_apps: project_apps,
        project_path: Path.expand(options.path),
        build_dir: build_lib_path,
        environment: options.env,
        apps: apps,
        known_modules: BeamReader.collect_modules_from_apps(apps_to_process)
      }

      {:ok, beam_files, context}
    end
  end

  # Run extraction and build result struct
  @spec run_extraction([String.t()], map()) :: {:ok, t()} | {:error, String.t()}
  defp run_extraction(beam_files, context) do
    {extraction_time_ms, {calls, function_locations, specs, types, structs, stats}} =
      :timer.tc(fn -> process_beam_files(beam_files, context.known_modules) end, :millisecond)

    stats = Stats.set_extraction_time(stats, extraction_time_ms)

    extraction_results = %{
      calls: calls,
      function_locations: function_locations,
      specs: specs,
      types: types,
      structs: structs,
      stats: stats
    }

    result =
      struct(
        __MODULE__,
        context
        |> Map.delete(:known_modules)
        |> Map.merge(extraction_results)
      )

    {:ok, result}
  end

  # Process BEAM files in parallel and merge results
  @spec process_beam_files([String.t()], MapSet.t()) ::
          {[map()], map(), map(), map(), map(), map()}
  defp process_beam_files(beam_files, known_modules) do
    results =
      beam_files
      |> Task.async_stream(
        &process_beam_file(&1, known_modules),
        max_concurrency: System.schedulers_online(),
        ordered: false
      )
      |> Enum.map(fn {:ok, result} -> result end)

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

          updated_stats =
            record_module_stats(stats, new_calls, new_locations, new_specs, new_types, new_struct)

          {calls_acc ++ new_calls, merged_locations, merged_specs, merged_types, merged_structs,
           updated_stats}

        {:error, _reason} ->
          updated_stats = Stats.record_failure(stats)
          {calls_acc, locations_acc, specs_acc, types_acc, structs_acc, updated_stats}
      end
    end)
  end

  # Record stats for a successfully processed module
  @spec record_module_stats(map(), [map()], map(), [map()], [map()], map() | nil) :: map()
  defp record_module_stats(stats, calls, locations, specs, types, struct_info) do
    structs_count = if struct_info, do: 1, else: 0

    Stats.record_success(
      stats,
      length(calls),
      map_size(locations),
      length(specs),
      length(types),
      structs_count
    )
  end

  # Process a single BEAM file to extract calls, function locations, specs, types, and structs
  @spec process_beam_file(String.t(), MapSet.t()) ::
          {:ok, {String.t(), [map()], map(), [map()], [map()], map() | nil}}
          | {:error, String.t()}
  defp process_beam_file(beam_path, known_modules) do
    with {:ok, {module, chunks}} <- BeamReader.read_chunks(beam_path),
         {:ok, debug_info} <- BeamReader.extract_debug_info(chunks, module) do
      source_file = debug_info[:file] || ""
      module_name = Utils.module_to_string(module)

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
  # Also prefixes the key with module name to prevent collisions across modules
  @spec add_module_to_locations(map(), atom()) :: map()
  defp add_module_to_locations(functions, module) do
    module_string = Utils.module_to_string(module)

    functions
    |> Enum.into(%{}, fn {func_key, info} ->
      # Prefix key with module to ensure uniqueness across modules
      unique_key = "#{module_string}.#{func_key}"
      {unique_key, Map.put(info, :module, module_string)}
    end)
  end
end
