#!/usr/bin/env bash
# Hook: Generate Sentry summary report
# Triggered by: Stop (orchestrator completion)
# Once: true

# VERSION: 2.57.3
# v2.57.3: Added proper Stop hook JSON output (SEC-039)
set -euo pipefail

# SEC-039: Guaranteed valid JSON output on any error (Stop hook format)
trap 'echo '"'"'{"decision": "approve"}'"'"'' ERR EXIT

# Only run if Sentry was used in this session
if [[ ! -f ".sentry-used" ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

echo "📊 Sentry Integration Summary"
echo "=============================="

# Count Sentry skill invocations
SKILL_COUNT=$(grep -c "sentry-" "$HOME/.claude/logs/session.log" 2>/dev/null || echo "0")
echo "Skills invoked: $SKILL_COUNT"

# Check final PR status if applicable
if [[ -n "${PR_NUMBER:-}" ]]; then
    SENTRY_STATUS=$(gh pr checks "$PR_NUMBER" --json name,conclusion \
        --jq '.[] | select(.name | contains("Sentry")) | .conclusion' 2>/dev/null || echo "unknown")
    echo "Final Sentry CI status: $SENTRY_STATUS"
fi

# Cleanup
rm -f ".sentry-used"

# Stop hook must output JSON
echo '{"decision": "approve"}'
exit 0
