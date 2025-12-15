# Output Format

This document describes the output formats produced by `ex_ast`.

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
  "total_structs": 15,
  "extraction_time_ms": 47
}
```

| Field | Type | Description |
|-------|------|-------------|
| `modules_processed` | integer | Total number of BEAM modules analyzed |
| `modules_with_debug_info` | integer | Modules with extractable debug info |
| `modules_without_debug_info` | integer | Modules missing debug info (compiled without `:debug_info`) |
| `total_calls` | integer | Total function calls extracted |
| `total_functions` | integer | Total function clauses extracted |
| `total_specs` | integer | Total `@spec` definitions extracted |
| `total_types` | integer | Total `@type`/`@opaque` definitions extracted |
| `total_structs` | integer | Total struct definitions extracted |
| `extraction_time_ms` | integer | Time taken for extraction in milliseconds |

### `calls`
Array of function call records. Each call represents a function invoking another function. This includes direct function calls and function captures.

```json
{
  "type": "local",
  "caller": {
    "module": "MyApp.Module",
    "function": "my_function/2",
    "kind": "def",
    "file": "/path/to/source.ex",
    "line": 42
  },
  "callee": {
    "module": "MyApp.Module",
    "function": "helper_function",
    "arity": 1
  }
}
```

**Call record fields:**

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `"local"` (same module) or `"remote"` (different module) |
| `caller` | object | Information about the calling function |
| `callee` | object | Information about the called function |

**Caller fields:**

| Field | Type | Description |
|-------|------|-------------|
| `module` | string | Module containing the caller |
| `function` | string | Function name with arity (e.g., `"my_function/2"`) |
| `kind` | string | `"def"`, `"defp"`, `"defmacro"`, or `"defmacrop"` |
| `file` | string | Absolute path to source file |
| `line` | integer | Line number where the call occurs |

**Callee fields:**

| Field | Type | Description |
|-------|------|-------------|
| `module` | string | Target module (same as caller module for local calls) |
| `function` | string | Function name being called |
| `arity` | integer | Number of arguments in the call |

**Function Captures:**
Function captures (e.g., `&Module.function/arity` and `&function/arity`) are included in the calls array with the same structure as regular function calls. They are identified by the line number of the capture expression.

**Excluded Calls:**
The following are excluded from the calls array:
- Special forms and language constructs (`if`, `case`, `cond`, `try`, `receive`, `for`, `with`, `quote`, `fn`, etc.)
- Operators (`=`, `==`, `+`, `-`, `*`, `/`, `and`, `or`, `&&`, `||`, etc.)
- Module directives (`import`, `require`, `alias`, `use`, `def`, `defp`, etc.)
- Language features (`::`, `->`, `<-`, `:=`, `@`, `&` when not used as function capture)

### `function_locations`
Map of modules to their function clause definitions. Each clause of a multi-clause function is a separate entry, keyed by `"function_name/arity:line"`.

```json
{
  "MyApp.Module": {
    "my_function/2:10": {
      "name": "my_function",
      "arity": 2,
      "line": 10,
      "start_line": 10,
      "end_line": 18,
      "kind": "def",
      "guard": null,
      "pattern": "x, y",
      "source_file": "lib/my_app/module.ex",
      "source_file_absolute": "/path/to/project/lib/my_app/module.ex",
      "source_sha": "a1b2c3d4e5f6...",
      "ast_sha": "f6e5d4c3b2a1...",
      "generated_by": null,
      "macro_source": null,
      "complexity": 3,
      "max_nesting_depth": 2
    },
    "my_function/2:15": {
      "name": "my_function",
      "arity": 2,
      "line": 15,
      "start_line": 15,
      "end_line": 22,
      "kind": "def",
      "guard": "is_list(y)",
      "pattern": "x, y",
      "source_file": "lib/my_app/module.ex",
      "source_file_absolute": "/path/to/project/lib/my_app/module.ex",
      "source_sha": "b2c3d4e5f6a1...",
      "ast_sha": "e5d4c3b2a1f6...",
      "generated_by": null,
      "macro_source": null,
      "complexity": 2,
      "max_nesting_depth": 1
    }
  }
}
```

**Function clause fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Function name without arity |
| `arity` | integer | Number of arguments |
| `line` | integer | Line number where clause is defined |
| `start_line` | integer | Start line of the clause (same as `line`) |
| `end_line` | integer | End line of the clause (computed from AST body) |
| `kind` | string | `"def"`, `"defp"`, `"defmacro"`, or `"defmacrop"` |
| `guard` | string or null | Guard expression as string, or `null` if no guard |
| `pattern` | string | Function arguments as human-readable string |
| `source_file` | string | Relative path to source file |
| `source_file_absolute` | string | Absolute path to source file |
| `source_sha` | string or null | SHA256 hash of source code (null if unavailable) |
| `ast_sha` | string | SHA256 hash of normalized AST |
| `generated_by` | string or null | Module that generated this function, or `null` |
| `macro_source` | string or null | Library location where macro is defined, or `null` |
| `complexity` | integer | Cyclomatic complexity (>= 1) |
| `max_nesting_depth` | integer | Maximum nesting depth of control structures (>= 0) |

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

**Macro-generated function fields:**
- `generated_by` - Module that generated this function (e.g., `"Phoenix.Endpoint"`, `"Kernel"`), or `null` for regular functions
- `macro_source` - Library source location where the macro is defined (e.g., `"lib/phoenix/endpoint.ex:552"`), or `null` if not available

For macro-generated functions (e.g., from `use GenServer`, `defstruct`):
- `end_line` equals `start_line` (body AST contains library line numbers)
- `generated_by` identifies the generating module
- `macro_source` points to the library source when available

**Complexity field:**
- `complexity` - Cyclomatic complexity of the function clause (integer >= 1)

Complexity is calculated by counting decision points:
- Base complexity: 1
- `case` clauses: +1 per clause beyond the first
- `cond` clauses: +1 per clause beyond the first
- `if`/`unless`: +1
- `with` match clauses: +1 per `<-` clause, +1 per `else` clause
- `try`/`rescue`/`catch`: +1 per rescue/catch clause
- `receive` clauses: +1 per clause beyond the first
- `and`/`or`/`&&`/`||`: +1 (short-circuit evaluation)

**Max Nesting Depth field:**
- `max_nesting_depth` - Maximum nesting depth of control structures (integer >= 0)

Max nesting depth is calculated by tracking the deepest level of nested control structures:
- Base depth: 0
- Nesting-introducing constructs: `with`, `case`, `cond`, `if`, `unless`, `try`, `for`, `fn`
- Each level of nesting increments the depth counter

Examples:
- Simple expression with no control structures: depth = 0
- Single `if` statement: depth = 1
- `if` nested inside a `case`: depth = 2
- Function definition with single-level nesting: depth = 1

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
          "input_strings": ["String.t()", "integer()"],
          "return_strings": ["{:ok, term()}", "{:error, String.t()}"],
          "full": "@spec my_function(String.t(), integer()) :: {:ok, term()} | {:error, String.t()}"
        }
      ]
    }
  ]
}
```

**Spec fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Function name |
| `arity` | integer | Number of arguments |
| `kind` | string | `"spec"` or `"callback"` |
| `line` | integer | Line number where spec is defined |
| `clauses` | array | List of spec clauses (most specs have one) |

**Clause fields:**

| Field | Type | Description |
|-------|------|-------------|
| `input_strings` | array of strings | Each input type as a formatted string |
| `return_strings` | array of strings | Each return type as a formatted string (union types are split) |
| `full` | string | Complete spec as it would appear in source code |

**Note on `return_strings`:** Union return types are split into individual strings. For example, a spec returning `atom() | binary() | :error` produces:
```json
"return_strings": ["atom()", "binary()", ":error"]
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
      "kind": "type",
      "params": ["t"],
      "line": 5,
      "definition": "@type my_type(t) :: %{value: t, count: integer()}"
    }
  ]
}
```

**Type fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Type name |
| `kind` | string | `"type"`, `"typep"`, or `"opaque"` |
| `params` | array of strings | Type parameters (empty array if none) |
| `line` | integer | Line number where type is defined |
| `definition` | string | Complete type definition as it would appear in source |

**Type kinds:**
- `type` - Public type (`@type`)
- `typep` - Private type (`@typep`)
- `opaque` - Opaque type (`@opaque`)

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

**Struct fields:**

| Field | Type | Description |
|-------|------|-------------|
| `fields` | array | List of field definitions |

**Field properties:**

| Field | Type | Description |
|-------|------|-------------|
| `field` | string | Field name |
| `default` | string | Default value as string representation (e.g., `"nil"`, `"0"`, `"[]"`) |
| `required` | boolean | Always `false` (see note below) |

**Note on `@enforce_keys`:**
The `@enforce_keys` directive information is not preserved in BEAM debug info as it's only used at compile time. Therefore, the `required` field is always `false`. To determine which fields are enforced at runtime, you would need to inspect the source code directly.

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
    "total_structs": 1,
    "extraction_time_ms": 15
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
        "start_line": 12,
        "end_line": 18,
        "kind": "def",
        "guard": null,
        "pattern": "name",
        "source_file": "lib/greeter.ex",
        "source_file_absolute": "/home/user/my_app/lib/greeter.ex",
        "source_sha": "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
        "ast_sha": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
        "generated_by": null,
        "macro_source": null,
        "complexity": 2,
        "max_nesting_depth": 1
      },
      "format_name/1:20": {
        "name": "format_name",
        "arity": 1,
        "line": 20,
        "start_line": 20,
        "end_line": 23,
        "kind": "defp",
        "guard": null,
        "pattern": "name",
        "source_file": "lib/greeter.ex",
        "source_file_absolute": "/home/user/my_app/lib/greeter.ex",
        "source_sha": "fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
        "ast_sha": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
        "generated_by": null,
        "macro_source": null,
        "complexity": 1,
        "max_nesting_depth": 0
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
            "input_strings": ["String.t()"],
            "return_strings": ["String.t()"],
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
./ex_ast -f toon -o ex_ast.toon /path/to/project
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
  extraction_time_ms: 15
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
      start_line: 20
      end_line: 23
      kind: defp
      guard: ~
      pattern: name
      source_file: lib/greeter.ex
      source_file_absolute: /home/user/my_app/lib/greeter.ex
      source_sha: fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321
      ast_sha: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
      generated_by: ~
      macro_source: ~
      complexity: 1
      max_nesting_depth: 0
    greet/1:12:
      name: greet
      arity: 1
      line: 12
      start_line: 12
      end_line: 18
      kind: def
      guard: ~
      pattern: name
      source_file: lib/greeter.ex
      source_file_absolute: /home/user/my_app/lib/greeter.ex
      source_sha: a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890
      ast_sha: 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
      generated_by: ~
      macro_source: ~
      complexity: 2
      max_nesting_depth: 1
specs:
  MyApp.Greeter[1]:
    - arity: 1
      clauses[1]:
        - full: "@spec greet(String.t()) :: String.t()"
          input_strings[1]: String.t()
          return_strings[1]: String.t()
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
