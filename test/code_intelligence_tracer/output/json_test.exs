defmodule CodeIntelligenceTracer.Output.JSONTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.Output.JSON

  describe "generate/1" do
    test "outputs valid JSON" do
      results = %{
        calls: [],
        function_locations: %{},
        project_path: "/test/project",
        environment: "dev"
      }

      json_string = JSON.generate(results)

      assert {:ok, _decoded} = Jason.decode(json_string)
    end

    test "includes all required metadata fields" do
      results = %{
        calls: [],
        function_locations: %{},
        project_path: "/test/project",
        environment: "test"
      }

      json_string = JSON.generate(results)
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
      results = %{calls: [], function_locations: %{}}

      json_string = JSON.generate(results)
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

      results = %{calls: calls, function_locations: %{}}

      json_string = JSON.generate(results)
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

      results = %{calls: [], function_locations: locations}

      json_string = JSON.generate(results)
      {:ok, decoded} = Jason.decode(json_string)

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

    test "pretty prints with indentation" do
      results = %{calls: [], function_locations: %{}}

      json_string = JSON.generate(results)

      # Pretty printed JSON should have newlines and indentation
      assert String.contains?(json_string, "\n")
      assert String.contains?(json_string, "  ")
    end

    test "handles empty results" do
      results = %{}

      json_string = JSON.generate(results)
      {:ok, decoded} = Jason.decode(json_string)

      assert decoded["calls"] == []
      assert decoded["function_locations"] == %{}
      assert decoded["project_path"] == ""
      assert decoded["environment"] == "dev"
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

      results = %{calls: calls, function_locations: %{}}

      json_string = JSON.generate(results)
      {:ok, decoded} = Jason.decode(json_string)

      [call] = decoded["calls"]
      assert call["type"] == "local"
      assert call["caller"]["kind"] == "defp"
    end
  end

  describe "write_file/2" do
    test "writes JSON to file" do
      tmp_dir = System.tmp_dir!()
      output_path = Path.join([tmp_dir, "test_output_#{:rand.uniform(10000)}", "output.json"])

      json_string = ~s({"test": true})

      try do
        assert :ok = JSON.write_file(json_string, output_path)
        assert File.exists?(output_path)
        assert File.read!(output_path) == json_string
      after
        File.rm_rf!(Path.dirname(output_path))
      end
    end

    test "creates parent directories" do
      tmp_dir = System.tmp_dir!()
      nested_path = Path.join([tmp_dir, "deep_#{:rand.uniform(10000)}", "nested", "path", "output.json"])

      json_string = ~s({"nested": true})

      try do
        assert :ok = JSON.write_file(json_string, nested_path)
        assert File.exists?(nested_path)
      after
        # Clean up the top-level random dir
        top_dir = nested_path |> Path.dirname() |> Path.dirname() |> Path.dirname()
        File.rm_rf!(top_dir)
      end
    end

    test "returns error for invalid path" do
      # Try to write to a path that can't be created (root-level on most systems)
      result = JSON.write_file("{}", "/nonexistent_root_dir_#{:rand.uniform(10000)}/file.json")

      assert {:error, _reason} = result
    end
  end
end
