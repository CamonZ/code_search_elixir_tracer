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
    :output_file
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
          output_file: String.t() | nil
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

    if result.output_file do
      lines ++ ["Output written to: #{result.output_file}"]
    else
      lines
    end
  end

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
