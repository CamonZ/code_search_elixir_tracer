# T028: Implement Full Extraction Pipeline

**Priority:** P0 | **Phase:** 10 - Integration & Polish
**Features:** F1-F10
**Depends On:** T001-T027

## Description

Wire together all components in the main extraction pipeline.

## Acceptance Criteria

- [x] Create `CodeIntelligenceTracer.Extractor` module
  - **Implemented directly in CLI.run/1 instead of separate module**
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
  - **All steps implemented in CLI.run/1 and extract_from_apps/2**
- [x] Wire CLI to call Extractor.run/1
  - **CLI.main/1 calls CLI.run/1 directly**
- [x] Generate output using appropriate format (JSON or TOON)
  - **Output.JSON.generate/1 implemented**
- [x] Write output to file
  - **Output.JSON.write_file/2 implemented**
- [x] Print summary to console
  - **RunResult.print/1 prints extraction summary**

## Files to Create

- `lib/code_intelligence_tracer/extractor.ex`

## Files to Modify

- `lib/code_intelligence_tracer/cli.ex`

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
