defmodule ExAst.Extractor.SpecExtractor.SpecParserTest do
  use ExUnit.Case, async: true

  alias ExAst.Extractor.SpecExtractor.SpecParser

  describe "extract_specs/1" do
    test "extracts specs from abstract_code chunk" do
      # Create a simple abstract code structure with a spec
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:attribute, 10, :spec,
            {{:my_func, 2},
             [
               {:type, {10, 9}, :fun,
                [
                  {:type, {10, 9}, :product,
                   [
                     {:type, {10, 18}, :integer, []},
                     {:type, {10, 30}, :binary, []}
                   ]},
                  {:type, {10, 44}, :atom, []}
                ]}
             ]}}
         ]}

      chunks = %{abstract_code: abstract_code}
      specs = SpecParser.extract_specs(chunks)

      assert length(specs) == 1
      [spec] = specs

      assert spec.name == :my_func
      assert spec.arity == 2
      assert spec.kind == :spec
      assert spec.line == 10
      assert is_list(spec.clauses)
    end

    test "extracts callbacks" do
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:attribute, 5, :callback,
            {{:handle_call, 3},
             [
               {:type, {5, 9}, :fun,
                [
                  {:type, {5, 9}, :product,
                   [
                     {:type, {5, 20}, :term, []},
                     {:type, {5, 27}, :term, []},
                     {:type, {5, 34}, :term, []}
                   ]},
                  {:type, {5, 44}, :term, []}
                ]}
             ]}}
         ]}

      chunks = %{abstract_code: abstract_code}
      specs = SpecParser.extract_specs(chunks)

      assert length(specs) == 1
      [callback] = specs

      assert callback.name == :handle_call
      assert callback.arity == 3
      assert callback.kind == :callback
      assert callback.line == 5
    end

    test "extracts both specs and callbacks" do
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:attribute, 10, :spec,
            {{:public_func, 1},
             [
               {:type, {10, 9}, :fun,
                [
                  {:type, {10, 9}, :product, [{:type, {10, 21}, :any, []}]},
                  {:type, {10, 29}, :ok, []}
                ]}
             ]}},
           {:attribute, 20, :callback,
            {{:on_init, 0},
             [
               {:type, {20, 9}, :fun,
                [{:type, {20, 9}, :product, []}, {:type, {20, 20}, :ok, []}]}
             ]}}
         ]}

      chunks = %{abstract_code: abstract_code}
      specs = SpecParser.extract_specs(chunks)

      assert length(specs) == 2

      spec = Enum.find(specs, &(&1.kind == :spec))
      callback = Enum.find(specs, &(&1.kind == :callback))

      assert spec.name == :public_func
      assert callback.name == :on_init
    end

    test "returns empty list when no abstract_code chunk" do
      chunks = %{abstract_code: nil}
      assert SpecParser.extract_specs(chunks) == []
    end

    test "returns empty list for unsupported abstract_code format" do
      chunks = %{abstract_code: {:unknown_format, []}}
      assert SpecParser.extract_specs(chunks) == []
    end

    test "handles modules without specs" do
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:function, 5, :some_func, 0, [{:clause, 5, [], [], [{:atom, 5, :ok}]}]}
         ]}

      chunks = %{abstract_code: abstract_code}
      assert SpecParser.extract_specs(chunks) == []
    end

    test "preserves multiple clauses for union types" do
      # Spec with multiple clauses (like @spec foo(integer) :: :ok; foo(binary) :: :error)
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:attribute, 10, :spec,
            {{:multi_clause, 1},
             [
               {:type, {10, 9}, :fun,
                [
                  {:type, {10, 9}, :product, [{:type, {10, 22}, :integer, []}]},
                  {:atom, {10, 35}, :ok}
                ]},
               {:type, {11, 9}, :fun,
                [
                  {:type, {11, 9}, :product, [{:type, {11, 22}, :binary, []}]},
                  {:atom, {11, 35}, :error}
                ]}
             ]}}
         ]}

      chunks = %{abstract_code: abstract_code}
      specs = SpecParser.extract_specs(chunks)

      assert length(specs) == 1
      [spec] = specs

      assert spec.name == :multi_clause
      assert length(spec.clauses) == 2
    end

    test "extracts line numbers correctly" do
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:attribute, 42, :spec, {{:foo, 0}, [{:type, {42, 9}, :fun, []}]}},
           {:attribute, 100, :spec, {{:bar, 1}, [{:type, {100, 9}, :fun, []}]}}
         ]}

      chunks = %{abstract_code: abstract_code}
      specs = SpecParser.extract_specs(chunks)

      foo_spec = Enum.find(specs, &(&1.name == :foo))
      bar_spec = Enum.find(specs, &(&1.name == :bar))

      assert foo_spec.line == 42
      assert bar_spec.line == 100
    end
  end

  describe "extract_specs/1 with real BEAM files" do
    test "extracts specs from Stats module" do
      beam_path =
        "_build/dev/lib/ex_ast/ebin/Elixir.ExAst.Extractor.Stats.beam"

      {:ok, {_module, chunks}} = ExAst.BeamReader.read_chunks(beam_path)
      specs = SpecParser.extract_specs(chunks)

      # Stats module has specs for new/0, record_success/3, record_failure/1, to_map/1
      assert length(specs) >= 4

      # Check that we found the new/0 spec
      new_spec = Enum.find(specs, &(&1.name == :new and &1.arity == 0))
      assert new_spec != nil
      assert new_spec.kind == :spec
      assert new_spec.line > 0

      # Check record_success/6 (has default args so spec is arity 6)
      record_success_spec = Enum.find(specs, &(&1.name == :record_success and &1.arity == 6))
      assert record_success_spec != nil
      assert record_success_spec.kind == :spec
    end
  end

  describe "parse_spec_clause/1" do
    test "parses simple spec clause" do
      # @spec foo(integer) :: atom
      clause =
        {:type, {10, 9}, :fun,
         [
           {:type, {10, 9}, :product, [{:type, {10, 18}, :integer, []}]},
           {:type, {10, 30}, :atom, []}
         ]}

      result = SpecParser.parse_spec_clause(clause)

      assert result.inputs == [%{type: :builtin, name: :integer}]
      assert result.return == %{type: :builtin, name: :atom}
    end

    test "parses spec with multiple inputs" do
      # @spec foo(integer, binary) :: atom
      clause =
        {:type, {10, 9}, :fun,
         [
           {:type, {10, 9}, :product,
            [
              {:type, {10, 18}, :integer, []},
              {:type, {10, 30}, :binary, []}
            ]},
           {:type, {10, 44}, :atom, []}
         ]}

      result = SpecParser.parse_spec_clause(clause)

      assert result.inputs == [
               %{type: :builtin, name: :integer},
               %{type: :builtin, name: :binary}
             ]

      assert result.return == %{type: :builtin, name: :atom}
    end

    test "parses spec with no inputs" do
      # @spec foo() :: atom
      clause =
        {:type, {10, 9}, :fun,
         [
           {:type, {10, 9}, :product, []},
           {:type, {10, 18}, :atom, []}
         ]}

      result = SpecParser.parse_spec_clause(clause)

      assert result.inputs == []
      assert result.return == %{type: :builtin, name: :atom}
    end

    test "handles bounded_fun (when clauses)" do
      # @spec foo(a) :: a when a: integer
      clause =
        {:type, {10, 9}, :bounded_fun,
         [
           {:type, {10, 9}, :fun,
            [
              {:type, {10, 9}, :product, [{:var, {10, 14}, :a}]},
              {:var, {10, 20}, :a}
            ]},
           [
             {:type, {10, 27}, :constraint,
              [
                {:atom, {10, 27}, :is_subtype},
                [{:var, {10, 27}, :a}, {:type, {10, 30}, :integer, []}]
              ]}
           ]
         ]}

      result = SpecParser.parse_spec_clause(clause)

      assert result.inputs == [%{type: :var, name: :a}]
      assert result.return == %{type: :var, name: :a}
    end
  end

  describe "parse_spec_clause/1 with real BEAM data" do
    test "parses clauses from Stats module" do
      beam_path =
        "_build/dev/lib/ex_ast/ebin/Elixir.ExAst.Extractor.Stats.beam"

      {:ok, {_module, chunks}} = ExAst.BeamReader.read_chunks(beam_path)
      specs = SpecParser.extract_specs(chunks)

      # Parse record_success/6 spec (has default args so spec is arity 6)
      record_success_spec = Enum.find(specs, &(&1.name == :record_success and &1.arity == 6))
      [clause] = record_success_spec.clauses
      parsed = SpecParser.parse_spec_clause(clause)

      # Should have 6 inputs: t() x 1, non_neg_integer() x 5
      assert length(parsed.inputs) == 6

      # First input should be t() (local type ref)
      assert %{type: :type_ref, module: nil, name: :t} = hd(parsed.inputs)

      # Return should be t()
      assert %{type: :type_ref, module: nil, name: :t} = parsed.return
    end
  end
end
