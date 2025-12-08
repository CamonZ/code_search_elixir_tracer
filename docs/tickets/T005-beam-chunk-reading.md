# T005: Implement BEAM Chunk Reading

**Priority:** P0 | **Phase:** 2 - BEAM File Reading
**Features:** F3.1
**Depends On:** T001

## Description

Create BeamReader module to read raw chunks from BEAM files using `:beam_lib`.

## Acceptance Criteria

- [ ] Create `CodeIntelligenceTracer.BeamReader` module
- [ ] Implement `read_chunks/1` (beam_path)
  - Uses `:beam_lib.chunks/2` to read chunks
  - Requests: `[:debug_info, :attributes, :abstract_code]`
  - Returns `{:ok, {module, chunks}}` or `{:error, reason}`
- [ ] Handle missing chunks gracefully (abstract_code may not exist)
- [ ] Handle missing/corrupt BEAM files

## Files to Create

- `lib/code_intelligence_tracer/beam_reader.ex`

## Tests

- Read chunks from valid BEAM file
- Handle BEAM without abstract_code chunk
- Handle non-existent file
- Handle corrupt/invalid BEAM file
