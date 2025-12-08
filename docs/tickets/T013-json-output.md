# T013: Implement JSON Output

**Priority:** P0 | **Phase:** 5 - Output Generation
**Features:** F10.1, F10.3
**Depends On:** T008, T011

## Description

Generate JSON output with calls and locations.

## Acceptance Criteria

- [ ] Add `jason` dependency (~> 1.4) to mix.exs
- [ ] Create `CodeIntelligenceTracer.Output.JSON` module
- [ ] Implement `generate/1` (extraction_results)
  - Returns JSON string
- [ ] Include metadata section:
  - `generated_at` - ISO8601 timestamp
  - `project_path` - analyzed project path
  - `environment` - build environment (dev/test/prod)
- [ ] Include `calls` array with caller/callee structure
- [ ] Include `function_locations` map organized by module
- [ ] Use `Jason.encode!` with `pretty: true`
- [ ] Implement `write_file/2` (json_string, output_path)

## Files to Create

- `lib/code_intelligence_tracer/output/json.ex`

## Files to Modify

- `mix.exs` - add jason dependency

## Output Structure

```json
{
  "generated_at": "2024-01-15T10:30:00Z",
  "project_path": "/path/to/project",
  "environment": "dev",
  "calls": [...],
  "function_locations": {...}
}
```

## Tests

- Output valid JSON
- Include all required fields
- Pretty print with indentation
