#!/bin/bash
# Test: Shell Syntax Validation
# Purpose: Validate bash syntax for all shell scripts in .claude/hooks/ and tests/
# Security: Prevents syntax errors from breaking hooks and test suites
# Version: 2.91.0

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ERRORS=0
CHECKED=0

echo "🔍 Shell Syntax Validation"
echo "=========================="
echo ""

# Function to check syntax of shell scripts
check_syntax() {
    local dir="$1"
    local description="$2"

    echo "Checking $description..."

    if [[ ! -d "$dir" ]]; then
        echo "⚠️  Directory not found: $dir"
        return
    fi

    while IFS= read -r -d '' script; do
        CHECKED=$((CHECKED + 1))
        if ! bash -n "$script" 2>/dev/null; then
            echo "❌ FAIL: Syntax error in $script"
            bash -n "$script" 2>&1 | sed 's/^/    /'
            ERRORS=$((ERRORS + 1))
        fi
    done < <(find "$dir" -type f -name "*.sh" -print0)
}

# Check .claude/hooks/
check_syntax "$PROJECT_ROOT/.claude/hooks" "Claude hooks"

# Check tests/
check_syntax "$PROJECT_ROOT/tests" "Test suite"

# Check .claude/tests/ (legacy location, may not exist)
if [[ -d "$PROJECT_ROOT/.claude/tests" ]]; then
    check_syntax "$PROJECT_ROOT/.claude/tests" "Legacy test location"
fi

# Summary
echo ""
echo "=========================="
echo "Checked: $CHECKED scripts"
echo "Errors: $ERRORS"

if [[ $ERRORS -eq 0 ]]; then
    echo "✅ PASS: All shell scripts have valid syntax"
    exit 0
else
    echo "❌ FAIL: Found $ERRORS scripts with syntax errors"
    exit 1
fi
