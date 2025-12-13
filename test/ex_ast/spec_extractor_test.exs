defmodule ExAst.SpecExtractorTest do
  use ExUnit.Case, async: true

  alias ExAst.SpecExtractor

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
        "_build/dev/lib/code_search_elixir_tracer/ebin/Elixir.ExAst.Extractor.Stats.beam"

      {:ok, {_module, chunks}} = ExAst.BeamReader.read_chunks(beam_path)
      {:ok, debug_info} = ExAst.BeamReader.extract_debug_info(chunks, ExAst.Stats)

      # Extract functions and specs
      functions =
        debug_info.definitions
        |> ExAst.FunctionExtractor.extract_functions("")

      specs = SpecExtractor.extract_specs(chunks)

      # Correlate
      result = SpecExtractor.correlate_specs(functions, specs)

      # Find new/0 entry (keys are now "name/arity:line")
      {_key, new_0} = Enum.find(result, fn {key, _} -> String.starts_with?(key, "new/0:") end)
      assert new_0.spec != nil
      assert new_0.spec.full == "@spec new() :: t()"

      # record_success/6 should have spec (default args mean function has arities 3,4,5,6 but spec is arity 6)
      {_key, record_success_6} = Enum.find(result, fn {key, _} -> String.starts_with?(key, "record_success/6:") end)
      assert record_success_6.spec != nil
      assert record_success_6.spec.inputs_string == ["t()", "non_neg_integer()", "non_neg_integer()", "non_neg_integer()", "non_neg_integer()", "non_neg_integer()"]
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
        "_build/dev/lib/code_search_elixir_tracer/ebin/Elixir.ExAst.Extractor.Stats.beam"

      {:ok, {_module, chunks}} = ExAst.BeamReader.read_chunks(beam_path)
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
