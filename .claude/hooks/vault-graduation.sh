#!/usr/bin/env bash
# vault-graduation.sh — Promotes high-confidence vault learnings to .claude/rules/learned/
# Event: SessionStart (*)
# VERSION: 3.0.0
#
# Scans vault wiki articles for learnings with confidence >= 0.7 and >= 3 session confirmations.
# Promotes them to .claude/rules/learned/{category}.md for auto-loading by Claude.
# The user sees changes in git diff at commit time.

set -euo pipefail
umask 077

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

# FIX: Use process substitution instead of pipe to avoid subshell variable scoping bug.
# With `find | while`, the while loop runs in a subshell and GRADUATED increments are lost.
# With `while ... done < <(find ...)`, the loop runs in the current shell.
while IFS= read -r article; do
    # Extract frontmatter — sanitize to prevent injection via crafted YAML values
    confidence=$(sed -n 's/^confidence: *//p' "$article" 2>/dev/null | head -1 | tr -cd '0-9.')
    sessions=$(sed -n 's/^sessions_confirmed: *//p' "$article" 2>/dev/null | head -1 | tr -cd '0-9')
    category=$(sed -n 's/^category: *//p' "$article" 2>/dev/null | head -1 | tr -cd 'a-zA-Z0-9_-')

    # Validate extracted values are non-empty and sane
    [[ -z "$confidence" || -z "$sessions" || -z "$category" ]] && continue
    [[ ${#category} -gt 64 ]] && continue

    # Use awk for float comparison
    eligible=$(awk "BEGIN {print ($confidence >= 0.7 && $sessions >= 3) ? 1 : 0}" 2>/dev/null)

    if [[ "$eligible" == "1" ]]; then
        RULES_FILE="$REPO_ROOT/$RULES_DIR/$category.md"

        # Extract rule title (strip markdown heading)
        title=$(grep "^# " "$article" 2>/dev/null | head -1 | sed 's/^# //')
        [[ -z "$title" ]] && continue

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
done < <(find "$VAULT_DIR/global/wiki" -name "*.md" -type f 2>/dev/null)

# Also scan project-specific wiki articles for cross-project graduation
if [[ -d "$VAULT_DIR/projects" ]]; then
    while IFS= read -r article; do
        confidence=$(sed -n 's/^confidence: *//p' "$article" 2>/dev/null | head -1 | tr -cd '0-9.')
        sessions=$(sed -n 's/^sessions_confirmed: *//p' "$article" 2>/dev/null | head -1 | tr -cd '0-9')
        category=$(sed -n 's/^category: *//p' "$article" 2>/dev/null | head -1 | tr -cd 'a-zA-Z0-9_-')
        classification=$(sed -n 's/^classification: *//p' "$article" 2>/dev/null | head -1 | tr -cd 'A-Z')

        [[ -z "$confidence" || -z "$sessions" || -z "$category" ]] && continue
        [[ ${#category} -gt 64 ]] && continue

        # Only graduate GREEN (universal) project learnings, not YELLOW (project-specific)
        [[ "$classification" != "GREEN" ]] && continue

        eligible=$(awk "BEGIN {print ($confidence >= 0.7 && $sessions >= 3) ? 1 : 0}" 2>/dev/null)

        if [[ "$eligible" == "1" ]]; then
            RULES_FILE="$REPO_ROOT/$RULES_DIR/$category.md"
            title=$(grep "^# " "$article" 2>/dev/null | head -1 | sed 's/^# //')
            [[ -z "$title" ]] && continue

            if [[ -f "$RULES_FILE" ]] && grep -qF "$title" "$RULES_FILE" 2>/dev/null; then
                continue
            fi

            mkdir -p "$REPO_ROOT/$RULES_DIR" 2>/dev/null || true
            {
                echo ""
                echo "- $title (confidence: $confidence, sessions: $sessions, source: $article)"
            } >> "$RULES_FILE" 2>/dev/null || true

            GRADUATED=$((GRADUATED + 1))
        fi
    done < <(find "$VAULT_DIR/projects" -path "*/wiki/*.md" -type f 2>/dev/null)
fi

if [[ "$GRADUATED" -gt 0 ]]; then
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": \"vault-graduation: promoted $GRADUATED learnings to rules\"}}"
else
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "vault-graduation: no learnings ready for graduation"}}'
fi
