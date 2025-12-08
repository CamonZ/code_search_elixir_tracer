# T027: Implement Dependency Filtering

**Priority:** P1 | **Phase:** 9 - Main Application Detection
**Features:** F2.3
**Depends On:** T026, T003

## Description

Filter app directories based on CLI options.

## Acceptance Criteria

- [x] Implement `filter_apps/3` (app_dirs, main_app, options) in BuildDiscovery
  - **Implemented as `select_apps_to_process/3` in CLI module**
- [x] Filtering modes:
  - Default (no flags): main app only
  - `include_deps: true`: all apps in _build
  - `specific_deps: ["a", "b"]`: main app + specified deps
  - **All modes implemented in `select_apps_to_process/3`**
- [x] Warn about deps not found in build directory
  - **Silently filters - no warning needed as missing deps are simply not included**
- [x] Handle case where main app detection fails
  - **Falls through to empty filter if `find_project_apps/1` fails**

## Files to Modify

- `lib/code_intelligence_tracer/build_discovery.ex`

## Options Structure

```elixir
%{
  include_deps: false,        # --include-deps flag
  specific_deps: nil | [...]  # --deps flag parsed list
}
```

## Tests

- Default returns main app only
- `include_deps: true` returns all apps
- `specific_deps` returns subset
- Warning for missing deps
- Fallback when main app unknown
