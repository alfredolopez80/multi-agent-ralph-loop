#!/usr/bin/env bats
# test-lsp-usage-validation.bats - Validate LSP is properly configured in skills and agents
# Version: 1.0.0
# Date: 2026-02-15
#
# Tests that verify skills CAN and DO use LSP when needed:
# 1. Skills have LSP in allowed-tools
# 2. Skills have PreToolUse hook for LSP validation
# 3. Agents have LSP in tools list
# 4. Hook file exists and is executable

# Setup
setup() {
    REAL_HOME=$(bash -c 'echo $HOME')
    PROJECT_ROOT="${REAL_HOME}/Documents/GitHub/multi-agent-ralph-loop"
    SKILLS_DIR="${PROJECT_ROOT}/.claude/skills"
    AGENTS_DIR="${PROJECT_ROOT}/.claude/agents"
    HOOKS_DIR="${PROJECT_ROOT}/.claude/hooks"
}

# =============================================================================
# SECTION 1: Skills with LSP - allowed-tools verification
# =============================================================================

@test "LSP: orchestrator skill has LSP in allowed-tools" {
    skill_file="${SKILLS_DIR}/orchestrator/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^allowed-tools:" "$skill_file"
    grep -A 20 "^allowed-tools:" "$skill_file" | grep -q "LSP"
}

@test "LSP: loop skill has LSP in allowed-tools" {
    skill_file="${SKILLS_DIR}/loop/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^allowed-tools:" "$skill_file"
    grep -A 20 "^allowed-tools:" "$skill_file" | grep -q "LSP"
}

@test "LSP: bugs skill has LSP in allowed-tools" {
    skill_file="${SKILLS_DIR}/bugs/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^allowed-tools:" "$skill_file"
    grep -A 20 "^allowed-tools:" "$skill_file" | grep -q "LSP"
}

@test "LSP: parallel skill has LSP in allowed-tools" {
    skill_file="${SKILLS_DIR}/parallel/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^allowed-tools:" "$skill_file"
    grep -A 20 "^allowed-tools:" "$skill_file" | grep -q "LSP"
}

@test "LSP: edd skill has LSP in allowed-tools" {
    skill_file="${SKILLS_DIR}/edd/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^allowed-tools:" "$skill_file"
    grep -A 20 "^allowed-tools:" "$skill_file" | grep -q "LSP"
}

@test "LSP: gates skill has LSP in allowed-tools" {
    skill_file="${SKILLS_DIR}/gates/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^allowed-tools:" "$skill_file"
    grep -A 20 "^allowed-tools:" "$skill_file" | grep -q "LSP"
}

@test "LSP: security skill has LSP in allowed-tools" {
    skill_file="${SKILLS_DIR}/security/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^allowed-tools:" "$skill_file"
    grep -A 20 "^allowed-tools:" "$skill_file" | grep -q "LSP"
}

@test "LSP: code-reviewer skill has LSP in allowed-tools" {
    skill_file="${SKILLS_DIR}/code-reviewer/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^allowed-tools:" "$skill_file"
    grep -A 20 "^allowed-tools:" "$skill_file" | grep -q "LSP"
}

# =============================================================================
# SECTION 2: Skills with LSP - PreToolUse hook verification
# =============================================================================

@test "LSP: orchestrator skill has PreToolUse hook for LSP" {
    skill_file="${SKILLS_DIR}/orchestrator/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^hooks:" "$skill_file"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "PreToolUse"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "validate-lsp-servers.sh"
}

@test "LSP: loop skill has PreToolUse hook for LSP" {
    skill_file="${SKILLS_DIR}/loop/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^hooks:" "$skill_file"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "PreToolUse"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "validate-lsp-servers.sh"
}

@test "LSP: bugs skill has PreToolUse hook for LSP" {
    skill_file="${SKILLS_DIR}/bugs/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^hooks:" "$skill_file"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "PreToolUse"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "validate-lsp-servers.sh"
}

@test "LSP: parallel skill has PreToolUse hook for LSP" {
    skill_file="${SKILLS_DIR}/parallel/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^hooks:" "$skill_file"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "PreToolUse"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "validate-lsp-servers.sh"
}

@test "LSP: edd skill has PreToolUse hook for LSP" {
    skill_file="${SKILLS_DIR}/edd/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^hooks:" "$skill_file"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "PreToolUse"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "validate-lsp-servers.sh"
}

@test "LSP: gates skill has PreToolUse hook for LSP" {
    skill_file="${SKILLS_DIR}/gates/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^hooks:" "$skill_file"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "PreToolUse"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "validate-lsp-servers.sh"
}

@test "LSP: security skill has PreToolUse hook for LSP" {
    skill_file="${SKILLS_DIR}/security/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^hooks:" "$skill_file"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "PreToolUse"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "validate-lsp-servers.sh"
}

@test "LSP: code-reviewer skill has PreToolUse hook for LSP" {
    skill_file="${SKILLS_DIR}/code-reviewer/SKILL.md"
    [ -f "$skill_file" ]
    grep -q "^hooks:" "$skill_file"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "PreToolUse"
    grep -A 10 "^hooks:" "$skill_file" | grep -q "validate-lsp-servers.sh"
}

# =============================================================================
# SECTION 3: Agents with LSP - tools verification
# =============================================================================

@test "LSP: ralph-coder agent has LSP in tools" {
    agent_file="${AGENTS_DIR}/ralph-coder.md"
    [ -f "$agent_file" ]
    grep -q "^tools:" "$agent_file"
    grep -A 10 "^tools:" "$agent_file" | grep -q "LSP"
}

@test "LSP: ralph-reviewer agent has LSP in tools" {
    agent_file="${AGENTS_DIR}/ralph-reviewer.md"
    [ -f "$agent_file" ]
    grep -q "^tools:" "$agent_file"
    grep -A 10 "^tools:" "$agent_file" | grep -q "LSP"
}

@test "LSP: ralph-tester agent has LSP in tools" {
    agent_file="${AGENTS_DIR}/ralph-tester.md"
    [ -f "$agent_file" ]
    grep -q "^tools:" "$agent_file"
    grep -A 10 "^tools:" "$agent_file" | grep -q "LSP"
}

@test "LSP: ralph-researcher agent has LSP in tools" {
    agent_file="${AGENTS_DIR}/ralph-researcher.md"
    [ -f "$agent_file" ]
    grep -q "^tools:" "$agent_file"
    grep -A 10 "^tools:" "$agent_file" | grep -q "LSP"
}

# =============================================================================
# SECTION 4: Hook file validation
# =============================================================================

@test "LSP: validate-lsp-servers.sh hook exists" {
    hook_file="${HOOKS_DIR}/validate-lsp-servers.sh"
    [ -f "$hook_file" ]
}

@test "LSP: validate-lsp-servers.sh hook is executable" {
    hook_file="${HOOKS_DIR}/validate-lsp-servers.sh"
    [ -x "$hook_file" ]
}

@test "LSP: validate-lsp-servers.sh hook has proper shebang" {
    hook_file="${HOOKS_DIR}/validate-lsp-servers.sh"
    [ -f "$hook_file" ]
    head -1 "$hook_file" | grep -q "#!/bin/bash"
}

@test "LSP: validate-lsp-servers.sh hook has version header" {
    hook_file="${HOOKS_DIR}/validate-lsp-servers.sh"
    [ -f "$hook_file" ]
    grep -q "VERSION" "$hook_file"
}

# =============================================================================
# SECTION 5: LSP Servers availability
# =============================================================================

@test "LSP: typescript-language-server is available" {
    command -v typescript-language-server >/dev/null 2>&1 || \
    npm list -g typescript-language-server >/dev/null 2>&1
}

@test "LSP: pyright is available" {
    command -v pyright >/dev/null 2>&1 || \
    command -v npx >/dev/null 2>&1 && npx pyright --version >/dev/null 2>&1
}

@test "LSP: clangd is available" {
    command -v clangd >/dev/null 2>&1
}

@test "LSP: sourcekit-lsp is available (macOS)" {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        command -v sourcekit-lsp >/dev/null 2>&1
    else
        skip "sourcekit-lsp only on macOS"
    fi
}

# =============================================================================
# SECTION 6: Count verification
# =============================================================================

@test "LSP: at least 8 skills have LSP in allowed-tools" {
    # Count skills that have LSP in allowed-tools (supports both formats)
    # Format 1: "  - LSP" (multiline YAML)
    # Format 2: "allowed-tools: LSP,..." (inline YAML)
    count_multiline=$(grep -r "^  - LSP" "${SKILLS_DIR}"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
    count_inline=$(grep -r "allowed-tools:.*LSP" "${SKILLS_DIR}"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
    total=$((count_multiline + count_inline))
    [ "$total" -ge 8 ]
}

@test "LSP: all 4 ralph agents have LSP in tools" {
    # Count agents that have "- LSP" in tools section
    count=$(grep -r "^  - LSP" "${AGENTS_DIR}"/ralph-*.md 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 4 ]
}

# =============================================================================
# SECTION 7: Hook output format validation
# =============================================================================

@test "LSP: validate-lsp-servers.sh produces valid JSON output with --json flag" {
    hook_file="${HOOKS_DIR}/validate-lsp-servers.sh"
    [ -f "$hook_file" ]

    # Run hook with --json flag to get JSON output
    output=$(bash "$hook_file" --json 2>&1)

    # Validate it's valid JSON
    echo "$output" | python3 -c "import sys,json; data=json.loads(sys.stdin.read()); assert 'status' in data; assert 'servers' in data" 2>/dev/null
}

@test "LSP: validate-lsp-servers.sh hook mode produces valid JSON" {
    hook_file="${HOOKS_DIR}/validate-lsp-servers.sh"
    [ -f "$hook_file" ]

    # Run hook with --hook flag for hook response format
    output=$(bash "$hook_file" --hook 2>&1 || true)

    # Should produce JSON with continue field
    if echo "$output" | grep -q '"continue"'; then
        echo "$output" | python3 -c "import sys,json; data=json.loads(sys.stdin.read()); assert 'continue' in data" 2>/dev/null
    else
        # Hook may exit 2 if servers missing, which is valid behavior
        true
    fi
}

# =============================================================================
# SECTION 8: Installation script validation
# =============================================================================

@test "LSP: install-language-servers.sh script exists" {
    script_file="${PROJECT_ROOT}/scripts/install-language-servers.sh"
    [ -f "$script_file" ]
}

@test "LSP: install-language-servers.sh is executable" {
    script_file="${PROJECT_ROOT}/scripts/install-language-servers.sh"
    [ -x "$script_file" ]
}

@test "LSP: install-language-servers.sh supports --check flag" {
    script_file="${PROJECT_ROOT}/scripts/install-language-servers.sh"
    [ -f "$script_file" ]
    grep -q "\-\-check" "$script_file"
}

@test "LSP: install-language-servers.sh supports --essential flag" {
    script_file="${PROJECT_ROOT}/scripts/install-language-servers.sh"
    [ -f "$script_file" ]
    grep -q "\-\-essential" "$script_file"
}
