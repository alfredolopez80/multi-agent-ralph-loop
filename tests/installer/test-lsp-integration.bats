#!/usr/bin/env bats
#===============================================================================
# test-lsp-integration.bats - Integration tests for LSP ecosystem
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Validate complete LSP integration (hooks → scripts → servers → skills)
#===============================================================================

load test_helper

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HOOK_SCRIPT="$PROJECT_ROOT/.claude/hooks/validate-lsp-servers.sh"
    INSTALL_SCRIPT="$PROJECT_ROOT/scripts/install-language-servers.sh"
    REAL_HOME=$(bash -c 'echo $HOME')
}

teardown() {
    :
}

#===============================================================================
# HOOK EXISTENCE TESTS
#===============================================================================

@test "validate-lsp-servers.sh hook exists" {
    [ -f "$HOOK_SCRIPT" ]
}

@test "validate-lsp-servers.sh hook is executable" {
    [ -x "$HOOK_SCRIPT" ]
}

@test "install-language-servers.sh script exists" {
    [ -f "$INSTALL_SCRIPT" ]
}

@test "install-language-servers.sh script is executable" {
    [ -x "$INSTALL_SCRIPT" ]
}

#===============================================================================
# HOOK OUTPUT MODE TESTS
#===============================================================================

@test "hook --help shows usage" {
    run "$HOOK_SCRIPT" --help
    [ $status -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "hook --json produces valid JSON" {
    run "$HOOK_SCRIPT" --json
    [ $status -eq 0 ]
    echo "$output" | jq empty
}

@test "hook --json has status field" {
    run "$HOOK_SCRIPT" --json
    local status=$(echo "$output" | jq -r '.status')
    [[ "$status" =~ ^(ok|degraded)$ ]]
}

@test "hook --json has servers object" {
    run "$HOOK_SCRIPT" --json
    echo "$output" | jq -e '.servers' > /dev/null
}

@test "hook --json includes typescript-language-server" {
    run "$HOOK_SCRIPT" --json
    echo "$output" | jq -e '.servers."typescript-language-server"' > /dev/null
}

@test "hook --json includes pyright" {
    run "$HOOK_SCRIPT" --json
    echo "$output" | jq -e '.servers.pyright' > /dev/null
}

@test "hook --json includes clangd" {
    run "$HOOK_SCRIPT" --json
    echo "$output" | jq -e '.servers.clangd' > /dev/null
}

#===============================================================================
# HOOK MODE TESTS
#===============================================================================

@test "hook --hook mode produces valid hook response" {
    run "$HOOK_SCRIPT" --hook
    # Should be valid JSON with continue field
    echo "$output" | jq -e '.continue' > /dev/null
}

@test "hook --hook mode returns continue:true when servers available" {
    run "$HOOK_SCRIPT" --hook
    local continue_val=$(echo "$output" | jq -r '.continue')
    [[ "$continue_val" == "true" ]]
}

#===============================================================================
# TEXT OUTPUT TESTS
#===============================================================================

@test "hook text mode shows essential servers" {
    run "$HOOK_SCRIPT"
    [[ "$output" == *"Essential Servers"* ]]
}

@test "hook text mode shows optional servers" {
    run "$HOOK_SCRIPT"
    [[ "$output" == *"Optional Servers"* ]]
}

@test "hook text mode shows summary" {
    run "$HOOK_SCRIPT"
    [[ "$output" == *"essential"* ]]
}

#===============================================================================
# ESSENTIAL SERVERS VALIDATION
#===============================================================================

@test "typescript-language-server is detected by hook" {
    run "$HOOK_SCRIPT" --json
    local status=$(echo "$output" | jq -r '.servers."typescript-language-server".status')
    [ "$status" == "available" ]
}

@test "pyright is detected by hook" {
    run "$HOOK_SCRIPT" --json
    local status=$(echo "$output" | jq -r '.servers.pyright.status')
    [ "$status" == "available" ]
}

@test "clangd is detected by hook" {
    run "$HOOK_SCRIPT" --json
    local status=$(echo "$output" | jq -r '.servers.clangd.status')
    [ "$status" == "available" ]
}

#===============================================================================
# SCRIPT-TO-HOOK INTEGRATION
#===============================================================================

@test "install script --check agrees with hook" {
    # Get hook status
    run "$HOOK_SCRIPT" --json
    local hook_status=$(echo "$output" | jq -r '.status')

    # Get install script status (use $status not $?)
    run "$INSTALL_SCRIPT" --check
    local install_exit=$status

    # Both should agree on essential servers being available
    if [ "$hook_status" == "ok" ]; then
        [ $install_exit -eq 0 ]
    fi
}

@test "hook calls correct install script path" {
    # Verify hook can find install script
    local hook_content=$(cat "$HOOK_SCRIPT")
    [[ "$hook_content" == *"install-language-servers.sh"* ]]
}

#===============================================================================
# LSP-EXPLORE SKILL INTEGRATION
#===============================================================================

@test "lsp-explore skill exists in global skills" {
    [ -f "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md" ]
}

@test "lsp-explore skill references allowed tools" {
    grep -q "allowed-tools:" "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md"
    grep -q "LSP" "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md"
}

@test "lsp-explore skill has hook configuration" {
    grep -q "hooks:" "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md"
}

@test "lsp-explore skill references supported languages" {
    grep -q "TypeScript" "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md"
    grep -q "Python" "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md"
}

#===============================================================================
# PLUGIN-TO-SERVER MAPPING
#===============================================================================

@test "typescript-lsp plugin is installed" {
    [ -f "$REAL_HOME/.claude/plugins/cache/claude-plugins-official/typescript-lsp/1.0.0/README.md" ]
}

@test "pyright-lsp plugin is installed" {
    [ -f "$REAL_HOME/.claude/plugins/cache/claude-plugins-official/pyright-lsp/1.0.0/README.md" ]
}

@test "clangd-lsp plugin is installed" {
    [ -f "$REAL_HOME/.claude/plugins/cache/claude-plugins-official/clangd-lsp/1.0.0/README.md" ]
}

#===============================================================================
# END-TO-END VALIDATION
#===============================================================================

@test "full LSP ecosystem is functional" {
    # 1. Hook validates successfully
    run "$HOOK_SCRIPT" --hook
    [ $status -eq 0 ]

    # 2. Install script agrees
    run "$INSTALL_SCRIPT" --check
    [ $status -eq 0 ]

    # 3. Skill exists
    [ -f "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md" ]

    # 4. Servers are available
    command -v typescript-language-server >/dev/null 2>&1
    command -v pyright >/dev/null 2>&1
    command -v clangd >/dev/null 2>&1
}

@test "at least 3 essential servers pass validation" {
    local count=0
    for server in typescript-language-server pyright clangd; do
        if command -v "$server" >/dev/null 2>&1; then
            ((count++)) || true
        fi
    done
    [ $count -ge 3 ]
}

@test "hook exit code reflects server availability" {
    run "$HOOK_SCRIPT"
    # Exit 0 = all essential available
    # Exit 1+ = some missing
    if command -v typescript-language-server >/dev/null 2>&1 && \
       command -v pyright >/dev/null 2>&1 && \
       command -v clangd >/dev/null 2>&1; then
        [ $status -eq 0 ]
    fi
}

#===============================================================================
# ERROR HANDLING TESTS
#===============================================================================

@test "hook handles missing servers gracefully" {
    # Even if some optional servers are missing, hook should work
    run "$HOOK_SCRIPT" --json
    [ $status -eq 0 ]
    echo "$output" | jq -e '.servers' > /dev/null
}

@test "hook produces valid JSON even with partial installation" {
    run "$HOOK_SCRIPT" --json
    # Must be valid JSON regardless of server status
    echo "$output" | jq empty
}
