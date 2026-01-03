# Multi-Agent Ralph v2.22

Orchestration with **automatic planning**, **intensive clarification**, **git worktree isolation**, adversarial validation, self-improvement, and 9-language quality gates.

## v2.22 Key Changes

- **STARTUP VALIDATION**: `startup_validation()` checks critical tools at every command
- **ON-DEMAND VALIDATION**: `require_tool()` blocks with installation instructions
- **TOOL CATEGORIES**: Critical, Feature, Quality Gates with appropriate validation levels
- **CLEAR ERRORS**: ASCII box format with exact install commands

### Tool Validation Behavior

| Category | Startup | On-Demand | Blocking |
|----------|---------|-----------|----------|
| Critical (claude, jq, git) | Warning | Error + Exit | Yes |
| Feature (wt, gh, mmc, codex, gemini) | Info | Error + Exit | When needed |
| Quality Gates (9 languages) | Count | Warning | No (graceful) |

### Quality Gate Tools (9 Languages)

| Language | Tools | Install |
|----------|-------|---------|
| TypeScript/JavaScript | npx, tsc | `brew install node` |
| Python | pyright, ruff | `npm i -g pyright && pip install ruff` |
| Go | go, staticcheck | `brew install go` |
| Rust | cargo | `brew install rust` |
| Solidity | forge, solhint | `foundryup && npm i -g solhint` |
| Swift | swiftlint | `brew install swiftlint` |
| JSON | jq | `brew install jq` |
| YAML | yamllint | `pip install yamllint` |

## v2.21 Key Changes

- **SELF-UPDATE**: `ralph self-update` syncs scripts from repo to ~/.local/bin/
- **PRE-MERGE VALIDATION**: `ralph pre-merge` validates shellcheck + versions + tests before PR
- **INTEGRATIONS CHECK**: `ralph integrations` shows status of all tools (Greptile always OPTIONAL)
- **COMMIT PREFIX**: Per-agent commit prefixes for consistent commit messages (security:, test:, ui:, etc.)
- **MODEL BY TASK**: Optimized model selection based on efficiency analysis (see below)

## Model Configuration by Task Type (v2.21)

Based on efficiency analysis prioritizing: **quality > speed > rework > context**

| Task Type | Model | Why |
|-----------|-------|-----|
| **Exploration** | MiniMax | 1M context, 8% cost, 74% SWE-bench |
| **Implementation** | Sonnet | Balanced quality/speed for 85% of tasks |
| **Review** | Opus | Surgical precision, catches bugs others miss |
| **Validation** | MiniMax | Second opinion at Opus quality, 8% cost |

```bash
# Environment variables in ralph
EXPLORATION_MODEL="minimax"     # Research, docs
IMPLEMENTATION_MODEL="sonnet"   # Features, tests
REVIEW_MODEL="opus"             # Pre-merge critical
VALIDATION_MODEL="minimax"      # Parallel review
```

**Why NOT Haiku?** Rework rate >30% cancels cost savings for code tasks.

## v2.20 Key Changes

- **WORKTREE WORKFLOW**: Git worktree isolation for features via `ralph worktree`
- **HUMAN-IN-THE-LOOP**: Orchestrator asks user about worktree isolation (Step 2b)
- **MULTI-AGENT PR REVIEW**: Claude Opus + Codex GPT-5 review before merge
- **ONE WORKTREE PER FEATURE**: Multiple subagents share same worktree
- **WorkTrunk Integration**: Required for worktree management (`brew install max-sixty/worktrunk/wt`)

## v2.19 Key Changes

- **VULN-001 FIX**: escape_for_shell() now uses `printf %q` (prevents command injection)
- **VULN-003 FIX**: Improved rm -rf regex patterns in git-safety-guard.py
- **VULN-004 FIX**: validate_path() uses `realpath -e` (resolves symlinks)
- **VULN-005 FIX**: Log files now chmod 600 (user-only read/write)
- **VULN-008 FIX**: All scripts start with `umask 077` (secure file creation)

## v2.17 Key Changes

- **Security Hardening**: All user inputs validated and shell-escaped
- **Enhanced validate_path()**: Blocks control chars, path traversal attacks
- **New validate_text_input()**: Validates non-path inputs (tasks, queries)
- **Safe JSON Construction**: Uses jq for all JSON building in mmc

## v2.16 Key Changes

- **Auto Plan Mode**: Automatically enters `EnterPlanMode` for non-trivial tasks
- **AskUserQuestion**: Uses native Claude tool for interactive MUST_HAVE/NICE_TO_HAVE questions
- **Deep Clarification**: New skill for comprehensive task understanding

## Mandatory Flow (8 Steps)

```
0. AUTO-PLAN    → EnterPlanMode (automatic for non-trivial)
1. /clarify     → AskUserQuestion (MUST_HAVE + NICE_TO_HAVE)
2. /classify    → Complexity 1-10
2b. WORKTREE    → Ask user: "¿Requiere worktree aislado?" (v2.20)
3. PLAN         → Write plan, get user approval
4. @orchestrator → Delegate to subagents (in worktree if selected)
5. ralph gates  → Quality gates (9 languages)
6. /adversarial → 2/3 consensus (complexity >= 7)
7. /retrospective → Propose improvements
7b. PR REVIEW   → If worktree: ralph worktree-pr (Claude + Codex review)
→ VERIFIED_DONE
```

## Clarification Philosophy

**The key to successful agentic coding is MAXIMUM CLARIFICATION before implementation.**

- **NEVER assume** - always use `AskUserQuestion`
- **MUST_HAVE questions** are blocking - cannot proceed without answers
- **NICE_TO_HAVE questions** can assume defaults if skipped
- **Enter Plan Mode** automatically for any non-trivial task

## Iteration Limits

| Model | Max Iter | Use Case |
|-------|----------|----------|
| Claude | **15** | Complex reasoning |
| MiniMax M2.1 | **30** | Standard (2x) |
| MiniMax-lightning | **60** | Extended (4x) |

## CRITICAL: Ralph Loop Pattern

**ALL tasks, subagents, tools, and MCPs MUST follow the Ralph Loop pattern:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH LOOP PATTERN                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────┐    ┌──────────────┐    ┌─────────────────┐      │
│   │ EXECUTE  │───▶│   VALIDATE   │───▶│ Quality Passed? │      │
│   │   Task   │    │ (hooks/gates)│    └────────┬────────┘      │
│   └──────────┘    └──────────────┘             │               │
│                                          NO ◀──┴──▶ YES        │
│                                           │         │          │
│                          ┌────────────────┘         │          │
│                          ▼                          ▼          │
│                   ┌─────────────┐          ┌──────────────┐    │
│                   │  ITERATE    │          │ VERIFIED_DONE│    │
│                   │ (max 15/30) │          │   (output)   │    │
│                   └──────┬──────┘          └──────────────┘    │
│                          │                                     │
│                          └──────────▶ Back to EXECUTE          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Iteration Limits by Model:**
| Model | Max Iterations | Rationale |
|-------|----------------|-----------|
| Claude (Sonnet/Opus) | **15** | Complex reasoning, higher accuracy per iteration |
| MiniMax M2.1 | **30** | Good quality at 8% cost, needs more iterations |
| MiniMax-lightning | **60** | Fast model, compensate with more iterations |

**Quality Hooks (automatic enforcement):**
- `quality-gates.sh` → Post-Edit/Write: tsc, eslint, pyright, ruff, etc. (9 languages)
- `git-safety-guard.py` → Pre-Bash: validates git commands for safety

**Subagent Configuration:**
```yaml
# Primary: Sonnet manages all Task() subagents
Task:
  subagent_type: "general-purpose"
  model: "sonnet"  # MANDATORY - Haiku causes infinite retries
  run_in_background: true
  prompt: "Primary task execution"

# Secondary: MiniMax for second opinion / validation
Task:
  subagent_type: "minimax-reviewer"
  model: "sonnet"  # Sonnet MANAGES the call to mmc
  run_in_background: true
  prompt: 'mmc --query "Second opinion on: $TOPIC"'
```

**Why Sonnet + MiniMax?**
- **Sonnet** (60% cost): Manages subagents reliably, no infinite loops
- **MiniMax** (8% cost): Second opinion with Opus-level quality (74% SWE-bench)
- **Haiku** (NOT recommended): 30%+ rework rate cancels cost savings

## Quick Commands

```bash
# CLI
ralph orch "task"         # Full orchestration (8 steps)
ralph adversarial src/    # 2/3 consensus
ralph parallel src/       # 6 subagents
ralph security src/       # Security audit
ralph bugs src/           # Bug hunting
ralph gates               # Quality gates
ralph loop "task"         # Loop (15 iter)
ralph loop --mmc "task"   # Loop (30 iter)
ralph retrospective       # Self-improvement

# Git Worktree + PR Workflow (v2.20)
ralph worktree "task"     # Create worktree + Claude
ralph worktree-pr <branch> # PR + multi-agent review
ralph worktree-merge <pr>  # Approve and merge
ralph worktree-fix <pr>    # Apply review fixes
ralph worktree-close <pr>  # Close and cleanup
ralph worktree-status      # Show worktree status
ralph worktree-cleanup     # Clean merged worktrees

# Maintenance (v2.21)
ralph self-update          # Sync scripts from repo
ralph pre-merge            # Validate before PR
ralph integrations         # Show tool status (Greptile optional)

# MiniMax
mmc                       # Launch with MiniMax
mmc --loop 30 "task"      # Extended loop

# Slash Commands (Claude Code)
/orchestrator /clarify /full-review /parallel
/security /bugs /unit-tests /refactor
/research /minimax /gates /loop
/adversarial /retrospective /improvements
```

## Native Claude Tools (v2.16+)

```yaml
# Automatic for non-trivial tasks
EnterPlanMode: {}

# Intensive clarification
AskUserQuestion:
  questions:
    - question: "What is the primary goal?"
      header: "Goal"
      multiSelect: false
      options:
        - label: "New feature"
          description: "Adding new functionality"
        - label: "Bug fix"
          description: "Correcting behavior"

# Exit only when plan approved
ExitPlanMode: {}
```

## Agents (9) with Model Assignment

```bash
# Critical tasks (Opus - surgical precision)
@orchestrator       # Opus - Coordinator (uses EnterPlanMode + AskUserQuestion)
@security-auditor   # Opus - Security requires maximum accuracy
@debugger           # Opus - Bug detection needs deep reasoning

# Implementation tasks (Sonnet - balanced)
@code-reviewer      # Sonnet - Balanced for code reviews
@test-architect     # Sonnet - Test generation
@refactorer         # Sonnet - Refactoring
@frontend-reviewer  # Sonnet - UI/UX reviews

# Cost-effective tasks (MiniMax - 8% cost)
@docs-writer        # MiniMax - Long context for documentation
@minimax-reviewer   # MiniMax - Second opinion/validation
```

## Skills (v2.20)

```bash
deep-clarification  # Intensive AskUserQuestion patterns
task-classifier     # Complexity 1-10 routing
retrospective       # Self-improvement analysis
worktree-pr         # Git worktree + PR workflow (v2.20)
```

## Aliases

```bash
rh=ralph rho=orch rhr=review rhs=security
rhb=bugs rhu=unit-tests rhg=gates rha=adversarial
mm=mmc mml="mmc --loop 30"
```

## Completion

`VERIFIED_DONE` = plan approved + all MUST_HAVE answered + classified + implemented + gates passed + adversarial passed (if critical) + retrospective done
