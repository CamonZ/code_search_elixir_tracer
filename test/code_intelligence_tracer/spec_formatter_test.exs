defmodule CodeIntelligenceTracer.SpecFormatterTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.SpecFormatter

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

      result = SpecFormatter.format_spec(spec)

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

      result = SpecFormatter.format_spec(spec)

      [clause] = result.clauses
      assert clause.full == "@callback handle_call(term(), term()) :: term()"
    end
  end

  describe "format_spec/1 with real BEAM data" do
    test "formats specs from Stats module" do
      beam_path =
        "_build/dev/lib/code_search_elixir_tracer/ebin/Elixir.CodeIntelligenceTracer.Extractor.Stats.beam"

      {:ok, {_module, chunks}} = CodeIntelligenceTracer.BeamReader.read_chunks(beam_path)
      specs = CodeIntelligenceTracer.SpecExtractor.extract_specs(chunks)

      # Format new/0 spec
      new_spec = Enum.find(specs, &(&1.name == :new and &1.arity == 0))
      formatted = SpecFormatter.format_spec(new_spec)

      [clause] = formatted.clauses
      assert clause.inputs_string == []
      assert clause.return_string == "t()"
      assert clause.full == "@spec new() :: t()"

      # Format record_success/6 spec (has default args so spec is arity 6)
      record_spec = Enum.find(specs, &(&1.name == :record_success and &1.arity == 6))
      formatted = SpecFormatter.format_spec(record_spec)

      [clause] = formatted.clauses
      assert clause.inputs_string == ["t()", "non_neg_integer()", "non_neg_integer()", "non_neg_integer()", "non_neg_integer()", "non_neg_integer()"]
      assert clause.return_string == "t()"
      assert clause.full == "@spec record_success(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()"
    end
  end
end
