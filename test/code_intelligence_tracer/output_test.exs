defmodule CodeIntelligenceTracer.OutputTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.Extractor
  alias CodeIntelligenceTracer.Extractor.Stats
  alias CodeIntelligenceTracer.Output

  defp build_extractor(attrs \\ %{}) do
    defaults = %{
      calls: [],
      function_locations: %{},
      specs: %{},
      types: %{},
      structs: %{},
      project_path: "/test/project",
      environment: "dev",
      stats: Stats.new()
    }

    struct(Extractor, Map.merge(defaults, attrs))
  end

  describe "default_filename/1" do
    test "returns correct filename for json format" do
      assert Output.default_filename("json") == "extracted_trace.json"
    end

    test "returns correct filename for toon format" do
      assert Output.default_filename("toon") == "extracted_trace.toon"
    end
  end

  describe "extension/1" do
    test "returns correct extension for json format" do
      assert Output.extension("json") == ".json"
    end

    test "returns correct extension for toon format" do
      assert Output.extension("toon") == ".toon"
    end
  end

  describe "generate/2 with json format" do
    test "outputs valid JSON" do
      extractor = build_extractor()

      json_string = Output.generate(extractor, "json")

      assert {:ok, _decoded} = Jason.decode(json_string)
    end

    test "includes all required metadata fields" do
      extractor = build_extractor(%{project_path: "/test/project", environment: "test"})

      json_string = Output.generate(extractor, "json")
      {:ok, decoded} = Jason.decode(json_string)

      assert Map.has_key?(decoded, "generated_at")
      assert Map.has_key?(decoded, "project_path")
      assert Map.has_key?(decoded, "environment")
      assert Map.has_key?(decoded, "calls")
      assert Map.has_key?(decoded, "function_locations")

      assert decoded["project_path"] == "/test/project"
      assert decoded["environment"] == "test"
    end

    test "generated_at is valid ISO8601 timestamp" do
      extractor = build_extractor()

      json_string = Output.generate(extractor, "json")
      {:ok, decoded} = Jason.decode(json_string)

      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(decoded["generated_at"])
    end

    test "formats calls with caller/callee structure" do
      calls = [
        %{
          type: :remote,
          caller: %{
            module: "MyApp.Foo",
            function: "process/2",
            kind: :def,
            file: "lib/my_app/foo.ex",
            line: 10
          },
          callee: %{
            module: "MyApp.Bar",
            function: "handle",
            arity: 1
          }
        }
      ]

      extractor = build_extractor(%{calls: calls})

      json_string = Output.generate(extractor, "json")
      {:ok, decoded} = Jason.decode(json_string)

      assert length(decoded["calls"]) == 1
      [call] = decoded["calls"]

      assert call["type"] == "remote"
      assert call["caller"]["module"] == "MyApp.Foo"
      assert call["caller"]["function"] == "process/2"
      assert call["caller"]["kind"] == "def"
      assert call["caller"]["file"] == "lib/my_app/foo.ex"
      assert call["caller"]["line"] == 10
      assert call["callee"]["module"] == "MyApp.Bar"
      assert call["callee"]["function"] == "handle"
      assert call["callee"]["arity"] == 1
    end

    test "formats function locations organized by module" do
      locations = %{
        "process/2:10" => %{
          module: "MyApp.Foo",
          name: "process",
          arity: 2,
          line: 10,
          start_line: 10,
          end_line: 25,
          kind: :def,
          guard: nil,
          pattern: "x, y",
          source_file: "lib/my_app/foo.ex",
          source_file_absolute: "/path/lib/my_app/foo.ex",
          source_sha: "abc123def456abc123def456abc123def456abc123def456abc123def456abc1",
          ast_sha: "def456abc123def456abc123def456abc123def456abc123def456abc123def4",
          generated_by: nil,
          macro_source: nil,
          complexity: 3
        },
        "helper/1:27" => %{
          module: "MyApp.Foo",
          name: "helper",
          arity: 1,
          line: 27,
          start_line: 27,
          end_line: 30,
          kind: :defp,
          guard: "is_list(x)",
          pattern: "x",
          source_file: "lib/my_app/foo.ex",
          source_file_absolute: "/path/lib/my_app/foo.ex",
          source_sha: nil,
          ast_sha: "123456789abcdef123456789abcdef123456789abcdef123456789abcdef1234",
          generated_by: nil,
          macro_source: nil,
          complexity: 1
        }
      }

      extractor = build_extractor(%{function_locations: locations})

      json_string = Output.generate(extractor, "json")
      {:ok, decoded} = Jason.decode(json_string)

      # Should be organized by module
      assert Map.has_key?(decoded["function_locations"], "MyApp.Foo")

      foo_funcs = decoded["function_locations"]["MyApp.Foo"]
      assert Map.has_key?(foo_funcs, "process/2:10")
      assert Map.has_key?(foo_funcs, "helper/1:27")

      process = foo_funcs["process/2:10"]
      assert process["name"] == "process"
      assert process["arity"] == 2
      assert process["line"] == 10
      assert process["start_line"] == 10
      assert process["end_line"] == 25
      assert process["kind"] == "def"
      assert process["guard"] == nil
      assert process["pattern"] == "x, y"
      assert process["source_sha"] == "abc123def456abc123def456abc123def456abc123def456abc123def456abc1"
      assert process["ast_sha"] == "def456abc123def456abc123def456abc123def456abc123def456abc123def4"
      assert process["generated_by"] == nil
      assert process["macro_source"] == nil
      assert process["complexity"] == 3

      helper = foo_funcs["helper/1:27"]
      assert helper["name"] == "helper"
      assert helper["arity"] == 1
      assert helper["line"] == 27
      assert helper["guard"] == "is_list(x)"
      assert helper["pattern"] == "x"
      assert helper["source_sha"] == nil
      assert helper["ast_sha"] == "123456789abcdef123456789abcdef123456789abcdef123456789abcdef1234"
      assert helper["generated_by"] == nil
      assert helper["macro_source"] == nil
      assert helper["complexity"] == 1
    end

    test "pretty prints with indentation" do
      extractor = build_extractor()
      json_string = Output.generate(extractor, "json")
      assert is_binary(json_string)
    end

    test "includes extraction metadata from stats" do
      stats =
        Stats.new()
        |> Stats.record_success(10, 5, 2, 1, 1)
        |> Stats.set_extraction_time(500)

      extractor = build_extractor(%{stats: stats})

      json_string = Output.generate(extractor, "json")
      {:ok, decoded} = Jason.decode(json_string)

      metadata = decoded["extraction_metadata"]
      assert metadata["modules_processed"] == 1
      assert metadata["total_calls"] == 10
      assert metadata["total_functions"] == 5
      assert metadata["extraction_time_ms"] == 500
    end

    test "converts atom types to strings" do
      calls = [
        %{
          type: :local,
          caller: %{
            module: "MyApp.Foo",
            function: "bar/0",
            kind: :defp,
            file: "lib/foo.ex",
            line: 5
          },
          callee: %{
            module: "MyApp.Foo",
            function: "helper",
            arity: 0
          }
        }
      ]

      extractor = build_extractor(%{calls: calls})

      json_string = Output.generate(extractor, "json")
      {:ok, decoded} = Jason.decode(json_string)

      [call] = decoded["calls"]
      assert call["type"] == "local"
      assert call["caller"]["kind"] == "defp"
    end
  end

  describe "generate/2 with toon format" do
    test "outputs valid TOON" do
      extractor = build_extractor()

      toon_string = Output.generate(extractor, "toon")

      # TOON should be decodable
      assert {:ok, _decoded} = Toon.decode(toon_string)
    end

    test "includes all required metadata fields" do
      extractor = build_extractor(%{project_path: "/test/project", environment: "test"})

      toon_string = Output.generate(extractor, "toon")
      {:ok, decoded} = Toon.decode(toon_string)

      assert Map.has_key?(decoded, "generated_at")
      assert Map.has_key?(decoded, "project_path")
      assert Map.has_key?(decoded, "environment")
      assert Map.has_key?(decoded, "calls")
      assert Map.has_key?(decoded, "function_locations")

      assert decoded["project_path"] == "/test/project"
      assert decoded["environment"] == "test"
    end

    test "generated_at is valid ISO8601 timestamp" do
      extractor = build_extractor()

      toon_string = Output.generate(extractor, "toon")
      {:ok, decoded} = Toon.decode(toon_string)

      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(decoded["generated_at"])
    end

    test "formats calls with caller/callee structure" do
      calls = [
        %{
          type: :remote,
          caller: %{
            module: "MyApp.Foo",
            function: "process/2",
            kind: :def,
            file: "lib/my_app/foo.ex",
            line: 10
          },
          callee: %{
            module: "MyApp.Bar",
            function: "handle",
            arity: 1
          }
        }
      ]

      extractor = build_extractor(%{calls: calls})

      toon_string = Output.generate(extractor, "toon")
      {:ok, decoded} = Toon.decode(toon_string)

      assert length(decoded["calls"]) == 1
      [call] = decoded["calls"]

      assert call["type"] == "remote"
      assert call["caller"]["module"] == "MyApp.Foo"
      assert call["caller"]["function"] == "process/2"
      assert call["caller"]["kind"] == "def"
      assert call["caller"]["file"] == "lib/my_app/foo.ex"
      assert call["caller"]["line"] == 10
      assert call["callee"]["module"] == "MyApp.Bar"
      assert call["callee"]["function"] == "handle"
      assert call["callee"]["arity"] == 1
    end

    test "formats function locations organized by module" do
      locations = %{
        "process/2:10" => %{
          module: "MyApp.Foo",
          name: "process",
          arity: 2,
          line: 10,
          start_line: 10,
          end_line: 25,
          kind: :def,
          guard: nil,
          pattern: "x, y",
          source_file: "lib/my_app/foo.ex",
          source_file_absolute: "/path/lib/my_app/foo.ex",
          source_sha: "abc123def456abc123def456abc123def456abc123def456abc123def456abc1",
          ast_sha: "def456abc123def456abc123def456abc123def456abc123def456abc123def4",
          generated_by: nil,
          macro_source: nil,
          complexity: 3
        },
        "helper/1:27" => %{
          module: "MyApp.Foo",
          name: "helper",
          arity: 1,
          line: 27,
          start_line: 27,
          end_line: 30,
          kind: :defp,
          guard: "is_list(x)",
          pattern: "x",
          source_file: "lib/my_app/foo.ex",
          source_file_absolute: "/path/lib/my_app/foo.ex",
          source_sha: nil,
          ast_sha: "123456789abcdef123456789abcdef123456789abcdef123456789abcdef1234",
          generated_by: nil,
          macro_source: nil,
          complexity: 1
        }
      }

      extractor = build_extractor(%{function_locations: locations})

      toon_string = Output.generate(extractor, "toon")
      {:ok, decoded} = Toon.decode(toon_string)

      # Should be organized by module
      assert Map.has_key?(decoded["function_locations"], "MyApp.Foo")

      foo_funcs = decoded["function_locations"]["MyApp.Foo"]
      assert Map.has_key?(foo_funcs, "process/2:10")
      assert Map.has_key?(foo_funcs, "helper/1:27")

      process = foo_funcs["process/2:10"]
      assert process["name"] == "process"
      assert process["arity"] == 2
      assert process["line"] == 10
      assert process["start_line"] == 10
      assert process["end_line"] == 25
      assert process["kind"] == "def"
      assert process["guard"] == nil
      assert process["pattern"] == "x, y"
      assert process["source_sha"] == "abc123def456abc123def456abc123def456abc123def456abc123def456abc1"
      assert process["ast_sha"] == "def456abc123def456abc123def456abc123def456abc123def456abc123def4"
      assert process["generated_by"] == nil
      assert process["macro_source"] == nil
      assert process["complexity"] == 3

      helper = foo_funcs["helper/1:27"]
      assert helper["name"] == "helper"
      assert helper["arity"] == 1
      assert helper["line"] == 27
      assert helper["guard"] == "is_list(x)"
      assert helper["pattern"] == "x"
      assert helper["source_sha"] == nil
      assert helper["ast_sha"] == "123456789abcdef123456789abcdef123456789abcdef123456789abcdef1234"
      assert helper["generated_by"] == nil
      assert helper["macro_source"] == nil
      assert helper["complexity"] == 1
    end

    test "includes extraction metadata from stats" do
      stats =
        Stats.new()
        |> Stats.record_success(10, 5, 2, 1, 1)
        |> Stats.set_extraction_time(500)

      extractor = build_extractor(%{stats: stats})

      toon_string = Output.generate(extractor, "toon")
      {:ok, decoded} = Toon.decode(toon_string)

      metadata = decoded["extraction_metadata"]
      assert metadata["modules_processed"] == 1
      assert metadata["total_calls"] == 10
      assert metadata["total_functions"] == 5
      assert metadata["extraction_time_ms"] == 500
    end

    test "converts atom types to strings" do
      calls = [
        %{
          type: :local,
          caller: %{
            module: "MyApp.Foo",
            function: "bar/0",
            kind: :defp,
            file: "lib/foo.ex",
            line: 5
          },
          callee: %{
            module: "MyApp.Foo",
            function: "helper",
            arity: 0
          }
        }
      ]

      extractor = build_extractor(%{calls: calls})

      toon_string = Output.generate(extractor, "toon")
      {:ok, decoded} = Toon.decode(toon_string)

      [call] = decoded["calls"]
      assert call["type"] == "local"
      assert call["caller"]["kind"] == "defp"
    end
  end

  describe "write/3" do
    test "writes JSON to file" do
      tmp_dir = System.tmp_dir!()
      output_path = Path.join([tmp_dir, "test_output_#{:rand.uniform(10000)}", "output.json"])

      extractor = build_extractor()

      try do
        assert :ok = Output.write(extractor, output_path, "json")
        assert File.exists?(output_path)

        content = File.read!(output_path)
        assert {:ok, _decoded} = Jason.decode(content)
      after
        File.rm_rf!(Path.dirname(output_path))
      end
    end

    test "writes TOON to file" do
      tmp_dir = System.tmp_dir!()
      output_path = Path.join([tmp_dir, "test_toon_#{:rand.uniform(10000)}", "output.toon"])

      extractor = build_extractor()

      try do
        assert :ok = Output.write(extractor, output_path, "toon")
        assert File.exists?(output_path)

        content = File.read!(output_path)
        assert {:ok, _decoded} = Toon.decode(content)
      after
        File.rm_rf!(Path.dirname(output_path))
      end
    end

    test "creates parent directories" do
      tmp_dir = System.tmp_dir!()

      nested_path =
        Path.join([tmp_dir, "deep_#{:rand.uniform(10000)}", "nested", "path", "output.json"])

      extractor = build_extractor()

      try do
        assert :ok = Output.write(extractor, nested_path, "json")
        assert File.exists?(nested_path)
      after
        # Clean up the top-level random dir
        top_dir = nested_path |> Path.dirname() |> Path.dirname() |> Path.dirname()
        File.rm_rf!(top_dir)
      end
    end

    test "returns error for invalid path" do
      extractor = build_extractor()

      result =
        Output.write(extractor, "/nonexistent_root_dir_#{:rand.uniform(10000)}/file.json", "json")

      assert {:error, _reason} = result
    end
  end
end
