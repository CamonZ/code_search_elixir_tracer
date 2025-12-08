defmodule CodeIntelligenceTracer.SpecExtractorTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.SpecExtractor

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
      specs = SpecExtractor.extract_specs(chunks)

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
      specs = SpecExtractor.extract_specs(chunks)

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
                [{:type, {10, 9}, :product, [{:type, {10, 21}, :any, []}]},
                 {:type, {10, 29}, :ok, []}]}
             ]}},
           {:attribute, 20, :callback,
            {{:on_init, 0},
             [
               {:type, {20, 9}, :fun,
                [{:type, {20, 9}, :product, []}, {:type, {20, 20}, :ok, []}]}
             ]}}
         ]}

      chunks = %{abstract_code: abstract_code}
      specs = SpecExtractor.extract_specs(chunks)

      assert length(specs) == 2

      spec = Enum.find(specs, &(&1.kind == :spec))
      callback = Enum.find(specs, &(&1.kind == :callback))

      assert spec.name == :public_func
      assert callback.name == :on_init
    end

    test "returns empty list when no abstract_code chunk" do
      chunks = %{abstract_code: nil}
      assert SpecExtractor.extract_specs(chunks) == []
    end

    test "returns empty list for unsupported abstract_code format" do
      chunks = %{abstract_code: {:unknown_format, []}}
      assert SpecExtractor.extract_specs(chunks) == []
    end

    test "handles modules without specs" do
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:function, 5, :some_func, 0, [{:clause, 5, [], [], [{:atom, 5, :ok}]}]}
         ]}

      chunks = %{abstract_code: abstract_code}
      assert SpecExtractor.extract_specs(chunks) == []
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
                [{:type, {10, 9}, :product, [{:type, {10, 22}, :integer, []}]},
                 {:atom, {10, 35}, :ok}]},
               {:type, {11, 9}, :fun,
                [{:type, {11, 9}, :product, [{:type, {11, 22}, :binary, []}]},
                 {:atom, {11, 35}, :error}]}
             ]}}
         ]}

      chunks = %{abstract_code: abstract_code}
      specs = SpecExtractor.extract_specs(chunks)

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
      specs = SpecExtractor.extract_specs(chunks)

      foo_spec = Enum.find(specs, &(&1.name == :foo))
      bar_spec = Enum.find(specs, &(&1.name == :bar))

      assert foo_spec.line == 42
      assert bar_spec.line == 100
    end
  end

  describe "extract_specs/1 with real BEAM files" do
    test "extracts specs from Stats module" do
      beam_path =
        "_build/dev/lib/code_search_elixir_tracer/ebin/Elixir.CodeIntelligenceTracer.Stats.beam"

      {:ok, {_module, chunks}} = CodeIntelligenceTracer.BeamReader.read_chunks(beam_path)
      specs = SpecExtractor.extract_specs(chunks)

      # Stats module has specs for new/0, record_success/3, record_failure/1, to_map/1
      assert length(specs) >= 4

      # Check that we found the new/0 spec
      new_spec = Enum.find(specs, &(&1.name == :new and &1.arity == 0))
      assert new_spec != nil
      assert new_spec.kind == :spec
      assert new_spec.line > 0

      # Check record_success/3
      record_success_spec = Enum.find(specs, &(&1.name == :record_success and &1.arity == 3))
      assert record_success_spec != nil
      assert record_success_spec.kind == :spec
    end
  end

  # =============================================================================
  # T019: parse_spec_clause/1 and parse_type_ast/1 tests
  # =============================================================================

  describe "parse_spec_clause/1" do
    test "parses simple spec clause" do
      # @spec foo(integer) :: atom
      clause =
        {:type, {10, 9}, :fun,
         [
           {:type, {10, 9}, :product, [{:type, {10, 18}, :integer, []}]},
           {:type, {10, 30}, :atom, []}
         ]}

      result = SpecExtractor.parse_spec_clause(clause)

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

      result = SpecExtractor.parse_spec_clause(clause)

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

      result = SpecExtractor.parse_spec_clause(clause)

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
           [{:type, {10, 27}, :constraint,
             [{:atom, {10, 27}, :is_subtype}, [{:var, {10, 27}, :a}, {:type, {10, 30}, :integer, []}]]}]
         ]}

      result = SpecExtractor.parse_spec_clause(clause)

      assert result.inputs == [%{type: :var, name: :a}]
      assert result.return == %{type: :var, name: :a}
    end
  end

  describe "parse_type_ast/1" do
    test "parses builtin types" do
      assert SpecExtractor.parse_type_ast({:type, {1, 1}, :integer, []}) ==
               %{type: :builtin, name: :integer}

      assert SpecExtractor.parse_type_ast({:type, {1, 1}, :binary, []}) ==
               %{type: :builtin, name: :binary}

      assert SpecExtractor.parse_type_ast({:type, {1, 1}, :atom, []}) ==
               %{type: :builtin, name: :atom}

      assert SpecExtractor.parse_type_ast({:type, {1, 1}, :term, []}) ==
               %{type: :builtin, name: :term}

      assert SpecExtractor.parse_type_ast({:type, {1, 1}, :any, []}) ==
               %{type: :builtin, name: :any}
    end

    test "parses union types" do
      # integer | atom
      union_ast =
        {:type, {1, 1}, :union,
         [
           {:type, {1, 1}, :integer, []},
           {:type, {1, 10}, :atom, []}
         ]}

      result = SpecExtractor.parse_type_ast(union_ast)

      assert result == %{
               type: :union,
               types: [
                 %{type: :builtin, name: :integer},
                 %{type: :builtin, name: :atom}
               ]
             }
    end

    test "parses tuple types" do
      # {atom, integer}
      tuple_ast =
        {:type, {1, 1}, :tuple,
         [
           {:type, {1, 2}, :atom, []},
           {:type, {1, 8}, :integer, []}
         ]}

      result = SpecExtractor.parse_type_ast(tuple_ast)

      assert result == %{
               type: :tuple,
               elements: [
                 %{type: :builtin, name: :atom},
                 %{type: :builtin, name: :integer}
               ]
             }
    end

    test "parses any tuple" do
      result = SpecExtractor.parse_type_ast({:type, {1, 1}, :tuple, :any})
      assert result == %{type: :tuple, elements: :any}
    end

    test "parses list types" do
      # [integer]
      list_ast = {:type, {1, 1}, :list, [{:type, {1, 2}, :integer, []}]}

      result = SpecExtractor.parse_type_ast(list_ast)

      assert result == %{
               type: :list,
               element_type: %{type: :builtin, name: :integer}
             }
    end

    test "parses empty list type" do
      result = SpecExtractor.parse_type_ast({:type, {1, 1}, :list, []})
      assert result == %{type: :list, element_type: nil}
    end

    test "parses map types with fields" do
      # %{key: value}
      map_ast =
        {:type, {1, 1}, :map,
         [
           {:type, {1, 3}, :map_field_exact,
            [
              {:atom, {1, 3}, :key},
              {:type, {1, 9}, :integer, []}
            ]}
         ]}

      result = SpecExtractor.parse_type_ast(map_ast)

      assert result == %{
               type: :map,
               fields: [
                 %{
                   kind: :exact,
                   key: %{type: :literal, kind: :atom, value: :key},
                   value: %{type: :builtin, name: :integer}
                 }
               ]
             }
    end

    test "parses any map" do
      result = SpecExtractor.parse_type_ast({:type, {1, 1}, :map, :any})
      assert result == %{type: :map, fields: :any}
    end

    test "parses remote type references" do
      # String.t()
      remote_ast =
        {:remote_type, {1, 1},
         [
           {:atom, 0, String},
           {:atom, 0, :t},
           []
         ]}

      result = SpecExtractor.parse_type_ast(remote_ast)

      assert result == %{
               type: :type_ref,
               module: "String",
               name: :t,
               args: []
             }
    end

    test "parses local type references" do
      # t()
      user_type_ast = {:user_type, {1, 1}, :t, []}

      result = SpecExtractor.parse_type_ast(user_type_ast)

      assert result == %{
               type: :type_ref,
               module: nil,
               name: :t,
               args: []
             }
    end

    test "parses atom literals" do
      result = SpecExtractor.parse_type_ast({:atom, {1, 1}, :ok})
      assert result == %{type: :literal, kind: :atom, value: :ok}
    end

    test "parses integer literals" do
      result = SpecExtractor.parse_type_ast({:integer, {1, 1}, 42})
      assert result == %{type: :literal, kind: :integer, value: 42}
    end

    test "parses type variables" do
      result = SpecExtractor.parse_type_ast({:var, {1, 1}, :a})
      assert result == %{type: :var, name: :a}
    end

    test "parses function types" do
      # (integer -> atom)
      fun_ast =
        {:type, {1, 1}, :fun,
         [
           {:type, {1, 2}, :product, [{:type, {1, 3}, :integer, []}]},
           {:type, {1, 15}, :atom, []}
         ]}

      result = SpecExtractor.parse_type_ast(fun_ast)

      assert result == %{
               type: :fun,
               inputs: [%{type: :builtin, name: :integer}],
               return: %{type: :builtin, name: :atom}
             }
    end

    test "parses annotated types" do
      # name :: integer
      ann_ast =
        {:ann_type, {1, 1},
         [
           {:var, {1, 1}, :name},
           {:type, {1, 10}, :integer, []}
         ]}

      result = SpecExtractor.parse_type_ast(ann_ast)

      # Annotated types strip the name and return the underlying type
      assert result == %{type: :builtin, name: :integer}
    end

    test "parses builtin types with args" do
      # nonempty_list(integer)
      ast = {:type, {1, 1}, :nonempty_list, [{:type, {1, 15}, :integer, []}]}

      result = SpecExtractor.parse_type_ast(ast)

      assert result == %{
               type: :builtin,
               name: :nonempty_list,
               args: [%{type: :builtin, name: :integer}]
             }
    end
  end

  describe "parse_spec_clause/1 with real BEAM data" do
    test "parses clauses from Stats module" do
      beam_path =
        "_build/dev/lib/code_search_elixir_tracer/ebin/Elixir.CodeIntelligenceTracer.Stats.beam"

      {:ok, {_module, chunks}} = CodeIntelligenceTracer.BeamReader.read_chunks(beam_path)
      specs = SpecExtractor.extract_specs(chunks)

      # Parse record_success/3 spec
      record_success_spec = Enum.find(specs, &(&1.name == :record_success and &1.arity == 3))
      [clause] = record_success_spec.clauses
      parsed = SpecExtractor.parse_spec_clause(clause)

      # Should have 3 inputs: t(), non_neg_integer(), non_neg_integer()
      assert length(parsed.inputs) == 3

      # First input should be t() (local type ref)
      assert %{type: :type_ref, module: nil, name: :t} = hd(parsed.inputs)

      # Return should be t()
      assert %{type: :type_ref, module: nil, name: :t} = parsed.return
    end
  end
end
