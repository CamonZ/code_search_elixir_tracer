# T031: Documentation and Help

**Priority:** P2 | **Phase:** 10 - Integration & Polish
**Features:** NF5.3
**Depends On:** T028

## Description

Complete documentation and help text.

## Acceptance Criteria

- [x] Comprehensive `--help` output covering all options
  - **CLI.print_help/0 covers all options with examples**
- [x] @moduledoc for all public modules
  - **All modules have @moduledoc**
- [x] @doc for public functions
  - **Public functions documented**
- [x] README with:
  - Installation instructions
  - Usage examples
  - Output format documentation
  - Requirements (Elixir version, etc.)
  - **Complete README.md rewritten**
- [x] Output format documentation
  - **docs/OUTPUT_FORMAT.md created with full JSON schema**

## Files to Modify

- All `lib/` modules (add @moduledoc/@doc)
- `lib/code_intelligence_tracer/cli.ex` (help text)

## Files to Create

- `README.md`

## Help Text Should Include

```
ex_ast - Extract call graphs from compiled Elixir projects

USAGE:
    ex_ast [OPTIONS] [PATH]

ARGUMENTS:
    PATH    Path to Elixir project (default: current directory)

OPTIONS:
    -o, --output FILE     Output file (default: ex_ast.json)
    -f, --format FORMAT   Output format: json, toon (default: json)
    -d, --include-deps    Include all dependencies
    --deps DEP1,DEP2      Include specific dependencies
    -e, --env ENV         Build environment (default: dev)
    -h, --help            Show this help

EXAMPLES:
    ex_ast                          # Current dir, JSON output
    ex_ast /path/to/project         # Specific project
    ex_ast -f toon -o graph.toon    # TOON format
    ex_ast --include-deps           # Include all deps
```
