# Changelog

All notable changes to Multi-Agent Ralph Wiggum are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.62.2] - 2026-01-23

### Fixed (PreToolUse Hook JSON Format Standardization)

**Severity**: HIGH
**Impact**: SEC-039 Compliance - All PreToolUse hooks now use correct JSON format

#### Overview

Comprehensive adversarial audit discovered that 8 PreToolUse hooks were using the wrong JSON output format (`{"continue": true}` instead of `{"decision": "allow"}`).

#### Fixed Hooks

| Hook | Issue |
|------|-------|
| `procedural-inject.sh` | Fixed FEEDBACK_RESULT + 9 exit points |
| `orchestrator-auto-learn.sh` | All exit points updated |
| `fast-path-check.sh` | All exit points updated |
| `inject-session-context.sh` | All exit points updated |
| `smart-memory-search.sh` | All exit points updated |
| `agent-memory-auto-init.sh` | All exit points updated |
| `skill-validator.sh` | Added missing JSON output |
| `smart-skill-reminder.sh` | Changed `{}` to decision format |

#### Pre-commit Hook Fix

- Now recognizes `# Hook:` header (not just `# Trigger:`)
- Corrected format rules message to show accurate requirements

---

## [2.62.1] - 2026-01-23

### Fixed (Adversarial Audit Fixes)

**Severity**: HIGH
**Impact**: Fixed critical syntax error and missing shebang

#### Fixes

| Issue | Fix |
|-------|-----|
| `orchestrator-auto-learn.sh` syntax error | Added missing `fi` for if block |
| `procedural-inject.sh` missing shebang | Added `#!/bin/bash` |
| Hook JSON format violations | Fixed 9 instances of wrong format |
| Registered v2.62.0 hooks to global | Copied and registered in settings.json |

---

## [2.62.0] - 2026-01-23

### Added (Claude Code Task Primitive Integration)

**Severity**: ENHANCEMENT
**Impact**: Major integration with Claude Code's evolved Task primitive (from TodoWrite)

#### Overview

This release integrates Claude Code Cowork Mode's new Task primitive patterns:
- **Verification via subagents** after step completion
- **Global task sync** with `~/.claude/tasks/<session>/`
- **Parallelization detection** for independent tasks
- **Context-hiding** optimization for high-token tasks

#### New Features

| Feature | Description |
|---------|-------------|
| **Verification Pattern** | Spawn verification subagent after each step completion |
| **Global Task Sync** | Bidirectional sync with `~/.claude/tasks/<session>/` |
| **Subagent Optimizer** | Auto-detect parallelization and context-hiding opportunities |
| **Schema v2.62.0** | Added `verification` object to steps |

#### Schema Changes

```json
{
  "steps": {
    "step-1": {
      "verification": {
        "required": true,
        "method": "subagent",
        "agent": "code-reviewer",
        "status": "pending|in_progress|passed|failed|skipped",
        "result": { "passed": true, "message": "..." },
        "task_id": "subagent-task-id"
      }
    }
  }
}
```

#### New Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `global-task-sync.sh` | PostToolUse (TodoWrite, TaskUpdate) | Sync with `~/.claude/tasks/` |
| `verification-subagent.sh` | PostToolUse (TaskUpdate) | Suggest verification after completion |
| `task-orchestration-optimizer.sh` | PreToolUse (Task) | Optimize Task tool usage |

#### New Workflow

```
EXECUTE-WITH-SYNC
    6a. LSA-VERIFY
    6b. IMPLEMENT
    6c. PLAN-SYNC
    6d. MICRO-GATE
    6e. VERIFICATION-SUBAGENT   ← NEW

VALIDATE
    7a-d. (existing)
    7e. COLLECT-VERIFICATIONS   ← NEW
```

#### Files Changed

| File | Change |
|------|--------|
| `.claude/schemas/plan-state-v2.schema.json` | Added verification object, version 2.62.0 |
| `.claude/hooks/global-task-sync.sh` | NEW - Global task sync |
| `.claude/hooks/verification-subagent.sh` | NEW - Verification pattern |
| `.claude/hooks/task-orchestration-optimizer.sh` | NEW - Subagent optimization |

#### References

- Tweet: @claudecoders on Cowork Mode Task primitive
- Context7 Claude Code documentation

---

## [2.61.0] - 2026-01-22

### Added (Adversarial Council v2.61 - LLM-Council Enhanced)

**Severity**: ENHANCEMENT
**Impact**: Major upgrade to /adversarial skill with llm-council patterns

#### New Features

| Feature | Description |
|---------|-------------|
| **Python Orchestration** | `adversarial_council.py` script for automated multi-model review |
| **Provider-Specific Extraction** | Codex, Claude, Gemini response parsing with fallbacks |
| **Exponential Backoff** | `2^attempt` seconds between retries (1s, 2s, 4s...) |
| **Command Allowlist** | Security: Only whitelisted commands for custom agents |
| **Path Validation** | Security: Prevents path traversal in output directory |
| **Feature Status Table** | Documentation: Clear Implemented vs Planned markers |

#### Security Hardening

| Fix | Severity | Description |
|-----|----------|-------------|
| Command Injection | HIGH | Added `ALLOWED_CUSTOM_COMMANDS` allowlist |
| Path Traversal | MEDIUM | Added `validate_output_path()` function |
| Config Validation | MEDIUM | Schema validation for agents.json |

#### Validation Results

| Model | Score | Notes |
|-------|-------|-------|
| Codex CLI | 6/10 | Identified initial issues |
| Claude Opus | 6.4/10 | Identified security vulnerabilities |
| Gemini | **9/10 Security**, **8/10 Quality** | Post-fix validation |

#### Files Changed

| File | Change |
|------|--------|
| `~/.claude/skills/adversarial/skill.md` | v2.61 with feature status table |
| `~/.claude/skills/adversarial/scripts/adversarial_council.py` | New orchestration script |

### Added (Security Audit - API Key Detection)

| Check | Result |
|-------|--------|
| MiniMax API Key | ✅ Not exposed |
| OpenAI API Key | ✅ Not exposed |
| JWT Tokens | ✅ Not exposed |
| .gitignore | ✅ Properly configured |
| Git History | ✅ Clean |

**Report**: `.claude/SECURITY_AUDIT_API_KEYS.md`

---

## [2.57.5] - 2026-01-20

### Fixed (Stop Hook JSON Format Error)

**Severity**: HIGH (P1)
**Impact**: Fixed Stop hook validation errors during session end

#### Root Cause

The error occurred because `orchestrator-report.sh` was outputting:
```json
{"decision": "continue"}  // INVALID
```

But Claude Code's Stop hook schema requires:
```json
{"decision": "approve"}   // VALID
{"decision": "block"}     // VALID (to block session end)
```

#### Fix Applied

| File | Line | Change |
|------|------|--------|
| `orchestrator-report.sh` | 181 | Changed `{"decision": "continue"}` → `{"decision": "approve"}` |

#### Hook Output Protocol Summary

| Hook Type | Required Format |
|-----------|-----------------|
| **PreToolUse** | `{"continue": true}` |
| **PostToolUse** | `{"continue": true, "systemMessage": "..."}` |
| **Stop** | `{"decision": "approve"}` or `{"decision": "block"}` |
| **UserPromptSubmit** | `{"additionalContext": "..."}` |

---

## [2.57.4] - 2026-01-20

### Fixed (Architecture Consistency Gaps)

**Severity**: HIGH (P1)
**Impact**: Resolved critical gaps in hooks system, memory writing, and documentation

This release addresses 5 critical gaps identified in a Codex CLI adversarial audit:

#### Gaps Fixed

| Gap ID | Issue | Severity | Fix |
|--------|-------|----------|-----|
| GAP-003 | Race condition in semantic.json writes | HIGH | Created `semantic-write-helper.sh` with flock locking |
| GAP-004 | `checkpoint-smart-save.sh` used wrong JSON format | HIGH | Changed `{"decision": "approve"}` to `{"continue": true}` |
| GAP-001 | `hooks.json` had only 3 hooks vs 56 in settings.json | HIGH | Removed obsolete `hooks.json`, created validation script |
| GAP-005 | Version mismatch (CLAUDE.md v2.57.3 vs hooks v2.57.0) | MEDIUM | Unified all hooks to v2.57.4 |
| GAP-002 | CLAUDE.md said 49 hooks but 52 exist | MEDIUM | Updated CLAUDE.md to reflect 52 hooks at v2.57.4 |

#### New Files

| File | Purpose |
|------|---------|
| `semantic-write-helper.sh` | Atomic writer for semantic.json with flock |
| `validate-hooks-consistency.sh` | Validates hooks in settings.json exist on disk |
| `bump-hooks-version.sh` | Bulk version bump for all hooks |

#### Modified Files

| File | Change |
|------|--------|
| `semantic-realtime-extractor.sh` | Uses atomic write helper (v2.57.4) |
| `decision-extractor.sh` | Uses atomic write helper (v2.57.4) |
| `checkpoint-smart-save.sh` | Fixed JSON output format (v2.57.4) |
| `CLAUDE.md` | Updated to v2.57.4, 52 hooks |

#### Validation

```bash
# Run hooks consistency validation
~/.claude/scripts/validate-hooks-consistency.sh
# Output: STATUS: PASSED (56 hooks verified, 0 errors)
```

#### Key Fixes

1. **Atomic Writes**: `semantic-write-helper.sh` uses `flock` for cross-platform locking
2. **JSON Protocol**: PreToolUse hooks use `{"continue": true}`, Stop hooks use `{"decision": "approve"}`
3. **Single Source of Truth**: `settings.json` is canonical, `hooks.json` removed

---

## [2.57.0] - 2026-01-20

### Fixed (Memory System Reconstruction - 8 Critical Issues)

**Severity**: CRITICAL (P1)
**Impact**: Memory search, plan-state sync, context injection, and semantic extraction now work correctly

This release addresses 8 critical issues discovered in a dual-model adversarial audit:

#### Issues Fixed

| # | Issue | Fix |
|---|-------|-----|
| 1 | `todo-plan-sync.sh` used `sort_by(tonumber)` failing on step-X-Y keys | Changed to `keys \| sort` |
| 2 | `smart-memory-search.sh` searched JSON files but claude-mem uses SQLite | Implemented SQLite FTS query |
| 3 | `inject-session-context.sh` output JSON but PreToolUse can't modify tool_input | Removed JSON output, uses cache file |
| 4 | Reflection-executor extracted JSON metadata instead of real decisions | Filters JSON content from extraction |
| 5 | Pattern detection threshold never met despite 162 episodes | Lowered threshold, improved matching |
| 6 | auto-learn-context.md written but never read | Integrated with SessionStart hook |
| 7 | Procedural rules only had 1 test rule | Bootstrapped with quality patterns |
| 8 | Semantic memory contained only test data | Cleaned test data, added real extraction |

#### Implementation Phases

| Phase | Description | Files Modified |
|-------|-------------|----------------|
| 1 | Plan-State Adaptive | `auto-plan-state.sh` (creates for all sessions) |
| 2 | Reflection-Executor | `reflection-executor.py` (filters JSON from decisions) |
| 3 | Context Injection | `inject-session-context.sh` (PreToolUse fix) |
| 4 | Semantic Auto-Extractor | `semantic-realtime-extractor.sh`, `decision-extractor.sh` |
| 5 | Memory Search | `todo-plan-sync.sh`, `smart-memory-search.sh` |
| 6 | Integration Testing | 48 new tests (all passing) |

#### New/Modified Hooks (v2.57.0)

| Hook | Change |
|------|--------|
| `todo-plan-sync.sh` | Fixed `sort_by(tonumber)` → `sort` for step-X-Y keys |
| `smart-memory-search.sh` | SQLite FTS instead of JSON file search |
| `inject-session-context.sh` | Removed JSON output, uses exit 0 only |
| `semantic-realtime-extractor.sh` | NEW: Real-time extraction from Edit/Write |
| `decision-extractor.sh` | Writes patterns to semantic memory |

#### Test Coverage

- `test_memory_search_v257.py` (19 tests)
- `test_reflection_executor_v257.py` (10 tests)
- `test_semantic_extractor_v257.py` (13 tests)
- `test_context_injection_v257.py` (6 tests)

**Total: 48/48 tests passing**

#### Key Learnings

1. **PreToolUse hooks**: Can ONLY block (exit 2) or allow (exit 0) - CANNOT modify tool_input
2. **claude-mem storage**: Uses SQLite (`claude-mem.db`) with FTS, NOT JSON files
3. **jq sort_by(tonumber)**: Fails silently on non-numeric strings like "step-1-1"
4. **Hook JSON output**: PostToolUse uses `{"continue": true}`, Stop uses `{"decision": "approve"}`

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
