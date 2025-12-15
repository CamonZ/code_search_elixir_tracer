defmodule ExAst.Extractor.StructExtractorTest do
  use ExUnit.Case, async: true

  alias ExAst.Extractor.StructExtractor

  describe "extract_struct/1" do
    test "extracts struct with fields" do
      debug_info = %{
        struct: [
          %{field: :name, default: nil},
          %{field: :age, default: 0},
          %{field: :active, default: true}
        ]
      }

      result = StructExtractor.extract_struct(debug_info)

      assert result == %{
               fields: [
                 %{field: "name", default: "nil", required: false},
                 %{field: "age", default: "0", required: false},
                 %{field: "active", default: "true", required: false}
               ]
             }
    end

    test "extracts struct with complex default values" do
      debug_info = %{
        struct: [
          %{field: :items, default: []},
          %{field: :metadata, default: %{}},
          %{field: :status, default: :pending}
        ]
      }

      result = StructExtractor.extract_struct(debug_info)

      assert result == %{
               fields: [
                 %{field: "items", default: "[]", required: false},
                 %{field: "metadata", default: "%{}", required: false},
                 %{field: "status", default: ":pending", required: false}
               ]
             }
    end

    test "returns nil for modules without struct" do
      debug_info = %{struct: nil}
      assert StructExtractor.extract_struct(debug_info) == nil
    end

    test "returns nil for empty struct list" do
      debug_info = %{struct: []}
      assert StructExtractor.extract_struct(debug_info) == nil
    end

    test "returns nil when struct key is missing" do
      debug_info = %{}
      assert StructExtractor.extract_struct(debug_info) == nil
    end

    test "preserves field order" do
      debug_info = %{
        struct: [
          %{field: :z_last, default: nil},
          %{field: :a_first, default: nil},
          %{field: :m_middle, default: nil}
        ]
      }

      result = StructExtractor.extract_struct(debug_info)
      field_names = Enum.map(result.fields, & &1.field)

      assert field_names == ["z_last", "a_first", "m_middle"]
    end
  end

  describe "extract_struct/1 with real BEAM data" do
    test "extracts struct from Stats module" do
      beam_path =
        "_build/dev/lib/ex_ast/ebin/Elixir.ExAst.Extractor.Stats.beam"

      {:ok, {module, chunks}} = ExAst.BeamReader.read_chunks(beam_path)

      {:ok, debug_info} =
        ExAst.BeamReader.extract_debug_info(chunks, module)

      result = StructExtractor.extract_struct(debug_info)

      assert result != nil
      assert is_list(result.fields)
      assert length(result.fields) >= 5

      # Check that expected fields are present
      field_names = Enum.map(result.fields, & &1.field)
      assert "modules_processed" in field_names
      assert "total_calls" in field_names
      assert "total_functions" in field_names

      # Check that defaults are properly formatted
      modules_processed_field = Enum.find(result.fields, &(&1.field == "modules_processed"))
      assert modules_processed_field.default == "0"
      assert modules_processed_field.required == false
    end

    test "returns nil for non-struct module" do
      beam_path =
        "_build/dev/lib/ex_ast/ebin/Elixir.ExAst.CLI.beam"

      {:ok, {module, chunks}} = ExAst.BeamReader.read_chunks(beam_path)

      {:ok, debug_info} =
        ExAst.BeamReader.extract_debug_info(chunks, module)

      result = StructExtractor.extract_struct(debug_info)
      assert result == nil
    end
  end
end
