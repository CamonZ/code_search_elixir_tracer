# Data Structure Conventions

This document defines the standard data structures used throughout the codebase.

## Overview

These structures represent the main entities extracted from Elixir/Erlang code:
- Functions and their definitions
- Function calls
- Type specifications
- Type definitions
- Struct definitions

## Function Information

### Clause Info (Per-Clause Function Definition)

Represents a single clause of a function definition.

```elixir
@type clause_info :: %{
  name: String.t(),                    # "process_data"
  arity: non_neg_integer(),            # 2
  line: non_neg_integer(),             # 10 (clause definition line)
  start_line: non_neg_integer(),       # 10 (first line of clause)
  end_line: non_neg_integer(),         # 25 (last line of clause)
  kind: :def | :defp | :defmacro | :defmacrop,  # :def
  guard: String.t() | nil,            # "is_list(x)" or nil
  pattern: String.t(),                # "x, y" (args as string)
  source_file: String.t(),            # "lib/my_app/processor.ex" (relative)
  source_file_absolute: String.t(),   # "/full/path/lib/my_app/processor.ex"
  source_sha: String.t() | nil,       # "a1b2c3d4..." (source code hash)
  ast_sha: String.t(),                # "f6e5d4c3..." (normalized AST hash)
  generated_by: String.t() | nil,     # "Kernel" (for macro-generated)
  macro_source: String.t() | nil,     # "lib/foo.ex:10" (macro location)
  complexity: non_neg_integer(),      # 2 (cyclomatic complexity)
  max_nesting_depth: non_neg_integer()  # 1 (max nesting depth)
}
```

### Example: Multi-Clause Function

For function:
```elixir
def process(x) when is_list(x), do: "list"
def process(x) when is_number(x), do: "number"
def process(_x), do: "other"
```

Results in three entries (one per clause):
```elixir
%{
  "process/1:10" => %{line: 10, guard: "is_list(x)", pattern: "x", ...},
  "process/1:11" => %{line: 11, guard: "is_number(x)", pattern: "x", ...},
  "process/1:12" => %{line: 12, guard: nil, pattern: "_x", ...}
}
```

## Call Information

### Call Record

Represents a single function call in the code.

```elixir
@type call_record :: %{
  type: :remote | :local,  # Type of call
  caller: %{
    module: String.t(),      # "MyApp.Processor"
    function: String.t(),    # "run"
    kind: :def | :defp | :defmacro | :defmacrop,
    file: String.t(),        # Relative source file path
    line: non_neg_integer()   # Line where call occurs
  },
  callee: %{
    module: String.t(),      # "Enum" (for remote) or caller module (for local)
    function: String.t(),    # "map"
    arity: non_neg_integer(),  # 2
    args: String.t()         # "list, &transform/1" (NEW in T040)
  }
}
```

### Call Type

- **Remote**: `Module.function(args)` - Function in different module
- **Local**: `function(args)` - Function in same module
- **Capture**: `&Module.function/arity` - Function capture

### Example: Remote Call

```json
{
  "type": "remote",
  "caller": {
    "module": "MyApp.Processor",
    "function": "run",
    "kind": "def",
    "file": "lib/my_app/processor.ex",
    "line": 15
  },
  "callee": {
    "module": "Enum",
    "function": "map",
    "arity": 2,
    "args": "list, &transform/1"
  }
}
```

## Specification Information

### Spec Record

Represents a type specification (`@spec` or `@callback`).

```elixir
@type spec_record :: %{
  name: atom(),                        # :process
  arity: non_neg_integer(),            # 2
  kind: :spec | :callback,            # :spec
  line: non_neg_integer(),             # 9
  clauses: [term()]                    # Raw clauses from BEAM
}
```

### Formatted Spec

After formatting by `SpecFormatter`:

```elixir
@type formatted_spec :: %{
  kind: :spec | :callback,
  line: non_neg_integer(),
  clauses: [%{
    inputs_string: [String.t()],      # ["integer()", "binary()"]
    return_string: String.t(),        # "atom()"
    full: String.t()                  # "@spec process(integer(), binary()) :: atom()"
  }]
}
```

### Example: Spec with Multiple Clauses

```elixir
@spec process(integer()) :: atom()
@spec process(binary()) :: string()

# Raw record (before formatting):
%{
  name: :process,
  arity: 1,
  kind: :spec,
  line: 9,
  clauses: [...]  # Abstract syntax
}

# Formatted record (after formatting):
%{
  kind: :spec,
  line: 9,
  clauses: [
    %{
      inputs_string: ["integer()"],
      return_string: "atom()",
      full: "@spec process(integer()) :: atom()"
    },
    %{
      inputs_string: ["binary()"],
      return_string: "string()",
      full: "@spec process(binary()) :: string()"
    }
  ]
}
```

## Type Definition Information

### Type Record

Represents a type definition (`@type` or `@opaque`).

```elixir
@type type_record :: %{
  name: atom(),                        # :result
  kind: :type | :opaque,              # :type
  params: [atom()],                    # [:a, :b] (type variables)
  line: non_neg_integer(),             # 15
  definition: String.t()               # "@type result(a, b) :: {:ok, a} | {:error, b}"
}
```

### Example: Parameterized Type

```elixir
@type result(a, b) :: {:ok, a} | {:error, b}

# Result:
%{
  name: :result,
  kind: :type,
  params: [:a, :b],
  line: 15,
  definition: "@type result(a, b) :: {:ok, a} | {:error, b}"
}
```

## Struct Definition Information

### Struct Record

Represents a struct definition created with `defstruct`.

```elixir
@type struct_record :: %{
  name: atom(),                        # :user
  module: String.t(),                  # "MyApp.User"
  fields: %{
    atom() => term()                   # :id => nil, :name => ""
  },
  file: String.t(),                    # Relative source file
  line: non_neg_integer()               # Line where defstruct appears
}
```

### Example: Struct Definition

```elixir
defstruct id: nil, name: "", email: ""

# Result:
%{
  name: :user,
  module: "MyApp.User",
  fields: %{
    id: nil,
    name: "",
    email: ""
  },
  file: "lib/my_app/user.ex",
  line: 2
}
```

## Type AST Information

### Type AST Structure

Represents a parsed type from Erlang abstract format.

```elixir
@type type_ast ::
  %{type: :union, types: [type_ast()]}
  | %{type: :tuple, elements: [type_ast()]}
  | %{type: :list, element_type: type_ast() | nil}
  | %{type: :map, fields: :any | [map()]}
  | %{type: :fun, inputs: [type_ast()], return: type_ast()}
  | %{type: :type_ref, module: String.t() | nil, name: atom(), args: [type_ast()]}
  | %{type: :literal, kind: :atom | :integer, value: term()}
  | %{type: :builtin, name: atom()}
  | %{type: :var, name: atom()}
  | %{type: :any}
```

### Type Examples

```elixir
# Built-in: integer()
%{type: :builtin, name: :integer}

# Union: integer() | atom()
%{
  type: :union,
  types: [
    %{type: :builtin, name: :integer},
    %{type: :builtin, name: :atom}
  ]
}

# Type ref: String.t()
%{
  type: :type_ref,
  module: "String",
  name: :t,
  args: []
}

# Tuple: {:ok, String.t()}
%{
  type: :tuple,
  elements: [
    %{type: :literal, kind: :atom, value: :ok},
    %{type: :type_ref, module: "String", name: :t, args: []}
  ]
}

# Function: (integer() -> atom())
%{
  type: :fun,
  inputs: [%{type: :builtin, name: :integer}],
  return: %{type: :builtin, name: :atom}
}
```

## Module Grouping

### Functions by Module

Functions are grouped by module in output:

```elixir
%{
  "MyApp.Processor" => %{
    "process/2:10" => %{...},
    "process/2:15" => %{...},
    "helper/1:27" => %{...}
  },
  "MyApp.Formatter" => %{
    "format/1:5" => %{...}
  }
}
```

### Specs by Module

Specs are also grouped by module:

```elixir
%{
  "MyApp.Processor" => [
    %{name: :process, arity: 2, kind: :spec, ...},
    %{name: :helper, arity: 1, kind: :spec, ...}
  ]
}
```

## Common Patterns

### Nil vs Empty

Use `nil` to indicate absence:
- `guard: nil` - No guard clause
- `source_sha: nil` - Source file not readable
- `generated_by: nil` - User-defined function

Use empty collection for multiple items:
- `clauses: []` - No clauses found
- `fields: %{}` - Struct with no fields
- `params: []` - Type with no parameters

### Keys in Maps

Keys use atoms for internal data structures:
```elixir
%{name: "foo", arity: 2}  # keys are atoms
```

Keys use strings in JSON output:
```json
{
  "name": "foo",
  "arity": 2
}
```

### String Representations

Type and format strings use Elixir syntax:
- Type reference: `"String.t()"` not `"String.t/0"`
- Function spec: `"@spec foo(integer()) :: atom()"`
- Guard: `"is_binary(x)"`

## See Also

- [PARAMETER_FORMATTING.md](./PARAMETER_FORMATTING.md) - Naming conventions for fields and parameters
- [../../OUTPUT_FORMAT.md](../../OUTPUT_FORMAT.md) - JSON/TOON output structure
