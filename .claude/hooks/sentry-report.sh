#!/usr/bin/env bash
# Hook: Stop (sentry-report)
# Generates Sentry summary report at orchestrator completion
# Once: true

# VERSION: 2.68.23
# v2.68.8: Fixed Hook comment format for pre-commit validation
# v2.57.3: Added proper Stop hook JSON output (SEC-039)
set -euo pipefail

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


# SEC-039: Guaranteed valid JSON output on any error (Stop hook format)
trap 'echo '"'"'{"decision": "approve"}'"'"'' ERR EXIT

# Only run if Sentry was used in this session
if [[ ! -f ".sentry-used" ]]; then
    # CRIT-003: Clear trap before explicit JSON output to avoid duplicates
    trap - ERR EXIT
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
# CRIT-003: Clear trap before explicit JSON output to avoid duplicates
trap - ERR EXIT
echo '{"decision": "approve"}'
exit 0
