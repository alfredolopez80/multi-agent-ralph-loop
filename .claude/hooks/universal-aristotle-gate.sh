#!/usr/bin/env bash
# universal-aristotle-gate.sh — PreToolUse gate: complexity >= 4 requires a plan first.
# VERSION: 2.0.0
#
# v2.0.0 fixes five defects that made this hook stop turns undiagnosably:
#   1. It emitted {"continue": false, "reason": ...}. For `continue:false` the harness
#      surfaces `stopReason`, not `reason`, so the explanation was silently discarded
#      and the user only saw "PreToolUse:Edit hook stopped continuation".
#   2. It never named itself, so a stop could not be traced to this script.
#   3. `continue:false` is the wrong mechanism for vetoing a tool: it halts the turn
#      *after* the tool ran. PreToolUse vetoes with permissionDecision "deny", which
#      blocks the call and hands the reason back so the model can react.
#   4. It read complexity from ~/.claude/state/ — global state shared by every project,
#      so a complexity set in one repo blocked edits in another (cross-contamination).
#      State is now per-project under $CWD/.claude/state/ (already gitignored).
#   5. It built JSON by string interpolation; a quote in the payload produced invalid
#      JSON. Output is now built with `jq -n`.
umask 077
INPUT=$(head -c 100000)

HOOK_NAME="universal-aristotle-gate"

allow() {
  printf '%s\n' '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
  exit 0
}

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Without a cwd the project state cannot be resolved. Say so on stderr rather than
# blocking every tool call, but never stay silent about it.
if [[ -z "$CWD" ]]; then
  echo "[$HOOK_NAME] no 'cwd' in hook payload; cannot resolve per-project state" >&2
  allow
fi

STATE="${CWD}/.claude/state/current-complexity.json"
[[ -f "$STATE" ]] || allow

COMPLEXITY=$(jq -r '.complexity // empty' "$STATE" 2>/dev/null)
if [[ ! "$COMPLEXITY" =~ ^[0-9]+$ ]]; then
  echo "[$HOOK_NAME] malformed 'complexity' in $STATE: ${COMPLEXITY:-<empty>}" >&2
  allow
fi

(( COMPLEXITY < 4 )) && allow

# Entering plan mode is exactly what this gate asks for — never block it.
[[ "$TOOL" == "EnterPlanMode" ]] && allow

# A plan exists: the gate is satisfied.
[[ -f "${CWD}/.claude/plan-state.json" ]] && allow

REASON="[$HOOK_NAME] Blocked ${TOOL:-tool}: complexity $COMPLEXITY requires a plan before implementation. Use EnterPlanMode first (Aristotle First Principles applies at complexity >= 4). Complexity source: $STATE"

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
