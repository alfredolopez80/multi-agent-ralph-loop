#!/usr/bin/env bash
# vault-fact-extractor.sh — Unified vault fact extraction (v3.1)
# Hook: PostToolUse (Edit|Write|Bash)
# VERSION: 3.1.0
# v3.1.0: fire-and-forget — respond JSON first, fork extractors in background
#
# Consolidates: decision-extractor.sh + semantic-realtime-extractor.sh
# Strategy: Thin wrapper that feeds the same stdin input to both original
# extractors. Original extraction logic is 100% preserved — no code was
# merged, modified, or rewritten. Both extractors remain as internal modules.
#
# Both write to: ~/Documents/Obsidian/MiVault/projects/{project}/facts/
#
# Fire-and-forget: vault fact extraction is pure background work. Returning the
# JSON response before fork+pipe drops wall-clock latency from ~33ms to <10ms.
#
# SECURITY: SEC-111 (stdin length limit), SEC-006 (error trap)

# Parent mode: read stdin, spawn worker, respond immediately
if [[ "${VAULT_FACT_EXTRACTOR_WORKER:-0}" != "1" ]]; then
  umask 077
  INPUT=$(head -c 100000)
  VAULT_FACT_EXTRACTOR_WORKER=1 nohup bash "$0" <<<"$INPUT" >/dev/null 2>&1 &
  disown 2>/dev/null || true
  echo '{"continue": true}'
  exit 0
fi

# --- Worker mode ---
set -euo pipefail
umask 077

# Worker is detached; log-and-exit on error (no JSON needed).
trap 'exit 0' ERR EXIT

INPUT=$(head -c 100000)

# Extractor scripts (remain in hooks/ as internal modules)
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
DECISION_EXTRACTOR="$HOOKS_DIR/decision-extractor.sh"
SEMANTIC_EXTRACTOR="$HOOKS_DIR/semantic-realtime-extractor.sh"

# Run both extractors in parallel, piping the same input to each.
# Each extractor handles its own background execution and logging internally.
if [[ -x "$DECISION_EXTRACTOR" ]]; then
    echo "$INPUT" | "$DECISION_EXTRACTOR" >/dev/null 2>&1 &
fi

if [[ -x "$SEMANTIC_EXTRACTOR" ]]; then
    echo "$INPUT" | "$SEMANTIC_EXTRACTOR" >/dev/null 2>&1 &
fi

# Worker-mode exit: clear trap and return quietly (parent already responded).
trap - EXIT
exit 0
