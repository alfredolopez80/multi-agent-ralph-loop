# Security Fixes Handoff - v2.45.4

**Created**: 2026-01-17
**Context**: 9 security findings from audit need fixing + unit tests

## Task

Fix all 9 security vulnerabilities identified in the hooks audit and add unit tests to prevent regression.

## Findings to Fix

### CRITICAL (2)

#### VULN-001: Command Injection in auto-plan-state.sh
**File**: `~/.claude/hooks/auto-plan-state.sh`
**Lines**: 80, 83-86, 108
**Issue**: Unescaped variables passed to jq --arg

**Fix needed**:
```bash
# Validate task content before using
if [[ "$task" =~ [^a-zA-Z0-9[:space:]._-] ]]; then
    task="Unknown task (invalid characters)"
fi
```

#### VULN-002: Command Injection in inject-session-context.sh
**File**: `~/.claude/hooks/inject-session-context.sh`
**Lines**: 93-95, 102-105, 112-115
**Issue**: Unescaped GOAL, RECENT, HEADER variables

**Fix needed**: Sanitize all variables from file reads

---

### HIGH (2)

#### VULN-003: Inadequate JSON Input Validation
**Files**: All hooks
**Issue**: No size limit on stdin, no schema validation

**Fix needed**:
```bash
# Add to all hooks
INPUT=$(head -c 1048576)  # Max 1MB
if ! echo "$INPUT" | jq -e '.tool_name | type == "string"' >/dev/null 2>&1; then
    log "ERROR" "Invalid JSON schema"
    return_json true "Invalid input"
    exit 0
fi
```

#### VULN-004: Path Traversal in auto-plan-state.sh
**File**: `~/.claude/hooks/auto-plan-state.sh`
**Lines**: 68-72
**Issue**: Symlink attack possible

**Fix needed**:
```bash
ANALYSIS_FILE=$(realpath "$ANALYSIS_FILE" 2>/dev/null || echo "$ANALYSIS_FILE")
if [[ "$ANALYSIS_FILE" != "$PWD/.claude/orchestrator-analysis.md" ]]; then
    log "ERROR" "Path validation failed"
    return_json true "Invalid path"
    exit 0
fi
```

---

### MEDIUM (3)

#### VULN-005: Race Condition in auto-plan-state.sh
**Lines**: 185-194
**Issue**: chmod 600 AFTER mv creates TOCTOU window

**Fix**: Set chmod BEFORE mv

#### VULN-006: World-Readable Hook Permissions
**Files**: All .sh hooks
**Fix**: `chmod 700 ~/.claude/hooks/*.sh`

#### VULN-007: grep ReDoS in context-warning.sh
**Lines**: 93-102
**Fix**: Add `| head -c 500` to limit output

---

### LOW (2)

#### VULN-008: Predictable Temp File Names
**File**: auto-plan-state.sh
**Fix**: Use `mktemp -t plan-state.XXXXXX`

#### VULN-009: Unvalidated Env Var Expansion
**File**: git-safety-guard.py, Line 65
**Fix**: Whitelist only TMPDIR, TMP, TEMP

---

## Unit Tests to Add

Add to `tests/test_hooks_v2454.py`:

```python
class TestSecurityHardening:
    """Tests for security vulnerability fixes"""

    def test_command_injection_resistance(self):
        """VULN-001/002: Test hooks reject malicious input"""
        malicious_inputs = [
            '{"tool_input": {"file_path": "foo$(rm -rf /)"}}',
            '{"tool_name": "Task", "session_id": "$(whoami)"}',
        ]
        for hook in ['auto-plan-state.sh', 'inject-session-context.sh']:
            for payload in malicious_inputs:
                result = run_hook(hook, payload)
                assert '$(' not in result.get('message', '')

    def test_input_size_limit(self):
        """VULN-003: Test hooks reject oversized input"""
        large_input = '{"data": "' + 'x' * 2_000_000 + '"}'
        for hook in HOOKS:
            result = run_hook(hook, large_input, timeout=5)
            assert result is not None  # Should not hang

    def test_path_traversal_blocked(self):
        """VULN-004: Test symlink attacks are blocked"""
        # Create symlink attack
        os.symlink('/etc/passwd', '.claude/orchestrator-analysis.md')
        try:
            result = run_hook('auto-plan-state.sh', '{}')
            assert 'passwd' not in str(result)
        finally:
            os.unlink('.claude/orchestrator-analysis.md')

    def test_file_permissions(self):
        """VULN-006: Test hooks have restrictive permissions"""
        for hook in HOOKS_DIR.glob('*.sh'):
            mode = hook.stat().st_mode & 0o777
            assert mode == 0o700, f"{hook.name} has insecure permissions {oct(mode)}"
```

---

## Commands to Run

```bash
# In new session:
# 1. Fix CRITICAL issues first
# 2. Fix HIGH issues
# 3. Fix MEDIUM/LOW issues
# 4. Add unit tests
# 5. Run full test suite
pytest tests/test_hooks_v2454.py -v

# 6. Set proper permissions
chmod 700 ~/.claude/hooks/*.sh
```

---

## Files to Modify

1. `~/.claude/hooks/auto-plan-state.sh` - VULN-001, 004, 005, 008
2. `~/.claude/hooks/inject-session-context.sh` - VULN-002
3. `~/.claude/hooks/context-warning.sh` - VULN-007
4. `~/.claude/hooks/git-safety-guard.py` - VULN-009
5. All hooks - VULN-003 (input validation)
6. `tests/test_hooks_v2454.py` - Add security tests

---

**Priority**: CRITICAL > HIGH > MEDIUM > LOW
