# T039: Output Function SHA Hashes

## Problem

The `FunctionExtractor` module has `compute_source_sha/3` and `compute_ast_sha/1` functions implemented and tested (T012), but they are never called during extraction. The computed hashes are not included in the output.

These hashes are valuable for:
- **Source SHA**: SHA256 of the source code from `start_line` to `end_line`. Detects any change to a function (formatting, comments, code).
- **AST SHA**: SHA256 of the normalized AST. Detects semantic changes only (ignores formatting/comments/line numbers).

## Implementation

### 1. Update `extract_function_info/4`

Call the SHA functions and include results in the function info:

```elixir
defp extract_function_info({{func_name, arity}, kind, _meta, clauses}, source_file, source_file_absolute) do
  {start_line, end_line} = compute_line_range(clauses)

  function_key = "#{func_name}/#{arity}"

  function_info = %{
    start_line: start_line,
    end_line: end_line,
    kind: kind,
    source_file: source_file,
    source_file_absolute: source_file_absolute,
    source_sha: compute_source_sha(source_file_absolute, start_line, end_line),
    ast_sha: compute_ast_sha(clauses)
  }

  {function_key, function_info}
end
```

### 2. Update type spec

```elixir
@type function_info :: %{
  start_line: non_neg_integer(),
  end_line: non_neg_integer(),
  kind: function_kind(),
  source_file: String.t(),
  source_file_absolute: String.t(),
  source_sha: String.t() | nil,
  ast_sha: String.t()
}
```

### 3. Update Output module

Ensure `format_function_info/1` includes the new fields:

```elixir
defp format_function_info(info) do
  %{
    start_line: info.start_line,
    end_line: info.end_line,
    kind: to_string(info.kind),
    source_file: info.source_file,
    source_file_absolute: info.source_file_absolute,
    source_sha: info.source_sha,
    ast_sha: info.ast_sha
  }
end
```

### 4. Update tests

Add tests verifying:
- Hashes appear in extracted function info
- Hashes appear in JSON/TOON output

## Performance Consideration

`compute_source_sha/3` reads the source file for each function. For modules with many functions, this could be optimized by:
- Reading the file once per module
- Caching file contents during extraction

However, start with the simple implementation and optimize if profiling shows it's a bottleneck.

## Acceptance Criteria

- [ ] `source_sha` field added to function info
- [ ] `ast_sha` field added to function info
- [ ] Both fields appear in JSON output
- [ ] Both fields appear in TOON output
- [ ] All existing tests pass
