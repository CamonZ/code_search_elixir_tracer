defmodule ExAst.Output do
  @moduledoc """
  Generates output for call graph extraction results.

  Supports multiple output formats (JSON, TOON) with a unified API.
  All formatting logic is shared between formats - only the final
  serialization differs.

  ## Supported Formats

  - `"json"` - Pretty-printed JSON via Jason
  - `"toon"` - Token-Oriented Object Notation for LLM consumption

  ## Output Structure

  Both formats produce the same logical structure:

      {
        "generated_at": "2024-01-15T10:30:00Z",
        "project_path": "/path/to/project",
        "environment": "dev",
        "extraction_metadata": {...},
        "calls": [...],
        "function_locations": {...},
        "specs": {...},
        "types": {...},
        "structs": {...}
      }

  """

  alias ExAst.Extractor

  @serializers %{
    "json" => Jason,
    "toon" => Toon
  }

  @type format :: String.t()

  @doc """
  Returns the default output filename for the given format.

  ## Examples

      iex> default_filename("json")
      "extracted_trace.json"

      iex> default_filename("toon")
      "extracted_trace.toon"

  """
  @spec default_filename(format()) :: String.t()
  def default_filename(format), do: "extracted_trace.#{format}"

  @doc """
  Returns the file extension for the given format.

  ## Examples

      iex> extension("json")
      ".json"

      iex> extension("toon")
      ".toon"

  """
  @spec extension(format()) :: String.t()
  def extension(format), do: ".#{format}"

  @doc """
  Generate output string from extraction results in the specified format.

  ## Parameters

    - `extractor` - The Extractor struct with extraction results
    - `format` - Output format: "json" or "toon"

  ## Returns

  A string in the specified format.
  """
  @spec generate(Extractor.t(), format()) :: String.t()
  def generate(%Extractor{} = extractor, format) do
    output = build_output_map(extractor)
    serialize(output, format)
  end

  @doc """
  Generate and write output to a file.

  Creates parent directories if they don't exist.

  ## Parameters

    - `extractor` - The Extractor struct with extraction results
    - `output_path` - Path to the output file
    - `format` - Output format: "json" or "toon"

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @spec write(Extractor.t(), String.t(), format()) :: :ok | {:error, term()}
  def write(%Extractor{} = extractor, output_path, format) do
    output_string = generate(extractor, format)

    output_path
    |> Path.dirname()
    |> File.mkdir_p()

    File.write(output_path, output_string)
  end

  # Build the output map from extractor results
  defp build_output_map(%Extractor{} = extractor) do
    %{
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      project_path: extractor.project_path || "",
      environment: extractor.environment || "dev",
      extraction_metadata: Map.from_struct(extractor.stats),
      calls: format_calls(extractor.calls || []),
      function_locations: format_function_locations(extractor.function_locations || %{}),
      specs: format_specs_by_module(extractor.specs || %{}),
      types: format_types_by_module(extractor.types || %{}),
      structs: format_structs_by_module(extractor.structs || %{})
    }
  end

  # Serialize to the specified format
  defp serialize(output, format) do
    serializer = Map.get(@serializers, format)
    serializer.encode!(output)
  end

  # Format calls list for output
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

  # Format function locations map for output
  # Organizes by module for easier lookup
  defp format_function_locations(locations) do
    locations
    |> Enum.group_by(fn {_func_key, info} -> info.module end, fn {func_key, info} ->
      # Strip module prefix from key (added to ensure uniqueness)
      # Key format is "ModuleName.function/arity:line", we want "function/arity:line"
      stripped_key =
        case String.split(func_key, ".", parts: 2) do
          [_module, rest] -> rest
          [key] -> key
        end

      {stripped_key, format_function_info(info)}
    end)
    |> Enum.into(%{}, fn {module, funcs} ->
      {module, Map.new(funcs)}
    end)
  end

  defp format_function_info(info) do
    %{
      name: info.name,
      arity: info.arity,
      line: info.line,
      start_line: info.start_line,
      end_line: info.end_line,
      kind: to_string(info.kind),
      guard: info.guard,
      pattern: info.pattern,
      source_file: info.source_file,
      source_file_absolute: info.source_file_absolute,
      source_sha: info[:source_sha],
      ast_sha: info[:ast_sha],
      generated_by: info[:generated_by],
      macro_source: info[:macro_source],
      complexity: info[:complexity],
      max_nesting_depth: info[:max_nesting_depth]
    }
  end

  # Format specs map for output
  # Organizes by module for easier lookup
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
      input_strings: clause.input_strings,
      return_strings: clause.return_strings,
      full: clause.full
    }
  end

  # Format types map for output
  # Organizes by module for easier lookup
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

  # Format structs map for output
  # Organizes by module for easier lookup
  defp format_structs_by_module(structs) when is_map(structs) do
    structs
    |> Enum.reject(fn {_module, struct_info} -> is_nil(struct_info) end)
    |> Enum.into(%{}, fn {module, struct_info} ->
      {module, struct_info}
    end)
  end

  defp format_structs_by_module(_), do: %{}
end
