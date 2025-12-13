defmodule ExAst.AstNormalizer do
  @moduledoc """
  Generic AST normalization utilities.

  Provides composable functions for traversing and transforming AST nodes
  while preserving or stripping metadata as needed.
  """

  @doc """
  Recursively traverse AST, applying a transform function to each node.

  The transform function should return `{transformed_node, continue}` where
  continue is true to traverse children, false to skip.

  ## Examples

      iex> transform({:foo, [line: 1], [:arg]}, fn
      ...>   {form, meta, args} when is_list(meta) -> {{form, [], args}, true}
      ...>   other -> {other, false}
      ...> end)
      {:foo, [], [:arg]}

  """
  @spec transform(term(), (term() -> {term(), boolean()})) :: term()
  def transform(ast, transformer) do
    case transformer.(ast) do
      {node, true} -> transform_children(node, transformer)
      {node, false} -> node
    end
  end

  # Transform children of a node
  defp transform_children({form, meta, args}, transformer) when is_list(args) do
    {form, meta, Enum.map(args, &transform(&1, transformer))}
  end

  defp transform_children({form, meta, args}, transformer) when is_list(meta) do
    {form, meta, transform(args, transformer)}
  end

  defp transform_children({left, right}, transformer) do
    {transform(left, transformer), transform(right, transformer)}
  end

  defp transform_children(list, transformer) when is_list(list) do
    Enum.map(list, &transform(&1, transformer))
  end

  defp transform_children(other, _transformer) do
    other
  end

  @doc """
  Strip metadata from all tuple nodes in AST.

  Converts `{form, meta, args}` to `{form, [], args}`.

  ## Examples

      iex> strip_metadata({:foo, [line: 1], [:bar]})
      {:foo, [], [:bar]}

  """
  @spec strip_metadata(term()) :: term()
  def strip_metadata(ast) do
    transform(ast, fn
      {form, meta, args} when is_list(meta) and is_list(args) ->
        {{form, [], args}, true}

      {form, meta, args} when is_list(meta) ->
        {{form, [], args}, true}

      other ->
        {other, true}
    end)
  end

  @doc """
  Normalize guard AST by converting Erlang format to Elixir syntax.

  Specifically handles:
  - `:erlang.andalso` → `:and`
  - `:erlang.orelse` → `:or`

  Preserves metadata for guard nodes to maintain source location info.

  ## Examples

      iex> normalize_guard_ast({{:., [], [:erlang, :andalso]}, [], [left, right]})
      {:and, [], [left, right]}

  """
  @spec normalize_guard_ast(term()) :: term()
  def normalize_guard_ast(ast) do
    transform(ast, fn
      {{:., _meta, [:erlang, :andalso]}, call_meta, [left, right]} ->
        {{:and, call_meta, [left, right]}, true}

      {{:., _meta, [:erlang, :orelse]}, call_meta, [left, right]} ->
        {{:or, call_meta, [left, right]}, true}

      {{:., _meta, [:erlang, func]}, call_meta, args} ->
        {{func, call_meta, args}, true}

      other ->
        {other, true}
    end)
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

  @doc """
  Extract line number from an AST node.

  Returns the `:line` metadata value if present, otherwise 0.

  ## Examples

      iex> extract_line_from_node({:foo, [line: 42], []})
      42

      iex> extract_line_from_node({:foo, [], []})
      0

  """
  @spec extract_line_from_node(term()) :: non_neg_integer()
  def extract_line_from_node({_form, meta, _args}) when is_list(meta) do
    Keyword.get(meta, :line, 0)
  end

  def extract_line_from_node(_), do: 0

  # Strip position-related metadata keys
  defp strip_position_metadata(meta) do
    meta
    |> Keyword.drop([:line, :column, :counter, :file, :end_of_expression, :newlines, :closing, :do, :end])
  end
end
