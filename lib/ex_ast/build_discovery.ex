defmodule ExAst.BuildDiscovery do
  @moduledoc """
  Discovers compiled applications in a Mix project's build directory.
  """

  @type project_type :: :regular | :umbrella

  @doc """
  Detect whether a project is a regular Mix project or an umbrella project.

  Returns `:umbrella` if the project has an `apps/` directory with subdirectories
  containing `mix.exs` files, otherwise returns `:regular`.
  """
  @spec detect_project_type(String.t()) :: project_type()
  def detect_project_type(project_path) do
    apps_path = Path.join(project_path, "apps")

    if File.dir?(apps_path) && has_app_subdirectories?(apps_path) do
      :umbrella
    else
      :regular
    end
  end

  defp has_app_subdirectories?(apps_path) do
    case File.ls(apps_path) do
      {:ok, entries} ->
        Enum.any?(entries, fn entry ->
          mix_exs_path = Path.join([apps_path, entry, "mix.exs"])
          File.regular?(mix_exs_path)
        end)

      {:error, _} ->
        false
    end
  end

  @doc """
  Find all project application names (excluding dependencies).

  For regular projects, returns a single-element list with the app name from `mix.exs`.
  For umbrella projects, returns all app names from `apps/*/mix.exs`.

  Returns `{:ok, [app_names]}` or `{:error, reason}`.
  """
  @spec find_project_apps(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def find_project_apps(project_path) do
    case detect_project_type(project_path) do
      :regular ->
        find_regular_project_app(project_path)

      :umbrella ->
        find_umbrella_project_apps(project_path)
    end
  end

  defp find_regular_project_app(project_path) do
    mix_exs_path = Path.join(project_path, "mix.exs")

    case parse_app_name(mix_exs_path) do
      {:ok, app_name} -> {:ok, [app_name]}
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_umbrella_project_apps(project_path) do
    apps_path = Path.join(project_path, "apps")

    case File.ls(apps_path) do
      {:ok, entries} ->
        app_names =
          entries
          |> Enum.map(fn entry -> Path.join([apps_path, entry, "mix.exs"]) end)
          |> Enum.filter(&File.regular?/1)
          |> Enum.map(&parse_app_name/1)
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, name} -> name end)

        {:ok, app_names}

      {:error, reason} ->
        {:error, "Failed to read apps directory: #{inspect(reason)}"}
    end
  end

  @doc """
  Parse the app name from a mix.exs file.

  Extracts the `:app` value from the project definition.
  """
  @spec parse_app_name(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def parse_app_name(mix_exs_path) do
    case File.read(mix_exs_path) do
      {:ok, content} ->
        extract_app_name(content, mix_exs_path)

      {:error, reason} ->
        {:error, "Failed to read #{mix_exs_path}: #{inspect(reason)}"}
    end
  end

  defp extract_app_name(content, mix_exs_path) do
    # Match app: :app_name pattern in the mix.exs content
    case Regex.run(~r/app:\s*:(\w+)/, content) do
      [_, app_name] ->
        {:ok, app_name}

      nil ->
        {:error, "Could not find app name in #{mix_exs_path}"}
    end
  end

  @doc """
  Find the build lib directory for a project.

  Returns `{:ok, path}` if the build directory exists, or `{:error, reason}` otherwise.

  ## Examples

      iex> find_build_dir("/path/to/project", "dev")
      {:ok, "/path/to/project/_build/dev/lib"}

  """
  @spec find_build_dir(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def find_build_dir(project_path, env) do
    build_lib_path = Path.join([project_path, "_build", env, "lib"])

    if File.dir?(build_lib_path) do
      {:ok, build_lib_path}
    else
      {:error, "Build directory not found: #{build_lib_path}. Run 'mix compile' first."}
    end
  end

  @doc """
  List all application directories in the build lib path.

  Returns a list of `{app_name, ebin_path}` tuples for each application
  that has an ebin directory.

  ## Examples

      iex> list_app_directories("/path/to/project/_build/dev/lib")
      [{"my_app", "/path/to/project/_build/dev/lib/my_app/ebin"}, ...]

  """
  @spec list_app_directories(String.t()) :: [{String.t(), String.t()}]
  def list_app_directories(build_lib_path) do
    case File.ls(build_lib_path) do
      {:ok, entries} ->
        entries
        |> Enum.map(&build_app_tuple(build_lib_path, &1))
        |> Enum.filter(&has_ebin?/1)

      {:error, _} ->
        []
    end
  end

  defp build_app_tuple(build_lib_path, app_name) do
    ebin_path = Path.join([build_lib_path, app_name, "ebin"])
    {app_name, ebin_path}
  end

  defp has_ebin?({_app_name, ebin_path}), do: File.dir?(ebin_path)

  @doc """
  Find all Elixir BEAM files in an application's ebin directory.

  Returns a list of absolute paths to BEAM files that are Elixir modules
  (files matching `Elixir.*.beam` pattern).

  Returns an empty list if the directory is empty or doesn't exist.

  ## Examples

      iex> find_beam_files("/path/to/app/ebin")
      ["/path/to/app/ebin/Elixir.MyApp.beam", "/path/to/app/ebin/Elixir.MyApp.Foo.beam"]

  """
  @spec find_beam_files(String.t()) :: [String.t()]
  def find_beam_files(ebin_path) do
    pattern = Path.join(ebin_path, "Elixir.*.beam")

    pattern
    |> Path.wildcard()
    |> Enum.map(&Path.expand/1)
  end
end
