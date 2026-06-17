#!/usr/bin/env bash
# memory-projection.sh — Native MEMORY.md GREEN-node projection (Phase B4)
# Hook: SessionEnd
# VERSION: 3.1.0
#
# Reconciles Claude's native project memory with the Ralph memory tree without
# drift: it regenerates a single delimited block of the top GREEN nodes inside
# ~/.claude/projects/<id>/memory/MEMORY.md. All content OUTSIDE the block is
# preserved — the projection NEVER clobbers the user's native memory.
#
# Fire-and-forget (same pattern as vault-fact-extractor.sh): respond with the
# SessionEnd JSON immediately, then run the projection in a detached worker so
# session teardown is never blocked.
#
# Output (SessionEnd): {"continue": true}  (per tests/HOOK_FORMAT_REFERENCE.md;
# SessionEnd cannot block and does NOT support hookSpecificOutput).
#
# SECURITY: umask 077, stdin length limit, worktree-safe path resolution.

# --- Parent mode: respond immediately, fork detached worker ---
if [[ "${MEMORY_PROJECTION_WORKER:-0}" != "1" ]]; then
  umask 077
  INPUT=$(head -c 100000)
  MEMORY_PROJECTION_WORKER=1 nohup bash "$0" <<<"$INPUT" >/dev/null 2>&1 &
  disown 2>/dev/null || true
  echo '{"continue": true}'
  exit 0
fi

# --- Worker mode (detached) ---
set -euo pipefail
umask 077

# Detached worker: log-and-exit on error (no JSON needed; parent already replied).
trap 'exit 0' ERR EXIT

INPUT=$(head -c 100000)  # drained for parity; not currently parsed.
: "${INPUT:=}"

LOG_DIR="${HOME}/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/memory-projection.log"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$LOG_FILE" 2>/dev/null || true; }

# Worktree-safe path resolution.
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  get_safe_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"; }
}

SCRIPTS_DIR="$(cd "${_HOOK_DIR}/../.." 2>/dev/null && pwd)/scripts/memory"
PROJECT_MEMORY="${SCRIPTS_DIR}/project_memory.py"

if [[ ! -f "$PROJECT_MEMORY" ]]; then
  log "project_memory.py not found at $PROJECT_MEMORY — skipping"
  trap - EXIT
  exit 0
fi

# project_memory.py auto-detects the main repo (unwrapping worktrees) so the
# projection always targets the canonical native project id.
if python3 "$PROJECT_MEMORY" --apply >> "$LOG_FILE" 2>&1; then
  log "projection applied"
else
  log "projection failed (non-critical)"
fi

trap - EXIT
exit 0
