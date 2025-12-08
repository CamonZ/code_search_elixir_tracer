defmodule CodeIntelligenceTracer.Stats do
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
  """

  defstruct modules_processed: 0,
            modules_with_debug_info: 0,
            modules_without_debug_info: 0,
            total_calls: 0,
            total_functions: 0

  @type t :: %__MODULE__{
          modules_processed: non_neg_integer(),
          modules_with_debug_info: non_neg_integer(),
          modules_without_debug_info: non_neg_integer(),
          total_calls: non_neg_integer(),
          total_functions: non_neg_integer()
        }

  @doc """
  Create a new Stats struct with zero counts.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Record a successfully processed module.

  Increments `modules_processed` and `modules_with_debug_info`,
  and adds the call and function counts.
  """
  @spec record_success(t(), non_neg_integer(), non_neg_integer()) :: t()
  def record_success(%__MODULE__{} = stats, calls_count, functions_count) do
    %{
      stats
      | modules_processed: stats.modules_processed + 1,
        modules_with_debug_info: stats.modules_with_debug_info + 1,
        total_calls: stats.total_calls + calls_count,
        total_functions: stats.total_functions + functions_count
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
  Convert stats to a map suitable for JSON output.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = stats) do
    %{
      modules_processed: stats.modules_processed,
      modules_with_debug_info: stats.modules_with_debug_info,
      modules_without_debug_info: stats.modules_without_debug_info,
      total_calls: stats.total_calls,
      total_functions: stats.total_functions
    }
  end
end
