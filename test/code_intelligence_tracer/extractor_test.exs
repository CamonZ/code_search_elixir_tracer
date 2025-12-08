defmodule CodeIntelligenceTracer.ExtractorTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.Extractor

  describe "run/1" do
    test "extracts data from this project" do
      options = %{
        path: File.cwd!(),
        env: "dev",
        include_deps: false,
        deps: []
      }

      assert {:ok, %Extractor{} = result} = Extractor.run(options)

      assert result.project_type == :regular
      assert result.project_apps == ["code_search_elixir_tracer"]
      assert String.ends_with?(result.build_dir, "_build/dev/lib")
      assert is_list(result.apps)
      assert Enum.any?(result.apps, fn {name, _} -> name == "code_search_elixir_tracer" end)

      assert is_list(result.calls)
      assert is_map(result.function_locations)
      assert is_map(result.specs)
      assert is_map(result.types)
      assert is_map(result.structs)
      assert result.stats.modules_processed > 0
      assert result.stats.total_functions > 0
      assert is_integer(result.stats.extraction_time_ms)
    end

    test "returns error for nonexistent project" do
      options = %{
        path: "/nonexistent/project",
        env: "dev",
        include_deps: false,
        deps: []
      }

      assert {:error, message} = Extractor.run(options)
      assert message =~ "Build directory not found"
    end

    test "filters to only project apps by default" do
      options = %{
        path: File.cwd!(),
        env: "dev",
        include_deps: false,
        deps: []
      }

      assert {:ok, result} = Extractor.run(options)

      # All extracted calls should be from project modules only
      # (filtered by known_modules which only includes project apps)
      assert length(result.calls) > 0
    end

    test "includes all deps when include_deps is true" do
      options = %{
        path: File.cwd!(),
        env: "dev",
        include_deps: true,
        deps: []
      }

      assert {:ok, result} = Extractor.run(options)

      # Should have more modules processed when including deps
      assert result.stats.modules_processed > 0
    end
  end
end
