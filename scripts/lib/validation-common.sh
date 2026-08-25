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

# BASH 4+ GUARD — OPT-IN. Set VC_REQUIRE_BASH4=1 *before* sourcing this file.
#
#   VC_REQUIRE_BASH4=1
#   source "${SCRIPT_DIR}/lib/validation-common.sh"
#
# Ten of this library's twenty callers build their result tables with `declare -A`.
# Bash 3.2 — what macOS still ships as /bin/bash — has no associative arrays. It does
# not abort: it writes "declare: -A: invalid option" to stderr, carries on, and then
# collapses every RESULTS[key]=... onto index 0, because an unset name in an array
# subscript evaluates arithmetically to 0. The run produces confident nonsense.
#
# That is how this reached CI as `jq: parse error: Invalid numeric literal at line 1,
# column N`, with N differing per script and matching nothing in any emitter — N was
# simply the length of the failing script's own absolute path, because $output began
# with "/Users/.../validate-<name>.sh: line 85: declare: -A: invalid option", not "{".
#
# The other ten callers are bash-3 clean and some say so in their headers
# (install-language-servers.sh: "COMPAT: Bash 3.2+ (macOS native)"). Enforcing this
# unconditionally would have broken every one of them on stock macOS to fix a problem
# they do not have, so the requirement is declared per caller rather than assumed.
#
# The flag is read at source time on purpose: "$@" here is the calling script's own
# argument list, so the re-exec below preserves it. A function form would see its own
# arguments instead, and would silently drop the caller's on bash 3 only — the exact
# class of platform-specific silent failure this guard exists to end.
#
# Re-exec under a newer bash when the machine has one; refuse to run when it does not.
# Degrading quietly is the one option available here that must not be taken.
if [ "${VC_REQUIRE_BASH4:-0}" = "1" ] && [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
    # Loop breaker. The guard trusts a `bash -c` probe to predict how the same binary
    # will behave with a script operand. A shim where those two diverge would re-exec
    # forever -- measured at ~3000 invocations in 8s with a deliberately lying stub.
    # One marker turns an unbounded loop into a single honest error.
    if [ "${VC_BASH4_REEXEC:-0}" = "1" ]; then
        echo "ERROR: $0 re-executed under '${BASH:-unknown}' and still sees bash ${BASH_VERSINFO:-?}." >&2
        echo "       Refusing to re-exec again. Check for a wrapper on PATH pretending to be bash." >&2
        exit 78
    fi

    # `command -v bash` first: the fixed list misses MacPorts (/opt/local/bin), nix,
    # asdf/mise shims and any --prefix build, so a user with a perfectly good bash 5
    # could be told to `brew install bash` they had already installed.
    # Kept on one line so a test can substitute the whole candidate set with one edit.
    _vc_candidates="$(command -v bash 2>/dev/null) /opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash"
    for _vc_bash in $_vc_candidates; do
        [ -n "$_vc_bash" ] && [ -x "$_vc_bash" ] || continue
        _vc_major="$("$_vc_bash" -c 'echo "${BASH_VERSINFO:-0}"' 2>/dev/null || echo 0)"
        case "$_vc_major" in
            ''|*[!0-9]*) continue ;;
        esac
        if [ "$_vc_major" -ge 4 ]; then
            VC_BASH4_REEXEC=1 export VC_BASH4_REEXEC
            exec "$_vc_bash" "$0" "$@"
        fi
    done
    echo "ERROR: $0 requires bash 4.0+ for associative arrays (found ${BASH_VERSION:-unknown})." >&2
    echo "       macOS ships bash 3.2. Install a newer one:  brew install bash" >&2
    exit 78
fi

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
