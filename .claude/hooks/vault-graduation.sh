#!/usr/bin/env bash
# vault-graduation.sh — Promotes high-confidence vault learnings to .claude/rules/learned/
# Event: SessionStart (*)
# VERSION: 3.0.0
#
# Scans vault wiki articles for learnings with confidence >= 0.7 and >= 3 session confirmations.
# Promotes them to .claude/rules/learned/{category}.md for auto-loading by Claude.
# The user sees changes in git diff at commit time.

set -euo pipefail

# Safety: always output valid JSON for SessionStart
trap 'echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": \"vault-graduation: error\"}}"' ERR INT TERM

VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"
RULES_DIR=".claude/rules/learned"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Skip if vault doesn't exist
if [[ ! -d "$VAULT_DIR/global/wiki" ]]; then
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "vault-graduation: no vault found, skipping"}}'
    exit 0
fi

GRADUATED=0

# Scan global wiki for graduation candidates
find "$VAULT_DIR/global/wiki" -name "*.md" -type f 2>/dev/null | while read -r article; do
    # Extract frontmatter
    confidence=$(sed -n 's/^confidence: *//p' "$article" 2>/dev/null | head -1)
    sessions=$(sed -n 's/^sessions_confirmed: *//p' "$article" 2>/dev/null | head -1)
    category=$(sed -n 's/^category: *//p' "$article" 2>/dev/null | head -1)

    # Check graduation criteria
    if [[ -n "$confidence" ]] && [[ -n "$sessions" ]] && [[ -n "$category" ]]; then
        # Use awk for float comparison
        eligible=$(awk "BEGIN {print ($confidence >= 0.7 && $sessions >= 3) ? 1 : 0}" 2>/dev/null)

        if [[ "$eligible" == "1" ]]; then
            RULES_FILE="$REPO_ROOT/$RULES_DIR/$category.md"

            # Extract rule title
            title=$(grep "^# " "$article" 2>/dev/null | head -1 | sed 's/^# //')

            # Check if already graduated (avoid duplicates)
            if [[ -f "$RULES_FILE" ]] && grep -qF "$title" "$RULES_FILE" 2>/dev/null; then
                continue
            fi

            # Ensure rules directory exists
            mkdir -p "$REPO_ROOT/$RULES_DIR" 2>/dev/null || true

            # Append to category rules file
            {
                echo ""
                echo "- $title (confidence: $confidence, sessions: $sessions, source: $article)"
            } >> "$RULES_FILE" 2>/dev/null || true

            GRADUATED=$((GRADUATED + 1))
        fi
    fi
done

if [[ "$GRADUATED" -gt 0 ]]; then
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": \"vault-graduation: promoted $GRADUATED learnings to rules\"}}"
else
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "vault-graduation: no learnings ready for graduation"}}'
fi
