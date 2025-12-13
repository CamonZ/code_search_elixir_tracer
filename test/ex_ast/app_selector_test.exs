defmodule ExAst.AppSelectorTest do
  use ExUnit.Case, async: true

  alias ExAst.AppSelector

  describe "select_apps_to_process/3" do
    test "returns all apps when include_deps is true" do
      all_apps = [
        {"app1", "/path/1"},
        {"app2", "/path/2"},
        {"dep1", "/path/3"}
      ]

      project_apps = ["app1", "app2"]
      options = %{include_deps: true, deps: []}

      result = AppSelector.select_apps_to_process(all_apps, project_apps, options)

      assert result == all_apps
    end

    test "returns only project apps when include_deps is false and no deps specified" do
      all_apps = [
        {"app1", "/path/1"},
        {"app2", "/path/2"},
        {"dep1", "/path/3"}
      ]

      project_apps = ["app1", "app2"]
      options = %{include_deps: false, deps: []}

      result = AppSelector.select_apps_to_process(all_apps, project_apps, options)

      assert result == [{"app1", "/path/1"}, {"app2", "/path/2"}]
    end

    test "returns project apps plus specified dependencies" do
      all_apps = [
        {"app1", "/path/1"},
        {"app2", "/path/2"},
        {"dep1", "/path/3"},
        {"dep2", "/path/4"}
      ]

      project_apps = ["app1", "app2"]
      options = %{include_deps: false, deps: ["dep1"]}

      result = AppSelector.select_apps_to_process(all_apps, project_apps, options)

      # Should include app1, app2 (project apps) and dep1 (explicit dependency)
      assert length(result) == 3
      assert Enum.find(result, fn {name, _} -> name == "app1" end) != nil
      assert Enum.find(result, fn {name, _} -> name == "app2" end) != nil
      assert Enum.find(result, fn {name, _} -> name == "dep1" end) != nil
      assert Enum.find(result, fn {name, _} -> name == "dep2" end) == nil
    end

    test "returns only matching apps when specific dependencies are requested" do
      all_apps = [
        {"app1", "/path/1"},
        {"app2", "/path/2"},
        {"dep1", "/path/3"},
        {"dep2", "/path/4"}
      ]

      project_apps = ["app1"]
      options = %{include_deps: false, deps: ["dep1", "dep2"]}

      result = AppSelector.select_apps_to_process(all_apps, project_apps, options)

      # Should include app1 (project app), dep1, and dep2 (explicit dependencies)
      assert length(result) == 3
      assert Enum.map(result, &elem(&1, 0)) |> Enum.sort() == ["app1", "dep1", "dep2"]
    end

    test "excludes unavailable dependencies" do
      all_apps = [
        {"app1", "/path/1"},
        {"dep1", "/path/2"}
      ]

      project_apps = ["app1"]
      options = %{include_deps: false, deps: ["dep1", "dep_missing"]}

      result = AppSelector.select_apps_to_process(all_apps, project_apps, options)

      # Should include app1 and dep1, but not dep_missing (not available)
      assert length(result) == 2
      assert Enum.find(result, fn {name, _} -> name == "app1" end) != nil
      assert Enum.find(result, fn {name, _} -> name == "dep1" end) != nil
    end

    test "returns empty list when no apps match" do
      all_apps = [
        {"other1", "/path/1"},
        {"other2", "/path/2"}
      ]

      project_apps = ["app1", "app2"]
      options = %{include_deps: false, deps: []}

      result = AppSelector.select_apps_to_process(all_apps, project_apps, options)

      assert result == []
    end

    test "handles empty all_apps list" do
      all_apps = []
      project_apps = ["app1"]
      options = %{include_deps: false, deps: []}

      result = AppSelector.select_apps_to_process(all_apps, project_apps, options)

      assert result == []
    end

    test "handles empty project_apps list" do
      all_apps = [
        {"dep1", "/path/1"},
        {"dep2", "/path/2"}
      ]

      project_apps = []
      options = %{include_deps: false, deps: ["dep1"]}

      result = AppSelector.select_apps_to_process(all_apps, project_apps, options)

      # Should only include explicitly specified dependencies
      assert length(result) == 1
      assert result == [{"dep1", "/path/1"}]
    end

    test "preserves app path information" do
      all_apps = [
        {"app1", "/project/lib/app1/ebin"},
        {"app2", "/project/lib/app2/ebin"}
      ]

      project_apps = ["app1"]
      options = %{include_deps: false, deps: []}

      result = AppSelector.select_apps_to_process(all_apps, project_apps, options)

      assert result == [{"app1", "/project/lib/app1/ebin"}]
    end

    test "prioritizes include_deps over deps list" do
      all_apps = [
        {"app1", "/path/1"},
        {"dep1", "/path/2"},
        {"dep2", "/path/3"}
      ]

      project_apps = ["app1"]
      # Both include_deps and deps are set; include_deps should take precedence
      options = %{include_deps: true, deps: []}

      result = AppSelector.select_apps_to_process(all_apps, project_apps, options)

      # Should return all apps, not just project + specific deps
      assert result == all_apps
    end
  end
end
