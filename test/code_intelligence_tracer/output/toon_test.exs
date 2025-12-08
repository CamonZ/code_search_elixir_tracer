defmodule CodeIntelligenceTracer.Output.TOONTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.Extractor
  alias CodeIntelligenceTracer.Extractor.Stats
  alias CodeIntelligenceTracer.Output.TOON

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

  describe "generate/1" do
    test "outputs valid TOON" do
      extractor = build_extractor()

      toon_string = TOON.generate(extractor)

      # TOON should be decodable
      assert {:ok, _decoded} = Toon.decode(toon_string)
    end

    test "includes all required metadata fields" do
      extractor = build_extractor(%{project_path: "/test/project", environment: "test"})

      toon_string = TOON.generate(extractor)
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

      toon_string = TOON.generate(extractor)
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

      toon_string = TOON.generate(extractor)
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
        "process/2" => %{
          module: "MyApp.Foo",
          start_line: 10,
          end_line: 25,
          kind: :def,
          source_file: "lib/my_app/foo.ex",
          source_file_absolute: "/path/lib/my_app/foo.ex"
        },
        "helper/1" => %{
          module: "MyApp.Foo",
          start_line: 27,
          end_line: 30,
          kind: :defp,
          source_file: "lib/my_app/foo.ex",
          source_file_absolute: "/path/lib/my_app/foo.ex"
        }
      }

      extractor = build_extractor(%{function_locations: locations})

      toon_string = TOON.generate(extractor)
      {:ok, decoded} = Toon.decode(toon_string)

      # Should be organized by module
      assert Map.has_key?(decoded["function_locations"], "MyApp.Foo")

      foo_funcs = decoded["function_locations"]["MyApp.Foo"]
      assert Map.has_key?(foo_funcs, "process/2")
      assert Map.has_key?(foo_funcs, "helper/1")

      process = foo_funcs["process/2"]
      assert process["start_line"] == 10
      assert process["end_line"] == 25
      assert process["kind"] == "def"
    end

    test "includes extraction metadata from stats" do
      stats =
        Stats.new()
        |> Stats.record_success(10, 5, 2, 1, 1)
        |> Stats.set_extraction_time(500)

      extractor = build_extractor(%{stats: stats})

      toon_string = TOON.generate(extractor)
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

      toon_string = TOON.generate(extractor)
      {:ok, decoded} = Toon.decode(toon_string)

      [call] = decoded["calls"]
      assert call["type"] == "local"
      assert call["caller"]["kind"] == "defp"
    end
  end

  describe "write_file/2" do
    test "writes TOON to file" do
      tmp_dir = System.tmp_dir!()
      output_path = Path.join([tmp_dir, "test_toon_#{:rand.uniform(10000)}", "output.toon"])

      toon_string = "test: true"

      try do
        assert :ok = TOON.write_file(toon_string, output_path)
        assert File.exists?(output_path)
        assert File.read!(output_path) == toon_string
      after
        File.rm_rf!(Path.dirname(output_path))
      end
    end

    test "creates parent directories" do
      tmp_dir = System.tmp_dir!()
      nested_path = Path.join([tmp_dir, "deep_toon_#{:rand.uniform(10000)}", "nested", "path", "output.toon"])

      toon_string = "nested: true"

      try do
        assert :ok = TOON.write_file(toon_string, nested_path)
        assert File.exists?(nested_path)
      after
        # Clean up the top-level random dir
        top_dir = nested_path |> Path.dirname() |> Path.dirname() |> Path.dirname()
        File.rm_rf!(top_dir)
      end
    end

    test "returns error for invalid path" do
      result = TOON.write_file("test: true", "/nonexistent_root_dir_#{:rand.uniform(10000)}/file.toon")

      assert {:error, _reason} = result
    end
  end
end
