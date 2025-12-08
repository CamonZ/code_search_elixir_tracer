# T019: Parse Spec Type Clauses

**Priority:** P1 | **Phase:** 7 - Spec & Type Definitions
**Features:** F7.2, F7.3
**Depends On:** T018

## Description

Parse spec clauses into structured type data.

## Acceptance Criteria

- [ ] Implement `parse_spec_clause/1` in SpecExtractor
  - Handle `{:type, _, :fun, [{:type, _, :product, inputs}, return]}`
  - Handle bounded_fun (specs with when clauses)
- [ ] Implement `parse_type_ast/1` for structured output:
  - Union types: `%{type: :union, types: [...]}`
  - Tuple types: `%{type: :tuple, elements: [...]}`
  - List types: `%{type: :list, element_type: ...}`
  - Map types: `%{type: :map, fields: [...]}`
  - Function types: `%{type: :fun, inputs: [...], return: ...}`
  - Type refs: `%{type: :type_ref, module: ..., name: ..., args: [...]}`
  - Literals: `%{type: :literal, kind: :atom/:integer, value: ...}`
  - Builtins: `%{type: :builtin, name: :integer/:binary/...}`
  - Variables: `%{type: :var, name: :T}`

## Files to Modify

- `lib/code_intelligence_tracer/spec_extractor.ex`

## Tests

- Parse `@spec foo(integer) :: string`
- Parse union type `integer | atom`
- Parse map type `%{key: value}`
- Parse function type `(a -> b)`
- Parse remote type `String.t()`
