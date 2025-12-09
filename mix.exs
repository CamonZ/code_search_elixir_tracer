defmodule CodeSearchElixirTracer.MixProject do
  use Mix.Project

  def project do
    [
      app: :code_search_elixir_tracer,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp escript do
    [
      main_module: CodeIntelligenceTracer.CLI,
      name: "code_search_elixir_tracer"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:toon, "~> 0.3"}
    ]
  end
end
