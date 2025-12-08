# T004: Build and Test Escript

**Priority:** P0 | **Phase:** 1 - Foundation
**Features:** F1.3
**Depends On:** T002, T003

## Description

Verify escript builds and runs correctly with basic integration.

## Acceptance Criteria

- [x] Run `mix escript.build` successfully
- [x] `./call_graph --help` displays help text
- [x] `./call_graph` with no args uses current directory
- [x] `./call_graph /path/to/project` accepts project path
- [x] Exit codes: 0 for success, 1 for error
- [x] Clear error message when build directory not found

## Verification

```bash
mix escript.build
./call_graph --help
./call_graph /nonexistent  # Should exit 1 with error message
```
