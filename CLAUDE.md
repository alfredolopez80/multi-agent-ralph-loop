# Multi-Agent Ralph v2.35

Orchestration with automatic planning, intensive clarification, git worktree isolation, adversarial validation, 9-language quality gates, context engineering, and automatic context preservation.

> **Historical versions**: See [CHANGELOG.md](./CHANGELOG.md) for v2.19-v2.34 details.

## v2.35 Current Features

### Context Preservation (100% Automatic)

| Event | Trigger | Action |
|-------|---------|--------|
| Session start | SessionStart hook | Loads ledger + handoff |
| Pre-compaction | PreCompact hook | Saves ledger + handoff |
| Context 70%+ | claude-hud | Yellow warning |
| Context 85%+ | claude-hud | Red warning |

**One-time setup**: `ralph setup-context-engine`

### Global Hooks Inheritance Pattern

Projects inherit hooks from `~/.claude/settings.json` automatically:

```
GLOBAL ~/.claude/
├── agents/            (27 agents)
├── commands/          (33 commands)
├── hooks/             (17 hooks)
└── settings.json      (6 hook types - INHERITED)

PROJECT .claude/
├── agents/            (synced from global)
├── commands/          (synced from global)
├── hooks/             (synced from global)
├── settings.local.json (permissions only)
└── NO settings.json   (inherits global)
```

**Benefits**: Zero maintenance, consistent behavior, updates apply everywhere.

**Commands**:
```bash
ralph sync-global                # Sync repo to global
ralph cleanup-project-settings   # Remove redundant settings.json
```

## Anthropic Best Practices

<investigate_before_answering>
Never speculate about code you have not opened. Read files BEFORE answering.
</investigate_before_answering>

<use_parallel_tool_calls>
Make independent tool calls in parallel, not sequentially.
</use_parallel_tool_calls>

<default_to_action>
Implement changes rather than only suggesting them.
</default_to_action>

<avoid_overengineering>
Only make changes that are directly requested. Keep solutions simple.
</avoid_overengineering>

## Ralph Loop Pattern (CRITICAL)

ALL tasks MUST follow this pattern:

```
EXECUTE → VALIDATE → Quality Passed? → YES → VERIFIED_DONE
                          ↓ NO
                      ITERATE (max 25)
                          ↓
                    Back to EXECUTE
```

**Iteration Limits**:
| Model | Max Iterations |
|-------|----------------|
| Claude (Sonnet/Opus) | 25 |
| MiniMax M2.1 | 50 |
| MiniMax-lightning | 100 |

**Quality Hooks**:
- `quality-gates.sh` → Post-Edit/Write (9 languages)
- `git-safety-guard.py` → Pre-Bash (validates git commands)

## Subagent Configuration

```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"  # MANDATORY - Haiku causes infinite retries
  run_in_background: true
```

**Why Sonnet + MiniMax?**
- Sonnet (60% cost): Manages subagents reliably
- MiniMax (8% cost): Second opinion with Opus-level quality
- Haiku: NOT recommended (30%+ rework rate)

## Mandatory Flow (8 Steps)

```
0. AUTO-PLAN    → EnterPlanMode (automatic)
1. /clarify     → AskUserQuestion (MUST_HAVE + NICE_TO_HAVE)
2. /classify    → Complexity 1-10
2b. WORKTREE    → Ask about worktree isolation
3. PLAN         → Write plan, get approval
4. @orchestrator → Delegate to subagents
5. ralph gates  → Quality gates (9 languages)
6. /adversarial → 2/3 consensus (if complexity >= 7)
7. /retrospective → Propose improvements
→ VERIFIED_DONE
```

## Quick Commands

```bash
# Core
ralph orch "task"         # Full orchestration
ralph gates               # Quality gates
ralph loop "task"         # Loop (25 iter)

# Review
ralph security src/       # Security audit
ralph bugs src/           # Bug hunting
ralph adversarial src/    # 2/3 consensus

# Git Worktree
ralph worktree "task"     # Create worktree
ralph worktree-pr <branch> # PR + review

# Context
ralph ledger save         # Save session state
ralph ledger load         # Load ledger
ralph handoff create      # Create handoff

# Sync
ralph sync-global         # Sync to ~/.claude/
ralph sync-to-projects    # Sync to all projects
```

## Agents (9)

```bash
# Critical (Opus)
@orchestrator       # Coordinator
@security-auditor   # Security
@debugger           # Bug detection

# Implementation (Sonnet)
@code-reviewer      # Code reviews
@test-architect     # Test generation
@refactorer         # Refactoring
@frontend-reviewer  # UI/UX

# Cost-effective (MiniMax - 8%)
@docs-writer        # Documentation
@minimax-reviewer   # Second opinion
```

## Hook Event Types (6)

| Hook | Purpose |
|------|---------|
| SessionStart | Context preservation at startup |
| PreCompact | Save state before compaction |
| PostToolUse | Quality gates after Edit/Write |
| PreToolUse | Safety guards before Bash/Skill |
| UserPromptSubmit | Context warnings, reminders |
| Stop | Session reports |

## Aliases

```bash
rh=ralph rho=orch rhs=security rhb=bugs rhg=gates
mm=mmc mml="mmc --loop 30"
```

## Completion

`VERIFIED_DONE` = plan approved + MUST_HAVE answered + classified + implemented + gates passed + adversarial passed (if critical) + retrospective done
