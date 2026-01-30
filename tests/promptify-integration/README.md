# Promptify Integration Test Suite

**Version**: 1.0.0
**Date**: 2026-01-30
**Status**: READY FOR VALIDATION

## Overview

This test suite provides comprehensive validation for the Promptify integration with Multi-Agent Ralph Loop. It includes unit tests, integration tests, security tests, and end-to-end tests.

## Test Structure

```
tests/promptify-integration/
├── run-all-tests.sh              # Main test runner
├── test-clarity-scoring.sh       # Clarity scoring algorithm tests
├── test-credential-redaction.sh  # Credential redaction tests
├── test-security-functions.sh    # Security hardening tests
├── test-e2e.sh                   # End-to-end integration tests
└── README.md                     # This file
```

## Quick Start

```bash
# Run all tests
cd tests/promptify-integration
./run-all-tests.sh

# Run individual test suites
./test-clarity-scoring.sh
./test-credential-redaction.sh
./test-security-functions.sh
./test-e2e.sh
```

## Test Suites

### 1. Clarity Scoring Tests (`test-clarity-scoring.sh`)

**Purpose**: Validate the prompt clarity scoring algorithm.

**Test Cases**:
- Very vague prompts (0-30% score)
- Vague prompts (20-40% score)
- Moderately vague prompts (30-50% score)
- Moderate clarity prompts (50-70% score)
- High clarity prompts (70-90% score)
- Very high clarity prompts (90-100% score)
- Edge cases (empty prompts, very short prompts)
- Scoring factor validation (word count, vague words, structure)

**Expected Results**: 30+ test cases, ≥90% pass rate

### 2. Credential Redaction Tests (`test-credential-redaction.sh`)

**Purpose**: Validate credential redaction functionality.

**Test Cases**:
- Password patterns (password:, Password=, PASSWORD)
- Token patterns (token:, access_token=, AUTH_TOKEN)
- API key patterns (api_key:, APIKEY=, apikey)
- Bearer tokens (authorization: Bearer, Authorization: bearer)
- Email addresses (user@example.com)
- Phone numbers (123-456-7890)
- GitHub tokens (ghp_...)
- Slack tokens (xoxb-...)
- AWS keys (AKIA..., 21L)
- Multiple credentials in one text
- Edge cases (empty input, case sensitivity)
- Performance test (100 credentials in <1s)

**Expected Results**: 20+ test cases, ≥95% pass rate

### 3. Security Functions Tests (`test-security-functions.sh`)

**Purpose**: Validate security hardening functions.

**Test Cases**:
- Credential redaction (multiple patterns)
- Clipboard consent (grant/deny)
- Agent timeout (short timeout, successful completion)
- Audit logging (log entry structure, log file creation)
- Input sanitization (null bytes, length limits)
- Security validation (clean prompts, injection attempts, jailbreak attempts, malicious URLs)

**Expected Results**: 15+ test cases, ≥90% pass rate

### 4. End-to-End Tests (`test-e2e.sh`)

**Purpose**: Validate complete integration.

**Test Cases**:
- Vague prompt detection and suggestion
- Clear prompt (no suggestion)
- Hook always continues
- Security - credential redaction in logs
- Integration with command-router
- Configuration override (enable/disable)
- Threshold configuration
- Error handling (invalid JSON)
- Large input handling (>100KB)
- Concurrent execution (5 parallel executions)

**Expected Results**: 10 test cases, 100% pass rate

## Coverage Goals

| Metric | Target | Current |
|--------|--------|---------|
| **Unit Test Coverage** | ≥90% | TBD |
| **Integration Coverage** | ≥85% | TBD |
| **Security Test Coverage** | ≥95% | TBD |
| **E2E Test Coverage** | 100% | TBD |
| **Overall Pass Rate** | ≥90% | TBD |

## Dependencies

### Required Tools

- **bash** 4.0+ (for test execution)
- **jq** 1.5+ (for JSON parsing)
- **sed** (for text processing)
- **grep** (for pattern matching)

### Required Files

- `.claude/hooks/promptify-auto-detect.sh` - Main hook
- `.claude/hooks/promptify-security.sh` - Security library
- `.claude/hooks/command-router.sh` - Command router
- `~/.ralph/config/promptify.json` - Configuration
- `~/.ralph/logs/` - Log directory

## Validation Workflow

### Phase 1: Run Tests

```bash
cd tests/promptify-integration
./run-all-tests.sh
```

### Phase 2: Adversarial Validation

```bash
/adversarial "Review the Promptify integration for security vulnerabilities and potential abuse vectors. Check: docs/promptify-integration/"
```

### Phase 3: Codex CLI Review

```bash
/codex-cli "Review the Promptify integration implementation for code quality, security, and best practices. Focus on: docs/promptify-integration/"
```

### Phase 4: Gemini CLI Validation

```bash
/gemini-cli "Validate the Promptify integration against Claude Code best practices and security guidelines. Analyze: docs/promptify-integration/"
```

## Troubleshooting

### Hook Not Found

**Error**: `Hook file not found: .claude/hooks/promptify-auto-detect.sh`

**Solution**:
```bash
ls -la .claude/hooks/promptify-auto-detect.sh
# If missing, re-create the hook
```

### jq Not Found

**Error**: `jq: command not found`

**Solution**:
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

### Permission Denied

**Error**: `Permission denied: ./run-all-tests.sh`

**Solution**:
```bash
chmod +x tests/promptify-integration/*.sh
```

### Config File Missing

**Error**: `Config file not found: ~/.ralph/config/promptify.json`

**Solution**:
```bash
mkdir -p ~/.ralph/config
cat > ~/.ralph/config/promptify.json <<EOF
{
  "enabled": true,
  "vagueness_threshold": 50
}
EOF
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Promptify Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: sudo apt-get install -y jq
      - name: Run tests
        run: cd tests/promptify-integration && ./run-all-tests.sh
```

## Test Maintenance

### Adding New Tests

1. Create new test file: `test-<feature>.sh`
2. Follow existing test structure
3. Add to `run-all-tests.sh`
4. Update this README

### Updating Tests

When modifying Promptify integration:

1. Update affected test cases
2. Add new test cases for new features
3. Verify all tests pass
4. Update version numbers

### Test Metrics

Track test metrics over time:

```bash
# Count test cases
grep -c "print_result" tests/promptify-integration/*.sh

# Count test files
ls -1 tests/promptify-integration/test-*.sh | wc -l

# Measure test execution time
time ./run-all-tests.sh
```

## Contributing

When adding new features to Promptify:

1. Write tests first (TDD)
2. Implement feature
3. Verify all tests pass
4. Update documentation
5. Submit for review

## License

Part of the Multi-Agent Ralph Loop project.

## References

- [Implementation Plan](../../docs/promptify-integration/IMPLEMENTATION_PLAN.md)
- [Security Analysis](../../docs/promptify-integration/ANALYSIS.md)
- [Configuration Guide](../../docs/promptify-integration/CONFIG.md)
- [User Guide](../../docs/promptify-integration/README.md)

---

**Last Updated**: 2026-01-30
**Maintainer**: Multi-Agent Ralph Loop Team
