#!/usr/bin/env bash
# test-statusline-context.sh - End-to-end test for statusline context display
#
# VERSION: 3.0.0 - T38 (issue #60): e2e, hermetic, CI-wired.
#
# ----------------------------------------------------------------------------
# History
#
# v1.0.0 — wrote its own cache fixture to /tmp/ralph-statusline-context.json
#          and asserted on that same fixture (closed loop; the talking-tests
#          defect PR #38 repaired across 30 other scripts).
#
# v2.0.0 — kept the closed-loop fixture and added cumulative_tokens > 0 to
#          fight the "well-formed but no real session" variant. Still a
#          closed loop; intentionally OUTSIDE run-all-unit-tests.sh
#          because it added a counter without a signal.
#
# v3.0.0 — e2e, hermetic, CI-wired. The statusline now honours
#          RALPH_STATUSLINE_CACHE (added in T38 / issue #60 so each
#          Claude session has its own cache file). This test:
#            1. Picks a tmpdir unique to this run.
#            2. Sets RALPH_STATUSLINE_CACHE=<tmpdir>/cache.json.
#            3. Invokes the real statusline with mock stdin.
#            4. Asserts against <tmpdir>/cache.json — not /tmp/...
#            5. Cleans up.
#          The test asserts on the REAL output of the REAL script, not
#          on a fixture it wrote itself. A bug that writes the wrong
#          field, writes to the wrong file, or skips the write will
#          fail this test. STATUSLINE_TEST_MODE=zero is preserved.
#
# Mode flag:
#   default (no flag): invokes the statusline with realistic data
#     (cumulative=75000, total=200000, used_pct=37), validates.
#     PASS expected.
#   STATUSLINE_TEST_MODE=zero: invokes the statusline with zero
#     data, validates. FAIL expected on cumulative_tokens > 0
#     (this is the talking-test scenario the test was designed
#     to catch).
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

# T38 (issue #60): per-run tmpdir so the cache is hermetic. The OLD
# /tmp/ralph-statusline-context.json is no longer used — the statusline
# now defaults to a per-session file under /tmp/ralph-statusline/ and
# honours RALPH_STATUSLINE_CACHE for explicit overrides (this test).
TEST_TMPDIR=""

# Cleanup: remove TEST_TMPDIR on exit, no matter how we exit.
cleanup() {
    if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}
trap cleanup EXIT

# Mock stdin: a realistic payload the statusline consumes. Fields
# read by the script (see statusline-ralph.sh):
#   .session_id           -> cache filename (T38)
#   .cwd                  -> used as fallback
#   .model.display_name   -> provider badge
#   .context_window.*     -> cumulative/used/total/percentage
#   .cost.total_cost_usd  -> cost in $ display
build_stdin() {
    local session_id="$1"
    local used_pct="$2"
    local total="$3"
    local cumulative="$4"
    local remaining_pct=$((100 - used_pct))
    # NOTE: cumulative_tokens = total_input_tokens + total_output_tokens
    # in the script. To produce a target cumulative in the cache, set
    # total_input_tokens = cumulative and total_output_tokens = 0.
    cat <<EOF
{
  "session_id": "${session_id}",
  "cwd": "/tmp/hermetic-test",
  "model": {"display_name": "claude-opus-4.5"},
  "context_window": {
    "used_percentage": ${used_pct},
    "remaining_percentage": ${remaining_pct},
    "context_window_size": ${total},
    "total_input_tokens": ${cumulative},
    "total_output_tokens": 0
  },
  "cost": {"total_cost_usd": 0.0}
}
EOF
}

# Invoke the real statusline with a mock stdin and a per-run cache
# path. The script writes the cache; we read it back and assert.
#
# stdout is captured separately — the statusline renders a UI segment
# to stdout which we don't need for the cache assertions.
invoke_statusline() {
    local stdin_json="$1"
    local cache_path="$2"
    RALPH_STATUSLINE_CACHE="$cache_path" \
        bash "$STATUSLINE_SCRIPT" <<< "$stdin_json" >/dev/null 2>&1
    return $?
}

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
# E2E TESTS (v3.0.0)
# ============================================

# Sanity: the e2e path is wired up. The statusline script must exist
# (this test is meaningless without it) and the RALPH_STATUSLINE_CACHE
# override must be honoured.
test_e2e_writes_cache_to_override_path() {
    log_test "Statusline writes cache to RALPH_STATUSLINE_CACHE path"

    TEST_TMPDIR="$(mktemp -d "${HOME}/.tmp-statusline-XXXXXX")"
    local cache_path="$TEST_TMPDIR/cache.json"
    local stdin_json
    stdin_json="$(build_stdin "sess-e2e-1" 37 200000 75000)"

    invoke_statusline "$stdin_json" "$cache_path"

    if [[ -f "$cache_path" ]]; then
        log_pass "Cache written to override path ($cache_path)"
    else
        log_fail "Cache NOT written to override path" \
            "file at $cache_path" "no file"
    fi
}

# The statusline was invoked for session sess-e2e-2 and the test reads
# the SAME file the script wrote. Talking-tests fail-open is gone.
test_e2e_cache_is_valid_json() {
    log_test "Cache file is valid JSON"

    if [[ -z "$CACHE_FILE" || ! -f "$CACHE_FILE" ]]; then
        log_fail "Cannot validate (no cache)" "Valid JSON" "No file"
        return
    fi

    if jq empty "$CACHE_FILE" 2>/dev/null; then
        log_pass "Valid JSON structure"
    else
        log_fail "Invalid JSON" "Valid JSON" "Parse error"
    fi
}

test_e2e_cache_has_required_fields() {
    log_test "Cache has required fields"

    if [[ -z "$CACHE_FILE" || ! -f "$CACHE_FILE" ]]; then
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
# must be > 0). A zero-default cache (cumulative_tokens = 0) means the
# statusline never processed real session data, and the test FAILS.
test_e2e_cache_reflects_real_session() {
    log_test "Cache reflects a real session (cumulative_tokens > 0)"

    if [[ -z "$CACHE_FILE" || ! -f "$CACHE_FILE" ]]; then
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

test_e2e_values_in_valid_range() {
    log_test "Values are in valid range"

    if [[ -z "$CACHE_FILE" || ! -f "$CACHE_FILE" ]]; then
        log_fail "Cannot validate (no cache)" "0 <= used <= total" "No file"
        return
    fi

    local used total pct
    used=$(jq -r '.used_tokens  // -1'  "$CACHE_FILE")
    total=$(jq -r '.total_tokens // -1' "$CACHE_FILE")
    pct=$(jq -r '.percentage    // -1' "$CACHE_FILE")

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
    else
        log_fail "Values out of range" "see above" "see above"
    fi
}

test_e2e_percentage_calculation() {
    log_test "Percentage calculation matches (used * 100 / total)"

    if [[ -z "$CACHE_FILE" || ! -f "$CACHE_FILE" ]]; then
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

test_e2e_remaining_percentage_matches() {
    log_test "remaining_percentage matches (100 - pct)"

    if [[ -z "$CACHE_FILE" || ! -f "$CACHE_FILE" ]]; then
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
        log_fail "remaining_percentage mismatch" "${expected_pct}%" "$pct%"
    fi
}

test_e2e_timestamp_recent() {
    log_test "Cache timestamp is recent (within 5 minutes)"

    if [[ -z "$CACHE_FILE" || ! -f "$CACHE_FILE" ]]; then
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

# T38 (issue #60): REMOVED — was a placebo.
#
# The previous version of this file asserted "old hardcoded path mtime
# unchanged after invocation" as a regression check. Lead correctly
# flagged it: mtime on the host filesystem has 1-second resolution,
# and the test's invoke + stat pair runs in well under a second. The
# mtime value is captured before the invocation and re-read after;
# if the script rewrote the file in the same wall-clock second, both
# stat calls return the same value, the test passes, and the
# regression (script writing to the OLD path) is undetected. A
# placebo test is worse than no test because it occupies the slot
# of a real assertion.
#
# The test that actually catches the regression is
# `test_e2e_writes_cache_to_override_path`: if the script ignores
# RALPH_STATUSLINE_CACHE, the override path stays empty, and that
# test fails on `[[ -f $cache_path ]]`. The "did not touch old path"
# assertion was a second check on the same property through a
# different code path that turned out to be inert. Removed.

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

    if [[ -z "$CACHE_FILE" || ! -f "$CACHE_FILE" ]]; then
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
            echo -e "${CYAN}Statusline Context Unit Tests (v3.0.0 e2e / T38)${RESET}"
            echo -e "${CYAN}============================================================${RESET}"

            # Pick a per-run tmpdir. The statusline will write its
            # cache inside it (via RALPH_STATUSLINE_CACHE override).
            TEST_TMPDIR="$(mktemp -d "${HOME}/.tmp-statusline-XXXXXX")"
            CACHE_FILE="$TEST_TMPDIR/cache.json"

            # Build the mock stdin for the statusline invocation.
            # The session_id is part of the discriminator the statusline
            # uses to compute the default cache path; with the override,
            # it does not affect the path but is still parsed.
            local stdin_json
            if [[ "${STATUSLINE_TEST_MODE:-}" == "zero" ]]; then
                echo ""
                echo -e "${YELLOW}STATUSLINE_TEST_MODE=zero: invoking with zero context data${RESET}"
                echo -e "${YELLOW}Expected: 1+ FAIL on 'Cache reflects a real session'${RESET}"
                # Zero data: total_input_tokens=0, total_output_tokens=0.
                # used_pct=0 to keep the script from doing arithmetic
                # on absent percentages.
                stdin_json="$(build_stdin "sess-zero-1" 0 1000000 0)"
            else
                # Realistic data: 75k cumulative, 200k window, 37% used.
                stdin_json="$(build_stdin "sess-e2e-1" 37 200000 75000)"
            fi
            echo ""

            # Invoke the REAL statusline. The script writes the cache
            # to $CACHE_FILE (our per-run tmpdir path). We then assert
            # on $CACHE_FILE below.
            if ! invoke_statusline "$stdin_json" "$CACHE_FILE"; then
                echo -e "${RED}\xe2\x9c\x97 Statusline exited non-zero — assertions will likely fail${RESET}"
            fi

            test_e2e_writes_cache_to_override_path
            test_e2e_cache_is_valid_json
            test_e2e_cache_has_required_fields
            test_e2e_cache_reflects_real_session
            test_e2e_values_in_valid_range
            test_e2e_percentage_calculation
            test_e2e_remaining_percentage_matches
            test_e2e_timestamp_recent

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
