# T003: Implement Build Directory Discovery

**Priority:** P0 | **Phase:** 1 - Foundation
**Features:** F2.1, F2.3
**Depends On:** T002

## Description

Locate compiled applications in `_build/{env}/lib`.

## Acceptance Criteria

- [ ] Create `CodeIntelligenceTracer.BuildDiscovery` module
- [ ] Implement `find_build_dir/2` (project_path, env)
  - Returns `{:ok, path}` or `{:error, reason}`
- [ ] Implement `list_app_directories/1` (build_lib_path)
  - Returns list of `{app_name, ebin_path}` tuples
- [ ] Handle missing build directory with clear error message

## Files to Create

- `lib/code_intelligence_tracer/build_discovery.ex`

## Tests

- Find build dir for valid project
- Error for missing build directory
- List all app directories in build
- Handle empty build directory
