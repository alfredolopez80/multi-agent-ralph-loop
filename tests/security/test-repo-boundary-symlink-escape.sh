#!/usr/bin/env bash
# Test: repo-boundary-guard.sh symlink-escape fail-closed (issue #45, PR3-C5)
# Runner: tests/security/fixtures/symlink_escape_runner.py
# Purpose: an in-boundary path that resolves through a symlink to OUTSIDE the
#          boundary is denied (canonicalization may not turn an in-boundary
#          reference into an out-of-boundary allow); same-repo symlinks, pure
#          readonly commands and never-claimed paths stay usable.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$PROJECT_ROOT/tests/security/fixtures/symlink_escape_runner.py"

echo "🔍 repo-boundary symlink-escape regression matrix (issue #45)"
echo "=============================================================="
echo ""

if python3 "$RUNNER"; then
    echo ""
    echo "✅ PASS: symlink escapes denied; usable paths stay usable"
    exit 0
else
    echo ""
    echo "❌ FAIL: symlink-escape fail-open regression in repo-boundary-guard.sh (issue #45)"
    exit 1
fi
