defmodule ExAst.Extractor.FunctionExtractor.ComplexityAnalyzerTest do
  use ExUnit.Case, async: true

  alias ExAst.Extractor.FunctionExtractor.ComplexityAnalyzer

  describe "compute_complexity/1" do
    test "simple expression has complexity 1" do
      ast = quote do: :ok
      assert ComplexityAnalyzer.compute_complexity(ast) == 1
    end

    test "if adds 1 to complexity" do
      ast = quote do: if(x > 0, do: :pos, else: :neg)
      assert ComplexityAnalyzer.compute_complexity(ast) == 2
    end

    test "unless adds 1 to complexity" do
      ast = quote do: unless(x == 0, do: :nonzero)
      assert ComplexityAnalyzer.compute_complexity(ast) == 2
    end

    test "case adds n-1 for n clauses" do
      # 3 clauses = +2
      ast =
        quote do
          case x do
            :a -> 1
            :b -> 2
            _ -> 3
          end
        end

      assert ComplexityAnalyzer.compute_complexity(ast) == 3
    end

    test "cond adds n-1 for n clauses" do
      # 3 clauses = +2
      ast =
        quote do
          cond do
            x > 0 -> :pos
            x < 0 -> :neg
            true -> :zero
          end
        end

      assert ComplexityAnalyzer.compute_complexity(ast) == 3
    end

    test "nested control structures add up" do
      # case(2 clauses = +1) + if(+1) = 3
      ast =
        quote do
          case x do
            :a -> if(y, do: 1, else: 2)
            :b -> 3
          end
        end

      assert ComplexityAnalyzer.compute_complexity(ast) == 3
    end

    test "with adds 1 per match clause" do
      # 2 <- clauses = +2
      ast =
        quote do
          with {:ok, a} <- foo(),
               {:ok, b} <- bar(a) do
            {:ok, a + b}
          end
        end

      assert ComplexityAnalyzer.compute_complexity(ast) == 3
    end

    test "with else clauses add to complexity" do
      # 2 <- clauses + 1 else clause = +3
      ast =
        quote do
          with {:ok, a} <- foo(),
               {:ok, b} <- bar(a) do
            {:ok, a + b}
          else
            {:error, _} -> :error
          end
        end

      assert ComplexityAnalyzer.compute_complexity(ast) == 4
    end

    test "boolean operators add 1 each" do
      # && and || each add 1
      ast = quote do: (x && y) || z
      assert ComplexityAnalyzer.compute_complexity(ast) == 3
    end

    test "and/or operators add 1 each" do
      ast = quote do: (x and y) or z
      assert ComplexityAnalyzer.compute_complexity(ast) == 3
    end

    test "try/rescue adds per rescue clause" do
      # 2 rescue clauses = +2
      ast =
        quote do
          try do
            risky()
          rescue
            ArgumentError -> :arg_error
            RuntimeError -> :runtime_error
          end
        end

      assert ComplexityAnalyzer.compute_complexity(ast) == 3
    end
  end
end
