# Multi-Agent Ralph v2.21

Orchestration with **automatic planning**, **intensive clarification**, **git worktree isolation**, adversarial validation, self-improvement, and 9-language quality gates.

## v2.21 Key Changes

- **SELF-UPDATE**: `ralph self-update` syncs scripts from repo to ~/.local/bin/
- **PRE-MERGE VALIDATION**: `ralph pre-merge` validates shellcheck + versions + tests before PR
- **INTEGRATIONS CHECK**: `ralph integrations` shows status of all tools (Greptile always OPTIONAL)
- **COMMIT PREFIX**: Per-agent commit prefixes for consistent commit messages (security:, test:, ui:, etc.)

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

## Agents (9)

```bash
@orchestrator       # Opus - Coordinator (uses EnterPlanMode + AskUserQuestion)
@security-auditor
@code-reviewer
@test-architect
@debugger           # Opus
@refactorer
@docs-writer
@frontend-reviewer  # Opus
@minimax-reviewer   # Fallback
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
