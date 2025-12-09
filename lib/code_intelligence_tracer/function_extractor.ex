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
          source_file_absolute: String.t(),
          source_sha: String.t() | nil,
          ast_sha: String.t()
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
      source_file_absolute: source_file_absolute,
      source_sha: compute_source_sha(source_file_absolute, start_line, end_line),
      ast_sha: compute_ast_sha(clauses)
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

  @doc """
  Compute SHA256 hash of source code for a function's line range.

  Reads the specified lines from the source file and computes a SHA256 hash.
  This hash changes when formatting, comments, or code changes.

  Returns `nil` if the source file doesn't exist or can't be read.

  ## Parameters

    - `source_file` - Absolute path to the source file
    - `start_line` - First line of the function (1-indexed)
    - `end_line` - Last line of the function (1-indexed)

  ## Examples

      iex> compute_source_sha("/path/to/lib/my_app/foo.ex", 10, 25)
      "a1b2c3d4..."

  """
  @spec compute_source_sha(String.t(), non_neg_integer(), non_neg_integer()) :: String.t() | nil
  def compute_source_sha(source_file, start_line, end_line) do
    case File.read(source_file) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.slice((start_line - 1)..(end_line - 1))
        |> Enum.join("\n")
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      {:error, _} ->
        nil
    end
  end

  @doc """
  Compute SHA256 hash of normalized AST for function clauses.

  Normalizes the AST to remove non-semantic metadata (line numbers, etc.)
  and computes a SHA256 hash. This hash only changes when the actual
  logic changes, not formatting or comments.

  ## Parameters

    - `clauses` - List of function clauses from debug info

  ## Examples

      iex> compute_ast_sha(clauses)
      "e5f6g7h8..."

  """
  @spec compute_ast_sha(list()) :: String.t()
  def compute_ast_sha(clauses) do
    clauses
    |> normalize_ast()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc """
  Normalize AST by stripping non-semantic metadata.

  Removes `:line`, `:column`, `:counter`, `:file`, and other position
  metadata from the AST while preserving semantic structure.

  ## Parameters

    - `ast` - Any Elixir AST term

  ## Examples

      iex> normalize_ast({:foo, [line: 1, column: 5], [:arg]})
      {:foo, [], [:arg]}

  """
  @spec normalize_ast(term()) :: term()
  def normalize_ast(ast) when is_list(ast) do
    Enum.map(ast, &normalize_ast/1)
  end

  # Function clause tuple: {meta, args, guards, body}
  def normalize_ast({meta, args, guards, body}) when is_list(meta) do
    normalized_meta = strip_position_metadata(meta)
    {normalized_meta, normalize_ast(args), normalize_ast(guards), normalize_ast(body)}
  end

  # Standard AST node: {form, meta, args}
  def normalize_ast({form, meta, args}) when is_list(meta) do
    normalized_meta = strip_position_metadata(meta)
    normalized_args = normalize_ast(args)
    {form, normalized_meta, normalized_args}
  end

  def normalize_ast({left, right}) do
    {normalize_ast(left), normalize_ast(right)}
  end

  def normalize_ast(other), do: other

  # Strip position-related metadata keys
  defp strip_position_metadata(meta) do
    meta
    |> Keyword.drop([:line, :column, :counter, :file, :end_of_expression, :newlines, :closing, :do, :end])
  end

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
