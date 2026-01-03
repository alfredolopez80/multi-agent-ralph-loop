---
name: ast-search
description: "Hybrid search: ast-grep (structural) + Explore agent (semantic) - 75% less tokens"
argument-hint: "<pattern-or-query>"
---

# /ast-search - Hybrid Code Search (v2.23)

This command combines **ast-grep** (structural AST search) with **Explore agent** (semantic search) for comprehensive code discovery.

## Philosophy

**Use the right tool for the right query:**

| Query Type | Tool | Example |
|------------|------|---------|
| Code pattern | ast-grep | `console.log($MSG)` |
| Structure | ast-grep | `async function $NAME` |
| Semantic/meaning | Explore | "authentication functions" |
| Hybrid | Both | Find all auth-related async functions |

## Execution

When `/ast-search` is invoked:

### Step 1: Analyze the Query

Determine if the query is:
- **AST Pattern**: Contains `$VAR`, `$$$`, or looks like code syntax
- **Semantic Query**: Natural language describing what to find
- **Hybrid**: Needs both for comprehensive results

### Step 2: Choose Search Strategy

```yaml
# If AST pattern detected, ask user to confirm
AskUserQuestion:
  questions:
    - question: "What type of search do you need?"
      header: "Search"
      multiSelect: false
      options:
        - label: "AST Pattern (Recommended)"
          description: "Structural search: console.log($MSG), async function $NAME"
        - label: "Semantic Search"
          description: "Meaning-based: 'authentication functions'"
        - label: "Hybrid (both)"
          description: "Combine AST + semantic for maximum coverage"
```

### Step 3: Execute Search

#### AST-Only Search (via MCP)

```yaml
# Use ast-grep MCP tool directly (75% less tokens)
mcp__ast-grep__find_code:
  pattern: "$PATTERN"
  path: "./src"
  output_format: "text"

# For complex patterns
mcp__ast-grep__find_code_by_rule:
  rule: |
    id: custom-search
    language: typescript
    rule:
      pattern: $PATTERN
  path: "./src"
```

#### Semantic-Only Search (via Explore)

```yaml
Task:
  subagent_type: "Explore"
  prompt: |
    Search the codebase for: $QUERY

    Focus on:
    - Function names and purposes
    - Related modules and dependencies
    - Usage patterns
```

#### Hybrid Search (Both)

```yaml
# Step 1: ast-grep for exact patterns
mcp__ast-grep__find_code:
  pattern: "async function $NAME"
  path: "./src"
  output_format: "text"

# Step 2: Explore for context
Task:
  subagent_type: "Explore"
  prompt: |
    Using the AST results above, explore:
    - Related files and dependencies
    - Usage patterns of found functions
    - Semantic context
```

## Pattern Syntax (ast-grep)

| Pattern | Meaning | Example |
|---------|---------|---------|
| `$VAR` | Single node | `console.log($MSG)` |
| `$$$` | Multiple nodes | `function($$$)` |
| `$$VAR` | Optional nodes | `async $$AWAIT function` |

## Examples

### Example 1: Find Console Logs

```
User: /ast-search console.log($MSG)

Claude:
- Detected: AST pattern
- Using: ast-grep via MCP
- Result: Found 42 matches in 12 files
```

### Example 2: Find Authentication Code

```
User: /ast-search authentication functions

Claude:
- Detected: Semantic query
- Using: Explore agent
- Result: Found auth module in src/auth/, 8 related files
```

### Example 3: Hybrid - Async Auth Functions

```
User: /ast-search async authentication functions

Claude:
1. AST search: async function $NAME → 156 matches
2. Semantic filter: authentication related → 12 functions
3. Combined result: 12 async auth functions found
```

## Token Efficiency

| Search Type | Token Usage | vs Traditional |
|-------------|-------------|----------------|
| AST-only | ~75% less | Best for patterns |
| Semantic | Variable | Best for context |
| Hybrid | Optimized | Best coverage |

## Integration with Ralph

```bash
# CLI equivalent
ralph ast 'console.log($MSG)' src/
ralph ast 'async function $NAME' .
```

## Anti-Patterns

- Don't use AST search for semantic queries (inefficient)
- Don't use Explore for exact pattern matching (imprecise)
- Don't search entire codebase when path is known
- Don't repeat searches - cache results
