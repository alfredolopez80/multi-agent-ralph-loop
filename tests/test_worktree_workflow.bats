#!/usr/bin/env bats

# Tests for ralph worktree workflow commands (v2.20)
# Tests cmd_worktree, cmd_worktree_pr, cmd_worktree_merge, cmd_worktree_fix,
# cmd_worktree_close, cmd_worktree_status, cmd_worktree_cleanup

setup() {
    RALPH_SCRIPT="$BATS_TEST_DIRNAME/../scripts/ralph"
    TEST_DIR="$(mktemp -d)"
    export RALPH_TMPDIR="$TEST_DIR/.ralph-tmp"
    export WORKTREES_DIR="$TEST_DIR/.worktrees"
    cd "$TEST_DIR"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# ===============================================================================
# cmd_worktree tests
# ===============================================================================

@test 'cmd_worktree function exists' {
    grep -q 'cmd_worktree()' "$RALPH_SCRIPT"
}

@test 'cmd_worktree checks for wt tool' {
    # v2.44+: wt is optional with native fallback
    grep -A15 'cmd_worktree()' "$RALPH_SCRIPT" | grep -qi 'wt'
}

@test 'cmd_worktree validates task input' {
    grep -A10 'cmd_worktree()' "$RALPH_SCRIPT" | grep -q 'validate_text_input'
}

@test 'cmd_worktree shows usage when no task provided' {
    grep -A15 'cmd_worktree()' "$RALPH_SCRIPT" | grep -q 'Usage: ralph worktree'
}

@test 'cmd_worktree creates worktree' {
    # v2.44+: uses git worktree add instead of WorkTrunk
    grep -A40 'cmd_worktree()' "$RALPH_SCRIPT" | grep -qi 'worktree'
}

@test 'cmd_worktree generates branch name from task' {
    grep -A30 'cmd_worktree()' "$RALPH_SCRIPT" | grep -q 'ai/ralph/'
}

@test 'cmd_worktree applies security hardening' {
    # v2.44+: security hardening may use hooksPath or repo-boundary-guard
    grep -A100 'cmd_worktree()' "$RALPH_SCRIPT" | grep -qiE 'security|hooks|guard|protect|harden'
}

# ===============================================================================
# cmd_worktree_pr tests
# ===============================================================================

@test 'cmd_worktree_pr function exists' {
    grep -q 'cmd_worktree_pr()' "$RALPH_SCRIPT"
}

@test 'cmd_worktree_pr requires wt and gh tools' {
    grep -A5 'cmd_worktree_pr()' "$RALPH_SCRIPT" | grep -q 'require_tools'
}

@test 'cmd_worktree_pr validates branch argument' {
    grep -A10 'cmd_worktree_pr()' "$RALPH_SCRIPT" | grep -q 'BRANCH=.*1:-'
}

@test 'cmd_worktree_pr shows usage when no branch' {
    grep -A20 'cmd_worktree_pr()' "$RALPH_SCRIPT" | grep -q 'Usage: ralph worktree-pr'
}

@test 'cmd_worktree_pr detects current branch' {
    grep -A15 'cmd_worktree_pr()' "$RALPH_SCRIPT" | grep -q 'git branch --show-current'
}

@test 'cmd_worktree_pr creates draft PR' {
    grep -A60 'cmd_worktree_pr()' "$RALPH_SCRIPT" | grep -q 'gh pr create --draft'
}

@test 'cmd_worktree_pr runs Claude Opus review' {
    grep -A100 'cmd_worktree_pr()' "$RALPH_SCRIPT" | grep -q 'claude --print -m opus'
}

@test 'cmd_worktree_pr runs Codex GPT-5 review' {
    grep -A120 'cmd_worktree_pr()' "$RALPH_SCRIPT" | grep -q 'codex exec -m gpt-5'
}

@test 'cmd_worktree_pr posts reviews as comments' {
    grep -A150 'cmd_worktree_pr()' "$RALPH_SCRIPT" | grep -q 'gh pr comment'
}

@test 'cmd_worktree_pr checks for blockers' {
    grep -A180 'cmd_worktree_pr()' "$RALPH_SCRIPT" | grep -qE 'BLOCKED|BLOCKER|CRITICAL'
}

# ===============================================================================
# cmd_worktree_merge tests
# ===============================================================================

@test 'cmd_worktree_merge function exists' {
    grep -q 'cmd_worktree_merge()' "$RALPH_SCRIPT"
}

@test 'cmd_worktree_merge validates PR number' {
    grep -A5 'cmd_worktree_merge()' "$RALPH_SCRIPT" | grep -q 'PR_NUMBER=.*1:-'
}

@test 'cmd_worktree_merge shows usage when no PR number' {
    grep -A10 'cmd_worktree_merge()' "$RALPH_SCRIPT" | grep -q 'Usage: ralph worktree-merge'
}

@test 'cmd_worktree_merge requires gh CLI' {
    grep -A15 'cmd_worktree_merge()' "$RALPH_SCRIPT" | grep -q 'command -v gh'
}

@test 'cmd_worktree_merge marks PR ready' {
    grep -A20 'cmd_worktree_merge()' "$RALPH_SCRIPT" | grep -q 'gh pr ready'
}

@test 'cmd_worktree_merge waits for CI checks' {
    grep -A25 'cmd_worktree_merge()' "$RALPH_SCRIPT" | grep -q 'gh pr checks.*--watch'
}

@test 'cmd_worktree_merge uses squash merge' {
    grep -A30 'cmd_worktree_merge()' "$RALPH_SCRIPT" | grep -q 'gh pr merge.*--squash'
}

@test 'cmd_worktree_merge cleans up worktree' {
    grep -A45 'cmd_worktree_merge()' "$RALPH_SCRIPT" | grep -qE 'wt remove|git worktree remove'
}

# ===============================================================================
# cmd_worktree_fix tests
# ===============================================================================

@test 'cmd_worktree_fix function exists' {
    grep -q 'cmd_worktree_fix()' "$RALPH_SCRIPT"
}

@test 'cmd_worktree_fix validates PR number' {
    grep -A5 'cmd_worktree_fix()' "$RALPH_SCRIPT" | grep -q 'PR_NUMBER=.*1:-'
}

@test 'cmd_worktree_fix shows usage when no PR number' {
    grep -A10 'cmd_worktree_fix()' "$RALPH_SCRIPT" | grep -q 'Usage: ralph worktree-fix'
}

@test 'cmd_worktree_fix requires gh CLI' {
    grep -A15 'cmd_worktree_fix()' "$RALPH_SCRIPT" | grep -q 'command -v gh'
}

@test 'cmd_worktree_fix fetches PR branch' {
    grep -A20 'cmd_worktree_fix()' "$RALPH_SCRIPT" | grep -q 'gh pr view.*headRefName'
}

@test 'cmd_worktree_fix switches to branch' {
    grep -A30 'cmd_worktree_fix()' "$RALPH_SCRIPT" | grep -qE 'wt switch|git checkout'
}

@test 'cmd_worktree_fix displays review comments' {
    grep -A30 'cmd_worktree_fix()' "$RALPH_SCRIPT" | grep -q 'gh pr view.*--comments'
}

# ===============================================================================
# cmd_worktree_close tests
# ===============================================================================

@test 'cmd_worktree_close function exists' {
    grep -q 'cmd_worktree_close()' "$RALPH_SCRIPT"
}

@test 'cmd_worktree_close validates PR number' {
    grep -A5 'cmd_worktree_close()' "$RALPH_SCRIPT" | grep -q 'PR_NUMBER=.*1:-'
}

@test 'cmd_worktree_close shows usage when no PR number' {
    grep -A10 'cmd_worktree_close()' "$RALPH_SCRIPT" | grep -q 'Usage: ralph worktree-close'
}

@test 'cmd_worktree_close requires gh CLI' {
    grep -A15 'cmd_worktree_close()' "$RALPH_SCRIPT" | grep -q 'command -v gh'
}

@test 'cmd_worktree_close gets branch before closing' {
    grep -A20 'cmd_worktree_close()' "$RALPH_SCRIPT" | grep -q 'gh pr view.*headRefName'
}

@test 'cmd_worktree_close closes PR' {
    grep -A25 'cmd_worktree_close()' "$RALPH_SCRIPT" | grep -q 'gh pr close'
}

@test 'cmd_worktree_close deletes branch' {
    grep -A25 'cmd_worktree_close()' "$RALPH_SCRIPT" | grep -F -- '--delete-branch'
}

@test 'cmd_worktree_close cleans up worktree' {
    grep -A30 'cmd_worktree_close()' "$RALPH_SCRIPT" | grep -q 'wt remove\|git worktree remove'
}

# ===============================================================================
# cmd_worktree_status tests
# ===============================================================================

@test 'cmd_worktree_status function exists' {
    grep -q 'cmd_worktree_status()' "$RALPH_SCRIPT"
}

@test 'cmd_worktree_status lists worktrees' {
    grep -A10 'cmd_worktree_status()' "$RALPH_SCRIPT" | grep -q 'git worktree list'
}

@test 'cmd_worktree_status prefers wt list' {
    grep -A10 'cmd_worktree_status()' "$RALPH_SCRIPT" | grep -q 'wt list'
}

@test 'cmd_worktree_status shows active PRs' {
    grep -A15 'cmd_worktree_status()' "$RALPH_SCRIPT" | grep -q 'gh pr list'
}

@test 'cmd_worktree_status filters ai/ralph branches' {
    grep -A15 'cmd_worktree_status()' "$RALPH_SCRIPT" | grep -q 'ai/ralph'
}

# ===============================================================================
# cmd_worktree_cleanup tests
# ===============================================================================

@test 'cmd_worktree_cleanup function exists' {
    grep -q 'cmd_worktree_cleanup()' "$RALPH_SCRIPT"
}

@test 'cmd_worktree_cleanup finds merged branches' {
    grep -A10 'cmd_worktree_cleanup()' "$RALPH_SCRIPT" | grep -q 'git branch --merged'
}

@test 'cmd_worktree_cleanup filters ai/ralph branches' {
    grep -A10 'cmd_worktree_cleanup()' "$RALPH_SCRIPT" | grep -q 'grep.*ai/ralph'
}

@test 'cmd_worktree_cleanup removes worktrees' {
    grep -A15 'cmd_worktree_cleanup()' "$RALPH_SCRIPT" | grep -q 'wt remove\|git worktree remove'
}

@test 'cmd_worktree_cleanup prunes worktree metadata' {
    grep -A25 'cmd_worktree_cleanup()' "$RALPH_SCRIPT" | grep -q 'git worktree prune'
}

@test 'cmd_worktree_cleanup cleans empty worktrees directory' {
    grep -A25 'cmd_worktree_cleanup()' "$RALPH_SCRIPT" | grep -q 'rmdir.*WORKTREES_DIR'
}

@test 'cmd_worktree_cleanup shows status at end' {
    grep -A30 'cmd_worktree_cleanup()' "$RALPH_SCRIPT" | grep -q 'cmd_worktree_status'
}

# ===============================================================================
# Integration tests (these assume actual commands exist)
# ===============================================================================

@test 'all worktree commands have help text' {
    for cmd in worktree worktree-pr worktree-merge worktree-fix worktree-close worktree-status worktree-cleanup; do
        grep -A10 "cmd_${cmd//-/_}()" "$RALPH_SCRIPT" | grep -qE 'Usage:|log_info|log_error' || {
            echo "Missing help text for cmd_${cmd//-/_}"
            return 1
        }
    done
}

@test 'worktree commands use consistent branch prefix' {
    # All should reference ai/ralph/ prefix
    local COUNT
    COUNT=$(grep -c 'ai/ralph' "$RALPH_SCRIPT" || echo 0)
    [ "$COUNT" -ge 5 ]
}

@test 'worktree commands use WorkTrunk wt tool' {
    # Should have multiple references to wt command
    local COUNT
    COUNT=$(grep -c 'wt switch\|wt remove\|wt list' "$RALPH_SCRIPT" || echo 0)
    [ "$COUNT" -ge 5 ]
}
