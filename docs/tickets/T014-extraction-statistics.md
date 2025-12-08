# T014: Add Extraction Statistics

**Priority:** P1 | **Phase:** 5 - Output Generation
**Features:** F10.2
**Depends On:** T013

## Description

Calculate and include extraction statistics in output.

## Acceptance Criteria

- [ ] Create `CodeIntelligenceTracer.Stats` module
- [ ] Track during extraction:
  - `modules_processed` - total BEAM files processed
  - `modules_with_debug_info` - modules with Elixir debug info
  - `modules_without_debug_info` - modules without debug info
  - `total_calls` - number of call records
  - `total_functions` - number of function locations
- [ ] Add `extraction_metadata` section to output
- [ ] Update both JSON and TOON output modules

## Files to Create

- `lib/code_intelligence_tracer/stats.ex`

## Files to Modify

- `lib/code_intelligence_tracer/output/json.ex`

## Output Structure Addition

```json
{
  "extraction_metadata": {
    "modules_processed": 50,
    "modules_with_debug_info": 45,
    "modules_without_debug_info": 5,
    "total_calls": 1234,
    "total_functions": 456
  }
}
```

## Tests

- Statistics reflect actual counts
- Handle zero counts correctly
