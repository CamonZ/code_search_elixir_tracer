# T008: Implement AST Walking for Function Calls

**Priority:** P0 | **Phase:** 3 - Basic Call Graph Extraction
**Features:** F4.1, F4.2
**Depends On:** T006

## Description

Walk function AST to extract remote and local calls.

## Acceptance Criteria

- [ ] Create `CodeIntelligenceTracer.CallExtractor` module
- [ ] Implement `extract_calls/3` (definitions, module_name, source_file)
  - Uses `Macro.prewalk` to traverse AST
- [ ] Detect remote calls: `{{:., _, [module, func]}, _, args}`
  - Handle `Module.function(args)` pattern
  - Handle `:erlang_module.function(args)` pattern
- [ ] Detect local calls: `{func_atom, _, args}` where func_atom is atom
- [ ] Capture caller info: module, function, arity, file, line
- [ ] Capture callee info: module, function, arity
- [ ] Return list of call records

## Files to Create

- `lib/code_intelligence_tracer/call_extractor.ex`

## Call Record Structure

```elixir
%{
  type: :remote | :local,
  caller: %{
    module: "MyApp.Foo",
    function: "bar/2",
    file: "lib/my_app/foo.ex",
    line: 42
  },
  callee: %{
    module: "MyApp.Baz",
    function: "qux",
    arity: 1
  }
}
```

## Tests

- Extract remote call `Enum.map(list, fun)`
- Extract local call `helper(x)`
- Capture line numbers correctly
- Handle nested calls
