# T002: Implement Basic CLI Argument Parsing

**Priority:** P0 | **Phase:** 1 - Foundation
**Features:** F1.1, F1.2
**Depends On:** T001

## Description

Create CLI module with argument parsing using OptionParser.

## Acceptance Criteria

- [ ] Implement `main/1` as escript entry point
- [ ] Implement `parse_args/1` supporting:
  - `-o, --output` (string, default: "call_graph.json")
  - `-f, --format` (string, "json" or "toon", default: "json")
  - `-d, --include-deps` (boolean)
  - `--deps` (string, comma-separated)
  - `-e, --env` (string, default: "dev")
  - `-h, --help` (boolean)
- [ ] Parse positional argument as project path (default: ".")
- [ ] Implement `print_help/0` function
- [ ] Return structured options map or `{:error, reason}`
- [ ] Validate `--include-deps` and `--deps` are mutually exclusive
- [ ] Validate `--format` is either "json" or "toon"

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
