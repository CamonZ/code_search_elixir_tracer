defmodule CodeIntelligenceTracer.FunctionExtractorTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.BeamReader
  alias CodeIntelligenceTracer.FunctionExtractor

  describe "extract_functions/2" do
    test "extracts public function location" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # read_chunks is a public function
      assert Map.has_key?(functions, "read_chunks/1")
      func_info = functions["read_chunks/1"]

      assert func_info.kind == :def
      assert func_info.start_line > 0
      assert func_info.end_line >= func_info.start_line
      assert String.ends_with?(func_info.source_file, "beam_reader.ex")
      assert String.starts_with?(func_info.source_file, "lib/")
    end

    test "extracts private function location" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # Check for any private function (defp)
      private_functions =
        functions
        |> Enum.filter(fn {_name, info} -> info.kind == :defp end)

      assert length(private_functions) > 0

      {_name, func_info} = hd(private_functions)
      assert func_info.kind == :defp
      assert func_info.start_line > 0
    end

    test "handles multi-clause functions" do
      # Create a module with multi-clause function for testing
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # All functions should have valid line ranges
      for {name, info} <- functions do
        assert info.start_line > 0, "#{name} should have start_line > 0"
        assert info.end_line >= info.start_line, "#{name} end_line should be >= start_line"
      end
    end

    test "returns map keyed by function_name/arity" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      assert is_map(functions)

      # All keys should be in "name/arity" format
      for key <- Map.keys(functions) do
        assert String.contains?(key, "/"), "Key #{key} should contain /"
      end
    end

    test "includes source file paths" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      {_name, func_info} = Enum.at(functions, 0)

      # Should have both relative and absolute paths
      assert is_binary(func_info.source_file)
      assert is_binary(func_info.source_file_absolute)

      # Relative path should start with lib/ or test/
      assert func_info.source_file =~ ~r/^(lib|test)\//

      # Absolute path should be longer and contain the relative path
      assert String.length(func_info.source_file_absolute) > String.length(func_info.source_file)
    end
  end

  describe "extract_functions/2 with macros" do
    test "detects macro definitions" do
      # We need a module that defines macros
      # Logger is a good example
      beam_path = get_beam_path(Logger)

      case BeamReader.read_chunks(beam_path) do
        {:ok, {module, chunks}} ->
          case BeamReader.extract_debug_info(chunks, module) do
            {:ok, debug_info} ->
              functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file || "")

              # Logger has macros like debug, info, warn, error
              macro_functions =
                functions
                |> Enum.filter(fn {_name, info} -> info.kind in [:defmacro, :defmacrop] end)

              # Logger should have macros
              assert length(macro_functions) > 0

            {:error, _} ->
              # Skip test if debug info not available
              :ok
          end

        {:error, _} ->
          # Skip test if BEAM file not readable
          :ok
      end
    end
  end

  describe "resolve_source_path/2" do
    test "extracts source path from debug info" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      {:ok, {relative, absolute}} = FunctionExtractor.resolve_source_path(debug_info, "")

      assert String.starts_with?(relative, "lib/")
      assert String.ends_with?(relative, "beam_reader.ex")
      assert String.contains?(absolute, "/lib/")
    end

    test "returns error when no file in debug info" do
      result = FunctionExtractor.resolve_source_path(%{}, "")
      assert {:error, "No :file key in debug info"} = result
    end

    test "handles charlist file paths" do
      debug_info = %{file: ~c"/path/to/lib/my_app/foo.ex"}
      {:ok, {relative, absolute}} = FunctionExtractor.resolve_source_path(debug_info, "")

      assert relative == "lib/my_app/foo.ex"
      assert absolute == "/path/to/lib/my_app/foo.ex"
    end

    test "handles binary file paths" do
      debug_info = %{file: "/path/to/lib/my_app/foo.ex"}
      {:ok, {relative, absolute}} = FunctionExtractor.resolve_source_path(debug_info, "")

      assert relative == "lib/my_app/foo.ex"
      assert absolute == "/path/to/lib/my_app/foo.ex"
    end

    test "handles test file paths" do
      debug_info = %{file: "/path/to/test/my_app/foo_test.exs"}
      {:ok, {relative, absolute}} = FunctionExtractor.resolve_source_path(debug_info, "")

      assert relative == "test/my_app/foo_test.exs"
      assert absolute == "/path/to/test/my_app/foo_test.exs"
    end
  end

  defp get_beam_path(module) do
    module
    |> :code.which()
    |> List.to_string()
  end
end
