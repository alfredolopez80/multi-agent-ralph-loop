#!/usr/bin/env bash
# Usage Count Consolidation Hook (v1.0.0)
# Hook: SessionStart
# Purpose: Consolidate pending usage_count updates at session start
#
# This hook processes the pending-updates.jsonl file created by
# procedural-inject.sh v2.60.0 and applies the updates to rules.json
#
# VERSION: 1.0.0
# SECURITY: SEC-006 compliant

set -euo pipefail

# Error trap for guaranteed JSON output (v2.62.3)
trap 'echo "SessionStart trap triggered" >&2' ERR

umask 077

CONSOLIDATE_SCRIPT="${HOME}/.ralph/scripts/consolidate-usage-counts.sh"

# Execute consolidation if script exists
if [[ -x "$CONSOLIDATE_SCRIPT" ]]; then
    "$CONSOLIDATE_SCRIPT" >/dev/null 2>&1 &
    # Run in background to not delay session start
fi

# SessionStart hooks don't need JSON output
exit 0
