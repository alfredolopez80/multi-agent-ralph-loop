#!/usr/bin/env bats
# test_v256_task_primitives.bats - Tests for v2.56+ Task Primitive Integration
# VERSION: 2.66.0
#
# Tests for:
# - global-task-sync.sh hook
# - task-primitive-sync.sh hook
# - task-project-tracker.sh hook
# - plan-state.json schema compliance

setup() {
    export HOOKS_DIR="${HOME}/.claude/hooks"
    export PLAN_STATE=".claude/plan-state.json"
    export TEST_TMP=$(mktemp -d)
}

teardown() {
    rm -rf "$TEST_TMP" 2>/dev/null || true
}

# ============================================================
# Hook Existence Tests
# ============================================================

@test "global-task-sync.sh exists and is executable" {
    [ -f "${HOOKS_DIR}/global-task-sync.sh" ]
    [ -x "${HOOKS_DIR}/global-task-sync.sh" ]
}

@test "task-primitive-sync.sh exists and is executable" {
    [ -f "${HOOKS_DIR}/task-primitive-sync.sh" ]
    [ -x "${HOOKS_DIR}/task-primitive-sync.sh" ]
}

@test "task-project-tracker.sh exists and is executable" {
    [ -f "${HOOKS_DIR}/task-project-tracker.sh" ]
    [ -x "${HOOKS_DIR}/task-project-tracker.sh" ]
}

# ============================================================
# Hook Version Tests
# ============================================================

@test "global-task-sync.sh has v2.66.0+ version" {
    # Accept v2.66.0 or later (v2.68.x)
    run grep -E "VERSION: 2\.(6[6-9]|[7-9][0-9])" "${HOOKS_DIR}/global-task-sync.sh"
    [ "$status" -eq 0 ]
}

@test "task-primitive-sync.sh has v1.2.0+ version" {
    run grep -E "VERSION: 1\.[2-9]|VERSION: [2-9]" "${HOOKS_DIR}/task-primitive-sync.sh"
    [ "$status" -eq 0 ]
}

@test "task-project-tracker.sh has v1.1.0+ version" {
    run grep -E "VERSION: 1\.[1-9]|VERSION: [2-9]" "${HOOKS_DIR}/task-project-tracker.sh"
    [ "$status" -eq 0 ]
}

# ============================================================
# Hook JSON Output Format Tests
# ============================================================

@test "global-task-sync.sh outputs valid JSON on empty input" {
    run bash -c 'echo "{}" | ${HOOKS_DIR}/global-task-sync.sh'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.' > /dev/null
}

@test "global-task-sync.sh outputs continue:true format" {
    run bash -c 'echo "{}" | ${HOOKS_DIR}/global-task-sync.sh'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.continue == true' > /dev/null
}

@test "task-primitive-sync.sh outputs valid JSON on empty input" {
    run bash -c 'echo "{}" | ${HOOKS_DIR}/task-primitive-sync.sh'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.' > /dev/null
}

@test "task-project-tracker.sh outputs valid JSON on empty input" {
    run bash -c 'echo "{}" | ${HOOKS_DIR}/task-project-tracker.sh'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.' > /dev/null
}

# ============================================================
# Error Trap Tests (SEC-033 Compliance)
# ============================================================

@test "global-task-sync.sh has SEC-033 error trap" {
    run grep -E "trap.*output_json.*ERR|SEC-033" "${HOOKS_DIR}/global-task-sync.sh"
    [ "$status" -eq 0 ]
}

@test "task-primitive-sync.sh has SEC-033 error trap" {
    run grep -E "trap.*output_json.*ERR|SEC-033" "${HOOKS_DIR}/task-primitive-sync.sh"
    [ "$status" -eq 0 ]
}

@test "task-project-tracker.sh has SEC-033 error trap" {
    run grep -E "trap.*output_json.*ERR|SEC-033" "${HOOKS_DIR}/task-project-tracker.sh"
    [ "$status" -eq 0 ]
}

# ============================================================
# Session ID Extraction Tests
# ============================================================

@test "global-task-sync.sh extracts session_id from input" {
    run grep "SESSION_ID_FROM_INPUT" "${HOOKS_DIR}/global-task-sync.sh"
    [ "$status" -eq 0 ]
}

@test "task-primitive-sync.sh extracts session_id from input" {
    run grep "SESSION_ID_FROM_INPUT" "${HOOKS_DIR}/task-primitive-sync.sh"
    [ "$status" -eq 0 ]
}

@test "task-project-tracker.sh extracts session_id from input" {
    run grep "SESSION_ID_FROM_INPUT" "${HOOKS_DIR}/task-project-tracker.sh"
    [ "$status" -eq 0 ]
}

# ============================================================
# TodoWrite Removal Tests (v2.66.0)
# ============================================================

@test "global-task-sync.sh case statement excludes TodoWrite" {
    # Verify that the case statement only matches TaskUpdate|TaskCreate (not TodoWrite)
    run grep -E "TaskUpdate\|TaskCreate\)" "${HOOKS_DIR}/global-task-sync.sh"
    [ "$status" -eq 0 ]
    # Ensure TodoWrite is NOT in the active case matcher
    run bash -c "grep -E 'case.*TOOL_NAME' -A5 ${HOOKS_DIR}/global-task-sync.sh | grep -v '#' | grep TodoWrite"
    [ "$status" -ne 0 ]
}

# ============================================================
# Plan-State Schema Tests
# ============================================================

@test "plan-state.json exists" {
    [ -f "${PLAN_STATE}" ]
}

@test "plan-state.json has phases array" {
    run jq -e '.phases | type == "array"' "${PLAN_STATE}"
    [ "$status" -eq 0 ]
}

@test "plan-state.json has barriers object" {
    run jq -e '.barriers | type == "object"' "${PLAN_STATE}"
    [ "$status" -eq 0 ]
}

@test "plan-state.json has steps object" {
    run jq -e '.steps | type == "object"' "${PLAN_STATE}"
    [ "$status" -eq 0 ]
}

@test "plan-state.json has version 2.66.0+" {
    # Accept v2.66.0 or later (v2.68.x)
    run jq -e '.version | test("^2\\.(6[6-9]|[7-9][0-9])")' "${PLAN_STATE}"
    [ "$status" -eq 0 ]
}

# ============================================================
# Hook Registration Tests
# ============================================================

@test "task-project-tracker.sh is registered in settings.json" {
    run grep "task-project-tracker.sh" "${HOME}/.claude/settings.json"
    [ "$status" -eq 0 ]
}

@test "task-primitive-sync.sh is registered in settings.json" {
    run grep "task-primitive-sync.sh" "${HOME}/.claude/settings.json"
    [ "$status" -eq 0 ]
}

@test "global-task-sync.sh is registered in settings.json" {
    run grep "global-task-sync.sh" "${HOME}/.claude/settings.json"
    [ "$status" -eq 0 ]
}
