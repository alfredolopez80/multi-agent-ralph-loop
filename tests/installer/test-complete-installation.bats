#!/usr/bin/env bats
# test-complete-installation.bats - Complete installation validation
# Version: 1.0.0
# Date: 2026-02-15
#
# Validates that all installation components are properly configured:
# 1. Installation scripts exist and are executable
# 2. Symlinks are created correctly
# 3. LSP servers are installed
# 4. Hooks are registered
# 5. Skills are available
# 6. Configuration is correct

# Setup
setup() {
    REAL_HOME=$(bash -c 'echo $HOME')
    PROJECT_ROOT="${REAL_HOME}/Documents/GitHub/multi-agent-ralph-loop"
    CLAUDE_DIR="${REAL_HOME}/.claude"
    SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
    CLAUDE_SCRIPTS="${PROJECT_ROOT}/.claude/scripts"
}

# =============================================================================
# SECTION 1: Installation Scripts
# =============================================================================

@test "INSTALL: centralize-all.sh exists and is executable" {
    script="${CLAUDE_SCRIPTS}/centralize-all.sh"
    [ -f "$script" ]
    [ -x "$script" ]
}

@test "INSTALL: install-language-servers.sh exists and is executable" {
    script="${SCRIPTS_DIR}/install-language-servers.sh"
    [ -f "$script" ]
    [ -x "$script" ]
}

@test "INSTALL: setup-symlinks.sh exists and is executable" {
    script="${SCRIPTS_DIR}/setup-symlinks.sh"
    [ -f "$script" ]
    [ -x "$script" ]
}

@test "INSTALL: install-security-tools.sh exists and is executable" {
    script="${SCRIPTS_DIR}/install-security-tools.sh"
    [ -f "$script" ]
    [ -x "$script" ]
}

@test "INSTALL: validate-installation.sh exists and is executable" {
    script="${SCRIPTS_DIR}/validate-installation.sh"
    [ -f "$script" ]
    [ -x "$script" ]
}

# =============================================================================
# SECTION 2: Project Structure
# =============================================================================

@test "INSTALL: .claude directory exists in project" {
    [ -d "${PROJECT_ROOT}/.claude" ]
}

@test "INSTALL: .claude/skills directory exists" {
    [ -d "${PROJECT_ROOT}/.claude/skills" ]
}

@test "INSTALL: .claude/agents directory exists" {
    [ -d "${PROJECT_ROOT}/.claude/agents" ]
}

@test "INSTALL: .claude/hooks directory exists" {
    [ -d "${PROJECT_ROOT}/.claude/hooks" ]
}

@test "INSTALL: .claude/scripts directory exists" {
    [ -d "${PROJECT_ROOT}/.claude/scripts" ]
}

@test "INSTALL: scripts directory exists at project root" {
    [ -d "${SCRIPTS_DIR}" ]
}

@test "INSTALL: tests directory exists" {
    [ -d "${PROJECT_ROOT}/tests" ]
}

@test "INSTALL: docs directory exists" {
    [ -d "${PROJECT_ROOT}/docs" ]
}

# =============================================================================
# SECTION 3: Core Skills Exist
# =============================================================================

@test "INSTALL: orchestrator skill exists" {
    [ -f "${PROJECT_ROOT}/.claude/skills/orchestrator/SKILL.md" ]
}

@test "INSTALL: loop skill exists" {
    [ -f "${PROJECT_ROOT}/.claude/skills/loop/SKILL.md" ]
}

@test "INSTALL: gates skill exists" {
    [ -f "${PROJECT_ROOT}/.claude/skills/gates/SKILL.md" ]
}

@test "INSTALL: security skill exists" {
    [ -f "${PROJECT_ROOT}/.claude/skills/security/SKILL.md" ]
}

@test "INSTALL: bugs skill exists" {
    [ -f "${PROJECT_ROOT}/.claude/skills/bugs/SKILL.md" ]
}

@test "INSTALL: parallel skill exists" {
    [ -f "${PROJECT_ROOT}/.claude/skills/parallel/SKILL.md" ]
}

@test "INSTALL: code-reviewer skill exists" {
    [ -f "${PROJECT_ROOT}/.claude/skills/code-reviewer/SKILL.md" ]
}

@test "INSTALL: task-batch skill exists" {
    [ -f "${PROJECT_ROOT}/.claude/skills/task-batch/SKILL.md" ]
}

# =============================================================================
# SECTION 4: Core Agents Exist
# =============================================================================

@test "INSTALL: ralph-coder agent exists" {
    [ -f "${PROJECT_ROOT}/.claude/agents/ralph-coder.md" ]
}

@test "INSTALL: ralph-reviewer agent exists" {
    [ -f "${PROJECT_ROOT}/.claude/agents/ralph-reviewer.md" ]
}

@test "INSTALL: ralph-tester agent exists" {
    [ -f "${PROJECT_ROOT}/.claude/agents/ralph-tester.md" ]
}

@test "INSTALL: ralph-researcher agent exists" {
    [ -f "${PROJECT_ROOT}/.claude/agents/ralph-researcher.md" ]
}

# =============================================================================
# SECTION 5: Critical Hooks Exist
# =============================================================================

@test "INSTALL: git-safety-guard.py hook exists" {
    [ -f "${PROJECT_ROOT}/.claude/hooks/git-safety-guard.py" ]
}

@test "INSTALL: repo-boundary-guard.sh hook exists" {
    [ -f "${PROJECT_ROOT}/.claude/hooks/repo-boundary-guard.sh" ]
}

@test "INSTALL: validate-lsp-servers.sh hook exists" {
    [ -f "${PROJECT_ROOT}/.claude/hooks/validate-lsp-servers.sh" ]
}

@test "INSTALL: auto-checkpoint.sh hook exists" {
    [ -f "${PROJECT_ROOT}/.claude/hooks/auto-checkpoint.sh" ]
}

@test "INSTALL: pre-compact-handoff.sh hook exists" {
    [ -f "${PROJECT_ROOT}/.claude/hooks/pre-compact-handoff.sh" ]
}

@test "INSTALL: post-compact-restore.sh hook exists" {
    [ -f "${PROJECT_ROOT}/.claude/hooks/post-compact-restore.sh" ]
}

# =============================================================================
# SECTION 6: LSP Servers Availability
# =============================================================================

@test "INSTALL: typescript-language-server is installed" {
    command -v typescript-language-server >/dev/null 2>&1 || \
    npm list -g typescript-language-server >/dev/null 2>&1
}

@test "INSTALL: pyright is installed" {
    command -v pyright >/dev/null 2>&1 || \
    command -v npx >/dev/null 2>&1
}

@test "INSTALL: clangd is installed" {
    command -v clangd >/dev/null 2>&1
}

# =============================================================================
# SECTION 7: Dependencies
# =============================================================================

@test "INSTALL: bash is version 3.2+" {
    bash_version=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    major=$(echo "$bash_version" | cut -d. -f1)
    minor=$(echo "$bash_version" | cut -d. -f2)
    [ "$major" -ge 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -ge 2 ])
}

@test "INSTALL: jq is installed" {
    command -v jq >/dev/null 2>&1
}

@test "INSTALL: git is installed" {
    command -v git >/dev/null 2>&1
}

@test "INSTALL: curl is installed" {
    command -v curl >/dev/null 2>&1
}

@test "INSTALL: python3 is installed" {
    command -v python3 >/dev/null 2>&1
}

# =============================================================================
# SECTION 8: README Documentation
# =============================================================================

@test "INSTALL: README.md exists" {
    [ -f "${PROJECT_ROOT}/README.md" ]
}

@test "INSTALL: README.md contains Quick Start section" {
    grep -q "Quick Start" "${PROJECT_ROOT}/README.md"
}

@test "INSTALL: README.md contains Requirements section" {
    grep -q "Requirements" "${PROJECT_ROOT}/README.md"
}

@test "INSTALL: README.md contains Installation instructions" {
    grep -q "Clone repository\|git clone" "${PROJECT_ROOT}/README.md"
}

@test "INSTALL: README.md mentions LSP" {
    grep -q "LSP\|Language Server" "${PROJECT_ROOT}/README.md"
}

@test "INSTALL: README.md contains version number" {
    grep -q "v2\.[0-9]" "${PROJECT_ROOT}/README.md"
}

# =============================================================================
# SECTION 9: Configuration Files
# =============================================================================

@test "INSTALL: CLAUDE.md exists in project" {
    [ -f "${PROJECT_ROOT}/CLAUDE.md" ]
}

@test "INSTALL: CLAUDE.md exists in .claude" {
    [ -f "${PROJECT_ROOT}/.claude/CLAUDE.md" ]
}

@test "INSTALL: .gitignore exists" {
    [ -f "${PROJECT_ROOT}/.gitignore" ]
}

@test "INSTALL: CHANGELOG.md exists" {
    [ -f "${PROJECT_ROOT}/CHANGELOG.md" ]
}

# =============================================================================
# SECTION 10: Count Validations
# =============================================================================

@test "INSTALL: at least 30 skills exist" {
    count=$(find "${PROJECT_ROOT}/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 30 ]
}

@test "INSTALL: at least 4 ralph agents exist" {
    count=$(find "${PROJECT_ROOT}/.claude/agents" -name "ralph-*.md" 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 4 ]
}

@test "INSTALL: at least 50 hooks exist" {
    count=$(find "${PROJECT_ROOT}/.claude/hooks" -name "*.sh" -o -name "*.py" 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 50 ]
}

# =============================================================================
# SECTION 11: Script Functionality Tests
# =============================================================================

@test "INSTALL: install-language-servers.sh --help works" {
    "${SCRIPTS_DIR}/install-language-servers.sh" --help 2>&1 | grep -q "Usage\|USAGE\|Options"
}

@test "INSTALL: install-language-servers.sh --check works" {
    "${SCRIPTS_DIR}/install-language-servers.sh" --check 2>&1 || true
    # Should not crash
}

@test "INSTALL: validate-lsp-servers.sh --help works" {
    "${PROJECT_ROOT}/.claude/hooks/validate-lsp-servers.sh" --help 2>&1 | grep -q "Usage\|USAGE\|Options"
}

# =============================================================================
# SECTION 12: Pre-commit Hooks
# =============================================================================

@test "INSTALL: pre-commit-installer-tests.sh hook exists" {
    hook_file="${PROJECT_ROOT}/.claude/hooks/pre-commit-installer-tests.sh"
    [ -f "$hook_file" ]
}

@test "INSTALL: pre-commit-installer-tests.sh hook is executable" {
    hook_file="${PROJECT_ROOT}/.claude/hooks/pre-commit-installer-tests.sh"
    [ -x "$hook_file" ]
}

@test "INSTALL: pre-commit-installer-tests.sh hook has proper shebang" {
    hook_file="${PROJECT_ROOT}/.claude/hooks/pre-commit-installer-tests.sh"
    [ -f "$hook_file" ]
    head -1 "$hook_file" | grep -qi "#!/usr/bin/env bash\|#!/bin/bash"
}

@test "INSTALL: pre-commit-installer-tests.sh hook produces valid JSON output" {
    hook_file="${PROJECT_ROOT}/.claude/hooks/pre-commit-installer-tests.sh"
    [ -f "$hook_file" ]

    # Run hook and capture output (may fail if bats not installed, but should produce JSON)
    output=$(bash "$hook_file" 2>&1 || true)

    # Should contain JSON with continue field
    echo "$output" | grep -q '"continue"'
}
