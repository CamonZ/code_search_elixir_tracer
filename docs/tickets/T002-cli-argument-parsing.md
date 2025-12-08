# T002: Implement Basic CLI Argument Parsing

**Priority:** P0 | **Phase:** 1 - Foundation
**Features:** F1.1, F1.2
**Depends On:** T001

## Description

Create CLI module with argument parsing using OptionParser.

## Acceptance Criteria

- [x] Implement `main/1` as escript entry point
- [x] Implement `parse_args/1` supporting:
  - `-o, --output` (string, default: "call_graph.json")
  - `-f, --format` (string, "json" or "toon", default: "json")
  - `-d, --include-deps` (boolean)
  - `--deps` (string, comma-separated)
  - `-e, --env` (string, default: "dev")
  - `-h, --help` (boolean)
- [x] Parse positional argument as project path (default: ".")
- [x] Implement `print_help/0` function
- [x] Return structured options map or `{:error, reason}`
- [x] Validate `--include-deps` and `--deps` are mutually exclusive
- [x] Validate `--format` is either "json" or "toon"

## Files to Modify

- `lib/code_intelligence_tracer/cli.ex`

## Tests

- Parse empty args returns defaults
- Parse `-o custom.json` sets output
- Parse `-f toon` sets format
- Parse `--include-deps` sets flag
- Parse `--deps a,b,c` creates list
- Parse positional path works
- Error when both `--include-deps` and `--deps` provided
- Error for invalid format value
