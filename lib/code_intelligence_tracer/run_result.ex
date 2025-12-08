defmodule CodeIntelligenceTracer.RunResult do
  @moduledoc """
  Holds the results of processing an Elixir project.

  This struct contains structured data about what was discovered and processed,
  such as project type, detected apps, and processed files.
  """

  defstruct [
    :project_type,
    :project_apps,
    :build_dir,
    :apps
  ]

  @type t :: %__MODULE__{
          project_type: :regular | :umbrella,
          project_apps: [String.t()],
          build_dir: String.t(),
          apps: [{String.t(), String.t()}]
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
    [
      "Project type: #{result.project_type}",
      "Project apps: #{inspect(result.project_apps)}",
      "Build directory: #{result.build_dir}",
      "Found #{length(result.apps)} application(s)"
    ]
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
