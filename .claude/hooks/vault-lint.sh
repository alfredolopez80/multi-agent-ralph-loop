#!/bin/bash
# vault-lint.sh — Vault Linter (Wave 5.1, Cron)
# =================================================
#
# Event: Cron (daily, NOT a Claude Code hook)
# Wave:  W5.1 (vault-lint)
# Plan:  .ralph/plans/breezy-coalescing-umbrella.md
#
# Scans vault for health issues:
#   1. Orphan articles (no inbound [[links]])
#   2. Stale articles (>30 days, confidence < 0.7)
#   3. Contradictions (NEVER vs ALWAYS on same topic)
#   4. Missing frontmatter fields
#   5. Old drafts (>7 days with status: draft)
#
# Output: Report at $VAULT/global/output/reports/vault-lint-{date}.md
#
# Install: Add to crontab via `crontab -e`:
#   0 3 * * * /path/to/.claude/hooks/vault-lint.sh
#
# VERSION: 1.0.0
# CREATED: 2026-04-09

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VAULT_DIR="${HOME}/Documents/Obsidian/MiVault"
REPORT_DIR="${VAULT_DIR}/global/output/reports"
LOG_FILE="${HOME}/.ralph/logs/vault-lint.log"
TODAY=$(date +"%Y-%m-%d")
REPORT_FILE="${REPORT_DIR}/vault-lint-${TODAY}.md"
STALE_DAYS=30
DRAFT_DAYS=7

# Required frontmatter fields
REQUIRED_FIELDS="type classification confidence category"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.ralph/logs" "${REPORT_DIR}"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] vault-lint: $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Graceful skip
# ---------------------------------------------------------------------------
if [[ ! -d "$VAULT_DIR" ]]; then
    log "WARN vault missing, skipping lint"
    exit 0
fi

# Counters
ORPHANS=0
STALE=0
CONTRADICTIONS=0
MISSING_FM=0
OLD_DRAFTS=0

# ---------------------------------------------------------------------------
# L1: Find all wiki .md files
# ---------------------------------------------------------------------------
ALL_ARTICLES=$(find "${VAULT_DIR}/global/wiki" "${VAULT_DIR}/projects" -name "*.md" -type f 2>/dev/null | grep -v "_index.md" | grep -v "README.md" | grep -v "diary/" || echo "")

if [[ -z "$ALL_ARTICLES" ]]; then
    log "INFO no wiki articles found, nothing to lint"
    echo "# Vault Lint Report — ${TODAY}

**Status**: No articles found in vault." > "$REPORT_FILE"
    exit 0
fi

# ---------------------------------------------------------------------------
# L2: Orphan detection (articles with no inbound [[links]])
# ---------------------------------------------------------------------------
ORPHAN_LIST=""
while IFS= read -r article; do
    [[ -z "$article" ]] && continue
    article_name=$(basename "$article" .md)

    # Check if any other article links to this one
    INBOUND=$(grep -rl "\[\[${article_name}" "${VAULT_DIR}/" 2>/dev/null | grep -v "$article" | head -1 || echo "")

    if [[ -z "$INBOUND" ]]; then
        ORPHANS=$((ORPHANS + 1))
        ORPHAN_LIST="${ORPHAN_LIST}- ${article_name} ($(echo "$article" | sed "s|${VAULT_DIR}/||"))
"
    fi
done <<< "$ALL_ARTICLES"

# ---------------------------------------------------------------------------
# L3: Stale detection (>30 days, confidence < 0.7)
# ---------------------------------------------------------------------------
STALE_LIST=""
while IFS= read -r article; do
    [[ -z "$article" ]] && continue
    confidence=$(grep -m1 "^confidence:" "$article" 2>/dev/null | sed 's/confidence: *//' || echo "1.0")

    # Check confidence threshold
    is_low=$(echo "$confidence < 0.7" | bc 2>/dev/null || echo "0")
    [[ "$is_low" != "1" ]] && continue

    # Check age
    if [[ "$(uname)" == "Darwin" ]]; then
        article_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$article" 2>/dev/null || echo "$TODAY")
    else
        article_date=$(stat -c "%Y" "$article" 2>/dev/null | xargs -I{} date -d @{} +"%Y-%m-%d" || echo "$TODAY")
    fi

    age_days=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$article_date" +%s 2>/dev/null || echo 0)) / 86400 ))

    if [[ $age_days -gt $STALE_DAYS ]]; then
        STALE=$((STALE + 1))
        STALE_LIST="${STALE_LIST}- $(basename "$article" .md) — ${age_days} days old, confidence=${confidence}
"
    fi
done <<< "$ALL_ARTICLES"

# ---------------------------------------------------------------------------
# L4: Contradiction detection (NEVER vs ALWAYS on same topic)
# ---------------------------------------------------------------------------
CONTRADICTION_LIST=""
# Extract all NEVER and ALWAYS statements
NEVER_FILE=$(mktemp)
ALWAYS_FILE=$(mktemp)

while IFS= read -r article; do
    [[ -z "$article" ]] && continue
    article_name=$(basename "$article" .md)
    grep -i "NEVER\|MUST NOT\|NEVER USE" "$article" 2>/dev/null | while IFS= read -r line; do
        echo "${article_name}: ${line}" >> "$NEVER_FILE"
    done
    grep -i "ALWAYS\|MUST\|SHOULD" "$article" 2>/dev/null | while IFS= read -r line; do
        echo "${article_name}: ${line}" >> "$ALWAYS_FILE"
    done
done <<< "$ALL_ARTICLES"

# Check for contradictions: same keyword in NEVER and ALWAYS
if [[ -f "$NEVER_FILE" && -f "$ALWAYS_FILE" && -s "$NEVER_FILE" && -s "$ALWAYS_FILE" ]]; then
    # Extract key nouns from NEVER statements and check against ALWAYS
    while IFS= read -r never_line; do
        keyword=$(echo "$never_line" | tr -cd 'a-zA-Z0-9 ' | awk '{for(i=1;i<=NF;i++) if(length($i)>5) print $i}' | sort -u | head -3)
        for word in $keyword; do
            if grep -q "$word" "$ALWAYS_FILE" 2>/dev/null; then
                always_article=$(grep "$word" "$ALWAYS_FILE" | head -1 | cut -d: -f1)
                never_article=$(echo "$never_line" | cut -d: -f1)
                if [[ "$always_article" != "$never_article" ]]; then
                    CONTRADICTIONS=$((CONTRADICTIONS + 1))
                    CONTRADICTION_LIST="${CONTRADICTION_LIST}- '${word}': ${never_article} (NEVER) vs ${always_article} (ALWAYS)
"
                fi
            fi
        done
    done < "$NEVER_FILE"
fi
rm -f "$NEVER_FILE" "$ALWAYS_FILE"

# ---------------------------------------------------------------------------
# L5: Frontmatter validation
# ---------------------------------------------------------------------------
MISSING_FM_LIST=""
while IFS= read -r article; do
    [[ -z "$article" ]] && continue
    MISSING=""
    for field in $REQUIRED_FIELDS; do
        if ! grep -q "^${field}:" "$article" 2>/dev/null; then
            MISSING="${MISSING} ${field}"
        fi
    done
    if [[ -n "$MISSING" ]]; then
        MISSING_FM=$((MISSING_FM + 1))
        MISSING_FM_LIST="${MISSING_FM_LIST}- $(basename "$article" .md): missing${MISSING}
"
    fi
done <<< "$ALL_ARTICLES"

# ---------------------------------------------------------------------------
# L6: Old drafts (>7 days with status: draft)
# ---------------------------------------------------------------------------
DRAFT_LIST=""
while IFS= read -r article; do
    [[ -z "$article" ]] && continue
    status=$(grep -m1 "^status:" "$article" 2>/dev/null | sed 's/status: *//' || echo "")
    [[ "$status" != "draft" ]] && continue

    created=$(grep -m1 "^created:" "$article" 2>/dev/null | sed 's/created: *//' | cut -dT -f1 || echo "$TODAY")
    if [[ "$(uname)" == "Darwin" ]]; then
        age_days=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$created" +%s 2>/dev/null || echo 0)) / 86400 ))
    else
        age_days=$(( ($(date +%s) - $(date -d "$created" +%s 2>/dev/null || echo 0)) / 86400 ))
    fi

    if [[ $age_days -gt $DRAFT_DAYS ]]; then
        OLD_DRAFTS=$((OLD_DRAFTS + 1))
        DRAFT_LIST="${DRAFT_LIST}- $(basename "$article" .md) — ${age_days} days old
"
    fi
done <<< "$ALL_ARTICLES"

# ---------------------------------------------------------------------------
# Write lint report
# ---------------------------------------------------------------------------
TOTAL_ARTICLES=$(echo "$ALL_ARTICLES" | wc -l | tr -d ' ')

cat > "$REPORT_FILE" << REPORT
# Vault Lint Report — ${TODAY}

**Total articles**: ${TOTAL_ARTICLES}
**Health score**: $(( 100 - (ORPHANS * 5 + STALE * 3 + CONTRADICTIONS * 10 + MISSING_FM * 2 + OLD_DRAFTS * 1) )) / 100

## Summary

| Check | Count | Severity |
|-------|-------|----------|
| Orphan articles (no inbound links) | ${ORPHANS} | Medium |
| Stale articles (>30 days, low confidence) | ${STALE} | Low |
| Contradictions (NEVER vs ALWAYS) | ${CONTRADICTIONS} | High |
| Missing frontmatter fields | ${MISSING_FM} | Medium |
| Old drafts (>7 days) | ${OLD_DRAFTS} | Low |

## Details

### Orphan Articles (${ORPHANS})
${ORPHAN_LIST:-None found}

### Stale Articles (${STALE})
${STALE_LIST:-None found}

### Contradictions (${CONTRADICTIONS})
${CONTRADICTION_LIST:-None found}

### Missing Frontmatter (${MISSING_FM})
${MISSING_FM_LIST:-None found}

### Old Drafts (${OLD_DRAFTS})
${DRAFT_LIST:-None found}

---
*Generated by vault-lint.sh at $(date -u +"%Y-%m-%dT%H:%M:%SZ")*
REPORT

log "INFO lint complete orphans=${ORPHANS} stale=${STALE} contradictions=${CONTRADICTIONS} missing_fm=${MISSING_FM} drafts=${OLD_DRAFTS}"
exit 0
