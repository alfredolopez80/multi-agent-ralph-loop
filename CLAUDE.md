# Multi-Agent Ralph v2.84.3

Orchestration system with memory-driven planning, multi-agent coordination, automatic learning, and quality validation.

## Configuration Location

**Settings**: `~/.claude-sneakpeek/zai/config/settings.json` (Zai variant)

Do not use `~/.claude/settings.json` - that is the legacy location.

## Language Policy

| Content Type | Language |
|--------------|----------|
| Code | English |
| Documentation | English |
| Commit messages | English |
| Chat responses | Match user's language |

## Commands

```bash
# Orchestration
/orchestrator "task"           # Full workflow
/loop "task"                   # Iterative execution
/gates                         # Quality validation
/adversarial                   # Spec refinement

# Debugging
/bug "issue description"
/bugs src/

# Security
/security src/

# Learning
/curator full --type backend --lang typescript
/repo-learn https://github.com/owner/repo

# Context
/docs hooks                    # Hooks documentation
/docs mcp                      # MCP documentation
```

## GLM-5 Integration (v2.84.1)

All major commands support `--with-glm5` flag:
```bash
/orchestrator "task" --with-glm5
/loop "fix errors" --with-glm5
/security src/ --with-glm5
```

## Critical Hooks

These hooks must be registered in settings.json:

| Hook | Event | Purpose |
|------|-------|---------|
| `git-safety-guard.py` | PreToolUse (Bash) | Blocks rm -rf, git reset --hard |
| `repo-boundary-guard.sh` | PreToolUse (Bash) | Prevents work outside repo |
| `learning-gate.sh` | PreToolUse (Task) | Auto-learning trigger |
| `status-auto-check.sh` | PostToolUse | Status updates |

Validation: `./scripts/validate-hooks-registration.sh`

## Model Routing

| Complexity | Model |
|------------|-------|
| 1-4 | GLM-4.7 (primary) |
| 5-6 | Claude Sonnet |
| 7-10 | Claude Opus |

## Memory System

```bash
ralph memory-search "query"    # Search memory
ralph health                   # System check
ralph agent-memory init <agent>
```

Storage locations:
- Semantic: `~/.ralph/memory/semantic.json`
- Episodic: `~/.ralph/episodes/`
- Procedural: `~/.ralph/procedural/rules.json`

## Quality Gates

Validation stages:
1. CORRECTNESS (syntax, blocking)
2. QUALITY (types, blocking)
3. SECURITY (semgrep + gitleaks, blocking)
4. CONSISTENCY (linting, advisory)

3-Fix Rule: Maximum 3 attempts before escalation.

## Repository Isolation

When working in this repository, do not:
- Edit files in external repositories
- Run git commands on external repos
- Execute tests in other projects

Use `/repo-learn` to extract patterns from external repos.

## Test Organization

Tests in `tests/` at project root:
```
tests/
├── quality-parallel/
├── swarm-mode/
└── unit/
```

Do not place tests in `.claude/tests/` (deprecated).

## Documentation

All documentation in `docs/`:
- `docs/architecture/` - Design documents
- `docs/swarm-mode/` - Swarm mode guides
- `docs/security/` - Security documentation
- `docs/hooks/` - Hook reference

## References

- [claude-sneakpeek](https://github.com/mikekelly/claude-sneakpeek) - Zai variant
- [cc-mirror](https://github.com/numman-ali/cc-mirror) - Documentation patterns
- [Claude Code Docs](https://github.com/ericbuess/claude-code-docs) - Official docs mirror
