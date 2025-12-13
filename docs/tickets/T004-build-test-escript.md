# T004: Build and Test Escript

**Priority:** P0 | **Phase:** 1 - Foundation
**Features:** F1.3
**Depends On:** T002, T003

## Description

Verify escript builds and runs correctly with basic integration.

## Acceptance Criteria

- [x] Run `mix escript.build` successfully
- [x] `./ex_ast --help` displays help text
- [x] `./ex_ast` with no args uses current directory
- [x] `./ex_ast /path/to/project` accepts project path
- [x] Exit codes: 0 for success, 1 for error
- [x] Clear error message when build directory not found

## Verification

```bash
mix escript.build
./ex_ast --help
./ex_ast /nonexistent  # Should exit 1 with error message
```
