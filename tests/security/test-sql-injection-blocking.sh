#!/bin/bash
# Test: SQL Injection Blocking
# Purpose: Block SQL injection patterns in src/ while allowing in tests/

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 Testing SQL injection blocking..."

# Check that src/ has no SQL injection patterns (should find nothing)
if [[ -d "src/" ]]; then
  SQL_PATTERNS=$(find src/ -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -E "SELECT.*WHERE.*+|query.*\${" 2>/dev/null || true)
  if [[ -n "$SQL_PATTERNS" ]]; then
    echo "❌ FAIL: Found SQL injection patterns in src/:"
    echo "$SQL_PATTERNS"
    exit 1
  fi
  echo "  ✓ No SQL injection patterns in src/"
else
  echo "  ℹ️  No src/ directory found (skipping production check)"
fi

# Check that test files are marked with warnings
if ! grep -r "INTENTIONAL SECURITY VULNERABILITIES" tests/ .claude/tests/ 2>/dev/null; then
  echo "❌ FAIL: Test files not marked with warnings"
  exit 1
fi

echo "✅ PASS: SQL injection properly blocked in src/"
exit 0
