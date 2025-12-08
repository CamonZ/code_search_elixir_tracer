# CodeSearchElixirTracer

A tool that leverages Elixir's compilation traces to extract AST (Abstract Syntax Tree) information from your codebase. This data is designed to be consumed by `code_search`, a Rust CLI application for code search, AST traversal, and semantic search.

## Features

- Uses Elixir's compilation tracing mechanism to capture AST data
- Extracts structural information from your codebase during compilation
- Outputs AST data in a format compatible with code_search

## Installation

Ensure the CLI is available in your `$PATH`.

## Usage

To use the tracer with an existing Elixir project, configure it to produce debug traces. Add the following to your `mix.exs` for the dev environment:

```elixir
def project do
  [
    # ... other config
    elixirc_options: elixirc_options(Mix.env())
  ]
end

defp elixirc_options(:dev) do
  [tracers: [CodeSearchElixirTracer]]
end

defp elixirc_options(_), do: []
```

Then recompile your project to generate the AST data.

