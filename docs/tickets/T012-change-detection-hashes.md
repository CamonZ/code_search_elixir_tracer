# T012: Implement Change Detection Hashes

**Priority:** P1 | **Phase:** 4 - Function Locations
**Features:** F6.4
**Depends On:** T011

## Description

Compute SHA hashes for change detection.

## Acceptance Criteria

- [ ] Implement `compute_source_sha/3` (source_file, start_line, end_line)
  - Read source file lines for function range
  - Compute SHA256 of the text
  - Return hex-encoded hash string
- [ ] Implement `compute_ast_sha/1` (function_clauses)
  - Normalize AST to remove non-semantic metadata
  - Compute SHA256 of normalized term
  - Return hex-encoded hash string
- [ ] Implement `normalize_ast/1`
  - Strip `:line`, `:column`, `:counter`, `:file` from metadata
  - Preserve semantic structure
- [ ] Handle missing source files (return nil)

## Files to Modify

- `lib/code_intelligence_tracer/function_extractor.ex`

## Hash Behavior

| Change Type | sha_source | sha_ast |
|-------------|------------|---------|
| Formatting only | Changes | Same |
| Comments only | Changes | Same |
| Logic change | Changes | Changes |
| Variable rename | Changes | Changes |

## Tests

- Same source produces same SHA
- Formatting change affects sha_source only
- Logic change affects both SHAs
- Missing source file returns nil
