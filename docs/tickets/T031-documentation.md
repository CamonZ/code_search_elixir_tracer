# T031: Documentation and Help

**Priority:** P2 | **Phase:** 10 - Integration & Polish
**Features:** NF5.3
**Depends On:** T028

## Description

Complete documentation and help text.

## Acceptance Criteria

- [ ] Comprehensive `--help` output covering all options
- [ ] @moduledoc for all public modules
- [ ] @doc for public functions
- [ ] README with:
  - Installation instructions
  - Usage examples
  - Output format documentation
  - Requirements (Elixir version, etc.)

## Files to Modify

- All `lib/` modules (add @moduledoc/@doc)
- `lib/code_intelligence_tracer/cli.ex` (help text)

## Files to Create

- `README.md`

## Help Text Should Include

```
call_graph - Extract call graphs from compiled Elixir projects

USAGE:
    call_graph [OPTIONS] [PATH]

ARGUMENTS:
    PATH    Path to Elixir project (default: current directory)

OPTIONS:
    -o, --output FILE     Output file (default: call_graph.json)
    -f, --format FORMAT   Output format: json, toon (default: json)
    -d, --include-deps    Include all dependencies
    --deps DEP1,DEP2      Include specific dependencies
    -e, --env ENV         Build environment (default: dev)
    -h, --help            Show this help

EXAMPLES:
    call_graph                          # Current dir, JSON output
    call_graph /path/to/project         # Specific project
    call_graph -f toon -o graph.toon    # TOON format
    call_graph --include-deps           # Include all deps
```
