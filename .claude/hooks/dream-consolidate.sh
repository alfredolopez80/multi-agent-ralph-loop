#!/usr/bin/env bash
# dream-consolidate.sh — Offline consolidation (L3 dream) in SHADOW mode (Phase B3/B4)
# Hook: SessionEnd
# VERSION: 3.1.0
#
# Runs scripts/memory/dream.py to consolidate Ralph learning sources into L3
# candidates. SHADOW-MODE-FIRST (plan risk mitigation): this hook ONLY runs
# `--dry-run`, which writes NOTHING to ~/.ralph/layers/. It writes a timestamped
# report under ~/.ralph/logs/ for review. The L3 layer is never modified
# automatically.
#
# HOW TO ENABLE --apply (do NOT do this until shadow output is reviewed):
#   1. Inspect a few reports in ~/.ralph/logs/dream/ and confirm candidates are
#      sane (no RED material, correct target layers, reasonable counts).
#   2. Set the env flag in ~/.claude/settings.json env block (or export before
#      a session):  RALPH_DREAM_APPLY=1
#   3. Re-run a session; this hook will then call `dream.py --apply`, writing
#      ~/.ralph/layers/L3_dream.md. Revert by unsetting RALPH_DREAM_APPLY.
# The default (flag unset / != 1) is and stays dry-run.
#
# Fire-and-forget: respond with SessionEnd JSON first, run dream in a detached
# worker so session teardown is never blocked.
#
# Output (SessionEnd): {"continue": true}  (per tests/HOOK_FORMAT_REFERENCE.md).
#
# SECURITY: umask 077, stdin length limit, worktree-safe path resolution.

# --- Parent mode: respond immediately, fork detached worker ---
if [[ "${DREAM_CONSOLIDATE_WORKER:-0}" != "1" ]]; then
  umask 077
  INPUT=$(head -c 100000)
  DREAM_CONSOLIDATE_WORKER=1 nohup bash "$0" <<<"$INPUT" >/dev/null 2>&1 &
  disown 2>/dev/null || true
  echo '{"continue": true}'
  exit 0
fi

# --- Worker mode (detached) ---
set -euo pipefail
umask 077

trap 'exit 0' ERR EXIT

INPUT=$(head -c 100000)  # drained for parity; not currently parsed.
: "${INPUT:=}"

LOG_DIR="${HOME}/.ralph/logs"
DREAM_LOG_DIR="${LOG_DIR}/dream"
mkdir -p "$DREAM_LOG_DIR"
LOG_FILE="${LOG_DIR}/dream-consolidate.log"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$LOG_FILE" 2>/dev/null || true; }

_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || true

SCRIPTS_DIR="$(cd "${_HOOK_DIR}/../.." 2>/dev/null && pwd)/scripts/memory"
DREAM="${SCRIPTS_DIR}/dream.py"

if [[ ! -f "$DREAM" ]]; then
  log "dream.py not found at $DREAM — skipping"
  trap - EXIT
  exit 0
fi

TS="$(date -u +"%Y%m%dT%H%M%SZ")"
REPORT="${DREAM_LOG_DIR}/dream-${TS}.json"

# SHADOW MODE (default): --dry-run writes no layer. --apply ONLY when the
# operator opts in explicitly via RALPH_DREAM_APPLY=1.
if [[ "${RALPH_DREAM_APPLY:-0}" == "1" ]]; then
  log "RALPH_DREAM_APPLY=1 — running dream.py --apply (L3 will be written)"
  if python3 "$DREAM" --apply --json > "$REPORT" 2>> "$LOG_FILE"; then
    log "dream apply OK — report: $REPORT"
  else
    log "dream apply failed (non-critical) — see $LOG_FILE"
  fi
else
  log "shadow mode — running dream.py --dry-run (no L3 written)"
  if python3 "$DREAM" --dry-run --json > "$REPORT" 2>> "$LOG_FILE"; then
    log "dream dry-run OK — report: $REPORT"
  else
    log "dream dry-run failed (non-critical) — see $LOG_FILE"
  fi
fi

trap - EXIT
exit 0
