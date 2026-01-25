---
# VERSION: 2.69.0
name: repo-learn
prefix: "@repo-learn"
category: tools
color: green
description: "Learn best practices from GitHub repositories and enrich procedural memory"
argument-hint: "<repository-url> [--category <pattern>]"
hidden: false
---

# Repository Learner

Learn best practices from GitHub repositories to enrich Ralph's procedural memory (`~/.ralph/procedural/rules.json`).

## Usage

```
/repo-learn <repository-url> [--category <pattern_type>] [--min-confidence 0.8]
```

## Examples

```bash
# Learn from a specific repository
/repo-learn https://github.com/python/cpython

# Focus on specific pattern categories
/repo-learn https://github.com/tiangolo/fastapi --category error_handling

# Set minimum confidence threshold
/repo-learn https://github.com/facebook/react --category security --min-confidence 0.9
```

## What It Does

1. **Acquires** the repository via git clone or GitHub API
2. **Analyzes** code using AST-based pattern extraction for:
   - Python, TypeScript, Rust, Go, and generic files
3. **Classifies** patterns into categories:
   - `error_handling` - Exception patterns, Result types
   - `async_patterns` - Async/await, Promise patterns
   - `type_safety` - Type guards, generics
   - `architecture` - Design patterns, DI
   - `testing` - Test patterns, fixtures
   - `security` - Auth, validation patterns
4. **Generates** procedural rules with confidence scores
5. **Enriches** `~/.ralph/procedural/rules.json` with deduplication

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--category` | Filter by pattern category | All categories |
| `--min-confidence` | Minimum confidence threshold | 0.8 |

## Output

After learning, you'll see:

```
Repository: https://github.com/org/repo
Files Analyzed: 150
Patterns Extracted: 45
Rules Generated: 32
High Confidence Rules (>=0.8): 28
Added to Procedural Memory: 28 rules

Next Session Context:
Claude will now consider learned patterns when:
- Implementing error handling
- Writing async code
- Designing architecture
- Writing tests
```

## Integration

Learned rules are automatically injected into subsequent Task calls via `procedural-inject.sh`:

```
Task: "/orchestrator Create REST API"

Claude receives:
- Task prompt
- "Based on past experience from {repo}:
   - Use async/await for I/O operations
   - Validate all inputs with type guards
   - Return structured error responses"
```

## Requirements

| Tool | Purpose |
|------|---------|
| `git` | Clone repositories |
| `gh` | GitHub CLI for API access |

## Safety

- **Read-only analysis**: Repository contents are not modified
- **Atomic writes**: `rules.json` updated atomically with backup
- **Rate limiting**: Respects GitHub API limits
- **Validation**: All generated rules validated before insertion
