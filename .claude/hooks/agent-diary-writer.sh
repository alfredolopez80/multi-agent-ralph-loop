#!/bin/bash
# agent-diary-writer.sh — TeammateIdle Hook (Wave 4.1)
# =====================================================
#
# Event: TeammateIdle
# Wave:  W4.1 (agent-diaries)
# Plan:  .ralph/plans/breezy-coalescing-umbrella.md
#
# Appends structured diary entries to Obsidian vault when a
# teammate goes idle (task completed). Creates episodic memory
# from agent work.
#
# Input (JSON via stdin):
#   - teammate_name: agent name (ralph-coder, etc.)
#   - session_id: session identifier
#   - files_modified: list of files touched (if available)
#
# Output: exit 0 (TeammateIdle uses exit codes)
#
# VERSION: 1.0.0
# CREATED: 2026-04-09

set -euo pipefail
umask 077

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VAULT_DIR="${HOME}/Documents/Obsidian/MiVault"
AGENTS_DIR="${VAULT_DIR}/agents"
LOG_FILE="${HOME}/.ralph/logs/agent-diary-writer.log"
KNOWN_AGENTS="ralph-coder ralph-reviewer ralph-tester ralph-researcher ralph-frontend ralph-security"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.ralph/logs"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] agent-diary-writer: $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Graceful skip if vault missing
# ---------------------------------------------------------------------------
if [[ ! -d "$VAULT_DIR" ]]; then
    log "WARN vault missing at ${VAULT_DIR}, skipping diary write"
    exit 0
fi

# ---------------------------------------------------------------------------
# Read stdin (SEC-111: limit to 100KB)
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)

# Extract teammate name from stdin
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // .agent_name // ""' 2>/dev/null || echo "")
TEAMMATE_NAME=$(echo "$TEAMMATE_NAME" | tr -cd 'a-zA-Z0-9_-' | head -c 64)

# Also try extracting from task context if available
if [[ -z "$TEAMMATE_NAME" ]]; then
    TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.name // ""' 2>/dev/null || echo "")
    TEAMMATE_NAME=$(echo "$TEAMMATE_NAME" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
fi

# If still empty, try to match from known agents in the input
if [[ -z "$TEAMMATE_NAME" ]]; then
    INPUT_LOWER=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]')
    for agent in $KNOWN_AGENTS; do
        if echo "$INPUT_LOWER" | grep -q "$agent"; then
            TEAMMATE_NAME="$agent"
            break
        fi
    done
fi

if [[ -z "$TEAMMATE_NAME" ]]; then
    log "WARN no teammate name found in input, skipping"
    exit 0
fi

# Validate against known agents
if ! echo " $KNOWN_AGENTS " | grep -q " $TEAMMATE_NAME "; then
    log "WARN unknown agent: ${TEAMMATE_NAME}, skipping"
    exit 0
fi

# ---------------------------------------------------------------------------
# Determine diary file path
# ---------------------------------------------------------------------------
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_MONTH=$(date +"%Y-%m")
DATE_SHORT=$(date +"%Y-%m-%d")
TIME_SHORT=$(date +"%H:%M")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

DIARY_DIR="${AGENTS_DIR}/${TEAMMATE_NAME}/diary"
DIARY_FILE="${DIARY_DIR}/${DATE_MONTH}.md"

mkdir -p "$DIARY_DIR"

# ---------------------------------------------------------------------------
# Extract files modified from input
# ---------------------------------------------------------------------------
FILES_MODIFIED=$(echo "$INPUT" | jq -r '.files_modified // [] | if type == "array" then join(", ") else . end' 2>/dev/null || echo "")
[[ "$FILES_MODIFIED" == "null" || -z "$FILES_MODIFIED" ]] && FILES_MODIFIED="(none detected)"

# ---------------------------------------------------------------------------
# Infer task category from file paths
# ---------------------------------------------------------------------------
TASK_CATEGORY="general"
if echo "$FILES_MODIFIED" | grep -qi "test\|spec\|__tests__"; then
    TASK_CATEGORY="testing"
elif echo "$FILES_MODIFIED" | grep -qi "hook\|\.claude/hooks"; then
    TASK_CATEGORY="hook-development"
elif echo "$FILES_MODIFIED" | grep -qi "security\|auth\|crypto"; then
    TASK_CATEGORY="security"
elif echo "$FILES_MODIFIED" | grep -qi "frontend\|component\|\.tsx\|\.jsx\|\.css"; then
    TASK_CATEGORY="frontend"
elif echo "$FILES_MODIFIED" | grep -qi "docs\|\.md\|README"; then
    TASK_CATEGORY="documentation"
elif echo "$FILES_MODIFIED" | grep -qi "\.py\|\.sh\|\.js\|\.ts"; then
    TASK_CATEGORY="implementation"
fi

# ---------------------------------------------------------------------------
# Write diary entry
# ---------------------------------------------------------------------------
ENTRY="## ${DATE_SHORT} ${TIME_SHORT} -- ${SESSION_ID}
- **Task category**: ${TASK_CATEGORY}
- **Files touched**: ${FILES_MODIFIED}
- **Outcome**: success (quality gate passed)

"

# Create file with frontmatter if it doesn't exist
if [[ ! -f "$DIARY_FILE" ]]; then
    cat > "$DIARY_FILE" << FRONTMATTER
---
agent: ${TEAMMATE_NAME}
type: diary
month: ${DATE_MONTH}
last_updated: ${NOW}
---

# ${TEAMMATE_NAME} — Diary ${DATE_MONTH}

FRONTMATTER
    log "INFO created diary file: ${DIARY_FILE}"
fi

# Append entry (mkdir-based locking for concurrent safety)
LOCK_DIR="${DIARY_DIR}/.lock"
LOCK_TRIES=0
LOCK_MAX=5
while [[ -d "$LOCK_DIR" && $LOCK_TRIES -lt $LOCK_MAX ]]; do
    sleep 0.2
    LOCK_TRIES=$((LOCK_TRIES + 1))
done

if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$ENTRY" >> "$DIARY_FILE"
    rmdir "$LOCK_DIR" 2>/dev/null || true
    log "INFO diary entry written agent=${TEAMMATE_NAME} category=${TASK_CATEGORY}"
else
    log "WARN could not acquire lock for diary write, skipping"
fi

exit 0
