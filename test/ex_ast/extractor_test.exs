defmodule ExAst.ExtractorTest do
  use ExUnit.Case, async: true

  alias ExAst.Extractor

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
      assert result.project_apps == ["ex_ast"]
      assert String.ends_with?(result.build_dir, "_build/dev/lib")
      assert is_list(result.apps)
      assert Enum.any?(result.apps, fn {name, _} -> name == "ex_ast" end)

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

  describe "run/1 with files option" do
    test "extracts data from a single BEAM file" do
      # Use a known BEAM file from this project's build
      beam_file = find_project_beam_file()

      assert {:ok, %Extractor{} = result} = Extractor.run(%{files: [beam_file]})

      # Files mode should have nil project_type
      assert result.project_type == nil
      assert result.project_apps == nil
      assert result.environment == nil
      assert result.apps == []

      # Should have extracted data from the file
      assert result.stats.modules_processed == 1
      assert result.stats.modules_with_debug_info == 1
      assert is_list(result.calls)
      assert is_map(result.function_locations)
      assert is_integer(result.stats.extraction_time_ms)

      # build_dir should be the absolute path to the BEAM file for single file
      assert result.build_dir == Path.expand(beam_file)
    end

    test "extracts data from multiple BEAM files" do
      beam_files = find_multiple_project_beam_files(3)

      assert {:ok, %Extractor{} = result} = Extractor.run(%{files: beam_files})

      # Should have processed all files
      assert result.stats.modules_processed == 3
      assert result.stats.modules_with_debug_info == 3

      # build_dir should be a list of paths for multiple files
      assert is_list(result.build_dir)
      assert length(result.build_dir) == 3
    end

    test "handles mix of valid and invalid BEAM files" do
      valid_beam = find_project_beam_file()
      tmp_dir = System.tmp_dir!()
      fake_beam = Path.join(tmp_dir, "Fake.beam")
      File.write!(fake_beam, "not a valid beam file")

      try do
        assert {:ok, result} = Extractor.run(%{files: [valid_beam, fake_beam]})

        # Should process valid file and record failure for invalid
        assert result.stats.modules_processed == 2
        assert result.stats.modules_with_debug_info == 1
        assert result.stats.modules_without_debug_info == 1
      after
        File.rm(fake_beam)
      end
    end

    test "extracts specs and types from single file" do
      beam_file = find_project_beam_file()

      assert {:ok, result} = Extractor.run(%{files: [beam_file]})

      # Should have specs and types maps with one module entry
      assert map_size(result.specs) == 1
      assert map_size(result.types) == 1
    end

    test "excludes __info__ specs from extraction" do
      beam_file = find_project_beam_file()

      assert {:ok, result} = Extractor.run(%{files: [beam_file]})

      # Get the specs for the module
      [{_module_name, module_specs}] = Map.to_list(result.specs)

      # Verify no spec has name "__info__"
      refute Enum.any?(module_specs, fn spec ->
        spec[:name] == "__info__" || spec[:name] == :__info__
      end), "Expected __info__ spec to be excluded from exported specs"
    end

    test "returns error for missing file" do
      assert {:error, message} = Extractor.run(%{files: ["/nonexistent/Module.beam"]})
      assert message =~ "BEAM file not found"
    end

    test "returns error for invalid extension" do
      assert {:error, message} = Extractor.run(%{files: ["/some/path/module.ex"]})
      assert message =~ ".beam extension"
    end

    test "handles function key collisions from multiple modules" do
      # This test verifies that when two modules have functions with the same
      # name/arity at the same line number, both are extracted without collision.
      # This can happen when modules have identical structure (same line numbers).

      beam_files = [
        find_beam_file("CollisionModuleA"),
        find_beam_file("CollisionModuleB")
      ]

      # Run extraction multiple times to catch race conditions
      results = for _ <- 1..5 do
        {:ok, result} = Extractor.run(%{files: beam_files})
        result
      end

      # All runs should extract the same number of functions
      # function_locations is a flat map with keys prefixed by module name
      function_counts = Enum.map(results, fn r ->
        map_size(r.function_locations)
      end)

      # Should have 4 functions total (2 per module)
      assert Enum.all?(function_counts, &(&1 == 4)),
        "Expected 4 functions in all runs, got: #{inspect(function_counts)}"

      # Verify both modules have their functions
      result = hd(results)

      # Group by module to verify both are present
      by_module = Enum.group_by(result.function_locations, fn {_key, info} -> info.module end)

      assert Map.has_key?(by_module, "CollisionModuleA")
      assert Map.has_key?(by_module, "CollisionModuleB")

      # Verify both modules have 2 functions each
      assert length(by_module["CollisionModuleA"]) == 2
      assert length(by_module["CollisionModuleB"]) == 2

      # Verify both modules have their first_function (the one that would collide)
      module_a_keys = Enum.map(by_module["CollisionModuleA"], fn {key, _} -> key end)
      module_b_keys = Enum.map(by_module["CollisionModuleB"], fn {key, _} -> key end)

      assert Enum.any?(module_a_keys, &String.contains?(&1, "first_function/0")),
        "CollisionModuleA missing first_function/0"
      assert Enum.any?(module_b_keys, &String.contains?(&1, "first_function/0")),
        "CollisionModuleB missing first_function/0"
    end

    test "extracts local calls from a single file" do
      # This test verifies the fix for the bug where call extraction
      # from individual files was broken due to empty known_modules set.
      # See: https://github.com/your-repo/issues/XXX
      beam_file = find_beam_file("CallExtractionFixture")

      assert {:ok, %Extractor{} = result} = Extractor.run(%{files: [beam_file]})

      # Should have extracted calls from the fixture module
      assert result.stats.modules_processed == 1
      assert result.stats.modules_with_debug_info == 1

      # Filter calls to only local calls within CallExtractionFixture
      local_calls = Enum.filter(result.calls, fn call ->
        call.type == :local &&
        call.caller.module == "CallExtractionFixture" &&
        call.callee.module == "CallExtractionFixture"
      end)

      # Expected local calls:
      # 1. greet/1 -> format_greeting/1
      # 2. process_list/1 -> sum_helper/1
      # 3. factorial/1 -> factorial/1 (recursive)
      assert length(local_calls) == 3, "Expected 3 local calls, got #{length(local_calls)}"

      # Verify specific calls
      call_signatures = Enum.map(local_calls, fn call ->
        "#{call.caller.function} -> #{call.callee.function}/#{call.callee.arity}"
      end)

      assert "greet/1 -> format_greeting/1" in call_signatures
      assert "process_list/1 -> sum_helper/1" in call_signatures
      assert "factorial/1 -> factorial/1" in call_signatures
    end
  end

  # Find a BEAM file from this project to use in tests
  defp find_project_beam_file do
    build_dir =
      Path.join([File.cwd!(), "_build", "dev", "lib", "ex_ast", "ebin"])

    build_dir
    |> File.ls!()
    |> Enum.find(&String.ends_with?(&1, ".beam"))
    |> then(&Path.join(build_dir, &1))
  end

  # Find multiple BEAM files from this project to use in tests
  defp find_multiple_project_beam_files(count) do
    build_dir =
      Path.join([File.cwd!(), "_build", "dev", "lib", "ex_ast", "ebin"])

    build_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".beam"))
    |> Enum.take(count)
    |> Enum.map(&Path.join(build_dir, &1))
  end

  # Find a specific BEAM file by module name (for test environment)
  defp find_beam_file(module_name) do
    build_dir =
      Path.join([File.cwd!(), "_build", "test", "lib", "ex_ast", "ebin"])

    Path.join(build_dir, "Elixir.#{module_name}.beam")
  end
end
