defmodule ExAst.CLI do
  @moduledoc """
  Command-line interface for the code intelligence tracer.
  """

  alias ExAst.Extractor
  alias ExAst.Output

  # Exit codes
  @exit_success 0
  @exit_error 1
  @exit_compilation_required 2

  @switches [
    output: :string,
    format: :string,
    include_deps: :boolean,
    deps: :string,
    env: :string,
    file: [:string, :keep],
    git_diff: :string,
    help: :boolean
  ]

  @aliases [
    o: :output,
    F: :format,
    d: :include_deps,
    e: :env,
    f: :file,
    g: :git_diff,
    h: :help
  ]

  @default_options %{
    output: nil,
    format: "json",
    include_deps: false,
    deps: [],
    env: "dev",
    path: ".",
    files: [],
    git_diff: nil
  }

  @valid_formats ~w(toon json)

  def main(args) do
    with {:ok, options} <- parse_args(args),
         :ok <- check_help(options),
         {:ok, extractor} <- run_extraction(options) do
      output_path = resolve_output_path(options, extractor)
      :ok = write_output(extractor, output_path, options.format)

      print_result(extractor, output_path)
    else
      :help ->
        print_help()

      {:error, {:compilation_required, message}} ->
        IO.puts(:stderr, "Error: #{message}")
        System.halt(@exit_compilation_required)

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{reason}")
        System.halt(@exit_error)
    end
  end

  defp run_extraction(options) do
    Extractor.run(options)
  end

  defp check_help(%{help: true}), do: :help
  defp check_help(_options), do: :ok

  defp resolve_output_path(%{output: output, format: format}, extractor) do
    filename = output || Output.default_filename(format)

    if Path.type(filename) == :absolute do
      filename
    else
      base_path = output_base_path(extractor)
      Path.join(base_path, filename)
    end
  end

  defp output_base_path(%Extractor{project_type: nil}), do: File.cwd!()
  defp output_base_path(%Extractor{project_path: project_path}), do: project_path

  defp write_output(extractor, output_path, format) do
    Output.write(extractor, output_path, format)
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

      {:file, file_path}, acc ->
        %{acc | files: acc.files ++ [file_path]}

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  defp apply_path(options, []), do: options
  defp apply_path(options, [path | _]), do: %{options | path: path}

  defp validate_options(options) do
    with :ok <- validate_format(options),
         :ok <- validate_deps_exclusivity(options),
         :ok <- validate_git_diff_exclusivity(options) do
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

  defp validate_git_diff_exclusivity(%{git_diff: git_diff, files: files})
       when not is_nil(git_diff) and files != [] do
    {:error, "--git-diff and --file are mutually exclusive"}
  end

  defp validate_git_diff_exclusivity(%{git_diff: git_diff, include_deps: true})
       when not is_nil(git_diff) do
    {:error, "--git-diff and --include-deps are mutually exclusive"}
  end

  defp validate_git_diff_exclusivity(%{git_diff: git_diff, deps: deps})
       when not is_nil(git_diff) and deps != [] do
    {:error, "--git-diff and --deps are mutually exclusive"}
  end

  defp validate_git_diff_exclusivity(_options), do: :ok

  defp format_invalid_options(invalid) do
    invalid
    |> Enum.map(fn {opt, _} -> opt end)
    |> Enum.join(", ")
    |> then(&"Invalid option(s): #{&1}")
  end

  def print_help do
    IO.puts("""
    Usage: ex_ast [OPTIONS] [PATH]

    Extracts call graph information from an Elixir project.

    Arguments:
      PATH                    Path to the Elixir project (default: ".")

    Options:
      -o, --output FILE       Output file path (default: "extracted_trace.<format>")
      -F, --format FORMAT     Output format: "json" or "toon" (default: "json")
      -f, --file BEAM_FILE    Process specific BEAM file(s) instead of a project
                              (can be specified multiple times)
      -g, --git-diff REF      Process only files changed in git diff
                              REF can be: commit hash, branch name, "HEAD~1", "--staged", etc.
                              Requires corresponding BEAM files to already exist
      -d, --include-deps      Include all dependencies in analysis
          --deps DEPS         Include specific dependencies (comma-separated)
      -e, --env ENV           Mix environment to use (default: "dev")
      -h, --help              Show this help message

    Exit Codes:
      0                       Success
      1                       General error (invalid options, file not found, etc.)
      2                       Compilation required (BEAM files missing or outdated)

    Examples:
      ex_ast                          Analyze current directory
      ex_ast /path/to/project         Analyze specific project
      ex_ast -o output.json           Custom output file
      ex_ast --include-deps           Include all dependencies
      ex_ast --deps phoenix,ecto      Include specific dependencies
      ex_ast -f path/to/Module.beam   Analyze a single BEAM file
      ex_ast -f A.beam -f B.beam      Analyze multiple BEAM files
      ex_ast --git-diff HEAD~1        Analyze files changed in last commit
      ex_ast --git-diff main..feature Analyze files changed between branches
      ex_ast --git-diff --staged      Analyze staged changes
    """)
  end

  defp print_result(%Extractor{} = result, output_path) do
    result
    |> format_result(output_path)
    |> Enum.each(&IO.puts/1)
  end

  defp format_result(%Extractor{stats: stats, project_type: nil} = result, output_path) do
    file_info = format_file_info(result.build_dir)

    [
      "Mode: file(s)",
      file_info,
      "Modules processed: #{stats.modules_processed}",
      "  - With debug info: #{stats.modules_with_debug_info}",
      "  - Without debug info: #{stats.modules_without_debug_info}",
      "Calls extracted: #{stats.total_calls}",
      "Functions indexed: #{stats.total_functions}"
    ]
    |> add_timing(stats.extraction_time_ms)
    |> add_output_file(output_path)
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

  defp format_file_info(files) when is_list(files) do
    "Files: #{length(files)}"
  end

  defp format_file_info(file) when is_binary(file) do
    "File: #{file}"
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
