defmodule ExAst.StdlibModulesTest do
  use ExUnit.Case, async: true

  alias ExAst.StdlibModules

  describe "stdlib_modules/0" do
    test "returns a MapSet" do
      result = StdlibModules.stdlib_modules()
      assert is_struct(result, MapSet)
    end

    test "returns non-empty set" do
      result = StdlibModules.stdlib_modules()
      assert MapSet.size(result) > 0
    end

    test "includes core Elixir collection modules" do
      modules = StdlibModules.stdlib_modules()

      assert MapSet.member?(modules, "Enum")
      assert MapSet.member?(modules, "Map")
      assert MapSet.member?(modules, "List")
      assert MapSet.member?(modules, "Keyword")
      assert MapSet.member?(modules, "String")
    end

    test "includes numeric type modules" do
      modules = StdlibModules.stdlib_modules()

      assert MapSet.member?(modules, "Integer")
      assert MapSet.member?(modules, "Float")
    end

    test "includes IO and file operation modules" do
      modules = StdlibModules.stdlib_modules()

      assert MapSet.member?(modules, "File")
      assert MapSet.member?(modules, "IO")
      assert MapSet.member?(modules, "Path")
    end

    test "includes concurrency modules" do
      modules = StdlibModules.stdlib_modules()

      assert MapSet.member?(modules, "Agent")
      assert MapSet.member?(modules, "Task")
      assert MapSet.member?(modules, "GenServer")
      assert MapSet.member?(modules, "Supervisor")
      assert MapSet.member?(modules, "Registry")
      assert MapSet.member?(modules, "Process")
    end

    test "includes system and runtime modules" do
      modules = StdlibModules.stdlib_modules()

      assert MapSet.member?(modules, "System")
      assert MapSet.member?(modules, "Code")
      assert MapSet.member?(modules, "Module")
      assert MapSet.member?(modules, "Application")
    end

    test "includes kernel and protocol modules" do
      modules = StdlibModules.stdlib_modules()

      assert MapSet.member?(modules, "Kernel")
      assert MapSet.member?(modules, "Protocol")
      assert MapSet.member?(modules, "Exception")
    end

    test "includes testing framework modules" do
      modules = StdlibModules.stdlib_modules()

      assert MapSet.member?(modules, "ExUnit")
      assert MapSet.member?(modules, "ExUnit.Case")
      assert MapSet.member?(modules, "ExUnit.Assertions")
    end

    test "includes logging modules" do
      modules = StdlibModules.stdlib_modules()

      assert MapSet.member?(modules, "Logger")
    end

    test "includes mix modules" do
      modules = StdlibModules.stdlib_modules()

      assert MapSet.member?(modules, "Mix")
      assert MapSet.member?(modules, "Mix.Project")
      assert MapSet.member?(modules, "Mix.Task")
    end

    test "is consistent across multiple calls" do
      result1 = StdlibModules.stdlib_modules()
      result2 = StdlibModules.stdlib_modules()

      assert result1 == result2
    end
  end

  describe "stdlib_module?/1" do
    test "returns true for stdlib modules" do
      assert StdlibModules.stdlib_module?("Enum")
      assert StdlibModules.stdlib_module?("String")
      assert StdlibModules.stdlib_module?("File")
      assert StdlibModules.stdlib_module?("Logger")
    end

    test "returns true for stdlib submodules" do
      assert StdlibModules.stdlib_module?("ExUnit.Case")
      assert StdlibModules.stdlib_module?("Mix.Task")
      assert StdlibModules.stdlib_module?("Logger.Formatter")
    end

    test "returns false for user-defined modules" do
      refute StdlibModules.stdlib_module?("MyApp")
      refute StdlibModules.stdlib_module?("MyApp.Utils")
      refute StdlibModules.stdlib_module?("MyApp.Foo.Bar")
    end

    test "returns false for empty string" do
      refute StdlibModules.stdlib_module?("")
    end

    test "returns false for unknown modules" do
      refute StdlibModules.stdlib_module?("UnknownModule")
      refute StdlibModules.stdlib_module?("FakeLib.Something")
    end

    test "is case-sensitive" do
      # Stdlib modules should be PascalCase
      assert StdlibModules.stdlib_module?("Enum")
      refute StdlibModules.stdlib_module?("enum")
      refute StdlibModules.stdlib_module?("ENUM")
    end

    test "handles modules with dots correctly" do
      # Submodules should be recognized if they're stdlib
      assert StdlibModules.stdlib_module?("Task.Supervisor")
      refute StdlibModules.stdlib_module?("Task.Unknown")
    end
  end

  describe "integration with CallFilter" do
    test "stdlib modules are recognized by CallFilter" do
      # Verify that the StdlibModules list is compatible with CallFilter
      alias ExAst.CallFilter

      # These should be considered stdlib modules
      refute CallFilter.should_include?(%{module: "Enum", function: "map", arity: 2})
      refute CallFilter.should_include?(%{module: "Logger", function: "info", arity: 1})

      # User modules should be included
      assert CallFilter.should_include?(%{module: "MyApp.Utils", function: "helper", arity: 1})
    end
  end
end
