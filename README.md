# call_graph

Extract call graphs, function locations, specs, types, and struct definitions from compiled Elixir projects.

## Features

- Extracts function call relationships from BEAM files
- Indexes function locations with source file mappings
- Parses `@spec` and `@type` definitions
- Extracts struct field information
- Supports regular and umbrella projects
- Filters by main app only or includes dependencies
- Outputs structured JSON for consumption by code intelligence tools

## Requirements

- Elixir 1.14+ with OTP 25+
- Project must be compiled with debug info (default in dev)

## Installation

Build the escript:

```bash
mix deps.get
mix escript.build
```

This creates the `call_graph` executable. Move it to a directory in your `$PATH`.

## Usage

```bash
call_graph [OPTIONS] [PATH]
```

### Arguments

- `PATH` - Path to Elixir project (default: current directory)

### Options

| Option | Alias | Description |
|--------|-------|-------------|
| `--output FILE` | `-o` | Output file path (default: `call_graph.json`) |
| `--format FORMAT` | `-f` | Output format: `json` (default: `json`) |
| `--include-deps` | `-d` | Include all dependencies in analysis |
| `--deps DEP1,DEP2` | | Include specific dependencies (comma-separated) |
| `--env ENV` | `-e` | Mix environment to use (default: `dev`) |
| `--help` | `-h` | Show help message |

### Examples

```bash
# Analyze current directory
call_graph

# Analyze specific project
call_graph /path/to/project

# Custom output file
call_graph -o output.json

# Include all dependencies
call_graph --include-deps

# Include specific dependencies
call_graph --deps phoenix,ecto

# Use test environment
call_graph -e test
```

## Output Format

The tool produces a JSON file containing:

- **calls** - Function call relationships (caller → callee)
- **function_locations** - Function definitions with line numbers
- **specs** - `@spec` definitions with parsed clauses
- **types** - `@type` and `@opaque` definitions
- **structs** - Struct field definitions

See [docs/OUTPUT_FORMAT.md](docs/OUTPUT_FORMAT.md) for the complete output schema.

### Sample Output

```json
{
  "generated_at": "2024-01-15T10:30:00Z",
  "project_path": "/path/to/project",
  "environment": "dev",
  "extraction_metadata": {
    "modules_processed": 50,
    "total_calls": 1234,
    "total_functions": 456
  },
  "calls": [...],
  "function_locations": {...},
  "specs": {...},
  "types": {...},
  "structs": {...}
}
```

## How It Works

1. Locates compiled BEAM files in `_build/<env>/lib/`
2. Reads debug info chunks from each BEAM file
3. Extracts function definitions, calls, specs, types, and structs
4. Filters calls to only include project modules (unless `--include-deps`)
5. Outputs structured JSON

## Development

```bash
# Run tests
mix test

# Format code
mix format

# Build escript
mix escript.build

# Run on self
./call_graph .
```

