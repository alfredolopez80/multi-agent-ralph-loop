# Retrospective: Critical Hook JSON Format Fix (v2.53)

**Date**: 2026-01-19
**Severity**: CRITICAL (P0)
**Impact**: All Claude Code sessions affected by hook errors
**Resolution**: Fixed 20+ hooks, created procedural rule

---

## Executive Summary

A critical error in Claude Code hook JSON output formats caused widespread "hook error" messages across all hook types (PostToolUse, UserPromptSubmit, Stop, PreToolUse). The root cause was **incorrect documentation** that propagated through the entire hook system.

### The Core Problem

**The string `"continue"` was being used as a decision value, which is INVALID for ALL Claude Code hook types.**

```json
// WRONG (used in 20+ hooks)
{"decision": "continue"}

// CORRECT for Stop hooks
{"decision": "approve"}  // or "block"

// CORRECT for all other hooks
{"continue": true}
```

---

## Timeline

| Time | Event |
|------|-------|
| ~21:00 | User reports persistent hook errors after v2.52 "fixes" |
| ~21:15 | Initial investigation shows Stop hook error: `{"decision": "continue"}` |
| ~21:20 | User requests Context7 documentation check |
| ~21:25 | **DISCOVERY**: Official docs show Stop hooks use `{"decision": "approve\|block"}` |
| ~21:30 | Fixed Stop hooks (stop-verification.sh, sentry-report.sh, reflection-engine.sh) |
| ~21:35 | User reports UserPromptSubmit hook errors persist |
| ~21:40 | Fixed UserPromptSubmit hooks (context-warning.sh, periodic-reminder.sh, etc.) |
| ~21:50 | User reports PostToolUse:Edit hook errors |
| ~22:00 | **BATCH FIX**: Corrected all 20+ hooks with incorrect format |
| ~22:10 | Created procedural rule and documentation v2.53.1 |

---

## Root Cause Analysis

### The Documentation Error

Previous documentation (v2.52) stated:

| Hook Type | v2.52 (WRONG) | v2.53 (CORRECT) |
|-----------|---------------|-----------------|
| **Stop** | `{"continue": true\|false}` | `{"decision": "approve\|block"}` |
| **PostToolUse** | `{"decision": "continue\|block"}` | `{"continue": true}` |
| **UserPromptSubmit** | `{"decision": "continue"}` | `{"continue": true}` |
| **PreToolUse** | `{"decision": "continue"}` | `hookSpecificOutput` or silent |

### Why It Happened

1. **Initial misunderstanding**: The schemas were inverted/confused
2. **Propagation**: The incorrect format was copy-pasted across 20+ hooks
3. **Self-reinforcing**: Claude followed its own incorrect documentation
4. **Validation gap**: The validation script also had incorrect schemas

### Why It Wasn't Caught Earlier

1. Hooks still "worked" but produced error messages
2. Error messages were vague ("hook error")
3. The system continued despite errors, masking the problem
4. Previous fixes addressed symptoms, not root cause

---

## Files Fixed

### Stop Hooks (3 files)
- `stop-verification.sh`
- `sentry-report.sh`
- `reflection-engine.sh`

### PostToolUse Hooks (13 files)
- `quality-gates-v2.sh`
- `checkpoint-auto-save.sh`
- `plan-sync-post-step.sh`
- `progress-tracker.sh`
- `auto-plan-state.sh`
- `auto-save-context.sh`
- `fast-path-check.sh`
- `parallel-explore.sh`
- `plan-analysis-cleanup.sh`
- `procedural-inject.sh`
- `recursive-decompose.sh`
- `lsa-pre-step.sh`
- `curator-trigger.sh`

### UserPromptSubmit Hooks (4 files)
- `context-warning.sh`
- `periodic-reminder.sh`
- `prompt-analyzer.sh`
- `memory-write-trigger.sh`

### PreToolUse Hooks (3 files)
- `inject-session-context.sh`
- `skill-validator.sh`
- `smart-memory-search.sh`

---

## Correct Schemas (Official)

### Stop Hooks
```json
{
  "decision": "approve|block",
  "reason": "Explanation",
  "systemMessage": "Context for Claude"
}
```
- `decision`: MUST be `"approve"` or `"block"`
- `"continue"` is **NEVER** valid!

### PostToolUse Hooks
```json
{
  "continue": true,
  "suppressOutput": false,
  "systemMessage": "Feedback for Claude"
}
```

### UserPromptSubmit Hooks
```json
{
  "continue": true,
  "systemMessage": "Context to inject"
}
```

### PreToolUse Hooks
```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow|deny|ask",
    "updatedInput": {}
  }
}
```
Or silent exit (exit 0 with no output)

### SessionStart Hooks
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Content to inject"
  }
}
```
Or `{"continue": true, "systemMessage": "..."}`

### PreCompact Hooks
```json
{
  "continue": true
}
```

---

## Prevention Measures

### 1. Procedural Rule Created
Location: `~/.ralph/procedural/rules-hook-json-format.json`

This rule will be automatically loaded and will trigger warnings when:
- Writing or editing hook files
- Seeing patterns like `"decision": "continue"`
- Hook-related errors occur

### 2. Documentation Updated
Location: `~/.claude/docs/HOOK_JSON_FORMAT_v2.53.md`

Comprehensive reference with:
- Correct schemas for all hook types
- Common mistakes and corrections
- Quick reference table

### 3. Validation Script Updated
Location: `~/.claude/scripts/validate-hooks.sh` (v2.53.0)

Now correctly validates:
- Stop hooks for `{"decision": "approve|block"}`
- Other hooks for `{"continue": true}`
- Detects `{"decision": "continue"}` as CRITICAL error

---

## Lessons Learned

### 1. Documentation is Critical
- Incorrect documentation propagates errors
- Always verify against official sources (Context7 MCP)
- Update documentation immediately when errors are found

### 2. Validate Against Official Sources
- Don't trust internal documentation alone
- Use Context7 MCP to fetch latest official docs
- Cross-reference multiple sources

### 3. Error Messages Matter
- "hook error" is too vague
- Better error messages would have caught this earlier
- Consider adding schema validation with specific messages

### 4. Systematic Fixes
- One-off fixes lead to whack-a-mole
- Batch fixes with `replace_all` are more reliable
- Create automated validation to prevent recurrence

---

## Action Items

- [x] Fix all Stop hooks
- [x] Fix all PostToolUse hooks
- [x] Fix all UserPromptSubmit hooks
- [x] Fix all PreToolUse hooks
- [x] Update documentation to v2.53
- [x] Update validation script to v2.53
- [x] Create procedural rule for prevention
- [x] Document retrospective
- [ ] Consider adding pre-commit hook for schema validation
- [ ] Add unit tests for hook JSON output

---

## Key Takeaway

> **The string `"continue"` is NEVER a valid value for the `decision` field in ANY Claude Code hook type!**

- Stop hooks: Use `"approve"` or `"block"`
- All other hooks: Use `continue` as a **boolean** field (`"continue": true`)

---

*This retrospective was created as part of the multi-agent-ralph-loop v2.53.1 release.*
*Source: Official Claude Code documentation via Context7 MCP (anthropics/claude-code)*
