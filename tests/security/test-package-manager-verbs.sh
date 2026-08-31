#!/usr/bin/env bash
# Test: git-safety-guard.py package-manager verbs at the ask tier (PR3-C4)
# Runner: tests/security/fixtures/package_manager_verbs_runner.py
# Purpose: brew/pip-global/npm-global mutations gated (ask); local/venv installs
#          and diagnostics stay allow-listed; PACKAGE_DESTRUCTIVE_CONFIRMED=1
#          skips the tier; existing cloud/git protections unchanged.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$PROJECT_ROOT/tests/security/fixtures/package_manager_verbs_runner.py"

echo "🔍 package-manager verbs regression matrix (PR3-C4)"
echo "===================================================="
echo ""

if python3 "$RUNNER"; then
    echo ""
    echo "✅ PASS: package-manager mutations gated; venv flow usable"
    exit 0
else
    echo ""
    echo "❌ FAIL: package-manager gate regression in git-safety-guard.py (PR3-C4)"
    exit 1
fi
