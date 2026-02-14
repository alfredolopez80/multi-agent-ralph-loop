# Learning System Tests

**Version**: 2.88.0
**Last Updated**: 2026-02-14

## Overview

Unit tests for the curator, repo-learn, and auto-learning system components.

## Tests Included

| Test | Description | Gap Fixed |
|------|-------------|-----------|
| Domain Detection | Validates domain keyword definitions | GAP-C02 |
| Pattern Extraction | Tests extract_patterns_from_files function | GAP-C01 |
| Manifest Files Population | Verifies files[] array is populated | GAP-C01 |
| Learning Gate Enforcement | Tests blocking capability | GAP-C03 |
| Lock Contention Fix | Validates exponential backoff | GAP-H01 |
| Rule Backfill | Tests backfill-domains.sh | GAP-C02 |
| Orchestrator Auto-Learn | Validates domain-based counting | Integration |
| Curator Scripts Existence | Checks all scripts present | Setup |
| JSON Schema Validation | Validates JSON formats | Data |

## Running Tests

```bash
# Run all tests
./tests/learning-system/test-learning-system-v2.88.sh

# Run with verbose output
./tests/learning-system/test-learning-system-v2.88.sh --verbose
```

## Pre-commit Integration

Add to `.git/hooks/pre-commit`:

```bash
# Run learning system tests
echo "Running learning system tests..."
./tests/learning-system/test-learning-system-v2.88.sh || {
    echo "ERROR: Learning system tests failed"
    exit 1
}
```

## Test Coverage

### GAP-C01: Empty Manifest Files
- Tests `update_manifest()` function
- Verifies `files[]` array population
- Checks `patterns_extracted` field

### GAP-C02: Uncategorized Rules
- Tests domain detection from content
- Validates backfill script functionality
- Checks domain keyword coverage

### GAP-C03: Learning Gate Not Enforced
- Tests blocking capability
- Validates exit codes
- Checks configuration options

### GAP-H01: Lock Contention
- Tests exponential backoff
- Validates retry mechanism
- Checks graceful degradation

## Related Documentation

- [Learning System Audit](../../docs/audits/LEARNING_SYSTEM_AUDIT_v2.88.md)
- [Curator Learn Script](../../.claude/scripts/curator-learn.sh)
- [Orchestrator Auto-Learn Hook](../../.claude/hooks/orchestrator-auto-learn.sh)
