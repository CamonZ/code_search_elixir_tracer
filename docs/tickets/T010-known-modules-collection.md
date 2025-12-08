# T010: Implement Known Modules Collection

**Priority:** P1 | **Phase:** 3 - Basic Call Graph Extraction
**Features:** F4.4
**Depends On:** T007

## Description

Build set of known modules for targeted filtering.

## Acceptance Criteria

- [ ] Implement `collect_module_names/1` (beam_paths) in BeamReader
  - Extract module name from each BEAM file using `:beam_lib.info/1`
  - Return `MapSet` of module name strings
- [ ] Implement `collect_modules_from_apps/1` (app_dirs)
  - Iterate over app directories
  - Collect all module names into single MapSet
- [ ] Handle invalid BEAM files gracefully (skip them)

## Files to Modify

- `lib/code_intelligence_tracer/beam_reader.ex`

## Tests

- Collect modules from single app
- Collect from multiple apps
- Return MapSet for O(1) lookup
- Skip invalid BEAM files
