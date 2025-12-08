defmodule CodeIntelligenceTracer.BeamReaderTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.BeamReader

  describe "read_chunks/1" do
    test "reads chunks from valid BEAM file" do
      # Use our own module's BEAM file
      beam_path = get_beam_path(CodeIntelligenceTracer.BeamReader)

      assert {:ok, {module, chunks}} = BeamReader.read_chunks(beam_path)

      assert module == CodeIntelligenceTracer.BeamReader
      assert is_map(chunks)
      assert Map.has_key?(chunks, :debug_info)
      assert Map.has_key?(chunks, :attributes)
      assert Map.has_key?(chunks, :abstract_code)
    end

    test "returns debug_info chunk" do
      beam_path = get_beam_path(CodeIntelligenceTracer.BeamReader)

      assert {:ok, {_module, chunks}} = BeamReader.read_chunks(beam_path)

      # debug_info should be present for modules compiled with debug info
      assert chunks.debug_info != nil
    end

    test "returns attributes chunk" do
      beam_path = get_beam_path(CodeIntelligenceTracer.BeamReader)

      assert {:ok, {_module, chunks}} = BeamReader.read_chunks(beam_path)

      assert is_list(chunks.attributes)
      # Should have vsn attribute at minimum
      assert Keyword.has_key?(chunks.attributes, :vsn)
    end

    test "handles BEAM without abstract_code chunk" do
      # Most modern BEAM files have debug_info but not abstract_code
      beam_path = get_beam_path(CodeIntelligenceTracer.BeamReader)

      assert {:ok, {_module, chunks}} = BeamReader.read_chunks(beam_path)

      # abstract_code is often nil in modern Elixir (uses debug_info instead)
      # Just verify it's either nil or a valid term
      assert chunks.abstract_code == nil or is_tuple(chunks.abstract_code)
    end

    test "returns error for non-existent file" do
      assert {:error, message} = BeamReader.read_chunks("/nonexistent/file.beam")
      assert message =~ "BEAM file not found"
    end

    test "returns error for corrupt/invalid BEAM file" do
      # Create a temp file that's not a valid BEAM file
      tmp_path = Path.join(System.tmp_dir!(), "not_a_beam_#{:rand.uniform(1000)}.beam")
      File.write!(tmp_path, "not a beam file contents")

      try do
        assert {:error, message} = BeamReader.read_chunks(tmp_path)
        assert message =~ "Not a valid BEAM file" or message =~ "BEAM file error"
      after
        File.rm!(tmp_path)
      end
    end

    test "returns error for non-BEAM file (text file)" do
      tmp_path = Path.join(System.tmp_dir!(), "text_file_#{:rand.uniform(1000)}.beam")
      File.write!(tmp_path, "module_info() -> ok.")

      try do
        assert {:error, _message} = BeamReader.read_chunks(tmp_path)
      after
        File.rm!(tmp_path)
      end
    end
  end

  describe "extract_debug_info/2" do
    test "extracts debug info from Elixir module" do
      beam_path = get_beam_path(CodeIntelligenceTracer.BeamReader)
      {:ok, {module, chunks}} = BeamReader.read_chunks(beam_path)

      assert {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      assert is_map(debug_info)
      assert Map.has_key?(debug_info, :definitions)
      assert Map.has_key?(debug_info, :module)
      assert debug_info.module == CodeIntelligenceTracer.BeamReader
    end

    test "debug info contains function definitions" do
      beam_path = get_beam_path(CodeIntelligenceTracer.BeamReader)
      {:ok, {module, chunks}} = BeamReader.read_chunks(beam_path)
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      assert is_list(debug_info.definitions)
      # Should have at least read_chunks and extract_debug_info
      function_names =
        Enum.map(debug_info.definitions, fn {{name, _arity}, _kind, _meta, _clauses} -> name end)

      assert :read_chunks in function_names
      assert :extract_debug_info in function_names
    end

    test "debug info contains source file path" do
      beam_path = get_beam_path(CodeIntelligenceTracer.BeamReader)
      {:ok, {module, chunks}} = BeamReader.read_chunks(beam_path)
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      assert is_binary(debug_info.file)
      assert String.ends_with?(debug_info.file, "beam_reader.ex")
    end

    test "returns error for Erlang-only modules" do
      # :lists is a pure Erlang module without Elixir debug info
      beam_path = get_beam_path(:lists)
      {:ok, {module, chunks}} = BeamReader.read_chunks(beam_path)

      assert {:error, message} = BeamReader.extract_debug_info(chunks, module)
      # Erlang modules use :erl_abstract_code backend which returns :unknown_format for :elixir_v1
      assert message =~ "unknown_format" or message =~ "Unsupported" or message =~ "missing"
    end

    test "returns error for missing debug_info chunk" do
      chunks = %{debug_info: nil, attributes: [], abstract_code: nil}

      assert {:error, message} = BeamReader.extract_debug_info(chunks, SomeModule)
      assert message =~ "No debug_info chunk available"
    end
  end

  describe "collect_module_names/1" do
    test "collects module names from BEAM paths" do
      beam_path = get_beam_path(CodeIntelligenceTracer.BeamReader)

      modules = BeamReader.collect_module_names([beam_path])

      assert %MapSet{} = modules
      assert MapSet.member?(modules, "CodeIntelligenceTracer.BeamReader")
    end

    test "collects multiple module names" do
      beam_paths = [
        get_beam_path(CodeIntelligenceTracer.BeamReader),
        get_beam_path(CodeIntelligenceTracer.BuildDiscovery)
      ]

      modules = BeamReader.collect_module_names(beam_paths)

      assert MapSet.size(modules) == 2
      assert MapSet.member?(modules, "CodeIntelligenceTracer.BeamReader")
      assert MapSet.member?(modules, "CodeIntelligenceTracer.BuildDiscovery")
    end

    test "returns MapSet for O(1) lookup" do
      beam_path = get_beam_path(CodeIntelligenceTracer.BeamReader)
      modules = BeamReader.collect_module_names([beam_path])

      # MapSet provides O(1) membership check
      assert %MapSet{} = modules
    end

    test "skips invalid BEAM files" do
      tmp_path = Path.join(System.tmp_dir!(), "invalid_#{:rand.uniform(1000)}.beam")
      File.write!(tmp_path, "not a beam file")

      valid_path = get_beam_path(CodeIntelligenceTracer.BeamReader)

      try do
        modules = BeamReader.collect_module_names([tmp_path, valid_path])

        # Should only have the valid module
        assert MapSet.size(modules) == 1
        assert MapSet.member?(modules, "CodeIntelligenceTracer.BeamReader")
      after
        File.rm!(tmp_path)
      end
    end

    test "returns empty MapSet for empty input" do
      modules = BeamReader.collect_module_names([])
      assert modules == MapSet.new()
    end

    test "strips Elixir. prefix from module names" do
      beam_path = get_beam_path(Enum)
      modules = BeamReader.collect_module_names([beam_path])

      assert MapSet.member?(modules, "Enum")
      refute MapSet.member?(modules, "Elixir.Enum")
    end
  end

  describe "collect_modules_from_apps/1" do
    test "collects modules from app directories" do
      project_path = File.cwd!()

      {:ok, build_lib_path} =
        CodeIntelligenceTracer.BuildDiscovery.find_build_dir(project_path, "dev")

      app_dirs = [{"code_search_elixir_tracer", Path.join(build_lib_path, "code_search_elixir_tracer/ebin")}]

      modules = BeamReader.collect_modules_from_apps(app_dirs)

      assert %MapSet{} = modules
      assert MapSet.size(modules) > 0
      assert MapSet.member?(modules, "CodeIntelligenceTracer.BeamReader")
      assert MapSet.member?(modules, "CodeIntelligenceTracer.BuildDiscovery")
    end

    test "collects from multiple apps" do
      project_path = File.cwd!()

      {:ok, build_lib_path} =
        CodeIntelligenceTracer.BuildDiscovery.find_build_dir(project_path, "dev")

      # Our project only has one app, but test the structure
      app_dirs = [
        {"code_search_elixir_tracer", Path.join(build_lib_path, "code_search_elixir_tracer/ebin")}
      ]

      modules = BeamReader.collect_modules_from_apps(app_dirs)

      # Should have multiple modules from the app
      assert MapSet.size(modules) >= 3
    end

    test "returns empty MapSet for empty app list" do
      modules = BeamReader.collect_modules_from_apps([])
      assert modules == MapSet.new()
    end
  end

  defp get_beam_path(module) do
    module
    |> :code.which()
    |> to_string()
  end
end
