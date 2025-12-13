defmodule CodeIntelligenceTracer.AppSelector do
  @moduledoc """
  Select which applications to process from available apps.

  Handles filtering of applications based on include_deps flag and
  explicit dependency list, respecting project app boundaries.
  """

  @doc """
  Select which apps to process based on options.

  Filters applications based on:
  - `include_deps` - If true, include all dependencies
  - `deps` - List of specific dependencies to include
  - Otherwise - Include only project apps

  ## Parameters

    - `all_apps` - All available apps from build directory (list of {name, ebin_path})
    - `project_apps` - Apps that are part of the project
    - `options` - Map with `:include_deps` and `:deps` keys

  ## Returns

  Filtered list of apps to process, with same structure as input.

  ## Examples

      iex> all = [{:app1, "/path/1"}, {:app2, "/path/2"}, {:dep1, "/path/d"}]
      iex> project = ["app1", "app2"]
      iex> AppSelector.select_apps_to_process(all, project, %{include_deps: true, deps: []})
      [{:app1, "/path/1"}, {:app2, "/path/2"}, {:dep1, "/path/d"}]

      iex> AppSelector.select_apps_to_process(all, project, %{include_deps: false, deps: []})
      [{:app1, "/path/1"}, {:app2, "/path/2"}]

  """
  @spec select_apps_to_process([{String.t() | atom(), String.t()}], [String.t()], map()) ::
          [{String.t() | atom(), String.t()}]
  def select_apps_to_process(all_apps, project_apps, options) do
    cond do
      options[:include_deps] ->
        all_apps

      options[:deps] != [] ->
        project_apps_set = MapSet.new(project_apps)
        deps_set = MapSet.new(options[:deps])

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
end
