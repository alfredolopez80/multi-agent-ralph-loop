# Multi-Agent Ralph v3.0.0

Orchestration system with memory-driven planning, multi-agent coordination, automatic learning, and quality validation.

## Parallel-First Execution (MANDATORY)

**All independent tasks MUST be executed in parallel using Agent Teams.** This is the #1 operational priority.

| Complexity | Execution Mode | Agent Teams |
|---|---|---|
| 1-2 | Direct execution (no team) | Optional |
| 3+ | **Parallel with Agent Teams** | **REQUIRED** |

**6 Ralph Teammates available for parallel spawning:**

| Teammate | Role | Spawn When |
|---|---|---|
| `ralph-coder` | Implementation | Code changes needed |
| `ralph-reviewer` | Code review | Post-implementation |
| `ralph-tester` | Testing & QA | Tests needed (always with coder) |
| `ralph-researcher` | Research | Unknown patterns |
| `ralph-frontend` | Frontend (WCAG 2.1 AA) | UI/component changes |
| `ralph-security` | Security (6 pillars) | Auth, crypto, user input |

**Rule**: `.claude/rules/parallel-first.md`
**Anti-rationalization**: entries #38-#46 in `docs/reference/anti-rationalization.md`

## Analysis Methodology

**Aristotle First Principles** is the foundational methodology. Every task passes through these phases before execution:

| Complexity | Phases | Duration |
|---|---|---|
| 1-3 | Phase 1 (Assumption Autopsy) + Phase 5 (Aristotelian Move) | 30s |
| 4+ | All 5 phases (Autopsy, Truths, Reconstruction, Map, Move) | 2-10 min |

Reference: `docs/reference/aristotle-first-principles.md`
Rule: `.claude/rules/aristotle-methodology.md`

## Configuration Location

**PRIMARY SETTINGS**: `~/.claude/settings.json`

This is the ONLY configuration file for Claude Code (all models: Claude, Zai, Minimax). All hooks, agents, and settings are configured here.

> **Reference material** (batch execution v2.88, skills/commands unification v2.87, GLM-5 flag, LSP integration, security fixes v2.89.2, test layout, docs map) moved to the lazy-loaded `ralph-reference` skill — invoke it when you need those detail tables.

### Global Infrastructure Validation

All rules, skills, and agents are symlinked from this repo to global directories (`~/.claude/`). Validate/repair:
```bash
bash ./scripts/validate-global-infrastructure.sh        # check
bash ./scripts/validate-global-infrastructure.sh --fix  # auto-fix broken symlinks
```

## Browser Automation (v3.0)

**Primary tool**: `agent-browser` (Vercel Labs) — isolated Chrome for Testing with domain allowlist and action policies.

| Config File | Purpose |
|---|---|
| `agent-browser.json` | Domain allowlist (localhost only by default) |
| `agent-browser-policy.json` | Action deny rules (passwords, wallets, seed phrases) |

Rule: `.claude/rules/browser-automation.md`

## Security (v3.0)

### Security Hooks

| Hook | Purpose | Trigger |
|------|---------|---------|
| `git-safety-guard.py` | Blocks rm -rf, git reset --hard, command chaining, and destructive aws/gcloud/gsutil/kubectl ops (deny + ask tiers, v2.70.0) | PreToolUse (Bash) |
| `repo-boundary-guard.sh` | Prevents operations outside current repo | PreToolUse (Bash) |
| `audit-secrets.js` | Audit logging for 20+ secret patterns | PostToolUse |
| `teammate-idle-quality-gate.sh` | Blocks idle with secrets/debug code (CWE-798, CWE-321) | TeammateIdle |
| `task-completed-quality-gate.sh` | 7 quality gates including hardcoded secrets + SQL injection | TaskCompleted |
| `cleanup-secrets-db.js` | Scans DB for exposed secrets | Manual |

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
| `ralph-frontend` | Frontend with DESIGN.md | LSP, Read, Edit, Write, Bash(npm/npx/bun/git) |
| `ralph-security` | Security specialist (6 pillars) | LSP, Read, Grep, Glob, Bash(audit/semgrep/gitleaks/git) |

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
/iterate "task"                # Iterative execution (renamed from /loop v2.94)
/task-batch <prd-file>         # Batch task execution (v2.88)
/create-task-batch "feature"   # Create PRD interactively (v2.88)
/gates                         # Quality validation
/autoresearch <target> <metric> # Autonomous experimentation (v2.94)
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

## Critical Hooks

These hooks must be registered in settings.json:

| Hook | Event | Purpose |
|------|-------|---------|
| `git-safety-guard.py` | PreToolUse (Bash) | Blocks rm -rf, git reset --hard, destructive aws/gcloud/kubectl |
| `repo-boundary-guard.sh` | PreToolUse (Bash) | Prevents work outside repo |
| `learning-gate.sh` | PreToolUse (Task) | Auto-learning trigger |
| `status-auto-check.sh` | PostToolUse | Status updates |
| `batch-progress-tracker.sh` | PostToolUse | Batch progress tracking (v2.88) |
| `teammate-idle-quality-gate.sh` | TeammateIdle | Quality checks before idle |
| `task-completed-quality-gate.sh` | TaskCompleted | Validation before completion |

Validation: `./scripts/validate-hooks-registration.sh`

### Hook Events (12 configured)

`SessionStart`, `SessionEnd`, `Stop`, `PreToolUse`, `PostToolUse`, `PreCompact`, `UserPromptSubmit`, `TeammateIdle`, `TaskCompleted`, `SubagentStart`, `SubagentStop`, `TaskCreated`

## Model Routing

| Complexity | Model |
|------------|-------|
| 1-4 | GLM-4.7 (primary) |
| 5-6 | Claude Sonnet |
| 7-10 | Claude Opus |

## Memory System (MemPalace v3.0)

### Layer Stack (SessionStart wake-up)

| Layer | File | Tokens (cl100k) | Purpose |
|-------|------|-----------------|---------|
| L0 | `~/.ralph/layers/L0_identity.md` | ~239 | Agent identity + principles |
| L1 | `~/.ralph/layers/L1_essential.md` | ~579 | 9 actionable rules (filtered from 1003) |
| L2 | `.claude/rules/learned/{halls,rooms,wings}/` | on-demand | Project-specific taxonomy |
| L3 | Obsidian vault grep | on-demand | Full knowledge base queries |

**Wake-up hook**: `.claude/hooks/wake-up-layer-stack.sh` loads L0+L1 at session start (~1050 tokens).

### Learned Rules Taxonomy

Rules organized in 3 dimensions for flexible retrieval:

| Dimension | Directory | Organization |
|-----------|-----------|--------------|
| **Halls** (by type) | `.claude/rules/learned/halls/` | decisions, patterns, anti-patterns, fixes |
| **Rooms** (by topic) | `.claude/rules/learned/rooms/` | hooks, memory, agents, security, testing |
| **Wings** (by scope) | `.claude/rules/learned/wings/` | `_global/`, `multi-agent-ralph-loop/` |

**L1 Filter**: Mechanical noise excluded (`ep-auto-*`, `ep-rule-*`), substantive filter (behavior >= 20 chars), criticality bonus (1.5x for CRITICAL/MUST/NEVER).

### Agent Diaries

Each ralph agent has a diary in Obsidian vault:
- Location: `~/Documents/Obsidian/MiVault/agents/{agent-name}/diary/`
- 6 agents: ralph-coder, ralph-reviewer, ralph-tester, ralph-researcher, ralph-frontend, ralph-security

### Storage Locations

- Knowledge graph: `~/Documents/Obsidian/MiVault/` (primary)
- Layer files: `~/.ralph/layers/`
- Session ledgers: `~/.ralph/ledgers/`
- Session handoffs: `~/.ralph/handoffs/`

### Key Decisions

- **AAAK rejected** for LLM context (see `docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md`): PUA encoding increases cl100k_base tokens by +19.8%. Selection beats encoding.
- **claude-mem removed**: Full forensic removal (Wave 0). Data migrated to Obsidian vault.
- **Drift audit**: 18 findings documented in `docs/audit/CLAUDE_MD_DRIFT_2026-04-07.md`
- **Context deduplication**: Global rules are symlinks to repo (not copies), reducing context overhead by 29% (~10K tokens saved). Run `scripts/sync-rules.sh` to maintain.
- **Distribution policy**: See `docs/architecture/DISTRIBUTION_POLICY.md` for symlink vs copy strategy per component type.

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

Do not place tests in `.claude/tests/` (deprecated).

## Reference

Test layout, docs map, version history, and external doc links live in the lazy-loaded `ralph-reference` skill.
