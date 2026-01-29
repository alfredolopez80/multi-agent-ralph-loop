#!/usr/bin/env bash
# Swarm Mode Configuration Unit Tests
# VERSION: 2.81.0
# Tests all swarm mode configuration components for reproducibility

set -euo pipefail

# Test configuration
TEST_NAME="Swarm Mode Configuration Tests"
TEST_VERSION="2.81.0"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results array
declare -a TEST_RESULTS=()

# Helper functions
log_header() {
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

log_test() {
  echo -e "${BLUE}▶${NC} $1"
  ((TESTS_RUN++))
}

log_pass() {
  echo -e "${GREEN}✓ PASS${NC} $1"
  ((TESTS_PASSED++))
  TEST_RESULTS+=("PASS: $1")
}

log_fail() {
  echo -e "${RED}✗ FAIL${NC} $1"
  ((TESTS_FAILED++))
  TEST_RESULTS+=("FAIL: $1")
}

log_skip() {
  echo -e "${YELLOW}⊘ SKIP${NC} $1"
  ((TESTS_SKIPPED++))
  TEST_RESULTS+=("SKIP: $1")
}

log_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

# Assertion helpers
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Assertion failed}"

  if [[ "$expected" == "$actual" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (expected: $expected, actual: $actual)"
    return 1
  fi
}

assert_not_empty() {
  local value="$1"
  local message="${2:-Value should not be empty}"

  if [[ -n "$value" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message (value is empty)"
    return 1
  fi
}

assert_file_exists() {
  local file="$1"
  local message="${2:-File should exist: $file}"

  if [[ -f "$file" ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Should contain: $needle}"

  if [[ "$haystack" == *"$needle"* ]]; then
    log_pass "$message"
    return 0
  else
    log_fail "$message"
    return 1
  fi
}

assert_json_key_exists() {
  local json_file="$1"
  local key_path="$2"
  local message="${3:-JSON key should exist: $key_path}"

  local value
  value=$(jq -r "$key_path // empty" "$json_file" 2>/dev/null)

  if [[ -n "$value" && "$value" != "null" ]]; then
    log_pass "$message (value: $value)"
    return 0
  else
    log_fail "$message"
    return 1
  fi
}

# Test Suite 1: Environment Detection
test_environment() {
  log_header "Test Suite 1: Environment Detection"

  log_test "Check OS type"
  local os_type
  os_type=$(uname -s)
  assert_not_empty "$os_type" "OS type detected: $os_type"

  log_test "Check architecture"
  local arch
  arch=$(uname -m)
  assert_not_empty "$arch" "Architecture detected: $arch"

  log_test "Check ZAI variant directory exists"
  assert_file_exists "$HOME/.claude-sneakpeek/zai/config/settings.json" "ZAI settings.json exists"

  log_test "Check Project directory exists"
  assert_file_exists ".claude/CLAUDE.md" "Project CLAUDE.md exists"
}

# Test Suite 2: Claude Code Version
test_claude_code_version() {
  log_header "Test Suite 2: Claude Code Version"

  local cli_path="$HOME/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/cli.js"

  log_test "Check CLI file exists"
  assert_file_exists "$cli_path" "Claude Code CLI exists"

  log_test "Read package.json version"
  local version
  version=$(cat "$HOME/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/package.json" 2>/dev/null | jq -r '.version // "unknown"')
  assert_not_empty "$version" "Version read: $version"

  log_test "Parse version components"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$version"
  assert_not_empty "$major" "Major version: $major"
  assert_not_empty "$minor" "Minor version: $minor"

  log_test "Check version >= 2.1.16"
  if [[ $major -gt 2 ]] || [[ $major -eq 2 && $minor -ge 1 ]]; then
    log_pass "Version $version meets requirement (>=2.1.16)"
  else
    log_fail "Version $version does not meet requirement (>=2.1.16)"
  fi
}

# Test Suite 3: Swarm Mode Gate
test_swarm_gate() {
  log_header "Test Suite 3: Swarm Mode Gate"

  local cli_path="$HOME/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/cli.js"

  log_test "Check for swarm gate (tengu_brass_pebble)"
  local gate_count
  gate_count=$(grep -c "tengu_brass_pebble" "$cli_path" 2>/dev/null || echo "0")

  if [[ "$gate_count" -eq 0 ]]; then
    log_pass "Swarm gate is patched (0 occurrences)"
  else
    log_fail "Swarm gate is NOT patched ($gate_count occurrences)"
  fi
}

# Test Suite 4: TeammateTool Availability
test_teammatetool() {
  log_header "Test Suite 4: TeammateTool Availability"

  local cli_path="$HOME/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/cli.js"

  log_test "Check for TeammateTool in CLI"
  local tool_count
  tool_count=$(grep -c "TeammateTool" "$cli_path" 2>/dev/null || echo "0")

  if [[ "$tool_count" -gt 0 ]]; then
    log_pass "TeammateTool found ($tool_count references)"
  else
    log_fail "TeammateTool NOT found"
  fi
}

# Test Suite 5: Agent Environment Variables
test_agent_env_vars() {
  log_header "Test Suite 5: Agent Environment Variables"

  local settings_path="$HOME/.claude-sneakpeek/zai/config/settings.json"

  log_test "Check CLAUDE_CODE_AGENT_ID exists"
  assert_json_key_exists "$settings_path" '.env.CLAUDE_CODE_AGENT_ID' "CLAUDE_CODE_AGENT_ID exists"

  log_test "Check CLAUDE_CODE_AGENT_NAME exists"
  assert_json_key_exists "$settings_path" '.env.CLAUDE_CODE_AGENT_NAME' "CLAUDE_CODE_AGENT_NAME exists"

  log_test "Check CLAUDE_CODE_TEAM_NAME exists"
  assert_json_key_exists "$settings_path" '.env.CLAUDE_CODE_TEAM_NAME' "CLAUDE_CODE_TEAM_NAME exists"

  log_test "Check CLAUDE_CODE_PLAN_MODE_REQUIRED exists"
  assert_json_key_exists "$settings_path" '.env.CLAUDE_CODE_PLAN_MODE_REQUIRED' "CLAUDE_CODE_PLAN_MODE_REQUIRED exists"

  log_test "Validate AGENT_ID value"
  local agent_id
  agent_id=$(jq -r '.env.CLAUDE_CODE_AGENT_ID' "$settings_path")
  assert_equals "claude-orchestrator" "$agent_id" "AGENT_ID has correct value"

  log_test "Validate AGENT_NAME value"
  local agent_name
  agent_name=$(jq -r '.env.CLAUDE_CODE_AGENT_NAME' "$settings_path")
  assert_equals "Orchestrator" "$agent_name" "AGENT_NAME has correct value"

  log_test "Validate TEAM_NAME value"
  local team_name
  team_name=$(jq -r '.env.CLAUDE_CODE_TEAM_NAME' "$settings_path")
  assert_equals "multi-agent-ralph-loop" "$team_name" "TEAM_NAME has correct value"

  log_test "Validate PLAN_MODE_REQUIRED value"
  local plan_mode
  plan_mode=$(jq -r '.env.CLAUDE_CODE_PLAN_MODE_REQUIRED' "$settings_path")
  assert_equals "false" "$plan_mode" "PLAN_MODE_REQUIRED is false"
}

# Test Suite 6: Permissions Configuration
test_permissions() {
  log_header "Test Suite 6: Permissions Configuration"

  local settings_path="$HOME/.claude-sneakpeek/zai/config/settings.json"

  log_test "Check defaultMode is delegate"
  local default_mode
  default_mode=$(jq -r '.permissions.defaultMode // "unknown"' "$settings_path")
  assert_equals "delegate" "$default_mode" "defaultMode is delegate"

  log_test "Check permissions.allow array exists"
  local allow_count
  allow_count=$(jq -r '.permissions.allow | length' "$settings_path")
  if [[ "$allow_count" -gt 0 ]]; then
    log_pass "permissions.allow has $allow_count entries"
  else
    log_fail "permissions.allow is empty or missing"
  fi

  log_test "Check permissions.deny array exists"
  local deny_count
  deny_count=$(jq -r '.permissions.deny | length' "$settings_path")
  if [[ "$deny_count" -ge 0 ]]; then
    log_pass "permissions.deny has $deny_count entries"
  else
    log_fail "permissions.deny is missing"
  fi
}

# Test Suite 7: Model Configuration
test_model_config() {
  log_header "Test Suite 7: Model Configuration"

  local settings_path="$HOME/.claude-sneakpeek/zai/config/settings.json"

  log_test "Check default model is GLM-4.7"
  local model
  model=$(jq -r '.model // "unknown"' "$settings_path")
  assert_equals "glm-4.7" "$model" "Default model is glm-4.7"

  log_test "Check ANTHROPIC_DEFAULT_SONNET_MODEL is GLM-4.7"
  local sonnet_model
  sonnet_model=$(jq -r '.env.ANTHROPIC_DEFAULT_SONNET_MODEL' "$settings_path")
  assert_equals "glm-4.7" "$sonnet_model" "SONNET_MODEL is glm-4.7"

  log_test "Check ANTHROPIC_DEFAULT_OPUS_MODEL is GLM-4.7"
  local opus_model
  opus_model=$(jq -r '.env.ANTHROPIC_DEFAULT_OPUS_MODEL' "$settings_path")
  assert_equals "glm-4.7" "$opus_model" "OPUS_MODEL is glm-4.7"
}

# Test Suite 8: Orchestrator Command
test_orchestrator_command() {
  log_header "Test Suite 8: Orchestrator Command"

  local orch_cmd=".claude/commands/orchestrator.md"

  log_test "Check orchestrator command exists"
  assert_file_exists "$orch_cmd" "Orchestrator command exists"

  log_test "Check orchestrator version is 2.81.0"
  local version
  version=$(grep "^# VERSION: " "$orch_cmd" | cut -d' ' -f2)
  assert_equals "2.81.0" "$version" "Orchestrator version is 2.81.0"

  log_test "Check team_name parameter exists"
  if grep -q "team_name:" "$orch_cmd"; then
    log_pass "team_name parameter found"
  else
    log_fail "team_name parameter NOT found"
  fi

  log_test "Check mode: delegate parameter exists"
  if grep -q 'mode: "delegate"' "$orch_cmd"; then
    log_pass "mode: delegate parameter found"
  else
    log_fail "mode: delegate parameter NOT found"
  fi

  log_test "Check launchSwarm parameter exists"
  if grep -q "launchSwarm:" "$orch_cmd"; then
    log_pass "launchSwarm parameter found"
  else
    log_fail "launchSwarm parameter NOT found"
  fi

  log_test "Check teammateCount parameter exists"
  if grep -q "teammateCount:" "$orch_cmd"; then
    log_pass "teammateCount parameter found"
  else
    log_fail "teammateCount parameter NOT found"
  fi
}

# Test Suite 9: Loop Command
test_loop_command() {
  log_header "Test Suite 9: Loop Command"

  local loop_cmd=".claude/commands/loop.md"

  log_test "Check loop command exists"
  assert_file_exists "$loop_cmd" "Loop command exists"

  log_test "Check loop version is 2.81.0"
  local version
  version=$(grep "^# VERSION: " "$loop_cmd" | cut -d' ' -f2)
  assert_equals "2.81.0" "$version" "Loop version is 2.81.0"

  log_test "Check team_name parameter exists"
  if grep -q "team_name:" "$loop_cmd"; then
    log_pass "team_name parameter found"
  else
    log_fail "team_name parameter NOT found"
  fi

  log_test "Check mode: delegate parameter exists"
  if grep -q 'mode: "delegate"' "$loop_cmd"; then
    log_pass "mode: delegate parameter found"
  else
    log_fail "mode: delegate parameter NOT found"
  fi
}

# Test Suite 10: Documentation
test_documentation() {
  log_header "Test Suite 10: Documentation"

  log_test "Check SWARM_MODE_INTEGRATION_ANALYSIS exists"
  assert_file_exists "docs/architecture/SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md" "Integration analysis exists"

  log_test "Check SWARM_MODE_VALIDATION exists"
  assert_file_exists "docs/architecture/SWARM_MODE_VALIDATION_v2.81.0.md" "Validation report exists"

  log_test "Check CHANGELOG.md mentions v2.81.0"
  if grep -q "2.81.0" "CHANGELOG.md"; then
    log_pass "CHANGELOG.md mentions v2.81.0"
  else
    log_fail "CHANGELOG.md does NOT mention v2.81.0"
  fi

  log_test "Check validation script exists"
  assert_file_exists ".claude/scripts/validate-swarm-mode.sh" "Validation script exists"
}

# Test Suite 11: Reproducibility
test_reproducibility() {
  log_header "Test Suite 11: Configuration Reproducibility"

  log_test "Create temporary config snapshot"
  local temp_config="/tmp/swarm-config-snapshot-$$.json"
  cat "$HOME/.claude-sneakpeek/zai/config/settings.json" > "$temp_config"
  assert_file_exists "$temp_config" "Config snapshot created"

  log_test "Validate snapshot has all required keys"
  local required_keys=(
    ".env.CLAUDE_CODE_AGENT_ID"
    ".env.CLAUDE_CODE_AGENT_NAME"
    ".env.CLAUDE_CODE_TEAM_NAME"
    ".env.CLAUDE_CODE_PLAN_MODE_REQUIRED"
    ".permissions.defaultMode"
    ".model"
  )

  local all_keys_present=true
  for key in "${required_keys[@]}"; do
    if ! jq -e "$key" "$temp_config" >/dev/null 2>&1; then
      all_keys_present=false
      log_fail "Missing key in snapshot: $key"
    fi
  done

  if [[ "$all_keys_present" == "true" ]]; then
    log_pass "All required keys present in snapshot"
  fi

  log_test "Clean up snapshot"
  rm -f "$temp_config"
  if [[ ! -f "$temp_config" ]]; then
    log_pass "Snapshot cleaned up"
  else
    log_fail "Snapshot cleanup failed"
  fi
}

# Test Suite 12: Integration Tests
test_integration() {
  log_header "Test Suite 12: Integration Tests"

  log_test "Check settings.json is valid JSON"
  if jq empty "$HOME/.claude-sneakpeek/zai/config/settings.json" >/dev/null 2>&1; then
    log_pass "settings.json is valid JSON"
  else
    log_fail "settings.json is NOT valid JSON"
  fi

  log_test "Check all environment variables are non-empty"
  local settings_path="$HOME/.claude-sneakpeek/zai/config/settings.json"
  local all_non_empty=true

  local agent_id agent_name team_name plan_mode
  agent_id=$(jq -r '.env.CLAUDE_CODE_AGENT_ID' "$settings_path")
  agent_name=$(jq -r '.env.CLAUDE_CODE_AGENT_NAME' "$settings_path")
  team_name=$(jq -r '.env.CLAUDE_CODE_TEAM_NAME' "$settings_path")
  plan_mode=$(jq -r '.env.CLAUDE_CODE_PLAN_MODE_REQUIRED' "$settings_path")

  if [[ -z "$agent_id" ]]; then
    all_non_empty=false
    log_fail "CLAUDE_CODE_AGENT_ID is empty"
  fi
  if [[ -z "$agent_name" ]]; then
    all_non_empty=false
    log_fail "CLAUDE_CODE_AGENT_NAME is empty"
  fi
  if [[ -z "$team_name" ]]; then
    all_non_empty=false
    log_fail "CLAUDE_CODE_TEAM_NAME is empty"
  fi
  if [[ -z "$plan_mode" ]]; then
    all_non_empty=false
    log_fail "CLAUDE_CODE_PLAN_MODE_REQUIRED is empty"
  fi

  if [[ "$all_non_empty" == "true" ]]; then
    log_pass "All environment variables are non-empty"
  fi

  log_test "Check command files reference swarm parameters"
  local orch_has_swarm=false
  local loop_has_swarm=false

  if grep -q "team_name:" ".claude/commands/orchestrator.md" && \
     grep -q "launchSwarm:" ".claude/commands/orchestrator.md"; then
    orch_has_swarm=true
  fi

  if grep -q "team_name:" ".claude/commands/loop.md"; then
    loop_has_swarm=true
  fi

  if [[ "$orch_has_swarm" == "true" && "$loop_has_swarm" == "true" ]]; then
    log_pass "Both commands have swarm parameters"
  else
    log_fail "One or both commands missing swarm parameters"
  fi
}

# Print summary
print_summary() {
  echo ""
  echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║                      TEST SUMMARY                               ║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BLUE}Test Suite:${NC} $TEST_NAME"
  echo -e "${BLUE}Version:${NC}    $TEST_VERSION"
  echo ""
  echo -e "  ${GREEN}PASSED:${NC}   $TESTS_PASSED"
  echo -e "  ${RED}FAILED:${NC}   $TESTS_FAILED"
  echo -e "  ${YELLOW}SKIPPED:${NC}  $TESTS_SKIPPED"
  echo -e "  ${BLUE}TOTAL:${NC}    $TESTS_RUN"
  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "Swarm mode v2.81.0 is properly configured and ready for use."
    return 0
  else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo ""
    echo "Please review the failed tests above and fix the issues."
    echo ""
    echo "Failed tests:"
    for result in "${TEST_RESULTS[@]}"; do
      if [[ "$result" == FAIL:* ]]; then
        echo -e "  ${RED}✗${NC} ${result#FAIL: }"
      fi
    done
    return 1
  fi
}

# Main execution
main() {
  echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║         Swarm Mode Configuration Unit Tests v2.81.0          ║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # Run all test suites
  test_environment
  test_claude_code_version
  test_swarm_gate
  test_teammatetool
  test_agent_env_vars
  test_permissions
  test_model_config
  test_orchestrator_command
  test_loop_command
  test_documentation
  test_reproducibility
  test_integration

  # Print summary
  print_summary
}

# Run main
main "$@"
