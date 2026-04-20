#!/usr/bin/env bash
# anti-rationalization-gate.sh — Stop hook: blocks excuses AND mid-plan confirmations
# VERSION: 2.0.0
# Event: Stop
# Format: {"decision": "approve"} or {"decision": "block", "reason": "..."}
#
# v2.0.0 (2026-04-20): MERGED plan-continuation-gate.sh into this hook.
#   - Unifies two Stop-chain gates into a single coordinated enforcer
#   - Shared state file (anti-rat-blocks.json) — no duplicated counters
#   - Reads plan-state.json (same source as statusline-ralph.sh) for execution awareness
#   - Confirmation-pattern detection is GATED on an active plan (no false positives
#     when the agent is idle between tasks)
#   - stop_hook_active infinite-loop guard added
#
# Two enforcement modes:
#   A) EXCUSE mode — always on. Scans transcript for rationalizations from
#      docs/reference/anti-rationalization.md (+ parallel-first fallback).
#   B) CONFIRMATION mode — only when an ACTIVE plan is detected. Scans the
#      tail for ES/EN patterns like "¿Procedo?" / "Should I continue?" that
#      violate .claude/rules/plan-immutability.md.
#
# Active-plan detection (PROJECT-ISOLATED, freshness filter: last_updated < 30 min):
#   - Reads ONLY $CWD/.claude/plan-state.json (current project scope)
#   - NO global/cross-project fallback — plans are per-repo by design to prevent
#     cross-project contamination (a plan in project A must NEVER block Stop
#     hooks in project B)
#
# Safeguards:
#   - Respects stop_hook_active (no self-triggering loops)
#   - MAX_BLOCKS=3 per session (auto-reset + approve after threshold)
#   - Fail-open on jq missing, patterns file missing, or malformed input

umask 077
INPUT=$(head -c 100000)

# --- Guard: jq required, fail-open otherwise ---
if ! command -v jq >/dev/null 2>&1; then
  echo '{"decision": "approve"}'
  exit 0
fi

# --- Infinite-loop guard: honor stop_hook_active ---
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# --- Resolve CWD and project-scoped state (isolated per-repo) ---
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null)
[[ -z "$CWD" || "$CWD" == "null" ]] && CWD="$(pwd)"

# State and patterns are PER-PROJECT. No cross-project contamination.
STATE_DIR="$CWD/.claude/state"
STATE_FILE="$STATE_DIR/anti-rat-blocks.json"
PATTERNS_FILE="$CWD/docs/reference/anti-rationalization.md"
mkdir -p "$STATE_DIR" 2>/dev/null || true

# --- Max blocks guard ---
MAX_BLOCKS=3
BLOCK_COUNT=0
if [[ -f "$STATE_FILE" ]]; then
  BLOCK_COUNT=$(jq -r '.blocks // 0' "$STATE_FILE" 2>/dev/null || echo 0)
fi
if [[ "$BLOCK_COUNT" -ge "$MAX_BLOCKS" ]]; then
  echo '{"blocks": 0}' > "$STATE_FILE" 2>/dev/null || true
  echo '{"decision": "approve"}'
  exit 0
fi

# --- Active-plan detection (freshness filter: last_updated < 30 min) ---

HAS_ACTIVE_PLAN=false
ACTIVE_PLAN_DETAIL=""
FRESH_WINDOW=1800  # 30 minutes

# 1) Project-level plan-state.json
PROJECT_PLAN_STATE="$CWD/.claude/plan-state.json"
if [[ -f "$PROJECT_PLAN_STATE" ]]; then
  LAST_UPDATED=$(jq -r '.last_updated // ""' "$PROJECT_PLAN_STATE" 2>/dev/null)
  if [[ -n "$LAST_UPDATED" && "$LAST_UPDATED" != "null" ]]; then
    TS="${LAST_UPDATED%%+*}"; TS="${TS%Z}"
    # Force UTC interpretation — plan timestamps are emitted with %Y-%m-%dT%H:%M:%SZ
    UPDATED_EPOCH=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$TS" "+%s" 2>/dev/null \
      || date -d "$LAST_UPDATED" "+%s" 2>/dev/null \
      || echo 0)
    NOW_EPOCH=$(date "+%s")
    AGE_SEC=$((NOW_EPOCH - UPDATED_EPOCH))
    if [[ "$UPDATED_EPOCH" -gt 0 && "$AGE_SEC" -ge 0 && "$AGE_SEC" -lt "$FRESH_WINDOW" ]]; then
      IN_PROGRESS=$(jq -r '[.steps[]? | select(.status == "in_progress")] | length' "$PROJECT_PLAN_STATE" 2>/dev/null || echo 0)
      if [[ "${IN_PROGRESS:-0}" -gt 0 ]]; then
        HAS_ACTIVE_PLAN=true
        NEXT=$(jq -r '[.steps[]? | select(.status == "in_progress")][0].name // "unnamed"' "$PROJECT_PLAN_STATE" 2>/dev/null | head -c 120)
        ACTIVE_PLAN_DETAIL="plan-state.json step: $NEXT"
      fi
    fi
  fi
fi

# NOTE: No global/cross-project fallback. Per-repo isolation is a SECURITY
# requirement — a plan in project A must never gate Stop events in project B.

# --- Mode A: Excuse detection (always on) ---
MATCHED_EXCUSE=""
MATCHED_REBUTTAL=""

if [[ -f "$PATTERNS_FILE" ]]; then
  EXCUSES=$(grep -E '^\|.*\|.*\|.*\|' "$PATTERNS_FILE" \
    | grep -v 'Excuse.*Rebuttal' \
    | grep -v -- '---' \
    | awk -F'|' '{print $3}' \
    | sed 's/^ *//;s/ *$//' \
    | grep -v '^$' \
    | sort -u)

  while IFS= read -r excuse; do
    [[ -z "$excuse" ]] && continue
    if echo "$INPUT" | grep -qiF -- "$excuse"; then
      MATCHED_EXCUSE="$excuse"
      ESC_EXCUSE=$(printf '%s' "$excuse" | sed 's/[][\.*^$/]/\\&/g')
      MATCHED_REBUTTAL=$(grep -E "^\|.*\|.*${ESC_EXCUSE}.*\|" "$PATTERNS_FILE" \
        | head -1 \
        | awk -F'|' '{print $4}' \
        | sed 's/^ *//;s/ *$//')
      break
    fi
  done <<< "$EXCUSES"
fi

# Hardcoded parallel-first fallback
if [[ -z "$MATCHED_EXCUSE" ]]; then
  PARALLEL_EXCUSES="Sequential is simpler
hidden dependencies
parallelize in the next
coordination overhead
faster to do it myself
too small for parallelism
already started sequentially
Only one file needs changing"
  while IFS= read -r excuse; do
    [[ -z "$excuse" ]] && continue
    if echo "$INPUT" | grep -qiF -- "$excuse"; then
      MATCHED_EXCUSE="$excuse"
      MATCHED_REBUTTAL="See .claude/rules/parallel-first.md for the rebuttal."
      break
    fi
  done <<< "$PARALLEL_EXCUSES"
fi

# --- Decision: Excuse match wins immediately ---
if [[ -n "$MATCHED_EXCUSE" ]]; then
  NEW_COUNT=$((BLOCK_COUNT + 1))
  echo "{\"blocks\": $NEW_COUNT}" > "$STATE_FILE"
  REASON="Anti-rationalization gate: Detected excuse pattern '$MATCHED_EXCUSE'. $MATCHED_REBUTTAL Provide a factual justification for stopping, not a rationalization. Block $NEW_COUNT/$MAX_BLOCKS."
  echo "{\"decision\": \"block\", \"reason\": $(echo "$REASON" | jq -Rs .)}"
  exit 0
fi

# --- Mode B: Confirmation-pattern detection (only when plan is active) ---
if [[ "$HAS_ACTIVE_PLAN" == true ]]; then
  TAIL=$(echo "$INPUT" | tail -c 2000)

  CONFIRMATION_PATTERNS=(
    # ES
    '¿Quieres que continúe'
    '¿Quieres que siga'
    '¿Procedo'
    '¿Sigo'
    '¿Continúo'
    '¿Te parece'
    '¿Avanzo'
    'Confirma si'
    'Dime si quieres'
    'Quieres que siga'
    'Espero tu confirmación'
    # EN
    'Should I proceed'
    'Should I continue'
    'Do you want me to proceed'
    'Do you want me to continue'
    'Let me know if you'
    'Shall I continue'
    'Shall I proceed'
    'Would you like me to continue'
    'Ready to proceed'
    'Waiting for your confirmation'
    'Please confirm'
  )

  MATCHED_CONFIRMATION=""
  for pat in "${CONFIRMATION_PATTERNS[@]}"; do
    if echo "$TAIL" | grep -qiF -- "$pat"; then
      MATCHED_CONFIRMATION="$pat"
      break
    fi
  done

  if [[ -n "$MATCHED_CONFIRMATION" ]]; then
    NEW_COUNT=$((BLOCK_COUNT + 1))
    echo "{\"blocks\": $NEW_COUNT}" > "$STATE_FILE"
    REASON="Plan-immutability gate: Active plan detected ($ACTIVE_PLAN_DETAIL). Transcript ends with confirmation pattern '$MATCHED_CONFIRMATION'. Per .claude/rules/plan-immutability.md, plans are IMMUTABLE during execution — continue the next step without asking. Only pause for destructive actions (rm -rf, git reset --hard, force-push) or when the user explicitly requested a checkpoint. Block $NEW_COUNT/$MAX_BLOCKS."
    echo "{\"decision\": \"block\", \"reason\": $(echo "$REASON" | jq -Rs .)}"
    exit 0
  fi
fi

# --- No match: approve ---
echo '{"decision": "approve"}'
exit 0
