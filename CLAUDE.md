# Elixir Project Guidelines

## Build & Test Commands

- `mix compile` - Compile the project
- `mix test` - Run all tests
- `mix test path/to/test.exs` - Run a specific test file
- `mix test path/to/test.exs:42` - Run test at specific line
- `mix format` - Format code
- `mix format --check-formatted` - Check formatting without changes
- `mix credo` - Run static analysis (if available)
- `mix dialyzer` - Run type checking (if available)

## Code Style

- Follow standard Elixir conventions (snake_case for functions/variables, PascalCase for modules)
- Use pattern matching over conditionals when possible
- Prefer pipe operator `|>` for data transformations
- Keep functions small and focused
- Use `@doc` and `@spec` for public functions
- Run `mix format` before committing
- Never use nested conditional blocks (nested `case`, `if`, `cond`). Use `with` blocks instead to flatten control flow.

## Function Naming Conventions

Consistent naming makes the codebase easier to navigate and understand:

### Extraction Functions
```
extract_*  → Primary extraction functions
extract_functions/2
extract_specs/1
extract_calls/3
extract_types/1
```

### Parsing Functions
```
parse_*  → Parse raw data into normalized structures
parse_spec_clause/1
parse_type_ast/1
```

### Formatting Functions
```
format_*  → Format data for output/display
format_spec/1
format_clause/3
format_type_string/1
```

### Computation Functions
```
compute_*  → Compute derived values (complexity, hashes, etc.)
compute_complexity/1
compute_max_nesting_depth/1
compute_source_sha/3
compute_ast_sha/1
```

### Normalization Functions
```
normalize_*  → Transform/normalize AST/data structures
normalize_guard_ast/1
normalize_ast/1
```

### Conversion Functions
```
*_to_*  → Type conversions and transformations
module_to_string/1
atom_to_string/1
args_to_string/1
```

### Helper Functions
```
*_from_*  → Extract from specific formats (internal helpers)
(used sparingly; most helpers just use descriptive names)
```
