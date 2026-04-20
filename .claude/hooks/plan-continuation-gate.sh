#!/usr/bin/env bash
# plan-continuation-gate.sh — Enforces plan-immutability during execution
# VERSION: 1.0.0
# Event: Stop
#
# Problem: Opus 4.7's cautious default pauses mid-plan to ask confirmation,
#          violating .claude/rules/plan-immutability.md ("plans are IMMUTABLE
#          during implementation").
#
# Solution: When an active plan is detected AND the transcript ends in a
# confirmation-seeking pattern, BLOCK the stop and instruct Claude to continue
# the next step without asking.
#
# Active plan detection (in priority order):
#   1. $CWD/.claude/plan-state.json with steps[].status == pending | in_progress
#   2. ~/.ralph/active-plan/*.json modified within the last 3h with non-completed steps
#
# Confirmation-pattern detection:
#   Scans the last 2KB of stdin for ES/EN patterns like:
#     ES: "¿Quieres que continúe", "¿Procedo", "¿Sigo", "¿Continúo"
#     EN: "Should I proceed", "Should I continue", "Shall I", "Let me know if"
#
# Safeguards (mirrors anti-rationalization-gate.sh):
#   - Respects stop_hook_active (infinite-loop guard)
#   - MAX_BLOCKS=3 per session (auto-reset + approve after threshold)
#   - No-op if no active plan detected (approve silently)
#
# Output (Stop hook format):
#   {"decision": "approve"}   — allow Claude to stop
#   {"decision": "block", "reason": "..."}   — force continuation

set -euo pipefail
umask 077

STATE_DIR="$HOME/.claude/state"
STATE_FILE="$STATE_DIR/plan-cont-blocks.json"
mkdir -p "$STATE_DIR"

INPUT=$(head -c 100000)

# Guard: invalid/missing jq → approve (fail-open)
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

# --- Max-blocks guard ---
MAX_BLOCKS=3
BLOCK_COUNT=0
if [[ -f "$STATE_FILE" ]]; then
  BLOCK_COUNT=$(jq -r '.blocks // 0' "$STATE_FILE" 2>/dev/null || echo 0)
fi
if [[ "$BLOCK_COUNT" -ge "$MAX_BLOCKS" ]]; then
  echo '{"blocks": 0}' > "$STATE_FILE"
  echo '{"decision": "approve"}'
  exit 0
fi

# --- Active plan detection ---
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null)
[[ -z "$CWD" || "$CWD" == "null" ]] && CWD="$(pwd)"

HAS_ACTIVE_PLAN=false
ACTIVE_PLAN_DETAIL=""

# 1) Project-level plan-state.json
PROJECT_PLAN_STATE="$CWD/.claude/plan-state.json"
if [[ -f "$PROJECT_PLAN_STATE" ]]; then
  PENDING=$(jq -r '[.steps[]? | select(.status == "pending" or .status == "in_progress")] | length' "$PROJECT_PLAN_STATE" 2>/dev/null || echo 0)
  if [[ "$PENDING" -gt 0 ]]; then
    HAS_ACTIVE_PLAN=true
    NEXT=$(jq -r '[.steps[]? | select(.status == "pending" or .status == "in_progress")][0].name // "unnamed"' "$PROJECT_PLAN_STATE" 2>/dev/null | head -c 120)
    ACTIVE_PLAN_DETAIL="next step: $NEXT"
  fi
fi

# 2) Global active-plan fallback (only if project-level didn't match)
#    Strict: require at least one step with status="in_progress" AND
#    the plan file modified within last 30 minutes (actively executing NOW).
if [[ "$HAS_ACTIVE_PLAN" == false ]]; then
  if [[ -d "$HOME/.ralph/active-plan" ]]; then
    RECENT_PLAN=$(find "$HOME/.ralph/active-plan" -maxdepth 1 -name '*.json' -mmin -30 2>/dev/null | head -1)
    if [[ -n "$RECENT_PLAN" && -f "$RECENT_PLAN" ]]; then
      IN_PROGRESS=$(jq -r '[.steps | to_entries[]? | select(.value.status == "in_progress")] | length' "$RECENT_PLAN" 2>/dev/null || echo 0)
      if [[ "${IN_PROGRESS:-0}" -gt 0 ]]; then
        HAS_ACTIVE_PLAN=true
        ACTIVE_PLAN_DETAIL="global plan: $(basename "$RECENT_PLAN")"
      fi
    fi
  fi
fi

# No active plan → no-op approve
if [[ "$HAS_ACTIVE_PLAN" == false ]]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# --- Confirmation-pattern detection (last 2KB of transcript) ---
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

MATCHED=""
for pat in "${CONFIRMATION_PATTERNS[@]}"; do
  if echo "$TAIL" | grep -qiF -- "$pat"; then
    MATCHED="$pat"
    break
  fi
done

# No confirmation pattern → approve
if [[ -z "$MATCHED" ]]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# --- Block with plan-immutability reason ---
NEW_COUNT=$((BLOCK_COUNT + 1))
echo "{\"blocks\": $NEW_COUNT}" > "$STATE_FILE"

REASON="Plan-continuation gate: Active plan detected ($ACTIVE_PLAN_DETAIL). Transcript ends with confirmation pattern '$MATCHED'. Per .claude/rules/plan-immutability.md, plans are IMMUTABLE during execution — continue the next step without asking. Only pause for destructive actions (rm -rf, git reset --hard, force-push) or when the user explicitly requested a checkpoint. Block $NEW_COUNT/$MAX_BLOCKS."

echo "{\"decision\": \"block\", \"reason\": $(echo "$REASON" | jq -Rs .)}"
