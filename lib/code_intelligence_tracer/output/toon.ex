defmodule CodeIntelligenceTracer.Output.TOON do
  @moduledoc """
  Generates TOON output for call graph extraction results.

  TOON (Token-Oriented Object Notation) achieves 30-60% token reduction
  compared to JSON while maintaining readability, making it ideal for
  LLM consumption.

  ## Output Structure

  The output structure mirrors the JSON format but encoded in TOON:

      generated_at: 2024-01-15T10:30:00Z
      project_path: /path/to/project
      environment: dev
      extraction_metadata:
        modules_processed: 50
        ...
      calls[N]: ...
      function_locations: ...

  """

  alias CodeIntelligenceTracer.Stats

  @doc """
  Generate TOON string from extraction results.

  Takes a map containing extraction data and returns a TOON-encoded string.

  ## Parameters

    - `results` - Map with keys:
      - `:calls` - List of call records
      - `:function_locations` - Map of module -> function locations
      - `:project_path` - Path to analyzed project
      - `:environment` - Build environment (dev/test/prod)
      - `:stats` - Stats struct with extraction statistics

  ## Examples

      iex> generate(%{calls: [], function_locations: %{}, project_path: "/foo", environment: "dev"})
      "generated_at: ...\\nproject_path: /foo\\n..."

  """
  @spec generate(map()) :: String.t()
  def generate(results) do
    output = %{
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      project_path: results[:project_path] || "",
      environment: results[:environment] || "dev",
      extraction_metadata: format_stats(results[:stats]),
      calls: format_calls(results[:calls] || []),
      function_locations: format_function_locations(results[:function_locations] || %{}),
      specs: format_specs_by_module(results[:specs] || %{}),
      types: format_types_by_module(results[:types] || %{}),
      structs: format_structs_by_module(results[:structs] || %{})
    }

    {:ok, toon_string} = Toon.encode(output)
    toon_string
  end

  defp format_stats(nil), do: Stats.to_map(Stats.new())
  defp format_stats(%Stats{} = stats), do: Stats.to_map(stats)

  @doc """
  Write TOON string to a file.

  Creates parent directories if they don't exist.

  ## Parameters

    - `toon_string` - The TOON content to write
    - `output_path` - Path to the output file

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure

  """
  @spec write_file(String.t(), String.t()) :: :ok | {:error, term()}
  def write_file(toon_string, output_path) do
    output_path
    |> Path.dirname()
    |> File.mkdir_p()

    File.write(output_path, toon_string)
  end

  # Format calls list for TOON output
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

  # Format function locations map for TOON output
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

  # Format specs map for TOON output
  defp format_specs_by_module(specs) when is_map(specs) do
    specs
    |> Enum.into(%{}, fn {module, module_specs} ->
      {module, Enum.map(module_specs, &format_spec_record/1)}
    end)
  end

  defp format_specs_by_module(_), do: %{}

  defp format_spec_record(spec) do
    %{
      name: spec.name,
      arity: spec.arity,
      kind: to_string(spec.kind),
      line: spec.line,
      clauses: Enum.map(spec.clauses, &format_spec_clause/1)
    }
  end

  defp format_spec_clause(clause) do
    %{
      inputs_string: clause.inputs_string,
      return_string: clause.return_string,
      full: clause.full
    }
  end

  # Format types map for TOON output
  defp format_types_by_module(types) when is_map(types) do
    types
    |> Enum.into(%{}, fn {module, module_types} ->
      {module, Enum.map(module_types, &format_type_record/1)}
    end)
  end

  defp format_types_by_module(_), do: %{}

  defp format_type_record(type_record) do
    %{
      name: type_record.name,
      kind: to_string(type_record.kind),
      params: type_record.params,
      line: type_record.line,
      definition: type_record.definition
    }
  end

  # Format structs map for TOON output
  defp format_structs_by_module(structs) when is_map(structs) do
    structs
    |> Enum.reject(fn {_module, struct_info} -> is_nil(struct_info) end)
    |> Enum.into(%{}, fn {module, struct_info} ->
      {module, struct_info}
    end)
  end

  defp format_structs_by_module(_), do: %{}
end
