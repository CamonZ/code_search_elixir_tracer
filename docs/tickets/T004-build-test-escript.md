# T004: Build and Test Escript

**Priority:** P0 | **Phase:** 1 - Foundation
**Features:** F1.3
**Depends On:** T002, T003

## Description

Verify escript builds and runs correctly with basic integration.

## Acceptance Criteria

- [ ] Run `mix escript.build` successfully
- [ ] `./call_graph --help` displays help text
- [ ] `./call_graph` with no args uses current directory
- [ ] `./call_graph /path/to/project` accepts project path
- [ ] Exit codes: 0 for success, 1 for error
- [ ] Clear error message when build directory not found

## Verification

```bash
mix escript.build
./call_graph --help
./call_graph /nonexistent  # Should exit 1 with error message
```
