# T040: Capture Call Arguments as Strings

**Status: COMPLETED**

## Problem

Call records only captured the callee's module, function, and arity. This doesn't provide visibility into *how* functions are being called - what actual arguments are passed at each call site.

## Solution

Add an `args` field to call records that captures the arguments as a human-readable string representation.

## Implementation

### Callee Structure

```elixir
callee: %{
  module: String.t(),
  function: String.t(),
  arity: non_neg_integer(),
  args: String.t()  # NEW
}
```

### Argument Conversion

Arguments are converted from AST to human-readable strings:
- Variables: `x` → `"x"`
- Multiple args: `x, y` → `"x, y"`
- Literals: `"hello"` → `"\"hello\""`
- Tuples: `{:ok, value}` → `"{:ok, value}"`
- Pattern matches: `{:ok, v} = result` → `"{:ok, v} = result"`

### Special Cases

- **Function captures** (`&Mod.func/1`): Empty string for args since captures have explicit arity but no actual arguments at the capture site
- **Zero-arity calls** (`helper()`): Empty string

### Files Changed

- `lib/code_intelligence_tracer/call_extractor.ex` - Added `args_to_string/1`, `arg_to_string/1`, `normalize_arg_ast/1` helpers; updated all call extraction points
- `lib/code_intelligence_tracer/output.ex` - Added `args` to call output formatting
- `docs/OUTPUT_FORMAT.md` - Updated documentation
- `test/code_intelligence_tracer/call_extractor_test.exs` - Added args capture tests

## Acceptance Criteria

- [x] Remote calls capture arguments as string
- [x] Local calls capture arguments as string
- [x] Literal arguments formatted correctly (strings quoted)
- [x] Tuple/list patterns captured
- [x] Function captures have empty args string
- [x] Zero-arity calls have empty args string
- [x] Output format documentation updated
- [x] All tests pass

## Example Output

```json
{
  "type": "remote",
  "caller": {
    "module": "MyApp.Processor",
    "function": "run/1",
    "kind": "def",
    "file": "lib/my_app/processor.ex",
    "line": 15
  },
  "callee": {
    "module": "Enum",
    "function": "map",
    "arity": 2,
    "args": "list, &transform/1"
  }
}
```
