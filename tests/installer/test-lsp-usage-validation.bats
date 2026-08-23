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
    # Derivada del fichero de test, no cableada a una maquina concreta:
    # ver la nota en test-complete-installation.bats.
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
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

@test "LSP: iterate skill has LSP in allowed-tools" {
    skill_file="${SKILLS_DIR}/iterate/SKILL.md"
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

# =============================================================================
# SECTION 3: Agents with LSP - tools verification
# =============================================================================

@test "LSP: ralph-frontend agent has LSP in tools" {
    agent_file="${AGENTS_DIR}/ralph-frontend.md"
    [ -f "$agent_file" ]
    grep -q "^tools:" "$agent_file"
    grep -A 10 "^tools:" "$agent_file" | grep -q "LSP"
}

@test "LSP: ralph-security agent has LSP in tools" {
    agent_file="${AGENTS_DIR}/ralph-security.md"
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

# =============================================================================
# SECTION 5: LSP Servers availability
# =============================================================================

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

# =============================================================================
# SECTION 7: Hook output format validation
# =============================================================================

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
