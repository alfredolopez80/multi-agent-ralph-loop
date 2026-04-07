#!/usr/bin/env bash
umask 077
INPUT=$(head -c 100000)

# Parse prompt from stdin
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')

# Heuristic complexity scoring
COMPLEXITY=1
LENGTH=${#PROMPT}

# Length-based (max 4 points)
if [[ $LENGTH -gt 500 ]]; then ((COMPLEXITY+=2)); elif [[ $LENGTH -gt 200 ]]; then ((COMPLEXITY+=1)); fi

# Multi-task patterns (max 2 points)
if echo "$PROMPT" | grep -qiE '(and also|additionally|as well as|multiple|several|parallel)'; then ((COMPLEXITY+=1)); fi
if echo "$PROMPT" | grep -qiE '(refactor|redesign|restructure|migrate|overhaul)'; then ((COMPLEXITY+=1)); fi

# Architecture keywords (max 3 points)
if echo "$PROMPT" | grep -qiE '(architect|design|system|infrastructure)'; then ((COMPLEXITY+=1)); fi
if echo "$PROMPT" | grep -qiE '(plan|strategy|approach|methodology)'; then ((COMPLEXITY+=1)); fi
if echo "$PROMPT" | grep -qiE '(implement|build|create|develop) .*(system|framework|pipeline)'; then ((COMPLEXITY+=1)); fi

# Cap at 10
[[ $COMPLEXITY -gt 10 ]] && COMPLEXITY=10

# Save complexity for other hooks
mkdir -p ~/.claude/state
echo "{\"complexity\": $COMPLEXITY, \"timestamp\": $(date +%s)}" > ~/.claude/state/current-complexity.json

# If complexity >= 4, inject reminder
if [[ $COMPLEXITY -ge 4 ]]; then
  MSG="Complexity $COMPLEXITY detected. Apply Aristotle First Principles + EnterPlanMode for complexity >= 4."
  echo "{\"continue\": true, \"hookSpecificOutput\": {\"hookEventName\": \"UserPromptSubmit\", \"additionalContext\": \"$MSG\"}}"
else
  echo '{"continue": true}'
fi
