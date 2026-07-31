#!/usr/bin/env bash
# validation-common.sh — shared colors, counters and verdict for scripts/ validators.
#
# Before this library, ~25 scripts each redefined the same ANSI palette and kept their
# own passed/failed/warnings trio under a dozen different names, and the "a run that
# checked nothing is never a success" guard lived — inconsistently — in only 4 of them.
# This file is the single home for all three.
#
# Canonical counters: PASSED / FAILED / WARNINGS. The JSON printers that already exist in
# the installer-family scripts read these names directly, so the contract with
# validate-installation.sh (.summary.passed/failed/warnings) is preserved untouched.
#
# INCREMENTS: always `VAR=$((VAR+1))`, never `((VAR++))`. Under `set -e` a post-increment
# on a counter holding 0 evaluates to 0, which is exit status 1, and aborts the script
# mid-run leaving the counters at zero. This library exists partly to keep that trap out
# of every caller.
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib/validation-common.sh"
#   vc_init
#   vc_pass "config file present"      # counts and prints
#   vc_fail "hook X not registered"    # counts and prints
#   vc_pass                            # counts only (caller prints its own, grouped)
#   vc_verdict "My Validator" || exit 1
#   exit 0

# Idempotent under re-source; no `readonly` so a second `source` cannot abort the caller.
# Color is emitted unconditionally (matching every current script) unless NO_COLOR is set,
# so piped output looks exactly as it did before this library existed.
if [[ -n "${NO_COLOR:-}" ]]; then
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
else
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  MAGENTA='\033[0;35m'
  NC='\033[0m'
fi

vc_init() { PASSED=0; FAILED=0; WARNINGS=0; }

# With a message: count and print it. Without: count only — the installer-family scripts
# print their own output grouped by section, and only want the tally kept.
#
# The trailing `return 0` is load-bearing: without it, the `[[ $# -gt 0 ]]` test evaluating
# false would be the function's last command and return 1, killing a caller under `set -e`.
vc_pass() { PASSED=$((PASSED + 1));     [[ $# -gt 0 ]] && echo -e "${GREEN}✓${NC} $*"; return 0; }
vc_fail() { FAILED=$((FAILED + 1));     [[ $# -gt 0 ]] && echo -e "${RED}✗${NC} $*";   return 0; }
vc_warn() { WARNINGS=$((WARNINGS + 1)); [[ $# -gt 0 ]] && echo -e "${YELLOW}⚠${NC} $*"; return 0; }

# Print the summary and return the verdict:
#   1 when total == 0 — a run that checked nothing cannot be a success. THE guard, once.
#   1 when FAILED > 0.
#   0 otherwise (warnings do not fail the run).
# The tokens "Total:", "Passed:", "Failed:", "Warnings:" are a contract with
# tests/test_validators_execute_clean.py — do not rename them.
vc_verdict() {
  local title="${1:-Validation}"
  local total=$((PASSED + FAILED + WARNINGS))
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "   ${title} — SUMMARY"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  Total:    $total"
  echo "  Passed:   $PASSED"
  echo "  Failed:   $FAILED"
  echo "  Warnings: $WARNINGS"
  echo ""
  if [[ $total -eq 0 ]]; then
    echo -e "${RED}✗ FATAL: zero checks executed — no verdict can be declared${NC}" >&2
    return 1
  fi
  if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}✗ ${title}: $FAILED check(s) failed${NC}"
    return 1
  fi
  if [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}⚠ ${title}: passed with $WARNINGS warning(s)${NC}"
  else
    echo -e "${GREEN}✓ ${title}: all checks passed${NC}"
  fi
  return 0
}

# The verdict as an EXIT CODE only, no printing — 1 when nothing was checked (zero-checks
# guard) or anything failed, else 0. A script whose text path prints via vc_verdict but
# whose `--format json` path prints its own JSON must call this after the case so the
# process exit code reflects the verdict in BOTH modes. Without it, json mode ends on a
# plain `echo` (rc 0) and reports success over failures or an empty run.
vc_exit_code() {
  local total=$((PASSED + FAILED + WARNINGS))
  [[ $total -eq 0 ]] && return 1
  [[ $FAILED -gt 0 ]] && return 1
  return 0
}
