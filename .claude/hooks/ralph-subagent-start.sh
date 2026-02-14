#!/bin/bash
# ralph-subagent-start.sh - Initialize subagents with Ralph context
# VERSION: 2.85.0
# REPO: multi-agent-ralph-loop
#
# Triggered by: SubagentStart hook event (matcher: ralph-*)
# Purpose: Load Ralph context into new subagents
#
# Input (stdin JSON):
#   {
#     "subagentId": "subagent-xxx",
#     "subagentType": "ralph-coder|ralph-reviewer|ralph-tester|ralph-researcher",
#     "parentId": "parent-xxx"
#   }
#
# Output (stdout JSON):
#   {"context": "...context to inject..."}

set -euo pipefail

# Configuration
REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
LOG_DIR="$HOME/.ralph/logs"
MEMORY_DIR="$HOME/.ralph/memory"
mkdir -p "$LOG_DIR"

# Read stdin for subagent info
stdin_data=$(cat)

# Extract info
subagent_id=$(echo "$stdin_data" | jq -r '.subagentId // .subagent_id // "unknown"')
subagent_type=$(echo "$stdin_data" | jq -r '.subagentType // .subagent_type // "unknown"')
parent_id=$(echo "$stdin_data" | jq -r '.parentId // .parent_id // "unknown"')

# Log the event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SubagentStart: ${subagent_id} (${subagent_type}) parent=${parent_id}" >> "$LOG_DIR/agent-teams.log"

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
