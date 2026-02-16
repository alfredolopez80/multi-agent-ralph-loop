#!/bin/bash
# Test: JSON Error Handling
# Purpose: Validate all JSON operations have error handling

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 Testing JSON error handling..."

# Find all JSON.parse operations
JSON_PARSE=$(grep -rn "JSON\.parse" --include="*.js" --include="*.ts" . 2>/dev/null | \
  grep -v node_modules | \
  grep -v ".claude/archive/" | \
  grep -v "tests/security/" || true)

if [[ -n "$JSON_PARSE" ]]; then
  # Check if any are NOT in try/catch blocks
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    line_num=$(echo "$line" | cut -d: -f2)

    # Get context around JSON.parse (10 lines before and after)
    context=$(sed -n "$((line_num-10)),$((line_num+10))p" "$file")

    # Check if context contains "try" or "catch"
    if ! echo "$context" | grep -q "try\|catch"; then
      echo "❌ FAIL: JSON.parse without try/catch at $file:$line_num"
      echo "  $line"
      exit 1
    fi
  done <<< "$JSON_PARSE"
fi

echo "✅ PASS: All JSON operations have error handling"
exit 0
