defmodule CodeIntelligenceTracer.BeamReader do
  @moduledoc """
  Reads raw chunks from BEAM files using :beam_lib.
  """

  @chunks [:debug_info, :attributes, :abstract_code]

  @doc """
  Read chunks from a BEAM file.

  Attempts to read debug_info, attributes, and abstract_code chunks.
  Missing chunks are returned as nil in the result map.

  Returns `{:ok, {module, chunks}}` where chunks is a map with keys
  `:debug_info`, `:attributes`, and `:abstract_code`.

  Returns `{:error, reason}` for missing or corrupt files.
  """
  @spec read_chunks(String.t()) ::
          {:ok, {module(), map()}} | {:error, String.t()}
  def read_chunks(beam_path) do
    with :ok <- validate_file_exists(beam_path),
         {:ok, module, chunks} <- read_beam_chunks(beam_path) do
      {:ok, {module, chunks}}
    end
  end

  defp validate_file_exists(beam_path) do
    if File.exists?(beam_path) do
      :ok
    else
      {:error, "BEAM file not found: #{beam_path}"}
    end
  end

  defp read_beam_chunks(beam_path) do
    charlist_path = String.to_charlist(beam_path)

    case :beam_lib.chunks(charlist_path, @chunks, [:allow_missing_chunks]) do
      {:ok, {module, chunk_list}} ->
        chunks = build_chunks_map(chunk_list)
        {:ok, module, chunks}

      {:error, :beam_lib, reason} ->
        {:error, format_beam_error(reason)}
    end
  end

  defp build_chunks_map(chunk_list) do
    Enum.reduce(chunk_list, %{}, fn {chunk_name, chunk_data}, acc ->
      Map.put(acc, chunk_name, normalize_chunk_data(chunk_data))
    end)
  end

  defp normalize_chunk_data(:missing_chunk), do: nil
  defp normalize_chunk_data(data), do: data

  defp format_beam_error({:file_error, _path, reason}) do
    "Failed to read BEAM file: #{inspect(reason)}"
  end

  defp format_beam_error({:not_a_beam_file, _path}) do
    "Not a valid BEAM file"
  end

  defp format_beam_error({:invalid_beam_file, _path, _pos}) do
    "Invalid or corrupt BEAM file"
  end

  defp format_beam_error({:chunk_too_big, _path, _chunk, _size, _left}) do
    "BEAM file has corrupt chunk"
  end

  defp format_beam_error(reason) do
    "BEAM file error: #{inspect(reason)}"
  end
end
