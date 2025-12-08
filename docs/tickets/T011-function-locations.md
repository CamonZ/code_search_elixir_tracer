# T011: Extract Function Definitions with Locations

**Priority:** P0 | **Phase:** 4 - Function Locations
**Features:** F6.1, F6.2, F6.3
**Depends On:** T006

## Description

Extract function locations from debug info.

## Acceptance Criteria

- [ ] Create `CodeIntelligenceTracer.FunctionExtractor` module
- [ ] Implement `extract_functions/2` (debug_info, source_file)
- [ ] For each function definition extract:
  - Function name and arity
  - Start line from definition metadata
  - End line computed from clause ranges
  - Kind: `def`, `defp`, `defmacro`, `defmacrop`
- [ ] Implement `resolve_source_path/2` (debug_info, beam_path)
  - Get absolute path from `:file` key in debug info
  - Create relative path (lib/... or test/...)

## Files to Create

- `lib/code_intelligence_tracer/function_extractor.ex`

## Function Record Structure

```elixir
%{
  "function_name/arity" => %{
    start_line: 10,
    end_line: 25,
    kind: :def,
    source_file: "lib/my_app/foo.ex",
    source_file_absolute: "/full/path/lib/my_app/foo.ex"
  }
}
```

## Tests

- Extract public function location
- Extract private function location
- Detect macro definitions
- Handle multi-clause functions (use first/last lines)
