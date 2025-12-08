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

  defp get_beam_path(module) do
    :code.which(module) |> to_string()
  end
end
