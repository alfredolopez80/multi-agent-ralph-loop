#!/usr/bin/env bats
# test_v2.36_integration.bats - Integration tests for Multi-Agent Ralph v2.36
# Tests skills, agents, hooks, and CLI integration

load test_helper

# Setup
setup() {
    export GLOBAL_CLAUDE_DIR="${HOME}/.claude"
    export GLOBAL_SKILLS_DIR="${GLOBAL_CLAUDE_DIR}/skills"
    export GLOBAL_AGENTS_DIR="${GLOBAL_CLAUDE_DIR}/agents"
    export GLOBAL_HOOKS_DIR="${GLOBAL_CLAUDE_DIR}/hooks"
    export RALPH_DIR="${HOME}/.ralph"
}

# ============================================================================
# SKILLS MIGRATION TESTS
# ============================================================================

@test "v2.36: Global skills directory exists" {
    [ -d "$GLOBAL_SKILLS_DIR" ]
}

@test "v2.36: orchestrator skill exists" {
    [ -f "$GLOBAL_SKILLS_DIR/orchestrator/SKILL.md" ]
}

@test "v2.36: clarify skill exists" {
    [ -f "$GLOBAL_SKILLS_DIR/clarify/SKILL.md" ]
}

@test "v2.36: gates skill exists" {
    [ -f "$GLOBAL_SKILLS_DIR/gates/SKILL.md" ]
}

@test "v2.36: adversarial skill exists" {
    [ -f "$GLOBAL_SKILLS_DIR/adversarial/SKILL.md" ]
}

@test "v2.36: loop skill exists" {
    [ -f "$GLOBAL_SKILLS_DIR/loop/SKILL.md" ]
}

@test "v2.36: parallel skill exists" {
    [ -f "$GLOBAL_SKILLS_DIR/parallel/SKILL.md" ]
}

@test "v2.36: retrospective skill exists" {
    [ -f "$GLOBAL_SKILLS_DIR/retrospective/SKILL.md" ]
}

@test "v2.36: orchestrator skill has name in frontmatter" {
    grep -q "^name:" "$GLOBAL_SKILLS_DIR/orchestrator/SKILL.md"
}

@test "v2.36: orchestrator skill has description in frontmatter" {
    grep -q "^description:" "$GLOBAL_SKILLS_DIR/orchestrator/SKILL.md"
}

@test "v2.36: gates skill has context: fork" {
    grep -q "context:.*fork" "$GLOBAL_SKILLS_DIR/gates/SKILL.md"
}

@test "v2.36: adversarial skill has context: fork" {
    grep -q "context:.*fork" "$GLOBAL_SKILLS_DIR/adversarial/SKILL.md"
}

@test "v2.36: parallel skill has context: fork" {
    grep -q "context:.*fork" "$GLOBAL_SKILLS_DIR/parallel/SKILL.md"
}

@test "v2.36: Total skills count >= 100" {
    local count
    count=$(find "$GLOBAL_SKILLS_DIR" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 100 ]
}

# ============================================================================
# AGENT HOOKS TESTS
# ============================================================================

@test "v2.36: security-auditor agent exists" {
    [ -f "$GLOBAL_AGENTS_DIR/security-auditor.md" ]
}

@test "v2.36: security-auditor has hooks in frontmatter" {
    grep -q "^hooks:" "$GLOBAL_AGENTS_DIR/security-auditor.md"
}

@test "v2.36: security-auditor has PreToolUse hook" {
    grep -q "PreToolUse:" "$GLOBAL_AGENTS_DIR/security-auditor.md"
}

@test "v2.36: orchestrator agent has hooks" {
    grep -q "^hooks:" "$GLOBAL_AGENTS_DIR/orchestrator.md"
}

@test "v2.36: code-reviewer agent has hooks" {
    grep -q "^hooks:" "$GLOBAL_AGENTS_DIR/code-reviewer.md"
}

@test "v2.36: test-architect agent has hooks" {
    grep -q "^hooks:" "$GLOBAL_AGENTS_DIR/test-architect.md"
}

@test "v2.36: debugger agent has hooks" {
    grep -q "^hooks:" "$GLOBAL_AGENTS_DIR/debugger.md"
}

@test "v2.36: Total agents count >= 20" {
    local count
    count=$(find "$GLOBAL_AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 20 ]
}

# ============================================================================
# CONTEXT THRESHOLD TESTS
# ============================================================================

@test "v2.36: context-warning.sh hook exists" {
    [ -f "$GLOBAL_HOOKS_DIR/context-warning.sh" ]
}

@test "v2.36: context-warning.sh is executable" {
    [ -x "$GLOBAL_HOOKS_DIR/context-warning.sh" ]
}

@test "v2.36: context warning threshold is 80%" {
    grep -qE "THRESHOLD=80" "$GLOBAL_HOOKS_DIR/context-warning.sh"
}

@test "v2.36: context critical threshold is 85%" {
    grep -qE "CRITICAL_THRESHOLD=85" "$GLOBAL_HOOKS_DIR/context-warning.sh"
}

# ============================================================================
# POST-COMPACT RECOVERY TESTS
# ============================================================================

@test "v2.36: session-start-ledger.sh exists" {
    [ -f "$GLOBAL_HOOKS_DIR/session-start-ledger.sh" ]
}

@test "v2.36: session-start-ledger.sh handles compact event" {
    grep -q "compact" "$GLOBAL_HOOKS_DIR/session-start-ledger.sh"
}

@test "v2.36: pre-compact-handoff.sh exists" {
    [ -f "$GLOBAL_HOOKS_DIR/pre-compact-handoff.sh" ]
}

@test "v2.36: Ledger directory exists or can be created" {
    mkdir -p "$RALPH_DIR/ledgers"
    [ -d "$RALPH_DIR/ledgers" ]
}

@test "v2.36: Handoff directory exists or can be created" {
    mkdir -p "$RALPH_DIR/handoffs"
    [ -d "$RALPH_DIR/handoffs" ]
}

@test "v2.36: Log directory exists or can be created" {
    mkdir -p "$RALPH_DIR/logs"
    [ -d "$RALPH_DIR/logs" ]
}

# ============================================================================
# GLOBAL CONFIGURATION TESTS
# ============================================================================

@test "v2.36: Global settings.json exists" {
    [ -f "$GLOBAL_CLAUDE_DIR/settings.json" ]
}

@test "v2.36: settings.json is valid JSON" {
    jq empty "$GLOBAL_CLAUDE_DIR/settings.json"
}

@test "v2.36: settings.json has hooks configuration" {
    jq -e '.hooks' "$GLOBAL_CLAUDE_DIR/settings.json" >/dev/null
}

@test "v2.36: settings.json has SessionStart hook" {
    grep -q "SessionStart" "$GLOBAL_CLAUDE_DIR/settings.json"
}

@test "v2.36: Global CLAUDE.md exists" {
    [ -f "$GLOBAL_CLAUDE_DIR/CLAUDE.md" ]
}

# ============================================================================
# RALPH CLI INTEGRATION TESTS
# ============================================================================

@test "v2.36: ralph command exists" {
    command -v ralph
}

@test "v2.36: ralph help includes sync-global" {
    ralph help 2>&1 | grep -q "sync-global"
}

@test "v2.36: ralph help includes validate-arch" {
    ralph help 2>&1 | grep -q "validate-arch"
}

@test "v2.36: ralph help includes ledger" {
    ralph help 2>&1 | grep -q "ledger"
}

@test "v2.36: ralph help includes gates" {
    ralph help 2>&1 | grep -q "gates"
}

@test "v2.36: ralph version output contains version number" {
    ralph version 2>&1 | grep -qE "[0-9]+\.[0-9]+"
}

# ============================================================================
# MIGRATION SCRIPT TESTS
# ============================================================================

@test "v2.36: Migration script exists" {
    [ -f "scripts/migrate-commands-to-skills.sh" ]
}

@test "v2.36: Migration script is executable" {
    [ -x "scripts/migrate-commands-to-skills.sh" ]
}

@test "v2.36: Migration script has dry-run option" {
    grep -q "\-\-dry-run" "scripts/migrate-commands-to-skills.sh"
}
