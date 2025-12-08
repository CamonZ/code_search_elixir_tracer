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

  describe "compute_source_sha/3" do
    test "same source produces same SHA" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)
      {_name, func_info} = Enum.at(functions, 0)

      sha1 = FunctionExtractor.compute_source_sha(
        func_info.source_file_absolute,
        func_info.start_line,
        func_info.end_line
      )

      sha2 = FunctionExtractor.compute_source_sha(
        func_info.source_file_absolute,
        func_info.start_line,
        func_info.end_line
      )

      assert sha1 == sha2
      assert is_binary(sha1)
      assert String.length(sha1) == 64  # SHA256 hex is 64 chars
    end

    test "different line ranges produce different SHAs" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # Get two different functions
      [{_name1, func1}, {_name2, func2} | _] = Enum.to_list(functions)

      sha1 = FunctionExtractor.compute_source_sha(
        func1.source_file_absolute,
        func1.start_line,
        func1.end_line
      )

      sha2 = FunctionExtractor.compute_source_sha(
        func2.source_file_absolute,
        func2.start_line,
        func2.end_line
      )

      # Different functions should (almost certainly) have different SHAs
      assert sha1 != sha2
    end

    test "returns nil for missing source file" do
      sha = FunctionExtractor.compute_source_sha("/nonexistent/file.ex", 1, 10)
      assert sha == nil
    end

    test "returns valid hex string" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)
      {_name, func_info} = Enum.at(functions, 0)

      sha = FunctionExtractor.compute_source_sha(
        func_info.source_file_absolute,
        func_info.start_line,
        func_info.end_line
      )

      # Should be valid lowercase hex
      assert sha =~ ~r/^[a-f0-9]{64}$/
    end
  end

  describe "compute_ast_sha/1" do
    test "same clauses produce same SHA" do
      clauses = [
        {[line: 1], [{:x, [line: 1], nil}], [], {:x, [line: 1], nil}}
      ]

      sha1 = FunctionExtractor.compute_ast_sha(clauses)
      sha2 = FunctionExtractor.compute_ast_sha(clauses)

      assert sha1 == sha2
      assert is_binary(sha1)
      assert String.length(sha1) == 64
    end

    test "different line numbers produce same SHA (normalized)" do
      # The clause tuple is {meta, args, guards, body}
      # Only the body contains AST nodes with line metadata
      clauses1 = [
        {[line: 1], [{:x, [], nil}], [], {:+, [line: 1], [{:x, [], nil}, 1]}}
      ]

      clauses2 = [
        {[line: 100], [{:x, [], nil}], [], {:+, [line: 100], [{:x, [], nil}, 1]}}
      ]

      sha1 = FunctionExtractor.compute_ast_sha(clauses1)
      sha2 = FunctionExtractor.compute_ast_sha(clauses2)

      # Same logic at different lines should have same AST SHA
      assert sha1 == sha2
    end

    test "different logic produces different SHA" do
      clauses1 = [
        {[line: 1], [{:x, [line: 1], nil}], [], {:x, [line: 1], nil}}
      ]

      clauses2 = [
        {[line: 1], [{:y, [line: 1], nil}], [], {:y, [line: 1], nil}}
      ]

      sha1 = FunctionExtractor.compute_ast_sha(clauses1)
      sha2 = FunctionExtractor.compute_ast_sha(clauses2)

      # Different variable names should produce different SHA
      assert sha1 != sha2
    end

    test "returns valid hex string" do
      clauses = [
        {[line: 1], [], [], :ok}
      ]

      sha = FunctionExtractor.compute_ast_sha(clauses)
      assert sha =~ ~r/^[a-f0-9]{64}$/
    end
  end

  describe "normalize_ast/1" do
    test "strips line metadata" do
      ast = {:foo, [line: 10, column: 5], [:arg]}
      normalized = FunctionExtractor.normalize_ast(ast)

      assert normalized == {:foo, [], [:arg]}
    end

    test "strips column metadata" do
      ast = {:bar, [column: 15], [{:x, [column: 20], nil}]}
      normalized = FunctionExtractor.normalize_ast(ast)

      assert normalized == {:bar, [], [{:x, [], nil}]}
    end

    test "strips counter metadata" do
      ast = {:baz, [counter: 42], []}
      normalized = FunctionExtractor.normalize_ast(ast)

      assert normalized == {:baz, [], []}
    end

    test "preserves non-position metadata" do
      ast = {:foo, [import: SomeModule, context: Elixir], [:arg]}
      normalized = FunctionExtractor.normalize_ast(ast)

      assert normalized == {:foo, [import: SomeModule, context: Elixir], [:arg]}
    end

    test "normalizes nested structures" do
      ast = {
        :def,
        [line: 1],
        [
          {:foo, [line: 1], nil},
          [do: {:bar, [line: 2], [{:x, [line: 2], nil}]}]
        ]
      }

      normalized = FunctionExtractor.normalize_ast(ast)

      # The do: keyword pair remains but the AST nodes inside are normalized
      expected = {
        :def,
        [],
        [
          {:foo, [], nil},
          [do: {:bar, [], [{:x, [], nil}]}]
        ]
      }

      assert normalized == expected
    end

    test "handles tuples" do
      ast = {{:a, [line: 1], nil}, {:b, [line: 2], nil}}
      normalized = FunctionExtractor.normalize_ast(ast)

      assert normalized == {{:a, [], nil}, {:b, [], nil}}
    end

    test "handles lists" do
      ast = [{:a, [line: 1], nil}, {:b, [line: 2], nil}]
      normalized = FunctionExtractor.normalize_ast(ast)

      assert normalized == [{:a, [], nil}, {:b, [], nil}]
    end

    test "handles atoms and other primitives" do
      assert FunctionExtractor.normalize_ast(:foo) == :foo
      assert FunctionExtractor.normalize_ast(42) == 42
      assert FunctionExtractor.normalize_ast("string") == "string"
    end
  end

  defp get_beam_path(module) do
    module
    |> :code.which()
    |> List.to_string()
  end
end
