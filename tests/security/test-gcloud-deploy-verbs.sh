#!/usr/bin/env bash
# Test: git-safety-guard.py gcloud deploy/mutate verbs at the ask tier (issue #70)
# Runner: tests/security/fixtures/gcloud_deploy_verbs_runner.py
# Purpose: explicit deploy verb list gated (ask), reads stay allow-listed, both
#          escape hatches documented, existing protections unchanged, and the
#          no-catch-all design pinned (a fresh unlisted verb is not gated).

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$PROJECT_ROOT/tests/security/fixtures/gcloud_deploy_verbs_runner.py"

echo "🔍 gcloud deploy-verbs regression matrix (issue #70)"
echo "====================================================="
echo ""

if python3 "$RUNNER"; then
    echo ""
    echo "✅ PASS: gcloud deploy verbs gated at ask; reads usable; design pinned"
    exit 0
else
    echo ""
    echo "❌ FAIL: gcloud deploy-verb gate regression in git-safety-guard.py (issue #70)"
    exit 1
fi
