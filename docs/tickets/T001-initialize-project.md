# T001: Initialize Elixir Project

**Priority:** P0 | **Phase:** 1 - Foundation
**Features:** Foundation
**Depends On:** None

## Description

Configure Mix project for escript build.

## Acceptance Criteria

- [x] Configure escript build in `mix.exs`:
  - `main_module: CodeIntelligenceTracer.CLI`
  - `name: "call_graph"`
- [x] Create placeholder `CodeIntelligenceTracer.CLI` module with `main/1` that prints "TODO"
- [x] Verify `mix compile` succeeds
- [x] Verify `mix escript.build` produces executable

## Files to Modify

- `mix.exs` - add escript config

## Files to Create

- `lib/code_intelligence_tracer/cli.ex` - placeholder module

## Verification

```bash
mix compile && mix escript.build
./call_graph  # Should print "TODO"
```
