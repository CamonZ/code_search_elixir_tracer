# T028: Implement Full Extraction Pipeline

**Status:** COMPLETED

**Priority:** P0 | **Phase:** 10 - Integration & Polish
**Features:** F1-F10
**Depends On:** T001-T027

## Description

Wire together all components in the main extraction pipeline.

## Acceptance Criteria

- [x] Create `CodeIntelligenceTracer.Extractor` module
  - **Created lib/code_intelligence_tracer/extractor.ex**
  - **Contains extraction logic refactored from CLI**
- [x] Implement `run/1` (options) orchestration:
  1. Find build directory
  2. List and filter app directories
  3. Collect known modules (first pass)
  4. For each app:
     - Find BEAM files
     - Extract from each BEAM (calls, functions, signatures, specs, types, structs)
  5. Merge results from all apps
  6. Correlate specs with functions
  7. Calculate statistics
  8. Return complete extraction result
  - **Extractor.extract/4 handles all extraction**
  - **Extractor.select_apps_to_process/3 handles app filtering**
  - **Parallel processing via Task.async_stream**
- [x] Wire CLI to call Extractor
  - **CLI.run/1 calls Extractor.extract/4**
- [x] Generate output using appropriate format (JSON or TOON)
  - **Output.JSON.generate/1 and Output.TOON.generate/1 implemented**
- [x] Write output to file
  - **Output.JSON.write_file/2 and Output.TOON.write_file/2 implemented**
- [x] Print summary to console
  - **RunResult.print/1 prints extraction summary**

## Files Created

- `lib/code_intelligence_tracer/extractor.ex`
- `test/code_intelligence_tracer/extractor_test.exs`

## Files Modified

- `lib/code_intelligence_tracer/cli.ex` - Now delegates to Extractor

## Extraction Result Structure

```elixir
%{
  metadata: %{...},
  stats: %{...},
  calls: [...],
  function_locations: %{...},
  type_signatures: %{...},
  specs: %{...},
  types: %{...},
  structs: %{...}
}
```

## Tests

- Full pipeline runs without error
- Output file created
- Console summary printed
