# Hook Registration Fix - v2.83.1

**Date**: 2026-02-04
**Version**: v2.83.1
**Status**: RESOLVED
**Severity**: SECURITY (HIGH)
**Author**: Alfredo Lopez

## Summary

Critical security hooks were not registered in `settings.json`, allowing dangerous commands like `rm -rf` to execute without validation. Analysis revealed **46 of 84 hooks (55%)** were unregistered, including critical security guards.

## Problem Description

### Initial Report

User reported that `rm -rf` commands were not being blocked by the security hook system.

### Root Cause Analysis

**Primary Issue**: `git-safety-guard.py` existed as a file but was **not registered** in `~/.claude-sneakpeek/zai/config/settings.json`.

**Discovery Process**:

1. Verified `git-safety-guard.py` exists: `.claude/hooks/git-safety-guard.py` ✅
2. Checked `settings.json` registration: ❌ **No matcher "Bash" in PreToolUse**
3. Only 2 matchers existed in PreToolUse: `Edit|Write` and `Task`

**Secondary Discovery**: Comprehensive audit revealed:

- 84 hooks in `.claude/hooks/` directory
- Only 38 hooks registered (45% coverage)
- 46 hooks unregistered (55% missing)

## Impact Assessment

### Commands Now Blocked

| Command | Before | After |
|---------|--------|-------|
| `rm -rf node_modules` | ❌ ALLOWED | ✅ BLOCKED |
| `rm -rf /tmp/test` | ❌ ALLOWED | ✅ ALLOWED (temp dir) |
| `git reset --hard` | ❌ ALLOWED | ✅ BLOCKED |
| `git clean -f` | ❌ ALLOWED | ✅ BLOCKED |
| `git push --force` | ❌ ALLOWED | ⚠️ REQUIRES CONFIRMATION |
| Work in external repos | ❌ ALLOWED | ✅ BLOCKED |

### Risk Level

- **Before**: **CRITICAL** - No protection against destructive commands
- **After**: **MITIGATED** - All critical security hooks active

## Solution

### Phase 1: Critical Security Hooks (5 hooks)

| Hook | Event | Matcher | Purpose |
|------|-------|---------|---------|
| `git-safety-guard.py` | PreToolUse | Bash | **Blocks rm -rf, git reset --hard, etc.** |
| `repo-boundary-guard.sh` | PreToolUse | Bash | Prevents work in external repos |
| `status-auto-check.sh` | PostToolUse | Edit\|Write\|Bash | Shows status every 5 ops |
| `console-log-detector.sh` | PostToolUse | Edit\|Write\|Bash | Detects console.log in JS/TS |
| `adversarial-auto-trigger.sh` | PostToolUse | Task | Auto-invoke /adversarial for complex tasks |

### Phase 2: Recommended Hooks (3 hooks)

| Hook | Event | Matcher | Purpose |
|------|-------|---------|---------|
| `plan-state-lifecycle.sh` | UserPromptSubmit | * | Auto-archive stale plans |
| `orchestrator-init.sh` | SessionStart | * | Initialize orchestrator state |
| `project-backup-metadata.sh` | SessionStart+Stop | * | Multi-project metadata backup |

### Phase 3: Optional Hooks (3 hooks)

| Hook | Event | Matcher | Purpose |
|------|-------|---------|---------|
| `ai-code-audit.sh` | PostToolUse | Edit\|Write\|Bash | Detect AI anti-patterns |
| `code-review-auto.sh` | PostToolUse | Task | Auto code review per step |
| `inject-session-context.sh` | PreToolUse | Task | Inject context before Task |

## Hooks NOT Registered (Analysis)

### Critical Issues (2 hooks)

| Hook | Reason | Action |
|------|--------|--------|
| `project-state.sh` | **NOT a hook** - it's a library/utility | Never register |
| `plan-analysis-cleanup.sh` | **Invalid matcher** `ExitPlanMode` doesn't exist | Never will work |

### Redundant/Problematic (5 hooks)

| Hook | Reason | Action |
|------|--------|--------|
| `prompt-analyzer.sh` | Redundant with `plan-state-adaptive.sh` | Not registered |
| `auto-format-prettier.sh` | High risk - auto-format conflicts | Not registered |
| `deslop-auto-clean.sh` | Modifies code without explicit approval | Not registered |
| `plan-analysis-cleanup.sh` | Invalid matcher | Not registered |
| `project-state.sh` | Library, not a hook | Not registered |

### Pending Optional (35 hooks)

Remaining 35 hooks are:

- Specific use cases (not critical)
- Deprecated/experimental
- Require user decision based on workflow

## Technical Details

### Registration Format

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/git-safety-guard.py"
          }
        ]
      }
    ]
  }
}
```

### Key Events

| Event | Triggers When | Example Use |
|-------|---------------|-------------|
| UserPromptSubmit | Before user message | Context warnings, command routing |
| SessionStart | When Claude Code starts | Initialize state, load memory |
| PreCompact | Before context compaction | Save state |
| PreToolUse | Before tool execution | Safety checks, validation |
| Stop | When session ends | Reports, cleanup |
| PostToolUse | After tool execution | Quality gates, logging |

### Matchers

| Matcher | Matches Tool | Example |
|---------|-------------|---------|
| `*` | All events | SessionStart, Stop, UserPromptSubmit |
| `Bash` | Bash tool only | Command execution |
| `Edit\|Write` | Edit + Write tools | File modifications |
| `Task` | Task tool | Agent spawning |

## Verification

### Before Fix

```bash
$ grep -c "command" ~/.claude-sneakpeek/zai/config/settings.json
38  # Only 38 hooks registered

$ jq '.hooks.PreToolUse[] | select(.matcher == "Bash")' settings.json
# No output - Bash matcher missing
```

### After Fix

```bash
$ grep -c "command" ~/.claude-sneakpeek/zai/config/settings.json
49  # Now 49 hooks registered (+11)

$ jq '.hooks.PreToolUse[] | select(.matcher == "Bash")' settings.json
{
  "matcher": "Bash",
  "hooks": [
    {"command": ".../git-safety-guard.py"},
    {"command": ".../repo-boundary-guard.sh"}
  ]
}
```

### Test Commands

```bash
# Should be BLOCKED
rm -rf node_modules
# Output: BLOCKED by git-safety-guard: recursive deletion not in safe temp directory

# Should be ALLOWED
rm -rf /tmp/test
# Output: Command executes successfully
```

## Prevention

### Documentation

1. **This document** (`docs/bugs/HOOK_REGISTRATION_FIX_v2.83.1.md`)
2. **Hook testing patterns** (`tests/HOOK_TESTING_PATTERNS.md`)
3. **Settings.json example** (includes all recommended hooks)

### Monitoring

Hook `status-auto-check.sh` now runs every 5 operations to show:

- Active plan status
- Current step progress
- Orchestration state

### Validation

```bash
# Quick validation script
python3 << 'EOF'
import json
with open("settings.json") as f:
    settings = json.load(f)
for event in settings["hooks"]:
    print(f"{event}: {len([h for m in settings['hooks'][event] for h in m['hooks']])} hooks")
EOF
```

## Coverage Statistics

### Before

```
Total hooks: 84
Registered: 38 (45%)
Missing: 46 (55%)

Event Breakdown:
- UserPromptSubmit: 5
- SessionStart: 4
- PreCompact: 1
- PreToolUse: 10 (2 matchers)
- Stop: 2
- PostToolUse: 16 (3 matchers)
```

### After

```
Total hooks: 84
Registered: 49 (58%)
Missing: 35 (42%)

Event Breakdown:
- UserPromptSubmit: 6 (+1)
- SessionStart: 6 (+2)
- PreCompact: 1
- PreToolUse: 13 (+1 matcher: Bash)
- Stop: 3 (+1)
- PostToolUse: 20 (+4)
```

## Related Issues

- **GitHub Issue**: (if applicable)
- **Claude Code Feature Request**: #14258 - PostCompact hook event
- **Parent Issue**: Hook system v2.83.1 audit

## References

- **Hook System Documentation**: `CLAUDE.md#hook-system-v2831--100-validated`
- **Security Hooks**: `.claude/hooks/git-safety-guard.py`
- **Settings Location**: `~/.claude-sneakpeek/zai/config/settings.json`

## Changelog Entry

```markdown
## v2.83.1 (2026-02-04)

### Security
- **CRITICAL FIX**: Registered 11 missing hooks including `git-safety-guard.py`
  - Blocks dangerous commands (rm -rf, git reset --hard, etc.)
  - Prevents work in external repositories
  - Auto-archives stale plans
  - Adds AI code audit and auto code review

### Hooks
- Added 5 critical security hooks (PreToolUse: Bash, PostToolUse)
- Added 3 recommended hooks (SessionStart, UserPromptSubmit)
- Added 3 optional hooks (AI audit, code review, context injection)
- Total registered: 38 → 49 (+11, +29%)
- Coverage: 45% → 58%
```

---

**Document Owner**: Alfredo Lopez
**Last Updated**: 2026-02-04
**Review Date**: 2026-03-04 (1 month review)
