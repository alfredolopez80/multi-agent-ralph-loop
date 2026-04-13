#!/usr/bin/env bash
umask 077
INPUT=$(head -c 100000)

# anti-rationalization-gate.sh — Stop hook that blocks when Claude stops for excuses, not facts
# v1.0.0
# Event: Stop
# Format: {"decision": "approve"} or {"decision": "block", "reason": "..."}
#
# Reads patterns from docs/reference/anti-rationalization.md (FUERA de contexto)
# Only injects ~30 tokens when a pattern matches. Zero cost otherwise.
# Max blocks: 3 per session (prevents infinite loops)

STATE_DIR="$HOME/.claude/state"
STATE_FILE="$STATE_DIR/anti-rat-blocks.json"
PATTERNS_FILE="$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/Documents/GitHub/multi-agent-ralph-loop")/docs/reference/anti-rationalization.md"
mkdir -p "$STATE_DIR"

# --- Max blocks guard ---
MAX_BLOCKS=3
BLOCK_COUNT=0
if [[ -f "$STATE_FILE" ]]; then
  BLOCK_COUNT=$(jq -r '.blocks // 0' "$STATE_FILE" 2>/dev/null || echo 0)
fi
if [[ "$BLOCK_COUNT" -ge "$MAX_BLOCKS" ]]; then
  # Reset counter and approve — agent has been warned enough
  echo '{"blocks": 0}' > "$STATE_FILE"
  echo '{"decision": "approve"}'
  exit 0
fi

# --- Check if patterns file exists ---
if [[ ! -f "$PATTERNS_FILE" ]]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# --- Extract excuse patterns from the anti-rationalization doc ---
# Read the left-column excuses (field 3 in markdown tables)
EXCUSES=$(grep -E '^\|.*\|.*\|.*\|' "$PATTERNS_FILE" \
  | grep -v 'Excuse.*Rebuttal' \
  | grep -v -- '---' \
  | awk -F'|' '{print $3}' \
  | sed 's/^ *//;s/ *$//' \
  | grep -v '^$' \
  | sort -u)

# --- Also check parallel-first anti-rationalization patterns ---
PARALLEL_EXCUSES="Sequential is simpler
hidden dependencies
parallelize in the next
coordination overhead
faster to do it myself
too small for parallelism
already started sequentially
Only one file needs changing"

# --- Check stdin (conversation transcript) against patterns ---
MATCHED_EXCUSE=""
MATCHED_REBUTTAL=""

while IFS= read -r excuse; do
  [[ -z "$excuse" ]] && continue
  if echo "$INPUT" | grep -qi "$excuse"; then
    MATCHED_EXCUSE="$excuse"
    # Find the corresponding rebuttal from the file
    MATCHED_REBUTTAL=$(grep -E "^\|.*\|.*$excuse.*\|" "$PATTERNS_FILE" \
      | head -1 \
      | awk -F'|' '{print $4}' \
      | sed 's/^ *//;s/ *$//')
    break
  fi
done <<< "$EXCUSES"

# If no match from doc, check parallel patterns
if [[ -z "$MATCHED_EXCUSE" ]]; then
  while IFS= read -r excuse; do
    [[ -z "$excuse" ]] && continue
    if echo "$INPUT" | grep -qi "$excuse"; then
      MATCHED_EXCUSE="$excuse"
      MATCHED_REBUTTAL="See .claude/rules/parallel-first.md for the rebuttal."
      break
    fi
  done <<< "$PARALLEL_EXCUSES"
fi

# --- Decision ---
if [[ -n "$MATCHED_EXCUSE" ]]; then
  # Increment block counter
  NEW_COUNT=$((BLOCK_COUNT + 1))
  echo "{\"blocks\": $NEW_COUNT}" > "$STATE_FILE"

  REASON="Anti-rationalization gate: Detected excuse pattern '$MATCHED_EXCUSE'. $MATCHED_REBUTTAL Provide a factual justification for stopping, not a rationalization."
  echo "{\"decision\": \"block\", \"reason\": $(echo "$REASON" | jq -Rs .)}"
else
  # No rationalization detected — approve
  echo '{"decision": "approve"}'
fi
