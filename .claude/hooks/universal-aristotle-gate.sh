#!/usr/bin/env bash
umask 077
INPUT=$(head -c 100000)

# Check if complexity was set
if [[ ! -f ~/.claude/state/current-complexity.json ]]; then
  echo '{"continue": true}'
  exit 0
fi

COMPLEXITY=$(jq -r '.complexity // 1' ~/.claude/state/current-complexity.json 2>/dev/null)

if [[ "$COMPLEXITY" -lt 4 ]]; then
  echo '{"continue": true}'
  exit 0
fi

# Check if plan mode was entered (look for plan file)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Allow EnterPlanMode tool
if [[ "$TOOL" == "EnterPlanMode" ]]; then
  echo '{"continue": true}'
  exit 0
fi

# Check if plan exists (plan mode was used)
if [[ -f "${CWD}/.claude/plan-state.json" ]]; then
  echo '{"continue": true}'
  exit 0
fi

# Block: complexity >= 4 without plan
REASON="Complexity $COMPLEXITY detected but no plan created. Use EnterPlanMode first per global rules (Aristotle First Principles for complexity >= 4)."
echo "{\"continue\": false, \"reason\": \"$REASON\"}"
