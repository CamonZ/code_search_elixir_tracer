# T021: Correlate Specs with Functions

**Priority:** P2 | **Phase:** 7 - Spec & Type Definitions
**Features:** F7.5
**Depends On:** T019, T011

## Description

Link specs to their function locations.

## Acceptance Criteria

- [ ] Implement `correlate_specs/2` (functions, specs) in SpecExtractor
  - Match spec by function name and arity
  - Add `:spec` key to function location entry
- [ ] Handle functions without specs (`:spec` is `nil`)
- [ ] Handle multiple arities correctly

## Files to Modify

- `lib/code_intelligence_tracer/spec_extractor.ex`

## Function Location with Spec

```elixir
%{
  "foo/2" => %{
    start_line: 10,
    end_line: 25,
    kind: :def,
    source_file: "lib/my_app/foo.ex",
    spec: %{
      inputs: [...],
      return: ...,
      inputs_string: ["integer()", "String.t()"],
      return_string: "boolean()",
      full: "@spec foo(integer(), String.t()) :: boolean()",
      kind: :spec,
      line: 9
    }
  }
}
```

## Tests

- Function with spec gets embedded spec data
- Function without spec has `spec: nil`
- Multiple arities handled correctly
