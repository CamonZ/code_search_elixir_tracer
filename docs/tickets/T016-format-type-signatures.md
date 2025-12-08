# T016: Format Type Signatures

# SKIP

**Priority:** P1 | **Phase:** 6 - Type Signatures (Elixir 1.20+)
**Features:** F5.2, F5.3
**Depends On:** T015

## Description

Format extracted signatures into readable strings.

## Acceptance Criteria

- [ ] Implement `format_signature/3` (name, arity, sig_data) in TypeExtractor
- [ ] Implement `type_to_string/1` (type_descriptor)
  - Use `Module.Types.Descr.to_quoted_string/1` when available
  - Fallback to "dynamic()" on error
- [ ] Format each clause with args and return type
- [ ] Handle complex nested types

## Files to Modify

- `lib/code_intelligence_tracer/type_extractor.ex`

## Formatted Output

```elixir
%{
  name: "foo",
  arity: 2,
  clauses: [
    %{
      args: ["integer()", "String.t()"],
      return: "{:ok, result()} | {:error, term()}"
    }
  ]
}
```

## Tests

- Format simple function signature
- Format function with multiple clauses
- Handle complex union types
- Graceful fallback for unknown types
