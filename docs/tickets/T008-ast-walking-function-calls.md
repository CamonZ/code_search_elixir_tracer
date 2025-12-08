# T008: Implement AST Walking for Function Calls

**Priority:** P0 | **Phase:** 3 - Basic Call Graph Extraction
**Features:** F4.1, F4.2
**Depends On:** T006

## Description

Walk function AST to extract remote and local calls.

## Acceptance Criteria

- [x] Create `CodeIntelligenceTracer.CallExtractor` module
- [x] Implement `extract_calls/3` (definitions, module_name, source_file)
  - Uses `Macro.prewalk` to traverse AST
- [x] Detect remote calls: `{{:., _, [module, func]}, _, args}`
  - Handle `Module.function(args)` pattern
  - Handle `:erlang_module.function(args)` pattern
- [x] Detect local calls: `{func_atom, _, args}` where func_atom is atom
- [x] Capture caller info: module, function, kind, file, line
- [x] Capture callee info: module, function, arity
- [x] Extract calls from all function types: def, defp, defmacro, defmacrop
- [x] Return list of call records

## Files to Create

- `lib/code_intelligence_tracer/call_extractor.ex`

## Call Record Structure

```elixir
%{
  type: :remote | :local,
  caller: %{
    module: "MyApp.Foo",
    function: "bar/2",
    kind: :def | :defp | :defmacro | :defmacrop,
    file: "lib/my_app/foo.ex",
    line: 42
  },
  callee: %{
    module: "MyApp.Baz",  # same as caller module for local calls
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
