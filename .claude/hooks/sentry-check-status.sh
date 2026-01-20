#!/usr/bin/env bash
# Hook: Check Sentry CI status after gh pr commands
# Triggered by: PostToolUse(Bash(gh pr *))
# Once: true

# VERSION: 2.57.5
set -euo pipefail

# Extract PR number from last command
PR_NUM=$(echo "$TOOL_OUTPUT" | grep -oE '#[0-9]+' | head -1 | tr -d '#')

if [[ -z "$PR_NUM" ]]; then
    echo "No PR number found in output"
    exit 0
fi

# Check for Sentry-related CI checks
SENTRY_CHECKS=$(gh pr checks "$PR_NUM" --json name,status,conclusion \
    --jq '.[] | select(.name | contains("Sentry"))' 2>/dev/null || echo "")

if [[ -n "$SENTRY_CHECKS" ]]; then
    echo "📊 Sentry CI Checks:"
    echo "$SENTRY_CHECKS" | jq -r '. | "\(.name): \(.status) (\(.conclusion // "in progress"))"'

    # Check for failures
    FAILED=$(echo "$SENTRY_CHECKS" | jq -r 'select(.conclusion == "failure") | .name')
    if [[ -n "$FAILED" ]]; then
        echo "⚠️  Sentry checks failed: $FAILED"
        echo "Consider running: ralph code-review-sentry"
    fi
fi

exit 0
