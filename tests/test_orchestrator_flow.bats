#!/usr/bin/env bats
# test_orchestrator_flow.bats - Orchestration flow coverage
# Run with: bats tests/test_orchestrator_flow.bats

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    RALPH_SCRIPT="$PROJECT_DIR/scripts/ralph"
    ORCH_AGENT_DOC="$PROJECT_DIR/.claude/agents/orchestrator.md"
    ORCH_COMMAND_DOC="$PROJECT_DIR/.claude/commands/orchestrator.md"

    [ -f "$RALPH_SCRIPT" ] || skip "ralph script not found at $RALPH_SCRIPT"
}

# ============================================================================
# CLI Orchestration Flow (cmd_orch)
# ============================================================================

@test "cmd_orch exists" {
    grep -q 'cmd_orch()' "$RALPH_SCRIPT"
}

@test "cmd_orch prints orchestration banner" {
    grep -A6 'cmd_orch()' "$RALPH_SCRIPT" | grep -q 'RALPH WIGGUM'
}

@test "cmd_orch includes step 0 auto-plan" {
    grep -A5 'AUTO-PLAN MODE' "$RALPH_SCRIPT" | grep -q '\[0/7\]'
}

@test "cmd_orch includes clarify step" {
    grep -A5 'CLARIFY' "$RALPH_SCRIPT" | grep -q '\[1/7\]'
}

@test "cmd_orch includes classify step" {
    grep -A5 'CLASSIFY' "$RALPH_SCRIPT" | grep -q '\[2/7\]'
}

@test "cmd_orch includes plan step" {
    grep -A5 'PLAN' "$RALPH_SCRIPT" | grep -q '\[3/7\]'
}

@test "cmd_orch includes delegate step" {
    grep -A5 'DELEGATE' "$RALPH_SCRIPT" | grep -q '\[4/7\]'
}

@test "cmd_orch includes execute step" {
    grep -A5 'EXECUTE' "$RALPH_SCRIPT" | grep -q '\[5/7\]'
}

@test "cmd_orch includes validate step" {
    grep -A5 'VALIDATE' "$RALPH_SCRIPT" | grep -q '\[6/7\]'
}

@test "cmd_orch includes retrospective step" {
    grep -A5 'RETROSPECTIVE' "$RALPH_SCRIPT" | grep -q '\[7/7\]'
}

@test "cmd_orch delegates execution to cmd_parallel" {
    grep -A6 'EXECUTE' "$RALPH_SCRIPT" | grep -q 'cmd_parallel'
}

@test "cmd_orch integrates quality gates" {
    grep -A6 'VALIDATE' "$RALPH_SCRIPT" | grep -q 'cmd_gates --check'
}

@test "cmd_orch runs retrospective" {
    grep -A6 'RETROSPECTIVE' "$RALPH_SCRIPT" | grep -q 'cmd_retrospective'
}

# ============================================================================
# Iteration Limits
# ============================================================================

@test "iteration limit is 15 for Claude" {
    grep -q 'CLAUDE_MAX_ITER=15\|CLAUDE_MAX_ITER="15"' "$RALPH_SCRIPT"
}

@test "iteration limit is 30 for MiniMax" {
    grep -q 'MINIMAX_MAX_ITER=30\|MINIMAX_MAX_ITER="30"' "$RALPH_SCRIPT"
}

# ============================================================================
# Model Selection by Task Type
# ============================================================================

@test "model selection defines EXPLORATION_MODEL" {
    grep -q 'EXPLORATION_MODEL="minimax"' "$RALPH_SCRIPT"
}

@test "model selection defines IMPLEMENTATION_MODEL" {
    grep -q 'IMPLEMENTATION_MODEL="sonnet"' "$RALPH_SCRIPT"
}

@test "model selection defines REVIEW_MODEL" {
    grep -q 'REVIEW_MODEL="opus"' "$RALPH_SCRIPT"
}

@test "model selection defines VALIDATION_MODEL" {
    grep -q 'VALIDATION_MODEL="minimax"' "$RALPH_SCRIPT"
}

@test "get_model_cli maps exploration to mmc" {
    grep -A10 'get_model_cli()' "$RALPH_SCRIPT" | grep -q 'exploration|validation'
}

@test "get_model_cli maps implementation to sonnet" {
    grep -A10 'get_model_cli()' "$RALPH_SCRIPT" | grep -q 'implementation'
}

@test "get_model_cli maps review to opus" {
    grep -A10 'get_model_cli()' "$RALPH_SCRIPT" | grep -q 'review'
}

# ============================================================================
# Orchestrator Agent Flow (8 steps)
# ============================================================================

@test "orchestrator agent doc exists" {
    [ -f "$ORCH_AGENT_DOC" ]
}

@test "orchestrator agent documents 8-step flow" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'Mandatory Flow (8 Steps)' "$ORCH_AGENT_DOC"
}

@test "step 0 auto-plan documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '0\. AUTO-PLAN' "$ORCH_AGENT_DOC"
}

@test "step 1 clarify documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '1\. CLARIFY' "$ORCH_AGENT_DOC"
}

@test "step 2 classify documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '2\. CLASSIFY' "$ORCH_AGENT_DOC"
}

@test "step 2b worktree decision documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '2b\. WORKTREE' "$ORCH_AGENT_DOC"
}

@test "step 3 plan documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '3\. PLAN' "$ORCH_AGENT_DOC"
}

@test "step 4 delegate documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '4\. DELEGATE' "$ORCH_AGENT_DOC"
}

@test "step 5 execute documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '5\. EXECUTE' "$ORCH_AGENT_DOC"
}

@test "step 6 validate documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '6\. VALIDATE' "$ORCH_AGENT_DOC"
}

@test "step 7 retrospective documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '7\. RETROSPECT' "$ORCH_AGENT_DOC"
}

@test "step 7b PR review documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '7b\. PR REVIEW' "$ORCH_AGENT_DOC"
}

# ============================================================================
# Worktree Decision and PR Workflow
# ============================================================================

@test "worktree question is present" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'worktree aislado' "$ORCH_AGENT_DOC"
}

@test "worktree creation command is documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'ralph worktree' "$ORCH_AGENT_DOC"
}

@test "worktree PR workflow is documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'ralph worktree-pr' "$ORCH_AGENT_DOC"
}

# ============================================================================
# Delegation Patterns
# ============================================================================

@test "delegation table includes complexity 1-2 MiniMax-lightning" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '1-2.*MiniMax-lightning' "$ORCH_AGENT_DOC"
}

@test "delegation table includes complexity 7-8 Opus" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '7-8.*Opus' "$ORCH_AGENT_DOC"
}

@test "delegation table includes complexity 9-10 Opus" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '9-10.*Opus' "$ORCH_AGENT_DOC"
}

@test "subagent tasks specify model sonnet" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'model: "sonnet"' "$ORCH_AGENT_DOC"
}

@test "subagent tasks run in background" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'run_in_background: true' "$ORCH_AGENT_DOC"
}

@test "Task-based subagent delegation is documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '^Task:' "$ORCH_AGENT_DOC"
}

# ============================================================================
# Quality Gates and Adversarial Validation
# ============================================================================

@test "quality gates command is documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'ralph gates' "$ORCH_AGENT_DOC"
}

@test "adversarial validation command is documented" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'ralph adversarial' "$ORCH_AGENT_DOC"
}

@test "adversarial validation requires 2/3 consensus" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q '2/3 consensus' "$ORCH_AGENT_DOC"
}

@test "adversarial trigger condition is complexity >= 7" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'complexity >= 7' "$ORCH_AGENT_DOC"
}

# ============================================================================
# Iteration Limits in Orchestrator Doc
# ============================================================================

@test "orchestrator doc lists Claude iteration limit 15" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'Claude.*15' "$ORCH_AGENT_DOC"
}

@test "orchestrator doc lists MiniMax iteration limit 30" {
    [ -f "$ORCH_AGENT_DOC" ] || skip "orchestrator agent doc missing"
    grep -q 'MiniMax M2.1.*30' "$ORCH_AGENT_DOC"
}

# ============================================================================
# Command Documentation
# ============================================================================

@test "orchestrator command doc exists" {
    [ -f "$ORCH_COMMAND_DOC" ]
}

@test "orchestrator command doc references ralph orch" {
    [ -f "$ORCH_COMMAND_DOC" ] || skip "orchestrator command doc missing"
    grep -q 'ralph orch' "$ORCH_COMMAND_DOC"
}
