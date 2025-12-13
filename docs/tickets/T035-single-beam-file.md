# T035: Process BEAM File(s) via CLI

**Status:** COMPLETED

**Priority:** P1 | **Phase:** 11 - CLI Enhancements
**Features:** F11
**Depends On:** T028

## Description

Add support for processing one or more BEAM files specified via command line arguments, bypassing the normal project discovery and app filtering logic.

## Motivation

- Useful for debugging extraction on specific modules
- Quick inspection of module(s) calls/functions without processing entire project
- Enables targeted analysis without full build directory scan

## Acceptance Criteria

- [x] Add `--file` / `-f` CLI option to specify BEAM file path(s)
- [x] Support multiple `-f` options to process multiple files
- [x] When `--file` is provided:
  - Skip build directory discovery
  - Skip app filtering
  - Process only the specified BEAM file(s)
  - Still generate output in requested format (JSON/TOON)
- [x] Validate all files exist and have `.beam` extension
- [x] Return appropriate error for invalid/missing file
- [x] Update help text to document new option
- [x] Default output to `extracted_trace.json` in current directory

## CLI Usage

```bash
# Process single BEAM file
./ex_ast --file _build/dev/lib/my_app/ebin/Elixir.MyApp.Module.beam

# Process multiple BEAM files
./ex_ast -f A.beam -f B.beam -f C.beam

# With output format (note: -F for format, -f for file)
./ex_ast -f path/to/Module.beam -F toon

# With output path
./ex_ast -f path/to/Module.beam -o output.json
```

## Implementation Notes

- Added `--file` / `-f` option to CLI with `:keep` to allow multiple values
- Changed `-f` from format to file, format now uses `-F`
- `Extractor.run_files/2` handles file(s) extraction with parallel processing
- Reuses `process_beam_file/2` for extraction (shared with project mode)
- Added `extract_from_files/1` for parallel processing of multiple files
- Added `record_module_stats/6` helper shared by both modes
- File mode sets `project_type: nil` to distinguish from project mode
- Default output filename changed from `ex_ast.json` to `extracted_trace.json`
- File mode outputs to current working directory (not BEAM file directory)

## Files Modified

- `lib/code_intelligence_tracer/cli.ex` - Added option parsing, validation, dispatch
- `lib/code_intelligence_tracer/extractor.ex` - Added `run_files/2` and helper functions

## Tests Added

- CLI parses `--file` and `-f` options correctly
- CLI collects multiple `-f` options into list
- Validates `.beam` extension for all files
- Validates all files exist
- `Extractor.run_files/2` extracts from single file
- `Extractor.run_files/2` extracts from multiple files
- Handles mix of valid and invalid BEAM files
- Output generation works in file(s) mode
