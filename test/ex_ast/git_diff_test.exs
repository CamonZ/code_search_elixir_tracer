defmodule ExAst.GitDiffTest do
  use ExUnit.Case, async: false

  alias ExAst.GitDiff

  setup do
    # Create unique test directory in system temp
    test_dir = Path.join(System.tmp_dir!(), "ex_ast_git_diff_test_#{:rand.uniform(100000)}")

    # Clean up any existing test directory
    File.rm_rf!(test_dir)
    File.mkdir_p!(test_dir)

    # Initialize git repo
    System.cmd("git", ["init"], cd: test_dir)
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: test_dir)
    System.cmd("git", ["config", "user.name", "Test User"], cd: test_dir)

    on_exit(fn ->
      File.rm_rf!(test_dir)
    end)

    {:ok, test_dir: test_dir}
  end

  describe "extract_modules_from_file/1" do
    test "extracts single module from .ex file", %{test_dir: test_dir} do
      file_path = Path.join([test_dir, "lib", "foo.ex"])
      File.mkdir_p!(Path.dirname(file_path))

      File.write!(file_path, """
      defmodule Foo do
        def hello, do: "foo"
      end
      """)

      assert GitDiff.extract_modules_from_file(file_path) == [Foo]
    end

    test "extracts multiple modules from single .ex file", %{test_dir: test_dir} do
      file_path = Path.join([test_dir, "lib", "multi.ex"])
      File.mkdir_p!(Path.dirname(file_path))

      File.write!(file_path, """
      defmodule Foo.Bar do
        def hello, do: "bar"
      end

      defmodule Foo.Baz do
        def hello, do: "baz"
      end
      """)

      assert GitDiff.extract_modules_from_file(file_path) == [Foo.Bar, Foo.Baz]
    end

    test "handles nested module names", %{test_dir: test_dir} do
      file_path = Path.join([test_dir, "lib", "nested.ex"])
      File.mkdir_p!(Path.dirname(file_path))

      File.write!(file_path, """
      defmodule MyApp.Deeply.Nested.Module do
        def hello, do: "nested"
      end
      """)

      assert GitDiff.extract_modules_from_file(file_path) == [MyApp.Deeply.Nested.Module]
    end

    test "returns empty list for non-existent file" do
      assert GitDiff.extract_modules_from_file("/nonexistent/file.ex") == []
    end

    test "falls back to regex for files with syntax errors", %{test_dir: test_dir} do
      file_path = Path.join([test_dir, "lib", "syntax_error.ex"])
      File.mkdir_p!(Path.dirname(file_path))

      # Invalid syntax but valid defmodule declaration
      File.write!(file_path, """
      defmodule SyntaxError do
        def hello, do "missing colon"
      end
      """)

      # Should still extract module using regex fallback
      assert GitDiff.extract_modules_from_file(file_path) == [SyntaxError]
    end
  end

  describe "get_changed_ex_files/2" do
    test "returns .ex files from git diff", %{test_dir: test_dir} do
      # Create initial files
      lib_dir = Path.join(test_dir, "lib")
      File.mkdir_p!(lib_dir)

      File.write!(Path.join(lib_dir, "a.ex"), "defmodule A, do: nil")
      File.write!(Path.join(lib_dir, "b.ex"), "defmodule B, do: nil")
      File.write!(Path.join(lib_dir, "readme.md"), "# README")

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Initial commit"], cd: test_dir)

      # Modify one .ex file and add one new .ex file
      File.write!(Path.join(lib_dir, "a.ex"), "defmodule A, do: :changed")
      File.write!(Path.join(lib_dir, "c.ex"), "defmodule C, do: nil")
      File.write!(Path.join(lib_dir, "readme.md"), "# CHANGED")

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Update files"], cd: test_dir)

      # Get changed files in last commit
      assert {:ok, files} = GitDiff.get_changed_ex_files("HEAD~1", test_dir)
      assert Enum.sort(files) == ["lib/a.ex", "lib/c.ex"]
    end

    test "returns staged .ex files with --staged", %{test_dir: test_dir} do
      lib_dir = Path.join(test_dir, "lib")
      File.mkdir_p!(lib_dir)

      File.write!(Path.join(lib_dir, "initial.ex"), "defmodule Initial, do: nil")
      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Initial"], cd: test_dir)

      # Stage some changes
      File.write!(Path.join(lib_dir, "staged.ex"), "defmodule Staged, do: nil")
      File.write!(Path.join(lib_dir, "not_staged.ex"), "defmodule NotStaged, do: nil")

      System.cmd("git", ["add", "lib/staged.ex"], cd: test_dir)

      assert {:ok, files} = GitDiff.get_changed_ex_files("--staged", test_dir)
      assert files == ["lib/staged.ex"]
    end

    test "returns empty list when no .ex files changed", %{test_dir: test_dir} do
      File.mkdir_p!(Path.join(test_dir, "lib"))
      File.write!(Path.join(test_dir, "README.md"), "# README")

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Add readme"], cd: test_dir)

      File.write!(Path.join(test_dir, "README.md"), "# CHANGED")
      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Update readme"], cd: test_dir)

      assert {:ok, files} = GitDiff.get_changed_ex_files("HEAD~1", test_dir)
      assert files == []
    end

    test "returns error for invalid git ref", %{test_dir: test_dir} do
      assert {:error, error_msg} = GitDiff.get_changed_ex_files("invalid-ref", test_dir)
      assert error_msg =~ "Git command failed"
    end
  end

  describe "get_beam_files_for_diff/3" do
    setup %{test_dir: test_dir} do
      # Set up a mini mix project
      lib_dir = Path.join(test_dir, "lib")
      build_dir = Path.join(test_dir, "_build/dev/lib/test_app/ebin")
      File.mkdir_p!(lib_dir)
      File.mkdir_p!(build_dir)

      # Create mix.exs
      File.write!(Path.join(test_dir, "mix.exs"), """
      defmodule TestApp.MixProject do
        use Mix.Project
        def project do
          [app: :test_app, version: "0.1.0"]
        end
      end
      """)

      {:ok, lib_dir: lib_dir, build_dir: build_dir}
    end

    test "returns BEAM files when they exist and are current", %{
      test_dir: test_dir,
      lib_dir: lib_dir,
      build_dir: build_dir
    } do
      # Create and commit initial file
      ex_file = Path.join(lib_dir, "foo.ex")

      File.write!(ex_file, """
      defmodule Foo do
        def hello, do: "foo"
      end
      """)

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Add foo"], cd: test_dir)

      # Create BEAM file with future timestamp (2 seconds ahead)
      beam_file = Path.join(build_dir, "Elixir.Foo.beam")
      File.write!(beam_file, "fake beam content")

      future_time = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time()) + 2
      future_datetime = :calendar.gregorian_seconds_to_datetime(future_time)
      File.touch!(beam_file, future_datetime)

      # Change the file
      File.write!(ex_file, """
      defmodule Foo do
        def hello, do: "changed"
      end
      """)

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Change foo"], cd: test_dir)

      # BEAM should still be valid since it's newer
      assert {:ok, [^beam_file]} =
               GitDiff.get_beam_files_for_diff(
                 "HEAD~1",
                 Path.join(test_dir, "_build/dev"),
                 test_dir
               )
    end

    test "returns error when BEAM file is missing", %{
      test_dir: test_dir,
      lib_dir: lib_dir
    } do
      ex_file = Path.join(lib_dir, "missing.ex")

      File.write!(ex_file, """
      defmodule Missing do
        def hello, do: "missing"
      end
      """)

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Add missing"], cd: test_dir)

      File.write!(ex_file, """
      defmodule Missing do
        def hello, do: "changed"
      end
      """)

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Change missing"], cd: test_dir)

      # No BEAM file exists
      assert {:error, {:compilation_required, error_msg}} =
               GitDiff.get_beam_files_for_diff(
                 "HEAD~1",
                 Path.join(test_dir, "_build/dev"),
                 test_dir
               )

      assert error_msg =~ "Compilation required"
      assert error_msg =~ "lib/missing.ex"
      assert error_msg =~ "Elixir.Missing.beam (missing)"
      assert error_msg =~ "mix compile"
    end

    test "returns error when source is newer than BEAM", %{
      test_dir: test_dir,
      lib_dir: lib_dir,
      build_dir: build_dir
    } do
      ex_file = Path.join(lib_dir, "outdated.ex")

      File.write!(ex_file, """
      defmodule Outdated do
        def hello, do: "old"
      end
      """)

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Add outdated"], cd: test_dir)

      # Create BEAM file with a fixed old timestamp
      beam_file = Path.join(build_dir, "Elixir.Outdated.beam")
      File.write!(beam_file, "fake beam content")

      # Set BEAM file mtime to 2 seconds in the past
      old_time = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time()) - 2
      old_datetime = :calendar.gregorian_seconds_to_datetime(old_time)
      File.touch!(beam_file, old_datetime)

      # Wait a bit to ensure filesystem timestamps are distinct
      :timer.sleep(100)

      # Now modify source
      File.write!(ex_file, """
      defmodule Outdated do
        def hello, do: "new"
      end
      """)

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Change outdated"], cd: test_dir)

      assert {:error, {:compilation_required, error_msg}} =
               GitDiff.get_beam_files_for_diff(
                 "HEAD~1",
                 Path.join(test_dir, "_build/dev"),
                 test_dir
               )

      assert error_msg =~ "Compilation required"
      assert error_msg =~ "lib/outdated.ex"
      assert error_msg =~ "Elixir.Outdated.beam (outdated"
      assert error_msg =~ "mix compile"
    end

    test "handles multiple modules in single file", %{
      test_dir: test_dir,
      lib_dir: lib_dir,
      build_dir: build_dir
    } do
      ex_file = Path.join(lib_dir, "multi.ex")

      File.write!(ex_file, """
      defmodule Multi.One do
        def hello, do: "one"
      end

      defmodule Multi.Two do
        def hello, do: "two"
      end
      """)

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Add multi"], cd: test_dir)

      # Create both BEAM files with future timestamp
      beam_one = Path.join(build_dir, "Elixir.Multi.One.beam")
      beam_two = Path.join(build_dir, "Elixir.Multi.Two.beam")
      File.write!(beam_one, "fake beam one")
      File.write!(beam_two, "fake beam two")

      future_time = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time()) + 2
      future_datetime = :calendar.gregorian_seconds_to_datetime(future_time)
      File.touch!(beam_one, future_datetime)
      File.touch!(beam_two, future_datetime)

      File.write!(ex_file, """
      defmodule Multi.One do
        def hello, do: "changed one"
      end

      defmodule Multi.Two do
        def hello, do: "changed two"
      end
      """)

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Change multi"], cd: test_dir)

      assert {:ok, beam_files} =
               GitDiff.get_beam_files_for_diff(
                 "HEAD~1",
                 Path.join(test_dir, "_build/dev"),
                 test_dir
               )

      assert Enum.sort(beam_files) == Enum.sort([beam_one, beam_two])
    end

    test "handles files in subdirectories", %{
      test_dir: test_dir,
      lib_dir: lib_dir,
      build_dir: build_dir
    } do
      sub_dir = Path.join(lib_dir, "sub")
      File.mkdir_p!(sub_dir)

      ex_file = Path.join(sub_dir, "nested.ex")

      File.write!(ex_file, """
      defmodule Nested do
        def hello, do: "nested"
      end
      """)

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Add nested"], cd: test_dir)

      # Create BEAM file with future timestamp
      beam_file = Path.join(build_dir, "Elixir.Nested.beam")
      File.write!(beam_file, "fake beam nested")

      future_time = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time()) + 2
      future_datetime = :calendar.gregorian_seconds_to_datetime(future_time)
      File.touch!(beam_file, future_datetime)

      File.write!(ex_file, """
      defmodule Nested do
        def hello, do: "changed nested"
      end
      """)

      System.cmd("git", ["add", "."], cd: test_dir)
      System.cmd("git", ["commit", "-m", "Change nested"], cd: test_dir)

      assert {:ok, [^beam_file]} =
               GitDiff.get_beam_files_for_diff(
                 "HEAD~1",
                 Path.join(test_dir, "_build/dev"),
                 test_dir
               )
    end
  end
end
