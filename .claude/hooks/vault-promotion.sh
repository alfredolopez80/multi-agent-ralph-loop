#!/bin/bash
# vault-promotion.sh — SessionStart Hook (Wave 3.2 + 4.2)
# ========================================================
#
# Event: SessionStart
# Wave:  W3.2 (wiki-promotion) + W4.2 (diary-to-wiki)
# Plan:  .ralph/plans/breezy-coalescing-umbrella.md
#
# Two functions:
# 1. Promotes project wiki articles (GREEN, confidence>=0.7,
#    sessions>=3) to global wiki.
# 2. Scans agent diaries for specialization patterns (3+ same
#    task type) and updates agent _index.md.
#
# Input (JSON via stdin):
#   - hook_event_name: "SessionStart"
#   - session_id: session identifier
#
# Output: {"hookSpecificOutput": {"additionalContext": "..."}}
#
# VERSION: 1.0.0
# CREATED: 2026-04-09

set -euo pipefail
umask 077

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VAULT_DIR="${HOME}/Documents/Obsidian/MiVault"
GLOBAL_WIKI="${VAULT_DIR}/global/wiki"
AGENTS_DIR="${VAULT_DIR}/agents"
LOG_FILE="${HOME}/.ralph/logs/vault-promotion.log"
KNOWN_AGENTS="ralph-coder ralph-reviewer ralph-tester ralph-researcher ralph-frontend ralph-security"

# Promotion thresholds
MIN_CONFIDENCE=0.7
MIN_SESSIONS=3

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.ralph/logs"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] vault-promotion: $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Read stdin (SEC-111)
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

# ---------------------------------------------------------------------------
# Graceful skip
# ---------------------------------------------------------------------------
if [[ ! -d "$VAULT_DIR" ]]; then
    log "WARN vault missing, skipping promotion"
    jq -n --arg ctx "vault-promotion: skipped (vault missing)" '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": $ctx}}'
    exit 0
fi

PROMOTED=0
INCREMENTED=0
SPECIALIZATIONS=0

# ---------------------------------------------------------------------------
# Function: promote_project_wiki_articles
# Scan project wikis for GREEN articles meeting promotion thresholds
# ---------------------------------------------------------------------------
for project_dir in "${VAULT_DIR}/projects"/*/; do
    [[ ! -d "$project_dir" ]] && continue
    wiki_dir="${project_dir}wiki"
    [[ ! -d "$wiki_dir" ]] && continue

    for article in "${wiki_dir}"/*.md; do
        [[ ! -f "$article" ]] && continue
        [[ "$(basename "$article")" == "_index.md" ]] && continue

        # Extract frontmatter values
        classification=$(grep -m1 "^classification:" "$article" 2>/dev/null | sed 's/classification: *//' || echo "")
        confidence=$(grep -m1 "^confidence:" "$article" 2>/dev/null | sed 's/confidence: *//' || echo "0")
        sessions=$(grep -m1 "^sessions_confirmed:" "$article" 2>/dev/null | sed 's/sessions_confirmed: *//' || echo "0")
        category=$(grep -m1 "^category:" "$article" 2>/dev/null | sed 's/category: *//' || echo "general")
        title=$(grep -m1 "^# " "$article" 2>/dev/null | sed 's/^# *//' || basename "$article" .md)

        # Check promotion criteria
        if [[ "$classification" != "GREEN" ]]; then continue; fi

        # Numeric comparison
        meets_confidence=$(echo "$confidence >= $MIN_CONFIDENCE" | bc 2>/dev/null || echo "0")
        meets_sessions=$(echo "$sessions >= $MIN_SESSIONS" | bc 2>/dev/null || echo "0")

        if [[ "$meets_confidence" == "1" && "$meets_sessions" == "1" ]]; then
            # Promote to global wiki
            target_dir="${GLOBAL_WIKI}/${category}"
            mkdir -p "$target_dir"
            target_file="${target_dir}/$(basename "$article")"

            if [[ ! -f "$target_file" ]]; then
                cp "$article" "$target_file"
                log "INFO promoted: ${title} → global/wiki/${category}/"
                PROMOTED=$((PROMOTED + 1))
            fi
        fi

        # Increment sessions_confirmed for query-hit articles
        if [[ -f "${HOME}/.ralph/.last-query-hits" ]]; then
            article_slug=$(basename "$article" .md)
            if grep -q "$article_slug" "${HOME}/.ralph/.last-query-hits" 2>/dev/null; then
                new_sessions=$((sessions + 1))
                sed -i.bak "s/^sessions_confirmed: ${sessions}$/sessions_confirmed: ${new_sessions}/" "$article" 2>/dev/null || true
                rm -f "${article}.bak"
                INCREMENTED=$((INCREMENTED + 1))
            fi
        fi
    done
done

# Clean up query hits file
rm -f "${HOME}/.ralph/.last-query-hits"

# ---------------------------------------------------------------------------
# Function: scan_agent_diaries_for_specialization
# If agent logged same task type 3+ times in past 7 days, update _index.md
# ---------------------------------------------------------------------------
for agent in $KNOWN_AGENTS; do
    diary_dir="${AGENTS_DIR}/${agent}/diary"
    [[ ! -d "$diary_dir" ]] && continue

    # Count task categories across all monthly diaries
    declare -A category_counts
    for diary_file in "${diary_dir}"/*.md; do
        [[ ! -f "$diary_file" ]] && continue
        while IFS= read -r line; do
            cat_name=$(echo "$line" | grep -oE 'Task category.*:.*' | sed 's/Task category.*: *//' | tr -d '*' | head -c 30)
            [[ -z "$cat_name" ]] && continue
            category_counts["$cat_name"]=$(( ${category_counts["$cat_name"]:-0} + 1 ))
        done < "$diary_file"
    done

    # Check for specialization (3+ same category)
    for cat in "${!category_counts[@]}"; do
        if [[ ${category_counts[$cat]} -ge 3 ]]; then
            # Update agent _index.md with specialization
            agent_index="${AGENTS_DIR}/${agent}/_index.md"
            if [[ -f "$agent_index" ]] && ! grep -q "Specialization.*${cat}" "$agent_index" 2>/dev/null; then
                echo "- Specialization detected: ${cat} (${category_counts[$cat]} tasks)" >> "$agent_index"
                log "INFO specialization updated: ${agent} → ${cat} (${category_counts[$cat]})"
                SPECIALIZATIONS=$((SPECIALIZATIONS + 1))
            fi
        fi
    done

    unset category_counts
done

# ---------------------------------------------------------------------------
# Output SessionStart format
# ---------------------------------------------------------------------------
MSG="vault-promotion: ${PROMOTED} promoted, ${INCREMENTED} sessions incremented, ${SPECIALIZATIONS} specializations"
log "INFO ${MSG}"

jq -n --arg ctx "$MSG" '{
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": $ctx,
        "_meta": {
            "hook": "vault-promotion",
            "wave": "W3.2+W4.2",
            "promoted": '"$PROMOTED"',
            "incremented": '"$INCREMENTED"',
            "specializations": '"$SPECIALIZATIONS"'
        }
    }
}'

exit 0
