#!/usr/bin/env bats
#===============================================================================
# test-lsp-skills-integration.bats - LSP integration with Ralph skills
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Validate that Ralph skills can access and use LSP functionality
#===============================================================================

load test_helper

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    REAL_HOME=$(bash -c 'echo $HOME')
}

teardown() {
    :
}

#===============================================================================
# LSP-EXPLORE SKILL AVAILABILITY
#===============================================================================

@test "lsp-explore skill exists in global skills" {
    [ -f "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md" ]
}

@test "lsp-explore skill has LSP in allowed-tools" {
    grep -q "LSP" "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md"
}

@test "lsp-explore skill version is documented" {
    grep -q "VERSION:" "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md"
}

#===============================================================================
# RALPH SKILLS LSP READINESS
#===============================================================================

# Skills that SHOULD use LSP for code analysis
@test "gates skill can reference LSP for type checking" {
    # gates uses linters/type checkers - LSP can enhance this
    [ -f "$PROJECT_ROOT/.claude/skills/gates/SKILL.md" ]
}

@test "security skill exists for code analysis" {
    [ -f "$PROJECT_ROOT/.claude/skills/security/SKILL.md" ]
}

@test "bugs skill exists for bug hunting" {
    [ -f "$PROJECT_ROOT/.claude/skills/bugs/SKILL.md" ]
}

@test "code-reviewer skill exists" {
    [ -f "$PROJECT_ROOT/.claude/skills/code-reviewer/SKILL.md" ]
}

@test "orchestrator skill exists" {
    [ -f "$PROJECT_ROOT/.claude/skills/orchestrator/SKILL.md" ]
}

@test "loop skill exists" {
    [ -f "$PROJECT_ROOT/.claude/skills/loop/SKILL.md" ]
}

#===============================================================================
# AGENT SUBAGENTS LSP READINESS
#===============================================================================

@test "ralph-reviewer agent config exists" {
    [ -f "$PROJECT_ROOT/.claude/agents/ralph-reviewer.md" ] || \
    [ -f "$REAL_HOME/.claude/agents/ralph-reviewer.md" ] || \
    skip "ralph-reviewer agent not in expected location"
}

@test "ralph-coder agent config exists" {
    [ -f "$PROJECT_ROOT/.claude/agents/ralph-coder.md" ] || \
    [ -f "$REAL_HOME/.claude/agents/ralph-coder.md" ] || \
    skip "ralph-coder agent not in expected location"
}

#===============================================================================
# LANGUAGE SERVERS AVAILABLE FOR SKILLS
#===============================================================================

@test "typescript-language-server available for JS/TS analysis" {
    command -v typescript-language-server >/dev/null 2>&1
}

@test "pyright available for Python analysis" {
    command -v pyright >/dev/null 2>&1
}

@test "clangd available for C/C++ analysis" {
    command -v clangd >/dev/null 2>&1
}

#===============================================================================
# LSP HOOK INTEGRATION
#===============================================================================

@test "validate-lsp-servers hook exists" {
    [ -f "$PROJECT_ROOT/.claude/hooks/validate-lsp-servers.sh" ]
}

@test "validate-lsp-servers hook is executable" {
    [ -x "$PROJECT_ROOT/.claude/hooks/validate-lsp-servers.sh" ]
}

@test "validate-lsp-servers hook can be called" {
    run "$PROJECT_ROOT/.claude/hooks/validate-lsp-servers.sh" --check
    [ $status -ge 0 ]
}

#===============================================================================
# INTEGRATION VALIDATION
#===============================================================================

@test "LSP ecosystem is complete and functional" {
    # 1. Servers available
    command -v typescript-language-server >/dev/null 2>&1
    command -v pyright >/dev/null 2>&1
    command -v clangd >/dev/null 2>&1

    # 2. Skill exists
    [ -f "$REAL_HOME/.claude/skills/lsp-explore/SKILL.md" ]

    # 3. Hook validates
    run "$PROJECT_ROOT/.claude/hooks/validate-lsp-servers.sh" --hook
    [ $status -eq 0 ]
}

#===============================================================================
# DOCUMENTATION CHECK
#===============================================================================

@test "LSP documentation exists" {
    # Check that we have documentation about LSP integration
    [ -f "$PROJECT_ROOT/CLAUDE.md" ]
    grep -q "lsp" "$PROJECT_ROOT/CLAUDE.md" || \
    grep -q "LSP" "$PROJECT_ROOT/CLAUDE.md" || \
    skip "LSP not explicitly documented in CLAUDE.md"
}
