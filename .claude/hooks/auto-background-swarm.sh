#!/usr/bin/env bash
# auto-background-swarm.sh
# PostToolUse hook - Automatically suggests/sets swarm mode for Task tool calls
# Version: 2.81.1

# This hook runs after PostToolUse events to detect Task tool usage
# and ensure swarm mode parameters are present for parallel execution

set +e  # Don't exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hook metadata
VERSION="2.81.1"
HOOK_NAME="auto-background-swarm"

# Supported commands that should use swarm mode
SUPPORTED_COMMANDS=(
  "orchestrator"
  "loop"
  "edd"
  "bug"
  "adversarial"
  "parallel"
  "gates"
)

# Function to log to file
log_message() {
  local level="$1"
  local message="$2"
  local log_file="${HOME}/.ralph/hooks/${HOOK_NAME}.log"

  mkdir -p "$(dirname "$log_file")"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$log_file"
}

# Function to check if command supports swarm mode
command_supports_swarm() {
  local cmd="$1"
  for supported in "${SUPPORTED_COMMANDS[@]}"; do
    if [[ "$supported" == "$cmd" ]]; then
      return 0  # Supports swarm
    fi
  done
  return 1  # Does not support swarm
}

# Function to extract command name from prompt
extract_command_from_prompt() {
  local prompt="$1"

  # Look for /command patterns
  if [[ "$prompt" =~ /([a-z]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# Function to check if Task tool was used
was_task_tool_used() {
  local tool_name="$1"

  # Check if this was a Task tool call
  if [[ "$tool_name" == "Task" ]]; then
    return 0
  fi
  return 1
}

# Main hook logic
main() {
  local tool_name="${1:-unknown}"
  local exit_code="${2:-0}"

  # Only proceed for Task tool calls
  if ! was_task_tool_used "$tool_name"; then
    echo '{"continue": true}'
    return 0
  fi

  log_message "INFO" "Task tool detected, checking for swarm mode configuration"

  # Read stdin to get the tool parameters
  local stdin_content
  stdin_content=$(cat)

  # Check if run_in_background is set
  if echo "$stdin_content" | grep -q '"run_in_background"\s*:\s*true'; then
    log_message "INFO" "run_in_background: true detected, OK"
    echo '{"continue": true}'
    return 0
  fi

  # Extract prompt to detect command
  local prompt
  prompt=$(echo "$stdin_content" | jq -r '.prompt // empty' 2>/dev/null)

  if [[ -n "$prompt" ]]; then
    local cmd
    cmd=$(extract_command_from_prompt "$prompt")

    if [[ -n "$cmd" ]] && command_supports_swarm "$cmd"; then
      log_message "WARN" "Command /$cmd supports swarm mode but run_in_background not set"

      # Print warning message (non-blocking)
      echo -e "${YELLOW}⚠️  SWARM MODE SUGGESTION${NC}" >&2
      echo -e "${BLUE}Command /$cmd supports swarm mode for parallel execution${NC}" >&2
      echo -e "${YELLOW}Consider adding: run_in_background: true${NC}" >&2
      echo "" >&2
    fi
  fi

  # Continue without blocking
  echo '{"continue": true}'
  return 0
}

# Execute main function
main "$@"
exit 0
