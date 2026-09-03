# Context System - Findings and Issues

> Historical record. Model/provider names below describe the state at the time of writing; the current rule is that the model is whatever the session runs.

**Date**: 2026-01-26
**Session**: ralph-20260126-12113
**Status**: In Progress

## Findings

### 🔴 CRITICAL Issues

#### 1. `ralph compact` Creates Empty Handoffs
**Location**: `~/.local/bin/ralph` line 853
**Problem**:
- Uses placeholder variables: `${RALPH_ENV:-unknown}`, `${ClaudeCode:-unknown}`
- Does not capture real session information
- Handoffs show "unknown" for all fields

**Impact**: High - Information loss during compaction
**Evidence**: Handoff files show "Environment: unknown", "Session ID: unknown"

**Root Cause**: `cmd_compact()` function doesn't use `ledger-manager.py`

**Fix Required**: Modify `ralph compact` to call `ledger-manager.py save` with real session data

---

#### 2. Session Information Not Available to Hooks
**Problem**: Hooks receive `session_id` and `transcript_path` in JSON input
**Evidence**: `pre-compact-handoff.sh` lines 78-83 parse INPUT correctly

**Issue**: When calling `/compact` via skill, session info may not be passed

**Impact**: Medium - Handoffs lack context about which session they belong to

---

### 🟡 MEDIUM Issues

#### 3. GLM Auto-Compact May Not Trigger
**Location**: `~/.claude/hooks/glm-context-manager.sh`
**Threshold**: 85%
**Status**: Implemented but not tested

**Risk**: Auto-compact may fail silently if:
- `ralph handoff create` fails
- Lock acquisition fails
- Cooldown not respected

---

### 🟢 LOW Priority

#### 4. Context Injection Works Correctly
**Evidence**: `context-injector.sh` loads contexts from `~/.claude/contexts/`
**Status**: ✅ Functional

---

#### 5. Ledger Manager Works Correctly
**Evidence**: `ledger-manager.py save` captures real information
**Status**: ✅ Functional

---

#### 6. StatusLine Duplication Fixed
**Location**: `~/.claude/scripts/statusline-ralph.sh`
**Fix**: Modified `get_glm_context_percentage()` to return empty
**Status**: ✅ Resolved

---

## System Architecture

### Current Flow (Broken)
```
User runs /compact
    ↓
Skill /compact reads instructions
    ↓
Calls: ralph compact
    ↓
ralph compact → cmd_compact()
    ↓
Creates: handoff with UNKNOWN placeholders ❌
```

### Correct Flow (Required)
```
User runs /compact OR system auto-compacts
    ↓
Should call: ledger-manager.py save
    ↓
Creates: ledger with REAL information ✅
```

---

## Required Fixes

### Priority 1: Fix `ralph compact` Command ✅ COMPLETADO
**File**: `~/.local/bin/ralph`
**Function**: `cmd_compact()`
**Change**: Now uses `ledger-manager.py` with real session info
**Status**: ✅ Working - creates ledgers with actual information

### Priority 2: GLM Context Lock Management 🔴 CRITICAL
**File**: `~/.claude/hooks/glm-context-tracker.sh`
**Problem**: Lock directory gets stuck and blocks all updates
**Impact**: Statusline NEVER updates because lock blocks tracker
**Root Cause**: Exception in `glm-message-tracker.sh` leaves lock directory
**Fix Required**: Improve lock cleanup in `glm-context-tracker.sh`

### Priority 3: Verify Auto-Compact Triggers
**File**: `~/.claude/hooks/glm-context-manager.sh`
**Test**: Simulate 85% context and verify auto-compact

### Priority 4: Test Session Resume Flow
**Verify**: Handoff information correctly loaded after `/compact`

---

## Issues Summary

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | `ralph compact` creates empty handoffs | 🔴 High | ✅ Fixed |
| 2 | GLM lock gets stuck blocking updates | 🔴 Critical | ⏳ Pending |
| 3 | Statusline not updating with GLM usage | 🔴 High | ⏳ Pending |
| 4 | Auto-compact not tested | 🟡 Medium | ⏳ Pending |

---

## Next Steps

1. ✅ Document findings
2. ⏳ Fix GLM lock management
3. ⏳ Verify statusline updates
4. ⏳ Test auto-compact at 85%
5. ⏳ Verify session resume with real information
6. ⏳ Audit with Codex
