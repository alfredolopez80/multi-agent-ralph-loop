# Changelog

All notable changes to Multi-Agent Ralph Wiggum are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.56.2] - 2026-01-20

### Fixed (StatusLine Health Monitor mkdir Bug)

**Severity**: MINOR (P3)
**Impact**: statusline-health-monitor.sh now creates directories correctly

Fixed a bug where `mkdir -p "$(dirname "$HEALTH_CACHE")"` created the parent directory instead of the cache directory itself.

**Before**: `mkdir -p "$(dirname "$HEALTH_CACHE")"` → Created `~/.ralph/cache/` instead of `~/.ralph/cache/statusline-health/`
**After**: `mkdir -p "$HEALTH_CACHE"` → Correctly creates `~/.ralph/cache/statusline-health/`

This caused the hook to fail with "No such file or directory" when writing to `$LAST_CHECK_FILE`.

---

## [2.56.1] - 2026-01-20

### Added (Full Automation of Manual Monitoring Tasks)

**Severity**: ENHANCEMENT (P2)
**Impact**: Three previously manual tasks are now fully automated

This release automates the monitoring and checkpoint tasks that previously required manual intervention.

#### Problem Statement

Users had to manually:
1. Monitor statusline for progress updates
2. Run `ralph checkpoint save` before important changes
3. Execute `ralph status --compact` to verify state

#### New Hooks (3)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `status-auto-check.sh` | PostToolUse (Edit/Write/Bash) | Auto-shows status every 5 operations or on step completion |
| `checkpoint-smart-save.sh` | PreToolUse (Edit/Write) | Smart checkpoint based on complexity, file criticality, and step risk |
| `statusline-health-monitor.sh` | UserPromptSubmit | Validates statusline health every 5 minutes |

#### status-auto-check.sh Features

- **Periodic Status**: Shows `ralph status --compact` output every 5 Edit/Write/Bash operations
- **Step Completion Detection**: Automatically shows status when a plan step completes
- **Session-Aware Counter**: Resets operation counter for each new session
- **Non-Blocking**: Adds systemMessage without interrupting workflow

```
# Example output in systemMessage
"Status: STANDARD Step 3/7 (42%) - in_progress"
```

#### checkpoint-smart-save.sh Features

Smart checkpoint triggers (replaces basic checkpoint-auto-save.sh for PreToolUse):

| Trigger | Condition |
|---------|-----------|
| `high_complexity` | Plan complexity >= 7, first edit of file |
| `high_risk_step` | Current step involves auth/security/payment |
| `critical_file` | Core config, security, database, API files |
| `security_file` | Files with auth/secret/credential in name |

Additional features:
- **Cooldown**: Minimum 120 seconds between auto-checkpoints
- **File Tracking**: Only checkpoints on first edit of each file per session
- **Rich Metadata**: Saves complexity level, step risk, and trigger reason
- **Auto-Cleanup**: Keeps only last 20 smart checkpoints

#### statusline-health-monitor.sh Features

Health checks performed every 5 minutes:
1. **Script Existence**: Verifies statusline-ralph.sh exists and is executable
2. **Plan-State Validity**: Checks JSON is valid and has required fields
3. **Stuck Detection**: Warns if status is "in_progress" but unchanged for 30+ minutes
4. **Sync Verification**: Compares statusline output with plan-state.json values

#### Configuration

All hooks are enabled by default. To disable:

```bash
# Disable status auto-check
export RALPH_STATUS_AUTO_CHECK=false

# Disable smart checkpoints
export RALPH_CHECKPOINT_SMART=false

# Disable health monitor
export RALPH_HEALTH_MONITOR=false
```

#### Documentation

- Hooks location: `~/.claude/hooks/`
- Logs: `~/.ralph/logs/status-auto-check.log`, `checkpoint-smart.log`, `statusline-health.log`

---

## [2.56.0] - 2026-01-20

### Fixed (Plan-State Auto-Archive and Staleness Detection)

**Severity**: CRITICAL (P0)
**Impact**: StatusLine now shows accurate progress instead of stale "2/17 11%"

This release fixes critical plan-state tracking issues discovered during comprehensive audit.

#### Root Cause Analysis

The statusline displayed fixed progress ("2/17 11%") because:
1. **Plan staleness**: plan-state.json was 2+ days old and never auto-reset
2. **No lifecycle management**: Old plans persisted indefinitely
3. **Missing sync**: TodoWrite updates didn't propagate to plan-state

#### Solutions Implemented

**plan-state-lifecycle.sh v2.56.0**
- NEW: `archive_plan()` function for automatic archiving
- NEW: Auto-archive stale plans (>2 hours) when new task detected
- NEW: Auto-archive on `/orchestrator` command (always fresh start)
- NEW: Archive location: `~/.ralph/archive/plans/`
- NEW: Archive metadata includes reason and timestamp
- NEW: `PLAN_STATE_AUTO_ARCHIVE` env var (default: true)

```bash
# Behavior
| Condition                          | Action                    |
|------------------------------------|---------------------------|
| Plan >2 hours + new task detected  | Auto-archive + notify     |
| /orchestrator command              | Always archive existing   |
| Recent plan (<2 hours)             | Keep plan, no action      |
```

**todo-plan-sync.sh v2.56.0** (NEW)
- Creates plan-state from TodoWrite todos when no plan exists
- Updates existing plan-state with todo progress
- Direct mapping when todo count matches step count
- Ratio mapping otherwise

#### Limitation Discovered

**TodoWrite is NOT a valid hook matcher in Claude Code.**

Valid PostToolUse matchers: `Edit`, `Write`, `Bash`, `Task`, `Read`, `Grep`, `Glob`, `ExitPlanMode`

The todo-plan-sync.sh hook is registered but cannot be triggered automatically. Manual invocation or alternative triggers required.

#### Test Coverage

| Category | Tests | Status |
|----------|-------|--------|
| Context Compaction | 15 | Pass |
| Plan-State | 15 | Pass |
| StatusLine | 5 | Pass |
| Lifecycle v2.56.0 | 7 | 6 Pass, 1 Edge |
| Todo-Sync v2.56.0 | 5 | 4 Pass, 1 Edge |
| **Total** | **47/49** | **96%** |

#### Documentation

- Retrospective: `.claude/retrospectives/2026-01-20-context-compaction-planstate-audit.md`

---

## [2.55.0] - 2026-01-20

### Added (Autonomous Self-Improvement System)

**Severity**: ENHANCEMENT (P1)
**Impact**: System now proactively learns and improves code quality autonomously

This release introduces automated memory population and proactive self-improvement capabilities.

#### New Hooks (6)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `agent-memory-auto-init.sh` | PreToolUse (Task) | Auto-initializes agent memory buffers when agents spawn |
| `semantic-auto-extractor.sh` | Stop | Extracts semantic facts from git diff (functions, classes, deps) |
| `decision-extractor.sh` | PostToolUse (Edit/Write) | Detects architectural patterns and decisions |
| `curator-suggestion.sh` | UserPromptSubmit | Suggests `/curator` when procedural memory is empty |
| `orchestrator-auto-learn.sh` | PreToolUse (Task) | Triggers learning for complexity >=7 tasks with insufficient memory |

#### New Command

```bash
ralph health                    # Full memory system health report
ralph health --compact          # One-line summary
ralph health --json             # JSON output for scripts
ralph health --fix              # Auto-fix critical issues
```

#### Health Check Categories

| Category | Checks |
|----------|--------|
| Semantic Memory | File exists, valid JSON, entry count |
| Procedural Memory | Rules count, staleness |
| Episodic Memory | Directory exists, recent entries |
| Agent Memory | Initialized agents count |
| Curator State | Pending repos, learned repos |
| Event Bus | Event log exists, recent events |
| Ledgers | Active ledgers, size |
| Handoffs | Recent handoffs |
| Checkpoints | Checkpoint count, recent |

#### Auto-Learning Triggers

| Condition | Severity | Action |
|-----------|----------|--------|
| ZERO relevant rules (any complexity) | CRITICAL | Learning REQUIRED |
| <3 rules AND complexity >=7 | HIGH | Learning RECOMMENDED |

#### Extraction Features

**Semantic Auto-Extractor** (on Stop):
- Extracts new functions from git diff
- Extracts new classes/components
- Extracts new dependencies
- Source tagged as "auto-extract"

**Decision Extractor** (on Edit/Write):
- Detects design patterns (Singleton, Repository, Factory, Observer, Strategy)
- Detects architectural decisions (async/await, caching, logging, error handling)
- Tracks file and timestamp

---

## [2.54.0] - 2026-01-19

### Fixed (StatusLine Progress Display)

**Severity**: MEDIUM (P2)
**Impact**: StatusLine now correctly shows completed steps instead of always showing 0

#### Root Cause

The `get_ralph_progress()` function in `statusline-ralph.sh` was counting steps incorrectly:
- Used `keys | length` which doesn't work properly with object iteration
- Status comparison used wrong syntax for jq

#### Solution

Fixed `statusline-ralph.sh` v2.54.0:
```bash
# Correct step counting
completed_steps=$(echo "$plan_state" | jq -r '
    if .steps then
        [.steps | to_entries[] | select(.value.status == "completed" or .value.status == "verified")] | length
    else 0 end
' 2>/dev/null || echo "0")
```

#### Test Results

| Test | Before | After |
|------|--------|-------|
| Show 0/7 when no steps completed | 0/7 | 0/7 |
| Show 3/7 when 3 steps completed | 0/7 | 3/7 |
| Show "done" when all completed | 0/7 | done |

---

## [2.53.0] - 2026-01-19

### Fixed (PostToolUse Hook JSON Format)

**Severity**: HIGH (P1)
**Impact**: Hooks now return correct JSON format, preventing silent failures

#### Problem

Multiple PostToolUse hooks were returning incorrect JSON:
```json
// WRONG (PreToolUse format)
{"decision": "continue"}

// CORRECT (PostToolUse format)
{"continue": true, "systemMessage": "optional message"}
```

#### Hooks Fixed

| Hook | Version |
|------|---------|
| `checkpoint-auto-save.sh` | v2.55.0 |
| `progress-tracker.sh` | v2.53.0 |
| `plan-sync-post-step.sh` | v2.53.0 |
| `quality-gates-v2.sh` | v2.53.0 |

#### Reference

PostToolUse hooks must return:
```json
{
  "continue": true,           // Required: always true for PostToolUse
  "systemMessage": "..."      // Optional: message to show user
}
```

---

## [2.52.0] - 2026-01-19

### Added (Local Observability System)

**Severity**: ENHANCEMENT (P2)
**Impact**: Full orchestration status and traceability without external services

#### New Commands

```bash
# Status
ralph status                  # Full orchestration status
ralph status --compact        # One-line summary
ralph status --steps          # Detailed step breakdown
ralph status --json           # JSON for scripts

# Traceability
ralph trace show [count]      # Recent events
ralph trace search <query>    # Search events
ralph trace timeline          # Visual timeline
ralph trace export [format]   # Export to JSON/CSV
ralph trace summary           # Session summary
```

#### StatusLine Integration

Progress shown in statusline:
```
main* | 3/7 42% | [claude-hud metrics]
```

| Icon | Meaning |
|------|---------|
| | Active plan |
| | Executing |
| | Fast-path |
| | Completed |

---

## [2.51.0] - 2026-01-18

### Added (Multi-Agent Infrastructure Improvements)

Major infrastructure release adding LangGraph-style checkpoints, OpenAI Agents SDK-style handoffs, event-driven orchestration, and agent-scoped memory.

#### Checkpoint System

```bash
ralph checkpoint save "name" "description"
ralph checkpoint restore "name"
ralph checkpoint list
ralph checkpoint diff "n1" "n2"
```

#### Handoff API

```bash
ralph handoff transfer --from X --to Y --task "desc"
ralph handoff agents
ralph handoff validate <agent>
```

#### Event-Driven Engine

```bash
ralph events emit <type> [payload]
ralph events barrier check <phase>
ralph events barrier wait <phase> [timeout]
ralph events route
```

#### Agent-Scoped Memory

```bash
ralph agent-memory init <agent>
ralph agent-memory write <agent> <type> <content>
ralph agent-memory read <agent> [type]
ralph agent-memory transfer <from> <to> [filter]
```

#### Plan State v2 Schema

Phases + barriers for strict WAIT-ALL consistency:
```json
{
  "version": "2.51.0",
  "phases": [
    {"phase_id": "clarify", "step_ids": ["1"], "execution_mode": "sequential"}
  ],
  "barriers": {
    "clarify_complete": false
  }
}
```

---

## [2.50.0] - 2026-01-17

### Added (Repository Learning and Curation)

#### Repository Learner

```bash
repo-learn https://github.com/python/cpython
repo-learn https://github.com/fastapi/fastapi --category error_handling
```

#### Repo Curator

```bash
/curator "best backend TypeScript repos"
ralph curator full --type backend --lang typescript
ralph curator approve nestjs/nest
ralph curator learn --all
```

#### Codex Planner

```bash
/codex-plan "Design distributed system"
/orchestrator "task" --use-codex
```

---

## [2.49.0] - 2026-01-15

### Added (Smart Memory-Driven Orchestration)

Based on @PerceptualPeak Smart Forking concept.

#### Memory Architecture

- Semantic Memory (permanent facts)
- Episodic Memory (30-day TTL experiences)
- Procedural Memory (learned behaviors)

#### Smart Memory Search

Parallel search across 4 sources:
- claude-mem MCP
- memvid
- handoffs
- ledgers

Results aggregated to `.claude/memory-context.json`

---

## [2.46.0] - 2026-01-10

### Added (RLM-Inspired Routing)

3-Dimension Classification:
- Complexity (1-10)
- Information Density (CONSTANT/LINEAR/QUADRATIC)
- Context Requirement (FITS/CHUNKED/RECURSIVE)

Workflow Routing:
- FAST_PATH: 3 steps for trivial tasks
- PARALLEL_CHUNKS: Concurrent exploration
- RECURSIVE_DECOMPOSE: Sub-orchestrators

Quality over Consistency:
- Style issues advisory, not blocking
- Quality issues blocking

---

## [2.45.0] - 2026-01-05

### Added (Plan-Sync and LSA Integration)

- Lead Software Architect verification
- Plan-Sync for drift detection
- Gap-Analyst for pre-implementation analysis
- Adversarial Plan Validation
- plan-state.json tracking

---

*For older versions, see git history.*
