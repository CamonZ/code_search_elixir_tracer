# T034: Implement TOON Output

**Priority:** P1 | **Phase:** 5 - Output Generation
**Features:** F10.1
**Depends On:** T013

## Description

Generate TOON format output (Token-Oriented Object Notation) for LLM efficiency.

TOON achieves 30-60% token reduction compared to JSON while maintaining readability.
See: https://github.com/kentaro/toon_ex

## Acceptance Criteria

- [x] Add `toon` dependency (~> 0.1) to mix.exs
  - **Added toon ~> 0.3**
- [x] Create `CodeIntelligenceTracer.Output.TOON` module
  - **Created lib/code_intelligence_tracer/output/toon.ex**
- [x] Implement `generate/1` (extraction_results)
  - Returns TOON string
- [x] Same structure as JSON output:
  - Metadata section
  - Extraction stats
  - Calls array
  - Function locations
  - Type signatures
  - Specs and types
  - Structs
  - **All fields included, same as JSON output**
- [x] Use `Toon.encode!/1`
  - **Uses Toon.encode/1 with pattern matching**
- [x] Implement `write_file/2` (toon_string, output_path)
- [x] Update CLI to dispatch to correct output module based on `--format`
  - **CLI.write_output/3 dispatches by format**

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
