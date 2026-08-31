#!/usr/bin/env bash
# Test: k8s-context-guard-v2 action-position classification (issue #67)
# Runner: tests/security/fixtures/k8s_action_position_runner.py
# Purpose: two-sided regression matrix — reads allowed by action position,
#          writes still gated, unknown-context protection intact.
# Note: the gcloud case asserts that git-safety-guard.py gates `gcloud app
#       deploy`; it FAILS until that guard gates deploy (reported to lead).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$PROJECT_ROOT/tests/security/fixtures/k8s_action_position_runner.py"

echo "🔍 k8s guard action-position regression matrix (issue #67)"
echo "==========================================================="
echo ""

if python3 "$RUNNER"; then
    echo ""
    echo "PASS: k8s guard classifies by action position; reads allowed, writes gated"
    exit 0
else
    echo ""
    echo "FAIL: action-position regression in k8s-context-guard-v2 (issue #67)"
    exit 1
fi
