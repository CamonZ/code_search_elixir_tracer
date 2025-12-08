# T018: Extract @spec Definitions

**Priority:** P1 | **Phase:** 7 - Spec & Type Definitions
**Features:** F7.1
**Depends On:** T005

## Description

Parse @spec definitions from abstract_code chunk.

## Acceptance Criteria

- [ ] Create `CodeIntelligenceTracer.SpecExtractor` module
- [ ] Implement `extract_specs/1` (chunks)
  - Get `:abstract_code` chunk
  - Filter for `{:attribute, _, :spec, _}` forms
  - Filter for `{:attribute, _, :callback, _}` forms
- [ ] Extract from each spec:
  - Function name and arity
  - Kind: `:spec` or `:callback`
  - Line number
  - Raw clause data for parsing

## Files to Create

- `lib/code_intelligence_tracer/spec_extractor.ex`

## Raw Spec Structure

```erlang
{:attribute, line, :spec, {{name, arity}, [clause, ...]}}
```

## Tests

- Extract spec from module with specs
- Handle modules without specs
- Detect callback specs
- Extract line numbers
