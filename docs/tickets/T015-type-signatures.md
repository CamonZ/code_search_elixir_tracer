# T015: Extract Type Signatures from Debug Info

# SKIP

**Priority:** P1 | **Phase:** 6 - Type Signatures (Elixir 1.20+)
**Features:** F5.1
**Depends On:** T006

## Description

Extract inferred type signatures from Elixir 1.20+ debug info.

## Acceptance Criteria

- [ ] Create `CodeIntelligenceTracer.TypeExtractor` module
- [ ] Implement `extract_signatures/1` (debug_info)
  - Check for `:signatures` key in debug info
  - Handle modules without signatures (pre-1.20 or inference disabled)
- [ ] Parse signature structure: `{{name, arity}, {:infer, clauses}}`
- [ ] Each clause contains `{arg_types, return_type}`
- [ ] Return map of `"name/arity" => signature_data`

## Files to Create

- `lib/code_intelligence_tracer/type_extractor.ex`

## Signature Structure

```elixir
%{
  "foo/2" => %{
    name: "foo",
    arity: 2,
    clauses: [
      %{args: ["integer()", "String.t()"], return: "boolean()"}
    ]
  }
}
```

## Tests

- Extract signatures from 1.20+ compiled module
- Return empty map for modules without signatures
- Handle multiple clauses per function
