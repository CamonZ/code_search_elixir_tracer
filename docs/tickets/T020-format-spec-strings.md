# T020: Format Spec Strings

**Priority:** P1 | **Phase:** 7 - Spec & Type Definitions
**Features:** F7.4
**Depends On:** T019

## Description

Generate human-readable spec strings.

## Acceptance Criteria

- [x] Implement `format_type_string/1` (type_ast) in SpecExtractor
  - Convert Erlang abstract format to Elixir syntax
- [x] Generate for each clause:
  - `inputs_string` - array of formatted input types
  - `return_string` - formatted return type
  - `full` - complete spec string like `@spec foo(integer()) :: String.t()`
- [x] Implement `erlang_to_elixir_type/1` conversions:
  - `'Elixir.String':t()` -> `String.t()`
  - `:erlang` module refs -> appropriate Elixir names

## Files to Modify

- `lib/code_intelligence_tracer/spec_extractor.ex`

## Output Per Clause

```elixir
%{
  inputs: [%{type: :builtin, name: :integer}],  # structured
  return: %{type: :type_ref, module: "String", name: :t, args: []},
  inputs_string: ["integer()"],  # human readable
  return_string: "String.t()",
  full: "@spec foo(integer()) :: String.t()"
}
```

## Tests

- Format simple spec correctly
- Format complex nested types
- Convert Erlang syntax to Elixir
