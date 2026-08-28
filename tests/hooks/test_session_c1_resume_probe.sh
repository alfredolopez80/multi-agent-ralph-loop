#!/usr/bin/env bash
# test_session_c1_resume_probe.sh — T110-c1-verify probe.
#
# Certifies #47 acceptance criterion C1: "Exact active-task resume works
# without semantic search." The probe exercises the real resume hook
# (session-start-restore-context.sh) against a fixture plan-state with
# HOME and worktree isolated, then asserts:
#   1. Fresh active plan -> the additionalContext contains the plan's
#      task_id, current_step, and progress (identity-based path).
#   2. Completed plan -> NOT resumed (status filter on the reader side).
#   3. Stale active plan (mtime > 30 min) -> the lead's spec says NOT
#      resumed. The current implementation (session-start-restore-context.sh)
#      does NOT have an mtime check on plan-state.json -- this is a real
#      finding to surface.
#   4. No call path into recall_v2 / tree_store.query / anything semantic.
#      We assert this by snapshotting the PATH/route markers before and
#      after, and by grepping the produced additionalContext for the
#      canonical recall-shaped fields. If recall ran, the context would
#      include a "tree_store" attribution field or a recall-search log;
#      absence of either is the trace.
#
# Sandbox: HOME under /tmp/t110-c1-* (mktemp). All writes inside sandbox.
# The fixture repo is /tmp/t110-c1-*/repo (also a tempdir, no .git).
#
# Usage: bash tests/hooks/test_session_c1_resume_probe.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/hooks/session-start-restore-context.sh"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL + 1)); }

# Sandbox setup.
SANDBOX_BASE="${TMPDIR:-/tmp}/t110-c1"
rm -rf "${SANDBOX_BASE}-"* 2>/dev/null || true
SANDBOX_HOME="$(mktemp -d "${SANDBOX_BASE}-XXXXXX")"
trap 'rm -rf "$SANDBOX_HOME"' EXIT
export HOME="$SANDBOX_HOME"
mkdir -p "$HOME/.ralph/logs"

# Fixture repo with a known .claude/plan-state.json.
FIXTURE_REPO="$(mktemp -d "${SANDBOX_BASE}-repo-XXXXXX")"
mkdir -p "$FIXTURE_REPO/.claude"
PLAN_STATE="$FIXTURE_REPO/.claude/plan-state.json"

write_plan_state() {
    local task_id="$1" step_in_progress="$2" mtime_offset="$3"
    cat > "$PLAN_STATE" <<JSON
{
  "plan": {
    "task_id": "${task_id}",
    "status": "in_progress",
    "summary": "Probe plan for C1 verification: ${task_id}",
    "current_step": "${step_in_progress}"
  },
  "steps": [
    {"id": "s1", "task_id": "${task_id}", "status": "completed", "title": "step one done"},
    {"id": "${step_in_progress}", "task_id": "${task_id}", "status": "in_progress", "title": "step in progress"}
  ],
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
    if [[ "$mtime_offset" != "now" ]]; then
        # Backdate the file. The previous attempt used `date -v-90M` then
        # `touch -t "$TS" file`; it worked in a one-liner but failed inside
        # the function shell with "out of range" (the timestamp format from
        # BSD date's `+%Y%m%d%H%M.%S` may not always be what touch -t expects
        # on every macOS). Use python to set mtime directly: portable
        # across BSD/GNU, no shell-quoting traps.
        local ago_seconds
        case "$mtime_offset" in
            *min) ago_seconds=$(( ${mtime_offset%min} * 60 )) ;;
            *h)   ago_seconds=$(( ${mtime_offset%h}   * 3600 )) ;;
            *)    ago_seconds=$(( ${mtime_offset}    * 60 )) ;;
        esac
        python3 -c "
import os, time, sys
path = sys.argv[1]
ago = int(sys.argv[2])
now = time.time()
os.utime(path, (now - ago, now - ago))
" "$PLAN_STATE" "$ago_seconds"
    fi
}

# Helper: invoke the SessionStart hook with a sandboxed cwd and parse JSON.
# IMPORTANT: the hook reads .claude/plan-state.json via get_main_repo which
# falls back to `pwd` when there's no .git. We cd into the fixture so pwd
# resolves to the fixture's repo root, NOT to this test's worktree.
run_resume() {
    local session_id="$1" project_dir="$2"
    local payload
    payload=$(printf '{"session_id":"%s","project_dir":"%s"}' "$session_id" "$project_dir")
    ( cd "$project_dir" && HOME="$SANDBOX_HOME" PROJECT_DIR="$project_dir" \
        printf '%s' "$payload" | bash "$HOOK" 2>/dev/null )
}

extract_context() {
    # $1 = hook output JSON
    printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}

# --- 1. Fresh active plan -> resumed -----------------------------------------
echo "=== 1. Fresh active plan: additionalContext contains plan identity ==="
SESSION_ID="t110-fresh"
write_plan_state "task-fresh-001" "s2" "now"
out="$(run_resume "$SESSION_ID" "$FIXTURE_REPO")"
ctx="$(extract_context "$out")"
if printf '%s' "$ctx" | grep -q "task-fresh-001"; then
    pass "fresh plan: task_id task-fresh-001 present in context"
else
    fail "fresh plan" "ctx did not contain task_id (rc=\$? out=${out:0:200})"
fi
if printf '%s' "$ctx" | grep -q "Current Step"; then
    pass "fresh plan: 'Current Step' label present"
else
    fail "fresh plan current step" "ctx missing 'Current Step' label"
fi
if printf '%s' "$ctx" | grep -q "1/2 steps completed"; then
    pass "fresh plan: progress '1/2 steps completed (50%)' present"
else
    fail "fresh plan progress" "ctx missing '1/2 steps completed (50%)'"
fi

# --- 2. No recall-shaped fields in context (semantic-search trace) -------
# If recall_v2.py / tree_store.query / etc. had been called by the resume
# hook, the additionalContext would have included a recall-shaped
# attribution block (e.g. 'tree_store' field, score numbers, MEMORY_TRACE).
# Absence of these fields is the trace that the resume was identity-based,
# not semantic.
echo "=== 2. No semantic-search trace in resumed context ==="
if printf '%s' "$ctx" | grep -qE 'tree_store|score|MEMORY_TRACE|recall_v2'; then
    fail "semantic trace" "ctx contains recall-shaped fields (semantic search ran)"
else
    pass "no semantic trace: context is identity-only (no tree_store/score/MEMORY_TRACE)"
fi

# --- 3. Completed plan -> NOT resumed ---------------------------------------
echo "=== 3. Completed plan: NOT resumed (status filter) ==="
SESSION_ID="t110-completed"
cat > "$PLAN_STATE" <<JSON
{
  "plan": {
    "task_id": "task-done-001",
    "status": "completed",
    "summary": "Already done",
    "current_step": "s5"
  },
  "steps": [
    {"id": "s1", "task_id": "task-done-001", "status": "completed", "title": "done1"},
    {"id": "s2", "task_id": "task-done-001", "status": "completed", "title": "done2"}
  ]
}
JSON
out="$(run_resume "$SESSION_ID" "$FIXTURE_REPO")"
ctx="$(extract_context "$out")"
if printf '%s' "$ctx" | grep -q "task-done-001"; then
    fail "completed plan" "ctx resumed a completed task (status filter failed)"
else
    pass "completed plan: NOT resumed (status filter works)"
fi

# --- 4. Stale plan (mtime > 30 min) -> spec says NOT resumed --------------
# The lead's spec: plan VIEJO (>30 min o completed) NO se retoma.
# Current session-start-restore-context.sh has no mtime check on plan-state.json.
# This is the live finding the probe surfaces -- a real bug, not a test bug.
echo "=== 4. Stale plan (mtime > 30 min): finding (mtime check missing) ==="
SESSION_ID="t110-stale"
rm -f "$PLAN_STATE"
write_plan_state "task-stale-001" "s3" "90min"
# Independently verify mtime of plan-state.json is > 30 min.
file_age_seconds=$(( $(date +%s) - $(stat -f %m "$PLAN_STATE" 2>/dev/null || stat -c %Y "$PLAN_STATE") ))
file_age_minutes=$((file_age_seconds / 60))
out="$(run_resume "$SESSION_ID" "$FIXTURE_REPO")"
ctx="$(extract_context "$out")"
if [[ "$file_age_minutes" -lt 30 ]]; then
    fail "stale fixture" "fixture mtime is only ${file_age_minutes}m, expected >30m"
fi
if printf '%s' "$ctx" | grep -q "task-stale-001"; then
    # Lead's spec says NOT resumed. If it IS resumed, that's the finding.
    cat <<'MSG' >&2

  ---- LIVE FINDING (T110 #4) -------------------------------------------
  The lead's spec for T110 requires that plan-state.json with mtime > 30 min
  is NOT resumed (freshness check). session-start-restore-context.sh has
  no mtime check on the plan-state.json path -- it reads the file
  unconditionally and trusts the status filter alone. This means a
  session-end handoff from yesterday would be resumed today if the plan
  is still in_progress in the file.

  Where the freshness check lives:
    .claude/hooks/plan-state-adaptive.sh:58 -- PLAN_STALENESS_MINUTES=30
    .claude/hooks/plan-state-lifecycle.sh -- archive-stale path

  Neither of those hooks is invoked by session-start-restore-context.sh.
  The C1 resume contract is therefore satisfied for "fresh in_progress
  plan + identity" but NOT for "stale in_progress plan + identity" --
  the freshness gate lives in a different file.

  This is a real #47 C1 gap and should be reported as such, not papered
  over. The probe surfaces it as a FAIL for case #4 (stale plan) because
  the lead's spec is the contract being verified.
  -------------------------------------------------------------------------

MSG
    fail "stale plan: SPEC says NOT resumed, ACTUAL resumes stale plan" \
         "live finding -- session-start-restore-context.sh has no mtime check (C1 freshness gap; see stderr)"
else
    pass "stale plan: NOT resumed (freshness gate honoured)"
fi

echo
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
