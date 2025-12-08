defmodule CodeIntelligenceTracer.Output.JSON do
  @moduledoc """
  Generates JSON output for call graph extraction results.

  Produces a structured JSON document containing:
  - Metadata (timestamp, project path, environment)
  - Function calls with caller/callee information
  - Function locations organized by module

  ## Output Structure

      {
        "generated_at": "2024-01-15T10:30:00Z",
        "project_path": "/path/to/project",
        "environment": "dev",
        "extraction_metadata": {
          "modules_processed": 50,
          "modules_with_debug_info": 45,
          "modules_without_debug_info": 5,
          "total_calls": 1234,
          "total_functions": 456
        },
        "calls": [...],
        "function_locations": {...}
      }

  """

  alias CodeIntelligenceTracer.Stats

  @doc """
  Generate JSON string from extraction results.

  Takes a map containing extraction data and returns a pretty-printed JSON string.

  ## Parameters

    - `results` - Map with keys:
      - `:calls` - List of call records
      - `:function_locations` - Map of module -> function locations
      - `:project_path` - Path to analyzed project
      - `:environment` - Build environment (dev/test/prod)
      - `:stats` - Stats struct with extraction statistics

  ## Examples

      iex> generate(%{calls: [], function_locations: %{}, project_path: "/foo", environment: "dev"})
      "{\\n  \\"generated_at\\": \\"...\\",\\n  ...\\n}"

  """
  @spec generate(map()) :: String.t()
  def generate(results) do
    output = %{
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      project_path: results[:project_path] || "",
      environment: results[:environment] || "dev",
      extraction_metadata: format_stats(results[:stats]),
      calls: format_calls(results[:calls] || []),
      function_locations: format_function_locations(results[:function_locations] || %{})
    }

    Jason.encode!(output, pretty: true)
  end

  defp format_stats(nil), do: Stats.to_map(Stats.new())
  defp format_stats(%Stats{} = stats), do: Stats.to_map(stats)

  @doc """
  Write JSON string to a file.

  Creates parent directories if they don't exist.

  ## Parameters

    - `json_string` - The JSON content to write
    - `output_path` - Path to the output file

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure

  """
  @spec write_file(String.t(), String.t()) :: :ok | {:error, term()}
  def write_file(json_string, output_path) do
    output_path
    |> Path.dirname()
    |> File.mkdir_p()

    File.write(output_path, json_string)
  end

  # Format calls list for JSON output
  defp format_calls(calls) do
    Enum.map(calls, fn call ->
      %{
        type: to_string(call.type),
        caller: %{
          module: call.caller.module,
          function: call.caller.function,
          kind: to_string(call.caller.kind),
          file: call.caller.file,
          line: call.caller.line
        },
        callee: %{
          module: call.callee.module,
          function: call.callee.function,
          arity: call.callee.arity
        }
      }
    end)
  end

  # Format function locations map for JSON output
  # Organizes by module for easier lookup
  defp format_function_locations(locations) do
    locations
    |> Enum.group_by(fn {_func_key, info} -> info.module end, fn {func_key, info} ->
      {func_key, format_function_info(info)}
    end)
    |> Enum.into(%{}, fn {module, funcs} ->
      {module, Map.new(funcs)}
    end)
  end

  defp format_function_info(info) do
    %{
      start_line: info.start_line,
      end_line: info.end_line,
      kind: to_string(info.kind),
      source_file: info.source_file,
      source_file_absolute: info.source_file_absolute
    }
  end
end
