#!/bin/bash
# ralph-subagent-start.sh - Initialize subagents with Ralph context
# VERSION: 2.88.0
# REPO: multi-agent-ralph-loop
#
# Triggered by: SubagentStart hook event (matcher: ralph-*)
# Purpose: Load Ralph context into new subagents
#
# v2.88.0 Changes:
#   - Register subagent state on start (Finding #4)
#   - Track parent-child relationships
#   - Enable lifecycle tracking for Stop hook
#
# Input (stdin JSON):
#   {
#     "subagentId": "subagent-xxx",
#     "subagentType": "ralph-coder|ralph-reviewer|ralph-tester|ralph-researcher",
#     "parentId": "parent-xxx",
#     "sessionId": "session-xxx",
#     "taskId": "task-xxx"
#   }
#
# Output (stdout JSON):
#   {"context": "...context to inject..."}

set -euo pipefail

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_DIR="$HOME/.ralph/state"
LOG_DIR="$HOME/.ralph/logs"
MEMORY_DIR="$HOME/.ralph/memory"
mkdir -p "$LOG_DIR" "$STATE_DIR"

# Read stdin for subagent info
# SEC-111: Limit stdin to 100KB to prevent memory exhaustion
stdin_data=$(head -c 100000)

# Extract info
# v2.89.2: Official field names first (agent_id, agent_type), then fallbacks
subagent_id=$(echo "$stdin_data" | jq -r '.agent_id // .subagentId // .subagent_id // "unknown"')
subagent_type=$(echo "$stdin_data" | jq -r '.agent_type // .subagentType // .subagent_type // "unknown"')
parent_id=$(echo "$stdin_data" | jq -r '.parent_id // .parentId // "unknown"')
session_id=$(echo "$stdin_data" | jq -r '.sessionId // .session_id // "default"')
task_id=$(echo "$stdin_data" | jq -r '.taskId // .task_id // ""')

# Log the event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SubagentStart: ${subagent_id} (${subagent_type}) parent=${parent_id} session=${session_id}" >> "$LOG_DIR/agent-teams.log"

# ============================================
# v2.88.0: Register subagent state (Finding #4)
# ============================================
SUBAGENT_STATE="$STATE_DIR/${session_id}/subagents/${subagent_id}.json"
mkdir -p "$(dirname "$SUBAGENT_STATE")"

jq -n \
    --arg id "$subagent_id" \
    --arg type "$subagent_type" \
    --arg parent "$parent_id" \
    --arg session "$session_id" \
    --arg task "$task_id" \
    --arg time "$(date -Iseconds)" \
    '{
        id: $id,
        type: $type,
        parent: $parent,
        session: $session,
        task: $task,
        status: "active",
        started_at: $time,
        last_heartbeat: $time
    }' > "$SUBAGENT_STATE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Subagent state registered: $SUBAGENT_STATE" >> "$LOG_DIR/agent-teams.log"

# Build context based on subagent type
CONTEXT=""

# Common Ralph context for all subagents
CONTEXT+="# Ralph Context for ${subagent_type}\n\n"

# Add project context if available
if [[ -f "$REPO_ROOT/CLAUDE.md" ]]; then
    # Extract key sections (first 50 lines for context)
    CONTEXT+="## Project Guidelines\n"
    CONTEXT+="$(head -50 "$REPO_ROOT/CLAUDE.md" | grep -v "^#" | grep -v "^$" | head -20)\n\n"
fi

# Add quality standards
CONTEXT+="## Quality Standards\n"
CONTEXT+="- CORRECTNESS: Syntax valid, logic sound\n"
CONTEXT+="- QUALITY: No console.log, proper types\n"
CONTEXT+="- SECURITY: No hardcoded secrets, input validation\n"
CONTEXT+="- CONSISTENCY: Follow project style\n\n"

# Add type-specific context
case "$subagent_type" in
    ralph-coder)
        CONTEXT+="## Coder Guidelines\n"
        CONTEXT+="- Run quality gates before marking work complete\n"
        CONTEXT+="- Use /gates command to verify\n"
        CONTEXT+="- Follow YAGNI principles\n\n"
        ;;
    ralph-reviewer)
        CONTEXT+="## Reviewer Guidelines\n"
        CONTEXT+="- Check for OWASP Top 10 vulnerabilities\n"
        CONTEXT+="- Verify proper error handling\n"
        CONTEXT+="- Ensure code follows project patterns\n\n"
        ;;
    ralph-tester)
        CONTEXT+="## Tester Guidelines\n"
        CONTEXT+="- Target 80% coverage for new code\n"
        CONTEXT+="- Use Arrange-Act-Assert pattern\n"
        CONTEXT+="- Name tests: test_<feature>_<scenario>_<expected>\n\n"
        ;;
    ralph-researcher)
        CONTEXT+="## Researcher Guidelines\n"
        CONTEXT+="- Find existing patterns to reuse\n"
        CONTEXT+="- Identify required dependencies\n"
        CONTEXT+="- Document findings clearly\n\n"
        ;;
esac

# Add recent memory context if available
if [[ -f "$MEMORY_DIR/semantic.json" ]]; then
    recent_entries=$(jq -r '.observations[:3][] | "- " + .title' "$MEMORY_DIR/semantic.json" 2>/dev/null || echo "")
    if [[ -n "$recent_entries" ]]; then
        CONTEXT+="## Recent Learnings\n"
        CONTEXT+="$recent_entries\n\n"
    fi
fi

# Output context
# v2.87.0 FIX: SubagentStart uses {"continue": true} format
# Context is passed via hookSpecificOutput.additionalContext
CONTEXT_ESCAPED=$(echo -e "$CONTEXT" | jq -Rs '.')
cat <<EOF
{"continue": true, "hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": $CONTEXT_ESCAPED}}
EOF

exit 0
