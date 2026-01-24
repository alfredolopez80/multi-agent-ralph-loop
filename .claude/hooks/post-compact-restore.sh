#!/bin/bash
# VERSION: 2.68.7
# post-compact-restore.sh - Multi-Agent Ralph v2.68.7
# Restores context after compaction using ledger + claude-mem MCP
# Triggered by PostCompact hook event
# v2.68.7: CRIT-001 - Added guaranteed JSON output for PostCompact hooks

set -euo pipefail

# SEC-006: Guaranteed JSON output on any error
trap 'echo "{\"continue\": true}"' ERR EXIT

LOG_FILE="${HOME}/.ralph/logs/post-compact.log"
SESSION_FILE="${HOME}/.ralph/.current-session"
LEDGER_DIR="${HOME}/.ralph/ledgers"

log() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

log "PostCompact hook triggered"

# Get current session ID
SESSION_ID=""
if [[ -f "$SESSION_FILE" ]]; then
    SESSION_ID=$(cat "$SESSION_FILE")
    log "Session ID: $SESSION_ID"
fi

# Get project name from PWD
PROJECT=$(basename "$(pwd)")
log "Project: $PROJECT"

# Output context restoration prompt for Claude
cat << 'EOF'
## Context Restored (Auto-injected by PostCompact hook)

### Quick Context Recovery

The conversation was just compacted. Use claude-mem MCP to restore full context:

```yaml
# 1. Search for recent session context
mcp__plugin_claude-mem_mcp-search__search:
  query: "session progress implementation"
  project: "${PROJECT}"
  limit: 10

# 2. Get timeline around key observations
mcp__plugin_claude-mem_mcp-search__timeline:
  query: "recent changes"
  depth_before: 5
  depth_after: 0

# 3. Fetch specific observations if needed
mcp__plugin_claude-mem_mcp-search__get_observations:
  ids: [<relevant_ids>]
```

### Ledger Summary
EOF

# Include compact ledger if available
if [[ -n "$SESSION_ID" ]] && command -v ralph &>/dev/null; then
    log "Loading ledger for session: $SESSION_ID"
    ralph ledger show --compact 2>/dev/null | head -50 || echo "No ledger data available"
else
    # Fallback: show most recent ledger
    RECENT_LEDGER=$(ls -t "$LEDGER_DIR"/CONTINUITY_RALPH-*.md 2>/dev/null | head -1)
    if [[ -n "$RECENT_LEDGER" ]]; then
        log "Loading recent ledger: $RECENT_LEDGER"
        echo "### Recent Session Context"
        head -100 "$RECENT_LEDGER" 2>/dev/null || true
    else
        echo "No ledger data available. Continue from scratch or use claude-mem MCP search."
    fi
fi

cat << 'EOF'

### Next Steps

1. Review the context above
2. Use claude-mem MCP if more detail needed
3. Continue with the task at hand

**Tip**: Your work progress was preserved. Focus on completing the current task.
EOF

log "PostCompact hook completed"

# Clear error trap and output success JSON
trap - ERR EXIT
echo '{"continue": true}'
