#!/bin/bash
# session-start-ledger.sh - SessionStart Hook for Ralph v2.43
# Auto-loads ledger, handoff, and claude-mem hints at session start
#
# Input (JSON via stdin):
#   - hook_event_name: "SessionStart"
#   - session_id: Current session identifier
#   - source: "startup" | "resume" | "clear" | "compact"
#
# Output (JSON):
#   - hookSpecificOutput.additionalContext: Content to inject into context
#
# Part of Ralph v2.43 Context Engineering with Claude-Mem Integration
#
# VERSION: 2.84.2

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# Configuration
LEDGER_DIR="${HOME}/.ralph/ledgers"
HANDOFF_DIR="${HOME}/.ralph/handoffs"
SCRIPTS_DIR="${HOME}/.claude/scripts"
FEATURES_FILE="${HOME}/.ralph/config/features.json"
LOG_FILE="${HOME}/.ralph/logs/session-start.log"
CLAUDE_MEM_CACHE="${HOME}/.ralph/cache/claude-mem-hints.txt"

# Ensure directories exist
mkdir -p "$LEDGER_DIR" "$HANDOFF_DIR" "${HOME}/.ralph/logs" "${HOME}/.ralph/cache"

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Check feature flags
check_feature_enabled() {
    local feature="$1"
    local default="$2"

    if [[ -f "$FEATURES_FILE" ]]; then
        local value
        value=$(jq -r ".$feature // \"$default\"" "$FEATURES_FILE" 2>/dev/null || echo "$default")
        [[ "$value" == "true" ]]
    else
        [[ "$default" == "true" ]]
    fi
}

# v2.84.2: Get most recent file matching pattern (avoids pipefail+head SIGPIPE)
get_most_recent_file() {
    local dir="$1"
    local pattern="$2"
    local recent=""

    while IFS= read -r -d '' file; do
        if [[ -z "$recent" ]] || [[ "$file" -nt "$recent" ]]; then
            recent="$file"
        fi
    done < <(find "$dir" -maxdepth 1 -name "$pattern" -type f -print0 2>/dev/null)

    echo "$recent"
}

# v2.43: Get claude-mem integration hints (3-layer workflow)
get_claude_mem_hints() {
    local hints=""

    # Check if claude-mem cache exists and is recent (< 1 hour)
    if [[ -f "$CLAUDE_MEM_CACHE" ]]; then
        local cache_age
        # MEDIUM-001 FIX: Portable stat (macOS/BSD: -f %m, Linux: -c %Y)
        cache_age=$(($(date +%s) - $(stat -f %m "$CLAUDE_MEM_CACHE" 2>/dev/null || stat -c %Y "$CLAUDE_MEM_CACHE" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt 3600 ]]; then
            hints=$(cat "$CLAUDE_MEM_CACHE" 2>/dev/null || true)
        fi
    fi

    # If no cache, provide default hints
    if [[ -z "$hints" ]]; then
        hints="**Claude-Mem Available**: Use MCP tools to search for relevant context:
\`\`\`
mcp__plugin_claude-mem_mcp-search__search({query: 'session goal progress', limit: 10})
\`\`\`
Then use get_observations for details on specific IDs."
    fi

    echo "$hints"
}

# Read input from stdin
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top

# Parse input JSON
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"' 2>/dev/null || echo "startup")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

log "INFO" "SessionStart hook triggered - source: $SOURCE, session: $SESSION_ID"

# Check if ledger feature is enabled (default: true)
if ! check_feature_enabled "RALPH_ENABLE_LEDGER" "true"; then
    log "INFO" "Ledger feature disabled via features.json"
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ""}}'
    exit 0
fi

# Find the most recent ledger (v2.84.2: use get_most_recent_file to avoid SIGPIPE)
LEDGER=""
if [[ -d "$LEDGER_DIR" ]]; then
    LEDGER=$(get_most_recent_file "$LEDGER_DIR" "CONTINUITY_RALPH-*.md")
fi

# Find the most recent handoff (v2.84.2: use get_most_recent_file for subdirs)
HANDOFF=""
if [[ -d "$HANDOFF_DIR" ]]; then
    # Search all subdirectories for handoffs
    while IFS= read -r -d '' file; do
        if [[ -z "$HANDOFF" ]] || [[ "$file" -nt "$HANDOFF" ]]; then
            HANDOFF="$file"
        fi
    done < <(find "$HANDOFF_DIR" -name "handoff-*.md" -type f -print0 2>/dev/null)
fi

# Build context to inject
CONTEXT=""

# Add ledger content if found
if [[ -n "$LEDGER" ]] && [[ -f "$LEDGER" ]]; then
    LEDGER_CONTENT=$(cat "$LEDGER" 2>/dev/null || true)
    if [[ -n "$LEDGER_CONTENT" ]]; then
        CONTEXT+="## Session Ledger (auto-loaded)\n"
        CONTEXT+="$LEDGER_CONTENT"
        CONTEXT+="\n\n"
        log "INFO" "Loaded ledger: $LEDGER"
    fi
fi

# Add handoff content if found and enabled
if check_feature_enabled "RALPH_ENABLE_HANDOFF" "true"; then
    if [[ -n "$HANDOFF" ]] && [[ -f "$HANDOFF" ]]; then
        HANDOFF_CONTENT=$(cat "$HANDOFF" 2>/dev/null || true)
        if [[ -n "$HANDOFF_CONTENT" ]]; then
            CONTEXT+="## Last Handoff (auto-loaded)\n"
            CONTEXT+="$HANDOFF_CONTENT"
            log "INFO" "Loaded handoff: $HANDOFF"
        fi
    fi
fi

# v2.43: Add claude-mem integration hints
if check_feature_enabled "RALPH_ENABLE_CLAUDE_MEM" "true"; then
    CLAUDE_MEM_HINTS=$(get_claude_mem_hints)
    if [[ -n "$CLAUDE_MEM_HINTS" ]]; then
        CONTEXT+="\n\n## Claude-Mem Integration (v2.43)\n"
        CONTEXT+="$CLAUDE_MEM_HINTS"
        log "INFO" "Added claude-mem integration hints"
    fi
fi

# v2.43: Add context engineering hints
CONTEXT+="\n\n## Context Engineering (v2.43)\n"
CONTEXT+="- Native context_window.used_percentage available via StatusLine\n"
CONTEXT+="- Use LSP tools for token-free code navigation\n"
CONTEXT+="- claude-mem MCP for persistent semantic memory\n"

# If no context to inject, return empty
if [[ -z "$CONTEXT" ]]; then
    log "INFO" "No ledger or handoff found to inject"
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ""}}'
    exit 0
fi

# Escape the context for JSON
# Use Python for reliable JSON escaping
ESCAPED_CONTEXT=$(python3 -c "
import json
import sys
content = sys.stdin.read()
print(json.dumps(content))
" <<< "$CONTEXT")

# Output JSON with context to inject
cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ESCAPED_CONTEXT
  }
}
EOF

log "INFO" "SessionStart hook completed successfully"
