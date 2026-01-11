#!/usr/bin/env bash
# Hook: Correlate bugs with Sentry production issues
# Triggered by: PostToolUse(Bash(gh api *)) in find-bugs skill
# Once: true

set -euo pipefail

# Only run if Sentry is configured
if [[ ! -f "sentry.properties" && -z "${SENTRY_DSN:-}" ]]; then
    exit 0  # Graceful skip
fi

# Check if sentry-cli is available
if ! command -v sentry-cli &> /dev/null; then
    echo "💡 Sentry configured but sentry-cli not available"
    echo "   Install: curl -sL https://sentry.io/get-cli/ | bash"
    exit 0
fi

# Get recent issues from Sentry
echo "🔍 Checking Sentry for related production issues..."
ISSUES=$(sentry-cli issues list --query "is:unresolved" --format json --max 20 2>/dev/null || echo "[]")

ISSUE_COUNT=$(echo "$ISSUES" | jq length)
if [[ "$ISSUE_COUNT" -gt 0 ]]; then
    echo "📊 Found $ISSUE_COUNT recent production issues in Sentry"

    # Show top 5 by event count
    echo "$ISSUES" | jq -r '.[:5] | .[] | "  - \(.title) (\(.count) events)"'
else
    echo "✅ No unresolved issues in Sentry"
fi

exit 0
