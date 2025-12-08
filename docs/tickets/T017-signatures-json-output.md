# T017: Add Signatures to Output

# SKIP

**Priority:** P1 | **Phase:** 6 - Type Signatures (Elixir 1.20+)
**Features:** F10.1
**Depends On:** T016, T013

## Description

Include type_signatures in JSON/TOON output.

## Acceptance Criteria

- [ ] Add `type_signatures` section to output structure
  - Organized by module: `{module: {func/arity: signature_data}}`
- [ ] Add statistics:
  - `total_modules_with_signatures`
  - `total_functions_with_signatures`
- [ ] Update JSON output module
- [ ] Update TOON output module (when implemented)

## Files to Modify

- `lib/code_intelligence_tracer/output/json.ex`

## Output Structure Addition

```json
{
  "total_modules_with_signatures": 10,
  "total_functions_with_signatures": 45,
  "type_signatures": {
    "MyApp.Foo": {
      "bar/2": {
        "name": "bar",
        "arity": 2,
        "clauses": [...]
      }
    }
  }
}
```

## Tests

- Signatures included in output
- Statistics calculated correctly
- Empty signatures handled
