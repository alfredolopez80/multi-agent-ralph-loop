#!/bin/bash
# Bump all hooks to specified version
# VERSION: 2.57.4
# Usage: ./bump-hooks-version.sh 2.57.4

set -euo pipefail

NEW_VERSION="${1:-2.57.4}"
HOOKS_DIR="${HOME}/.claude/hooks"
PROJECT_HOOKS_DIR="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks"

echo "=== Bumping hooks to version $NEW_VERSION ==="
echo ""

# Count before
BEFORE=$(grep -r "^# VERSION:" "$HOOKS_DIR"/*.sh 2>/dev/null | wc -l)
echo "Files to update: $BEFORE"

# Update global hooks
for f in "$HOOKS_DIR"/*.sh; do
    if [[ -f "$f" ]]; then
        sed -i '' "s/^# VERSION: [0-9]*\.[0-9]*\.[0-9]*/# VERSION: $NEW_VERSION/g" "$f" 2>/dev/null || \
        sed -i "s/^# VERSION: [0-9]*\.[0-9]*\.[0-9]*/# VERSION: $NEW_VERSION/g" "$f"
    fi
done

# Update project hooks
for f in "$PROJECT_HOOKS_DIR"/*.sh; do
    if [[ -f "$f" ]]; then
        sed -i '' "s/^# VERSION: [0-9]*\.[0-9]*\.[0-9]*/# VERSION: $NEW_VERSION/g" "$f" 2>/dev/null || \
        sed -i "s/^# VERSION: [0-9]*\.[0-9]*\.[0-9]*/# VERSION: $NEW_VERSION/g" "$f"
    fi
done

# Count after
AFTER=$(grep -r "^# VERSION: $NEW_VERSION" "$HOOKS_DIR"/*.sh 2>/dev/null | wc -l)
echo "Updated to $NEW_VERSION: $AFTER files"
echo ""
echo "=== Verification ==="
grep "^# VERSION:" "$HOOKS_DIR"/*.sh 2>/dev/null | cut -d':' -f3 | sort | uniq -c
