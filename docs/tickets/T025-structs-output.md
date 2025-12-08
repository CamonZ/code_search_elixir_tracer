# T025: Add Structs to Output

**Priority:** P2 | **Phase:** 8 - Struct Extraction
**Features:** F10.1
**Depends On:** T024, T013

## Description

Include struct definitions in JSON/TOON output.

## Acceptance Criteria

- [ ] Add `structs` section organized by module
- [ ] Add `total_structs` statistic
- [ ] Update JSON output module
- [ ] Update TOON output module

## Files to Modify

- `lib/code_intelligence_tracer/output/json.ex`
- `lib/code_intelligence_tracer/output/toon.ex`

## Output Structure Addition

```json
{
  "total_structs": 15,
  "structs": {
    "MyApp.User": {
      "fields": [
        {"field": "name", "default": "nil", "required": true},
        {"field": "age", "default": "0", "required": false}
      ]
    }
  }
}
```

## Tests

- Structs included in output
- Statistics calculated correctly
- Empty structs section handled
