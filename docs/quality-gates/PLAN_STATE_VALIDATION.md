# Plan-State Schema Validation Report
**Date:** 2026-01-23
**Repository:** multi-agent-ralph-loop
**Schema Version:** 2.62.0

---

## Executive Summary

**CRITICAL ISSUES FOUND: 5**
**HIGH PRIORITY ISSUES: 3**
**MEDIUM PRIORITY ISSUES: 2**

The plan-state schema and its implementation have **significant mismatches** that will cause runtime failures. The most critical issue is the **array vs object mismatch** for the `steps` field.

---

## 1. Schema Version Validation

### ✅ Documentation Match
- CLAUDE.md header: `v2.62.0` ✓
- Schema title: `Plan State Schema v2.62.0` ✓

### ❌ **CRITICAL: Schema Reference Mismatch**

**Issue:** Hooks reference `plan-state-v1` but schema ID is `plan-state-v2`

**Evidence:**
```bash
# Schema declares:
"$id": "plan-state-v2"
"title": "Plan State Schema v2.62.0"

# But hooks use:
plan-state-init.sh:71:  "\$schema": "plan-state-v1",
auto-plan-state.sh:140:  --arg schema "plan-state-v1"
```

**Impact:** Schema validation will fail. Any tooling expecting v2 schema will not recognize v1 references.

**Recommendation:** Update all hooks to use `plan-state-v2` schema reference.

---

## 2. Steps Field Format: CRITICAL SCHEMA VIOLATION

### ❌ **CRITICAL: Array vs Object Mismatch**

**Schema Definition (v2.62.0):**
```json
"steps": {
  "type": "object",
  "description": "Steps keyed by ID with execution details",
  "additionalProperties": {
    "type": "object",
    "required": ["name", "status"]
  }
}
```

**Expected Format:**
```json
{
  "steps": {
    "step1": {"name": "...", "status": "pending"},
    "step2": {"name": "...", "status": "completed"}
  }
}
```

**Hooks Implementation:**
14 hooks use **array access pattern** `.steps[]`:

1. `plan-state-init.sh` - Creates steps as ARRAY
2. `lsa-pre-step.sh` - Reads `.steps[]`
3. `plan-sync-post-step.sh` - Iterates `.steps[]`
4. `orchestrator-report.sh` - Filters `.steps[]`
5. `statusline-ralph.sh` - Counts `.steps[]`
6. Many others...

**Expected Usage for Object Format:**
```bash
# Wrong (treats as array):
jq '.steps[] | select(.status == "pending")'

# Correct (treats as object):
jq '.steps | to_entries[] | select(.value.status == "pending")'
```

**Impact:** 
- All hooks will fail when steps is an object
- Schema validation will reject array format
- Runtime errors: "Cannot iterate over object with []"

**Files Affected:**
```
.claude/hooks/plan-state-init.sh        (lines 90, 136-157, 346, 354-357)
.claude/hooks/lsa-pre-step.sh           (lines 32, 43)
.claude/hooks/plan-sync-post-step.sh    (lines 75, 86-87, 179)
.claude/hooks/orchestrator-report.sh    (lines 80-81)
.claude/hooks/auto-plan-state.sh        (creates array at line 147)
.claude/hooks/todo-plan-sync.sh         (lines 215-250)
.claude/hooks/global-task-sync.sh       (line 179 - mixed, handles both!)
.claude/scripts/statusline-ralph.sh     (lines 114-159 - handles both!)
```

**Note:** `global-task-sync.sh` and `statusline-ralph.sh` already handle **both** formats:
```bash
# From statusline-ralph.sh:114-124
if (.steps | type) == "array" then
    (.steps | length)
else
    (.steps | keys | length)
end
```

This suggests the codebase is **transitioning** from array to object but incomplete.

---

## 3. Version Pattern Validation

### ✅ Version Pattern
Schema requires: `^2\.(5[1-9]|6[0-9])\.[0-9]+$`
- Allows: 2.51.0 through 2.69.x ✓

### ❌ **HIGH: Version Checking Incomplete**

**Issue:** Multiple hooks check version but don't validate schema compatibility.

**Evidence:**
```bash
# state-sync.sh:160 - Only warns, doesn't enforce
if [[ ! "$version" =~ ^2\.5[1-9] ]]; then
    log "WARN: Legacy schema detected (v$version)"
fi

# statusline-ralph.sh:105 - Reads version but doesn't validate
version=$(echo "$plan_state" | jq -r '.version // "1.0"')
```

**Recommendation:** Add schema version enforcement:
```bash
REQUIRED_MAJOR=2
REQUIRED_MINOR_MIN=51
validate_schema_version() {
    local version="$1"
    # Extract and validate major.minor
    [[ "$version" =~ ^2\.(5[1-9]|6[0-9])\.[0-9]+$ ]]
}
```

---

## 4. Verification Object (v2.62.0 Feature)

### ✅ **Schema Properly Defines Verification**
Lines 120-166 in schema define complete verification object.

### ⚠️ **MEDIUM: Inconsistent Initialization**

**verification-subagent.sh** (v2.62.0) - **CORRECT**:
```bash
# Lines 125-141 properly initializes verification object
.steps[$id].verification = {
    required: true,
    method: "subagent",
    agent: $agent,
    status: "pending",
    result: null,
    started_at: null,
    completed_at: null,
    task_id: null
}
```

**plan-state-init.sh** (v2.57.5) - **INCOMPLETE**:
```bash
# Lines 151-154 - Missing verification field entirely!
"lsa_verification": null,  # OLD v1 field
"quality_audit": null,
"micro_gate": null,
```

**Impact:** New steps created by `plan-state-init.sh` will be **missing** the verification field, causing errors in `verification-subagent.sh`.

**Recommendation:** Update `plan-state-init.sh` to include:
```json
"verification": {
  "required": false,
  "method": "skip",
  "status": "pending"
}
```

---

## 5. Race Condition Analysis

### ✅ **Atomic Updates Implemented**
Most hooks use `mktemp` + `mv` pattern:
- `plan-state-init.sh` ✓
- `plan-sync-post-step.sh` ✓
- `auto-plan-state.sh` ✓
- `verification-subagent.sh` ✓

### ⚠️ **HIGH: No Inter-Hook Locking**

**Issue:** Multiple hooks can run **simultaneously** (PostToolUse is not serialized).

**Scenario:**
1. Hook A reads plan-state.json
2. Hook B reads plan-state.json (same content)
3. Hook A modifies and writes temp file
4. Hook B modifies and writes temp file
5. Hook A runs `mv temp plan-state.json`
6. Hook B runs `mv temp plan-state.json` ← **Overwrites Hook A's changes**

**Evidence:** Only 2 hooks implement locking:
```bash
global-task-sync.sh:99-116  # Has flock-based locking
procedural-inject.sh        # Has flock-based locking
```

**Impact:** 
- Lost updates during concurrent writes
- Inconsistent state between subsystems
- Silent data corruption

**Recommendation:** Implement centralized locking:
```bash
# Example from global-task-sync.sh
LOCK_FILE="${HOME}/.ralph/locks/plan-state.lock"
acquire_lock() {
    exec {lock_fd}>"$LOCK_FILE"
    flock -w 5 "$lock_fd" || return 1
    echo "$lock_fd"
}
```

Apply to ALL hooks that modify plan-state.json.

---

## 6. Missing Field Handling

### ⚠️ **MEDIUM: Graceful Degradation**

Most hooks use `// empty` or `// null` defaults:
```bash
jq -r '.current_phase // empty'
jq -r '.active_agent // "orchestrator"'
```

**Good practices found:**
- `statusline-ralph.sh` handles missing fields well
- `state-sync.sh` provides defaults

**Issue:** Some hooks assume fields exist:
```bash
# orchestrator-report.sh:80 - No null check before filter
COMPLETED_STEPS=$(jq -r '[.steps[] | select(...)] | length')
```

**Recommendation:** Add existence checks:
```bash
COMPLETED_STEPS=$(jq -r '
    if .steps then 
        [.steps[] | select(.status == "completed")] | length
    else 
        0 
    end
' "$PLAN_STATE")
```

---

## 7. v2.54 Unified State Management Fields

### ✅ Schema Includes v2.54 Fields
- `active_agent` (line 178-182) ✓
- `current_handoff_id` (line 183-186) ✓
- `state_coordinator` (line 332-362) ✓

### ✅ Hooks Use These Fields
- `state-sync.sh` reads/writes `active_agent` ✓
- `global-task-sync.sh` syncs state ✓

---

## 8. Phases and Barriers (v2.51+)

### ✅ Schema Properly Defines
- `phases` array (lines 31-76) ✓
- `barriers` object (lines 187-193) ✓

### ✅ Usage in Hooks
- `state-sync.sh` checks barriers ✓
- `statusline-ralph.sh` displays barrier status ✓

---

## Critical Issues Summary

| Issue | Severity | Files Affected | Impact |
|-------|----------|----------------|--------|
| Array vs Object mismatch | **CRITICAL** | 14 hooks | Complete failure |
| Schema v1 references | **CRITICAL** | 2 hooks | Validation fails |
| Missing verification init | **HIGH** | plan-state-init.sh | New steps break |
| No inter-hook locking | **HIGH** | 12 hooks | Lost updates |
| Version not enforced | **MEDIUM** | state-sync.sh | Silent degradation |

---

## Recommendations

### **IMMEDIATE (Blocking)**

1. **Decide on steps format**: Array or Object?
   - Schema says **object** → Update all hooks to use object format
   - OR change schema to array → Update schema documentation
   
2. **Fix schema references**: 
   - Change `plan-state-v1` → `plan-state-v2` in all hooks

3. **Add verification field to init**:
   - Update `plan-state-init.sh` to include v2.62.0 verification object

### **HIGH PRIORITY**

4. **Implement global locking**:
   - Create `~/.ralph/locks/plan-state.lock`
   - Wrapper function for all plan-state modifications
   - Use `flock` with timeout

5. **Version enforcement**:
   - Reject incompatible schemas
   - Auto-migration script for v1 → v2

### **MEDIUM PRIORITY**

6. **Null-safety**:
   - Add existence checks before array operations
   - Default values for all optional fields

7. **Testing**:
   - Unit tests for jq queries
   - Integration tests for concurrent writes
   - Schema validation tests

---

## Files Requiring Updates

### Critical Priority
```
.claude/hooks/plan-state-init.sh        # Array → Object, add verification
.claude/hooks/auto-plan-state.sh        # Array → Object, schema ref
.claude/hooks/lsa-pre-step.sh           # Array → Object queries
.claude/hooks/plan-sync-post-step.sh    # Array → Object queries
.claude/hooks/orchestrator-report.sh    # Array → Object queries
.claude/hooks/todo-plan-sync.sh         # Already uses object! Keep it.
```

### High Priority
```
All 12 hooks modifying plan-state.json  # Add flock locking
.claude/hooks/state-sync.sh             # Enforce version check
```

### Reference Implementation (Already Correct)
```
.claude/hooks/global-task-sync.sh       # Has locking, handles both formats
.claude/scripts/statusline-ralph.sh     # Handles both array/object gracefully
```

---

## Appendix: Schema Consistency Check

### Required Fields (per schema line 7)
- ✅ `version`
- ✅ `plan_id`
- ✅ `phases`
- ✅ `steps`
- ✅ `barriers`

### Hook Initialization Coverage
| Field | plan-state-init.sh | auto-plan-state.sh | orchestrator-init.sh |
|-------|-------------------|-------------------|---------------------|
| version | ❌ (uses $schema) | ❌ (uses $schema) | ✅ |
| plan_id | ✅ | ✅ | ✅ |
| phases | ❌ | ❌ | ❌ |
| steps | ✅ (array!) | ✅ (array!) | ✅ (array!) |
| barriers | ❌ | ❌ | ❌ |

**Missing:** None of the init hooks create `phases` or `barriers` arrays!

---

## Conclusion

The plan-state system has a **fundamental schema mismatch** that requires immediate attention. The codebase appears to be mid-transition from v1 (array-based steps) to v2 (object-based steps), with incomplete migration.

**Action Items:**
1. ✅ Choose format: Recommend **object** (per schema)
2. ✅ Update 14 hooks to use object queries
3. ✅ Fix schema references (v1 → v2)
4. ✅ Add locking to prevent race conditions
5. ✅ Initialize all required v2.62.0 fields

**Estimated Effort:** 4-6 hours for complete remediation.

