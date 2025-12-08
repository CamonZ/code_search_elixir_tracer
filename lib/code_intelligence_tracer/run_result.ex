defmodule CodeIntelligenceTracer.RunResult do
  @moduledoc """
  Holds the results of processing an Elixir project.

  This struct contains structured data about what was discovered and processed,
  including extracted calls and function locations.
  """

  alias CodeIntelligenceTracer.Stats

  defstruct [
    :project_type,
    :project_apps,
    :project_path,
    :build_dir,
    :environment,
    :apps,
    :calls,
    :function_locations,
    :stats,
    :output_file,
    :extraction_time_ms
  ]

  @type t :: %__MODULE__{
          project_type: :regular | :umbrella,
          project_apps: [String.t()],
          project_path: String.t(),
          build_dir: String.t(),
          environment: String.t(),
          apps: [{String.t(), String.t()}],
          calls: [map()],
          function_locations: %{String.t() => map()},
          stats: Stats.t() | nil,
          output_file: String.t() | nil,
          extraction_time_ms: non_neg_integer() | nil
        }

  @doc """
  Create a new RunResult with the given fields.
  """
  @spec new(keyword()) :: t()
  def new(fields \\ []) do
    struct(__MODULE__, fields)
  end

  @doc """
  Format the result for display.
  """
  @spec format(t()) :: [String.t()]
  def format(%__MODULE__{} = result) do
    stats = result.stats || Stats.new()

    lines = [
      "Project type: #{result.project_type}",
      "Project apps: #{Enum.join(result.project_apps || [], ", ")}",
      "Environment: #{result.environment}",
      "Modules processed: #{stats.modules_processed}",
      "  - With debug info: #{stats.modules_with_debug_info}",
      "  - Without debug info: #{stats.modules_without_debug_info}",
      "Calls extracted: #{stats.total_calls}",
      "Functions indexed: #{stats.total_functions}"
    ]

    lines = add_timing(lines, result.extraction_time_ms)
    add_output_file(lines, result.output_file)
  end

  defp add_timing(lines, nil), do: lines

  defp add_timing(lines, time_ms) when time_ms < 1000 do
    lines ++ ["Extraction time: #{time_ms}ms"]
  end

  defp add_timing(lines, time_ms) do
    seconds = Float.round(time_ms / 1000, 2)
    lines ++ ["Extraction time: #{seconds}s"]
  end

  defp add_output_file(lines, nil), do: lines
  defp add_output_file(lines, output_file), do: lines ++ ["Output written to: #{output_file}"]

  @doc """
  Print the result to stdout.
  """
  @spec print(t()) :: :ok
  def print(%__MODULE__{} = result) do
    result
    |> format()
    |> Enum.each(&IO.puts/1)
  end
end
