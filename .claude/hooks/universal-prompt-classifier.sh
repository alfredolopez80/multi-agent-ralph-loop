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

# Save complexity for other hooks (universal-aristotle-gate.sh reads it).
# PER-PROJECT, never ~/.claude/state: a shared file lets the complexity scored in one
# repo gate tool calls in another. $CWD/.claude/state/ is already gitignored.
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
if [[ -z "$CWD" ]]; then
  echo "[universal-prompt-classifier] no 'cwd' in hook payload; complexity $COMPLEXITY not persisted" >&2
else
  mkdir -p "${CWD}/.claude/state"
  jq -n --argjson c "$COMPLEXITY" --argjson t "$(date +%s)" \
    '{complexity: $c, timestamp: $t}' > "${CWD}/.claude/state/current-complexity.json"
fi

# Complexity message delegated to aristotle-analysis-display.sh (last in chain)
# This hook only scores + saves state — the aristotle hook generates the 5-phase message
echo '{"continue": true}'
