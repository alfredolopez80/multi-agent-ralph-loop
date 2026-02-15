# Multi-Agent Ralph v2.88.0

Orchestration system with memory-driven planning, multi-agent coordination, automatic learning, and quality validation.

## Configuration Location

**PRIMARY SETTINGS**: `~/.claude/settings.json`

This is the ONLY configuration file for Claude Code. All hooks, agents, and settings are here.

> ⚠️ **NOT**: `~/.claude-sneakpeek/zai/config/settings.json` (Zai variant - legacy)

## Batch Task Execution (v2.88.0)

New skills for autonomous multi-task execution:

| Skill | Purpose | Usage |
|-------|---------|-------|
| `/task-batch` | Execute task lists autonomously | `/task-batch docs/prd/file.prq.md` |
| `/create-task-batch` | Interactive PRD creator | `/create-task-batch "Feature name"` |

**Key Features**:
- Handles MULTIPLE tasks (not single task)
- MANDATORY completion criteria per task
- VERIFIED_DONE validation guarantee
- Fresh context per task execution
- Auto-commit after each completed task

See: `docs/batch-execution/BATCH_SKILLS_v2.88.0.md`

## Skills/Commands Unification (v2.87.0)

**Unified Skills Model**: All commands now use the SKILL.md format per Claude Code best practices.

| Location | Purpose | Format |
|----------|---------|--------|
| `.claude/skills/<name>/SKILL.md` | Source of truth (repo) | Skill directory |
| `~/.claude/skills/<name>` | Symlink to repo | Symlink |

**Key Changes**:
- Removed duplicate command files from `~/.claude/commands/`
- All Ralph skills symlinked from global to repo
- Single source of truth: changes in repo reflect globally
- Version aligned to v2.87.0 across all skills

See: `docs/architecture/UNIFIED_ARCHITECTURE_v2.87.md`

## Security Hooks (v2.86.1)

| Hook | Purpose | Trigger |
|------|---------|---------|
| `sanitize-secrets.js` | Redacts 20+ secret patterns before saving | PostToolUse (before claude-mem) |
| `cleanup-secrets-db.js` | Scans DB for exposed secrets | Manual run |
| `procedural-forget.sh` | Removes obsolete patterns from memory | Manual/scheduled |

Secret patterns detected: GitHub PAT, OpenAI keys, AWS keys, Anthropic keys, JWT tokens, SSH keys, Ethereum private keys, Slack/Discord/Stripe tokens, database connection strings.

## Session Lifecycle Hooks (v2.86)

| Event | Hook | Purpose |
|-------|------|---------|
| `PreCompact` | pre-compact-handoff.sh | Save state BEFORE compaction |
| `SessionStart(compact)` | post-compact-restore.sh | Restore context AFTER compaction |
| `SessionEnd` | session-end-handoff.sh | Save state when session TERMINATES |

> **Note**: `PostCompact` event does NOT exist in Claude Code. Use `SessionStart(matcher="compact")` instead.

## Agent Teams (v2.86)

Agent Teams permite múltiples Claude Code instances trabajando en paralelo con un team lead coordinando.

### Nuevos Hooks

| Event | Purpose | Exit 2 Behavior |
|-------|---------|-----------------|
| `TeammateIdle` | Quality gate when teammate goes idle | Keep working + feedback |
| `TaskCompleted` | Quality gate before task completion | Prevent completion + feedback |
| `SubagentStart` | Load Ralph context into subagents | - |
| `SubagentStop` | Quality gates when subagent stops | - |

### Teammate Types

| Type | Role | Tools |
|------|------|-------|
| `ralph-coder` | Code implementation | Read, Edit, Write, Bash |
| `ralph-reviewer` | Code review | Read, Grep, Glob |
| `ralph-tester` | Testing & QA | Read, Edit, Write, Bash(test) |
| `ralph-researcher` | Research & exploration | Read, Grep, Glob, WebSearch |

### Crear Team

```bash
# Usando TeamCreate tool en Claude Code
TeamCreate(team_name="my-project", description="Working on feature X")

# Spawn teammates
Task(subagent_type="ralph-coder", team_name="my-project")
Task(subagent_type="ralph-reviewer", team_name="my-project")
```

### Agent Teams Configuration

Agent Teams está habilitado en `~/.claude/settings.json`:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

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
/task-batch <prd-file>         # Batch task execution (v2.88)
/create-task-batch "feature"   # Create PRD interactively (v2.88)
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
| `batch-progress-tracker.sh` | PostToolUse | Batch progress tracking (v2.88) |

Validation: `./scripts/validate-hooks-registration.sh`

## LSP Integration (v2.88.1)

Language Server Protocol for efficient code navigation:

| Skill | LSP Usage |
|-------|-----------|
| `/gates` | Type checking without reading files |
| `/security` | Navigate code during audits |
| `/code-reviewer` | Find references efficiently |
| `/lsp-explore` | Dedicated LSP navigation skill |

**Essential Language Servers:**
- `typescript-language-server` - TypeScript/JavaScript
- `pyright` - Python
- `clangd` - C/C++

**Installation:** `./scripts/install-language-servers.sh --essential`
**Validation:** `./scripts/install-language-servers.sh --check`

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
├── skills/               # Skill unit tests (v2.88)
│   ├── test-task-batch.sh
│   ├── test-create-task-batch.sh
│   └── test-batch-skills-integration.sh
├── quality-parallel/
├── swarm-mode/
└── unit/
```

Do not place tests in `.claude/tests/` (deprecated).

## Documentation

All documentation in `docs/`:
- `docs/architecture/` - Design documents
- `docs/batch-execution/` - Batch task execution (v2.88)
- `docs/swarm-mode/` - Swarm mode guides
- `docs/security/` - Security documentation
- `docs/hooks/` - Hook reference
- `docs/prd/` - Example PRD files

## References

- [claude-sneakpeek](https://github.com/mikekelly/claude-sneakpeek) - Zai variant
- [cc-mirror](https://github.com/numman-ali/cc-mirror) - Documentation patterns
- [Claude Code Docs](https://github.com/ericbuess/claude-code-docs) - Official docs mirror
