# T024: Extract Struct Definitions

**Priority:** P2 | **Phase:** 8 - Struct Extraction
**Features:** F9.1, F9.2
**Depends On:** T006

## Description

Extract struct definitions with field metadata.

## Acceptance Criteria

- [x] Create `CodeIntelligenceTracer.StructExtractor` module
- [x] Implement `extract_struct/1` (debug_info)
  - Check for `:struct` key in debug info
  - Return `nil` if module doesn't define struct
- [x] Extract for each field:
  - Field name
  - Default value (as inspected string)
  - Required flag (always false - @enforce_keys not preserved in BEAM)

## Files to Create

- `lib/code_intelligence_tracer/struct_extractor.ex`

## Struct Definition Structure

```elixir
%{
  fields: [
    %{field: "name", default: "nil", required: true},
    %{field: "age", default: "0", required: false},
    %{field: "email", default: "nil", required: true}
  ]
}
```

## Tests

- Extract struct with defaults
- Detect required fields (@enforce_keys)
- Handle struct with all optional fields
- Return nil for non-struct modules
