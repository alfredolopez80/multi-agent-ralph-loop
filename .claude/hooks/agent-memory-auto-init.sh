#!/bin/bash
# Agent Memory Auto-Init (v2.55.0)
# Hook: PreToolUse (Task)
# Purpose: Automatically initialize agent memory buffers when agents are spawned
#
# When a Task tool spawns an agent, this hook checks if the agent
# has a memory buffer. If not, it initializes one automatically.
#
# VERSION: 2.57.2
# v2.57.2: Fixed JSON output (SEC-034) - must output JSON, not silent exit
# SECURITY: SEC-006 compliant with ERR trap for guaranteed clean exit

set -euo pipefail
umask 077

# SEC-034: Guaranteed JSON output on any error or exit
output_json() {
    echo '{"decision": "continue"}'
}
trap 'output_json' ERR EXIT

# Parse input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only process Task tool
if [[ "$TOOL_NAME" != "Task" ]]; then
    trap - EXIT; echo '{"decision": "continue"}'; exit 0
fi

# Extract subagent type
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || echo "")

# Skip if no subagent type
if [[ -z "$SUBAGENT_TYPE" ]]; then
    trap - EXIT; echo '{"decision": "continue"}'; exit 0
fi

# Agent memory directory
AGENT_MEM_DIR="${HOME}/.ralph/agent-memory"
AGENT_DIR="${AGENT_MEM_DIR}/${SUBAGENT_TYPE}"

# Skip if already initialized
if [[ -d "$AGENT_DIR" ]] && [[ -f "${AGENT_DIR}/memory.json" ]]; then
    trap - EXIT; echo '{"decision": "continue"}'; exit 0
fi

# Log directory
LOG_DIR="${HOME}/.ralph/logs"
mkdir -p "$LOG_DIR"

# Initialize agent memory buffer
{
    echo "[$(date -Iseconds)] Auto-initializing agent memory: $SUBAGENT_TYPE"

    # Create agent directory
    mkdir -p "$AGENT_DIR"

    # Create memory.json with proper structure
    cat > "${AGENT_DIR}/memory.json" << 'MEMORYJSON'
{
  "agent_id": "AGENT_PLACEHOLDER",
  "created": "CREATED_PLACEHOLDER",
  "semantic": [],
  "episodic": [],
  "working": []
}
MEMORYJSON

    # Replace placeholders
    sed -i.bak \
        -e "s/AGENT_PLACEHOLDER/${SUBAGENT_TYPE}/" \
        -e "s/CREATED_PLACEHOLDER/$(date -Iseconds)/" \
        "${AGENT_DIR}/memory.json" 2>/dev/null || \
    sed -i '' \
        -e "s/AGENT_PLACEHOLDER/${SUBAGENT_TYPE}/" \
        -e "s/CREATED_PLACEHOLDER/$(date -Iseconds)/" \
        "${AGENT_DIR}/memory.json"

    # Clean up backup file if created
    rm -f "${AGENT_DIR}/memory.json.bak"

    echo "[$(date -Iseconds)] Agent memory initialized: $AGENT_DIR"

} >> "${LOG_DIR}/agent-memory-init-$(date +%Y%m%d).log" 2>&1 || true

# Allow the Task to proceed
exit 0
