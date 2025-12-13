defmodule CodeIntelligenceTracer.TestHelpers do
  @moduledoc """
  Common test utilities and fixtures.
  """

  alias CodeIntelligenceTracer.BeamReader

  @doc """
  Get the path to the compiled BEAM file for a module.

  ## Examples

      iex> get_beam_path(Enum)
      "/path/to/erlang/lib/stdlib-*/ebin/enum.beam"

      iex> get_beam_path(CodeIntelligenceTracer.BeamReader)
      "/path/to/project/_build/dev/lib/code_search_elixir_tracer/ebin/Elixir.CodeIntelligenceTracer.BeamReader.beam"

  """
  @spec get_beam_path(module()) :: String.t()
  def get_beam_path(module) do
    module
    |> :code.which()
    |> to_string()
  end

  @doc """
  Load and extract debug info from a module's BEAM file.

  Handles the common pattern of reading chunks and extracting debug info.

  ## Examples

      iex> {:ok, debug_info} = load_debug_info(CodeIntelligenceTracer.BeamReader)
      iex> debug_info.definitions |> length()
      15

  """
  @spec load_debug_info(module()) :: {:ok, map()} | {:error, String.t()}
  def load_debug_info(module) do
    beam_path = get_beam_path(module)

    with {:ok, {_module, chunks}} <- BeamReader.read_chunks(beam_path) do
      BeamReader.extract_debug_info(chunks, module)
    end
  end

  @doc """
  Extract data from a module using an extractor function.

  Common pattern for BEAM file extraction:
  1. Get BEAM path
  2. Read chunks
  3. Extract debug info
  4. Apply extractor function
  5. Return result

  ## Examples

      iex> functions = extract_with(CodeIntelligenceTracer.BeamReader, fn debug_info ->
      ...>   FunctionExtractor.extract_functions(debug_info.definitions, debug_info[:file])
      ...> end)
      iex> is_map(functions)
      true

  """
  @spec extract_with(module(), (map() -> term())) :: term() | {:error, String.t()}
  def extract_with(module, extractor_fn) do
    case load_debug_info(module) do
      {:ok, debug_info} -> extractor_fn.(debug_info)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Read chunks from a module's BEAM file.

  Convenience wrapper that combines path lookup and chunk reading.

  ## Examples

      iex> {:ok, {module, chunks}} = read_beam_chunks(Enum)
      iex> is_atom(module)
      true

  """
  @spec read_beam_chunks(module()) :: {:ok, {module(), map()}} | {:error, String.t()}
  def read_beam_chunks(module) do
    module
    |> get_beam_path()
    |> BeamReader.read_chunks()
  end
end
