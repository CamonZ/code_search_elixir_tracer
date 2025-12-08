# T036: Unified Output Module

## Problem

1. **Code Duplication**: `Output.JSON` and `Output.TOON` contain identical code (197 vs 189 lines) except for:
   - Module name and `@moduledoc`
   - The serialization call: `Jason.encode!(output, pretty: true)` vs `Toon.encode(output)`

2. **Default Output Extension Bug**: When `-o` is not specified, the default output is always `extracted_trace.json` regardless of the chosen format. Using `-F toon` still produces a `.json` file.

## Solution

Create a unified `Output` module that:
1. Contains all shared formatting logic
2. Dispatches to the appropriate serializer based on format
3. Generates the correct default filename with appropriate extension

## Implementation

### 1. Create `lib/code_intelligence_tracer/output.ex`

Move all formatting functions to the unified module:
- `format_calls/1`
- `format_function_locations/1`
- `format_function_info/1`
- `format_specs_by_module/1`
- `format_spec_record/1`
- `format_spec_clause/1`
- `format_types_by_module/1`
- `format_type_record/1`
- `format_structs_by_module/1`

Add unified public API:
- `generate(extractor, format)` - Returns serialized string based on format
- `write(extractor, output_path, format)` - Generates and writes to file
- `default_filename(format)` - Returns `"extracted_trace.json"` or `"extracted_trace.toon"`
- `extension(format)` - Returns `".json"` or `".toon"`

### 2. Update CLI

- Change `@default_options` to not have a hardcoded default output filename
- Add logic to compute default output based on format:
  ```elixir
  output = options[:output] || Output.default_filename(options.format)
  ```
- Replace `write_output/3` dispatch with single call to `Output.write/3`

### 3. Delete `lib/code_intelligence_tracer/output/json.ex` and `toon.ex`

After migrating all logic to the unified module.

### 4. Update Tests

- Update any tests that reference `Output.JSON` or `Output.TOON` directly
- Add tests for default filename generation based on format

## Acceptance Criteria

- [x] Single `Output` module handles both JSON and TOON formats
- [x] `./call_graph -F toon` produces `extracted_trace.toon` (not `.json`)
- [x] `./call_graph -F json` produces `extracted_trace.json`
- [x] Explicit `-o custom.ext` still works regardless of format
- [x] All existing tests pass
- [x] No code duplication between format handlers
