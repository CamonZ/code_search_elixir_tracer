# Development Tickets

Progressive tickets for building CodeIntelligenceTracer from scratch. Each ticket builds upon previous work.

## Phase Overview

| Phase | Tickets | Description |
|-------|---------|-------------|
| 1 | T001-T004 | Project Foundation & CLI |
| 2 | T005-T007 | BEAM File Reading |
| 3 | T008-T010 | Call Graph Extraction |
| 4 | T011-T012 | Function Locations |
| 5 | T013-T014, T034 | Output Generation (JSON & TOON) |
| 6 | T015-T017 | Type Signatures (Elixir 1.18+) |
| 7 | T018-T023 | Spec & Type Definitions |
| 8 | T024-T025 | Struct Extraction |
| 9 | T026-T027 | Main App Detection & Filtering |
| 10 | T028-T031 | Integration & Polish |
| 11 | T032-T033 | Optimization (Optional) |

## Critical Path (P0)

```
T001 → T002 → T003 → T004
              ↓
T005 → T006 → T008 → T011 → T013 → T028
       ↓
      T007
```

## All Tickets

### Phase 1: Project Foundation
- [T001 - Initialize Project](T001-initialize-project.md) - P0
- [T002 - CLI Argument Parsing](T002-cli-argument-parsing.md) - P0
- [T003 - Build Directory Discovery](T003-build-directory-discovery.md) - P0
- [T004 - Build and Test Escript](T004-build-test-escript.md) - P0

### Phase 2: BEAM File Reading
- [T005 - BEAM Chunk Reading](T005-beam-chunk-reading.md) - P0
- [T006 - Extract Debug Info](T006-extract-debug-info.md) - P0
- [T007 - BEAM File Discovery](T007-beam-file-discovery.md) - P0

### Phase 3: Call Graph Extraction
- [T008 - AST Walking for Function Calls](T008-ast-walking-function-calls.md) - P0
- [T009 - Call Filtering](T009-call-filtering.md) - P1
- [T010 - Known Modules Collection](T010-known-modules-collection.md) - P1

### Phase 4: Function Locations
- [T011 - Function Locations](T011-function-locations.md) - P0
- [T012 - Change Detection Hashes](T012-change-detection-hashes.md) - P1

### Phase 5: Output Generation
- [T013 - JSON Output](T013-json-output.md) - P0
- [T014 - Extraction Statistics](T014-extraction-statistics.md) - P1
- [T034 - TOON Output](T034-toon-output.md) - P1

### Phase 6: Type Signatures (Elixir 1.18+)
- [T015 - Type Signatures](T015-type-signatures.md) - P1
- [T016 - Format Type Signatures](T016-format-type-signatures.md) - P1
- [T017 - Signatures in Output](T017-signatures-json-output.md) - P1

### Phase 7: Spec & Type Definitions
- [T018 - Extract Specs](T018-extract-specs.md) - P1
- [T019 - Parse Spec Clauses](T019-parse-spec-clauses.md) - P1
- [T020 - Format Spec Strings](T020-format-spec-strings.md) - P1
- [T021 - Correlate Specs with Functions](T021-correlate-specs-functions.md) - P2
- [T022 - Extract Types](T022-extract-types.md) - P2
- [T023 - Specs and Types in Output](T023-specs-types-output.md) - P2

### Phase 8: Struct Extraction
- [T024 - Extract Structs](T024-extract-structs.md) - P2
- [T025 - Structs in Output](T025-structs-output.md) - P2

### Phase 9: Main App Detection
- [T026 - Main App Detection](T026-main-app-detection.md) - P1
- [T027 - Dependency Filtering](T027-dependency-filtering.md) - P1

### Phase 10: Integration & Polish
- [T028 - Extraction Pipeline](T028-extraction-pipeline.md) - P0
- [T029 - Error Handling](T029-error-handling.md) - P1
- [T030 - Integration Tests](T030-integration-tests.md) - P1
- [T031 - Documentation](T031-documentation.md) - P2

### Phase 11: Optimization (Optional)
- [T032 - Performance Profiling](T032-performance-profiling.md) - P3
- [T033 - Parallel Processing](T033-parallel-processing.md) - P3

## Module Architecture

```
lib/
├── code_intelligence_tracer.ex          # Main module, delegates
├── code_intelligence_tracer/
│   ├── cli.ex                           # CLI entry point
│   ├── extractor.ex                     # Main orchestration
│   ├── build_discovery.ex               # Find apps/BEAM files
│   ├── beam_reader.ex                   # Read BEAM chunks
│   ├── call_extractor.ex                # Extract function calls
│   ├── call_filter.ex                   # Filter stdlib/erlang
│   ├── function_extractor.ex            # Function locations + SHAs
│   ├── type_extractor.ex                # Type signatures (1.18+)
│   ├── spec_extractor.ex                # @spec/@type definitions
│   ├── struct_extractor.ex              # Struct definitions
│   ├── stats.ex                         # Statistics tracking
│   └── output/
│       ├── json.ex                      # JSON output
│       └── toon.ex                      # TOON output
```

## Priority Legend

- **P0**: Critical path, must have for MVP
- **P1**: Important, should have
- **P2**: Nice to have
- **P3**: Optional/future
