#!/usr/bin/env bash
# Swarm Mode Validation Script
# VERSION: 2.81.0
# Validates that native swarm mode is properly configured

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; ((PASSED++)); }
log_error() { echo -e "${RED}✗${NC} $1"; ((FAILED++)); }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }

print_header() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║         Swarm Mode Validation Script v2.81.0               ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# Test 1: Verify Claude Code version
test_claude_code_version() {
  log_info "Testing Claude Code version..."

  local version
  version=$(cat ~/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/package.json 2>/dev/null | jq -r '.version // "unknown"')

  if [[ "$version" == "unknown" ]]; then
    log_error "Could not determine Claude Code version"
    return 1
  fi

  # Parse version (expect 2.1.16+)
  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"

  if [[ $major -gt 2 ]] || [[ $major -eq 2 && $minor -ge 1 ]]; then
    log_success "Claude Code version: $version (≥2.1.16 required)"
    return 0
  else
    log_error "Claude Code version: $version (≥2.1.16 required)"
    return 1
  fi
}

# Test 2: Verify swarm gate is patched
test_swarm_gate_patched() {
  log_info "Testing swarm gate patch status..."

  local cli_path="$HOME/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/cli.js"

  if [[ ! -f "$cli_path" ]]; then
    log_error "CLI not found at $cli_path"
    return 1
  fi

  local gate_count
  gate_count=$(grep -c "tengu_brass_pebble" "$cli_path" 2>/dev/null || echo "0")

  if [[ "$gate_count" -eq 0 ]]; then
    log_success "Swarm gate patched (tengu_brass_pebble not found)"
    return 0
  else
    log_error "Swarm gate NOT patched (found $gate_count occurrences)"
    return 1
  fi
}

# Test 3: Verify TeammateTool availability
test_teammatetool_available() {
  log_info "Testing TeammateTool availability..."

  local cli_path="$HOME/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/cli.js"

  local tool_count
  tool_count=$(grep -c "TeammateTool" "$cli_path" 2>/dev/null || echo "0")

  if [[ "$tool_count" -gt 0 ]]; then
    log_success "TeammateTool available (found $tool_count references)"
    return 0
  else
    log_error "TeammateTool NOT found"
    return 1
  fi
}

# Test 4: Verify agent environment variables
test_agent_env_vars() {
  log_info "Testing agent environment variables..."

  local settings_path="$HOME/.claude-sneakpeek/zai/config/settings.json"

  if [[ ! -f "$settings_path" ]]; then
    log_error "Settings file not found at $settings_path"
    return 1
  fi

  local missing_vars=()

  # Check required variables
  local required_vars=(
    "CLAUDE_CODE_AGENT_ID"
    "CLAUDE_CODE_AGENT_NAME"
    "CLAUDE_CODE_TEAM_NAME"
  )

  for var in "${required_vars[@]}"; do
    if ! jq -e ".env.\"$var\"" "$settings_path" >/dev/null 2>&1; then
      missing_vars+=("$var")
    fi
  done

  if [[ ${#missing_vars[@]} -eq 0 ]]; then
    local agent_id agent_name team_name
    agent_id=$(jq -r '.env.CLAUDE_CODE_AGENT_ID' "$settings_path")
    agent_name=$(jq -r '.env.CLAUDE_CODE_AGENT_NAME' "$settings_path")
    team_name=$(jq -r '.env.CLAUDE_CODE_TEAM_NAME' "$settings_path")

    log_success "Agent environment variables configured:"
    echo "        - CLAUDE_CODE_AGENT_ID=$agent_id"
    echo "        - CLAUDE_CODE_AGENT_NAME=$agent_name"
    echo "        - CLAUDE_CODE_TEAM_NAME=$team_name"
    return 0
  else
    log_error "Missing agent environment variables: ${missing_vars[*]}"
    return 1
  fi
}

# Test 5: Verify defaultMode is delegate
test_default_mode_delegate() {
  log_info "Testing defaultMode setting..."

  local settings_path="$HOME/.claude-sneakpeek/zai/config/settings.json"

  local default_mode
  default_mode=$(jq -r '.permissions.defaultMode // "unknown"' "$settings_path")

  if [[ "$default_mode" == "delegate" ]]; then
    log_success "defaultMode is set to 'delegate' (required for swarm)"
    return 0
  else
    log_error "defaultMode is '$default_mode' (should be 'delegate')"
    return 1
  fi
}

# Test 6: Verify orchestrator command has swarm parameters
test_orchestrator_swarm_params() {
  log_info "Testing /orchestrator command for swarm parameters..."

  local orch_cmd="$HOME/Documents/GitHub/multi-agent-ralph-loop/.claude/commands/orchestrator.md"

  if [[ ! -f "$orch_cmd" ]]; then
    log_warning "Orchestrator command not found at $orch_cmd"
    return 1
  fi

  local missing_params=()

  # Check for swarm parameters
  grep -q "team_name:" "$orch_cmd" || missing_params+=("team_name")
  grep -q "mode: \"delegate\"" "$orch_cmd" || missing_params+=("mode: delegate")
  grep -q "launchSwarm:" "$orch_cmd" || missing_params+=("launchSwarm")
  grep -q "teammateCount:" "$orch_cmd" || missing_params+=("teammateCount")

  if [[ ${#missing_params[@]} -eq 0 ]]; then
    log_success "Orchestrator command has all swarm parameters"
    return 0
  else
    log_error "Orchestrator missing swarm parameters: ${missing_params[*]}"
    return 1
  fi
}

# Test 7: Verify loop command has swarm parameters
test_loop_swarm_params() {
  log_info "Testing /loop command for swarm parameters..."

  local loop_cmd="$HOME/Documents/GitHub/multi-agent-ralph-loop/.claude/commands/loop.md"

  if [[ ! -f "$loop_cmd" ]]; then
    log_warning "Loop command not found at $loop_cmd"
    return 1
  fi

  local missing_params=()

  # Check for swarm parameters
  grep -q "team_name:" "$loop_cmd" || missing_params+=("team_name")
  grep -q "mode: \"delegate\"" "$loop_cmd" || missing_params+=("mode: delegate")

  if [[ ${#missing_params[@]} -eq 0 ]]; then
    log_success "Loop command has all swarm parameters"
    return 0
  else
    log_error "Loop missing swarm parameters: ${missing_params[*]}"
    return 1
  fi
}

# Test 8: Verify GLM-4.7 as PRIMARY model
test_glm_primary() {
  log_info "Testing GLM-4.7 as PRIMARY model..."

  local settings_path="$HOME/.claude-sneakpeek/zai/config/settings.json"

  local model
  model=$(jq -r '.model // "unknown"' "$settings_path")

  if [[ "$model" == "glm-4.7" ]]; then
    log_success "GLM-4.7 is set as PRIMARY model"
    return 0
  else
    log_warning "Model is '$model' (expected 'glm-4.7' for v2.81)"
    return 1
  fi
}

# Main execution
main() {
  print_header

  # Run all tests
  test_claude_code_version
  test_swarm_gate_patched
  test_teammatetool_available
  test_agent_env_vars
  test_default_mode_delegate
  test_orchestrator_swarm_params
  test_loop_swarm_params
  test_glm_primary

  # Print summary
  echo ""
  echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}                         VALIDATION SUMMARY                      ${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "  ${GREEN}PASSED:${NC}   $PASSED"
  echo -e "  ${RED}FAILED:${NC}   $FAILED"
  echo -e "  ${YELLOW}WARNINGS:${NC} $WARNINGS"
  echo ""

  if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ Swarm mode is properly configured!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Test /orchestrator with a simple task"
    echo "  2. Verify teammates spawn during plan approval"
    echo "  3. Test /loop with swarm coordination"
    echo ""
    echo "Example:"
    echo "  /orchestrator \"create a simple hello world function\""
    echo ""
    return 0
  else
    echo -e "${RED}✗ Swarm mode configuration has issues${NC}"
    echo ""
    echo "Please review the failed tests above and fix the issues."
    echo ""
    return 1
  fi
}

# Run main
main "$@"
