# T006: Extract Elixir Debug Info

**Priority:** P0 | **Phase:** 2 - BEAM File Reading
**Features:** F3.2
**Depends On:** T005

## Description

Parse Elixir debug info from BEAM chunks to get module metadata.

## Acceptance Criteria

- [ ] Implement `extract_debug_info/2` (chunks, module) in BeamReader
  - Handle `:debug_info_v1` format with backend callback
  - Call `backend.debug_info(:elixir_v1, module, data, [])`
  - Returns `{:ok, debug_info_map}` or `{:error, reason}`
- [ ] Debug info map contains:
  - `:definitions` - list of function definitions with AST
  - `:file` - source file path
  - `:module` - module atom
  - `:signatures` - type signatures (Elixir 1.20+)
  - `:struct` - struct definition if present

## Files to Modify

- `lib/code_intelligence_tracer/beam_reader.ex`

## Tests

- Extract debug info from Elixir module
- Return error for Erlang-only modules (no elixir_v1 backend)
- Handle missing debug_info chunk
