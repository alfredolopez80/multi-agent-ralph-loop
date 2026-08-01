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
# 10 MB, not 100 KB. The old cap truncated any payload with a large `new_string`, `jq`
# then failed to parse it, `cwd` came back empty and the gate allowed the call — so a
# BIG edit skipped the gate while a small one was denied. Large edits are precisely the
# high-complexity ones this gate exists for. The cap remains as a DoS bound.
INPUT=$(head -c 10000000)

HOOK_NAME="universal-aristotle-gate"

allow() {
  printf '%s\n' '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
  exit 0
}

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# No payload at all means there is no tool call to judge — distinct from a payload that
# exists but cannot be read, which is handled below.
[[ -z "${INPUT//[[:space:]]/}" ]] && allow

if ! printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1; then
  deny "[$HOOK_NAME] the hook payload is not valid JSON, so the complexity gate cannot be evaluated. Blocking rather than assuming the call is safe."
fi

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Only the tools that IMPLEMENT are gated — see the note further down for why. Running
# this filter BEFORE the cwd check keeps an unreadable cwd from blocking reads.
case "$TOOL" in
  Edit|Write|MultiEdit|NotebookEdit) ;;
  *) allow ;;
esac

# A payload we cannot parse must FAIL CLOSED. Allowing here was a regression: the
# previous version emitted `continue: false` on this path, i.e. it did not let the call
# through. Since only mutating tools reach this point, denying costs a retry; allowing
# costs the whole guarantee.
if [[ -z "$CWD" ]]; then
  deny "[$HOOK_NAME] cannot determine the project directory from the hook payload (absent or unparseable 'cwd'), so the complexity gate cannot be evaluated. Blocking ${TOOL:-this tool} rather than assuming it is safe."
fi

STATE="${CWD}/.claude/state/current-complexity.json"
[[ -f "$STATE" ]] || allow

COMPLEXITY=$(jq -r '.complexity // empty' "$STATE" 2>/dev/null)
if [[ ! "$COMPLEXITY" =~ ^[0-9]+$ ]]; then
  # The state file EXISTS but its score is unreadable, so the gate cannot tell whether a
  # plan is required. Allowing here let an implementation edit through on a corrupt or
  # hand-edited state file; only mutating tools reach this point, so denying costs a fix
  # to the file, while allowing costs the guarantee.
  deny "[$HOOK_NAME] '$STATE' exists but its 'complexity' is not an integer (${COMPLEXITY:-<empty>}), so the plan requirement cannot be evaluated. Repair or delete the file."
fi

(( COMPLEXITY < 4 )) && allow

# The tool filter runs earlier, right after parsing, so an unreadable payload cannot
# block reads. Registered with matcher "*", this hook sees EVERY tool call, but its rule
# is "plan before IMPLEMENTING" — with `permissionDecision: "deny"` a broad match denied
# Read, Grep, Glob, Task and even ExitPlanMode, trapping the user inside plan mode.

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
