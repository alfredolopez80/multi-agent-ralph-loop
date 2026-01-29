#!/usr/bin/env bash
# Swarm Mode Configuration Script
# VERSION: 2.81.0
# Automatically configures Swarm Mode settings on any machine

set -euo pipefail

# Script metadata
VERSION="2.81.0"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SETTINGS_PATH="$HOME/.claude-sneakpeek/zai/config/settings.json"
BACKUP_PATH="$HOME/.claude-sneakpeek/zai/config/settings.json.backup.$(date +%Y%m%d-%H%M%S)"

# Required settings
REQUIRED_SETTINGS=(
  "CLAUDE_CODE_AGENT_ID=claude-orchestrator"
  "CLAUDE_CODE_AGENT_NAME=Orchestrator"
  "CLAUDE_CODE_TEAM_NAME=multi-agent-ralph-loop"
  "CLAUDE_CODE_PLAN_MODE_REQUIRED=false"
)

# Functions
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

print_header() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║     Swarm Mode Configuration Script v$VERSION               ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

check_prerequisites() {
  log_info "Checking prerequisites..."

  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed"
    echo "  Install: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
  fi
  log_success "jq is installed"

  # Check if settings.json exists
  if [[ ! -f "$SETTINGS_PATH" ]]; then
    log_error "Settings file not found: $SETTINGS_PATH"
    echo "  Are you using the claude-sneakpeek zai variant?"
    exit 1
  fi
  log_success "Settings file found: $SETTINGS_PATH"

  # Check if settings.json is valid JSON
  if ! jq empty "$SETTINGS_PATH" &> /dev/null; then
    log_error "Settings file is not valid JSON"
    exit 1
  fi
  log_success "Settings file is valid JSON"
}

backup_settings() {
  log_info "Creating backup..."

  if cp "$SETTINGS_PATH" "$BACKUP_PATH"; then
    log_success "Backup created: $BACKUP_PATH"
  else
    log_error "Failed to create backup"
    exit 1
  fi
}

configure_agent_env_vars() {
  log_info "Configuring agent environment variables..."

  local temp_file="/tmp/settings.$$.json"
  local needs_update=false

  # Read current settings
  local current_settings
  current_settings=$(cat "$SETTINGS_PATH")

  # Check and add each required variable
  for setting in "${REQUIRED_SETTINGS[@]}"; do
    local key="${setting%%=*}"
    local value="${setting#*=}"

    if ! jq -e ".env.\"$key\"" "$SETTINGS_PATH" &> /dev/null; then
      log_info "Adding $key=$value"
      current_settings=$(echo "$current_settings" | jq --arg key "$key" --arg value "$value" \
        '.env[$key] = $value')
      needs_update=true
    else
      log_success "$key already set"
    fi
  done

  # Write updated settings
  if [[ "$needs_update" == "true" ]]; then
    echo "$current_settings" > "$temp_file"
    if mv "$temp_file" "$SETTINGS_PATH"; then
      log_success "Agent environment variables configured"
    else
      log_error "Failed to update settings"
      rm -f "$temp_file"
      exit 1
    fi
  else
    log_success "All agent environment variables already set"
  fi
}

configure_permissions() {
  log_info "Configuring permissions..."

  local current_mode
  current_mode=$(jq -r '.permissions.defaultMode // "unknown"' "$SETTINGS_PATH")

  if [[ "$current_mode" != "delegate" ]]; then
    log_info "Setting defaultMode to delegate"
    local temp_file="/tmp/settings.$$.json"
    jq '.permissions.defaultMode = "delegate"' "$SETTINGS_PATH" > "$temp_file"
    if mv "$temp_file" "$SETTINGS_PATH"; then
      log_success "defaultMode set to delegate"
    else
      log_error "Failed to set defaultMode"
      rm -f "$temp_file"
      exit 1
    fi
  else
    log_success "defaultMode already set to delegate"
  fi
}

configure_model() {
  log_info "Configuring primary model..."

  local current_model
  current_model=$(jq -r '.model // "unknown"' "$SETTINGS_PATH")

  if [[ "$current_model" != "glm-4.7" ]]; then
    log_info "Setting model to glm-4.7 (current: $current_model)"
    local temp_file="/tmp/settings.$$.json"
    jq '.model = "glm-4.7"' "$SETTINGS_PATH" > "$temp_file"
    if mv "$temp_file" "$SETTINGS_PATH"; then
      log_success "Model set to glm-4.7"
    else
      log_error "Failed to set model"
      rm -f "$temp_file"
      exit 1
    fi
  else
    log_success "Model already set to glm-4.7"
  fi
}

validate_configuration() {
  log_info "Validating configuration..."

  local all_valid=true

  # Check each required setting
  for setting in "${REQUIRED_SETTINGS[@]}"; do
    local key="${setting%%=*}"
    local expected_value="${setting#*=}"

    if ! jq -e ".env.\"$key\"" "$SETTINGS_PATH" &> /dev/null; then
      log_error "Missing: $key"
      all_valid=false
    else
      local actual_value
      actual_value=$(jq -r ".env.\"$key\"" "$SETTINGS_PATH")
      if [[ "$actual_value" != "$expected_value" ]]; then
        log_warning "$key has unexpected value: $actual_value (expected: $expected_value)"
      else
        log_success "$key=$actual_value"
      fi
    fi
  done

  # Check defaultMode
  local default_mode
  default_mode=$(jq -r '.permissions.defaultMode' "$SETTINGS_PATH")
  if [[ "$default_mode" == "delegate" ]]; then
    log_success "defaultMode=$default_mode"
  else
    log_error "defaultMode is $default_mode (should be delegate)"
    all_valid=false
  fi

  # Check model
  local model
  model=$(jq -r '.model' "$SETTINGS_PATH")
  if [[ "$model" == "glm-4.7" ]]; then
    log_success "model=$model"
  else
    log_warning "model is $model (recommended: glm-4.7)"
  fi

  if [[ "$all_valid" == "false" ]]; then
    log_error "Configuration validation failed"
    exit 1
  fi
}

print_summary() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║              Configuration Complete                           ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Swarm Mode v$VERSION has been configured successfully!"
  echo ""
  echo "Configuration Summary:"
  echo "  • Agent ID: $(jq -r '.env.CLAUDE_CODE_AGENT_ID' "$SETTINGS_PATH")"
  echo "  • Agent Name: $(jq -r '.env.CLAUDE_CODE_AGENT_NAME' "$SETTINGS_PATH")"
  echo "  • Team Name: $(jq -r '.env.CLAUDE_CODE_TEAM_NAME' "$SETTINGS_PATH")"
  echo "  • Plan Mode Required: $(jq -r '.env.CLAUDE_CODE_PLAN_MODE_REQUIRED' "$SETTINGS_PATH")"
  echo "  • Default Mode: $(jq -r '.permissions.defaultMode' "$SETTINGS_PATH")"
  echo "  • Primary Model: $(jq -r '.model' "$SETTINGS_PATH")"
  echo ""
  echo "Backup Location:"
  echo "  • $BACKUP_PATH"
  echo ""
  echo "Next Steps:"
  echo "  1. Run validation tests:"
  echo "     bash $SCRIPT_DIR/test-swarm-mode-config.sh"
  echo ""
  echo "  2. Test swarm mode:"
  echo "     /orchestrator \"create a hello world function\""
  echo ""
  echo "  3. If needed, rollback:"
  echo "     cp $BACKUP_PATH $SETTINGS_PATH"
  echo ""
}

# Main execution
main() {
  print_header

  log_info "Starting Swarm Mode configuration..."
  echo ""

  # Execute configuration steps
  check_prerequisites
  echo ""
  backup_settings
  echo ""
  configure_agent_env_vars
  echo ""
  configure_permissions
  echo ""
  configure_model
  echo ""
  validate_configuration
  echo ""

  # Print summary
  print_summary
}

# Usage
usage() {
  echo "Usage: $SCRIPT_NAME [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help     Show this help message"
  echo "  -v, --version  Show version information"
  echo ""
  echo "This script configures Swarm Mode v$VERSION for Claude Code."
  echo ""
  echo "It will:"
  echo "  1. Backup your current settings.json"
  echo "  2. Add required agent environment variables"
  echo "  3. Set defaultMode to 'delegate'"
  echo "  4. Set primary model to 'glm-4.7'"
  echo "  5. Validate the configuration"
  echo ""
}

# Handle command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      echo "Swarm Mode Configuration Script v$VERSION"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

# Run main
main
