#!/bin/bash
# continuous-learning.sh - Extract reusable patterns from session at end
# VERSION: 3.1.0
# Hook: Stop
# Part of Multi-Agent Ralph Loop v3.1.0
#
# v3.1.0: Redirected output to vault pipeline (was ~/.claude/skills/learned/)
#         Now writes to $VAULT_DIR/projects/{project}/lessons/ for vault graduation
# v2.69.0: Inspired by everything-claude-code's continuous learning skill
# v2.68.2: FIX CRIT-011 - Updated hook type declaration and trap pattern

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

# SEC-033: Guaranteed allow on any error.
# Stop hooks: allow = clean exit 0 with NO output; block = {"decision":"block"}.
# "approve" is NOT a valid Stop decision (see tests/HOOK_FORMAT_REFERENCE.md).
# This learning hook must never block stopping, so it emits nothing.
output_json() {
    : # no output -> clean exit allows the Stop
}
trap 'output_json' ERR EXIT

# Read stdin
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top

# v3.1.0: Write to vault instead of ~/.claude/skills/learned/
VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo 'unknown')")
LEARNED_DIR="$VAULT_DIR/projects/$PROJECT_NAME/lessons"
mkdir -p "$LEARNED_DIR" 2>/dev/null || true

# Get session transcript path if available
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
# SEC-029: Sanitize session_id to prevent path traversal
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"
TRANSCRIPT="${HOME}/.claude/projects/${CLAUDE_PROJECT_ID:-default}/${SESSION_ID}.jsonl"

# Skip if transcript doesn't exist or is too short
if [[ ! -f "$TRANSCRIPT" ]]; then
    trap - EXIT
    output_json
    exit 0
fi

# Count messages in transcript
MSG_COUNT=$(wc -l < "$TRANSCRIPT" 2>/dev/null || echo "0")

# Only analyze sessions with 10+ messages
if [[ $MSG_COUNT -lt 10 ]]; then
    trap - EXIT
    output_json
    exit 0
fi

# Look for patterns to extract — write to vault lessons directory
PATTERNS_FILE="${LEARNED_DIR}/learning-${SESSION_ID}-$(date +%Y-%m-%d).md"

# Check for user corrections (indicates learning opportunity)
CORRECTIONS=$(grep -c '"role":"user".*"(no|wrong|actually|instead|should be|fix)"' "$TRANSCRIPT" 2>/dev/null || echo "0")

# Check for error resolutions
ERRORS=$(grep -c '"error"' "$TRANSCRIPT" 2>/dev/null || echo "0")

# Only create pattern file if there were learning opportunities
if [[ $CORRECTIONS -gt 0 ]] || [[ $ERRORS -gt 2 ]]; then
    cat > "$PATTERNS_FILE" << EOF
# Learned Patterns: Session ${SESSION_ID}

Extracted: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Message Count: ${MSG_COUNT}
User Corrections: ${CORRECTIONS}
Errors Resolved: ${ERRORS}

## Review Required

This session had learning opportunities. Review the transcript to extract:

- [ ] Error resolution patterns
- [ ] User correction patterns
- [ ] Workarounds discovered
- [ ] Project-specific conventions

Transcript: ${TRANSCRIPT}

## Notes

[Add extracted patterns here after manual review]
EOF

    # v2.69.0: Write to log file instead of stderr (fixes hook error warnings)
    LOG_FILE="${HOME}/.ralph/logs/continuous-learning.log"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Learning opportunity detected - Review: ${PATTERNS_FILE}" >> "$LOG_FILE" 2>/dev/null || true

    # ──────────────────────────────────────────────
    # B3: Capture validated learnings as MemoryNode v2 (typed memory tree)
    # Reuses scripts/memory/learn_capture.py: should_persist_learning +
    # extract_validated_learning + RED-gate -> tree_store.create_node.
    # Best-effort: a memory-capture failure NEVER blocks the Stop hook.
    # ──────────────────────────────────────────────
    _CL_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=lib/worktree-utils.sh
    source "${_CL_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || true
    if declare -f get_safe_project_root >/dev/null 2>&1; then
        PROJECT_ROOT="$(get_safe_project_root)"
    else
        PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
    fi
    LEARN_CAPTURE_PY="${_CL_HOOK_DIR}/../../scripts/memory/learn_capture.py"
    if [[ -f "$LEARN_CAPTURE_PY" ]] && command -v python3 >/dev/null 2>&1; then
        BRANCH=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        COMMIT=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo "")
        # Build the candidate learning text from the most recent assistant text
        # chunks in the transcript. Sanitization (RED-gate, validated-line
        # extraction) happens inside learn_capture.py — bash only ferries text.
        LEARNING_TEXT=$(jq -rs '
            [ .[]
              | select(.message?.role == "assistant")
              | .message.content
              | if type == "array"
                then (map(select(.type == "text") | .text) | join("\n"))
                else (. // "" | tostring) end
            ] | join("\n") | .[-8000:]
        ' "$TRANSCRIPT" 2>/dev/null || echo "")
        if [[ -n "$LEARNING_TEXT" ]]; then
            CAPTURE_RESULT=$(printf '%s' "$LEARNING_TEXT" | jq -Rs \
                --arg root "$PROJECT_ROOT" \
                --arg branch "$BRANCH" \
                --arg session "$SESSION_ID" \
                --arg commit "$COMMIT" \
                '{text: ., project_root: $root, branch: $branch, session_id: $session, commit: $commit, source_description: "continuous-learning Stop hook"}' \
                2>/dev/null \
                | python3 "$LEARN_CAPTURE_PY" 2>>"$LOG_FILE" || echo '{"status":"error"}')
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] learn_capture: ${CAPTURE_RESULT}" >> "$LOG_FILE" 2>/dev/null || true
        fi
    fi

    # ──────────────────────────────────────────────
    # v3.2: Feed session learnings back to procedural memory
    # Only writes metadata (counts, IDs) — never file contents or code
    # Marked needs_review: true — vault graduation requires sessions_confirmed >= 3
    # ──────────────────────────────────────────────
    PROCEDURAL_FILE="${HOME}/.ralph/procedural/rules.json"
    if [[ -f "$PROCEDURAL_FILE" ]]; then
        RULE_ID="session-$(date +%s)-$RANDOM"
        # Sanitize inputs to prevent JSON injection
        SAFE_PROJECT=$(echo "$PROJECT_NAME" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
        SAFE_SESSION=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
        jq --arg id "$RULE_ID" \
           --arg project "$SAFE_PROJECT" \
           --arg session "$SAFE_SESSION" \
           --argjson corrections "${CORRECTIONS}" \
           --argjson errors "${ERRORS}" \
           '. + {($id): {
               type: "session-learning",
               source: "continuous-learning",
               project: $project,
               session: $session,
               corrections: $corrections,
               errors: $errors,
               created_at: now | floor,
               confidence: 0.5,
               needs_review: true
           }}' "$PROCEDURAL_FILE" > "${PROCEDURAL_FILE}.tmp" \
           && mv "${PROCEDURAL_FILE}.tmp" "$PROCEDURAL_FILE"
    fi
fi

trap - EXIT
output_json
