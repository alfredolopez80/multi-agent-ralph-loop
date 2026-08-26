# daily-gate.sh — Skip a hook body if it already ran today.
#
# Library (source it, do not execute). Aligns with the existing repo pattern
# ai-code-audit.sh uses (`~/.ralph/markers/` + portable stat) and adds a
# simpler time-based variant for periodic SessionStart maintenance hooks.
#
# Usage in a hook:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/daily-gate.sh"
#   if ! daily_gate_check "<hook-name>"; then
#       # Already ran today — emit a breadcrumb and exit cleanly.
#       printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<hook-name>: skipped (ran today)"}}'
#       exit 0
#   fi
#   # ... hook body ...
#   daily_gate_touch "<hook-name>"   # mark unconditionally, AFTER the work.
#
# Escape hatch: set RALPH_FORCE_DAILY_GATE=1 in the environment to bypass
# the gate and force the body to run. Useful for tests and for manual reruns.
#
# Isolation (T75 doctrine): markers live under $HOME/.ralph/markers/, OUTSIDE
# the project tree. Override with RALPH_DAILY_GATE_DIR for tests in isolated
# homes so that no real cooldown is touched. No .gitignore needed, no tracked
# files, no project-tree pollution — the lesson T75 applied from the start.
#
# Filename shape: daily-gate-<hook>-YYYYMMDD. A new run on a new day picks a
# new filename automatically, so there is no expiry logic to maintain; stale
# markers from previous days are simply ignored.

# Defensive: keep permissions tight when sourcing, but do NOT `set -euo pipefail`
# here — propagating shell options into the caller's environment changes its
# behaviour unpredictably. Each function is internally robust instead.
umask 077

MARKERS_DIR="${RALPH_DAILY_GATE_DIR:-${HOME}/.ralph/markers}"

# Compute the canonical marker path for (hook, today).
#
# Sanitisation: keep only [a-zA-Z0-9_-] in the hook name. Anything else came
# from an untrusted source (config files, env vars) and could try to escape
# the markers directory. The post-sanitisation concatenation is safe; the
# date suffix is generated and safe by construction.
_dg_marker_path() {
    local hook_name="$1"
    local safe
    safe=$(printf '%s' "$hook_name" | tr -cd 'a-zA-Z0-9_-')
    [[ -z "$safe" ]] && safe="unnamed"
    printf '%s' "${MARKERS_DIR}/daily-gate-${safe}-$(date -u +%Y%m%d)"
}

# Returns 0 when the caller should run; 1 when it should skip.
#
# The force flag overrides everything — the escape hatch is opt-in via the
# environment, never implicit. A bare invocation with no override either runs
# (no marker yet today) or skips (marker exists).
daily_gate_check() {
    local hook_name="$1"
    if [[ -n "${RALPH_FORCE_DAILY_GATE:-}" ]]; then
        return 0
    fi
    mkdir -p "$MARKERS_DIR" 2>/dev/null || true
    if [[ -f "$(_dg_marker_path "$hook_name")" ]]; then
        return 1
    fi
    return 0
}

# Stamp "ran today" with the current UTC date. Call this AFTER the body, not
# before — marking before the work would make a half-failed body look like a
# successful gate execution on subsequent runs.
#
# Failure of this function is non-fatal for the hook; touch is best-effort.
# A disk full or permissions error here must not break the hook body that
# already succeeded.
daily_gate_touch() {
    local hook_name="$1"
    local path
    path=$(_dg_marker_path "$hook_name")
    mkdir -p "$MARKERS_DIR" 2>/dev/null || return 0
    : > "$path" 2>/dev/null || true
}

# Test helper: clear the marker for a hook, simulating "first run of the day".
# Not for production use; tests import it to reset state between cases.
#
# Exposed so test_hooks_daily_gate.py can verify the failure-fresh path
# (delete the marker → hook should now run the body on next invocation).
daily_gate_clear() {
    local hook_name="$1"
    local path
    path=$(_dg_marker_path "$hook_name")
    rm -f "$path" 2>/dev/null || true
}
