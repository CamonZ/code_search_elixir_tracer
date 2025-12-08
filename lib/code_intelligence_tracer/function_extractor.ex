defmodule CodeIntelligenceTracer.FunctionExtractor do
  @moduledoc """
  Extracts function definitions with their locations from Elixir debug info.

  Parses the definitions list from debug info to extract function metadata
  including line numbers, kind (def/defp/defmacro/defmacrop), and source file.

  ## Function Record Structure

  Returns a map keyed by "function_name/arity" with values containing:

      %{
        start_line: 10,
        end_line: 25,
        kind: :def,
        source_file: "lib/my_app/foo.ex",
        source_file_absolute: "/full/path/lib/my_app/foo.ex"
      }

  """

  @type function_kind :: :def | :defp | :defmacro | :defmacrop

  @type function_info :: %{
          start_line: non_neg_integer(),
          end_line: non_neg_integer(),
          kind: function_kind(),
          source_file: String.t(),
          source_file_absolute: String.t()
        }

  @doc """
  Extract function definitions with locations from debug info.

  Takes the definitions list from debug info and the source file path.
  Returns a map keyed by "function_name/arity".

  ## Parameters

    - `definitions` - List of function definitions from debug info
    - `source_file` - Absolute path to the source file

  ## Examples

      iex> extract_functions(definitions, "/path/to/lib/my_app/foo.ex")
      %{
        "process/2" => %{start_line: 10, end_line: 25, kind: :def, ...},
        "helper/1" => %{start_line: 27, end_line: 30, kind: :defp, ...}
      }

  """
  @spec extract_functions(list(), String.t()) :: %{String.t() => function_info()}
  def extract_functions(definitions, source_file_absolute) do
    source_file = make_relative_path(source_file_absolute)

    definitions
    |> Enum.map(fn definition ->
      extract_function_info(definition, source_file, source_file_absolute)
    end)
    |> Map.new()
  end

  @doc """
  Resolve the source file path from debug info.

  Returns `{:ok, {relative_path, absolute_path}}` or `{:error, reason}`.

  The absolute path comes from the `:file` key in debug info.
  The relative path strips common prefixes to get "lib/..." or "test/...".

  ## Parameters

    - `debug_info` - Map from BeamReader.extract_debug_info/2
    - `beam_path` - Path to the BEAM file (used as fallback reference)

  """
  @spec resolve_source_path(map(), String.t()) ::
          {:ok, {String.t(), String.t()}} | {:error, String.t()}
  def resolve_source_path(debug_info, _beam_path) do
    case Map.get(debug_info, :file) do
      nil ->
        {:error, "No :file key in debug info"}

      file when is_binary(file) ->
        relative = make_relative_path(file)
        {:ok, {relative, file}}

      file when is_list(file) ->
        # Charlist path
        absolute = List.to_string(file)
        relative = make_relative_path(absolute)
        {:ok, {relative, absolute}}
    end
  end

  # Extract info for a single function definition
  defp extract_function_info({{func_name, arity}, kind, _meta, clauses}, source_file, source_file_absolute) do
    {start_line, end_line} = compute_line_range(clauses)

    function_key = "#{func_name}/#{arity}"

    function_info = %{
      start_line: start_line,
      end_line: end_line,
      kind: kind,
      source_file: source_file,
      source_file_absolute: source_file_absolute
    }

    {function_key, function_info}
  end

  # Compute the line range from all clauses
  # For multi-clause functions, returns the first line of first clause
  # and the last line of the last clause's body
  defp compute_line_range(clauses) do
    lines =
      clauses
      |> Enum.flat_map(fn {meta, _args, _guards, body} ->
        clause_start = Keyword.get(meta, :line, 0)
        body_end = find_max_line(body)
        [clause_start, body_end]
      end)
      |> Enum.filter(&(&1 > 0))

    case lines do
      [] -> {0, 0}
      lines -> {Enum.min(lines), Enum.max(lines)}
    end
  end

  # Walk the AST to find the maximum line number
  defp find_max_line(ast) do
    {_ast, max_line} =
      Macro.prewalk(ast, 0, fn node, acc ->
        line = extract_line_from_node(node)
        {node, max(acc, line)}
      end)

    max_line
  end

  defp extract_line_from_node({_form, meta, _args}) when is_list(meta) do
    Keyword.get(meta, :line, 0)
  end

  defp extract_line_from_node(_), do: 0

  # Convert absolute path to relative path
  # Strips everything up to and including "lib/" or "test/"
  defp make_relative_path(absolute_path) do
    cond do
      String.contains?(absolute_path, "/lib/") ->
        absolute_path
        |> String.split("/lib/", parts: 2)
        |> List.last()
        |> then(&("lib/" <> &1))

      String.contains?(absolute_path, "/test/") ->
        absolute_path
        |> String.split("/test/", parts: 2)
        |> List.last()
        |> then(&("test/" <> &1))

      true ->
        # Fallback: use basename
        Path.basename(absolute_path)
    end
  end
end
