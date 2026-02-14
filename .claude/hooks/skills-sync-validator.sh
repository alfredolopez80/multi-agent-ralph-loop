#!/bin/bash
#
# Skills Sync Validator Hook v2.87.0
# Validates sync between skills directories on session end
# Event: SessionEnd
#
# Output: JSON for Claude Code hook protocol
#

GLOBAL_SKILLS="$HOME/.claude/skills"
BACKUP_SKILLS="$HOME/backup/claude-skills"
AGENTS_SKILLS="$HOME/.agents/skills"
LOG_FILE="$HOME/.ralph/logs/skills-sync.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Log function
log() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

# Count items
global_count=$(ls "$GLOBAL_SKILLS" 2>/dev/null | wc -l | tr -d ' ')
backup_count=$(ls "$BACKUP_SKILLS" 2>/dev/null | wc -l | tr -d ' ')
agents_count=$(ls "$AGENTS_SKILLS" 2>/dev/null | wc -l | tr -d ' ')

# Check for broken symlinks in global
broken_global=$(find "$GLOBAL_SKILLS" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')

# Check for broken symlinks in agents
broken_agents=$(find "$AGENTS_SKILLS" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')

# Determine status
issues=()
[[ $broken_global -gt 0 ]] && issues+=("$broken_global broken symlinks in global")
[[ $broken_agents -gt 0 ]] && issues+=("$broken_agents broken symlinks in agents")
[[ ! -d "$BACKUP_SKILLS" ]] && issues+=("Backup directory missing")
[[ ! -d "$AGENTS_SKILLS" ]] && issues+=("Agents directory missing")

# Log status
log "Global: $global_count, Backup: $backup_count, Agents: $agents_count"
log "Broken global: $broken_global, Broken agents: $broken_agents"

# Output JSON
if [[ ${#issues[@]} -eq 0 ]]; then
    log "Status: OK"
    cat <<EOF
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "SessionEnd",
    "status": "sync_valid",
    "global": $global_count,
    "backup": $backup_count,
    "agents": $agents_count
  }
}
EOF
else
    log "Status: ISSUES - ${issues[*]}"
    cat <<EOF
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "SessionEnd",
    "status": "sync_issues",
    "issues": $(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .),
    "global": $global_count,
    "backup": $backup_count,
    "agents": $agents_count
  }
}
EOF
fi
