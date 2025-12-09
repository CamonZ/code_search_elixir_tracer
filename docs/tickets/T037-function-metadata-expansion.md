# T037: Expand Function Definition Metadata

**Status: COMPLETED (Phase 2)**

## Problem

Originally, function definitions aggregated all clauses into a single entry. Phase 2 changes each clause to be its own separate entry with individual line, guard, and pattern information.

## Phase 1 (Completed)

Added metadata fields to aggregated function entries:
- `name`, `arity`, `clause_count`, `guards[]`

## Phase 2 (Completed)

Changed from aggregated entries to per-clause entries:

**Before (Phase 1):**
```elixir
"multi_guard/1" => %{
  clause_count: 3,
  guards: ["is_binary(x)", "is_number(x)", nil],
  start_line: 13,
  end_line: 15,
  ...
}
```

**After (Phase 2):**
```elixir
"multi_guard/1:13" => %{line: 13, guard: "is_binary(x)", pattern: "x", ...}
"multi_guard/1:14" => %{line: 14, guard: "is_number(x)", pattern: "x", ...}
"multi_guard/1:15" => %{line: 15, guard: nil, pattern: "_x", ...}
```

## Implementation

### Key Format

Function keys changed from `"name/arity"` to `"name/arity:line"`.

### Clause Info Structure

Each clause entry contains:

```elixir
@type clause_info :: %{
  name: String.t(),
  arity: non_neg_integer(),
  line: non_neg_integer(),
  kind: function_kind(),
  guard: String.t() | nil,
  pattern: String.t(),
  source_file: String.t(),
  source_file_absolute: String.t(),
  source_sha: String.t() | nil,
  ast_sha: String.t()
}
```

### Pattern Extraction

Function arguments are converted to human-readable strings:
- `"x"` - simple variable
- `"x, y"` - multiple args
- `"{:ok, value}"` - tuple pattern
- `"{:error, _} = err"` - pattern with binding

## Acceptance Criteria

- [x] Each function clause is a separate entry keyed by `name/arity:line`
- [x] `line` field contains the clause's line number
- [x] `guard` field contains guard expression (or nil)
- [x] `pattern` field contains args as human-readable string
- [x] `source_sha` and `ast_sha` are per-clause
- [x] All 264 tests pass
- [x] OUTPUT_FORMAT.md updated

## Example Output

For the functions:

```elixir
def multi_guard(x) when is_binary(x), do: "string"
def multi_guard(x) when is_number(x), do: "number"
def multi_guard(_x), do: "other"
```

Output:

```elixir
%{
  "multi_guard/1:13" => %{
    name: "multi_guard",
    arity: 1,
    line: 13,
    kind: :def,
    guard: "is_binary(x)",
    pattern: "x",
    source_file: "test/support/guarded_functions.ex",
    source_file_absolute: "/path/to/test/support/guarded_functions.ex",
    source_sha: "3ea6b35d...",
    ast_sha: "c8a51ee0..."
  },
  "multi_guard/1:14" => %{
    name: "multi_guard",
    arity: 1,
    line: 14,
    kind: :def,
    guard: "is_number(x)",
    pattern: "x",
    source_file: "test/support/guarded_functions.ex",
    source_file_absolute: "/path/to/test/support/guarded_functions.ex",
    source_sha: "4815bfef...",
    ast_sha: "d9b62ff1..."
  },
  "multi_guard/1:15" => %{
    name: "multi_guard",
    arity: 1,
    line: 15,
    kind: :def,
    guard: nil,
    pattern: "_x",
    source_file: "test/support/guarded_functions.ex",
    source_file_absolute: "/path/to/test/support/guarded_functions.ex",
    source_sha: "5926caef...",
    ast_sha: "e0c73002..."
  }
}
```
