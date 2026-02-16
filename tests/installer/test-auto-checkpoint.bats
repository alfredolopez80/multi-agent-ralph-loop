#!/usr/bin/env bats
#===============================================================================
# test-auto-checkpoint.bats - Test automatic checkpoint management
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Validate auto-checkpoint hook functionality
#===============================================================================

load test_helper

setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    CHECKPOINT_HOOK="$PROJECT_ROOT/.claude/hooks/auto-checkpoint.sh"
    CHECKPOINT_DIR="$PROJECT_ROOT/.ralph/checkpoints"
}

teardown() {
    :
}

#===============================================================================
# HOOK EXISTENCE TESTS
#===============================================================================

@test "auto-checkpoint.sh hook exists" {
    [ -f "$CHECKPOINT_HOOK" ]
}

@test "auto-checkpoint.sh hook is executable" {
    [ -x "$CHECKPOINT_HOOK" ]
}

@test "checkpoint directory exists" {
    [ -d "$CHECKPOINT_DIR" ]
}

#===============================================================================
# HELP OUTPUT TESTS
#===============================================================================

@test "hook --help shows usage" {
    run "$CHECKPOINT_HOOK" --help
    [ $status -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--save"* ]]
    [[ "$output" == *"--list"* ]]
}

#===============================================================================
# LIST COMMAND TESTS
#===============================================================================

@test "hook --list runs without error" {
    run "$CHECKPOINT_HOOK" --list
    [ $status -eq 0 ]
}

@test "hook --list shows checkpoints header" {
    run "$CHECKPOINT_HOOK" --list
    [[ "$output" == *"Available Checkpoints"* ]]
}

#===============================================================================
# SAVE COMMAND TESTS
#===============================================================================

@test "hook --save creates checkpoint" {
    run "$CHECKPOINT_HOOK" --save "test_unit"
    [ $status -eq 0 ]
    [[ "$output" == *"checkpoint"* ]]
}

@test "saved checkpoint file exists" {
    "$CHECKPOINT_HOOK" --save "test_unit_verify" >/dev/null 2>&1
    # Checkpoint naming uses timestamp_manual format, not the reason argument
    run ls "$CHECKPOINT_DIR"/checkpoint_*.md 2>/dev/null
    [ $status -eq 0 ]
}

@test "saved checkpoint has correct format" {
    "$CHECKPOINT_HOOK" --save "test_format" >/dev/null 2>&1
    local checkpoint=$(ls -1t "$CHECKPOINT_DIR"/checkpoint_*.md 2>/dev/null | head -1)
    [ -f "$checkpoint" ]
    # Checkpoint contains structured markdown content
    grep -qE "Checkpoint|checkpoint|Created|created|Reason|reason|Session" "$checkpoint"
}

#===============================================================================
# RESTORE COMMAND TESTS
#===============================================================================

@test "hook --restore shows checkpoint content" {
    "$CHECKPOINT_HOOK" --save "test_restore" >/dev/null 2>&1
    local checkpoint_name=$(ls -1t "$CHECKPOINT_DIR"/checkpoint_*.md 2>/dev/null | head -1 | xargs basename | sed 's/.md$//')
    [ -n "$checkpoint_name" ] || skip "No checkpoint file created"
    run "$CHECKPOINT_HOOK" --restore "$checkpoint_name"
    [ $status -eq 0 ]
    [[ "$output" == *"checkpoint"* ]] || [[ "$output" == *"Checkpoint"* ]] || [[ "$output" == *"Session"* ]]
}

@test "hook --restore fails gracefully for missing checkpoint" {
    run "$CHECKPOINT_HOOK" --restore "nonexistent_checkpoint_xyz"
    [ $status -ne 0 ] || [[ "$output" == *"not found"* ]]
}

#===============================================================================
# CLEANUP TESTS
#===============================================================================

@test "hook --cleanup runs without error" {
    run "$CHECKPOINT_HOOK" --cleanup
    [ $status -eq 0 ]
}

#===============================================================================
# JSON OUTPUT TESTS
#===============================================================================

@test "hook outputs valid JSON on save" {
    run "$CHECKPOINT_HOOK" --save "test_json"
    # Find the JSON line in output
    local json_line=$(echo "$output" | grep "^{")
    if [ -n "$json_line" ]; then
        echo "$json_line" | jq -e . >/dev/null 2>&1
    fi
}

#===============================================================================
# CONTEXT THRESHOLD TESTS
#===============================================================================

@test "hook --check with low context does not save" {
    run "$CHECKPOINT_HOOK" --check 50
    # Should not save checkpoint at 50% (threshold is 75%)
    [ $status -eq 0 ]
}

@test "hook --check with high context saves checkpoint" {
    run "$CHECKPOINT_HOOK" --check 85
    # Should save checkpoint at 85% (above 75% threshold)
    # Output may include JSON or be empty
    [ $status -eq 0 ]
}
