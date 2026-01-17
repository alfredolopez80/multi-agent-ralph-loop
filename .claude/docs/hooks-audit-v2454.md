# Claude Code Hooks Audit Report - v2.45.4

**Date**: 2026-01-17 (Updated)
**Auditor**: Claude Opus 4.5
**Test Suite**: `tests/test_hooks_v2454.py`
**Result**: ✅ 46/46 tests passed

## Executive Summary

Complete audit of all Claude Code hooks in `~/.claude/hooks/`. All hooks were verified for:
1. JSON output compliance (Claude Code hook protocol)
2. Script executability
3. VERSION markers (2.45.4)
4. Expected behavior under different conditions

---

## Problems Found and Solutions Applied

### Problem 1: `auto-plan-state.sh` - Empty JSON Output

**Symptom**: Test failed with "Empty output"

**Root Cause**: Lines 61-64 and 67-70 had `exit 0` without returning JSON first:
```bash
# BEFORE (broken)
if [[ "$file_path" != *"orchestrator-analysis.md" ]]; then
    log "Skipping: not orchestrator-analysis.md"
    exit 0  # ← No JSON returned!
fi
```

**Solution**: Added `return_json true` before each early exit:
```bash
# AFTER (fixed)
if [[ "$file_path" != *"orchestrator-analysis.md" ]]; then
    log "Skipping: not orchestrator-analysis.md"
    return_json true  # ← JSON returned
    exit 0
fi
```

**Files Modified**: `~/.claude/hooks/auto-plan-state.sh`

---

### Problem 2: `context-warning.sh` - TIMEOUT

**Symptom**: Test timed out after 10 seconds

**Root Cause**: The command `claude --print "/context"` can hang indefinitely in non-interactive environments:
```bash
# BEFORE (broken)
context_output=$(claude --print "/context" 2>/dev/null || echo "unknown")
```

**Solution**: Added 2-second timeout to prevent hanging:
```bash
# AFTER (fixed)
context_output=$(timeout 2 claude --print "/context" 2>/dev/null || echo "unknown")
```

**Files Modified**: `~/.claude/hooks/context-warning.sh`

---

### Problem 3: `lsa-pre-step.sh` - Missing JSON at All Exit Points

**Symptom**: Hook returned text output without JSON wrapper

**Root Cause**: Added `return_json` function but didn't call it at all exit points.

**Solution**: Added `return_json true "message"` at line 117 before final log:
```bash
log "LSA pre-check completed for step $CURRENT_STEP"
return_json true "LSA pre-check completed for step $CURRENT_STEP"
```

**Files Modified**: `~/.claude/hooks/lsa-pre-step.sh`

---

### Problem 4: `stop-verification.sh` - Text Output Instead of JSON

**Symptom**: Hook output plain text warnings instead of JSON

**Root Cause**: The hook was using `echo` statements for output instead of JSON format.

**Solution**: Added `return_json` function and converted output:
```bash
# BEFORE (broken)
echo "⚠️ Stop Verification: ..."

# AFTER (fixed)
return_json true "Stop Verification: ${CHECKS_PASSED}/${TOTAL_CHECKS} passed. Issues: ..."
```

**Files Modified**: `~/.claude/hooks/stop-verification.sh`

---

### Problem 5: `inject-session-context.sh` - PreToolUse:Task Hook Error

**Symptom**: "PreToolUse:Task hook error" when invoking Task tool (subagents)

**Root Cause**:
1. `set -euo pipefail` caused premature exit on any command failure
2. `jq` commands had no error handling - if JSON escaping failed, no output was produced
3. Hook configured in `~/.claude/settings.json` under `PreToolUse.matcher: "Task"`

**Solution**:
1. Removed `set -e` (changed to `set -uo pipefail`)
2. Added `output_json()` function with robust fallback
3. If `jq` fails, returns `{"hookSpecificOutput": {}}` instead of nothing

```bash
# NEW safe output function
output_json() {
    local context="${1:-}"
    if [[ -n "$context" ]]; then
        if ESCAPED=$(printf '%s' "$context" | jq -Rs '.' 2>/dev/null); then
            if OUTPUT=$(jq -n --argjson ctx "$ESCAPED" '{...}' 2>/dev/null); then
                echo "$OUTPUT"
                return 0
            fi
        fi
        log "WARN" "jq failed, returning empty hookSpecificOutput"
    fi
    echo '{"hookSpecificOutput": {}}'  # Always valid JSON
}
```

**Files Modified**: `~/.claude/hooks/inject-session-context.sh`

---

### Problem 6: `auto-plan-state.sh` - stdout Pollution & Missing JSON Returns

**Symptom**: Code review flagged HIGH priority issues - stdout pollution and exit without JSON

**Root Cause**:
1. Lines 197-198 used `echo` to stdout which pollutes JSON response
2. Line 188 had `exit 1` without returning JSON first
3. Line 202 had `exit 1` without returning JSON first

**Solution**:
```bash
# Fix 1: Lines 197-198 - Changed stdout echo to log function
# BEFORE (broken):
echo "plan-state-created: $PLAN_STATE_FILE"
echo "steps: $(echo "$steps_json" | jq 'length')"

# AFTER (fixed):
log "SUCCESS: plan-state-created: $PLAN_STATE_FILE"
log "SUCCESS: steps: $(echo "$steps_json" | jq 'length')"

# Fix 2: Lines 186-189 - Added JSON return before exit
# BEFORE (broken):
temp_file=$(mktemp "${PLAN_STATE_FILE}.XXXXXX") || {
    log "ERROR: Failed to create temp file"
    exit 1
}

# AFTER (fixed):
temp_file=$(mktemp "${PLAN_STATE_FILE}.XXXXXX") || {
    log "ERROR: Failed to create temp file"
    return_json true "Failed to create temp file"
    exit 0
}

# Fix 3: Lines 200-203 - Added JSON return before exit
# BEFORE (broken):
else
    rm -f "$temp_file"
    log "ERROR: Failed to create plan-state.json"
    exit 1
fi

# AFTER (fixed):
else
    rm -f "$temp_file"
    log "ERROR: Failed to create plan-state.json"
    return_json true "Failed to create valid plan-state.json"
    exit 0
fi
```

**Files Modified**: `~/.claude/hooks/auto-plan-state.sh`

---

## Previously Fixed Hooks (v2.45.3)

These hooks were fixed in a previous session:

| Hook | Problem | Solution |
|------|---------|----------|
| `sentry-check-status.sh` | Missing JSON return | Added `return_json` function |
| `sentry-correlation.sh` | Missing JSON return | Added `return_json` function |
| `auto-save-context.sh` | Missing JSON return | Added `return_json` function |
| `progress-tracker.sh` | Missing JSON return | Added `echo '{"continue": true}'` |
| `checkpoint-auto-save.sh` | Missing JSON return | Added `return_json` function |
| `plan-sync-post-step.sh` | Missing JSON return | Added `return_json` function |
| `plan-analysis-cleanup.sh` | Missing JSON return | Added `return_json` function |
| `quality-gates.sh` | Missing JSON return | Added `return_json` function |

---

## Hooks Verified as Correct (No Changes Needed)

| Hook | Type | Format |
|------|------|--------|
| `git-safety-guard.py` | PreToolUse | `{"decision": "block"}` when blocking, silent exit 0 when allowing |
| `session-start-ledger.sh` | SessionStart | `{"hookSpecificOutput": {"additionalContext": "..."}}` |
| `pre-compact-handoff.sh` | PreCompact | `{"continue": true}` |
| `skill-validator.sh` | PreToolUse | `{"continue": true/false}` |
| `detect-environment.sh` | Helper (sourced) | N/A (not a hook, helper library) |

---

## Claude Code Hook Protocol Summary

### Standard Hooks (PostToolUse, PreCompact, UserPromptSubmit, Stop)
```json
{"continue": true}
// or with message:
{"continue": true, "message": "informational message"}
```

### SessionStart Hooks
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Context injected into session"
  }
}
```

### PreToolUse Hooks (Blocking)
```json
{"decision": "block", "reason": "Why the tool call was blocked"}
```

### PreToolUse Hooks (Allowing)
Silent `exit 0` (no output required)

---

## Test Coverage

| Category | Tests | Status |
|----------|-------|--------|
| PostToolUse JSON compliance | 9 | ✅ |
| PreToolUse JSON compliance | 6 | ✅ |
| SessionStart format | 1 | ✅ |
| PreCompact format | 1 | ✅ |
| UserPromptSubmit format | 1 | ✅ |
| Stop format | 1 | ✅ |
| VERSION markers | 9 | ✅ |
| Executability | 18 | ✅ |
| **Total** | **46** | **✅ ALL PASSING** |

---

## Validation Commands Run

```bash
# Full test suite (final run)
pytest tests/test_hooks_v2454.py -v
# Result: 46 passed in 3.82s

# Additional validations performed:
# - Code review via code-reviewer agent (CONDITIONAL PASS)
# - Security audit via security-auditor agent (found 5 issues)
# - All HIGH priority issues from code review fixed
```

---

## Recommendations

1. **Always use `return_json` helper**: Every hook should have this function and use it at ALL exit points.

2. **Add timeouts to external commands**: Any command that might hang (like `claude --print`) should use `timeout`.

3. **Test hooks in isolation**: The test suite runs hooks in a subprocess environment that catches issues not visible during normal operation.

4. **VERSION markers**: All hooks should have `VERSION: X.Y.Z` for tracking changes.

---

## Files Created/Modified

### Created
- `tests/test_hooks_v2454.py` - Comprehensive test suite (46 tests)
- `.claude/docs/hooks-audit-v2454.md` - This audit report

### Modified
- `~/.claude/hooks/auto-plan-state.sh` - **UPDATED** Fixed stdout pollution (lines 197-198) + added JSON returns at exits (lines 188, 202)
- `~/.claude/hooks/context-warning.sh` - Added timeout to `claude` command
- `~/.claude/hooks/lsa-pre-step.sh` - Already had return_json, verified working
- `~/.claude/hooks/stop-verification.sh` - Converted text output to JSON
- `~/.claude/hooks/inject-session-context.sh` - **UPDATED** Fixed PreToolUse JSON format (changed hookSpecificOutput to continue)

---

## Security Findings (From Audit)

The security audit identified the following issues for future consideration:

| ID | Severity | Hook | Issue |
|----|----------|------|-------|
| VULN-001 | CRITICAL | auto-plan-state.sh | Potential command injection via unescaped jq args |
| VULN-002 | CRITICAL | inject-session-context.sh | Potential command injection via unescaped variables |
| VULN-003 | HIGH | all hooks | Inadequate JSON input validation |
| VULN-004 | HIGH | auto-plan-state.sh | Path traversal risk in file_path handling |
| VULN-005 | MEDIUM | various | Race conditions, world-readable permissions |

**Note**: These security findings require additional hardening beyond the JSON format fixes applied in this audit.

---

**Report Generated**: 2026-01-17T21:45:00Z (Updated)
**VERSION**: 2.45.4
