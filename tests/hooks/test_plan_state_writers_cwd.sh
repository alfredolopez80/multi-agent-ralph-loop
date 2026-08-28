#!/usr/bin/env bash
# test_plan_state_writers_cwd.sh — T87: plan-state writers and readers must be
# root-resolved, never cwd-relative or main-checkout-bound.
#
# Background (T86 + T87 investigation, epic #47 / C1): every measured plan-state
# consumer reads PER-WORKTREE (statusline, orchestrator-init, anti-rat gate,
# status-auto-check). Two writers used get_main_repo and wrote to the MAIN
# checkout from a linked worktree, where there are ZERO readers of that file —
# the bug is invisible in solo sessions because get_main_repo ==
# get_project_root there.
#
# Three scenarios, each RED before the fix and GREEN after:
#   1. plan-sync-post-step (writer, from a LINKED WORKTREE): must mutate the
#      worktree's own plan-state.json, not the main checkout's.
#   2. plan-state-lifecycle (writer/ager, from a LINKED WORKTREE): a stale
#      plan must be archived FROM the worktree; the main checkout's file
#      (which does not exist) must not be the lookup target.
#   3. ralph-subagent-start (reader, from a SUBDIRECTORY): is_ralph_project
#      must resolve plan-state via the repo root, not the process CWD.
#
# The fixtures build a REAL git repo plus a REAL linked worktree in a temp
# dir: without a worktree, get_main_repo and get_project_root coincide and the
# tests would pass against the buggy code (zero-scope green).

set -uo pipefail   # no -e: failures are counted, not fatal

HOOKS_SRC="$(cd "$(dirname "$0")/../.." && pwd)/.claude/hooks"

PASS=0
FAIL=0

ok() {
  echo "  OK   $1"
  PASS=$((PASS + 1))
}

bad() {
  echo "  FAIL $1"
  [[ -n "${2:-}" ]] && echo "       $2"
  FAIL=$((FAIL + 1))
}

# --- Fixture: temp main repo + linked worktree, both carrying the hooks ---
# Echoes two canonical paths on separate lines: main checkout, then worktree.
make_worktree_fixtures() {
  local main_dir wt_dir
  main_dir=$(mktemp -d)
  git -C "$main_dir" init -q
  git -C "$main_dir" config user.email t87@test
  git -C "$main_dir" config user.name t87
  # The hooks travel with the repo so the worktree checkout carries its own
  # copy (as in real life: each worktree resolves paths from its own tree).
  mkdir -p "$main_dir/.claude/hooks"
  cp -R "$HOOKS_SRC/." "$main_dir/.claude/hooks/"
  git -C "$main_dir" add -A
  git -C "$main_dir" commit -q -m "t87 fixtures $(date -u +%Y%m%dT%H%M%SZ)" --allow-empty
  # The worktree dir must NOT pre-exist: `git worktree add` refuses an
  # existing path. If creation fails, the fixture premise is broken — fail
  # loud here; never let the scenarios run against a fake worktree.
  wt_dir="${main_dir}-wt"
  if ! git -C "$main_dir" worktree add -q -b t87-wt "$wt_dir" HEAD >/dev/null 2>&1 \
     || [[ ! -f "$wt_dir/.git" ]]; then
    echo "FIXTURE ERROR: git worktree add failed for $wt_dir" >&2
    return 1
  fi
  # Canonical (physical) paths: on macOS /var is a symlink to /private/var,
  # and both realpath (used by plan-sync) and git rev-parse report the
  # physical form. Paths must be BORN canonical or spec.file never matches.
  main_dir=$(cd "$main_dir" && pwd -P)
  wt_dir=$(cd "$wt_dir" && pwd -P)
  printf '%s\n%s\n' "$main_dir" "$wt_dir"
}

require_fixtures() {
  if [[ ! -d "${MAIN_DIR:-}" || ! -d "${WT_DIR:-}" ]]; then
    echo "FIXTURE ERROR: worktree fixtures missing — aborting suite" >&2
    exit 2
  fi
}

cleanup() { rm -rf "$@" 2>/dev/null || true; }

echo "=== T87-W1: plan-sync-post-step from worktree mutates the WORKTREE plan ==="
FIX=$(make_worktree_fixtures)
MAIN_DIR=$(printf '%s\n' "$FIX" | sed -n 1p)
WT_DIR=$(printf '%s\n' "$FIX" | sed -n 2p)
require_fixtures
PLAN="$WT_DIR/.claude/plan-state.json"
mkdir -p "$WT_DIR/src"
cat > "$WT_DIR/src/foo.ts" <<'EOF'
export const foo = 1;
EOF
# Plan lives ONLY in the worktree. spec expects the export "foo".
cat > "$PLAN" <<EOF
{"version":"1.0","task":"t87","steps":[{"id":"s1","name":"write foo","status":"in_progress","spec":{"file":"$WT_DIR/src/foo.ts","exports":["foo"]},"actual":{}}]}
EOF
BEFORE_MAIN=$( [[ -f "$MAIN_DIR/.claude/plan-state.json" ]] && echo yes || echo no )
(cd "$WT_DIR" && CLAUDE_TOOL_ARG_file_path="$WT_DIR/src/foo.ts" \
  /bin/bash "$WT_DIR/.claude/hooks/plan-sync-post-step.sh" </dev/null >/dev/null 2>&1)
UPDATED_AT=$(jq -r '.steps[0].actual.updated_at // ""' "$PLAN" 2>/dev/null)
if [[ -n "$UPDATED_AT" ]]; then
  ok "worktree plan-state was mutated in place (actual.updated_at written)"
else
  bad "worktree plan-state was NOT mutated (writer went elsewhere or bailed)"
fi
if [[ "$BEFORE_MAIN" == "no" && ! -f "$MAIN_DIR/.claude/plan-state.json" ]]; then
  ok "main checkout plan-state untouched (never created there)"
else
  bad "main checkout plan-state appeared/changed — writer leaked to main repo"
fi
cleanup "$MAIN_DIR" "$WT_DIR"

echo "=== T87-W2: plan-state-lifecycle from worktree archives the WORKTREE plan ==="
FIX=$(make_worktree_fixtures)
MAIN_DIR=$(printf '%s\n' "$FIX" | sed -n 1p)
WT_DIR=$(printf '%s\n' "$FIX" | sed -n 2p)
require_fixtures
PLAN="$WT_DIR/.claude/plan-state.json"
mkdir -p "$WT_DIR/.claude"
cat > "$PLAN" <<EOF
{"version":"1.0","task":"t87 stale plan","last_updated":"2020-01-01T00:00:00Z","steps":[{"id":"s1","name":"old step","status":"pending"}]}
EOF
# Force a genuinely stale mtime (macOS -t / GNU -d fallback).
STALE_TS=$( { date -v-3H +%Y%m%d%H%M 2>/dev/null || date -d '3 hours ago' +%Y%m%d%H%M; } )
touch -t "$STALE_TS" "$PLAN"
ISO_HOME=$(mktemp -d)
# Prompt: >50 chars, matches implement*, no continuation words → new task.
# The hook reads .userPromptContent from its stdin JSON payload.
NEW_TASK_PROMPT="implement the new dashboard feature with full test coverage and documentation"
(cd "$WT_DIR" && printf '{"userPromptContent": "%s"}' "$NEW_TASK_PROMPT" | \
  HOME="$ISO_HOME" /bin/bash "$WT_DIR/.claude/hooks/plan-state-lifecycle.sh" >/dev/null 2>&1)
ARCHIVED=$(find "$ISO_HOME/.ralph/archive/plans" -name 'plan-*.json' 2>/dev/null | wc -l | tr -d ' ')
if [[ ! -f "$PLAN" && "${ARCHIVED:-0}" -ge 1 ]]; then
  ok "stale plan archived FROM the worktree (removed at root, copy in archive)"
else
  bad "stale worktree plan NOT archived (lifecycle looked at the wrong root)"
fi
if [[ ! -f "$MAIN_DIR/.claude/plan-state.json" ]]; then
  ok "main checkout plan-state untouched"
else
  bad "main checkout plan-state appeared — lifecycle leaked to main repo"
fi
cleanup "$MAIN_DIR" "$WT_DIR" "$ISO_HOME"

echo "=== T87-W3: ralph-subagent-start from subdirectory detects the project ==="
R2=$(mktemp -d)
git -C "$R2" init -q
git -C "$R2" config user.email t87@test
git -C "$R2" config user.name t87
mkdir -p "$R2/.claude" "$R2/sub"
cat > "$R2/.claude/plan-state.json" <<'EOF'
{"version":"1.0","task":"t87","steps":[]}
EOF
mkdir -p "$R2/.claude/hooks/lib"
cp "$HOOKS_SRC/ralph-subagent-start.sh" "$R2/.claude/hooks/"
cp "$HOOKS_SRC/lib/worktree-utils.sh" "$R2/.claude/hooks/lib/"
ISO_HOME=$(mktemp -d)
(cd "$R2/sub" && printf '%s' \
  '{"agent_id":"t87a","agent_type":"ralph-researcher","parent_id":"p","session_id":"s1"}' | \
  HOME="$ISO_HOME" /bin/bash "$R2/.claude/hooks/ralph-subagent-start.sh" >/dev/null 2>&1)
if grep -q "Ralph project detected" "$ISO_HOME/.ralph/logs/agent-teams.log" 2>/dev/null; then
  ok "root-resolved plan-state detected from subdirectory (context injection logged)"
else
  bad "Ralph project NOT detected from subdirectory (relative read missed the root)"
fi
cleanup "$R2" "$ISO_HOME"

echo
echo "=========================================="
echo "Passed: $PASS | Failed: $FAIL"
echo "=========================================="
exit $FAIL
