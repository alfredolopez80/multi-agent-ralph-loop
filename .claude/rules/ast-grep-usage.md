# ast-grep Structural Code Search

Use the ast-grep MCP tools for structural code search based on Abstract Syntax Tree (AST) pattern matching.

## Tool Selection: ast-grep vs Grep vs Glob

Choose the right tool based on the search type:

| Search Type | Tool | Why |
|-------------|------|-----|
| Text/string literals ("TODO", "FIXME", error messages) | **Grep** | Faster (~0.08s), no MCP overhead |
| File names and paths | **Glob** | Purpose-built for file matching |
| Relational patterns (X inside Y, function containing call) | **ast-grep** | Impossible with regex |
| Security audits (dangerous patterns in specific contexts) | **ast-grep** | Zero false positives, structural certainty |
| Refactoring (find all functions/classes matching a shape) | **ast-grep** | Returns complete code blocks, not lines |
| Multi-line structural patterns | **ast-grep** | Regex fails across line boundaries |
| Simple single-node patterns (`json.loads()`, `console.log()`) | **Grep** | Faster; use ast-grep only if false positives matter |

**Key trade-off**: Grep is ~30x faster in wall-clock time but produces false positives (matches in comments, strings, non-code contexts). ast-grep is slower (~2-3s MCP overhead) but structurally precise.

## When ast-grep is Required (Grep Cannot Do This)

- **Containment queries**: "find functions that contain `subprocess.run`" — Grep can only show co-occurrence in a file, not structural containment
- **Block extraction**: "find all `try/except` blocks catching `Exception`" — ast-grep returns the complete block (6-9 lines), Grep returns only the matching line
- **Negation with context**: "find `subprocess.run` calls WITHOUT `shell=True`" — requires AST-level understanding
- **Scope-aware search**: "find variables assigned inside a `with` block" — regex has no concept of scope

## Available MCP Tools

| Tool | Purpose |
|------|---------|
| `dump_syntax_tree` | Visualize AST structure of code. Use to debug non-matching patterns |
| `test_match_code_rule` | Test a YAML rule against a code snippet before searching |
| `find_code` | Search codebase with simple ast-grep patterns |
| `find_code_by_rule` | Advanced search with complex YAML rules (relational constraints) |

## General Process

1. Understand the user's query. Clarify ambiguities if needed.
2. Write a simple example code snippet matching the query.
3. Write an ast-grep rule that matches the example.
4. Test the rule with `test_match_code_rule` to verify it matches.
   - If rule fails, revise by removing sub-rules and debugging unmatching parts.
   - If using `inside` or `has` relational rules, add `stopBy: end`.
5. Search the codebase with `find_code` or `find_code_by_rule`.

## Tips for Writing Rules

- **Always use `stopBy: end`** for relational rules (`inside`, `has`, `precedes`, `follows`):
  ```yaml
  has:
    pattern: await $EXPR
    stopBy: end
  ```
- Use `pattern` for simple structures (function calls, variable names).
- Use `rule` for complex matching (find call inside certain function).
- If `pattern` fails, use `kind` to match node type first, then `has`/`inside` for structure.
- Use `dump_syntax_tree` to inspect target AST when debugging.

## Rule Development Process

1. Break down the query into smaller parts.
2. Identify sub-rules for each part.
3. Combine sub-rules using relational or composite rules.
4. If rule doesn't match, revise by removing sub-rules and debugging.
5. Use `dump_syntax_tree` to inspect AST.
6. Use `test_match_code_rule` to verify before searching.

## Rule Reference

### Atomic Rules

| Rule | Purpose | Example |
|------|---------|---------|
| `pattern` | Match by code pattern | `pattern: console.log($ARG)` |
| `kind` | Match by AST node type | `kind: call_expression` |
| `regex` | Match node text by regex | `regex: ^[a-z]+$` |
| `nthChild` | Match by position in parent | `nthChild: 1` |

### Relational Rules

| Rule | Purpose | Example |
|------|---------|---------|
| `inside` | Node must be inside parent | `inside: { pattern: "class $C { $$$ }", stopBy: end }` |
| `has` | Node must have descendant | `has: { pattern: "await $EXPR", stopBy: end }` |
| `precedes` | Node must appear before | `precedes: { pattern: "return $VAL" }` |
| `follows` | Node must appear after | `follows: { pattern: "import $M from '$P'" }` |

### Composite Rules

| Rule | Purpose | Example |
|------|---------|---------|
| `all` | All sub-rules must match (AND) | `all: [{ kind: call_expression }, { pattern: "foo($A)" }]` |
| `any` | Any sub-rule must match (OR) | `any: [{ pattern: "foo()" }, { pattern: "bar()" }]` |
| `not` | Sub-rule must NOT match | `not: { pattern: "console.log($ARG)" }` |
| `matches` | Match predefined utility rule | `matches: my-utility-rule-id` |

### Metavariables

| Syntax | Purpose | Example |
|--------|---------|---------|
| `$VAR` | Capture single named node | `console.log($ARG)` matches `console.log('hello')` |
| `$$VAR` | Capture single unnamed node (operators) | `$$OP` captures `+` in `a + b` |
| `$$$VAR` | Capture zero or more nodes | `foo($$$ARGS)` matches any arity |
| `_VAR` prefix | Non-capturing (performance) | `$_FUNC($_ARG)` matches without capture |

**Metavariable constraints**: Must be UPPERCASE (`$VAR` not `$var`), be the only text in a node, and cannot be embedded in strings or identifiers.

### Object Pattern Form

For ambiguous patterns, use the object form:
```yaml
pattern:
  selector: field_definition
  context: "class { $F }"
```

With strictness control:
```yaml
pattern:
  context: "foo($BAR)"
  strictness: relaxed  # cst | smart | ast | relaxed | signature
```

### stopBy Options

| Value | Behavior |
|-------|----------|
| `"neighbor"` | Default. Stop at immediate surrounding node |
| `"end"` | Search to root (inside) or leaf (has) |
| Rule object | Stop when surrounding node matches rule |

**When unsure, always use `stopBy: end`.**
