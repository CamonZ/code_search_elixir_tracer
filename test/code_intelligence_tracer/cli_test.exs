defmodule CodeIntelligenceTracer.CLITest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.CLI

  describe "parse_args/1" do
    test "empty args returns defaults" do
      assert {:ok, options} = CLI.parse_args([])

      assert options.output == "call_graph.json"
      assert options.format == "json"
      assert options.include_deps == false
      assert options.deps == []
      assert options.env == "dev"
      assert options.path == "."
    end

    test "parse -o sets output" do
      assert {:ok, options} = CLI.parse_args(["-o", "custom.json"])
      assert options.output == "custom.json"
    end

    test "parse --output sets output" do
      assert {:ok, options} = CLI.parse_args(["--output", "custom.json"])
      assert options.output == "custom.json"
    end

    test "parse -f toon sets format" do
      assert {:ok, options} = CLI.parse_args(["-f", "toon"])
      assert options.format == "toon"
    end

    test "parse --format json sets format" do
      assert {:ok, options} = CLI.parse_args(["--format", "json"])
      assert options.format == "json"
    end

    test "parse -d sets include_deps flag" do
      assert {:ok, options} = CLI.parse_args(["-d"])
      assert options.include_deps == true
    end

    test "parse --include-deps sets flag" do
      assert {:ok, options} = CLI.parse_args(["--include-deps"])
      assert options.include_deps == true
    end

    test "parse --deps creates list" do
      assert {:ok, options} = CLI.parse_args(["--deps", "a,b,c"])
      assert options.deps == ["a", "b", "c"]
    end

    test "parse --deps trims whitespace" do
      assert {:ok, options} = CLI.parse_args(["--deps", "a, b, c"])
      assert options.deps == ["a", "b", "c"]
    end

    test "parse -e sets env" do
      assert {:ok, options} = CLI.parse_args(["-e", "prod"])
      assert options.env == "prod"
    end

    test "parse --env sets env" do
      assert {:ok, options} = CLI.parse_args(["--env", "test"])
      assert options.env == "test"
    end

    test "parse -h sets help flag" do
      assert {:ok, options} = CLI.parse_args(["-h"])
      assert options.help == true
    end

    test "parse --help sets help flag" do
      assert {:ok, options} = CLI.parse_args(["--help"])
      assert options.help == true
    end

    test "parse positional path works" do
      assert {:ok, options} = CLI.parse_args(["/path/to/project"])
      assert options.path == "/path/to/project"
    end

    test "parse positional path with options" do
      assert {:ok, options} = CLI.parse_args(["-o", "out.json", "/my/project"])
      assert options.path == "/my/project"
      assert options.output == "out.json"
    end

    test "error when both --include-deps and --deps provided" do
      assert {:error, message} = CLI.parse_args(["--include-deps", "--deps", "a,b"])
      assert message =~ "mutually exclusive"
    end

    test "error for invalid format value" do
      assert {:error, message} = CLI.parse_args(["--format", "xml"])
      assert message =~ "Invalid format"
      assert message =~ "xml"
    end

    test "error for unknown option" do
      assert {:error, message} = CLI.parse_args(["--unknown"])
      assert message =~ "Invalid option"
    end

    test "multiple options combined" do
      args = ["-o", "output.json", "-f", "toon", "-e", "prod", "/project"]
      assert {:ok, options} = CLI.parse_args(args)

      assert options.output == "output.json"
      assert options.format == "toon"
      assert options.env == "prod"
      assert options.path == "/project"
    end
  end

  describe "print_help/0" do
    test "prints usage information" do
      output = capture_io(fn -> CLI.print_help() end)

      assert output =~ "Usage: call_graph"
      assert output =~ "--output"
      assert output =~ "--format"
      assert output =~ "--include-deps"
      assert output =~ "--deps"
      assert output =~ "--env"
      assert output =~ "--help"
    end
  end

  defp capture_io(fun), do: ExUnit.CaptureIO.capture_io(fun)
end
