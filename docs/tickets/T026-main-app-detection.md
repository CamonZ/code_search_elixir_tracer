# T026: Detect Main Application from mix.exs

**Priority:** P1 | **Phase:** 9 - Main Application Detection
**Features:** F2.2
**Depends On:** T003

## Description

Parse mix.exs to determine main app name.

## Acceptance Criteria

- [x] Implement `detect_main_app/1` (project_path) in BuildDiscovery
  - Read mix.exs file
  - Use regex to find `app: :app_name` in project/0 function
  - Return app name as string or `nil` if not found
  - **Implemented as `parse_app_name/1` and `find_project_apps/1`**
- [x] Handle various formatting styles:
  - `app: :my_app`
  - `app:  :my_app` (extra space)
  - Multi-line project definitions
  - **Handled via `~r/app:\s*:(\w+)/` regex**

## Files to Modify

- `lib/code_intelligence_tracer/build_discovery.ex`

## Tests

- Detect app from standard mix.exs
- Handle various formatting styles
- Return nil for missing mix.exs
- Return nil if app not found in file
