#!/bin/bash
#!/usr/bin/env bash
# VERSION: 2.69.0
# Usage Count Consolidation Hook (v2.68.6)
# Hook: SessionStart
# Purpose: Consolidate pending usage_count updates at session start
#
# This hook processes the pending-updates.jsonl file created by
# procedural-inject.sh v2.68.5 and applies the updates to rules.json
#
# v2.68.6: Version bump for consistency audit compliance
# SECURITY: SEC-006 compliant

set -euo pipefail

# v2.69.0: Error trap for SessionStart hooks (plain text OK, no JSON required)
# Removed stderr which causes hook error warnings
trap 'echo "SessionStart usage-consolidate recovery"' ERR EXIT

umask 077

CONSOLIDATE_SCRIPT="${HOME}/.ralph/scripts/consolidate-usage-counts.sh"

# Execute consolidation if script exists
if [[ -x "$CONSOLIDATE_SCRIPT" ]]; then
    "$CONSOLIDATE_SCRIPT" >/dev/null 2>&1 &
    # Run in background to not delay session start
fi

# SessionStart hooks don't need JSON output
exit 0
