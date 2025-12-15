defmodule ExAst.BuildDiscoveryTest do
  use ExUnit.Case, async: true

  alias ExAst.BuildDiscovery

  describe "find_build_dir/2" do
    test "finds build dir for valid project" do
      # Use this project's own build directory
      project_path = File.cwd!()

      assert {:ok, build_lib_path} = BuildDiscovery.find_build_dir(project_path, "dev")
      assert String.ends_with?(build_lib_path, "_build/dev/lib")
      assert File.dir?(build_lib_path)
    end

    test "returns error for missing build directory" do
      assert {:error, message} = BuildDiscovery.find_build_dir("/nonexistent/path", "dev")
      assert message =~ "Build directory not found"
      assert message =~ "mix compile"
    end

    test "returns error for wrong environment" do
      project_path = File.cwd!()

      assert {:error, message} = BuildDiscovery.find_build_dir(project_path, "nonexistent_env")
      assert message =~ "Build directory not found"
    end
  end

  describe "list_app_directories/1" do
    test "lists all app directories in build" do
      project_path = File.cwd!()
      {:ok, build_lib_path} = BuildDiscovery.find_build_dir(project_path, "dev")

      apps = BuildDiscovery.list_app_directories(build_lib_path)

      assert is_list(apps)
      # Our own app should be in the list
      assert Enum.any?(apps, fn {app_name, _path} -> app_name == "ex_ast" end)

      # Each entry should have a valid ebin path
      Enum.each(apps, fn {app_name, ebin_path} ->
        assert is_binary(app_name)
        assert String.ends_with?(ebin_path, "ebin")
        assert File.dir?(ebin_path)
      end)
    end

    test "returns empty list for nonexistent path" do
      assert [] = BuildDiscovery.list_app_directories("/nonexistent/path")
    end

    test "returns empty list for empty directory" do
      tmp_dir = System.tmp_dir!()
      empty_dir = Path.join(tmp_dir, "empty_build_test_#{:rand.uniform(1000)}")
      File.mkdir_p!(empty_dir)

      try do
        assert [] = BuildDiscovery.list_app_directories(empty_dir)
      after
        File.rm_rf!(empty_dir)
      end
    end

    test "skips directories without ebin" do
      tmp_dir = System.tmp_dir!()
      test_dir = Path.join(tmp_dir, "build_test_#{:rand.uniform(1000)}")

      # Create a fake app directory without ebin
      fake_app_dir = Path.join(test_dir, "fake_app")
      File.mkdir_p!(fake_app_dir)

      # Create a real app directory with ebin
      real_app_dir = Path.join(test_dir, "real_app")
      real_ebin = Path.join(real_app_dir, "ebin")
      File.mkdir_p!(real_ebin)

      try do
        apps = BuildDiscovery.list_app_directories(test_dir)

        assert length(apps) == 1
        assert [{"real_app", _}] = apps
      after
        File.rm_rf!(test_dir)
      end
    end
  end

  describe "detect_project_type/1" do
    test "detects regular project" do
      # This project is a regular project
      project_path = File.cwd!()
      assert :regular = BuildDiscovery.detect_project_type(project_path)
    end

    test "detects umbrella project" do
      tmp_dir = System.tmp_dir!()
      umbrella_dir = Path.join(tmp_dir, "umbrella_test_#{:rand.uniform(1000)}")

      # Create umbrella structure
      app_one_dir = Path.join([umbrella_dir, "apps", "app_one"])
      app_two_dir = Path.join([umbrella_dir, "apps", "app_two"])
      File.mkdir_p!(app_one_dir)
      File.mkdir_p!(app_two_dir)

      # Create mix.exs files in each app
      File.write!(Path.join(app_one_dir, "mix.exs"), """
      defmodule AppOne.MixProject do
        use Mix.Project
        def project do
          [app: :app_one, version: "0.1.0"]
        end
      end
      """)

      File.write!(Path.join(app_two_dir, "mix.exs"), """
      defmodule AppTwo.MixProject do
        use Mix.Project
        def project do
          [app: :app_two, version: "0.1.0"]
        end
      end
      """)

      try do
        assert :umbrella = BuildDiscovery.detect_project_type(umbrella_dir)
      after
        File.rm_rf!(umbrella_dir)
      end
    end

    test "returns regular for apps dir without mix.exs files" do
      tmp_dir = System.tmp_dir!()
      fake_umbrella_dir = Path.join(tmp_dir, "fake_umbrella_#{:rand.uniform(1000)}")

      # Create apps dir with subdirectories but no mix.exs
      app_dir = Path.join([fake_umbrella_dir, "apps", "some_app"])
      File.mkdir_p!(app_dir)

      try do
        assert :regular = BuildDiscovery.detect_project_type(fake_umbrella_dir)
      after
        File.rm_rf!(fake_umbrella_dir)
      end
    end

    test "returns regular for nonexistent path" do
      assert :regular = BuildDiscovery.detect_project_type("/nonexistent/path")
    end
  end

  describe "find_project_apps/1" do
    test "finds app name for regular project" do
      project_path = File.cwd!()
      assert {:ok, ["ex_ast"]} = BuildDiscovery.find_project_apps(project_path)
    end

    test "finds all app names for umbrella project" do
      tmp_dir = System.tmp_dir!()
      umbrella_dir = Path.join(tmp_dir, "umbrella_apps_test_#{:rand.uniform(1000)}")

      # Create umbrella structure
      app_one_dir = Path.join([umbrella_dir, "apps", "app_one"])
      app_two_dir = Path.join([umbrella_dir, "apps", "app_two"])
      File.mkdir_p!(app_one_dir)
      File.mkdir_p!(app_two_dir)

      File.write!(Path.join(app_one_dir, "mix.exs"), """
      defmodule AppOne.MixProject do
        use Mix.Project
        def project do
          [app: :app_one, version: "0.1.0"]
        end
      end
      """)

      File.write!(Path.join(app_two_dir, "mix.exs"), """
      defmodule AppTwo.MixProject do
        use Mix.Project
        def project do
          [app: :app_two, version: "0.1.0"]
        end
      end
      """)

      try do
        assert {:ok, apps} = BuildDiscovery.find_project_apps(umbrella_dir)
        assert length(apps) == 2
        assert "app_one" in apps
        assert "app_two" in apps
      after
        File.rm_rf!(umbrella_dir)
      end
    end

    test "returns error for missing mix.exs" do
      tmp_dir = System.tmp_dir!()
      empty_dir = Path.join(tmp_dir, "no_mix_test_#{:rand.uniform(1000)}")
      File.mkdir_p!(empty_dir)

      try do
        assert {:error, message} = BuildDiscovery.find_project_apps(empty_dir)
        assert message =~ "Failed to read"
      after
        File.rm_rf!(empty_dir)
      end
    end
  end

  describe "parse_app_name/1" do
    test "parses app name from mix.exs" do
      project_path = File.cwd!()
      mix_exs_path = Path.join(project_path, "mix.exs")

      assert {:ok, "ex_ast"} = BuildDiscovery.parse_app_name(mix_exs_path)
    end

    test "returns error for nonexistent file" do
      assert {:error, message} = BuildDiscovery.parse_app_name("/nonexistent/mix.exs")
      assert message =~ "Failed to read"
    end

    test "returns error for file without app name" do
      tmp_dir = System.tmp_dir!()
      bad_mix = Path.join(tmp_dir, "bad_mix_#{:rand.uniform(1000)}.exs")
      File.write!(bad_mix, "# empty file")

      try do
        assert {:error, message} = BuildDiscovery.parse_app_name(bad_mix)
        assert message =~ "Could not find app name"
      after
        File.rm!(bad_mix)
      end
    end
  end

  describe "find_beam_files/1" do
    test "finds BEAM files in populated ebin" do
      project_path = File.cwd!()
      {:ok, build_lib_path} = BuildDiscovery.find_build_dir(project_path, "dev")
      ebin_path = Path.join([build_lib_path, "ex_ast", "ebin"])

      beam_files = BuildDiscovery.find_beam_files(ebin_path)

      assert is_list(beam_files)
      assert length(beam_files) > 0

      # All files should be absolute paths ending in .beam
      Enum.each(beam_files, fn path ->
        assert String.ends_with?(path, ".beam")
        assert Path.type(path) == :absolute
      end)

      # Should include our main module
      assert Enum.any?(beam_files, &String.contains?(&1, "Elixir.ExAst"))
    end

    test "returns empty list for empty directory" do
      tmp_dir = System.tmp_dir!()
      empty_ebin = Path.join(tmp_dir, "empty_ebin_#{:rand.uniform(1000)}")
      File.mkdir_p!(empty_ebin)

      try do
        assert [] = BuildDiscovery.find_beam_files(empty_ebin)
      after
        File.rm_rf!(empty_ebin)
      end
    end

    test "returns empty list for nonexistent directory" do
      assert [] = BuildDiscovery.find_beam_files("/nonexistent/ebin/path")
    end

    test "only returns Elixir modules (Elixir.*.beam)" do
      tmp_dir = System.tmp_dir!()
      test_ebin = Path.join(tmp_dir, "test_ebin_#{:rand.uniform(1000)}")
      File.mkdir_p!(test_ebin)

      # Create an Elixir module BEAM file
      elixir_beam = Path.join(test_ebin, "Elixir.MyModule.beam")
      File.write!(elixir_beam, "fake beam content")

      # Create an Erlang module BEAM file (no Elixir. prefix)
      erlang_beam = Path.join(test_ebin, "my_erlang_module.beam")
      File.write!(erlang_beam, "fake beam content")

      try do
        beam_files = BuildDiscovery.find_beam_files(test_ebin)

        assert length(beam_files) == 1
        assert Enum.any?(beam_files, &String.contains?(&1, "Elixir.MyModule.beam"))
        refute Enum.any?(beam_files, &String.contains?(&1, "my_erlang_module.beam"))
      after
        File.rm_rf!(test_ebin)
      end
    end
  end
end
