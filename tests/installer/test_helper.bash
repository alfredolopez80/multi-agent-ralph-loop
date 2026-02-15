#!/usr/bin/env bash
#===============================================================================
# test_helper.bash - Shared helpers for Installer Validation Tests
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Common setup/teardown and assertion helpers for installer tests
#
# Usage:
#   Load in BATS tests: load test_helper
#===============================================================================

# Project root detection
get_project_root() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
    echo "$root"
}

# Setup test environment
setup_installer_test() {
    PROJECT_ROOT="$(get_project_root)"
    INSTALLER_DIR="$PROJECT_ROOT/tests/installer"
    SCRIPTS_DIR="$PROJECT_ROOT/scripts"
    HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"

    # Create temp test environment
    TEST_TMPDIR=$(mktemp -d)
    TEST_HOME="$TEST_TMPDIR/home"
    TEST_BIN="$TEST_TMPDIR/bin"

    mkdir -p "$TEST_HOME/.ralph/config" \
             "$TEST_HOME/.ralph/logs" \
             "$TEST_HOME/.ralph/memory" \
             "$TEST_HOME/.ralph/plans" \
             "$TEST_HOME/.ralph/episodes" \
             "$TEST_HOME/.ralph/ledgers" \
             "$TEST_HOME/.ralph/handoffs" \
             "$TEST_HOME/.ralph/improvements" \
             "$TEST_HOME/.local/bin" \
             "$TEST_HOME/.claude/agents" \
             "$TEST_HOME/.claude/commands" \
             "$TEST_HOME/.claude/skills" \
             "$TEST_HOME/.claude/hooks" \
             "$TEST_BIN"

    # Save original environment
    ORIGINAL_HOME="$HOME"
    ORIGINAL_PATH="$PATH"

    export HOME="$TEST_HOME"
    export PATH="$TEST_BIN:$PATH"
}

# Teardown test environment
teardown_installer_test() {
    export HOME="$ORIGINAL_HOME"
    export PATH="$ORIGINAL_PATH"

    if [[ -n "${TEST_TMPDIR:-}" && -d "${TEST_TMPDIR:-}" ]]; then
        rm -rf "$TEST_TMPDIR" 2>/dev/null || true
    fi
}

# Create a mock executable
# Security: Uses printf %s to safely handle output strings without command substitution
create_mock_bin() {
    local name="$1"
    local output="${2:-}"
    local version="${3:-1.0.0}"

    # Build script safely using printf to avoid command injection via $output
    {
        printf '%s\n' '#!/usr/bin/env bash'
        printf '%s\n' 'case "$1" in'
        printf '\t%s\n' "--version|-V) echo \"$name $version\"; exit 0;;"
        printf '\t%s\n' "--help|-h) echo \"Usage: $name [options]\"; exit 0;;"
        printf '%s\n' 'esac'
        # Only add output line if output is non-empty; use printf %s to prevent command execution
        if [[ -n "$output" ]]; then
            printf "printf '%%s\\n' '%s'\n" "${output//\'/\'\\\'\'}"
        fi
        printf '%s\n' 'exit 0'
    } > "$TEST_BIN/$name"
    chmod +x "$TEST_BIN/$name"
}

# Create mock tool input JSON for hooks
create_mock_tool_input() {
    local tool_name="$1"
    local input_file="$TEST_TMPDIR/tool_input.json"

    case "$tool_name" in
        Edit)
            cat > "$input_file" << 'EOF'
{
    "tool": "Edit",
    "input": {
        "file_path": "/tmp/test.py",
        "old_string": "old",
        "new_string": "new"
    }
}
EOF
            ;;
        Write)
            cat > "$input_file" << 'EOF'
{
    "tool": "Write",
    "input": {
        "file_path": "/tmp/test.py",
        "content": "print('hello')"
    }
}
EOF
            ;;
        Bash)
            cat > "$input_file" << 'EOF'
{
    "tool": "Bash",
    "input": {
        "command": "echo test",
        "description": "Test command"
    }
}
EOF
            ;;
        Task)
            cat > "$input_file" << 'EOF'
{
    "tool": "Task",
    "input": {
        "subagent_type": "ralph-coder",
        "prompt": "Test task"
    }
}
EOF
            ;;
        *)
            cat > "$input_file" << 'EOF'
{
    "tool": "Unknown",
    "input": {}
}
EOF
            ;;
    esac

    echo "$input_file"
}

# Assert a command exists
assert_command_exists() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        echo "Command not found: $cmd" >&2
        return 1
    fi
    return 0
}

# Assert a file exists
assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "File not found: $file" >&2
        return 1
    fi
    return 0
}

# Assert a directory exists
assert_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Directory not found: $dir" >&2
        return 1
    fi
    return 0
}

# Assert a file is executable
assert_executable() {
    local file="$1"
    if [[ ! -x "$file" ]]; then
        echo "File not executable: $file" >&2
        return 1
    fi
    return 0
}

# Assert valid JSON
assert_valid_json() {
    local file="$1"
    if ! jq empty < "$file" 2>/dev/null; then
        echo "Invalid JSON in file: $file" >&2
        return 1
    fi
    return 0
}

# Assert JSON has key
assert_json_has_key() {
    local file="$1"
    local key="$2"
    if ! jq -e ".$key" < "$file" >/dev/null 2>&1; then
        echo "JSON missing key '$key' in file: $file" >&2
        return 1
    fi
    return 0
}

# Check if a tool is available (optional, not required)
tool_available() {
    local tool="$1"
    command -v "$tool" &>/dev/null
}

# Skip if tool not available
skip_if_missing() {
    local tool="$1"
    if ! tool_available "$tool"; then
        skip "Tool not available: $tool"
    fi
}

# Get minimum required version for a tool
get_min_version() {
    local tool="$1"
    case "$tool" in
        bash) echo "4.0" ;;
        git)  echo "2.0" ;;
        node) echo "18" ;;
        python3) echo "3.9" ;;
        jq)   echo "1.5" ;;
        *)    echo "0" ;;
    esac
}

# Compare versions (returns 0 if $1 >= $2)
version_ge() {
    local v1="$1"
    local v2="$2"

    # Handle simple numeric comparisons
    if [[ "$v1" == "$v2" ]]; then
        return 0
    fi

    # Split versions into arrays
    IFS='.' read -ra v1_parts <<< "$v1"
    IFS='.' read -ra v2_parts <<< "$v2"

    # Compare each part
    local max_parts=${#v1_parts[@]}
    [[ ${#v2_parts[@]} -gt $max_parts ]] && max_parts=${#v2_parts[@]}

    for ((i=0; i<max_parts; i++)); do
        local p1="${v1_parts[i]:-0}"
        local p2="${v2_parts[i]:-0}"

        # Remove non-numeric suffixes
        p1="${p1%%[!0-9]*}"
        p2="${p2%%[!0-9]*}"

        if (( p1 > p2 )); then
            return 0
        elif (( p1 < p2 )); then
            return 1
        fi
    done

    return 0
}

# Extract version from command output
extract_version() {
    local cmd="$1"
    local version_output

    version_output=$("$cmd" --version 2>&1 | head -1) || return 1

    # Common version patterns
    if [[ "$version_output" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$version_output" =~ ([0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$version_output" =~ ([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "0"
    fi
}

# Check shell type
get_shell_type() {
    basename "${SHELL:-/bin/bash}"
}

# Check if Ralph is installed
ralph_installed() {
    [[ -d "$HOME/.ralph" ]]
}

# Check if Claude settings exist
claude_settings_exist() {
    [[ -f "$HOME/.claude/settings.json" ]]
}

# Get hooks from settings.json
get_hooks_for_event() {
    local event="$1"
    local settings_file="${2:-$HOME/.claude/settings.json}"

    if [[ -f "$settings_file" ]]; then
        jq -r ".hooks[\"$event\"] // [] | .[].hooks[]?.command // empty" "$settings_file" 2>/dev/null
    fi
}

# Count hooks for event
count_hooks_for_event() {
    local event="$1"
    local settings_file="${2:-$HOME/.claude/settings.json}"

    if [[ -f "$settings_file" ]]; then
        jq ".hooks[\"$event\"] // [] | length" "$settings_file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}
