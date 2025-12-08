defmodule CodeIntelligenceTracer.RunResult do
  @moduledoc """
  Holds the results of processing an Elixir project.

  This struct contains structured data about what was discovered and processed,
  including extracted calls and function locations.
  """

  defstruct [
    :project_type,
    :project_apps,
    :project_path,
    :build_dir,
    :environment,
    :apps,
    :calls,
    :function_locations,
    :modules_processed,
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
          modules_processed: non_neg_integer(),
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
    lines = [
      "Project type: #{result.project_type}",
      "Project apps: #{Enum.join(result.project_apps || [], ", ")}",
      "Environment: #{result.environment}",
      "Modules processed: #{result.modules_processed || 0}",
      "Calls extracted: #{length(result.calls || [])}",
      "Functions indexed: #{map_size(result.function_locations || %{})}"
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
