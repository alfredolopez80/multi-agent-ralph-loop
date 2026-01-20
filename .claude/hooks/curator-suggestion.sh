#!/bin/bash
# Curator Suggestion Hook (v2.55.0)
# Hook: UserPromptSubmit
# Purpose: Suggest using curator when procedural memory is empty
#
# Checks if user mentions learning patterns, best practices, or similar
# and if the curator corpus is empty, suggests running /curator.
#
# VERSION: 2.57.4
# SECURITY: SEC-006 compliant with ERR trap for guaranteed JSON output

set -euo pipefail
umask 077

# Guaranteed JSON output on any error (SEC-006)
# UserPromptSubmit hooks use {"continue": true, "systemMessage": "..."}
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

# Parse input
INPUT=$(cat)
USER_PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // ""' 2>/dev/null || echo "")
USER_PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

# Keywords that suggest the user wants to learn from best practices
KEYWORDS="best practice|pattern|learn from|reference|example repo|quality code|clean code|architecture pattern|design pattern"

# Check if prompt contains relevant keywords
if ! echo "$USER_PROMPT_LOWER" | grep -qE "$KEYWORDS"; then
    echo '{"continue": true}'
    exit 0
fi

# Check curator corpus status
CORPUS_DIR="${HOME}/.ralph/curator/corpus/approved"
CORPUS_COUNT=0
if [[ -d "$CORPUS_DIR" ]]; then
    CORPUS_COUNT=$(find "$CORPUS_DIR" -type f -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
fi

# Check procedural rules
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
RULES_COUNT=0
LEARNED_COUNT=0
if [[ -f "$RULES_FILE" ]]; then
    RULES_COUNT=$(jq -r '.rules | length // 0' "$RULES_FILE" 2>/dev/null || echo "0")
    LEARNED_COUNT=$(jq -r '[.rules[] | select(.source_repo != null)] | length // 0' "$RULES_FILE" 2>/dev/null || echo "0")
fi

# If corpus is empty and few learned rules, suggest curator
if [[ "$CORPUS_COUNT" -eq 0 ]] && [[ "$LEARNED_COUNT" -lt 3 ]]; then
    SUGGESTION="💡 **Tip**: Your procedural memory is nearly empty ($RULES_COUNT rules, $LEARNED_COUNT learned from repos). Consider running:
\`\`\`
/curator full --type backend --lang typescript
\`\`\`
This will discover, score, and learn from high-quality repositories to improve code generation quality."

    # Escape for JSON
    SUGGESTION_ESCAPED=$(echo "$SUGGESTION" | jq -Rs '.')

    echo "{\"continue\": true, \"systemMessage\": $SUGGESTION_ESCAPED}"
    exit 0
fi

# If corpus exists but few learned rules, suggest learning
if [[ "$CORPUS_COUNT" -gt 0 ]] && [[ "$LEARNED_COUNT" -lt 3 ]]; then
    SUGGESTION="💡 **Tip**: You have $CORPUS_COUNT approved repos but only $LEARNED_COUNT learned rules. Run:
\`\`\`
/curator learn --type backend --lang typescript
\`\`\`
to extract patterns from your approved repositories."

    SUGGESTION_ESCAPED=$(echo "$SUGGESTION" | jq -Rs '.')
    echo "{\"continue\": true, \"systemMessage\": $SUGGESTION_ESCAPED}"
    exit 0
fi

# All good, continue without suggestion
echo '{"continue": true}'
