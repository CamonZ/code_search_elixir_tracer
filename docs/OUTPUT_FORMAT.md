# Output Format

This document describes the output formats produced by `call_graph`.

The tool supports two output formats:
- **JSON** (default) - Standard JSON format
- **TOON** - Token-Oriented Object Notation, optimized for LLM token efficiency

Both formats contain the same data structure, just encoded differently.

---

# JSON Format

Use `--format json` (default) to output JSON.

## Top-Level Structure

```json
{
  "generated_at": "2024-01-15T10:30:00.000000Z",
  "project_path": "/path/to/project",
  "environment": "dev",
  "extraction_metadata": { ... },
  "calls": [ ... ],
  "function_locations": { ... },
  "specs": { ... },
  "types": { ... },
  "structs": { ... }
}
```

## Fields

### `generated_at`
ISO 8601 timestamp of when the extraction was performed.

### `project_path`
Absolute path to the analyzed project.

### `environment`
Mix environment used for extraction (e.g., "dev", "test", "prod").

### `extraction_metadata`
Statistics about the extraction process:

```json
{
  "modules_processed": 50,
  "modules_with_debug_info": 45,
  "modules_without_debug_info": 5,
  "total_calls": 1234,
  "total_functions": 456,
  "total_specs": 120,
  "total_types": 30,
  "total_structs": 15
}
```

### `calls`
Array of function call records. Each call represents a function invoking another function.

```json
{
  "type": "local|remote",
  "caller": {
    "module": "MyApp.Module",
    "function": "my_function/2",
    "kind": "def|defp|defmacro|defmacrop",
    "file": "/path/to/source.ex",
    "line": 42
  },
  "callee": {
    "module": "OtherModule",
    "function": "other_function",
    "arity": 1
  }
}
```

**Call types:**
- `local` - Call to a function in the same module
- `remote` - Call to a function in a different module

**Caller kinds:**
- `def` - Public function
- `defp` - Private function
- `defmacro` - Public macro
- `defmacrop` - Private macro

### `function_locations`
Map of modules to their function clause definitions. Each clause of a multi-clause function is a separate entry, keyed by `"function_name/arity:line"`.

```json
{
  "MyApp.Module": {
    "my_function/2:10": {
      "name": "my_function",
      "arity": 2,
      "line": 10,
      "kind": "def",
      "guard": null,
      "pattern": "x, y",
      "source_file": "lib/my_app/module.ex",
      "source_file_absolute": "/path/to/project/lib/my_app/module.ex",
      "source_sha": "a1b2c3d4e5f6...",
      "ast_sha": "f6e5d4c3b2a1..."
    },
    "my_function/2:15": {
      "name": "my_function",
      "arity": 2,
      "line": 15,
      "kind": "def",
      "guard": "is_list(y)",
      "pattern": "x, y",
      "source_file": "lib/my_app/module.ex",
      "source_file_absolute": "/path/to/project/lib/my_app/module.ex",
      "source_sha": "b2c3d4e5f6a1...",
      "ast_sha": "e5d4c3b2a1f6..."
    }
  }
}
```

**Clause fields:**
- `name` - Function name without arity (e.g., `"my_function"`)
- `arity` - Number of arguments as integer
- `line` - Line number where this clause is defined
- `kind` - Function kind (`def`, `defp`, `defmacro`, `defmacrop`)
- `guard` - Guard expression as string, or `null` if no guard
- `pattern` - Function arguments as human-readable string (e.g., `"x, y"`, `"{:ok, value}"`)

**Guard examples:**
```json
"guard": null                           // no guard
"guard": "is_binary(x)"                 // simple guard
"guard": "is_integer(x) and x > 0"      // compound guard with `and`
"guard": "is_binary(x) or is_atom(x)"   // compound guard with `or`
```

**Pattern examples:**
```json
"pattern": "x"                          // simple variable
"pattern": "x, y"                       // multiple args
"pattern": "{:ok, value}"               // tuple pattern
"pattern": "{:error, _} = err"          // pattern with binding
"pattern": "%{name: name}"              // map pattern
```

**SHA fields:**
- `source_sha` - SHA256 hash of the source code for this clause. Detects any change (formatting, comments, code). May be `null` if the source file is unavailable.
- `ast_sha` - SHA256 hash of the normalized AST for this clause. Detects semantic changes only (ignores formatting, comments, line numbers).

### `specs`
Map of modules to their `@spec` definitions.

```json
{
  "MyApp.Module": [
    {
      "name": "my_function",
      "arity": 2,
      "kind": "spec",
      "line": 9,
      "clauses": [
        {
          "inputs_string": "String.t(), integer()",
          "return_string": "{:ok, term()} | {:error, String.t()}",
          "full": "@spec my_function(String.t(), integer()) :: {:ok, term()} | {:error, String.t()}"
        }
      ]
    }
  ]
}
```

**Spec kinds:**
- `spec` - Regular function spec
- `callback` - Behaviour callback spec

### `types`
Map of modules to their `@type` and `@opaque` definitions.

```json
{
  "MyApp.Module": [
    {
      "name": "my_type",
      "kind": "type|typep|opaque",
      "params": ["t"],
      "line": 5,
      "definition": "@type my_type(t) :: %{value: t, count: integer()}"
    }
  ]
}
```

**Type kinds:**
- `type` - Public type
- `typep` - Private type
- `opaque` - Opaque type

### `structs`
Map of modules to their struct definitions. Only modules that define structs are included.

```json
{
  "MyApp.User": {
    "fields": [
      {
        "field": "name",
        "default": "nil",
        "required": false
      },
      {
        "field": "email",
        "default": "nil",
        "required": false
      },
      {
        "field": "age",
        "default": "0",
        "required": false
      }
    ]
  }
}
```

## Example Output

A minimal example showing all sections:

```json
{
  "generated_at": "2024-01-15T10:30:00.000000Z",
  "project_path": "/home/user/my_app",
  "environment": "dev",
  "extraction_metadata": {
    "modules_processed": 2,
    "modules_with_debug_info": 2,
    "modules_without_debug_info": 0,
    "total_calls": 3,
    "total_functions": 4,
    "total_specs": 2,
    "total_types": 1,
    "total_structs": 1
  },
  "calls": [
    {
      "type": "local",
      "caller": {
        "module": "MyApp.Greeter",
        "function": "greet/1",
        "kind": "def",
        "file": "/home/user/my_app/lib/greeter.ex",
        "line": 15
      },
      "callee": {
        "module": "MyApp.Greeter",
        "function": "format_name",
        "arity": 1
      }
    }
  ],
  "function_locations": {
    "MyApp.Greeter": {
      "greet/1:12": {
        "name": "greet",
        "arity": 1,
        "line": 12,
        "kind": "def",
        "guard": null,
        "pattern": "name",
        "source_file": "lib/greeter.ex",
        "source_file_absolute": "/home/user/my_app/lib/greeter.ex",
        "source_sha": "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
        "ast_sha": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
      },
      "format_name/1:20": {
        "name": "format_name",
        "arity": 1,
        "line": 20,
        "kind": "defp",
        "guard": null,
        "pattern": "name",
        "source_file": "lib/greeter.ex",
        "source_file_absolute": "/home/user/my_app/lib/greeter.ex",
        "source_sha": "fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
        "ast_sha": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
      }
    }
  },
  "specs": {
    "MyApp.Greeter": [
      {
        "name": "greet",
        "arity": 1,
        "kind": "spec",
        "line": 11,
        "clauses": [
          {
            "inputs_string": "String.t()",
            "return_string": "String.t()",
            "full": "@spec greet(String.t()) :: String.t()"
          }
        ]
      }
    ]
  },
  "types": {
    "MyApp.Greeter": [
      {
        "name": "greeting_style",
        "kind": "type",
        "params": [],
        "line": 5,
        "definition": "@type greeting_style :: :formal | :casual"
      }
    ]
  },
  "structs": {
    "MyApp.User": {
      "fields": [
        {
          "field": "name",
          "default": "nil",
          "required": false
        }
      ]
    }
  }
}
```

---

# TOON Format

Use `--format toon` to output TOON (Token-Oriented Object Notation).

TOON is a compact data format optimized for LLM token efficiency, achieving 30-60% token reduction compared to JSON while maintaining readability. See [toon_ex](https://github.com/kentaro/toon_ex) for more information.

## Usage

```bash
./call_graph -f toon -o call_graph.toon /path/to/project
```

## Top-Level Structure

```yaml
generated_at: 2024-01-15T10:30:00.000000Z
project_path: /path/to/project
environment: dev
extraction_metadata:
  modules_processed: 50
  modules_with_debug_info: 45
  modules_without_debug_info: 5
  total_calls: 1234
  total_functions: 456
  total_specs: 120
  total_types: 30
  total_structs: 15
calls[N]: ...
function_locations: ...
specs: ...
types: ...
structs: ...
```

## Example Output

The same data as the JSON example, encoded in TOON:

```yaml
generated_at: 2024-01-15T10:30:00.000000Z
project_path: /home/user/my_app
environment: dev
extraction_metadata:
  modules_processed: 2
  modules_with_debug_info: 2
  modules_without_debug_info: 0
  total_calls: 3
  total_functions: 4
  total_specs: 2
  total_types: 1
  total_structs: 1
calls[1]:
  - callee:
      arity: 1
      function: format_name
      module: MyApp.Greeter
    caller:
      file: /home/user/my_app/lib/greeter.ex
      function: greet/1
      kind: def
      line: 15
      module: MyApp.Greeter
    type: local
function_locations:
  MyApp.Greeter:
    format_name/1:20:
      name: format_name
      arity: 1
      line: 20
      kind: defp
      guard: ~
      pattern: name
      source_file: lib/greeter.ex
      source_file_absolute: /home/user/my_app/lib/greeter.ex
      source_sha: fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321
      ast_sha: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
    greet/1:12:
      name: greet
      arity: 1
      line: 12
      kind: def
      guard: ~
      pattern: name
      source_file: lib/greeter.ex
      source_file_absolute: /home/user/my_app/lib/greeter.ex
      source_sha: a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890
      ast_sha: 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
specs:
  MyApp.Greeter[1]:
    - arity: 1
      clauses[1]:
        - full: "@spec greet(String.t()) :: String.t()"
          inputs_string: String.t()
          return_string: String.t()
      kind: spec
      line: 11
      name: greet
types:
  MyApp.Greeter[1]:
    - definition: "@type greeting_style :: :formal | :casual"
      kind: type
      line: 5
      name: greeting_style
      params[0]:
structs:
  MyApp.User:
    fields[1]:
      - default: nil
        field: name
        required: false
```

## Key Differences from JSON

- No quotes around simple string values
- Arrays use `[N]` notation to indicate length
- Nested structures use YAML-like indentation
- More compact representation overall
