# Stop Hook Unit Tests

**Version**: 2.87.0
**Date**: 2026-02-14

## Overview

This directory contains unit tests for the `ralph-stop-quality-gate.sh` hook, which implements the "Ralph Wiggum Loop" pattern to prevent Claude Code from stopping until VERIFIED_DONE conditions are met.

## Files

| File | Description |
|------|-------------|
| `test-ralph-stop-quality-gate.sh` | Main test script with 8 test scenarios |

## Running Tests

```bash
# Run all tests
./tests/stop-hook/test-ralph-stop-quality-gate.sh

# Expected output: "All tests passed!" with 11 assertions
```

## Test Scenarios

| # | Test | Expected Result |
|---|------|-----------------|
| 1 | `stop_hook_active = true` | Exit 0, approve (prevent infinite loop) |
| 2 | No state file | Exit 0, approve (nothing to validate) |
| 3 | Incomplete orchestrator | Exit 2, block |
| 4 | Complete orchestrator | Exit 0, approve |
| 5 | Incomplete loop | Exit 2, block |
| 6 | Complete loop | Exit 0, approve |
| 7 | Quality gate failed | Exit 2, block |
| 8 | ralph-state.sh functions | All operations work correctly |

## Related Files

- **Hook**: `.claude/hooks/ralph-stop-quality-gate.sh`
- **State Script**: `.claude/scripts/ralph-state.sh`
- **Documentation**: `docs/hooks/STOP_HOOK_INTEGRATION_ANALYSIS.md`
- **Skills**: `.claude/skills/loop/SKILL.md`, `.claude/skills/orchestrator/SKILL.md`

## How It Works

### Stop Hook Flow

```
[Claude finishes turn]
        |
        v
[Stop hook fires]
        |
        +-- stop_hook_active = true?
        |       |
        |       +-- YES --> exit 0 (prevent infinite loop)
        |       |
        |       +-- NO --> Check state files
        |               |
        |               +-- Check orchestrator.json
        |               +-- Check loop.json
        |               +-- Check quality-gate.json
        |               +-- Check team tasks
        |               |
        |               +-- Issues found? --> exit 2 + reason
        |               |
        |               +-- All clear? --> exit 0
```

### State File Locations

```
~/.ralph/state/{session_id}/
├── orchestrator.json   # /orchestrator skill state
├── loop.json          # /loop skill state
└── quality-gate.json  # /gates skill state
```

## Debugging

### Check Stop Hook Logs

```bash
tail -f ~/.ralph/logs/stop-hook.log
```

### Manually Test Hook

```bash
echo '{"session_id":"test","stop_hook_active":false}' | \
    .claude/hooks/ralph-stop-quality-gate.sh
```

### Check State Files

```bash
# List all session states
ls -la ~/.ralph/state/

# Read specific session state
cat ~/.ralph/state/{session_id}/orchestrator.json | jq .
```

## Troubleshooting

### Hook not blocking when expected

1. Check state files exist: `ls ~/.ralph/state/{session_id}/`
2. Check `verified_done` is `false`: `jq .verified_done ~/.ralph/state/{session_id}/orchestrator.json`
3. Check hook is registered: `grep -A5 '"Stop"' ~/.claude/settings.json`

### Hook always blocking

1. Check `stop_hook_active` is being checked first
2. Ensure skills are calling `ralph-state.sh complete` when done
3. Check state files for correct structure

### Tests failing

1. Ensure `jq` is installed: `jq --version`
2. Ensure hook is executable: `chmod +x .claude/hooks/ralph-stop-quality-gate.sh`
3. Ensure state script is executable: `chmod +x .claude/scripts/ralph-state.sh`
