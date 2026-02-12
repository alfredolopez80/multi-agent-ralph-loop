#!/bin/bash
# .claude/scripts/glm5-teammate.sh
# GLM-5 Teammate Execution Script with project-scoped file-based status
# Version: 2.84.0

set -e

# === Configuration ===
ROLE="${1:-coder}"
TASK="${2:-}"
TASK_ID="${3:-task-$(date +%s)}"
THINKING="${4:-enabled}"
API_ENDPOINT="${GLM5_API_ENDPOINT:-https://api.z.ai/api/coding/paas/v4/chat/completions}"

# === Get Project Root ===
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"

# === Directories (project-scoped) ===
RALPH_DIR="${PROJECT_ROOT}/.ralph"
REASONING_DIR="${RALPH_DIR}/reasoning"
STATUS_DIR="${RALPH_DIR}/teammates/${TASK_ID}"
LOGS_DIR="${RALPH_DIR}/logs"

mkdir -p "$REASONING_DIR" "$STATUS_DIR" "$LOGS_DIR"

# === Logging Function ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [glm5-${ROLE}] $1" >> "${LOGS_DIR}/teammates.log"
}

log "Starting teammate execution (task_id: ${TASK_ID})"

# === Validate Inputs ===
if [ -z "$TASK" ]; then
    echo "Error: TASK is required" >&2
    exit 1
fi

if [ -z "$Z_AI_API_KEY" ]; then
    echo "Error: Z_AI_API_KEY environment variable is not set" >&2
    exit 1
fi

# === Build System Prompt Based on Role ===
build_system_prompt() {
    local role="$1"
    case "$role" in
        "coder")
            echo "You are a coding agent powered by GLM-5. Implement the requested feature following best practices. Output code with brief explanations. Follow TDD principles when appropriate."
            ;;
        "reviewer")
            echo "You are a code reviewer agent powered by GLM-5. Analyze for security vulnerabilities, performance issues, and code quality. Provide actionable feedback with severity ratings."
            ;;
        "tester")
            echo "You are a testing agent powered by GLM-5. Generate comprehensive tests with good coverage. Include edge cases, error scenarios, and use the AAA pattern (Arrange, Act, Assert)."
            ;;
        "planner")
            echo "You are an architecture planner powered by GLM-5. Design solutions with clear rationale. Consider scalability, maintainability, and best practices."
            ;;
        "researcher")
            echo "You are a research agent powered by GLM-5. Explore and document findings thoroughly. Provide comprehensive analysis with citations where possible."
            ;;
        *)
            echo "You are a helpful agent powered by GLM-5. Complete the task to the best of your ability."
            ;;
    esac
}

SYSTEM_PROMPT=$(build_system_prompt "$ROLE")

# === Escape Task for JSON ===
# Simple escaping for JSON strings
TASK_ESCAPED=$(echo "$TASK" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
SYSTEM_PROMPT_ESCAPED=$(echo "$SYSTEM_PROMPT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')

# === Call GLM-5 API ===
log "Calling GLM-5 API (thinking: ${THINKING})"

# Build JSON payload properly to avoid encoding issues
JSON_PAYLOAD=$(cat <<EOF
{
  "model": "glm-5",
  "messages": [
    {"role": "system", "content": $(echo "$SYSTEM_PROMPT" | jq -Rs .)},
    {"role": "user", "content": $(echo "$TASK" | jq -Rs .)}
  ],
  "thinking": {"type": "${THINKING}"},
  "max_tokens": 8192,
  "temperature": 0.7
}
EOF
)

RESPONSE=$(curl -s -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${Z_AI_API_KEY}" \
  -d "$JSON_PAYLOAD")

# === Check for API Errors ===
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // .error')
    log "API Error: ${ERROR_MSG}"
    echo "Error: GLM-5 API returned an error: ${ERROR_MSG}" >&2
    exit 1
fi

# === Extract Content and Reasoning ===
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')
REASONING=$(echo "$RESPONSE" | jq -r '.choices[0].message.reasoning_content // empty')
USAGE=$(echo "$RESPONSE" | jq -r '.usage // empty')

# === Extract Usage Stats ===
PROMPT_TOKENS=$(echo "$USAGE" | jq -r '.prompt_tokens // 0')
COMPLETION_TOKENS=$(echo "$USAGE" | jq -r '.completion_tokens // 0')
TOTAL_TOKENS=$(echo "$USAGE" | jq -r '.total_tokens // 0')

log "API call complete (tokens: ${TOTAL_TOKENS})"

# === Write Reasoning to File ===
if [ -n "$REASONING" ]; then
    REASONING_FILE="${REASONING_DIR}/${TASK_ID}.txt"
    echo "$REASONING" > "$REASONING_FILE"
    log "Reasoning saved to ${REASONING_FILE} ($(${#REASONING}) chars)"
else
    REASONING_FILE=""
    log "No reasoning content captured"
fi

# === Write Status File ===
STATUS_FILE="${STATUS_DIR}/status.json"
cat > "$STATUS_FILE" << EOF
{
  "task_id": "${TASK_ID}",
  "agent_type": "glm5-${ROLE}",
  "status": "completed",
  "project": "${PROJECT_ROOT}",
  "reasoning_file": "${REASONING_FILE}",
  "output_summary": $(echo "$CONTENT" | head -c 500 | jq -Rs .),
  "usage": {
    "prompt_tokens": ${PROMPT_TOKENS},
    "completion_tokens": ${COMPLETION_TOKENS},
    "total_tokens": ${TOTAL_TOKENS}
  },
  "timestamp": "$(date -Iseconds)"
}
EOF

log "Status file written to ${STATUS_FILE}"

# === Output Content for Orchestrator ===
echo "$CONTENT"
