# Multi-Agent Ralph v2.84.0

> "Me fail English? That's unpossible!" - Ralph Wiggum

**Smart Memory-Driven Orchestration** with GLM-5 Agent Teams, native hooks, quality-first validation, and adversarial-validated system.

> **🆕 v2.84.0**: **GLM-5 Agent Teams Integration** - Native TeammateIdle/TaskCompleted hooks, project-scoped storage, reasoning capture. See [docs/architecture/GLM5_AGENT_TEAMS_INTEGRATION_PLAN_v2.84.md](docs/architecture/GLM5_AGENT_TEAMS_INTEGRATION_PLAN_v2.84.md)

---

## Quick Start

```bash
# Orchestration
/orchestrator "Implement OAuth2 authentication"
ralph orch "Migrate database"

# Quality
/gates          # Quality gates
/adversarial    # Spec refinement

# GLM-5 Agent Teams (v2.84.0)
.claude/scripts/glm5-init-team.sh "my-team"
.claude/scripts/glm5-teammate.sh coder "Implement auth" "auth-001"
```

---

## Commands

| Command | Description |
|---------|-------------|
| `/orchestrator` | Main orchestration entry point |
| `/gates` | Quality gate validation |
| `/adversarial` | Specification refinement |
| `/loop` | Iterative execution until VERIFIED_DONE |
| `/bug` | Systematic debugging |
| `/security` | Security audit |
| `/parallel` | Parallel review |

---

## GLM-5 Agent Teams (v2.84.0)

### Agents

| Agent | Role |
|-------|------|
| `glm5-coder` | Implementation & refactoring |
| `glm5-reviewer` | Code review & quality |
| `glm5-tester` | Test generation |
| `glm5-orchestrator` | Multi-agent coordination |

### Hooks (Native v2.1.33+)

| Hook | When it fires |
|------|---------------|
| `TeammateIdle` | Teammate about to go idle |
| `TaskCompleted` | Task marked complete |

### File Structure

```
.ralph/
├── teammates/     # Teammate status
├── reasoning/     # GLM-5 reasoning
├── agent-memory/  # Agent memory
├── logs/          # Activity logs
└── team-status.json
```

### Usage

```bash
# Initialize
.claude/scripts/glm5-init-team.sh "team-name"

# Spawn
.claude/scripts/glm5-teammate.sh <role> "<task>" "<task-id>"

# Status
cat .ralph/team-status.json
```

---

## Hooks System

**Total**: 83+ hooks | **Status**: 100% validated

Key hooks:
- `UserPromptSubmit`: Command routing, context warning
- `PreToolUse`: Security guards, validation
- `PostToolUse`: Quality gates, learning
- `SessionStart`: State restoration
- **`TeammateIdle`**: GLM-5 teammate tracking (NEW)
- **`TaskCompleted`**: GLM-5 task completion (NEW)

---

## Memory System

- **Semantic**: Facts and knowledge
- **Episodic**: Experiences and events
- **Working**: Current context

Access: `~/.ralph/memory/` or `.ralph/agent-memory/`

---

## Configuration

Key files:
- `.claude/CLAUDE.md` - Project instructions
- `.claude/settings.json` - Project settings
- `~/.claude-sneakpeek/zai/config/settings.json` - Global settings

---

## Documentation

| Topic | Location |
|-------|----------|
| Architecture | `docs/architecture/` |
| Hooks | `docs/hooks/` |
| Commands | `docs/command-router/` |
| GLM-5 Integration | `docs/architecture/GLM5_*.md` |
| Testing | `tests/agent-teams/` |

---

## Testing

```bash
# All tests
./tests/agent-teams/test-glm5-teammates.sh

# Expected: 20/20 PASSED
```

---

## Language Policy

| Content | Language |
|---------|----------|
| Code | English |
| Documentation | English |
| Chat | User's language |

---

## Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| **v2.84.0** | 2026-02-12 | GLM-5 Agent Teams, native hooks |
| v2.83.1 | 2026-01-28 | Hook system audit, race condition fixes |
| v2.82.0 | 2026-01-26 | Intelligent command router |
| v2.81.0 | 2026-01-22 | Swarm mode integration |

---

*For detailed documentation, see `docs/` directory.*
