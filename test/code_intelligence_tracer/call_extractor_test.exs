defmodule CodeIntelligenceTracer.CallExtractorTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.CallExtractor
  alias CodeIntelligenceTracer.BeamReader

  describe "extract_calls/3" do
    test "extracts remote call Enum.map(list, fun)" do
      # Create a simple definition that calls Enum.map
      definitions = [
        {{:my_function, 1}, :def, [line: 1], [
          {[line: 2], [{:list, [line: 2], nil}], [],
           {{:., [line: 3], [{:__aliases__, [line: 3], [:Enum]}, :map]}, [line: 3],
            [{:list, [line: 3], nil}, {:fun, [line: 3], nil}]}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")

      assert length(calls) == 1
      [call] = calls

      assert call.type == :remote
      assert call.caller.module == "MyApp.Foo"
      assert call.caller.function == "my_function/1"
      assert call.caller.kind == :def
      assert call.caller.file == "lib/my_app/foo.ex"
      assert call.caller.line == 3
      assert call.callee.module == "Enum"
      assert call.callee.function == "map"
      assert call.callee.arity == 2
    end

    test "extracts local call helper(x)" do
      definitions = [
        {{:my_function, 1}, :def, [line: 1], [
          {[line: 2], [{:x, [line: 2], nil}], [],
           {:helper, [line: 3], [{:x, [line: 3], nil}]}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")

      assert length(calls) == 1
      [call] = calls

      assert call.type == :local
      assert call.caller.module == "MyApp.Foo"
      assert call.caller.function == "my_function/1"
      assert call.caller.kind == :def
      assert call.caller.file == "lib/my_app/foo.ex"
      assert call.caller.line == 3
      # Local calls have the same module as the caller
      assert call.callee.module == "MyApp.Foo"
      assert call.callee.function == "helper"
      assert call.callee.arity == 1
    end

    test "captures line numbers correctly" do
      definitions = [
        {{:process, 0}, :def, [line: 10], [
          {[line: 11], [], [],
           {:__block__, [],
            [
              {{:., [line: 15], [{:__aliases__, [line: 15], [:IO]}, :puts]}, [line: 15],
               ["hello"]},
              {{:., [line: 20], [{:__aliases__, [line: 20], [:Enum]}, :each]}, [line: 20],
               [{:list, [line: 20], nil}, {:fun, [line: 20], nil}]}
            ]}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")

      lines = Enum.map(calls, & &1.caller.line) |> Enum.sort()
      assert lines == [15, 20]
    end

    test "handles nested calls" do
      # Nested call: Enum.map(Enum.filter(list, pred), fun)
      definitions = [
        {{:nested, 1}, :def, [line: 1], [
          {[line: 2], [{:list, [line: 2], nil}], [],
           {{:., [line: 3], [{:__aliases__, [line: 3], [:Enum]}, :map]}, [line: 3],
            [
              {{:., [line: 3], [{:__aliases__, [line: 3], [:Enum]}, :filter]}, [line: 3],
               [{:list, [line: 3], nil}, {:pred, [line: 3], nil}]},
              {:fun, [line: 3], nil}
            ]}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")

      assert length(calls) == 2

      function_names = Enum.map(calls, & &1.callee.function) |> Enum.sort()
      assert function_names == ["filter", "map"]
    end

    test "extracts calls from real module using BeamReader" do
      # Test with our own BeamReader module
      beam_path =
        CodeIntelligenceTracer.BeamReader
        |> :code.which()
        |> to_string()

      {:ok, {module, chunks}} = BeamReader.read_chunks(beam_path)
      {:ok, debug_info} = BeamReader.extract_debug_info(chunks, module)

      calls =
        CallExtractor.extract_calls(
          debug_info.definitions,
          debug_info.module,
          debug_info.file
        )

      assert is_list(calls)
      assert length(calls) > 0

      # Should find calls to :beam_lib functions (Erlang module, so "beam_lib" without colon)
      beam_lib_calls = Enum.filter(calls, &(&1.callee.module == "beam_lib"))
      assert length(beam_lib_calls) > 0

      # All calls should have proper structure
      Enum.each(calls, fn call ->
        assert call.type in [:remote, :local]
        assert is_binary(call.caller.module)
        assert is_binary(call.caller.function)
        assert is_binary(call.caller.file)
        assert is_integer(call.caller.line)
        assert is_binary(call.callee.module)
        assert is_binary(call.callee.function)
        assert is_integer(call.callee.arity)
      end)
    end

    test "handles Erlang module calls (:erlang_module.function)" do
      definitions = [
        {{:get_info, 0}, :def, [line: 1], [
          {[line: 2], [], [],
           {{:., [line: 3], [:erlang, :system_info]}, [line: 3], [:otp_release]}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.System, "lib/my_app/system.ex")

      assert length(calls) == 1
      [call] = calls

      assert call.type == :remote
      # Erlang atoms are converted to strings without the colon prefix
      assert call.callee.module == "erlang"
      assert call.callee.function == "system_info"
      assert call.callee.arity == 1
    end

    test "excludes special forms from local calls" do
      # Block with special forms that shouldn't be counted as calls
      definitions = [
        {{:my_func, 0}, :def, [line: 1], [
          {[line: 2], [], [],
           {:__block__, [],
            [
              {:=, [line: 3], [{:x, [line: 3], nil}, 1]},
              {:case, [line: 4],
               [
                 {:x, [line: 4], nil},
                 [do: [{:->, [line: 5], [[1], :one]}]]
               ]}
            ]}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")

      # Should not include __block__, case, =, etc.
      function_names = Enum.map(calls, & &1.callee.function)
      refute "__block__" in function_names
      refute "case" in function_names
      refute "=" in function_names
    end

    test "handles multiple clauses in function" do
      definitions = [
        {{:multi_clause, 1}, :def, [line: 1], [
          {[line: 2], [1], [],
           {:first_helper, [line: 3], []}},
          {[line: 5], [2], [],
           {:second_helper, [line: 6], []}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")

      assert length(calls) == 2
      function_names = Enum.map(calls, & &1.callee.function) |> Enum.sort()
      assert function_names == ["first_helper", "second_helper"]
    end

    test "returns empty list for empty definitions" do
      calls = CallExtractor.extract_calls([], MyApp.Empty, "lib/my_app/empty.ex")
      assert calls == []
    end

    test "extracts calls from private functions with correct kind" do
      definitions = [
        {{:public_func, 0}, :def, [line: 1], [
          {[line: 2], [], [],
           {:public_helper, [line: 3], []}}
        ]},
        {{:private_func, 0}, :defp, [line: 5], [
          {[line: 6], [], [],
           {:private_helper, [line: 7], []}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")

      assert length(calls) == 2

      public_call = Enum.find(calls, &(&1.callee.function == "public_helper"))
      private_call = Enum.find(calls, &(&1.callee.function == "private_helper"))

      assert public_call.caller.kind == :def
      assert private_call.caller.kind == :defp
    end

    test "extracts calls from macros with correct kind" do
      definitions = [
        {{:my_macro, 1}, :defmacro, [line: 1], [
          {[line: 2], [{:arg, [line: 2], nil}], [],
           {{:., [line: 3], [{:__aliases__, [line: 3], [:Macro]}, :expand]}, [line: 3],
            [{:arg, [line: 3], nil}, {:__ENV__, [line: 3], nil}]}}
        ]},
        {{:private_macro, 0}, :defmacrop, [line: 5], [
          {[line: 6], [], [],
           {:do_something, [line: 7], []}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Macros, "lib/my_app/macros.ex")

      macro_call = Enum.find(calls, &(&1.callee.function == "expand"))
      private_macro_call = Enum.find(calls, &(&1.callee.function == "do_something"))

      assert macro_call.caller.kind == :defmacro
      assert private_macro_call.caller.kind == :defmacrop
    end

    test "extracts remote function capture &Module.function/arity with correct arity" do
      # AST for: &String.upcase/1
      # {:&, [line: 3], [{:/, [line: 3], [{{:., [line: 3], [{:__aliases__, [line: 3], [:String]}, :upcase]}, [no_parens: true, line: 3], []}, 1]}]}
      definitions = [
        {{:my_function, 1}, :def, [line: 1], [
          {[line: 2], [{:list, [line: 2], nil}], [],
           {:&, [line: 3],
            [{:/, [line: 3],
              [{{:., [line: 3], [{:__aliases__, [line: 3], [:String]}, :upcase]},
                [no_parens: true, line: 3], []}, 1]}]}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")

      assert length(calls) == 1
      [call] = calls

      assert call.type == :remote
      assert call.caller.module == "MyApp.Foo"
      assert call.caller.function == "my_function/1"
      assert call.callee.module == "String"
      assert call.callee.function == "upcase"
      assert call.callee.arity == 1
    end

    test "extracts local function capture &function/arity with correct arity" do
      # AST for: &helper/2
      # {:&, [line: 3], [{:/, [line: 3], [{:helper, [line: 3], nil}, 2]}]}
      definitions = [
        {{:my_function, 0}, :def, [line: 1], [
          {[line: 2], [], [],
           {:&, [line: 3],
            [{:/, [line: 3], [{:helper, [line: 3], nil}, 2]}]}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")

      assert length(calls) == 1
      [call] = calls

      assert call.type == :local
      assert call.caller.module == "MyApp.Foo"
      assert call.caller.function == "my_function/0"
      assert call.callee.module == "MyApp.Foo"
      assert call.callee.function == "helper"
      assert call.callee.arity == 2
    end

    test "extracts function capture passed to Enum.map" do
      # AST for: Enum.map(list, &String.downcase/1)
      definitions = [
        {{:process, 1}, :def, [line: 1], [
          {[line: 2], [{:list, [line: 2], nil}], [],
           {{:., [line: 3], [{:__aliases__, [line: 3], [:Enum]}, :map]}, [line: 3],
            [{:list, [line: 3], nil},
             {:&, [line: 3],
              [{:/, [line: 3],
                [{{:., [line: 3], [{:__aliases__, [line: 3], [:String]}, :downcase]},
                  [no_parens: true, line: 3], []}, 1]}]}]}}
        ]}
      ]

      calls = CallExtractor.extract_calls(definitions, MyApp.Foo, "lib/my_app/foo.ex")

      assert length(calls) == 2

      enum_call = Enum.find(calls, &(&1.callee.function == "map"))
      capture_call = Enum.find(calls, &(&1.callee.function == "downcase"))

      assert enum_call.type == :remote
      assert enum_call.callee.module == "Enum"
      assert enum_call.callee.arity == 2

      assert capture_call.type == :remote
      assert capture_call.callee.module == "String"
      assert capture_call.callee.arity == 1
    end
  end
end
