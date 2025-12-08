# T022: Extract @type Definitions

**Priority:** P2 | **Phase:** 7 - Spec & Type Definitions
**Features:** F8.1, F8.2
**Depends On:** T005

## Description

Parse @type and @opaque definitions from abstract_code.

## Acceptance Criteria

- [ ] Implement `extract_types/1` (chunks) in SpecExtractor
  - Filter for `{:attribute, _, :type, _}` forms
  - Filter for `{:attribute, _, :opaque, _}` forms
- [ ] Extract for each type:
  - Type name
  - Kind: `:type` or `:opaque`
  - Type parameters (for parameterized types)
  - Full definition string
- [ ] Use `:erl_pp.form/1` to format, then convert to Elixir syntax

## Files to Modify

- `lib/code_intelligence_tracer/spec_extractor.ex`

## Type Definition Structure

```elixir
%{
  name: "result",
  kind: :type,
  params: ["a", "b"],
  definition: "@type result(a, b) :: {:ok, a} | {:error, b}"
}
```

## Tests

- Extract `@type t :: integer`
- Extract `@opaque t :: term`
- Extract parameterized type `@type t(a) :: {a, a}`
