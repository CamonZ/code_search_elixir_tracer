defmodule ExAst.ComplexityAnalyzer do
  @moduledoc """
  Analyze function complexity metrics.

  Provides functions to compute:
  - Cyclomatic complexity: Number of decision points in function
  - Max nesting depth: Maximum nesting level of control structures
  """

  @doc """
  Compute cyclomatic complexity of a function body AST.

  Walks the AST and counts decision points to calculate complexity.
  Base complexity is 1, with additional points for branching constructs.

  ## Examples

      iex> compute_complexity({:ok, [], nil})
      1

      iex> compute_complexity({:if, [], [condition, [do: a, else: b]]})
      2

  """
  @spec compute_complexity(term()) :: non_neg_integer()
  def compute_complexity(body_ast) do
    {_ast, complexity} =
      Macro.prewalk(body_ast, 1, fn node, acc ->
        {node, acc + complexity_of(node)}
      end)

    complexity
  end

  @doc """
  Compute maximum nesting depth of control structures in function body.

  Walks the AST and tracks the deepest nesting level of control structures
  like with, case, cond, if, unless, try, for, and fn.

  ## Examples

      iex> compute_max_nesting_depth({:ok, [], nil})
      0

      iex> compute_max_nesting_depth({:if, [], [condition, [do: a, else: b]]})
      1

      iex> compute_max_nesting_depth({:with, [], [{:<-, [], [{:x, [], nil}, {:ok, [], nil}]}, [do: {:if, [], [cond, [do: a]]}]]})
      2

  """
  @spec compute_max_nesting_depth(term()) :: non_neg_integer()
  def compute_max_nesting_depth(body_ast) do
    calculate_max_nesting_depth(body_ast, 0)
  end

  # Recursively calculate max nesting depth
  @spec calculate_max_nesting_depth(term(), non_neg_integer()) :: non_neg_integer()
  defp calculate_max_nesting_depth(ast, current_depth) when is_tuple(ast) do
    # If this node introduces nesting, increment depth
    node_depth = if introduces_nesting?(ast), do: current_depth + 1, else: current_depth

    # Get children and calculate their max depths
    children_max = get_ast_children(ast)
      |> Enum.map(&calculate_max_nesting_depth(&1, node_depth))
      |> Enum.max(fn -> node_depth end)

    max(node_depth, children_max)
  end

  defp calculate_max_nesting_depth(ast, current_depth) when is_list(ast) do
    ast
    |> Enum.map(&calculate_max_nesting_depth(&1, current_depth))
    |> Enum.max(fn -> current_depth end)
  end

  defp calculate_max_nesting_depth(_ast, current_depth) do
    current_depth
  end

  # Check if a node introduces nesting
  @spec introduces_nesting?(term()) :: boolean()
  defp introduces_nesting?({:with, _, _}), do: true
  defp introduces_nesting?({:case, _, _}), do: true
  defp introduces_nesting?({:cond, _, _}), do: true
  defp introduces_nesting?({:if, _, _}), do: true
  defp introduces_nesting?({:unless, _, _}), do: true
  defp introduces_nesting?({:try, _, _}), do: true
  defp introduces_nesting?({:for, _, _}), do: true
  defp introduces_nesting?({:fn, _, _}), do: true
  defp introduces_nesting?(_), do: false

  # Extract children from AST node
  @spec get_ast_children(term()) :: [term()]
  defp get_ast_children({_form, _meta, args}) when is_list(args) do
    args
  end

  defp get_ast_children({_form, _meta, arg}) when is_tuple(arg) do
    [arg]
  end

  defp get_ast_children({left, right}) when is_tuple(left) or is_tuple(right) do
    [left, right]
  end

  defp get_ast_children(_), do: []

  # Calculate complexity contribution of a single AST node
  @spec complexity_of(term()) :: non_neg_integer()
  defp complexity_of({:case, _meta, [_expr, [do: clauses]]}) when is_list(clauses) do
    max(0, length(clauses) - 1)
  end

  defp complexity_of({:cond, _meta, [[do: clauses]]}) when is_list(clauses) do
    max(0, length(clauses) - 1)
  end

  defp complexity_of({op, _meta, _args}) when op in [:if, :unless] do
    1
  end

  defp complexity_of({:with, _meta, args}) when is_list(args) do
    # Count <- clauses (match operations)
    match_clauses = Enum.count(args, fn
      {:<-, _, _} -> true
      _ -> false
    end)

    # Count else clauses if present
    else_clauses = case List.last(args) do
      [do: _, else: else_block] when is_list(else_block) -> length(else_block)
      [else: else_block] when is_list(else_block) -> length(else_block)
      _ -> 0
    end

    match_clauses + else_clauses
  end

  defp complexity_of({:try, _meta, [block_opts]}) when is_list(block_opts) do
    rescue_count = case Keyword.get(block_opts, :rescue) do
      nil -> 0
      clauses when is_list(clauses) -> length(clauses)
      _ -> 0
    end

    catch_count = case Keyword.get(block_opts, :catch) do
      nil -> 0
      clauses when is_list(clauses) -> length(clauses)
      _ -> 0
    end

    rescue_count + catch_count
  end

  defp complexity_of({:receive, _meta, [[do: clauses]]}) when is_list(clauses) do
    max(0, length(clauses) - 1)
  end

  defp complexity_of({:receive, _meta, [[do: clauses, after: _after]]}) when is_list(clauses) do
    max(0, length(clauses) - 1) + 1
  end

  defp complexity_of({op, _meta, [_left, _right]}) when op in [:and, :or, :&&, :||] do
    1
  end

  defp complexity_of(_node), do: 0
end
