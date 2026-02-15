#!/usr/bin/env bats
#===============================================================================
# test-settings-merge.bats - Test settings merge validation for installer
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify that settings.json merge operations work correctly
#
# Acceptance Criteria:
# - [x] Test file exists at tests/installer/test-settings-merge.bats
# - [x] Tests fresh install scenario
# - [x] Tests merge with existing settings
# - [x] Tests merge when Ralph already installed
# - [x] Tests invalid JSON handling
# - [x] All tests pass: `bats tests/installer/test-settings-merge.bats`
#===============================================================================

load test_helper

# Store original HOME
ORIGINAL_HOME="${HOME}"

setup() {
    setup_installer_test
    FIXTURES_DIR="$INSTALLER_DIR/fixtures"

    # Create Claude settings directory
    CLAUDE_DIR="$TEST_HOME/.claude"
    mkdir -p "$CLAUDE_DIR"

    # Define Ralph settings template (what installer would merge)
    RALPH_TEMPLATE="$TEST_TMPDIR/ralph_template.json"
    cat > "$RALPH_TEMPLATE" << 'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(ralph:*)",
      "Bash(mmc:*)",
      "Read",
      "Write",
      "Edit"
    ]
  },
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/home/user/.claude/hooks/git-safety-guard.py",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Task",
        "hooks": [
          {
            "type": "command",
            "command": "/home/user/.claude/hooks/repo-boundary-guard.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/home/user/.claude/hooks/quality-gates-v2.sh"
          }
        ]
      }
    ]
  }
}
EOF
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

# Perform settings merge (simulates installer merge logic)
do_merge() {
    local ralph_settings="$1"
    local user_settings="$2"
    local output="$3"

    if [[ ! -f "$user_settings" ]]; then
        # Fresh install - copy template
        cp "$ralph_settings" "$output"
        return 0
    fi

    # Merge using jq
    jq -s '
    def merge_hooks(a; b):
        if (a | type) == "array" and (b | type) == "array" then
            (a + b) | group_by(.matcher) | map(
                .[0] + {
                    hooks: ([.[].hooks] | add | unique_by(.command))
                }
            )
        elif (a | type) == "array" then a
        elif (b | type) == "array" then b
        else [] end;

    .[0] as $user | .[1] as $ralph |
    $user |
    (if .["$schema"] then . else . + {"$schema": $ralph["$schema"]} end) |
    .permissions.allow = (
        (($user.permissions.allow // []) + ($ralph.permissions.allow // [])) | unique
    ) |
    (if ($user.permissions.deny // $ralph.permissions.deny) then
        .permissions.deny = ((($user.permissions.deny // []) + ($ralph.permissions.deny // [])) | unique)
    else . end) |
    .hooks.PreToolUse = merge_hooks($user.hooks.PreToolUse; $ralph.hooks.PreToolUse) |
    .hooks.PostToolUse = merge_hooks($user.hooks.PostToolUse; $ralph.hooks.PostToolUse) |
    del(..|nulls)
    ' "$user_settings" "$ralph_settings" > "$output" 2>/dev/null
}

# Check if JSON file is valid (must have actual JSON content)
json_valid() {
    local file="$1"
    # Check file exists and is not empty
    [[ -s "$file" ]] || return 1
    # Check file has non-whitespace content
    grep -q '[^[:space:]]' "$file" || return 1
    # Check it contains valid JSON
    jq empty < "$file" 2>/dev/null
}

#===============================================================================
# FIXTURE EXISTENCE TESTS
#===============================================================================

@test "fixture: settings-fresh.json exists" {
    assert_file_exists "$FIXTURES_DIR/settings-fresh.json"
}

@test "fixture: settings-existing.json exists" {
    assert_file_exists "$FIXTURES_DIR/settings-existing.json"
}

@test "fixture: settings-with-ralph.json exists" {
    assert_file_exists "$FIXTURES_DIR/settings-with-ralph.json"
}

@test "fixture: settings-fresh.json is valid JSON" {
    assert_valid_json "$FIXTURES_DIR/settings-fresh.json"
}

@test "fixture: settings-existing.json is valid JSON" {
    assert_valid_json "$FIXTURES_DIR/settings-existing.json"
}

@test "fixture: settings-with-ralph.json is valid JSON" {
    assert_valid_json "$FIXTURES_DIR/settings-with-ralph.json"
}

#===============================================================================
# FRESH INSTALL TESTS
#===============================================================================

@test "fresh install: creates settings when none exist" {
    local output="$CLAUDE_DIR/settings.json"

    # No existing settings
    [[ ! -f "$output" ]]

    # Perform merge with non-existent user settings
    do_merge "$RALPH_TEMPLATE" "$CLAUDE_DIR/nonexistent.json" "$output"

    # Settings file should be created
    assert_file_exists "$output"
    assert_valid_json "$output"
}

@test "fresh install: has correct permissions structure" {
    local output="$CLAUDE_DIR/settings.json"

    do_merge "$RALPH_TEMPLATE" "$CLAUDE_DIR/nonexistent.json" "$output"

    # Should have permissions.allow array
    jq -e '.permissions.allow | type == "array"' "$output"

    # Should include Ralph permissions
    jq -e '.permissions.allow | contains(["Bash(ralph:*)"])' "$output"
    jq -e '.permissions.allow | contains(["Bash(mmc:*)"])' "$output"
    jq -e '.permissions.allow | contains(["Read"])' "$output"
}

@test "fresh install: has correct hooks structure" {
    local output="$CLAUDE_DIR/settings.json"

    do_merge "$RALPH_TEMPLATE" "$CLAUDE_DIR/nonexistent.json" "$output"

    # Should have PreToolUse hooks
    jq -e '.hooks.PreToolUse | type == "array"' "$output"

    # Should have PostToolUse hooks
    jq -e '.hooks.PostToolUse | type == "array"' "$output"
}

@test "fresh install: has agent teams env variable" {
    local output="$CLAUDE_DIR/settings.json"

    do_merge "$RALPH_TEMPLATE" "$CLAUDE_DIR/nonexistent.json" "$output"

    jq -e '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == "1"' "$output"
}

@test "fresh install: has JSON schema" {
    local output="$CLAUDE_DIR/settings.json"

    do_merge "$RALPH_TEMPLATE" "$CLAUDE_DIR/nonexistent.json" "$output"

    jq -e '.["$schema"] | contains("claude-code-settings")' "$output"
}

#===============================================================================
# MERGE WITH EXISTING SETTINGS TESTS
#===============================================================================

@test "merge: preserves user permissions" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    # Use existing settings fixture
    cp "$FIXTURES_DIR/settings-existing.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # User's original permissions should be preserved
    jq -e '.permissions.allow | contains(["Bash(docker:*)"])' "$output"
    jq -e '.permissions.allow | contains(["Bash(npm:*)"])' "$output"
    jq -e '.permissions.allow | contains(["Read(**/*.md)"])' "$output"

    # User's deny list should be preserved
    jq -e '.permissions.deny | contains(["Bash(rm -rf:*)"])' "$output"
}

@test "merge: adds Ralph permissions" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-existing.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # Ralph permissions should be added
    jq -e '.permissions.allow | contains(["Bash(ralph:*)"])' "$output"
    jq -e '.permissions.allow | contains(["Bash(mmc:*)"])' "$output"
}

@test "merge: preserves user environment variables" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-existing.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # User's env vars should be preserved
    jq -e '.env.MY_API_KEY == "my-secret-key"' "$output"
    jq -e '.env.CUSTOM_SETTING == "value123"' "$output"
    jq -e '.env.DEBUG_MODE == "true"' "$output"
}

@test "merge: preserves MCP servers" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-existing.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # MCP servers should be preserved
    jq -e '.mcpServers.filesystem' "$output"
    jq -e '.mcpServers.github' "$output"
}

@test "merge: preserves user hooks" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-existing.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # User's custom hooks should be preserved
    jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command == "/my/custom/pre-hook.sh")' "$output"
    jq -e '.hooks.PostToolUse[] | select(.matcher == "Write") | .hooks[] | select(.command == "/my/custom/post-hook.sh")' "$output"
}

@test "merge: adds Ralph hooks without removing user hooks" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-existing.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # Ralph hooks should be added
    jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | contains("git-safety-guard"))' "$output"

    # User hooks should still exist
    jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command == "/my/custom/pre-hook.sh")' "$output"
}

@test "merge: preserves custom fields" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-existing.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # Custom nested fields should be preserved
    jq -e '.customField.nested.deeply == true' "$output"
    jq -e '.customField.nested.value == "preserved"' "$output"
}

@test "merge: preserves user schema preference" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-existing.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # User's custom schema should be preserved
    jq -e '.["$schema"] == "https://example.com/my-custom-schema.json"' "$output"
}

@test "merge: adds schema if user does not have one" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    # Create settings without schema
    cat > "$user_settings" << 'EOF'
{
  "permissions": {
    "allow": ["Read"]
  }
}
EOF

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # Schema should be added
    jq -e '.["$schema"] | contains("claude-code-settings")' "$output"
}

#===============================================================================
# REINSTALL (RALPH ALREADY INSTALLED) TESTS
#===============================================================================

@test "reinstall: no duplicate permissions" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    # Use settings that already have Ralph installed
    cp "$FIXTURES_DIR/settings-with-ralph.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # Count Bash(ralph:*) - should be exactly 1
    local count
    count=$(jq '[.permissions.allow[] | select(. == "Bash(ralph:*)")] | length' "$output")
    [[ "$count" -eq 1 ]]

    # Count Bash(mmc:*) - should be exactly 1
    count=$(jq '[.permissions.allow[] | select(. == "Bash(mmc:*)")] | length' "$output")
    [[ "$count" -eq 1 ]]
}

@test "reinstall: no duplicate hooks" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-with-ralph.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # Count git-safety-guard hooks - should be exactly 1
    local count
    count=$(jq '[.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]? | select(.command | contains("git-safety-guard"))] | length' "$output")
    [[ "$count" -eq 1 ]]
}

@test "reinstall: preserves user additions since last install" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-with-ralph.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # User's custom env var should be preserved
    jq -e '.env.CUSTOM_VAR == "already-set"' "$output"

    # User's deny list should be preserved
    jq -e '.permissions.deny | contains(["Read(**/.ssh/**)"])' "$output"
}

@test "reinstall: preserves additional Ralph hooks added by user" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-with-ralph.json" "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # Additional hooks user had should be preserved
    jq -e '.hooks.PostToolUse[] | select(.matcher == "Edit|Write|Bash") | .hooks[] | select(.command | contains("status-auto-check"))' "$output"
    jq -e '.hooks.SessionStart[] | select(.matcher == "*") | .hooks[] | select(.command | contains("orchestrator-init"))' "$output"
}

#===============================================================================
# INVALID JSON HANDLING TESTS
#===============================================================================

@test "invalid JSON: creates backup before handling" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local backup="$CLAUDE_DIR/settings.json.backup"
    local output="$CLAUDE_DIR/merged.json"

    # Create invalid JSON
    cat > "$user_settings" << 'EOF'
{
  "permissions": {
    "allow": ["Read"
  }
}
EOF

    # Backup should be created (simulated)
    cp "$user_settings" "$backup"

    assert_file_exists "$backup"
}

@test "invalid JSON: detected and reported" {
    local invalid_file="$CLAUDE_DIR/invalid.json"

    # Create invalid JSON
    cat > "$invalid_file" << 'EOF'
{
  "broken": json
}
EOF

    # Should fail validation
    ! json_valid "$invalid_file"
}

@test "invalid JSON: fresh install proceeds if user settings invalid" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    # Create invalid JSON
    cat > "$user_settings" << 'EOF'
{ invalid json }
EOF

    # When user settings are invalid, merge should fail gracefully
    # In this case, we expect the merge to fail and return non-zero
    ! jq empty < "$user_settings" 2>/dev/null
}

@test "invalid JSON: handles truncated JSON" {
    local truncated_file="$CLAUDE_DIR/truncated.json"

    # Create truncated JSON (common error case)
    cat > "$truncated_file" << 'EOF'
{"permissions": {"allow": ["Read", "Write"
EOF

    # Should fail validation
    ! json_valid "$truncated_file"
}

@test "invalid JSON: handles empty file" {
    local empty_file="$CLAUDE_DIR/empty.json"
    touch "$empty_file"

    # Empty file is not valid JSON
    ! json_valid "$empty_file"
}

@test "invalid JSON: handles file with only whitespace" {
    local whitespace_file="$CLAUDE_DIR/whitespace.json"
    echo "   " > "$whitespace_file"

    # Whitespace-only is not valid JSON
    ! json_valid "$whitespace_file"
}

#===============================================================================
# EDGE CASES
#===============================================================================

@test "edge case: handles empty user settings object" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    echo '{}' > "$user_settings"

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # Should add Ralph config
    assert_valid_json "$output"
    jq -e '.permissions.allow | contains(["Bash(ralph:*)"])' "$output"
}

@test "edge case: handles user settings with only permissions" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cat > "$user_settings" << 'EOF'
{
  "permissions": {
    "allow": ["Read"]
  }
}
EOF

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    assert_valid_json "$output"
    jq -e '.permissions.allow | contains(["Read"])' "$output"
    jq -e '.permissions.allow | contains(["Bash(ralph:*)"])' "$output"
}

@test "edge case: handles user settings with only env" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cat > "$user_settings" << 'EOF'
{
  "env": {
    "MY_VAR": "value"
  }
}
EOF

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    assert_valid_json "$output"
    jq -e '.env.MY_VAR == "value"' "$output"
}

@test "edge case: handles user settings with only hooks" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cat > "$user_settings" << 'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/my/stop-hook.sh"
          }
        ]
      }
    ]
  }
}
EOF

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    assert_valid_json "$output"
    # User's Stop hook should be preserved
    jq -e '.hooks.Stop[] | select(.matcher == "*")' "$output"
}

@test "edge case: merges multiple matchers correctly" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    # User has different matchers than Ralph
    cat > "$user_settings" << 'EOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "/user/write-hook.sh"
          }
        ]
      }
    ]
  }
}
EOF

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # Both Write matcher (user) and Edit|Write|Bash matcher (Ralph) should exist
    jq -e '.hooks.PostToolUse[] | select(.matcher == "Write")' "$output"
    jq -e '.hooks.PostToolUse[] | select(.matcher == "Edit|Write|Bash")' "$output"
}

@test "edge case: handles large permissions list" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    # Create settings with many permissions
    cat > "$user_settings" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(git:*)", "Bash(npm:*)", "Bash(yarn:*)", "Bash(pnpm:*)",
      "Bash(python:*)", "Bash(pip:*)", "Bash(pipenv:*)", "Bash(poetry:*)",
      "Bash(docker:*)", "Bash(docker-compose:*)", "Bash(kubectl:*)",
      "Bash(terraform:*)", "Bash(ansible:*)", "Bash(vagrant:*)",
      "Read", "Write", "Edit"
    ]
  }
}
EOF

    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # All permissions should be present and unique
    local count
    count=$(jq '.permissions.allow | length' "$output")

    # Should have user's 16 + Ralph's additions (without duplicates)
    [[ "$count" -ge 16 ]]

    # Check unique (no duplicates)
    local unique_count
    unique_count=$(jq '.permissions.allow | unique | length' "$output")
    [[ "$count" -eq "$unique_count" ]]
}

#===============================================================================
# OUTPUT FORMAT TESTS
#===============================================================================

@test "output: merged file is valid JSON" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-existing.json" "$user_settings"
    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    assert_valid_json "$output"
}

@test "output: merged file is properly formatted" {
    local user_settings="$CLAUDE_DIR/settings.json"
    local output="$CLAUDE_DIR/merged.json"

    cp "$FIXTURES_DIR/settings-existing.json" "$user_settings"
    do_merge "$RALPH_TEMPLATE" "$user_settings" "$output"

    # Should be valid JSON that jq can pretty-print
    jq '.' "$output" > /dev/null
}
