#!/bin/bash
# Test: Logging Standards
# Purpose: Enforce proper logging (no console.log in src/)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 Testing logging standards..."

# Check for console.log in src/ (should find none)
CONSOLE_LOGS=$(grep -rn "console\.log\|console\.error\|console\.warn" src/ --include="*.js" --include="*.ts" 2>/dev/null || true)

if [[ -n "$CONSOLE_LOGS" ]]; then
  echo "❌ FAIL: Found console.log/console.error/console.warn in src/:"
  echo "$CONSOLE_LOGS"
  echo ""
  echo "Use proper logging framework instead:"
  echo "  logger.info()  → for informational messages"
  echo "  logger.error() → for error messages"
  echo "  logger.warn()  → for warnings"
  exit 1
fi

echo "✅ PASS: No console.log in src/ directory"
exit 0
