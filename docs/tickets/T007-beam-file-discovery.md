# T007: BEAM File Discovery in Application

**Priority:** P0 | **Phase:** 2 - BEAM File Reading
**Features:** F2.4
**Depends On:** T003

## Description

Find all BEAM files in an application's ebin directory.

## Acceptance Criteria

- [x] Implement `find_beam_files/1` (ebin_path) in BuildDiscovery
  - Use `Path.wildcard` for `*.beam` pattern
  - Filter to only `Elixir.*.beam` files (skip Erlang modules)
  - Return list of absolute paths
- [x] Handle empty directories (return empty list)
- [x] Handle non-existent directories (return empty list)

## Files to Modify

- `lib/code_intelligence_tracer/build_discovery.ex`

## Tests

- Find BEAM files in populated ebin
- Return empty list for empty directory
- Only return Elixir modules (Elixir.*.beam)
