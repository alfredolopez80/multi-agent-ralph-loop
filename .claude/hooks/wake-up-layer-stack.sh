#!/bin/bash
umask 077
# wake-up-layer-stack.sh — SessionStart Hook, Wave 2.2 Layer Stack
# ================================================================
#
# Event: SessionStart
# Wave:  W2.2 (layer-stack)
# Plan:  .ralph/plans/cheeky-dazzling-catmull.md
#
# Loads only L0 (identity) + L1 (essential rules) at session start.
# Target: <1500 tokens total wake-up cost.
#
# Activation: NOT yet registered in settings.json (W4.2 hook-consolidation
#             will activate this hook and retire session-start-restore-context.sh).
#
# Input (JSON via stdin):
#   - hook_event_name: "SessionStart"
#   - session_id: session identifier
#
# Output (JSON via stdout):
#   {
#     "hookSpecificOutput": {
#       "hookEventName": "SessionStart",
#       "additionalContext": "<L0 + L1 content>"
#     }
#   }
#
# Format reference: tests/HOOK_FORMAT_REFERENCE.md
# SessionStart hooks use hookSpecificOutput.additionalContext per official docs.
#
# VERSION: 1.0.0
# CREATED: 2026-04-07

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_DIR="${HOME}/Documents/GitHub/multi-agent-ralph-loop"
LIB_DIR="${REPO_DIR}/.claude/lib"
LOG_FILE="${HOME}/.ralph/logs/wake-up-layer-stack.log"
L0_PATH="${HOME}/.ralph/layers/L0_identity.md"
L1_PATH="${HOME}/.ralph/layers/L1_essential.md"
VAULT_DIR="${HOME}/Documents/Obsidian/MiVault"
VAULT_INDEX="${VAULT_DIR}/_vault-index.md"
L2_DIR="${HOME}/.ralph/layers/L2_wings"
LINT_REPORT_DIR="${VAULT_DIR}/global/output/reports"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.ralph/logs"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] wake-up-layer-stack: $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Read stdin (SEC-111: limit to 100KB to prevent DoS)
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

log "INFO SessionStart triggered session=${SESSION_ID}"

# ---------------------------------------------------------------------------
# Load L0 — Identity
# ---------------------------------------------------------------------------
L0_CONTENT=""
if [[ -f "$L0_PATH" ]]; then
    L0_CONTENT=$(cat "$L0_PATH" 2>/dev/null || echo "")
    log "INFO L0 loaded chars=${#L0_CONTENT}"
else
    L0_CONTENT="[L0 identity file missing at ${L0_PATH}]"
    log "WARN L0 file not found at ${L0_PATH}"
fi

# ---------------------------------------------------------------------------
# Load L1 — Essential rules (plain markdown, no decoding needed)
# Note: Original W2.2 design used AAAK encoding here, but cl100k_base
# measurement showed AAAK INCREASED tokens by ~20%. Plain markdown is now
# canonical. See docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md.
# ---------------------------------------------------------------------------
L1_CONTENT=""
if [[ -f "$L1_PATH" ]]; then
    L1_CONTENT=$(cat "$L1_PATH" 2>/dev/null || echo "")
    log "INFO L1 loaded chars=${#L1_CONTENT}"
else
    L1_CONTENT="[L1 not built — run: python3 -c \"import sys; sys.path.insert(0, '${LIB_DIR}'); from layers import Layer1; Layer1().build()\"]"
    log "WARN L1 file not found at ${L1_PATH}"
fi

# ---------------------------------------------------------------------------
# Load Vault Stats (from _vault-index.md)
# W1.1: Karpathy-style vault context at wake-up
# ---------------------------------------------------------------------------
VAULT_STATS=""
if [[ -f "$VAULT_INDEX" ]]; then
    # Extract only the ## Statistics section (first 8 lines after that header)
    VAULT_STATS=$(sed -n '/^## Statistics/,/^## /{ /^## Statistics/p; /^## /!p; }' "$VAULT_INDEX" 2>/dev/null | head -8 || echo "")
    if [[ -n "$VAULT_STATS" ]]; then
        log "INFO vault stats loaded chars=${#VAULT_STATS}"
    fi
else
    log "WARN vault index not found at ${VAULT_INDEX}"
fi

# ---------------------------------------------------------------------------
# Load L2 Wing Summary (project-specific context, if exists)
# W2.2: Auto-compiled project context from facts/decisions
# ---------------------------------------------------------------------------
WING_SUMMARY=""
PROJECT_NAME=""
if command -v git &>/dev/null; then
    PROJECT_NAME=$(basename "$(git -C "${REPO_DIR}" rev-parse --show-toplevel 2>/dev/null || echo "")" 2>/dev/null || echo "")
fi
if [[ -n "$PROJECT_NAME" && -f "${L2_DIR}/${PROJECT_NAME}/context.md" ]]; then
    WING_SUMMARY=$(head -20 "${L2_DIR}/${PROJECT_NAME}/context.md" 2>/dev/null || echo "")
    if [[ -n "$WING_SUMMARY" ]]; then
        log "INFO L2 wing loaded project=${PROJECT_NAME} chars=${#WING_SUMMARY}"
    fi
fi

# ---------------------------------------------------------------------------
# Load Lint Summary (if vault lint ran yesterday)
# W5.3: One-line lint health check
# ---------------------------------------------------------------------------
LINT_SUMMARY=""
YESTERDAY=$(date -u -v-1d +"%Y-%m-%d" 2>/dev/null || date -u -d "yesterday" +"%Y-%m-%d" 2>/dev/null || echo "")
if [[ -n "$YESTERDAY" && -f "${LINT_REPORT_DIR}/vault-lint-${YESTERDAY}.md" ]]; then
    LINT_ORPHANS=$(grep -c "orphan" "${LINT_REPORT_DIR}/vault-lint-${YESTERDAY}.md" 2>/dev/null || echo "0")
    LINT_STALE=$(grep -c "stale" "${LINT_REPORT_DIR}/vault-lint-${YESTERDAY}.md" 2>/dev/null || echo "0")
    LINT_CONFLICTS=$(grep -c "contradiction" "${LINT_REPORT_DIR}/vault-lint-${YESTERDAY}.md" 2>/dev/null || echo "0")
    LINT_SUMMARY="Vault lint (${YESTERDAY}): ${LINT_ORPHANS} orphans, ${LINT_STALE} stale, ${LINT_CONFLICTS} contradictions"
    log "INFO lint summary loaded: ${LINT_SUMMARY}"
fi

# ---------------------------------------------------------------------------
# Load Top-N memory nodes by SCORE via recall_v2 (B3), with ctx-query fallback.
#
# B3: the primary source for the "Top Procedural Rules" block is now the typed
# memory tree (scripts/memory/recall_v2.py), which selects the top-N MemoryNode
# v2 entries by their score for THIS project/worktree. If the project tree is
# empty (still migrating) or recall yields nothing, we FALL BACK to the A2
# ctx-query index over ~/.ralph/procedural/rules.json — so wake-up never fails
# because the memory tree is empty.
#
# Only the top-N selection block is affected; L0 (identity), L1 (essential),
# and L2 (wing) loads above are intentionally NOT touched.
# ---------------------------------------------------------------------------
TOPN_SUMMARY=""
TOPN_SOURCE=""
_WUL_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve the working-tree root (worktree-safe) for project isolation.
# shellcheck source=lib/worktree-utils.sh
source "${_WUL_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || true
if declare -f get_safe_project_root >/dev/null 2>&1; then
    _WUL_PROJECT_ROOT="$(get_safe_project_root)"
else
    _WUL_PROJECT_ROOT="$(git -C "${REPO_DIR}" rev-parse --show-toplevel 2>/dev/null || echo "${REPO_DIR}")"
fi

# --- Primary: recall_v2 top-N by score -------------------------------------
RECALL_PY="${_WUL_HOOK_DIR}/../../scripts/memory/recall_v2.py"
if [[ -f "$RECALL_PY" ]] && command -v python3 >/dev/null 2>&1; then
    # A broad, low-risk query surfaces the highest-scoring nodes for this
    # project. The terms include the canonical tags attached to captured
    # learnings (session-learning / continuous-learning) plus the common
    # domain anchors, so the top scorers are reliably matched by recall_v2's
    # tag/summary/trigger scoring (rather than depending on a single keyword).
    RECALL_JSON=$(python3 "$RECALL_PY" \
        --project-root "$_WUL_PROJECT_ROOT" \
        --query "session-learning continuous-learning decision root cause fix validated rule pattern hooks security testing database backend frontend" \
        --limit 5 --json 2>>"$LOG_FILE" || echo "")
    if [[ -n "$RECALL_JSON" ]]; then
        TOPN_LINES=$(echo "$RECALL_JSON" | jq -r '
            (.memory_context // [])
            | map("- (score \(.score)) "
                  + ((.summary // "") | if length > 90 then .[:90] + "..." else . end))
            | join("\n")
        ' 2>/dev/null || echo "")
        if [[ -n "$TOPN_LINES" && "$TOPN_LINES" != "null" ]]; then
            TOPN_SUMMARY="$TOPN_LINES"
            TOPN_SOURCE="recall_v2 by score"
            log "INFO top-N memory nodes loaded via recall_v2 count=$(echo "$TOPN_LINES" | grep -c .)"
        fi
    fi
fi

# --- Fallback: A2 ctx-query index over rules.json --------------------------
if [[ -z "$TOPN_SUMMARY" && -f "${_WUL_HOOK_DIR}/lib/ctx-query.sh" ]]; then
    log "INFO recall_v2 returned no nodes (empty tree?); falling back to ctx-query"
    # shellcheck disable=SC1091
    source "${_WUL_HOOK_DIR}/lib/ctx-query.sh" 2>/dev/null || true
    if declare -f ctx_query_top_rules >/dev/null 2>&1; then
        # TSV rows: rule_id\tdomain\tconfidence\tusage\tscore\tbehavior\ttrigger\ttags
        TOPN_RAW=$(ctx_query_top_rules 5 2>/dev/null || echo "")
        if [[ -n "$TOPN_RAW" ]]; then
            TOPN_LINES=$(echo "$TOPN_RAW" | awk -F'\t' '{ b=$6; if (length(b) > 90) b=substr(b,1,90) "..."; printf "- **%s** (%s, score %.0f): %s\n", $1, $2, $5, b }')
            if [[ -n "$TOPN_LINES" ]]; then
                TOPN_SUMMARY="$TOPN_LINES"
                TOPN_SOURCE="ctx-query index (fallback)"
                log "INFO top-N procedural rules loaded via ctx-query count=$(echo "$TOPN_RAW" | grep -c . )"
            fi
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Compose context (L0 + L1 + Vault Stats + Wing + Lint + Top-N rules)
# ---------------------------------------------------------------------------
EXTRA_SECTIONS=""

if [[ -n "$TOPN_SUMMARY" ]]; then
    EXTRA_SECTIONS="${EXTRA_SECTIONS}

### Top Procedural Rules (${TOPN_SOURCE:-memory})
${TOPN_SUMMARY}

"
fi

if [[ -n "$VAULT_STATS" ]]; then
    EXTRA_SECTIONS="${EXTRA_SECTIONS}

### Vault Stats
${VAULT_STATS}

"
fi

if [[ -n "$WING_SUMMARY" ]]; then
    EXTRA_SECTIONS="${EXTRA_SECTIONS}

### Project Wing (L2): ${PROJECT_NAME}
${WING_SUMMARY}

"
fi

if [[ -n "$LINT_SUMMARY" ]]; then
    EXTRA_SECTIONS="${EXTRA_SECTIONS}

### Vault Health
${LINT_SUMMARY}

"
fi

CONTEXT="## Ralph Layer Stack — Session Wake-Up

### Identity (L0)

${L0_CONTENT}

---

### Essential Rules (L1)

${L1_CONTENT}
${EXTRA_SECTIONS}
---

*Layer stack loaded at $(date -u +"%Y-%m-%dT%H:%M:%SZ") | Living Wiki v4.0 | Karpathy cycle: INGEST→QUERY→WRITEBACK→LINT*"

log "INFO context composed chars=${#CONTEXT}"

# ---------------------------------------------------------------------------
# Measure token cost and log it.
# Prefer a real tiktoken cl100k_base count (learned rule: NEVER use wc -w for
# token claims). Fall back to the word-based heuristic only if tiktoken is
# unavailable, and mark the estimate as approximate in that case.
# ---------------------------------------------------------------------------
TOKEN_ESTIMATE=""
if command -v python3 >/dev/null 2>&1; then
    TOKEN_ESTIMATE=$(printf '%s' "$CONTEXT" | python3 -c '
import sys
try:
    import tiktoken
    enc = tiktoken.get_encoding("cl100k_base")
    print(len(enc.encode(sys.stdin.read())))
except Exception:
    pass
' 2>/dev/null || echo "")
fi
if [[ -n "$TOKEN_ESTIMATE" ]]; then
    log "INFO token_count tiktoken_cl100k=${TOKEN_ESTIMATE} target=1500"
else
    WORD_COUNT=$(echo "$CONTEXT" | wc -w | tr -d ' ')
    TOKEN_ESTIMATE=$(( (WORD_COUNT * 4 + 2) / 3 ))  # wc -w / 0.75 ≈ * 4/3 (approx)
    log "INFO token_estimate words=${WORD_COUNT} tokens~=${TOKEN_ESTIMATE} (approx, tiktoken unavailable) target=1500"
fi

# ---------------------------------------------------------------------------
# Output SessionStart hook JSON
# Per tests/HOOK_FORMAT_REFERENCE.md:
#   SessionStart format: {"hookSpecificOutput": {"additionalContext": "..."}}
# ---------------------------------------------------------------------------
jq -n \
    --arg ctx "$CONTEXT" \
    --arg sess "$SESSION_ID" \
    --argjson tokens "$TOKEN_ESTIMATE" \
    '{
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": $ctx,
            "_meta": {
                "hook": "wake-up-layer-stack",
                "wave": "W2.2",
                "session_id": $sess,
                "token_estimate": $tokens,
                "layers_loaded": ["L0", "L1"]
            }
        }
    }'

log "INFO hook completed token_estimate=${TOKEN_ESTIMATE}"
