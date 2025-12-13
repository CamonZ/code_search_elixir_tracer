defmodule ExAst.Extractor.Stats do
  @moduledoc """
  Tracks extraction statistics during call graph analysis.

  Provides a struct to accumulate counts during processing and
  functions to update and query statistics.

  ## Statistics Tracked

  - `modules_processed` - Total BEAM files attempted
  - `modules_with_debug_info` - Modules successfully processed with Elixir debug info
  - `modules_without_debug_info` - Modules skipped (no debug info or errors)
  - `total_calls` - Number of call records extracted
  - `total_functions` - Number of function locations indexed
  - `extraction_time_ms` - Time taken for extraction in milliseconds
  """

  defstruct modules_processed: 0,
            modules_with_debug_info: 0,
            modules_without_debug_info: 0,
            total_calls: 0,
            total_functions: 0,
            total_specs: 0,
            total_types: 0,
            total_structs: 0,
            extraction_time_ms: nil

  @type t :: %__MODULE__{
          modules_processed: non_neg_integer(),
          modules_with_debug_info: non_neg_integer(),
          modules_without_debug_info: non_neg_integer(),
          total_calls: non_neg_integer(),
          total_functions: non_neg_integer(),
          total_specs: non_neg_integer(),
          total_types: non_neg_integer(),
          total_structs: non_neg_integer(),
          extraction_time_ms: non_neg_integer() | nil
        }

  @doc """
  Create a new Stats struct with zero counts.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Record a successfully processed module.

  Increments `modules_processed` and `modules_with_debug_info`,
  and adds the call, function, spec, type, and struct counts.
  """
  @spec record_success(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: t()
  def record_success(
        %__MODULE__{} = stats,
        calls_count,
        functions_count,
        specs_count \\ 0,
        types_count \\ 0,
        structs_count \\ 0
      ) do
    %{
      stats
      | modules_processed: stats.modules_processed + 1,
        modules_with_debug_info: stats.modules_with_debug_info + 1,
        total_calls: stats.total_calls + calls_count,
        total_functions: stats.total_functions + functions_count,
        total_specs: stats.total_specs + specs_count,
        total_types: stats.total_types + types_count,
        total_structs: stats.total_structs + structs_count
    }
  end

  @doc """
  Record a module that couldn't be processed (no debug info or error).

  Increments `modules_processed` and `modules_without_debug_info`.
  """
  @spec record_failure(t()) :: t()
  def record_failure(%__MODULE__{} = stats) do
    %{
      stats
      | modules_processed: stats.modules_processed + 1,
        modules_without_debug_info: stats.modules_without_debug_info + 1
    }
  end

  @doc """
  Set the extraction time in milliseconds.
  """
  @spec set_extraction_time(t(), non_neg_integer()) :: t()
  def set_extraction_time(%__MODULE__{} = stats, time_ms) do
    %{stats | extraction_time_ms: time_ms}
  end
end
