#!/bin/bash
# promptify-auto-detect.sh - Auto-detect vague prompts and suggest /promptify
# VERSION: 1.0.0
# Hook: UserPromptSubmit
# Purpose: Analyze prompt clarity and suggest optimization when needed
#
# Integration with Multi-Agent Ralph Loop v2.82.0+
# Coordinates with command-router.sh via confidence thresholds

set -euo pipefail

readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly CONFIG_FILE="$HOME/.ralph/config/promptify.json"
readonly CONSENT_FILE="$HOME/.ralph/config/promptify-consent.json"
readonly LOG_DIR="$HOME/.ralph/logs"
readonly LOG_FILE="$LOG_DIR/promptify-auto-detect.log"

# Create directories if needed
mkdir -p "$LOG_DIR" "$(dirname "$CONFIG_FILE")"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$VERSION] $message" >> "$LOG_FILE"
}

# Trap for guaranteed JSON output
trap '{ echo "{\"continue\": true}"; exit 0; }' ERR INT TERM

# Read and validate input
INPUT=$(cat)
INPUT_SIZE=$(echo "$INPUT" | wc -c)

# Security: Limit input size (SEC-111)
readonly MAX_INPUT_SIZE=100000
if [[ $INPUT_SIZE -gt $MAX_INPUT_SIZE ]]; then
    log_message "WARN" "Input exceeds ${MAX_INPUT_SIZE} bytes, truncating"
    INPUT=$(echo "$INPUT" | head -c "$MAX_INPUT_SIZE}")
fi

# Parse user prompt
USER_PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // empty' 2>/dev/null || echo "")

if [[ -z "$USER_PROMPT" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Security: Redact sensitive information (SEC-110)
REDACTED_PROMPT=$(echo "$USER_PROMPT" | sed -E \
    's/(password|secret|token|api_key|credential)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1: [REDACTED]/gi')

log_message "INFO" "Processing prompt: ${REDACTED_PROMPT:0:100}..."

# Load config with defaults
if [[ -f "$CONFIG_FILE" ]]; then
    ENABLED=$(jq -r '.enabled // true' "$CONFIG_FILE")
    THRESHOLD=$(jq -r '.vagueness_threshold // 50' "$CONFIG_FILE")
    LOG_LEVEL=$(jq -r '.log_level // "INFO"' "$CONFIG_FILE")
else
    ENABLED=true
    THRESHOLD=50
    LOG_LEVEL="INFO"
fi

# Exit if disabled
if [[ "$ENABLED" != "true" ]]; then
    log_message "DEBUG" "Promptify disabled in config"
    echo '{"continue": true}'
    exit 0
fi

# Vagueness detection algorithm
calculate_clarity_score() {
    local prompt="$1"
    local score=100
    local prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

    # 1. Word count penalty (too short = vague)
    local word_count=$(echo "$prompt" | wc -w | tr -d ' ')
    if [[ $word_count -lt 5 ]]; then
        score=$((score - 40))
        [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "Word count penalty: -40% (count: $word_count)"
    elif [[ $word_count -lt 10 ]]; then
        score=$((score - 20))
        [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "Word count penalty: -20% (count: $word_count)"
    fi

    # 2. Vague word penalty
    local vague_words=("thing" "stuff" "something" "anything" "nothing" "fix it" "make it better" "help me" "whatsit" "thingy" "whatever")
    for word in "${vague_words[@]}"; do
        if echo "$prompt_lower" | grep -qE "$word"; then
            score=$((score - 15))
            [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "Vague word penalty: -15% (word: $word)"
        fi
    done

    # 3. Pronoun penalty (ambiguous references)
    if echo "$prompt_lower" | grep -qE "\b(this|that|it|they|them)\s+\b"; then
        score=$((score - 10))
        [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "Pronoun penalty: -10% (ambiguous reference)"
    fi

    # 4. Missing structure penalty
    local has_role=false
    local has_task=false
    local has_constraints=false

    # Check for role indicators
    if echo "$prompt_lower" | grep -qE "(you are|act as|role|persona|you.re a|you are an?)"; then
        has_role=true
        [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "Role detected"
    fi

    # Check for task indicators
    if echo "$prompt_lower" | grep -qE "(implement|create|build|write|analyze|design|fix|add|make|develop|code)"; then
        has_task=true
        [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "Task detected"
    fi

    # Check for constraint indicators
    if echo "$prompt_lower" | grep -qE "(must|should|constraint|requirement|limit|except|but|however)"; then
        has_constraints=true
        [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "Constraints detected"
    fi

    if [[ "$has_role" == false ]]; then
        score=$((score - 15))
        [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "Missing role penalty: -15%"
    fi
    if [[ "$has_task" == false ]]; then
        score=$((score - 20))
        [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "Missing task penalty: -20%"
    fi
    if [[ "$has_constraints" == false ]]; then
        score=$((score - 10))
        [[ "$LOG_LEVEL" == "DEBUG" ]] && log_message "DEBUG" "Missing constraints penalty: -10%"
    fi

    # Ensure score is within 0-100 range
    if [[ $score -lt 0 ]]; then
        score=0
    elif [[ $score -gt 100 ]]; then
        score=100
    fi

    echo "$score"
}

# Calculate clarity score
CLARITY_SCORE=$(calculate_clarity_score "$USER_PROMPT")

log_message "INFO" "Clarity score: $CLARITY_SCORE% (threshold: ${THRESHOLD}%)"

# If clarity score is below threshold, suggest /promptify
if [[ $CLARITY_SCORE -lt $THRESHOLD ]]; then
    # Analyze what's missing to provide helpful feedback
    local prompt_lower=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')
    local missing_role=false
    local missing_task=false
    local missing_constraints=false
    local missing_details=()

    if ! echo "$prompt_lower" | grep -qE "(you are|act as|role|persona)"; then
        missing_role=true
        missing_details+=("Role definition (who should Claude be?)")
    fi

    if ! echo "$prompt_lower" | grep -qE "(implement|create|build|write|analyze|design|fix)"; then
        missing_task=true
        missing_details+=("Task specification (what exactly needs doing?)")
    fi

    if ! echo "$prompt_lower" | grep -qE "(must|should|constraint|requirement|limit)"; then
        missing_constraints=true
        missing_details+=("Constraints (what rules apply?)")
    fi

    # Build suggestion message
    local suggestion_parts=()
    suggestion_parts+=("💡 **Prompt Clarity**: Your prompt clarity score is **${CLARITY_SCORE}%** (below ${THRESHOLD}% threshold).")

    if [[ ${#missing_details[@]} -gt 0 ]]; then
        suggestion_parts+=("")
        suggestion_parts+=("**Missing Elements**:")
        for detail in "${missing_details[@]}"; do
            suggestion_parts+=("- ❌ $detail")
        done
    fi

    suggestion_parts+=("")
    suggestion_parts+=("Consider using **/promptify** to automatically optimize your prompt with:")
    suggestion_parts+=("- ✅ **Role definition** (who should Claude be?)")
    suggestion_parts+=("- ✅ **Task specification** (what exactly needs doing?)")
    suggestion_parts+=("- ✅ **Constraints** (what rules apply?)")
    suggestion_parts+=("- ✅ **Output format** (what does done look like?)")
    suggestion_parts+=("")
    suggestion_parts+=("**Usage**:")
    suggestion_parts+=('```bash')
    suggestion_parts+=("/promptify $USER_PROMPT")
    suggestion_parts+=('```')
    suggestion_parts+=("")
    suggestion_parts+=("Or use modifiers:")
    suggestion_parts+=('```bash')
    suggestion_parts+=("/promptify +ask    # Ask clarifying questions first")
    suggestion_parts+=("/promptify +deep   # Explore codebase for context")
    suggestion_parts+=("/promptify +web    # Search web for best practices")
    suggestion_parts+=("/promptify +ask+deep+web  # Combine multiple")
    suggestion_parts+=('```')

    # Join suggestion parts with newlines
    local SUGGESTION=$(IFS=$'\n'; echo "${suggestion_parts[*]}")

    # Output via additionalContext (non-intrusive)
    jq -n \
        --arg context "$SUGGESTION" \
        '{"additionalContext": $context, "continue": true}'

    log_message "INFO" "Suggested /promptify (clarity: $CLARITY_SCORE%, missing: ${#missing_details[@]} elements)"
else
    echo '{"continue": true}'
    log_message "DEBUG" "No suggestion needed (clarity: $CLARITY_SCORE% >= threshold: ${THRESHOLD}%)"
fi
