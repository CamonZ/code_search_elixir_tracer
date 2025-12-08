# T034: Implement TOON Output

**Priority:** P1 | **Phase:** 5 - Output Generation
**Features:** F10.1
**Depends On:** T013

## Description

Generate TOON format output (Token-Oriented Object Notation) for LLM efficiency.

TOON achieves 30-60% token reduction compared to JSON while maintaining readability.
See: https://github.com/kentaro/toon_ex

## Acceptance Criteria

- [ ] Add `toon` dependency (~> 0.1) to mix.exs
- [ ] Create `CodeIntelligenceTracer.Output.TOON` module
- [ ] Implement `generate/1` (extraction_results)
  - Returns TOON string
- [ ] Same structure as JSON output:
  - Metadata section
  - Extraction stats
  - Calls array
  - Function locations
  - Type signatures
  - Specs and types
  - Structs
- [ ] Use `Toon.encode!/1`
- [ ] Implement `write_file/2` (toon_string, output_path)
- [ ] Update CLI to dispatch to correct output module based on `--format`

## Files to Create

- `lib/code_intelligence_tracer/output/toon.ex`

## Files to Modify

- `mix.exs` - add toon dependency
- `lib/code_intelligence_tracer/cli.ex` - dispatch by format

## Usage

```bash
./call_graph -f toon -o call_graph.toon /path/to/project
```

## Tests

- Output valid TOON
- Include all required fields
- Can be decoded back to same structure as JSON
