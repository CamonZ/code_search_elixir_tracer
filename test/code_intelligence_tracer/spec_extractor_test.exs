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

      # Check record_success/5 (has default args so spec is arity 5)
      record_success_spec = Enum.find(specs, &(&1.name == :record_success and &1.arity == 5))
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

      # Parse record_success/5 spec (has default args so spec is arity 5)
      record_success_spec = Enum.find(specs, &(&1.name == :record_success and &1.arity == 5))
      [clause] = record_success_spec.clauses
      parsed = SpecExtractor.parse_spec_clause(clause)

      # Should have 5 inputs: t(), non_neg_integer() x 4
      assert length(parsed.inputs) == 5

      # First input should be t() (local type ref)
      assert %{type: :type_ref, module: nil, name: :t} = hd(parsed.inputs)

      # Return should be t()
      assert %{type: :type_ref, module: nil, name: :t} = parsed.return
    end
  end

  # =============================================================================
  # T020: format_type_string/1 tests
  # =============================================================================

  describe "format_type_string/1" do
    test "formats builtin types" do
      assert SpecExtractor.format_type_string(%{type: :builtin, name: :integer}) == "integer()"
      assert SpecExtractor.format_type_string(%{type: :builtin, name: :binary}) == "binary()"
      assert SpecExtractor.format_type_string(%{type: :builtin, name: :atom}) == "atom()"
      assert SpecExtractor.format_type_string(%{type: :builtin, name: :term}) == "term()"
    end

    test "formats builtin types with args" do
      ast = %{type: :builtin, name: :nonempty_list, args: [%{type: :builtin, name: :integer}]}
      assert SpecExtractor.format_type_string(ast) == "nonempty_list(integer())"
    end

    test "formats atom literals" do
      assert SpecExtractor.format_type_string(%{type: :literal, kind: :atom, value: :ok}) == ":ok"

      assert SpecExtractor.format_type_string(%{type: :literal, kind: :atom, value: :error}) ==
               ":error"
    end

    test "formats integer literals" do
      assert SpecExtractor.format_type_string(%{type: :literal, kind: :integer, value: 42}) == "42"
    end

    test "formats local type refs" do
      assert SpecExtractor.format_type_string(%{type: :type_ref, module: nil, name: :t, args: []}) ==
               "t()"

      ast = %{
        type: :type_ref,
        module: nil,
        name: :option,
        args: [%{type: :builtin, name: :integer}]
      }

      assert SpecExtractor.format_type_string(ast) == "option(integer())"
    end

    test "formats remote type refs" do
      assert SpecExtractor.format_type_string(%{
               type: :type_ref,
               module: "String",
               name: :t,
               args: []
             }) == "String.t()"

      ast = %{
        type: :type_ref,
        module: "GenServer",
        name: :on_start,
        args: []
      }

      assert SpecExtractor.format_type_string(ast) == "GenServer.on_start()"
    end

    test "formats union types" do
      ast = %{
        type: :union,
        types: [
          %{type: :builtin, name: :integer},
          %{type: :builtin, name: :atom}
        ]
      }

      assert SpecExtractor.format_type_string(ast) == "integer() | atom()"
    end

    test "formats tuple types" do
      ast = %{
        type: :tuple,
        elements: [
          %{type: :literal, kind: :atom, value: :ok},
          %{type: :builtin, name: :integer}
        ]
      }

      assert SpecExtractor.format_type_string(ast) == "{:ok, integer()}"
    end

    test "formats any tuple" do
      assert SpecExtractor.format_type_string(%{type: :tuple, elements: :any}) == "tuple()"
    end

    test "formats list types" do
      ast = %{type: :list, element_type: %{type: :builtin, name: :integer}}
      assert SpecExtractor.format_type_string(ast) == "[integer()]"
    end

    test "formats empty list type" do
      assert SpecExtractor.format_type_string(%{type: :list, element_type: nil}) == "list()"
    end

    test "formats map types" do
      ast = %{
        type: :map,
        fields: [
          %{
            kind: :exact,
            key: %{type: :literal, kind: :atom, value: :name},
            value: %{type: :type_ref, module: "String", name: :t, args: []}
          }
        ]
      }

      assert SpecExtractor.format_type_string(ast) == "%{name: String.t()}"
    end

    test "formats any map" do
      assert SpecExtractor.format_type_string(%{type: :map, fields: :any}) == "map()"
    end

    test "formats function types" do
      ast = %{
        type: :fun,
        inputs: [%{type: :builtin, name: :integer}],
        return: %{type: :builtin, name: :atom}
      }

      assert SpecExtractor.format_type_string(ast) == "(integer() -> atom())"
    end

    test "formats type variables" do
      assert SpecExtractor.format_type_string(%{type: :var, name: :a}) == "a"
      assert SpecExtractor.format_type_string(%{type: :var, name: :T}) == "T"
    end

    test "formats any type" do
      assert SpecExtractor.format_type_string(%{type: :any}) == "any()"
    end
  end

  describe "format_spec/1" do
    test "formats a complete spec" do
      spec = %{
        name: :foo,
        arity: 1,
        kind: :spec,
        line: 10,
        clauses: [
          {:type, {10, 9}, :fun,
           [
             {:type, {10, 9}, :product, [{:type, {10, 18}, :integer, []}]},
             {:type, {10, 30}, :atom, []}
           ]}
        ]
      }

      result = SpecExtractor.format_spec(spec)

      assert result.name == :foo
      assert result.arity == 1
      assert result.kind == :spec
      assert result.line == 10
      assert length(result.clauses) == 1

      [clause] = result.clauses
      assert clause.inputs_string == ["integer()"]
      assert clause.return_string == "atom()"
      assert clause.full == "@spec foo(integer()) :: atom()"
    end

    test "formats a callback" do
      spec = %{
        name: :handle_call,
        arity: 2,
        kind: :callback,
        line: 5,
        clauses: [
          {:type, {5, 9}, :fun,
           [
             {:type, {5, 9}, :product,
              [
                {:type, {5, 20}, :term, []},
                {:type, {5, 27}, :term, []}
              ]},
             {:type, {5, 34}, :term, []}
           ]}
        ]
      }

      result = SpecExtractor.format_spec(spec)

      [clause] = result.clauses
      assert clause.full == "@callback handle_call(term(), term()) :: term()"
    end
  end

  describe "format_spec/1 with real BEAM data" do
    test "formats specs from Stats module" do
      beam_path =
        "_build/dev/lib/code_search_elixir_tracer/ebin/Elixir.CodeIntelligenceTracer.Stats.beam"

      {:ok, {_module, chunks}} = CodeIntelligenceTracer.BeamReader.read_chunks(beam_path)
      specs = SpecExtractor.extract_specs(chunks)

      # Format new/0 spec
      new_spec = Enum.find(specs, &(&1.name == :new and &1.arity == 0))
      formatted = SpecExtractor.format_spec(new_spec)

      [clause] = formatted.clauses
      assert clause.inputs_string == []
      assert clause.return_string == "t()"
      assert clause.full == "@spec new() :: t()"

      # Format record_success/5 spec (has default args so spec is arity 5)
      record_spec = Enum.find(specs, &(&1.name == :record_success and &1.arity == 5))
      formatted = SpecExtractor.format_spec(record_spec)

      [clause] = formatted.clauses
      assert clause.inputs_string == ["t()", "non_neg_integer()", "non_neg_integer()", "non_neg_integer()", "non_neg_integer()"]
      assert clause.return_string == "t()"
      assert clause.full == "@spec record_success(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()"
    end
  end

  # =============================================================================
  # T021: correlate_specs/2 tests
  # =============================================================================

  describe "correlate_specs/2" do
    test "adds specs to matching functions" do
      functions = %{
        "foo/1" => %{start_line: 10, end_line: 15, kind: :def},
        "bar/0" => %{start_line: 20, end_line: 25, kind: :def}
      }

      specs = [
        %{
          name: :foo,
          arity: 1,
          kind: :spec,
          line: 9,
          clauses: [
            {:type, {9, 9}, :fun,
             [
               {:type, {9, 9}, :product, [{:type, {9, 18}, :integer, []}]},
               {:type, {9, 30}, :atom, []}
             ]}
          ]
        }
      ]

      result = SpecExtractor.correlate_specs(functions, specs)

      # foo/1 should have the spec
      assert result["foo/1"].spec != nil
      assert result["foo/1"].spec.kind == :spec
      assert result["foo/1"].spec.line == 9
      assert result["foo/1"].spec.full == "@spec foo(integer()) :: atom()"

      # bar/0 should have spec: nil
      assert result["bar/0"].spec == nil
    end

    test "handles functions without specs" do
      functions = %{
        "foo/0" => %{start_line: 10, kind: :def},
        "bar/1" => %{start_line: 20, kind: :def}
      }

      specs = []

      result = SpecExtractor.correlate_specs(functions, specs)

      assert result["foo/0"].spec == nil
      assert result["bar/1"].spec == nil
    end

    test "handles multiple arities correctly" do
      functions = %{
        "foo/0" => %{start_line: 10, kind: :def},
        "foo/1" => %{start_line: 15, kind: :def},
        "foo/2" => %{start_line: 20, kind: :def}
      }

      specs = [
        %{
          name: :foo,
          arity: 1,
          kind: :spec,
          line: 14,
          clauses: [
            {:type, {14, 9}, :fun,
             [
               {:type, {14, 9}, :product, [{:type, {14, 18}, :integer, []}]},
               {:type, {14, 30}, :atom, []}
             ]}
          ]
        },
        %{
          name: :foo,
          arity: 2,
          kind: :spec,
          line: 19,
          clauses: [
            {:type, {19, 9}, :fun,
             [
               {:type, {19, 9}, :product,
                [
                  {:type, {19, 18}, :integer, []},
                  {:type, {19, 28}, :binary, []}
                ]},
               {:type, {19, 40}, :atom, []}
             ]}
          ]
        }
      ]

      result = SpecExtractor.correlate_specs(functions, specs)

      # foo/0 has no spec
      assert result["foo/0"].spec == nil

      # foo/1 has spec
      assert result["foo/1"].spec != nil
      assert result["foo/1"].spec.full == "@spec foo(integer()) :: atom()"

      # foo/2 has spec
      assert result["foo/2"].spec != nil
      assert result["foo/2"].spec.full == "@spec foo(integer(), binary()) :: atom()"
    end

    test "excludes __info__ specs" do
      functions = %{
        "foo/0" => %{start_line: 10, kind: :def}
      }

      specs = [
        %{
          name: :__info__,
          arity: 1,
          kind: :spec,
          line: 1,
          clauses: [{:type, {1, 9}, :fun, []}]
        },
        %{
          name: :foo,
          arity: 0,
          kind: :spec,
          line: 9,
          clauses: [
            {:type, {9, 9}, :fun,
             [
               {:type, {9, 9}, :product, []},
               {:type, {9, 18}, :atom, []}
             ]}
          ]
        }
      ]

      result = SpecExtractor.correlate_specs(functions, specs)

      # Only foo/0 should have spec, __info__ should not appear
      assert result["foo/0"].spec != nil
      assert result["foo/0"].spec.full == "@spec foo() :: atom()"
    end

    test "preserves original function info" do
      functions = %{
        "foo/1" => %{
          start_line: 10,
          end_line: 15,
          kind: :def,
          source_file: "lib/foo.ex",
          custom_field: "preserved"
        }
      }

      specs = [
        %{
          name: :foo,
          arity: 1,
          kind: :spec,
          line: 9,
          clauses: [
            {:type, {9, 9}, :fun,
             [
               {:type, {9, 9}, :product, [{:type, {9, 18}, :integer, []}]},
               {:type, {9, 30}, :atom, []}
             ]}
          ]
        }
      ]

      result = SpecExtractor.correlate_specs(functions, specs)

      # Original fields should be preserved
      assert result["foo/1"].start_line == 10
      assert result["foo/1"].end_line == 15
      assert result["foo/1"].kind == :def
      assert result["foo/1"].source_file == "lib/foo.ex"
      assert result["foo/1"].custom_field == "preserved"

      # Spec should be added
      assert result["foo/1"].spec != nil
    end
  end

  describe "correlate_specs/2 with real BEAM data" do
    test "correlates specs with functions from Stats module" do
      beam_path =
        "_build/dev/lib/code_search_elixir_tracer/ebin/Elixir.CodeIntelligenceTracer.Stats.beam"

      {:ok, {_module, chunks}} = CodeIntelligenceTracer.BeamReader.read_chunks(beam_path)
      {:ok, debug_info} = CodeIntelligenceTracer.BeamReader.extract_debug_info(chunks, CodeIntelligenceTracer.Stats)

      # Extract functions and specs
      functions =
        debug_info.definitions
        |> CodeIntelligenceTracer.FunctionExtractor.extract_functions("")

      specs = SpecExtractor.extract_specs(chunks)

      # Correlate
      result = SpecExtractor.correlate_specs(functions, specs)

      # new/0 should have spec
      assert result["new/0"].spec != nil
      assert result["new/0"].spec.full == "@spec new() :: t()"

      # record_success/5 should have spec (default args mean function has arities 3,4,5 but spec is arity 5)
      assert result["record_success/5"].spec != nil
      assert result["record_success/5"].spec.inputs_string == ["t()", "non_neg_integer()", "non_neg_integer()", "non_neg_integer()", "non_neg_integer()"]
    end
  end

  # =============================================================================
  # T022: extract_types/1 tests
  # =============================================================================

  describe "extract_types/1" do
    test "extracts type definitions" do
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:attribute, 5, :type, {:my_type, {:type, {5, 20}, :integer, []}, []}}
         ]}

      chunks = %{abstract_code: abstract_code}
      types = SpecExtractor.extract_types(chunks)

      assert length(types) == 1
      [type_def] = types

      assert type_def.name == :my_type
      assert type_def.kind == :type
      assert type_def.params == []
      assert type_def.line == 5
      assert type_def.definition == "@type my_type() :: integer()"
    end

    test "extracts opaque type definitions" do
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:attribute, 10, :opaque, {:secret, {:type, {10, 25}, :term, []}, []}}
         ]}

      chunks = %{abstract_code: abstract_code}
      types = SpecExtractor.extract_types(chunks)

      assert length(types) == 1
      [type_def] = types

      assert type_def.name == :secret
      assert type_def.kind == :opaque
      assert type_def.definition == "@opaque secret() :: term()"
    end

    test "extracts parameterized types" do
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:attribute, 15, :type,
            {:result,
             {:type, {15, 30}, :union,
              [
                {:type, {15, 30}, :tuple,
                 [{:atom, 0, :ok}, {:var, {15, 36}, :a}]},
                {:type, {15, 45}, :tuple,
                 [{:atom, 0, :error}, {:var, {15, 55}, :b}]}
              ]},
             [{:var, {15, 20}, :a}, {:var, {15, 23}, :b}]}}
         ]}

      chunks = %{abstract_code: abstract_code}
      types = SpecExtractor.extract_types(chunks)

      assert length(types) == 1
      [type_def] = types

      assert type_def.name == :result
      assert type_def.kind == :type
      assert type_def.params == [:a, :b]
      assert type_def.definition == "@type result(a, b) :: {:ok, a} | {:error, b}"
    end

    test "extracts both types and opaques" do
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:attribute, 5, :type, {:public, {:type, {5, 20}, :integer, []}, []}},
           {:attribute, 10, :opaque, {:private, {:type, {10, 25}, :binary, []}, []}}
         ]}

      chunks = %{abstract_code: abstract_code}
      types = SpecExtractor.extract_types(chunks)

      assert length(types) == 2

      public_type = Enum.find(types, &(&1.kind == :type))
      opaque_type = Enum.find(types, &(&1.kind == :opaque))

      assert public_type.name == :public
      assert opaque_type.name == :private
    end

    test "returns empty list when no abstract_code chunk" do
      chunks = %{abstract_code: nil}
      assert SpecExtractor.extract_types(chunks) == []
    end

    test "handles modules without types" do
      abstract_code =
        {:raw_abstract_v1,
         [
           {:attribute, 1, :module, TestModule},
           {:function, 5, :some_func, 0, [{:clause, 5, [], [], [{:atom, 5, :ok}]}]}
         ]}

      chunks = %{abstract_code: abstract_code}
      assert SpecExtractor.extract_types(chunks) == []
    end
  end

  describe "extract_types/1 with real BEAM data" do
    test "extracts types from Stats module" do
      beam_path =
        "_build/dev/lib/code_search_elixir_tracer/ebin/Elixir.CodeIntelligenceTracer.Stats.beam"

      {:ok, {_module, chunks}} = CodeIntelligenceTracer.BeamReader.read_chunks(beam_path)
      types = SpecExtractor.extract_types(chunks)

      # Stats module has @type t
      assert length(types) >= 1

      t_type = Enum.find(types, &(&1.name == :t))
      assert t_type != nil
      assert t_type.kind == :type
      assert t_type.params == []
      assert String.starts_with?(t_type.definition, "@type t() ::")
    end
  end
end
