#!/usr/bin/env bash
umask 077
# VERSION: 2.70.0
# Hook: Plan-Sync Post-Step
# Trigger: PostToolUse (after Edit or Write completes in orchestrated context)
# Purpose: Detect drift and trigger Plan-Sync agent for downstream patching
# Security: v2.45.1 - Fixed race condition, path traversal, atomic updates
# SEC-047: Added guaranteed JSON output for PostToolUse hooks
# v2.70.0: Worktree-safe path resolution via worktree-utils.sh

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# SEC-047: Error trap for guaranteed JSON output (PostToolUse format)
trap 'echo "{\"continue\": true}"' ERR EXIT

# Worktree-safe path resolution
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  get_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"; }
  get_main_repo() { get_project_root; }
}

# Configuration — T87: get_project_root (THIS working tree), matching every
# other plan-state consumer. get_main_repo pointed this writer at the MAIN
# checkout from a linked worktree, where that file has ZERO readers.
#
# T99: the `|| pwd` here was dead code (get_project_root cannot fail — its
# fallback echoes "."), and the "." fallback made PLAN_STATE relative to the
# process CWD: the hook then silently operated on a plan-state that does not
# exist. Fail loud instead: log it and leave without a relative lookup.
# T99 r4: get_project_root (lib) is the single resolution — content-marker
# walk, broken-git tolerant, and ALWAYS absolute (it canonizes internally),
# so the "reject '.'" case below is now pure defense.
_PROJECT_ROOT="$(get_project_root 2>/dev/null || true)"
LOG_FILE="${HOME}/.ralph/logs/plan-sync.log"
SYNC_LOG="${HOME}/.ralph/logs/drift-history.jsonl"
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$SYNC_LOG")"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}
if [[ -z "$_PROJECT_ROOT" || "$_PROJECT_ROOT" != /* ]]; then
    log "ERROR: project root not resolvable to an absolute path (got '${_PROJECT_ROOT:-<empty>}'); refusing relative plan-state lookup"
    trap - ERR EXIT
    echo '{"continue": true}'
    exit 0
fi
PLAN_STATE="${_PROJECT_ROOT}/.claude/plan-state.json"

# SECURITY: Validate path to prevent traversal attacks (v2.45.1)
validate_file_path() {
    local path="$1"
    local resolved

    # Reject empty paths
    if [ -z "$path" ]; then
        return 1
    fi

    # Reject paths with traversal sequences.
    # T87 fix: the null-byte half of this check (`*$'\0'*`) collapsed to `**`
    # — bash strings cannot contain NUL, so the pattern token lost its middle
    # and matched EVERY non-empty path. Since v2.45.1 (770de221, 2026-01-17)
    # validate_file_path rejected all paths, silently turning this whole hook
    # into a no-op for its primary function. A NUL cannot reach a bash string
    # argument in the first place; the `..` traversal guard does the real work.
    #
    # T99: match `..` as a PATH COMPONENT, not a substring — "report.v1..v2.ts"
    # is a legitimate filename and was rejected by the substring form.
    if [[ "$path" =~ (^|/)\.\.(/|$) ]]; then
        log "SECURITY: Rejected suspicious path: $path"
        return 1
    fi

    # Resolve to absolute path and verify it's under project root.
    # T87: same root as PLAN_STATE — the modified file lives in THIS tree.
    # T99: reuse the root resolved once at the top (was re-derived per call),
    #   and compare with a BOUNDARY, not a raw prefix — "$project_root"* also
    #   admitted a sibling like "$project_root-2/evil.ts".
    resolved=$(realpath "$path" 2>/dev/null || echo "")

    if [[ "$resolved" != "$_PROJECT_ROOT" && "$resolved" != "$_PROJECT_ROOT"/* ]]; then
        log "SECURITY: Path traversal attempt blocked: $path"
        return 1
    fi

    echo "$resolved"
}

# Check if we're in orchestrated context
if [ ! -f "$PLAN_STATE" ]; then
    exit 0
fi

# Get the file that was just modified (from hook context).
# T99: Claude Code delivers the edited path in the PostToolUse STDIN payload
# as .tool_input.file_path. The previous source, ${CLAUDE_TOOL_ARG_file_path},
# is an environment variable NOBODY sets — every production invocation hit
# the "No modified file detected" branch, turning this hook into a no-op.
RAW_FILE="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

if [ -z "$RAW_FILE" ]; then
    log "No modified file detected, skipping plan-sync"
    exit 0
fi

# SECURITY: Validate the file path (v2.45.1)
MODIFIED_FILE=$(validate_file_path "$RAW_FILE") || {
    log "SECURITY: Invalid file path rejected: $RAW_FILE"
    exit 0
}

log "Plan-Sync check for modified file: $MODIFIED_FILE"

# Find which step this file belongs to
STEP_ID=$(jq -r --arg file "$MODIFIED_FILE" '
  .steps[] | select(.spec.file == $file or .actual.file == $file) | .id
' "$PLAN_STATE" 2>/dev/null | head -1)

if [ -z "$STEP_ID" ] || [ "$STEP_ID" = "null" ]; then
    log "File $MODIFIED_FILE not in plan, skipping"
    exit 0
fi

log "File belongs to step: $STEP_ID"

# Get the spec for this step
SPEC_FILE=$(jq -r --arg step "$STEP_ID" '.steps[] | select(.id == $step) | .spec.file' "$PLAN_STATE")
SPEC_EXPORTS=$(jq -r --arg step "$STEP_ID" '.steps[] | select(.id == $step) | .spec.exports // []' "$PLAN_STATE")

# Analyze actual implementation for drift
if [ -f "$MODIFIED_FILE" ]; then
    # Extract actual exports (for TypeScript/JavaScript)
    if [[ "$MODIFIED_FILE" == *.ts || "$MODIFIED_FILE" == *.js || "$MODIFIED_FILE" == *.tsx || "$MODIFIED_FILE" == *.jsx ]]; then
        ACTUAL_EXPORTS=$(grep -E "^export (const|function|class|interface|type|enum)" "$MODIFIED_FILE" 2>/dev/null | \
            sed -E 's/export (const|function|class|interface|type|enum) ([a-zA-Z0-9_]+).*/\2/' | \
            jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
    # For Python
    elif [[ "$MODIFIED_FILE" == *.py ]]; then
        ACTUAL_EXPORTS=$(grep -E "^(def |class |[A-Z_]+ =)" "$MODIFIED_FILE" 2>/dev/null | \
            sed -E 's/(def |class )([a-zA-Z0-9_]+).*/\2/; s/([A-Z_]+) =.*/\1/' | \
            jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
    else
        ACTUAL_EXPORTS="[]"
    fi
else
    ACTUAL_EXPORTS="[]"
fi

log "Spec exports: $SPEC_EXPORTS"
log "Actual exports: $ACTUAL_EXPORTS"

# Check for drift
DRIFT_DETECTED="false"
DRIFT_ITEMS="[]"

# Compare exports
if [ "$SPEC_EXPORTS" != "[]" ] && [ "$ACTUAL_EXPORTS" != "[]" ]; then
    # Find missing exports (in spec but not in actual)
    MISSING=$(jq -n --argjson spec "$SPEC_EXPORTS" --argjson actual "$ACTUAL_EXPORTS" '
      [$spec[] | select(. as $s | $actual | index($s) | not)] |
      map({type: "missing", spec: ., actual: null})
    ')

    # Find extra exports (in actual but not in spec)
    EXTRA=$(jq -n --argjson spec "$SPEC_EXPORTS" --argjson actual "$ACTUAL_EXPORTS" '
      [$actual[] | select(. as $a | $spec | index($a) | not)] |
      map({type: "extra", spec: null, actual: .})
    ')

    # Combine drift items
    DRIFT_ITEMS=$(jq -n --argjson missing "$MISSING" --argjson extra "$EXTRA" '
      $missing + $extra
    ')

    if [ "$(echo "$DRIFT_ITEMS" | jq 'length')" -gt 0 ]; then
        DRIFT_DETECTED="true"
        log "DRIFT DETECTED: $DRIFT_ITEMS"
    fi
fi

# Update plan-state with actual values and drift (v2.0: via lib/plan-state-writer.sh)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/plan-state-writer.sh"

if ! plan_state_update "$PLAN_STATE" '
  .steps |= map(
    if .id == $step then
      .actual.exports = $actual_exports |
      .actual.updated_at = $ts |
      .drift.detected = $drift_detected |
      .drift.items = $drift_items |
      (if $drift_detected then .drift.needs_sync = true else . end)
    else . end
  )
' \
    --arg step "$STEP_ID" \
    --arg ts "$TIMESTAMP" \
    --argjson actual_exports "$ACTUAL_EXPORTS" \
    --argjson drift_detected "$DRIFT_DETECTED" \
    --argjson drift_items "$DRIFT_ITEMS"; then
    log "ERROR: plan_state_update failed"
    exit 1
fi

# If drift detected, output warning and log to history
if [ "$DRIFT_DETECTED" = "true" ]; then
    # Get downstream steps that might be affected
    DOWNSTREAM=$(jq -r --arg step "$STEP_ID" '
      [.steps[] | select(.status == "pending") | .id] | join(", ")
    ' "$PLAN_STATE")

    cat << EOF

╔══════════════════════════════════════════════════════════════════╗
║                    ⚠️  DRIFT DETECTED                             ║
╠══════════════════════════════════════════════════════════════════╣
║  Step: $STEP_ID
║  File: $MODIFIED_FILE
║                                                                   ║
║  Drift Items:                                                     ║
$(echo "$DRIFT_ITEMS" | jq -r '.[] | "║  • \(.type): spec=\(.spec // "N/A") actual=\(.actual // "N/A")"')
║                                                                   ║
║  Downstream steps that may need patching:                         ║
║  $DOWNSTREAM
║                                                                   ║
║  ACTION: Plan-Sync will be triggered to patch downstream specs    ║
╚══════════════════════════════════════════════════════════════════╝

EOF

    # Log drift event
    echo "{\"timestamp\":\"$TIMESTAMP\",\"step\":\"$STEP_ID\",\"file\":\"$MODIFIED_FILE\",\"drift_items\":$DRIFT_ITEMS}" >> "$SYNC_LOG"

    log "Drift logged, Plan-Sync recommended for steps: $DOWNSTREAM"
fi

log "Plan-Sync post-step check completed"

# v2.87.0 FIX: Always output JSON for PostToolUse hooks
trap - ERR EXIT
echo '{"continue": true}'
