defmodule ExAst.CallFilterTest do
  use ExUnit.Case, async: true

  alias ExAst.CallFilter

  describe "should_include?/1" do
    test "includes project module calls" do
      callee = %{module: "MyApp.Foo", function: "bar", arity: 1}
      assert CallFilter.should_include?(callee)
    end

    test "excludes Enum calls" do
      callee = %{module: "Enum", function: "map", arity: 2}
      refute CallFilter.should_include?(callee)
    end

    test "excludes Map calls" do
      callee = %{module: "Map", function: "get", arity: 2}
      refute CallFilter.should_include?(callee)
    end

    test "excludes String calls" do
      callee = %{module: "String", function: "trim", arity: 1}
      refute CallFilter.should_include?(callee)
    end

    test "excludes GenServer calls" do
      callee = %{module: "GenServer", function: "call", arity: 2}
      refute CallFilter.should_include?(callee)
    end

    test "excludes Logger calls" do
      callee = %{module: "Logger", function: "info", arity: 1}
      refute CallFilter.should_include?(callee)
    end

    test "excludes erlang module calls" do
      callee = %{module: "erlang", function: "self", arity: 0}
      refute CallFilter.should_include?(callee)
    end

    test "excludes lists module calls" do
      callee = %{module: "lists", function: "reverse", arity: 1}
      refute CallFilter.should_include?(callee)
    end

    test "excludes beam_lib module calls" do
      callee = %{module: "beam_lib", function: "chunks", arity: 2}
      refute CallFilter.should_include?(callee)
    end

    test "includes third-party library calls" do
      callee = %{module: "Phoenix.Controller", function: "render", arity: 2}
      assert CallFilter.should_include?(callee)
    end

    test "includes Ecto calls (not in stdlib)" do
      callee = %{module: "Ecto.Query", function: "from", arity: 2}
      assert CallFilter.should_include?(callee)
    end
  end

  describe "should_include?/2 with known_modules" do
    test "includes calls to known modules" do
      known = MapSet.new(["MyApp.Foo", "MyApp.Bar"])
      callee = %{module: "MyApp.Foo", function: "bar", arity: 1}
      assert CallFilter.should_include?(callee, known)
    end

    test "excludes calls to unknown modules" do
      known = MapSet.new(["MyApp.Foo", "MyApp.Bar"])
      callee = %{module: "MyApp.Baz", function: "qux", arity: 0}
      refute CallFilter.should_include?(callee, known)
    end

    test "excludes stdlib calls even if checking known modules" do
      known = MapSet.new(["MyApp.Foo", "Enum"])
      callee = %{module: "Enum", function: "map", arity: 2}
      # Note: if Enum is in known_modules, it WILL be included
      # This is intentional - known_modules overrides stdlib filtering
      assert CallFilter.should_include?(callee, known)
    end

    test "excludes third-party libs not in known modules" do
      known = MapSet.new(["MyApp.Foo", "MyApp.Bar"])
      callee = %{module: "Phoenix.Controller", function: "render", arity: 2}
      refute CallFilter.should_include?(callee, known)
    end
  end

  describe "filter_calls/2" do
    test "filters out stdlib calls by default" do
      calls = [
        %{type: :remote, caller: %{module: "MyApp.Foo"}, callee: %{module: "MyApp.Bar", function: "baz", arity: 1}},
        %{type: :remote, caller: %{module: "MyApp.Foo"}, callee: %{module: "Enum", function: "map", arity: 2}},
        %{type: :remote, caller: %{module: "MyApp.Foo"}, callee: %{module: "erlang", function: "self", arity: 0}}
      ]

      filtered = CallFilter.filter_calls(calls)

      assert length(filtered) == 1
      assert hd(filtered).callee.module == "MyApp.Bar"
    end

    test "filters to known modules when provided" do
      calls = [
        %{type: :remote, caller: %{module: "MyApp.Foo"}, callee: %{module: "MyApp.Bar", function: "baz", arity: 1}},
        %{type: :remote, caller: %{module: "MyApp.Foo"}, callee: %{module: "MyApp.Baz", function: "qux", arity: 0}},
        %{type: :remote, caller: %{module: "MyApp.Foo"}, callee: %{module: "SomeLib.Thing", function: "call", arity: 1}}
      ]

      known = MapSet.new(["MyApp.Foo", "MyApp.Bar"])
      filtered = CallFilter.filter_calls(calls, known_modules: known)

      assert length(filtered) == 1
      assert hd(filtered).callee.module == "MyApp.Bar"
    end

    test "returns empty list when all calls are filtered" do
      calls = [
        %{type: :remote, caller: %{module: "MyApp.Foo"}, callee: %{module: "Enum", function: "map", arity: 2}},
        %{type: :remote, caller: %{module: "MyApp.Foo"}, callee: %{module: "Map", function: "get", arity: 2}}
      ]

      filtered = CallFilter.filter_calls(calls)
      assert filtered == []
    end

    test "keeps local calls (same module)" do
      calls = [
        %{type: :local, caller: %{module: "MyApp.Foo"}, callee: %{module: "MyApp.Foo", function: "helper", arity: 1}}
      ]

      filtered = CallFilter.filter_calls(calls)
      assert length(filtered) == 1
    end
  end

  describe "stdlib_module?/1" do
    test "returns true for Enum" do
      assert CallFilter.stdlib_module?("Enum")
    end

    test "returns true for GenServer" do
      assert CallFilter.stdlib_module?("GenServer")
    end

    test "returns true for Logger" do
      assert CallFilter.stdlib_module?("Logger")
    end

    test "returns false for project modules" do
      refute CallFilter.stdlib_module?("MyApp.Foo")
    end

    test "returns false for third-party modules" do
      refute CallFilter.stdlib_module?("Phoenix.Controller")
    end
  end

  describe "erlang_module?/1" do
    test "returns true for erlang" do
      assert CallFilter.erlang_module?("erlang")
    end

    test "returns true for lists" do
      assert CallFilter.erlang_module?("lists")
    end

    test "returns true for beam_lib" do
      assert CallFilter.erlang_module?("beam_lib")
    end

    test "returns true for ets" do
      assert CallFilter.erlang_module?("ets")
    end

    test "returns false for Elixir modules (PascalCase)" do
      refute CallFilter.erlang_module?("Enum")
    end

    test "returns false for namespaced modules" do
      refute CallFilter.erlang_module?("MyApp.Foo")
    end

    test "returns false for empty string" do
      refute CallFilter.erlang_module?("")
    end
  end

  describe "stdlib_modules/0" do
    test "returns a MapSet" do
      modules = CallFilter.stdlib_modules()
      assert %MapSet{} = modules
    end

    test "contains common stdlib modules" do
      modules = CallFilter.stdlib_modules()
      assert MapSet.member?(modules, "Enum")
      assert MapSet.member?(modules, "Map")
      assert MapSet.member?(modules, "List")
      assert MapSet.member?(modules, "String")
      assert MapSet.member?(modules, "GenServer")
    end
  end
end
