#!/usr/bin/env bash
# Test: k8s-context-guard-v2 unresolved-script-path fail-closed (issue #68)
# Runner: tests/security/fixtures/k8s_unresolved_script_runner.py
# Purpose: literal cloud scripts stay inspected; dynamic/symlink cloud scripts
#          get an explicit deny (never a silent allow, and "deny" — not "ask" —
#          because an ask is auto-approved under bypassPermissions); ordinary
#          non-cloud dynamic scripts that resolve via $HOME/$PWD stay usable.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$PROJECT_ROOT/tests/security/fixtures/k8s_unresolved_script_runner.py"

echo "🔍 k8s guard unresolved-script-path regression matrix (issue #68)"
echo "=================================================================="
echo ""

if python3 "$RUNNER"; then
    echo ""
    echo "✅ PASS: unresolved script paths fail closed; usable scripts stay usable"
    exit 0
else
    echo ""
    echo "❌ FAIL: fail-open regression in k8s-context-guard-v2 script resolution (issue #68)"
    exit 1
fi
