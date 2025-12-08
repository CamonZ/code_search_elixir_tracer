# T023: Add Specs and Types to Output

**Priority:** P2 | **Phase:** 7 - Spec & Type Definitions
**Features:** F10.1
**Depends On:** T020, T022, T013

## Description

Include specs and types in JSON/TOON output.

## Acceptance Criteria

- [ ] Add `specs` section organized by module
- [ ] Add `types` section organized by module
- [ ] Add statistics:
  - `total_specs`
  - `total_types`
- [ ] Update JSON output module
- [ ] Update TOON output module

## Files to Modify

- `lib/code_intelligence_tracer/output/json.ex`
- `lib/code_intelligence_tracer/output/toon.ex`

## Output Structure Addition

```json
{
  "total_specs": 123,
  "total_types": 45,
  "specs": {
    "MyApp.Foo": [
      {
        "name": "bar",
        "arity": 2,
        "kind": "spec",
        "line": 15,
        "clauses": [...]
      }
    ]
  },
  "types": {
    "MyApp.Foo": [
      {
        "name": "result",
        "kind": "type",
        "params": [],
        "definition": "@type result :: {:ok, term()} | {:error, term()}"
      }
    ]
  }
}
```

## Tests

- Specs included in output
- Types included in output
- Statistics calculated correctly
