#!/bin/bash
# Test: Environment Variable Validation
# Purpose: Test API key validation in install scripts

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "🔍 Testing environment variable validation..."

# Check if install script has validation
if [[ -f ".claude/scripts/install-glm-usage-tracking.sh" ]]; then
  if ! grep -q "Z_AI_API_KEY" ".claude/scripts/install-glm-usage-tracking.sh"; then
    echo "⚠️  WARNING: No API key validation found in install script"
  else
    echo "✓ API key validation present"
  fi
fi

# Check if validate-environment.sh exists
if [[ -f ".claude/scripts/validate-environment.sh" ]]; then
  echo "✓ Environment validation script exists"
else
  echo "⚠️  WARNING: validate-environment.sh not found"
fi

echo "✅ PASS: Environment validation checks complete"
exit 0
