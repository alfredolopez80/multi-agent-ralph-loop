# Hook Testing Patterns - v2.52.0

This document captures the testing patterns established to ensure hooks work correctly and prevent regressions.

## Test Philosophy

**BEHAVIORAL over STATIC**: Tests must execute hooks with real inputs and validate outputs, not just check code presence.

```python
# ❌ BAD - Static test (just checks code exists)
def test_function_exists():
    assert "escape_for_grep" in hook_source

# ✅ GOOD - Behavioral test (executes and validates)
def test_escape_for_grep_blocks_injection():
    result = run_hook(HOOK_PATH, malicious_input)
    assert result["returncode"] == 0
    assert result["is_valid_json"]
```

## Core Test Categories

### 1. JSON Output Validation
Every hook MUST return valid JSON with `{"decision": "continue"}` format.

```python
def test_valid_json_always_returned(self):
    test_cases = [
        {},                           # Empty
        None,                         # Null
        "invalid json",              # String
        {"tool_name": 123},          # Wrong type
    ]
    for input_data in test_cases:
        result = run_hook(HOOK_PATH, json.dumps(input_data))
        assert result["is_valid_json"], f"Failed for: {input_data}"
```

### 2. Security - Command Injection
Test all shell metacharacters and injection vectors.

```python
INJECTION_PAYLOADS = [
    "; touch /tmp/pwned ;",
    "$(touch /tmp/pwned)",
    "`touch /tmp/pwned`",
    "| cat /etc/passwd",
    "&& rm -rf /",
    "test\nrm -rf /",
    "test\x00null",
]

def test_injection_blocked(self):
    for payload in INJECTION_PAYLOADS:
        result = run_hook(HOOK_PATH, create_input(payload))
        assert marker_file_not_created()
```

### 3. Security - Path Traversal
Validate symlink resolution and path containment.

```python
def test_path_traversal_blocked(self):
    # Verify realpath used
    assert "realpath" in hook_source
    # Verify base path check
    assert "=~ ^" in hook_source or ".startswith(" in hook_source
```

### 4. Security - Race Conditions
Verify TOCTOU mitigations.

```python
def test_atomic_operations(self):
    assert "set -o noclobber" in hook_source  # Atomic create
    assert "umask 077" in hook_source         # Restrictive perms
    assert "chmod 700" in hook_source         # Explicit perms
```

### 5. Edge Cases
Test boundary conditions and unusual inputs.

```python
EDGE_CASES = [
    "émoji 🚀 unicode",           # Unicode
    "a" * 10000,                  # Long (10KB safe limit)
    'test "quotes" and \\slash',  # Special chars
    "test\x00null\x00bytes",      # Null bytes
    "test\x07\x1b[31mcontrol",    # Control chars
]
```

### 6. Error Handling
Hooks must never crash and always return valid JSON.

```python
def test_always_exit_zero(self):
    """Even on errors, hook should exit 0 with JSON error message."""
    result = run_hook(HOOK_PATH, "completely invalid garbage")
    assert result["returncode"] == 0

def test_stderr_clean(self):
    """Stderr should be clean or go to log file, not pollute output."""
    result = run_hook(HOOK_PATH, valid_input)
    assert result["stderr"] == "" or "DEBUG" not in result["stderr"]
```

### 7. Regressions
Add specific tests for each past bug.

```python
def test_regression_SECURITY_001_command_injection(self):
    """SECURITY-001: Keywords must use escape_for_grep."""
    result = run_hook(HOOK_PATH, injection_payload)
    assert safe_output(result)

def test_regression_ADV_001_schema_validation(self):
    """ADV-001: Input JSON must be validated before processing."""
    assert "validate_input_schema" in hook_source
```

### 8. Performance
Verify hooks respond quickly.

```python
MAX_EXECUTION_TIME = 5.0  # seconds

def test_performance(self):
    result = run_hook(HOOK_PATH, valid_input)
    assert result["execution_time"] < MAX_EXECUTION_TIME

def test_fast_path_immediate(self):
    """Non-matching tools should return instantly."""
    start = time.time()
    result = run_hook(HOOK_PATH, non_matching_input)
    assert time.time() - start < 0.1  # 100ms
```

## Helper Functions

### `run_hook()` - Execute hook with real subprocess

```python
def run_hook(hook_path: Path, input_json: str,
             cwd: str = None, timeout: int = 10) -> Dict:
    """Execute hook and return comprehensive result."""
    result = subprocess.run(
        ["bash", str(hook_path)],
        input=input_json.encode(),
        capture_output=True,
        timeout=timeout,
        cwd=cwd
    )

    return {
        "returncode": result.returncode,
        "stdout": result.stdout.decode(),
        "stderr": result.stderr.decode(),
        "output": try_parse_json(result.stdout),
        "is_valid_json": is_valid_json(result.stdout),
        "execution_time": measured_time,
    }
```

## Codex CLI Integration

Run Codex CLI for independent review of hooks:

```bash
codex exec -m gpt-5.2-codex --sandbox read-only \
  --config model_reasoning_effort=high \
  "review ~/.claude/hooks/smart-memory-search.sh \
   --focus security,edge-cases,error-handling,json-output-validation" \
  2>/dev/null
```

Expected output format:
```json
{
  "findings": [
    {
      "id": "SMMS-001",
      "severity": "HIGH|MEDIUM|LOW|ADVISORY",
      "category": "CATEGORY",
      "lines": "X-Y",
      "issue": "Description",
      "recommendation": "Fix"
    }
  ]
}
```

## Known Limitations (Document for Future Fixes)

| ID | Severity | Issue | Status |
|----|----------|-------|--------|
| SMMS-001 | HIGH | ERR trap needed for guaranteed JSON output | Pending |
| SMMS-002 | MEDIUM | Full JSON escaping needed in additionalContext | Pending |
| SMMS-003 | MEDIUM | Atomic file write (temp+mv) needed | Pending |
| SMMS-005 | LOW | Input size limit needed (currently unbounded) | Documented |

## Adding Tests for New Hooks

1. **Copy template** from `test_hooks_comprehensive.py`
2. **Add all 8 categories** of tests
3. **Run behavioral tests** - don't just check code presence
4. **Add regression tests** for any bugs found during development
5. **Run Codex CLI** for independent security review
6. **Document limitations** that can't be fixed immediately

## Running Tests

```bash
# All hook tests
python -m pytest tests/test_hooks_comprehensive.py -v

# Specific category
python -m pytest tests/test_hooks_comprehensive.py::TestSecurityCommandInjection -v

# With coverage
python -m pytest tests/test_hooks_comprehensive.py --cov=tests -v
```

---

*Generated by Claude Opus 4.5 - v2.52.0 Hook Validation Suite*
