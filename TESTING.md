# Testing Guide - Multi-Agent Ralph Loop v2.19

This document describes the comprehensive test suite for Multi-Agent Ralph Loop.

## Overview

| Category | Framework | Tests | Coverage |
|----------|-----------|-------|----------|
| **Python** | pytest | 71 | 99% code coverage |
| **Bash** | bats-core | 146 | All components |
| **Total** | - | **217** | Exhaustive validation |

## Quick Start

```bash
# Install test dependencies
pip install pytest pytest-cov
brew install bats-core

# Run all tests
./tests/run_tests.sh

# Run specific categories
./tests/run_tests.sh python    # Python only
./tests/run_tests.sh bash      # Bash only
./tests/run_tests.sh security  # Security tests
./tests/run_tests.sh v218      # v2.19 security fixes
```

## Test Files

### Python Tests

#### `test_git_safety_guard.py` (71 tests)

Tests the PreToolUse hook that blocks destructive git commands.

| Test Class | Tests | Purpose |
|------------|-------|---------|
| `TestNormalizeCommand` | 6 | Whitespace, quotes, env vars, tabs |
| `TestSafePatterns` | 21 | Allowed git commands, safe rm paths |
| `TestBlockedPatterns` | 14 | Destructive commands are detected |
| `TestConfirmationPatterns` | 5 | Force push requires confirmation |
| `TestMainFunction` | 6 | JSON input/output, edge cases |
| `TestBypassPrevention` | 7 | Whitespace injection, quote bypass |
| `TestCoverageGaps` | 6 | Lines 197, 239-248, 265, 278-284 |
| `TestEdgeCases` | 6 | Unicode, long commands, empty input |

**Run:**
```bash
pytest tests/test_git_safety_guard.py -v --cov=.claude/hooks --cov-report=term-missing
```

### Bash Tests (bats)

#### `test_install_security.bats` (30 tests)

Tests the installation script's security and correctness.

| Category | Tests | Purpose |
|----------|-------|---------|
| Script Integrity | 3 | Shebang, set -euo pipefail, executable |
| Backup Functionality | 2 | Timestamped backups |
| Permissions | 2 | chmod +x on scripts and hooks |
| Path Handling | 2 | Safe HOME and SCRIPT_DIR usage |
| Verification | 4 | Dependency checks (jq, curl) |
| Shell RC | 2 | PATH configuration, markers |
| Directory Creation | 3 | mkdir -p, .ralph, .claude dirs |
| Error Handling | 3 | log_error, exit codes, 2>/dev/null |
| Content Integrity | 3 | Version, git-safety-guard, quality-gates |
| Copy Operations | 3 | Script copying, optional copies |
| V2.19 Security | 3 | umask 077, logs directory |

**Run:**
```bash
bats tests/test_install_security.bats
```

#### `test_uninstall_security.bats` (28 tests)

Tests the uninstallation script's safe removal behavior.

| Category | Tests | Purpose |
|----------|-------|---------|
| Script Integrity | 3 | Shebang, set -euo pipefail, executable |
| Selective Removal | 3 | Only Ralph-specific agents/commands/skills |
| Hook Removal | 2 | git-safety-guard.py, quality-gates.sh |
| Settings Handling | 4 | clean_settings_json, backup, jq usage |
| Shell Config | 4 | Marker-based removal, legacy handling |
| External Configs | 4 | Codex/Gemini config with section markers |
| CLI Options | 3 | --keep-backups, --full, --help |
| Safety | 4 | User confirmation, path validation, rm -f |
| Completion | 1 | Success message |

**Run:**
```bash
bats tests/test_uninstall_security.bats
```

#### `test_ralph_security.bats` (33 tests)

Tests the main `ralph` CLI orchestrator.

| Category | Tests | Purpose |
|----------|-------|---------|
| validate_path() | 11 | Regex patterns for metacharacters |
| escape_for_shell() | 3 | printf %q, no sed |
| init_tmpdir() | 3 | mktemp template, chmod 700 |
| cleanup() | 2 | Safe temp dir removal |
| CLI Commands | 4 | help, version, unknown, gates |
| Iteration Limits | 3 | Claude 15, MiniMax 30, Lightning 60 |
| V2.19 Security | 7 | VULN-001, VULN-004, VULN-008 fixes |

**Run:**
```bash
bats tests/test_ralph_security.bats
```

#### `test_mmc_security.bats` (21 tests)

Tests the MiniMax wrapper CLI.

| Category | Tests | Purpose |
|----------|-------|---------|
| CLI Commands | 3 | --help, --version, --status |
| API Key Security | 3 | File permissions, env var, not readable |
| JSON Injection | 4 | Quotes, newlines, backslashes, control chars |
| Dependencies | 2 | jq, curl availability |
| Loop Behavior | 2 | Max iterations, VERIFIED_DONE exit |
| Model Mapping | 2 | M2.1, M2.1-lightning |
| Error Handling | 1 | Missing config |
| V2.19 Security | 4 | VULN-005, VULN-008, chmod 600, jq |

**Run:**
```bash
bats tests/test_mmc_security.bats
```

#### `test_quality_gates.bats` (23 tests)

Tests the quality gates stop hook.

| Category | Tests | Purpose |
|----------|-------|---------|
| Blocking Mode | 3 | Non-blocking returns 0, blocking returns 2 |
| JSON Validation | 3 | Valid/invalid JSON, deeply nested |
| Language Detection | 6 | TS, Python, Go, Rust, Foundry, GitHub Actions |
| Skip Behavior | 2 | Missing npx, missing pyright |
| Color Output | 1 | No ANSI in non-TTY |
| Directory Exclusion | 2 | node_modules, .git |
| Summary Output | 3 | Header, pass message, failure summary |
| Edge Cases | 3 | Empty dir, many files, spaces in names |

**Run:**
```bash
bats tests/test_quality_gates.bats
```

#### `test_settings_merge.bats` (11 tests)

Tests the settings.json merge behavior during install.

| Category | Tests | Purpose |
|----------|-------|---------|
| New Install | 1 | Creates new file |
| Preservation | 4 | User permissions, hooks, MCP servers, custom |
| Deduplication | 2 | No duplicate permissions/hooks on reinstall |
| Schema Handling | 2 | Adds if missing, preserves if present |
| Edge Cases | 2 | Empty settings, multiple matchers |

**Run:**
```bash
bats tests/test_settings_merge.bats
```

## V2.19 Security Tests

The `v218` test mode runs only tests that verify security vulnerability fixes:

```bash
./tests/run_tests.sh v218
```

### VULN-001: Command Injection via escape_for_shell()

**Fix:** Changed from `sed` escaping to `printf %q`

**Tests:**
- `escape_for_shell uses printf %q for safe escaping`
- `escape_for_shell prevents command injection`
- `escape_for_shell handles backticks`

### VULN-003: rm -rf Pattern Bypass

**Fix:** Improved regex patterns in git-safety-guard.py

**Tests:** All 65 Python tests in `test_git_safety_guard.py`

### VULN-004: Path Traversal via validate_path()

**Fix:** Added `realpath -e` to resolve symlinks

**Tests:**
- `validate_path uses realpath -e`
- `validate_path blocks symlink traversal`

### VULN-005: Log File Permissions

**Fix:** Added `chmod 600` after log file creation

**Tests:**
- `log_usage sets chmod 600 on log files`
- `log files are protected with chmod 600`

### VULN-008: Predictable File Permissions

**Fix:** Added `umask 077` at script start

**Tests:**
- `script starts with umask 077` (ralph, mmc, install)
- `temp files created with restrictive permissions`

## Writing New Tests

### Python Tests (pytest)

```python
import pytest
from pathlib import Path
import sys

# Add hooks directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / '.claude' / 'hooks'))
from git_safety_guard import main, normalize_command

class TestNewFeature:
    def test_feature_works(self):
        result = some_function("input")
        assert result == "expected"

    @pytest.mark.parametrize("input,expected", [
        ("case1", "result1"),
        ("case2", "result2"),
    ])
    def test_multiple_cases(self, input, expected):
        assert process(input) == expected
```

### Bash Tests (bats)

```bash
#!/usr/bin/env bats

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    SCRIPT="$PROJECT_DIR/scripts/my_script"

    [ -f "$SCRIPT" ] || skip "script not found"

    TEST_TMPDIR=$(mktemp -d)
}

teardown() {
    [ -n "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

@test "script does something" {
    run bash "$SCRIPT" --arg value
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}

@test "script has security feature" {
    grep -q 'security_pattern' "$SCRIPT"
}
```

## CI Integration

Add to your GitHub Actions workflow:

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install test dependencies
        run: |
          pip install pytest pytest-cov
          sudo apt-get install -y bats

      - name: Run tests
        run: ./tests/run_tests.sh
```

## Test Coverage Goals

- **Python:** Maintain ≥85% code coverage
- **Security functions:** 100% coverage required
- **New features:** Must include tests before merge
- **Security fixes:** Must have dedicated validation tests

## Troubleshooting

### bats not found

```bash
# macOS
brew install bats-core

# Linux
sudo apt-get install bats
```

### pytest-cov not found

```bash
pip install pytest-cov
```

### Tests fail with "script not found"

Ensure you're running from the project root:

```bash
cd /path/to/multi-agent-ralph-loop
./tests/run_tests.sh
```

### Permission denied

```bash
chmod +x tests/run_tests.sh
chmod +x tests/*.bats
```
