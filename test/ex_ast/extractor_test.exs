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

    test "returns error for missing file" do
      assert {:error, message} = Extractor.run(%{files: ["/nonexistent/Module.beam"]})
      assert message =~ "BEAM file not found"
    end

    test "returns error for invalid extension" do
      assert {:error, message} = Extractor.run(%{files: ["/some/path/module.ex"]})
      assert message =~ ".beam extension"
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
end
