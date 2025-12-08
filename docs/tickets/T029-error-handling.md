# T029: Add Error Handling

**Priority:** P1 | **Phase:** 10 - Integration & Polish
**Features:** F11.1, F11.2, F11.3
**Depends On:** T028

## Description

Comprehensive error handling throughout the pipeline.

## Acceptance Criteria

- [ ] Handle missing build directory with helpful message
  - Suggest running `mix compile`
- [ ] Handle BEAM file read errors gracefully
  - Log warning, continue with other files
- [ ] Handle missing source files
  - Set SHA values to nil, continue
- [ ] Count and report modules without debug info
- [ ] Exit codes:
  - 0: Success
  - 1: Fatal error (no build dir, invalid options)
- [ ] All errors written to stderr
- [ ] Warnings don't halt execution

## Files to Modify

- `lib/code_intelligence_tracer/cli.ex`
- `lib/code_intelligence_tracer/extractor.ex`
- Various extraction modules

## Error Messages

```
Error: Build directory not found: /path/to/project/_build/dev/lib
Hint: Make sure the project has been compiled with `mix compile`

Warning: Could not read BEAM file: /path/to/file.beam (reason)
Warning: Source file not found: /path/to/source.ex (SHA will be null)
Warning: Dependency 'foo' not found in build directory
```

## Tests

- Graceful handling of missing build dir
- Continue on individual BEAM failures
- Report stats on skipped modules
