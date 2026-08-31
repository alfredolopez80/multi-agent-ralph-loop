# Security Regression Tests

Comprehensive test suite to prevent security regressions and ensure security fixes remain in place.

## Test Files

### test-shell-syntax-validation.sh
Validates bash syntax for all shell scripts in `.claude/hooks/` and `tests/`.

**Purpose**: Prevents syntax errors from breaking hooks and test suites.

**Run**: `./tests/security/test-shell-syntax-validation.sh`

### test-sql-injection-blocking.sh
Blocks SQL injection patterns in `src/` while allowing them in test files with warnings.

**Purpose**: Prevents SQL injection vulnerabilities in production code.

**Run**: `./tests/security/test-sql-injection-blocking.sh`

### test-command-injection-prevention.sh
Validates all command execution uses safe array arguments.

**Purpose**: Prevents command injection vulnerabilities (CWE-78).

**Run**: `./tests/security/test-command-injection-prevention.sh`

### test-logging-standards.sh
Enforces proper logging framework usage (no console.log in src/).

**Purpose**: Ensures production-ready logging with sensitive data redaction.

**Run**: `./tests/security/test-logging-standards.sh`

### test-json-error-handling.sh
Validates all JSON operations have try/catch error handling.

**Purpose**: Prevents crashes from malformed JSON input.

**Run**: `./tests/security/test-json-error-handling.sh`

### test-k8s-guard-action-position.sh
Two-sided regression matrix for k8s-context-guard-v2 action-position
classification (issue #67): `kubectl get/describe/logs deploy` are READ,
`delete deploy` / `helm deploy` stay gated, unknown-context protection intact.
Runner: `tests/security/fixtures/k8s_action_position_runner.py`. The gcloud
case is a known-gap XFAIL (issue #70): while git-safety-guard.py answers
`allow` it reports XFAIL; once gated it XPASSes and fails the run so the
marker gets removed.

**Run**: `bash tests/security/test-k8s-guard-action-position.sh`

### test-environment-validation.sh
Tests API key and environment variable validation.

**Purpose**: Ensures required environment variables are validated before use.

**Run**: `./tests/security/test-environment-validation.sh`

## Running All Tests

```bash
# Run all security tests
./tests/security/test-*.sh

# Or run individually
./tests/security/test-shell-syntax-validation.sh
./tests/security/test-sql-injection-blocking.sh
# ... etc
```

## CI/CD Integration

Add to `.github/workflows/security-tests.yml`:

```yaml
name: Security Tests
on: [push, pull_request]
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run security tests
        run: ./tests/security/test-*.sh
```

## Test Coverage

- Shell script syntax validation
- SQL injection prevention
- Command injection prevention
- Logging standards enforcement
- JSON error handling validation
- Environment variable validation

**Total Tests**: 6
**Coverage**: All critical security findings from v2.90.2 review

## Version

**Created**: 2026-02-16
**Version**: 2.91.0
**Review**: Comprehensive Security Review v2.90.2
