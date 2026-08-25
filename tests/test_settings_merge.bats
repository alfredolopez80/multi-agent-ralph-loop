#!/usr/bin/env bats
# test_settings_merge.bats - Tests for safe settings.json merge functionality
# Verifies that install.sh preserves user settings while adding Ralph configuration

setup() {
    TEST_DIR="$(mktemp -d)"
    CLAUDE_DIR="${TEST_DIR}/.claude"
    RALPH_DIR="${TEST_DIR}/.ralph"
    mkdir -p "$CLAUDE_DIR" "$RALPH_DIR"

    # Source the merge function from install.sh
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

    # Create Ralph's settings template
    RALPH_SETTINGS="${TEST_DIR}/ralph_settings.json"
    cat > "$RALPH_SETTINGS" << 'EOF'
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
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${HOME}/.claude/hooks/git-safety-guard.py",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${HOME}/.claude/hooks/quality-gates.sh",
            "timeout": 300
          }
        ]
      }
    ]
  }
}
EOF
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Helper function to perform merge (extracted from install.sh)
do_merge() {
    local RALPH_SETTINGS="$1"
    local USER_SETTINGS="$2"
    local OUTPUT="${TEST_DIR}/merged.json"

    if [ ! -f "$USER_SETTINGS" ]; then
        cp "$RALPH_SETTINGS" "$OUTPUT"
        echo "$OUTPUT"
        return 0
    fi

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
    ' "$USER_SETTINGS" "$RALPH_SETTINGS" > "$OUTPUT" 2>/dev/null

    echo "$OUTPUT"
}

@test "No existing settings - creates new file" {
    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/nonexistent.json")

    [ -f "$result" ]
    # Should have ralph's settings
    jq -e '.permissions.allow | contains(["Bash(ralph:*)"])' "$result"
}

@test "Preserves user's existing permissions" {
    # Create user settings with custom permissions
    cat > "${CLAUDE_DIR}/settings.json" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(docker:*)",
      "Bash(npm:*)",
      "CustomPermission"
    ]
  }
}
EOF

    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/settings.json")

    # User's original permissions preserved
    jq -e '.permissions.allow | contains(["Bash(docker:*)"])' "$result"
    jq -e '.permissions.allow | contains(["Bash(npm:*)"])' "$result"
    jq -e '.permissions.allow | contains(["CustomPermission"])' "$result"

    # Ralph's permissions added
    jq -e '.permissions.allow | contains(["Bash(ralph:*)"])' "$result"
    jq -e '.permissions.allow | contains(["Bash(mmc:*)"])' "$result"
}

@test "Preserves user's existing hooks" {
    # Create user settings with custom hooks
    cat > "${CLAUDE_DIR}/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/my/custom/hook.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "/my/custom/post-hook.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
EOF

    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/settings.json")

    # User's custom hooks preserved
    jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command == "/my/custom/hook.sh")' "$result"
    jq -e '.hooks.PostToolUse[] | select(.matcher == "Write") | .hooks[] | select(.command == "/my/custom/post-hook.sh")' "$result"

    # Ralph's hooks added
    jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | contains("git-safety-guard"))' "$result"
    jq -e '.hooks.PostToolUse[] | select(.matcher == "Edit") | .hooks[] | select(.command | contains("quality-gates"))' "$result"
}

@test "Does not duplicate permissions on reinstall" {
    # Create settings that already have Ralph's permissions
    cat > "${CLAUDE_DIR}/settings.json" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(ralph:*)",
      "Bash(mmc:*)",
      "Read"
    ]
  }
}
EOF

    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/settings.json")

    # Count occurrences - should be exactly 1
    local count=$(jq '[.permissions.allow[] | select(. == "Bash(ralph:*)")] | length' "$result")
    [ "$count" -eq 1 ]
}

@test "Does not duplicate hooks on reinstall" {
    # Create settings that already have Ralph's hooks
    cat > "${CLAUDE_DIR}/settings.json" << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${HOME}/.claude/hooks/git-safety-guard.py",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
EOF

    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/settings.json")

    # Count git-safety-guard hooks - should be exactly 1
    local count=$(jq '[.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | contains("git-safety-guard"))] | length' "$result")
    [ "$count" -eq 1 ]
}

@test "Preserves user's MCP server configuration" {
    # Create user settings with MCP servers
    cp "${SCRIPT_DIR}/tests/installer/fixtures/preserves_user_mcp_settings.json" "${CLAUDE_DIR}/settings.json"

    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/settings.json")

    # MCP servers preserved
    jq -e '.mcpServers.filesystem' "$result"
    jq -e '.mcpServers.github' "$result"
}

@test "Preserves user's custom settings" {
    # Create user settings with various custom fields
    cat > "${CLAUDE_DIR}/settings.json" << 'EOF'
{
  "permissions": {
    "allow": ["Read"]
  },
  "env": {
    "MY_CUSTOM_VAR": "value123",
    "API_KEY": "secret"
  },
  "customField": {
    "nested": {
      "deeply": true
    }
  }
}
EOF

    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/settings.json")

    # Custom fields preserved
    jq -e '.env.MY_CUSTOM_VAR == "value123"' "$result"
    jq -e '.env.API_KEY == "secret"' "$result"
    jq -e '.customField.nested.deeply == true' "$result"
}

@test "Adds schema if user doesn't have one" {
    cat > "${CLAUDE_DIR}/settings.json" << 'EOF'
{
  "permissions": {
    "allow": ["Read"]
  }
}
EOF

    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/settings.json")

    # Schema should be added
    jq -e '.["$schema"] | contains("claude-code-settings")' "$result"
}

@test "Preserves user's schema if they have one" {
    cat > "${CLAUDE_DIR}/settings.json" << 'EOF'
{
  "$schema": "https://example.com/custom-schema.json",
  "permissions": {
    "allow": ["Read"]
  }
}
EOF

    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/settings.json")

    # User's schema preserved
    jq -e '.["$schema"] == "https://example.com/custom-schema.json"' "$result"
}

@test "Handles empty user settings gracefully" {
    cat > "${CLAUDE_DIR}/settings.json" << 'EOF'
{}
EOF

    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/settings.json")

    # Should add Ralph's config
    jq -e '.permissions.allow | contains(["Bash(ralph:*)"])' "$result"
}

@test "Merges multiple matchers correctly" {
    # User has Write matcher, Ralph has Edit matcher
    cat > "${CLAUDE_DIR}/settings.json" << 'EOF'
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

    local result=$(do_merge "$RALPH_SETTINGS" "${CLAUDE_DIR}/settings.json")

    # Both matchers should exist
    jq -e '.hooks.PostToolUse[] | select(.matcher == "Write")' "$result"
    jq -e '.hooks.PostToolUse[] | select(.matcher == "Edit")' "$result"
}
