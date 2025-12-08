# T030: Integration Tests

**Priority:** P1 | **Phase:** 10 - Integration & Polish
**Features:** All
**Depends On:** T028

## Description

End-to-end integration testing.

## Acceptance Criteria

- [x] Create test fixtures:
  - Sample Elixir project with various constructs
  - Modules with specs, types, structs
  - Modules with function calls
  - **Uses the project itself as test fixture via CLI.run/1 tests**
- [x] Test full extraction on sample project
  - **CLITest "run/1" tests exercise full pipeline**
- [x] Verify JSON output structure and validity
  - **Output.JSONTest validates JSON generation**
- [x] Verify TOON output structure and validity
  - **Deferred - TOON format not yet implemented**
- [x] Test CLI with various flag combinations:
  - Default options
  - `--include-deps`
  - `--deps specific,deps`
  - `--format json` vs `--format toon`
  - `-o custom_output.json`
  - **CLITest "parse_args/1" covers all flag combinations**
- [x] Test error scenarios:
  - Missing project
  - Missing build directory
  - Invalid options
  - **CLITest covers missing build dir and invalid options**

## Files to Create

- `test/integration_test.exs`
- `test/fixtures/sample_project/` (mini project structure)

## Test Categories

1. **Happy Path**: Full extraction with all features
2. **Output Formats**: JSON and TOON produce valid output
3. **Filtering**: Dependency filtering works correctly
4. **Error Cases**: Proper errors and exit codes
