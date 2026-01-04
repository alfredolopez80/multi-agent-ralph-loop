# test_helper.bash - shared helpers for BATS tests

setup_cli_test_env() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    RALPH_SCRIPT="$PROJECT_DIR/scripts/ralph"

    [ -f "$RALPH_SCRIPT" ] || skip "ralph script not found at $RALPH_SCRIPT"

    TEST_TMPDIR=$(mktemp -d)
    RUN_DIR="$TEST_TMPDIR/run"
    STUB_BIN="$TEST_TMPDIR/bin"
    HOME_DIR="$TEST_TMPDIR/home"

    mkdir -p "$RUN_DIR" "$STUB_BIN" "$HOME_DIR" "$HOME_DIR/.ralph/config" "$HOME_DIR/.claude/hooks"

    ORIGINAL_HOME="$HOME"
    ORIGINAL_PATH="$PATH"

    export HOME="$HOME_DIR"
    export PATH="$STUB_BIN:$PATH"

    # Minimal MiniMax config so cmd_minimax can run
    echo '{"api_key":"test"}' > "$HOME_DIR/.ralph/config/minimax.json"

    # Stub quality gates hook
    cat > "$HOME_DIR/.claude/hooks/quality-gates.sh" << 'EOF'
#!/usr/bin/env bash
echo "quality gates ok"
exit 0
EOF
    chmod +x "$HOME_DIR/.claude/hooks/quality-gates.sh"

    # Dummy image for cmd_image tests
    IMAGE_FILE="$RUN_DIR/test.png"
    : > "$IMAGE_FILE"

    # Precompute help output
    HELP_OUTPUT="$TEST_TMPDIR/help.txt"
    bash "$RALPH_SCRIPT" help > "$HELP_OUTPUT" 2>/dev/null || true

    # Stubs for external tools
    create_stub "claude" '#!/usr/bin/env bash
if [[ "$*" == *"--version"* ]]; then echo "claude 0.0.0"; exit 0; fi
echo "{\"approved\": true, \"issues\": []}"
echo "VERIFIED_DONE"
exit 0'

    create_stub "codex" '#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "codex 0.0.0"; exit 0; fi
if [[ "$1" == "exec" ]]; then echo "{\"approved\": true, \"issues\": []}"; exit 0; fi
echo "codex stub"
exit 0'

    create_stub "gemini" '#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "gemini 0.0.0"; exit 0; fi
echo "{\"approved\": true, \"issues\": []}"
exit 0'

    create_stub "mmc" '#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "mmc 0.0.0"; exit 0; fi
if [[ "$1" == "--query" ]]; then echo "VERIFIED_DONE"; exit 0; fi
echo "mmc stub"
exit 0'

    create_stub "sg" '#!/usr/bin/env bash
echo "sg stub"
exit 0'

    create_stub "wt" '#!/usr/bin/env bash
exit 0'

    create_stub "gh" '#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "gh version 0.0.0"; exit 0; fi
if [[ "$1" == "auth" && "$2" == "status" ]]; then echo "Logged in"; exit 0; fi
if [[ "$1" == "pr" ]]; then
  case "$2" in
    create) echo "https://example.com/123"; exit 0;;
    diff) echo "diff --git a/a b/b"; exit 0;;
    comment) exit 0;;
    ready) exit 0;;
    checks) exit 0;;
    merge) exit 0;;
    view)
      if [[ "$*" == *"--json"* && "$*" == *"headRefName"* ]]; then
        echo "ai/ralph/20260104-test"; exit 0;
      fi
      echo ""; exit 0;;
    close) exit 0;;
    list) echo ""; exit 0;;
  esac
fi
exit 0'

    create_stub "git" '#!/usr/bin/env bash
case "$1" in
  rev-parse)
    if [[ "$2" == "--show-toplevel" ]]; then pwd; else echo ""; fi
    exit 0;;
  worktree)
    exit 0;;
  branch)
    if [[ "$2" == "--show-current" ]]; then echo ""; exit 0; fi
    if [[ "$2" == "--merged" ]]; then echo ""; exit 0; fi
    exit 0;;
  status)
    echo ""; exit 0;;
  diff)
    exit 0;;
  config)
    exit 0;;
  push)
    exit 0;;
  checkout)
    exit 0;;
  *)
    exit 0;;
esac'

    create_stub "jq" '#!/usr/bin/env bash
echo "{}"
exit 0'

    create_stub "shellcheck" '#!/usr/bin/env bash
exit 0'

    create_stub "bats" '#!/usr/bin/env bash
echo "ok 1"; exit 0'
}

teardown_cli_test_env() {
    export HOME="$ORIGINAL_HOME"
    export PATH="$ORIGINAL_PATH"

    [ -n "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

create_stub() {
    local name="$1"
    local content="$2"
    local path="$STUB_BIN/$name"

    printf '%s\n' "$content" > "$path"
    chmod +x "$path"
}

shell_escape() {
    printf '%q' "$1"
}

run_cli() {
    local cmd="$1"
    shift
    local script_escaped
    local run_dir_escaped
    script_escaped=$(shell_escape "$RALPH_SCRIPT")
    run_dir_escaped=$(shell_escape "$RUN_DIR")

    local cmd_escaped
    cmd_escaped=$(shell_escape "$cmd")

    local args_escaped=()
    for arg in "$@"; do
        args_escaped+=("$(shell_escape "$arg")")
    done

    run bash -c "cd $run_dir_escaped; $script_escaped $cmd_escaped ${args_escaped[*]}"
}

run_cli_with_input() {
    local input="$1"
    shift
    local script_escaped
    local run_dir_escaped
    script_escaped=$(shell_escape "$RALPH_SCRIPT")
    run_dir_escaped=$(shell_escape "$RUN_DIR")

    local cmd_escaped
    cmd_escaped=$(shell_escape "$1")
    shift

    local args_escaped=()
    for arg in "$@"; do
        args_escaped+=("$(shell_escape "$arg")")
    done

    local input_escaped
    input_escaped=$(shell_escape "$input")

    run bash -c "cd $run_dir_escaped; printf %s $input_escaped | $script_escaped $cmd_escaped ${args_escaped[*]}"
}

assert_cmd_exists() {
    local fn_name="$1"
    grep -q "$fn_name()" "$RALPH_SCRIPT"
}

assert_help_for_token() {
    local token="$1"
    local cmd="$2"

    if grep -Fq "$token" "$HELP_OUTPUT"; then
        return 0
    fi

    run_cli "$cmd"
    [ "$status" -ne 127 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"$token"* ]]
}

assert_basic_invocation() {
    local cmd="$1"
    shift
    run_cli "$cmd" "$@"
    [ "$status" -ne 127 ]
    [[ "$output" != *"Unknown command"* ]]
}

assert_basic_invocation_with_input() {
    local input="$1"
    shift
    local cmd="$1"
    shift
    run_cli_with_input "$input" "$cmd" "$@"
    [ "$status" -ne 127 ]
    [[ "$output" != *"Unknown command"* ]]
}
