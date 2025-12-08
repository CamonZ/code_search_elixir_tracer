# T009: Implement Call Filtering (Stdlib/Erlang)

**Priority:** P1 | **Phase:** 3 - Basic Call Graph Extraction
**Features:** F4.3
**Depends On:** T008

## Description

Filter out stdlib and Erlang modules from call graph.

## Acceptance Criteria

- [x] Create `CodeIntelligenceTracer.CallFilter` module
- [x] Define `@stdlib_modules` MapSet:
  - Enum, Map, List, Keyword, String, Integer, Float
  - Tuple, MapSet, Range, Stream, File, IO, Path
  - Regex, URI, Base, Date, DateTime, Time, NaiveDateTime
  - Access, Agent, Application, Task, GenServer, Supervisor
  - Process, Node, Port, System, Code, Macro, Module
  - Kernel, Protocol, Exception, Logger, etc.
- [x] Special forms handled in CallExtractor (not duplicated here)
- [x] Implement `should_include?/1` and `should_include?/2`
  - Filter out Erlang modules (lowercase, no dots)
  - Filter out stdlib modules
  - Optionally filter to only known_modules
- [x] Implement `filter_calls/2` for batch filtering

## Files to Create

- `lib/code_intelligence_tracer/call_filter.ex`

## Tests

- Filter out `Enum.map` call
- Filter out `:erlang.+` call
- Keep project module calls
- Filter special forms like `if`, `case`
