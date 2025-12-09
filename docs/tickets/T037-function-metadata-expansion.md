# T037: Expand Function Definition Metadata

## Problem

Currently, function definitions only include:
- `start_line`, `end_line`
- `kind` (def/defp/defmacro/defmacrop)
- `source_file`, `source_file_absolute`

The function key is `"function_name/arity"` which combines name and arity. We need:
1. Separate `name` field (without arity)
2. Separate `arity` field (as integer)
3. `clause_count` - number of pattern matching function heads

## Context

Multi-clause functions in Elixir use pattern matching:

```elixir
def process(:ok, data), do: handle_success(data)      # clause 1
def process(:error, reason), do: handle_error(reason) # clause 2
def process(_, _), do: :unknown                       # clause 3
```

Knowing the clause count helps understand function complexity and identifies
functions that rely heavily on pattern matching dispatch.

## Implementation

### 1. Update `FunctionExtractor.extract_function_info/4`

Add new fields to the returned map:

```elixir
function_info = %{
  name: to_string(func_name),
  arity: arity,
  clause_count: length(clauses),
  start_line: start_line,
  end_line: end_line,
  kind: kind,
  source_file: source_file,
  source_file_absolute: source_file_absolute
}
```

### 2. Update type spec

```elixir
@type function_info :: %{
  name: String.t(),
  arity: non_neg_integer(),
  clause_count: pos_integer(),
  start_line: non_neg_integer(),
  end_line: non_neg_integer(),
  kind: function_kind(),
  source_file: String.t(),
  source_file_absolute: String.t()
}
```

### 3. Update Output module

Ensure the new fields are included in JSON/TOON output formatting.

### 4. Update tests

Add tests for:
- Single-clause functions have `clause_count: 1`
- Multi-clause functions have correct clause count
- Name and arity are extracted separately

## Acceptance Criteria

- [ ] `name` field contains function name without arity
- [ ] `arity` field contains function arity as integer
- [ ] `clause_count` field contains number of function clauses
- [ ] All existing tests pass
- [ ] New fields appear in JSON/TOON output
