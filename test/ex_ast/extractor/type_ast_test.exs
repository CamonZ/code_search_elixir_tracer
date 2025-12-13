defmodule ExAst.Extractor.TypeAstTest do
  use ExUnit.Case, async: true

  alias ExAst.Extractor.TypeAst

  describe "parse/1" do
    test "parses builtin types" do
      assert TypeAst.parse({:type, {1, 1}, :integer, []}) ==
               %{type: :builtin, name: :integer}

      assert TypeAst.parse({:type, {1, 1}, :binary, []}) ==
               %{type: :builtin, name: :binary}

      assert TypeAst.parse({:type, {1, 1}, :atom, []}) ==
               %{type: :builtin, name: :atom}

      assert TypeAst.parse({:type, {1, 1}, :term, []}) ==
               %{type: :builtin, name: :term}

      assert TypeAst.parse({:type, {1, 1}, :any, []}) ==
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

      result = TypeAst.parse(union_ast)

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

      result = TypeAst.parse(tuple_ast)

      assert result == %{
               type: :tuple,
               elements: [
                 %{type: :builtin, name: :atom},
                 %{type: :builtin, name: :integer}
               ]
             }
    end

    test "parses any tuple" do
      result = TypeAst.parse({:type, {1, 1}, :tuple, :any})
      assert result == %{type: :tuple, elements: :any}
    end

    test "parses list types" do
      # [integer]
      list_ast = {:type, {1, 1}, :list, [{:type, {1, 2}, :integer, []}]}

      result = TypeAst.parse(list_ast)

      assert result == %{
               type: :list,
               element_type: %{type: :builtin, name: :integer}
             }
    end

    test "parses empty list type" do
      result = TypeAst.parse({:type, {1, 1}, :list, []})
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

      result = TypeAst.parse(map_ast)

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
      result = TypeAst.parse({:type, {1, 1}, :map, :any})
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

      result = TypeAst.parse(remote_ast)

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

      result = TypeAst.parse(user_type_ast)

      assert result == %{
               type: :type_ref,
               module: nil,
               name: :t,
               args: []
             }
    end

    test "parses atom literals" do
      result = TypeAst.parse({:atom, {1, 1}, :ok})
      assert result == %{type: :literal, kind: :atom, value: :ok}
    end

    test "parses integer literals" do
      result = TypeAst.parse({:integer, {1, 1}, 42})
      assert result == %{type: :literal, kind: :integer, value: 42}
    end

    test "parses type variables" do
      result = TypeAst.parse({:var, {1, 1}, :a})
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

      result = TypeAst.parse(fun_ast)

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

      result = TypeAst.parse(ann_ast)

      # Annotated types strip the name and return the underlying type
      assert result == %{type: :builtin, name: :integer}
    end

    test "parses builtin types with args" do
      # nonempty_list(integer)
      ast = {:type, {1, 1}, :nonempty_list, [{:type, {1, 15}, :integer, []}]}

      result = TypeAst.parse(ast)

      assert result == %{
               type: :builtin,
               name: :nonempty_list,
               args: [%{type: :builtin, name: :integer}]
             }
    end
  end

  describe "format/1" do
    test "formats builtin types" do
      assert TypeAst.format(%{type: :builtin, name: :integer}) == "integer()"
      assert TypeAst.format(%{type: :builtin, name: :binary}) == "binary()"
      assert TypeAst.format(%{type: :builtin, name: :atom}) == "atom()"
      assert TypeAst.format(%{type: :builtin, name: :term}) == "term()"
    end

    test "formats builtin types with args" do
      ast = %{type: :builtin, name: :nonempty_list, args: [%{type: :builtin, name: :integer}]}
      assert TypeAst.format(ast) == "nonempty_list(integer())"
    end

    test "formats atom literals" do
      assert TypeAst.format(%{type: :literal, kind: :atom, value: :ok}) == ":ok"
      assert TypeAst.format(%{type: :literal, kind: :atom, value: :error}) == ":error"
    end

    test "formats integer literals" do
      assert TypeAst.format(%{type: :literal, kind: :integer, value: 42}) == "42"
    end

    test "formats local type refs" do
      assert TypeAst.format(%{type: :type_ref, module: nil, name: :t, args: []}) == "t()"

      ast = %{
        type: :type_ref,
        module: nil,
        name: :option,
        args: [%{type: :builtin, name: :integer}]
      }

      assert TypeAst.format(ast) == "option(integer())"
    end

    test "formats remote type refs" do
      assert TypeAst.format(%{
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

      assert TypeAst.format(ast) == "GenServer.on_start()"
    end

    test "formats union types" do
      ast = %{
        type: :union,
        types: [
          %{type: :builtin, name: :integer},
          %{type: :builtin, name: :atom}
        ]
      }

      assert TypeAst.format(ast) == "integer() | atom()"
    end

    test "formats tuple types" do
      ast = %{
        type: :tuple,
        elements: [
          %{type: :literal, kind: :atom, value: :ok},
          %{type: :builtin, name: :integer}
        ]
      }

      assert TypeAst.format(ast) == "{:ok, integer()}"
    end

    test "formats any tuple" do
      assert TypeAst.format(%{type: :tuple, elements: :any}) == "tuple()"
    end

    test "formats list types" do
      ast = %{type: :list, element_type: %{type: :builtin, name: :integer}}
      assert TypeAst.format(ast) == "[integer()]"
    end

    test "formats empty list type" do
      assert TypeAst.format(%{type: :list, element_type: nil}) == "list()"
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

      assert TypeAst.format(ast) == "%{name: String.t()}"
    end

    test "formats any map" do
      assert TypeAst.format(%{type: :map, fields: :any}) == "map()"
    end

    test "formats function types" do
      ast = %{
        type: :fun,
        inputs: [%{type: :builtin, name: :integer}],
        return: %{type: :builtin, name: :atom}
      }

      assert TypeAst.format(ast) == "(integer() -> atom())"
    end

    test "formats type variables" do
      assert TypeAst.format(%{type: :var, name: :a}) == "a"
      assert TypeAst.format(%{type: :var, name: :T}) == "T"
    end

    test "formats any type" do
      assert TypeAst.format(%{type: :any}) == "any()"
    end
  end
end
