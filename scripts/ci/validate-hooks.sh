#!/usr/bin/env bash
# validate-hooks.sh - CI hook validation
set -euo pipefail

HOOKS_DIR="${1:-.claude/hooks}"
ERRORS=0

echo "🔍 Validating hooks in $HOOKS_DIR..."

for hook in "$HOOKS_DIR"/*.sh; do
    if [ ! -f "$hook" ]; then continue; fi
    
    echo -n "  Checking $(basename "$hook")... "
    
    # Check syntax
    if ! bash -n "$hook" 2>/dev/null; then
        echo "❌ SYNTAX ERROR"
        ((ERRORS++))
        continue
    fi
    
    # Check executable
    if [ ! -x "$hook" ]; then
        echo "⚠️  NOT EXECUTABLE"
        ((ERRORS++))
        continue
    fi
    
    echo "✅"
done

if [ $ERRORS -gt 0 ]; then
    echo "❌ Found $ERRORS errors"
    exit 1
fi

echo "✅ All hooks validated successfully"
