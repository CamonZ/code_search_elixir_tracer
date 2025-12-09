defmodule CodeIntelligenceTracer.FunctionExtractorTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.BeamReader
  alias CodeIntelligenceTracer.FunctionExtractor

  describe "extract_functions/2" do
    test "extracts public function location" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # read_chunks is a public function - find it by prefix since key includes line number
      read_chunks_entries = Enum.filter(functions, fn {key, _} -> String.starts_with?(key, "read_chunks/1:") end)
      assert length(read_chunks_entries) >= 1

      {_key, func_info} = hd(read_chunks_entries)

      assert func_info.kind == :def
      assert func_info.line > 0
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
      assert func_info.line > 0
    end

    test "handles multi-clause functions as separate entries" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(TestSupport.GuardedFunctions))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # multi_guard/1 has 3 clauses, should produce 3 entries
      multi_guard_entries = Enum.filter(functions, fn {key, _} -> String.starts_with?(key, "multi_guard/1:") end)
      assert length(multi_guard_entries) == 3

      # Each entry should have a different line
      lines = Enum.map(multi_guard_entries, fn {_, info} -> info.line end)
      assert length(Enum.uniq(lines)) == 3
    end

    test "returns map keyed by function_name/arity:line" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      assert is_map(functions)

      # All keys should be in "name/arity:line" format
      for key <- Map.keys(functions) do
        assert String.contains?(key, "/"), "Key #{key} should contain /"
        assert String.contains?(key, ":"), "Key #{key} should contain :"
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

    test "includes source_sha and ast_sha fields" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      {_name, func_info} = Enum.at(functions, 0)

      # Should have source_sha (64-char hex string)
      assert is_binary(func_info.source_sha)
      assert func_info.source_sha =~ ~r/^[a-f0-9]{64}$/

      # Should have ast_sha (64-char hex string)
      assert is_binary(func_info.ast_sha)
      assert func_info.ast_sha =~ ~r/^[a-f0-9]{64}$/
    end

    test "includes name and arity fields" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # Find read_chunks/1 entry
      {_key, func_info} = Enum.find(functions, fn {key, _} -> String.starts_with?(key, "read_chunks/1:") end)

      assert func_info.name == "read_chunks"
      assert func_info.arity == 1
    end

    test "includes guard and pattern fields" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(CodeIntelligenceTracer.BeamReader))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # All clauses should have guard (string or nil) and pattern (string)
      for {_name, info} <- functions do
        assert is_binary(info.pattern) or info.pattern == ""
        assert is_binary(info.guard) or is_nil(info.guard)
      end
    end
  end

  describe "extract_functions/2 with guards" do
    test "extracts nil guard for functions without guards" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(TestSupport.GuardedFunctions))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # Find no_guard/1 entry
      {_key, func_info} = Enum.find(functions, fn {key, _} -> String.starts_with?(key, "no_guard/1:") end)

      assert func_info.guard == nil
      assert func_info.pattern == "x"
    end

    test "extracts single guard as string" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(TestSupport.GuardedFunctions))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # Find single_guard/1 entry
      {_key, func_info} = Enum.find(functions, fn {key, _} -> String.starts_with?(key, "single_guard/1:") end)

      assert func_info.guard == "is_binary(x)"
      assert func_info.pattern == "x"
    end

    test "extracts separate entries for multi-clause functions with guards" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(TestSupport.GuardedFunctions))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # multi_guard/1 has 3 clauses
      multi_guard_entries = functions
        |> Enum.filter(fn {key, _} -> String.starts_with?(key, "multi_guard/1:") end)
        |> Enum.sort_by(fn {_, info} -> info.line end)

      assert length(multi_guard_entries) == 3

      [{_, clause1}, {_, clause2}, {_, clause3}] = multi_guard_entries

      assert clause1.guard == "is_binary(x)"
      assert clause2.guard == "is_number(x)"
      assert clause3.guard == nil
    end

    test "extracts compound guards with and" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(TestSupport.GuardedFunctions))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # compound_guard/1 has 3 clauses
      compound_guard_entries = functions
        |> Enum.filter(fn {key, _} -> String.starts_with?(key, "compound_guard/1:") end)
        |> Enum.sort_by(fn {_, info} -> info.line end)

      assert length(compound_guard_entries) == 3

      [{_, clause1}, {_, clause2}, {_, clause3}] = compound_guard_entries

      assert clause1.guard =~ "is_integer(x)"
      assert clause1.guard =~ "x > 0"
      assert clause2.guard =~ "is_integer(x)"
      assert clause2.guard =~ "x < 0"
      assert clause3.guard == nil
    end

    test "extracts guards with or" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(TestSupport.GuardedFunctions))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # or_guard/1 has 2 clauses
      or_guard_entries = functions
        |> Enum.filter(fn {key, _} -> String.starts_with?(key, "or_guard/1:") end)
        |> Enum.sort_by(fn {_, info} -> info.line end)

      assert length(or_guard_entries) == 2

      [{_, clause1}, {_, clause2}] = or_guard_entries

      assert clause1.guard =~ "is_binary(x)"
      assert clause1.guard =~ "is_atom(x)"
      assert clause2.guard == nil
    end

    test "extracts patterns from pattern matching clauses" do
      {:ok, {module, chunks}} = BeamReader.read_chunks(get_beam_path(TestSupport.GuardedFunctions))
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      functions = FunctionExtractor.extract_functions(debug_info.definitions, debug_info.file)

      # pattern_with_guard/1 has 3 clauses with different patterns
      pattern_entries = functions
        |> Enum.filter(fn {key, _} -> String.starts_with?(key, "pattern_with_guard/1:") end)
        |> Enum.sort_by(fn {_, info} -> info.line end)

      assert length(pattern_entries) == 3

      [{_, clause1}, {_, clause2}, {_, clause3}] = pattern_entries

      # First clause: {:ok, value} with guard is_list(value)
      assert clause1.guard =~ "is_list(value)"
      assert clause1.pattern =~ "{:ok, value}"

      # Second clause: {:ok, value} without guard
      assert clause2.guard == nil
      assert clause2.pattern =~ "{:ok, value}"

      # Third clause: {:error, _} = err
      assert clause3.guard == nil
      assert clause3.pattern =~ "{:error, _}"
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
      # Just test the function directly with fixed line numbers
      sha1 = FunctionExtractor.compute_source_sha(
        Path.expand("lib/code_intelligence_tracer/beam_reader.ex"),
        10,
        20
      )

      sha2 = FunctionExtractor.compute_source_sha(
        Path.expand("lib/code_intelligence_tracer/beam_reader.ex"),
        10,
        20
      )

      assert sha1 == sha2
      assert is_binary(sha1)
      assert String.length(sha1) == 64  # SHA256 hex is 64 chars
    end

    test "different line ranges produce different SHAs" do
      sha1 = FunctionExtractor.compute_source_sha(
        Path.expand("lib/code_intelligence_tracer/beam_reader.ex"),
        10,
        20
      )

      sha2 = FunctionExtractor.compute_source_sha(
        Path.expand("lib/code_intelligence_tracer/beam_reader.ex"),
        30,
        40
      )

      # Different line ranges should produce different SHAs
      assert sha1 != sha2
    end

    test "returns nil for missing source file" do
      sha = FunctionExtractor.compute_source_sha("/nonexistent/file.ex", 1, 10)
      assert sha == nil
    end

    test "returns valid hex string" do
      sha = FunctionExtractor.compute_source_sha(
        Path.expand("lib/code_intelligence_tracer/beam_reader.ex"),
        10,
        20
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
