#!/usr/bin/env bats
# test_cli_commands.bats - CLI command coverage for scripts/ralph
#
# Run with: bats tests/test_cli_commands.bats
# Install bats: brew install bats-core

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    RALPH_SCRIPT="$PROJECT_DIR/scripts/ralph"

    [ -f "$RALPH_SCRIPT" ] || skip "ralph script not found at $RALPH_SCRIPT"

    TEST_TMPDIR=$(mktemp -d)
    TEST_HOME="$TEST_TMPDIR/home"
    BIN_DIR="$TEST_TMPDIR/bin"
    TARGET_DIR="$TEST_TMPDIR/target"

    mkdir -p "$TEST_HOME" "$BIN_DIR" "$TARGET_DIR"
    echo "test" > "$TARGET_DIR/file.txt"

    # Minimal MiniMax config to avoid skip paths
    mkdir -p "$TEST_HOME/.ralph/config"
    echo '{"api_key":"stub"}' > "$TEST_HOME/.ralph/config/minimax.json"

    # Minimal quality gates hook
    mkdir -p "$TEST_HOME/.claude/hooks"
    cat > "$TEST_HOME/.claude/hooks/quality-gates.sh" << 'EOF'
#!/usr/bin/env bash
echo "Quality Gates"
exit 0
EOF
    chmod +x "$TEST_HOME/.claude/hooks/quality-gates.sh"

    # Stub binaries to avoid external dependencies
    cat > "$BIN_DIR/claude" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
  echo "claude 0.0.0"
  exit 0
fi
# Return a predictable response for tests
if [[ "$*" == *"--print"* ]]; then
  echo "VERIFIED_DONE"
  exit 0
fi
echo "claude stub"
EOF

    cat > "$BIN_DIR/codex" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
  echo "codex 0.0.0"
  exit 0
fi
# Return JSON-like output for grep/jq in tests
if [[ "$1" == "exec" ]]; then
  echo '{"approved": true, "summary": {}}'
  exit 0
fi
echo '{"approved": true}'
EOF

    cat > "$BIN_DIR/gemini" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
  echo "gemini 0.0.0"
  exit 0
fi
# Output JSON when requested
if [[ "$*" == *"-o json"* ]]; then
  echo '{"approved": true}'
  exit 0
fi
echo '{"approved": true}'
EOF

    cat > "$BIN_DIR/mmc" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
  echo "mmc 0.0.0"
  exit 0
fi
if [[ "$1" == "--query" ]]; then
  echo '{"result":"ok"}'
  exit 0
fi
echo "mmc stub"
EOF

    cat > "$BIN_DIR/wt" << 'EOF'
#!/usr/bin/env bash
# WorkTrunk stub
exit 0
EOF

    cat > "$BIN_DIR/gh" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
  echo "gh version 0.0.0"
  exit 0
fi
if [[ "$1" == "auth" ]]; then
  echo "Logged in to github.com as stub"
  exit 0
fi
# Default no-op
exit 0
EOF

    cat > "$BIN_DIR/sg" << 'EOF'
#!/usr/bin/env bash
# ast-grep stub
exit 0
EOF

    cat > "$BIN_DIR/jq" << 'EOF'
#!/usr/bin/env bash
# jq stub
if [[ "$1" == "-n" ]]; then
  echo "{}"
  exit 0
fi
cat 2>/dev/null || true
exit 0
EOF

    cat > "$BIN_DIR/git" << 'EOF'
#!/usr/bin/env bash
# git stub
case "$1" in
  status)
    exit 0
    ;;
  branch)
    exit 0
    ;;
  worktree)
    exit 0
    ;;
  diff)
    exit 0
    ;;
  checkout)
    exit 0
    ;;
  push)
    exit 0
    ;;
  config)
    exit 0
    ;;
  rev-parse)
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
EOF

    cat > "$BIN_DIR/shellcheck" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF

    cat > "$BIN_DIR/bats" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF

    chmod +x "$BIN_DIR"/*

    TEST_PATH="$BIN_DIR:$PATH"
    export HOME="$TEST_HOME"
    export PATH="$TEST_PATH"

    cd "$TEST_TMPDIR"
}

teardown() {
    cd /
    [ -n "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

run_cli() {
    run env HOME="$TEST_HOME" PATH="$TEST_PATH" bash "$RALPH_SCRIPT" "$@"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCTION EXISTENCE TESTS (33)
# ═══════════════════════════════════════════════════════════════════════════════

@test "cmd_orch function exists" { grep -qE "^cmd_orch\(\)" "$RALPH_SCRIPT"; }
@test "cmd_loop function exists" { grep -qE "^cmd_loop\(\)" "$RALPH_SCRIPT"; }
@test "cmd_clarify function exists" { grep -qE "^cmd_clarify\(\)" "$RALPH_SCRIPT"; }
@test "cmd_security function exists" { grep -qE "^cmd_security\(\)" "$RALPH_SCRIPT"; }
@test "cmd_security_loop function exists" { grep -qE "^cmd_security_loop\(\)" "$RALPH_SCRIPT"; }
@test "cmd_bugs function exists" { grep -qE "^cmd_bugs\(\)" "$RALPH_SCRIPT"; }
@test "cmd_unit_tests function exists" { grep -qE "^cmd_unit_tests\(\)" "$RALPH_SCRIPT"; }
@test "cmd_refactor function exists" { grep -qE "^cmd_refactor\(\)" "$RALPH_SCRIPT"; }
@test "cmd_parallel function exists" { grep -qE "^cmd_parallel\(\)" "$RALPH_SCRIPT"; }
@test "cmd_adversarial function exists" { grep -qE "^cmd_adversarial\(\)" "$RALPH_SCRIPT"; }
@test "cmd_gates function exists" { grep -qE "^cmd_gates\(\)" "$RALPH_SCRIPT"; }
@test "cmd_research function exists" { grep -qE "^cmd_research\(\)" "$RALPH_SCRIPT"; }
@test "cmd_library function exists" { grep -qE "^cmd_library\(\)" "$RALPH_SCRIPT"; }
@test "cmd_browse function exists" { grep -qE "^cmd_browse\(\)" "$RALPH_SCRIPT"; }
@test "cmd_ast function exists" { grep -qE "^cmd_ast\(\)" "$RALPH_SCRIPT"; }
@test "cmd_worktree function exists" { grep -qE "^cmd_worktree\(\)" "$RALPH_SCRIPT"; }
@test "cmd_worktree_pr function exists" { grep -qE "^cmd_worktree_pr\(\)" "$RALPH_SCRIPT"; }
@test "cmd_worktree_merge function exists" { grep -qE "^cmd_worktree_merge\(\)" "$RALPH_SCRIPT"; }
@test "cmd_worktree_fix function exists" { grep -qE "^cmd_worktree_fix\(\)" "$RALPH_SCRIPT"; }
@test "cmd_worktree_close function exists" { grep -qE "^cmd_worktree_close\(\)" "$RALPH_SCRIPT"; }
@test "cmd_worktree_status function exists" { grep -qE "^cmd_worktree_status\(\)" "$RALPH_SCRIPT"; }
@test "cmd_worktree_cleanup function exists" { grep -qE "^cmd_worktree_cleanup\(\)" "$RALPH_SCRIPT"; }
@test "cmd_self_update function exists" { grep -qE "^cmd_self_update\(\)" "$RALPH_SCRIPT"; }
@test "cmd_pre_merge function exists" { grep -qE "^cmd_pre_merge\(\)" "$RALPH_SCRIPT"; }
@test "cmd_integrations function exists" { grep -qE "^cmd_integrations\(\)" "$RALPH_SCRIPT"; }
@test "cmd_uninstall function exists" { grep -qE "^cmd_uninstall\(\)" "$RALPH_SCRIPT"; }
@test "cmd_websearch function exists" { grep -qE "^cmd_websearch\(\)" "$RALPH_SCRIPT"; }
@test "cmd_image function exists" { grep -qE "^cmd_image\(\)" "$RALPH_SCRIPT"; }
@test "cmd_minimax function exists" { grep -qE "^cmd_minimax\(\)" "$RALPH_SCRIPT"; }
@test "cmd_improvements function exists" { grep -qE "^cmd_improvements\(\)" "$RALPH_SCRIPT"; }
@test "cmd_status function exists" { grep -qE "^cmd_status\(\)" "$RALPH_SCRIPT"; }
@test "cmd_version function exists" { grep -qE "^cmd_version\(\)" "$RALPH_SCRIPT"; }
@test "cmd_help function exists" { grep -qE "^cmd_help\(\)" "$RALPH_SCRIPT"; }

# ═══════════════════════════════════════════════════════════════════════════════
# HELP TEXT TESTS (14)
# ═══════════════════════════════════════════════════════════════════════════════

@test "help lists orchestration commands" {
    run_cli help
    [[ "$output" == *"ralph orch"* ]]
    [[ "$output" == *"ralph loop"* ]]
    [[ "$output" == *"ralph clarify"* ]]
}

@test "help lists review commands" {
    run_cli help
    [[ "$output" == *"ralph parallel"* ]]
    [[ "$output" == *"ralph full-review"* ]]
}

@test "help lists adversarial and gates" {
    run_cli help
    [[ "$output" == *"ralph adversarial"* ]]
    [[ "$output" == *"ralph gates"* ]]
}

@test "help lists security and bugs" {
    run_cli help
    [[ "$output" == *"ralph security"* ]]
    [[ "$output" == *"ralph bugs"* ]]
}

@test "help lists unit-tests and refactor" {
    run_cli help
    [[ "$output" == *"ralph unit-tests"* ]]
    [[ "$output" == *"ralph refactor"* ]]
}

@test "help lists research and minimax" {
    run_cli help
    [[ "$output" == *"ralph research"* ]]
    [[ "$output" == *"ralph minimax"* ]]
}

@test "help lists library and browse" {
    run_cli help
    [[ "$output" == *"ralph library"* ]]
    [[ "$output" == *"ralph browse"* ]]
}

@test "help lists ast search" {
    run_cli help
    [[ "$output" == *"ralph ast"* ]]
}

@test "help lists websearch and image" {
    run_cli help
    [[ "$output" == *"ralph websearch"* ]]
    [[ "$output" == *"ralph image"* ]]
}

@test "help lists retrospective and improvements" {
    run_cli help
    [[ "$output" == *"ralph retrospective"* ]]
    [[ "$output" == *"ralph improvements"* ]]
}

@test "help lists worktree commands" {
    run_cli help
    [[ "$output" == *"ralph worktree"* ]]
    [[ "$output" == *"ralph worktree-pr"* ]]
    [[ "$output" == *"ralph worktree-merge"* ]]
    [[ "$output" == *"ralph worktree-fix"* ]]
    [[ "$output" == *"ralph worktree-close"* ]]
    [[ "$output" == *"ralph worktree-status"* ]]
    [[ "$output" == *"ralph worktree-cleanup"* ]]
}

@test "help lists maintenance commands" {
    run_cli help
    [[ "$output" == *"ralph self-update"* ]]
    [[ "$output" == *"ralph pre-merge"* ]]
    [[ "$output" == *"ralph integrations"* ]]
}

@test "help lists utility commands" {
    run_cli help
    [[ "$output" == *"ralph status"* ]]
    [[ "$output" == *"ralph version"* ]]
    [[ "$output" == *"ralph help"* ]]
}

@test "help lists uninstall command" {
    run_cli help
    [[ "$output" == *"ralph --uninstall"* ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# BASIC INVOCATION TESTS (33)
# ═══════════════════════════════════════════════════════════════════════════════

@test "cmd_orch basic invocation" {
    run bash -c "printf '\n' | env HOME=\"$TEST_HOME\" PATH=\"$TEST_PATH\" bash \"$RALPH_SCRIPT\" orch \"test task\""
    [ "$status" -eq 0 ]
}

@test "cmd_loop basic invocation" {
    run_cli loop "test loop"
    [ "$status" -eq 0 ]
}

@test "cmd_clarify basic invocation" {
    run_cli clarify "test clarify"
    [ "$status" -eq 0 ]
}

@test "cmd_security basic invocation" {
    run_cli security "$TARGET_DIR"
    [ "$status" -eq 0 ]
}

@test "cmd_security_loop basic invocation" {
    run_cli security-loop
    [ "$status" -eq 1 ]
    [[ "$output" == *"MULTI-LEVEL SECURITY LOOP"* ]]
}

@test "cmd_bugs basic invocation" {
    run_cli bugs "$TARGET_DIR"
    [ "$status" -eq 0 ]
}

@test "cmd_unit_tests basic invocation" {
    run_cli unit-tests "$TARGET_DIR"
    [ "$status" -eq 0 ]
}

@test "cmd_refactor basic invocation" {
    run_cli refactor "$TARGET_DIR"
    [ "$status" -eq 0 ]
}

@test "cmd_parallel basic invocation" {
    run_cli parallel "$TARGET_DIR" --async
    [ "$status" -eq 0 ]
}

@test "cmd_adversarial basic invocation" {
    run_cli adversarial "$TARGET_DIR"
    [ "$status" -eq 0 ]
}

@test "cmd_gates basic invocation" {
    run_cli gates --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"Quality Gates"* ]]
}

@test "cmd_research basic invocation" {
    run_cli research "test query"
    [ "$status" -eq 0 ]
}

@test "cmd_library basic invocation" {
    run_cli library "React useEffect"
    [ "$status" -eq 0 ]
}

@test "cmd_browse basic invocation" {
    run_cli browse "example.com" --snapshot
    [ "$status" -eq 0 ]
}

@test "cmd_ast basic invocation" {
    run_cli ast 'console.log($MSG)' "$TARGET_DIR"
    [ "$status" -eq 0 ]
}

@test "cmd_worktree basic invocation" {
    run_cli worktree
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: ralph worktree"* ]]
}

@test "cmd_worktree_pr basic invocation" {
    run_cli worktree-pr
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: ralph worktree-pr"* ]]
}

@test "cmd_worktree_merge basic invocation" {
    run_cli worktree-merge
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: ralph worktree-merge"* ]]
}

@test "cmd_worktree_fix basic invocation" {
    run_cli worktree-fix
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: ralph worktree-fix"* ]]
}

@test "cmd_worktree_close basic invocation" {
    run_cli worktree-close
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: ralph worktree-close"* ]]
}

@test "cmd_worktree_status basic invocation" {
    run_cli worktree-status
    [ "$status" -eq 0 ]
}

@test "cmd_worktree_cleanup basic invocation" {
    run_cli worktree-cleanup
    [ "$status" -eq 0 ]
}

@test "cmd_self_update basic invocation" {
    run_cli self-update
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot find ralph repository"* ]]
}

@test "cmd_pre_merge basic invocation" {
    run_cli pre-merge
    [ "$status" -eq 0 ]
}

@test "cmd_integrations basic invocation" {
    run_cli integrations
    [ "$status" -eq 0 ]
}

@test "cmd_uninstall basic invocation" {
    run_cli uninstall
    [ "$status" -eq 1 ]
    [[ "$output" == *"Uninstall script not found"* ]]
}

@test "cmd_websearch basic invocation" {
    run_cli websearch
    [ "$status" -eq 1 ]
    [[ "$output" == *"MINIMAX WEB SEARCH"* ]]
}

@test "cmd_image basic invocation" {
    run_cli image
    [ "$status" -eq 1 ]
    [[ "$output" == *"MINIMAX IMAGE ANALYSIS"* ]]
}

@test "cmd_minimax basic invocation" {
    run_cli minimax "test query"
    [ "$status" -eq 0 ]
}

@test "cmd_improvements basic invocation" {
    run_cli improvements
    [ "$status" -eq 0 ]
}

@test "cmd_status basic invocation" {
    run_cli status
    [ "$status" -eq 0 ]
}

@test "cmd_version basic invocation" {
    run_cli version
    [ "$status" -eq 0 ]
    [[ "$output" == *"ralph v"* ]]
}

@test "cmd_help basic invocation" {
    run_cli help
    [ "$status" -eq 0 ]
    [[ "$output" == *"ralph - Multi-Agent Orchestrator CLI"* ]]
}
