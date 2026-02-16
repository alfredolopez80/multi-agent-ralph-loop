#!/bin/bash
# Test: Command Injection Prevention
# Purpose: Validate all command execution uses safe array arguments

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 Testing command injection prevention..."

# Find all execSync/spawn calls with string interpolation
UNSAFE_COMMANDS=$(grep -rn "execSync.*\`\|spawnSync.*\`" --include="*.js" --include="*.ts" . 2>/dev/null | \
  grep -v node_modules | \
  grep -v ".claude/archive/" | \
  grep -v "tests/security/" || true)

if [[ -n "$UNSAFE_COMMANDS" ]]; then
  echo "❌ FAIL: Found unsafe command execution with string interpolation:"
  echo "$UNSAFE_COMMANDS"
  exit 1
fi

# Check for template literals in commands
TEMPLATE_LITERALS=$(grep -rn "execSync.*\${\|spawnSync.*\${" --include="*.js" --include="*.ts" . 2>/dev/null | \
  grep -v node_modules | \
  grep -v ".claude/archive/" | \
  grep -v "tests/security/" || true)

if [[ -n "$TEMPLATE_LITERALS" ]]; then
  echo "❌ FAIL: Found template literals in command execution:"
  echo "$TEMPLATE_LITERALS"
  exit 1
fi

echo "✅ PASS: All command execution uses safe patterns"
exit 0
