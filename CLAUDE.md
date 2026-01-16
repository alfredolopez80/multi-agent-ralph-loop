# Multi-Agent Ralph v2.43

## Multi-Agent Ralph Loop Orchestration

### Primary Commands (Always Available)

| Command | Description |
|---------|-------------|
| `/orchestrator` | **Full 8-step workflow**: clarify → classify → worktree → plan → execute → validate → retrospect |
| `/loop` | Execute until VERIFIED_DONE with quality gates |
| `/clarify` | Intensive AskUserQuestion (MUST_HAVE + NICE_TO_HAVE) |
| `/gates` | Quality validation (format, lint, tests) |
| `/adversarial` | Adversarial spec refinement (adversarial-spec) |
| `/retrospective` | Post-task analysis and improvements |
| `/parallel` | Run multiple loops concurrently |
| `/lsp-explore` | **NEW** Token-free code navigation via LSP |

### Orchestration Flow (8 Steps) - v2.43

```
0. AUTO-PLAN    → Enter Plan Mode (unless trivial)
1. CLARIFY      → AskUserQuestion intensively
1b. SOCRATIC    → Present 2-3 design alternatives (v2.42)
2. CLASSIFY     → Complexity 1-10, model routing
2b. WORKTREE    → Ask user about isolated worktree
3. PLAN         → Write plan, get approval
4. DELEGATE     → Route to model/agent
5. EXECUTE      → Parallel subagents + 3-Fix Rule (v2.42)
6. VALIDATE     → Two-Stage Review (v2.42):
                  Stage 1: Spec Compliance (gates)
                  Stage 2: Code Quality (adversarial)
7. RETROSPECT   → Analyze and improve
```

### Usage Examples

```bash
# Full orchestration for features
/orchestrator Implement user authentication with JWT

# Loop for iterative fixes
/loop "fix all type errors"

# Quality validation
/gates
/adversarial "Design a rate limiter service"
```

Orchestration with automatic planning, intensive clarification, git worktree isolation, adversarial validation, 9-language quality gates, context engineering, and automatic context preservation.

> **Historical versions**: See [CHANGELOG.md](./CHANGELOG.md) for v2.19-v2.41 details.

## v2.43 Context Engineering & LSP Integration

Based on Claude Code v2.0.71-v2.1.9 analysis (43+ improvements).

### New Features (v2.43)

| Feature | Description |
|---------|-------------|
| **claude-mem Integration** | SessionStart hook now integrates with claude-mem MCP for semantic context |
| **PreToolUse additionalContext** | Task calls receive session context automatically |
| **LSP-Explore Skill** | Token-free code navigation (90%+ savings) |
| **mcpToolSearchMode: auto:10** | Deferred MCP tool loading until 10% context usage |
| **Keybindings** | Custom shortcuts for orchestration commands |
| **Worktree Dashboard** | `ralph worktree-dashboard` for parallel work visibility |
| **tldr .gitignore** | Auto-adds `.tldr/` to .gitignore on `ralph tldr warm` |

### New Hooks (v2.43)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `inject-session-context.sh` | PreToolUse (Task) | Inject goal/progress into subagent context |
| Enhanced `session-start-ledger.sh` | SessionStart | claude-mem hints + context engineering tips |

### LSP Integration (90%+ Token Savings)

Use LSP tools for efficient code navigation without reading files:

```yaml
# Token comparison
Read entire file:     ~2000 tokens
LSP hover:            ~50 tokens (96% savings)
LSP go-to-definition: ~100 tokens (95% savings)
LSP find-references:  ~150 tokens (92% savings)
```

**Hybrid Pattern: llm-tldr + LSP**
1. `ralph tldr semantic "authentication"` → Find candidates
2. LSP go-to-definition → Navigate to implementation
3. LSP find-references → Understand usage
4. Read ONLY specific functions needed

### Codex CLI Security (v2.43)

**IMPORTANT**: `--yolo` replaced with `--full-auto` for safer defaults.

| Flag | Behavior | Use Case |
|------|----------|----------|
| `--full-auto` | Auto-approve workspace writes only | Default for all Codex calls |
| `--profile <name>` | Use security profile | `security-audit`, `code-review` |
| `CODEX_ALLOW_DANGEROUS=true` | Override safety gates | Trusted environments only |

### Git Operations Policy

- **MANDATORY**: Use `git` CLI or GitHub CLI (`gh`) for all git operations
- **DO NOT USE**: GitHub MCP or similar for git operations
- **Alternatives**: `mcp__gordon__git` for Gordon MCP users

### New CLI Commands (v2.43)

```bash
# Worktree visibility
ralph worktree-dashboard    # Show all worktrees with status

# Enhanced tldr (auto-adds .gitignore)
ralph tldr warm .           # Now auto-adds .tldr/ to .gitignore

# VERSION Markers (v2.43)
ralph add-version-markers            # Add VERSION: 2.43.0 to all config files
ralph add-version-markers --check    # Verify current versions
ralph add-version-markers --global   # Process global ~/.claude/ only

# Config Cleanup (v2.43)
ralph cleanup-project-configs        # Remove redundant local settings.json
```

### StatusLine Git Enhancement (v2.43)

Shows current branch/worktree in StatusLine:
- `⎇ main*` - Branch with uncommitted changes
- `⎇ feature ↑3` - Branch with 3 unpushed commits
- `⎇ fix-123 🌳worktree` - Worktree indicator

Configured via wrapper script: `~/.claude/scripts/statusline-git.sh`

### Configuration (v2.43)

New settings in `~/.claude/settings.json`:
```json
{
  "mcpToolSearchMode": "auto:10",
  "plansDirectory": "~/.ralph/plans/"
}
```

New keybindings in `~/.claude/keybindings.json`:
```json
{
  "ctrl+shift+o": "/orchestrator",
  "ctrl+shift+g": "/gates",
  "ctrl+shift+l": "/lsp-explore"
}
```

---

## v2.42 Context Preservation & Review Improvements

Based on analysis of [planning-with-files](https://github.com/OthmanAdi/planning-with-files) and [superpowers](https://github.com/obra/superpowers).

### New Hooks (v2.42)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `stop-verification.sh` | Stop | Verify completion checklist before session end |
| `auto-save-context.sh` | PostToolUse | Auto-save context every 5 operations |

### Improved Skills (v2.42)

| Skill | Improvement |
|-------|-------------|
| `/orchestrator` | **Full v2.42 Integration**: Step 1b Socratic, Step 6 Two-Stage, 3-Fix Rule in Anti-Patterns |
| `/adversarial` | **Two-Stage Review**: Stage 1 (spec compliance) → Stage 2 (code quality) |
| `systematic-debugging` | **3-Fix Rule Enforcement**: Mandatory escalation after 3 failed attempts |
| `/clarify` | **Socratic Design**: Present 2-3 alternatives with trade-offs |

### Stop Verification Checklist

Before session ends, the hook verifies:
- [ ] All TODOs completed (from progress.md)
- [ ] No uncommitted git changes
- [ ] No recent lint errors
- [ ] No recent test failures

### Auto-Save Configuration

```bash
export RALPH_AUTO_SAVE_INTERVAL=5  # Save every N operations (default: 5)
```

Context snapshots stored in `~/.ralph/state/context-snapshot-*.md` (keeps last 10).

### Two-Stage Review Process

```
Stage 1: Spec Compliance          Stage 2: Code Quality
├── Meets requirements?           ├── Follows patterns?
├── Covers use cases?             ├── Performance OK?
├── Respects constraints?         ├── Security applied?
└── Handles edge cases?           └── Tests adequate?
```

**Exit Stage 1 before proceeding to Stage 2.**

---

## v2.41 Context Engineering

### New Features

| Feature | Description |
|---------|-------------|
| **`context: fork`** | 5 skills now use isolated context (orchestrator, bugs, refactor, prd, ast-search) |
| **progress.md** | Auto-tracking of tool results/errors via `progress-tracker.sh` |
| **PIN/Lookup Tables** | `/pin` skill improves search tool hit rate with keywords |
| **Session Refresh Hints** | PreCompact hook generates recommendations for fresh context |

### New Commands

| Command | Description |
|---------|-------------|
| `/pin init` | Create `.claude/pins/readme.md` from template |
| `/pin show` | Show current lookup table |
| `/pin add` | Add area/keywords/files entry |
| `/pin scan` | Scan project and suggest keywords |

### Storage Structure

```
.claude/
├── pins/
│   └── readme.md          # Lookup table for search optimization
├── progress.md            # Auto-generated by progress-tracker.sh
└── settings.local.json    # Project permissions
```

## v2.40 Features

### Integration Testing Suite (26 tests)

Comprehensive pytest suite for validating v2.40 integration:

```bash
# Run all v2.40 tests
pytest tests/test_v2_40_integration.py -v

# Quick bash validation (23 checks)
ralph validate-integration
```

**Tests cover**:
- Skills discovery and frontmatter validation
- llm-tldr SessionStart hook registration
- ultrathink skill with model: opus
- Hooks configuration and executability
- Configuration hierarchy (global vs local)
- OpenCode synchronization
- Ralph backups and context preservation

### OpenCode Synchronization (v2.40)

Sync Claude Code configuration to OpenCode with naming conversion:

```bash
ralph sync-to-opencode           # Sync ~/.claude/ → ~/.config/opencode/
ralph sync-to-opencode --dry-run # Preview changes
```

**Mapping** (Claude plural → OpenCode singular):
- `~/.claude/skills/` → `~/.config/opencode/skill/`
- `~/.claude/agents/` → `~/.config/opencode/agent/`
- `~/.claude/commands/` → `~/.config/opencode/command/`

### LLM-TLDR Integration (95% Token Savings)

Token-efficient code analysis for exploring large codebases:

| Feature | Description |
|---------|-------------|
| **95% Token Savings** | 21,000 tokens → 175 tokens for function context |
| **155x Faster Queries** | Daemon mode with 100ms latency |
| **5-Layer Analysis** | AST → Call Graph → CFG → DFG → PDG |
| **16 Languages** | Python, TypeScript, Go, Rust, Java, C, C++, etc. |

**Commands**:
```bash
ralph tldr warm .              # Build index (first time)
ralph tldr semantic "query" .  # Semantic code search
ralph tldr context function .  # LLM-optimized context
ralph tldr impact function .   # Call graph analysis
ralph tldr structure src/      # Codebase structure
```

**Orchestrator Integration** (via /tldr-context skill):
- **Step 1 (CLARIFY)**: `tldr semantic` finds existing functionality
- **Step 3 (PLAN)**: `tldr impact` shows change blast radius
- **Step 5 (EXECUTE)**: `tldr context` prepares minimal context for subagents
- **Step DEBUG**: `tldr slice` for root cause analysis

**Installation**: `pip install llm-tldr`

## v2.36 Features

### Commands → Skills Unification (Claude Code v2.1.3)

All commands migrated to global skills (`~/.claude/skills/`):
- **Hot-reload**: Skills auto-reload without restart
- **Progressive Disclosure**: ~100 words in context until activated
- **`context: fork`**: Available for isolation (gates, adversarial, parallel)
- **185+ skills** available globally

### Context Preservation (100% Automatic)

| Event | Trigger | Action |
|-------|---------|--------|
| Session start | SessionStart hook | Loads ledger + handoff |
| Pre-compaction | PreCompact hook | Saves ledger + handoff |
| Post-compaction | SessionStart:compact | Restores with claude-mem hints |
| Context 80%+ | claude-hud | Yellow warning |
| Context 85%+ | claude-hud | Red warning |

**Threshold updated**: 60%→80% (aligned with Claude Code v2.1.0 auto-compact)

### Agent Hooks (v2.36)

5 agents now have frontmatter hooks for logging:
- `@security-auditor` - Audit logging
- `@orchestrator` - Orchestration tracking
- `@code-reviewer` - Review metrics
- `@test-architect` - Coverage tracking
- `@debugger` - Debug session logging

Logs: `~/.ralph/logs/`

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
6. /adversarial → adversarial-spec refinement (if complexity >= 7)
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
ralph adversarial "Design a rate limiter service"

# Git Worktree
ralph worktree "task"     # Create worktree
ralph worktree-pr <branch> # PR + review
ralph worktree-dashboard  # Show all worktrees (v2.43)

# Context
ralph ledger save         # Save session state
ralph ledger load         # Load ledger
ralph handoff create      # Create handoff

# Sync & Maintenance (v2.43)
ralph sync-global                 # Sync to ~/.claude/
ralph sync-to-projects            # Sync to all projects
ralph add-version-markers         # Add VERSION markers
ralph cleanup-project-configs     # Remove redundant configs
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

## v2.42 Retrospective Improvements (from @claudecoders tweet)

Based on Claude Code official prompt structure (2026-01-13):

### Self-Identification Guidelines
- Claude should NOT refer to itself as "Claude Code" unless directly asked
- Claude runs on top of Claude Code and Claude Agent SDK, but IS NOT Claude Code
- Focus on user-facing capabilities, not implementation details

### Model Versions Update
Update model references to latest versions:
| Model | Current | Latest Available |
|-------|---------|------------------|
| Opus | (not specified) | `claude-opus-4-5-20251101` |
| Sonnet | sonnet | `claude-sonnet-4-5-20250929` |
| Haiku | haiku | `claude-haiku-4-5-20251001` |

### Security Sandbox Pattern
Claude Code runs in a lightweight Linux VM providing **secure sandbox** for code execution. Consider:
- Adding sandbox validation for sensitive operations
- Documenting workspace isolation behavior
- Implementing controlled access patterns for workspace folders

### Product Context (Optional)
When users ask about Claude/Anthropic products, Claude can mention:
- Claude Code (command line tool for agentic coding)
- Claude for Chrome (browsing agent) - beta
- Claude for Excel (spreadsheet agent) - beta
- API and developer platform access

**Source**: https://x.com/claudecoders/status/2010895731549487409
