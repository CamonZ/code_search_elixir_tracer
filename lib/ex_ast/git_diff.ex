defmodule ExAst.GitDiff do
  @moduledoc """
  Git integration for incremental analysis.

  This module provides functionality to:
  - Get changed .ex files from git diff
  - Extract module names from .ex files
  - Map modules to BEAM file paths
  - Validate BEAM files exist and are current
  """

  @doc """
  Get BEAM files corresponding to .ex files changed in a git diff.

  Returns `{:ok, beam_files}` if all BEAM files exist and are current,
  or `{:error, reason}` if compilation is needed.

  ## Parameters
    - `git_ref` - Git reference (e.g., "HEAD~1", "main..feature", "--staged")
    - `build_dir` - Path to build directory containing ebin folders
    - `project_path` - Root path of the project (for resolving relative paths)

  ## Examples

      iex> get_beam_files_for_diff("HEAD~1", "_build/dev", ".")
      {:ok, ["_build/dev/lib/myapp/ebin/Elixir.Foo.beam"]}

      iex> get_beam_files_for_diff("--staged", "_build/dev", ".")
      {:error, "Compilation required..."}
  """
  @spec get_beam_files_for_diff(String.t(), String.t(), String.t()) ::
          {:ok, [String.t()]} | {:error, String.t()}
  def get_beam_files_for_diff(git_ref, build_dir, project_path) do
    with {:ok, ex_files} <- get_changed_ex_files(git_ref, project_path),
         {:ok, mappings} <- map_ex_files_to_beams(ex_files, build_dir, project_path) do
      validate_beams_exist_and_current(mappings)
    end
  end

  @doc """
  Get list of .ex files changed in git diff.

  Returns `{:ok, files}` with list of .ex file paths,
  or `{:error, reason}` if git command fails.

  ## Examples

      iex> get_changed_ex_files("HEAD~1", ".")
      {:ok, ["lib/foo.ex", "lib/bar.ex"]}

      iex> get_changed_ex_files("--staged", ".")
      {:ok, ["lib/baz.ex"]}
  """
  @spec get_changed_ex_files(String.t(), String.t()) ::
          {:ok, [String.t()]} | {:error, String.t()}
  def get_changed_ex_files(git_ref, project_path) do
    args = build_git_diff_args(git_ref)

    case System.cmd("git", args, cd: project_path, stderr_to_stdout: true) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.filter(&String.ends_with?(&1, ".ex"))

        {:ok, files}

      {error_output, _} ->
        {:error, "Git command failed: #{String.trim(error_output)}"}
    end
  end

  @doc """
  Extract module names from an .ex file using AST parsing.

  Returns list of module atoms found in the file.

  ## Examples

      iex> extract_modules_from_file("lib/foo.ex")
      [Foo, Foo.Bar]
  """
  @spec extract_modules_from_file(String.t()) :: [atom()]
  def extract_modules_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        extract_modules_from_content(content)

      {:error, _reason} ->
        []
    end
  end

  # Private functions

  defp build_git_diff_args(git_ref) do
    base_args = ["diff", "--name-only"]

    case git_ref do
      "--staged" -> base_args ++ ["--staged"]
      "--cached" -> base_args ++ ["--cached"]
      ref -> base_args ++ [ref]
    end
  end

  defp extract_modules_from_content(content) do
    case Code.string_to_quoted(content) do
      {:ok, ast} ->
        extract_modules_from_ast(ast)

      {:error, _} ->
        # Fallback to regex if parsing fails (e.g., syntax errors)
        extract_modules_with_regex(content)
    end
  end

  defp extract_modules_from_ast(ast) do
    {_ast, modules} =
      Macro.prewalk(ast, [], fn
        {:defmodule, _meta, [{:__aliases__, _, module_parts}, _body]} = node, acc ->
          module_name = Module.concat(module_parts)
          {node, [module_name | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(modules)
  end

  defp extract_modules_with_regex(content) do
    regex = ~r/^\s*defmodule\s+([A-Z][A-Za-z0-9_.]*)/m

    Regex.scan(regex, content)
    |> Enum.map(fn [_, module_name] ->
      String.to_atom("Elixir.#{module_name}")
    end)
  end

  defp map_ex_files_to_beams(ex_files, build_dir, project_path) do
    mappings =
      ex_files
      |> Enum.flat_map(fn ex_file ->
        full_ex_path = Path.join(project_path, ex_file)
        modules = extract_modules_from_file(full_ex_path)

        Enum.map(modules, fn module ->
          beam_filename = "#{Atom.to_string(module)}.beam"
          beam_path = find_beam_in_build_dir(beam_filename, build_dir)
          # Store full path to source file for timestamp comparison
          {full_ex_path, module, beam_path}
        end)
      end)

    {:ok, mappings}
  end

  defp find_beam_in_build_dir(beam_filename, build_dir) do
    # Search for BEAM file in all ebin directories under build_dir
    # Handles both regular and umbrella projects
    ebin_pattern = Path.join([build_dir, "**", "ebin", beam_filename])

    case Path.wildcard(ebin_pattern) do
      [beam_path | _] -> beam_path
      [] -> Path.join([build_dir, "ebin", beam_filename])
    end
  end

  defp validate_beams_exist_and_current(mappings) do
    issues =
      mappings
      |> Enum.map(fn {ex_file, _module, beam_path} ->
        cond do
          not File.exists?(beam_path) ->
            {:missing, ex_file, beam_path}

          source_newer_than_beam?(ex_file, beam_path) ->
            {:outdated, ex_file, beam_path}

          true ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(issues) do
      beam_files = Enum.map(mappings, fn {_, _, beam_path} -> beam_path end)
      {:ok, beam_files}
    else
      {:error, format_compilation_error(issues)}
    end
  end

  defp source_newer_than_beam?(ex_file, beam_path) do
    with {:ok, ex_stat} <- File.stat(ex_file),
         {:ok, beam_stat} <- File.stat(beam_path) do
      ex_mtime = NaiveDateTime.from_erl!(ex_stat.mtime)
      beam_mtime = NaiveDateTime.from_erl!(beam_stat.mtime)

      NaiveDateTime.compare(ex_mtime, beam_mtime) == :gt
    else
      _ -> false
    end
  end

  defp format_compilation_error(issues) do
    grouped = Enum.group_by(issues, fn {type, _, _} -> type end)

    missing = Map.get(grouped, :missing, [])
    outdated = Map.get(grouped, :outdated, [])

    message = """
    Compilation required before analysis.

    The following source files have changed but their BEAM files are missing or outdated:
    """

    message =
      if Enum.empty?(missing) do
        message
      else
        missing_details =
          Enum.map(missing, fn {:missing, ex_file, beam_path} ->
            # Display relative path for better readability
            display_path = Path.relative_to_cwd(ex_file)
            "  #{display_path} → #{Path.basename(beam_path)} (missing)"
          end)
          |> Enum.join("\n")

        message <> "\n" <> missing_details
      end

    message =
      if Enum.empty?(outdated) do
        message
      else
        outdated_details =
          Enum.map(outdated, fn {:outdated, ex_file, beam_path} ->
            # Display relative path for better readability
            display_path = Path.relative_to_cwd(ex_file)

            "  #{display_path} → #{Path.basename(beam_path)} (outdated: source modified after compilation)"
          end)
          |> Enum.join("\n")

        message <> "\n" <> outdated_details
      end

    message <> "\n\nPlease run: mix compile"
  end
end
