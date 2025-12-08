# T009: Implement Call Filtering (Stdlib/Erlang)

**Priority:** P1 | **Phase:** 3 - Basic Call Graph Extraction
**Features:** F4.3
**Depends On:** T008

## Description

Filter out stdlib and Erlang modules from call graph.

## Acceptance Criteria

- [ ] Create `CodeIntelligenceTracer.CallFilter` module
- [ ] Define `@stdlib_modules` list:
  - Enum, Map, List, Keyword, String, Integer, Float
  - Tuple, MapSet, Range, Stream, File, IO, Path
  - Regex, URI, Base, Date, DateTime, Time, NaiveDateTime
  - Access, Agent, Application, Task, GenServer, Supervisor
  - Process, Node, Port, System, Code, Macro, Module
  - Kernel, Protocol, Exception, Logger, etc.
- [ ] Define `@special_forms` list:
  - `__block__`, `__aliases__`, `case`, `cond`, `for`, `fn`, `if`
  - `quote`, `receive`, `require`, `try`, `unless`, `with`, etc.
- [ ] Implement `should_include?/2` (callee_module, known_modules)
  - Filter out Erlang modules (starts with ":")
  - Filter out stdlib modules
  - Filter out special forms
  - Optionally filter to only known_modules

## Files to Create

- `lib/code_intelligence_tracer/call_filter.ex`

## Tests

- Filter out `Enum.map` call
- Filter out `:erlang.+` call
- Keep project module calls
- Filter special forms like `if`, `case`
