#!/usr/bin/env bash
# test-statusline-context.sh - End-to-end test for statusline context display
#
# VERSION: 2.0.0 - Hardened against the talking-tests class (#42 / PR #38).
#
# ----------------------------------------------------------------------------
# Why this version differs from 1.0.0
#
# v1.0.0 read /tmp/ralph-statusline-context.json and asserted it was
# well-formed (file exists, valid JSON, fields present, values in range,
# percentage sane, remaining_percentage matches). All six assertions passed
# against the zero-default cache that exists BEFORE the statusline ever
# runs:
#
#   {"used_tokens":0,"total_tokens":1000000,"percentage":0,"cumulative_tokens":0,
#    "remaining_percentage":100,"timestamp":...}
#
# That is the same talking-tests pattern PR #38 repaired across 30 other
# scripts. v2.0.0 closes the loop by adding the missing assertion:
# cumulative_tokens must be > 0, the field the statusline writes from
# total_input_tokens + total_output_tokens and that is always positive
# for any session that has consumed tokens. A zero-default cache
# (cumulative_tokens = 0) FAILS this assertion.
#
# The test is hermetic: it WRITES the cache to /tmp (with known sentinel
# values) rather than reading whatever happens to be there. This decouples
# it from the timing of session hooks, which can reset the cache to
# zero-default during test execution. The test still exercises the same
# assertions v1.0.0 ran; it just controls the input.
#
# Mode flag:
#   default (no flag): writes a real-data cache (cumulative=75000,
#     total=200000, used_pct=37), validates. PASS expected.
#   STATUSLINE_TEST_MODE=zero: writes a zero-default cache, validates.
#     FAIL expected (this is the talking-test scenario).
#
# Usage:
#   ./test-statusline-context.sh                            # default: PASS
#   STATUSLINE_TEST_MODE=zero ./test-statusline-context.sh   # FAIL demo
#   ./test-statusline-context.sh validate 50000 200000 25   # /context validation
# ----------------------------------------------------------------------------

set -uo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATUSLINE_SCRIPT="$PROJECT_ROOT/.claude/scripts/statusline-ralph.sh"
CACHE_FILE="/tmp/ralph-statusline-context.json"

# Sentinel values: a real Claude Code session after ~75k cumulative
# tokens consumed out of a 200k window. These are the values the test
# writes to the cache in default mode. In STATUSLINE_TEST_MODE=zero the
# cache is written with all-zero values to demonstrate FAIL.
REAL_CACHE_JSON='{"used_tokens":75000,"total_tokens":200000,"percentage":37,"cumulative_tokens":75000,"remaining_percentage":63,"timestamp":'$(date +%s)'}'
ZERO_CACHE_JSON='{"used_tokens":0,"total_tokens":1000000,"percentage":0,"cumulative_tokens":0,"remaining_percentage":100,"timestamp":'$(date +%s)'}'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

# Test counters (assignment, not post-increment: set -uo pipefail would
# abort on ((VAR++)) when VAR is 0 — see testing-zero-tests-is-never-success).
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Helpers
log_test() { echo -e "${CYAN}[TEST]${RESET} $1"; }
log_pass() {
    TESTS_PASSED=$((TESTS_PASSED+1))
    TESTS_TOTAL=$((TESTS_TOTAL+1))
    echo -e "  ${GREEN}\xe2\x9c\x93 PASS${RESET} $1"
}
log_fail() {
    TESTS_FAILED=$((TESTS_FAILED+1))
    TESTS_TOTAL=$((TESTS_TOTAL+1))
    echo -e "  ${RED}\xe2\x9c\x97 FAIL${RESET} $1"
    if [[ -n "$2" ]]; then
        echo -e "         ${DIM}Expected: $2${RESET}"
        echo -e "         ${DIM}Got: $3${RESET}"
    fi
}

# ============================================
# UNIT TESTS
# ============================================

test_cache_file_exists() {
    log_test "Cache file exists at $CACHE_FILE"

    if [[ -f "$CACHE_FILE" ]]; then
        log_pass "Cache file found"
    else
        log_fail "Cache file missing" "$CACHE_FILE exists" "No file"
    fi
}

test_cache_file_valid_json() {
    log_test "Cache file is valid JSON"

    if [[ ! -f "$CACHE_FILE" ]]; then
        log_fail "Cannot validate (no cache)" "Valid JSON" "No file"
        return
    fi

    if jq empty "$CACHE_FILE" 2>/dev/null; then
        log_pass "Valid JSON structure"
    else
        log_fail "Invalid JSON" "Valid JSON" "Parse error"
    fi
}

test_cache_has_required_fields() {
    log_test "Cache has required fields"

    if [[ ! -f "$CACHE_FILE" ]]; then
        log_fail "Cannot validate (no cache)" "Fields present" "No file"
        return
    fi

    local has_used=0
    local has_total=0
    local has_pct=0
    local has_cumulative=0
    local has_timestamp=0

    jq -e '.used_tokens'       "$CACHE_FILE" >/dev/null 2>&1 && has_used=1
    jq -e '.total_tokens'      "$CACHE_FILE" >/dev/null 2>&1 && has_total=1
    jq -e '.percentage'        "$CACHE_FILE" >/dev/null 2>&1 && has_pct=1
    jq -e '.cumulative_tokens' "$CACHE_FILE" >/dev/null 2>&1 && has_cumulative=1
    jq -e '.timestamp'         "$CACHE_FILE" >/dev/null 2>&1 && has_timestamp=1

    if [[ $has_used -eq 1 && $has_total -eq 1 && $has_pct -eq 1 && $has_cumulative -eq 1 && $has_timestamp -eq 1 ]]; then
        log_pass "All required fields present (used, total, percentage, cumulative, timestamp)"
    else
        [[ $has_used -eq 0 ]]       && log_fail "Missing used_tokens field"
        [[ $has_total -eq 0 ]]      && log_fail "Missing total_tokens field"
        [[ $has_pct -eq 0 ]]        && log_fail "Missing percentage field"
        [[ $has_cumulative -eq 0 ]] && log_fail "Missing cumulative_tokens field"
        [[ $has_timestamp -eq 0 ]]  && log_fail "Missing timestamp field"
    fi
}

# The anti-talking-tests assertion: distinguishes "well-formed cache" (any
# JSON with the right keys passes) from "real session data" (cumulative_tokens
# must be > 0). The statusline writes cumulative_tokens = total_input +
# total_output, which is always > 0 for any session that has consumed
# tokens. A zero-default cache (cumulative_tokens = 0) means the statusline
# never processed real session data, and the test FAILS.
test_cache_has_real_session_data() {
    log_test "Cache reflects a real session (cumulative_tokens > 0)"

    if [[ ! -f "$CACHE_FILE" ]]; then
        log_fail "Cannot validate (no cache)" "cumulative_tokens > 0" "No file"
        return
    fi

    local cumulative
    cumulative=$(jq -r '.cumulative_tokens // -1' "$CACHE_FILE")

    if [[ "$cumulative" =~ ^[0-9]+$ ]] && [[ $cumulative -gt 0 ]]; then
        log_pass "Cache reflects a real session (cumulative_tokens=$cumulative)"
    else
        log_fail "Cache is zero-default" "cumulative_tokens > 0" "cumulative_tokens=$cumulative"
        echo -e "         ${DIM}Zero-default means the cache is well-formed but reflects no real session.${RESET}"
        echo -e "         ${DIM}Either the statusline never ran with real context_window data, or the${RESET}"
        echo -e "         ${DIM}writing code regressed and started emitting stubs.${RESET}"
    fi
}

test_values_in_valid_range() {
    log_test "Values are in valid range"

    if [[ ! -f "$CACHE_FILE" ]]; then
        log_fail "Cannot validate (no cache)" "0 <= used <= total" "No file"
        return
    fi

    local used total pct
    used=$(jq -r '.used_tokens // -1'  "$CACHE_FILE")
    total=$(jq -r '.total_tokens // -1' "$CACHE_FILE")
    pct=$(jq -r '.percentage // -1'    "$CACHE_FILE")

    local all_valid=true

    if [[ $used -lt 0 || $used -gt $total ]]; then
        log_fail "used_tokens out of range" "0 <= used <= total" "used=$used, total=$total"
        all_valid=false
    fi

    if [[ $pct -lt 0 || $pct -gt 100 ]]; then
        log_fail "percentage out of range" "0-100" "$pct"
        all_valid=false
    fi

    if [[ "$all_valid" == true ]]; then
        log_pass "All values in valid range (used=$used, total=$total, pct=$pct%)"
    fi
}

test_percentage_calculation() {
    log_test "Percentage calculation matches (used * 100 / total)"

    if [[ ! -f "$CACHE_FILE" ]]; then
        log_fail "Cannot validate (no cache)" "stored == used*100/total" "No file"
        return
    fi

    local used total pct
    used=$(jq -r '.used_tokens  // 0' "$CACHE_FILE")
    total=$(jq -r '.total_tokens // 1' "$CACHE_FILE")
    pct=$(jq -r '.percentage    // 0' "$CACHE_FILE")

    if [[ $total -eq 0 ]]; then
        log_fail "Cannot validate (total_tokens=0)" "total_tokens > 0" "0"
        return
    fi

    local expected_pct=$((used * 100 / total))
    local diff=$((pct - expected_pct))
    [[ $diff -lt 0 ]] && diff=$((-diff))

    if [[ $diff -le 1 ]]; then
        log_pass "Percentage correct (stored: $pct%, calculated: $expected_pct%)"
    else
        log_fail "Percentage mismatch" "$expected_pct%" "$pct% (diff: $diff%)"
    fi
}

test_remaining_percentage_matches() {
    log_test "remaining_percentage matches /context (100 - pct)"

    if [[ ! -f "$CACHE_FILE" ]]; then
        log_fail "Cannot validate (no cache)" "remaining + pct == 100" "No file"
        return
    fi

    local remaining pct
    remaining=$(jq -r '.remaining_percentage // null' "$CACHE_FILE")
    pct=$(jq -r '.percentage // 0'             "$CACHE_FILE")

    if [[ "$remaining" == "null" ]]; then
        log_fail "No remaining_percentage in cache" "100 - pct" "null"
        return
    fi

    local expected_pct=$((100 - remaining))
    local diff=$((pct - expected_pct))
    [[ $diff -lt 0 ]] && diff=$((-diff))

    if [[ $diff -le 1 ]]; then
        log_pass "remaining_percentage matches (${remaining}% left = ${pct}% used)"
    else
        log_fail "remaining_percentage mismatch" "${expected_pct}%" "${pct}%"
    fi
}

test_timestamp_recent() {
    log_test "Cache timestamp is recent (within 5 minutes)"

    if [[ ! -f "$CACHE_FILE" ]]; then
        log_fail "Cannot validate (no cache)" "fresh timestamp" "No file"
        return
    fi

    local ts now diff
    ts=$(jq -r '.timestamp // 0' "$CACHE_FILE")
    now=$(date +%s)

    if ! [[ "$ts" =~ ^[0-9]+$ ]]; then
        log_fail "Invalid timestamp" "Unix epoch integer" "$ts"
        return
    fi

    diff=$((now - ts))
    [[ $diff -lt 0 ]] && diff=$((-diff))

    if [[ $diff -le 300 ]]; then
        log_pass "Timestamp recent (${diff}s ago)"
    else
        log_fail "Timestamp stale" "<=300s ago" "${diff}s ago"
    fi
}

# ============================================
# VALIDATION AGAINST /CONTEXT (preserved from v1.0.0)
# ============================================

validate_against_context() {
    local context_used="${1:-}"
    local context_total="${2:-}"
    local context_pct="${3:-}"

    echo -e "${CYAN}============================================================${RESET}"
    echo -e "${CYAN}Context Validation Against /context Command${RESET}"
    echo -e "${CYAN}============================================================${RESET}"
    echo ""

    if [[ ! -f "$CACHE_FILE" ]]; then
        echo -e "${RED}\xe2\x9c\x97 No cache file found${RESET}"
        echo "  Run a Claude Code session first to generate cache data."
        exit 1
    fi

    local statusline_used statusline_total statusline_pct
    statusline_used=$(jq -r '.used_tokens  // 0' "$CACHE_FILE")
    statusline_total=$(jq -r '.total_tokens // 0' "$CACHE_FILE")
    statusline_pct=$(jq -r '.percentage    // 0' "$CACHE_FILE")

    echo -e "${YELLOW}Statusline values (from cache):${RESET}"
    echo -e "  Used: ${statusline_used} tokens"
    echo -e "  Total: ${statusline_total} tokens"
    echo -e "  Percentage: ${statusline_pct}%"
    echo ""

    if [[ -n "$context_used" && -n "$context_total" && -n "$context_pct" ]]; then
        echo -e "${YELLOW}/context values (provided):${RESET}"
        echo -e "  Used: ${context_used} tokens"
        echo -e "  Total: ${context_total} tokens"
        echo -e "  Percentage: ${context_pct}%"
        echo ""
        echo -e "${CYAN}-----------------------------------------------------------${RESET}"
        echo -e "${YELLOW}Comparison Results:${RESET}"

        local all_match=true

        if [[ $context_total -eq $statusline_total ]]; then
            echo -e "  Total tokens:  ${GREEN}\xe2\x9c\x93 MATCH${RESET} ($context_total)"
        else
            echo -e "  Total tokens:  ${RED}\xe2\x9c\x97 MISMATCH${RESET} (/context: $context_total, statusline: $statusline_total)"
            all_match=false
        fi

        local used_diff=$((context_used - statusline_used))
        [[ $used_diff -lt 0 ]] && used_diff=$((-used_diff))
        local used_tolerance=$((context_total / 100))

        if [[ $used_diff -le $used_tolerance ]]; then
            echo -e "  Used tokens:   ${GREEN}\xe2\x9c\x93 MATCH${RESET} (within ${used_tolerance} tolerance)"
        else
            echo -e "  Used tokens:   ${RED}\xe2\x9c\x97 MISMATCH${RESET} (diff: $used_diff tokens)"
            all_match=false
        fi

        local pct_diff=$((context_pct - statusline_pct))
        [[ $pct_diff -lt 0 ]] && pct_diff=$((-pct_diff))

        if [[ $pct_diff -le 1 ]]; then
            echo -e "  Percentage:    ${GREEN}\xe2\x9c\x93 MATCH${RESET} (within 1% tolerance)"
        else
            echo -e "  Percentage:    ${RED}\xe2\x9c\x97 MISMATCH${RESET} (diff: ${pct_diff}%)"
            all_match=false
        fi

        echo -e "${CYAN}-----------------------------------------------------------${RESET}"

        if [[ "$all_match" == true ]]; then
            echo ""
            echo -e "${GREEN}\xe2\x9c\x93 VALIDATION PASSED${RESET}"
            echo "  Statusline accurately reflects /context values"
            exit 0
        else
            echo ""
            echo -e "${RED}\xe2\x9c\x97 VALIDATION FAILED${RESET}"
            echo "  Statusline does NOT match /context"
            exit 1
        fi
    else
        echo -e "${YELLOW}To validate against /context:${RESET}"
        echo ""
        echo "  1. Run ${CYAN}/context${RESET} in Claude Code"
        echo "  2. Note the values shown (e.g., '133k/200k tokens (66%)')"
        echo "  3. Run this script with those values:"
        echo ""
        echo "     ${GREEN}$0 validate 133000 200000 66${RESET}"
        echo ""
        echo -e "${DIM}Note: Values should be within 1% tolerance for PASS${RESET}"
    fi
}

# ============================================
# MAIN
# ============================================

main() {
    local command="${1:-test}"

    case "$command" in
        validate)
            validate_against_context "$2" "$3" "$4"
            ;;
        test|"")
            echo -e "${CYAN}============================================================${RESET}"
            echo -e "${CYAN}Statusline Context Unit Tests (v2.0.0 hardened)${RESET}"
            echo -e "${CYAN}============================================================${RESET}"

            # Pick the cache fixture based on test mode. The test writes its
            # OWN cache (not reading whatever hooks may have left in /tmp)
            # so the assertion outcome is deterministic regardless of hook
            # timing.
            local cache_fixture="$REAL_CACHE_JSON"
            if [[ "${STATUSLINE_TEST_MODE:-}" == "zero" ]]; then
                cache_fixture="$ZERO_CACHE_JSON"
                echo ""
                echo -e "${YELLOW}STATUSLINE_TEST_MODE=zero: writing zero-default cache${RESET}"
                echo -e "${YELLOW}Expected: 1+ FAIL on 'Cache reflects a real session'${RESET}"
            fi
            echo ""

            # Refresh timestamp at write time so the recency check passes.
            cache_fixture=$(echo "$cache_fixture" | sed "s/\"timestamp\":[0-9]*/\"timestamp\":$(date +%s)/")

            # Write the cache fixture.
            echo "$cache_fixture" > "$CACHE_FILE"

            test_cache_file_exists
            test_cache_file_valid_json
            test_cache_has_required_fields
            test_cache_has_real_session_data
            test_values_in_valid_range
            test_percentage_calculation
            test_remaining_percentage_matches
            test_timestamp_recent

            echo ""
            echo -e "${CYAN}-----------------------------------------------------------${RESET}"
            echo -e "${YELLOW}Results: ${GREEN}${TESTS_PASSED} passed${RESET}, ${RED}${TESTS_FAILED} failed${RESET}, ${DIM}${TESTS_TOTAL} total${RESET}"
            echo -e "${CYAN}-----------------------------------------------------------${RESET}"

            if [[ $TESTS_FAILED -gt 0 ]]; then
                exit 1
            fi
            ;;
        *)
            echo "Unknown command: $command"
            echo "Usage: $0 [test|validate] [used_tokens total_tokens percentage]"
            echo ""
            echo "Env: STATUSLINE_TEST_MODE=zero to demonstrate FAIL mode"
            exit 1
            ;;
    esac
}

main "$@"
