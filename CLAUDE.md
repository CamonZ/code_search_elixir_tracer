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
