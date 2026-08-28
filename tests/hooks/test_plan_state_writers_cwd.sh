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
# T99: the hook learns the edited file from its STDIN PAYLOAD
# (.tool_input.file_path — the real PostToolUse envelope), not from a
# CLAUDE_TOOL_ARG_* environment variable nobody produces. The suite feeds the
# real payload and isolates HOME like W2/W3 do (the hook writes its log under
# $HOME/.ralph — without isolation it litters the runner's home).
ISO_HOME_W1=$(mktemp -d)
(cd "$WT_DIR" && printf '{"tool_input": {"file_path": "%s"}}' "$WT_DIR/src/foo.ts" | \
  HOME="$ISO_HOME_W1" /bin/bash "$WT_DIR/.claude/hooks/plan-sync-post-step.sh" >/dev/null 2>&1)
UPDATED_AT=$(jq -r '.steps[0].actual.updated_at // ""' "$PLAN" 2>/dev/null)
if [[ -n "$UPDATED_AT" ]]; then
  ok "worktree plan-state was mutated in place (actual.updated_at written)"
else
  bad "worktree plan-state was NOT mutated (payload .tool_input.file_path not honored)"
fi
if [[ "$BEFORE_MAIN" == "no" && ! -f "$MAIN_DIR/.claude/plan-state.json" ]]; then
  ok "main checkout plan-state untouched (never created there)"
else
  bad "main checkout plan-state appeared/changed — writer leaked to main repo"
fi
cleanup "$MAIN_DIR" "$WT_DIR" "$ISO_HOME_W1"

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

echo "=== T99-W4: plan-sync validate_file_path — component traversal rejected, dotted names accepted, root boundary enforced ==="
# Guard direction tests (T99 review rule 3): each assert must be able to go
# RED when its specific check is removed —
#   a) 'src/../src/foo.ts' resolves INSIDE the root: only the '../component'
#      check can reject it (the prefix check passes — realpath is in-root).
#   b) 'src/foo.ts' must be ACCEPTED: the guard rejects paths, not work.
#   c) '<worktree>-2/evil.ts' STARTS WITH the root prefix: only the
#      boundary-aware comparison ('root' vs 'root-2') can reject it. The
#      plan carries a step spec'ing evil.ts so the "not mutated" assert
#      DISCRIMINATES (T99 RETURN 6: with no matching step it passed either
#      way — zero-scope green).
#   d) 'report.v1..v2.ts' carries '..' INSIDE a filename: the old substring
#      check rejected it; only the component regex accepts it (RETURN 5).
FIX=$(make_worktree_fixtures)
MAIN_DIR=$(printf '%s\n' "$FIX" | sed -n 1p)
WT_DIR=$(printf '%s\n' "$FIX" | sed -n 2p)
require_fixtures
PLAN="$WT_DIR/.claude/plan-state.json"
mkdir -p "$WT_DIR/src"
cat > "$WT_DIR/src/foo.ts" <<'EOF'
export const foo = 1;
EOF
cat > "$WT_DIR/src/report.v1..v2.ts" <<'EOF'
export const dotted = 2;
EOF
cat > "$PLAN" <<EOF
{"version":"1.0","task":"t99","steps":[
 {"id":"s1","name":"write foo","status":"in_progress","spec":{"file":"$WT_DIR/src/foo.ts","exports":["foo"]},"actual":{}},
 {"id":"s2","name":"write dotted","status":"in_progress","spec":{"file":"$WT_DIR/src/report.v1..v2.ts","exports":["dotted"]},"actual":{}},
 {"id":"s3","name":"write evil","status":"in_progress","spec":{"file":"${WT_DIR}-2/evil.ts","exports":["evil"]},"actual":{}}]}
EOF
# A sibling directory whose path is a strict PREFIX EXTENSION of the worktree
# root: "<WT_DIR>-2" begins with "<WT_DIR>" — the naive prefix check admits it.
mkdir -p "${WT_DIR}-2"
echo "evil" > "${WT_DIR}-2/evil.ts"
ISO_HOME_W4=$(mktemp -d)
SYNC_LOG="$ISO_HOME_W4/.ralph/logs/plan-sync.log"

run_sync() {
  (cd "$WT_DIR" && printf '{"tool_input": {"file_path": "%s"}}' "$1" | \
    HOME="$ISO_HOME_W4" /bin/bash "$WT_DIR/.claude/hooks/plan-sync-post-step.sh" >/dev/null 2>&1)
}

# (a) traversal-as-component: realpath is INSIDE the root; only '..' sees it.
run_sync "$WT_DIR/src/../src/foo.ts"
A_KEPT=$(jq -r '.steps[] | select(.id == "s1") | .actual.updated_at // ""' "$PLAN" 2>/dev/null)
if [[ -z "$A_KEPT" ]] && grep -q "Rejected suspicious path" "$SYNC_LOG" 2>/dev/null; then
  ok "component traversal (src/../src/foo.ts) rejected by the '..' check"
else
  bad "component traversal NOT rejected (check missing or wrong shape): plan mutated='${A_KEPT:+yes}'"
fi

# (b) a legitimate dotted filename must sail through and reach the plan.
run_sync "$WT_DIR/src/foo.ts"
B_WROTE=$(jq -r '.steps[] | select(.id == "s1") | .actual.updated_at // ""' "$PLAN" 2>/dev/null)
if [[ -n "$B_WROTE" ]]; then
  ok "legitimate path accepted (plan mutated in place)"
else
  bad "legitimate path REJECTED — guard over-blocks real work"
fi

# (d) '..' inside a FILENAME is legal: only the component regex accepts it.
run_sync "$WT_DIR/src/report.v1..v2.ts"
D_WROTE=$(jq -r '.steps[] | select(.id == "s2") | .actual.updated_at // ""' "$PLAN" 2>/dev/null)
if [[ -n "$D_WROTE" ]]; then
  ok "dotted filename (report.v1..v2.ts) accepted — '..' matched as component only"
else
  bad "dotted filename REJECTED — substring '..' check is back"
fi

# (c) prefix-boundary sibling: '<root>-2' must NOT count as '<root>'.
run_sync "${WT_DIR}-2/evil.ts"
C_BLOCKED=$(grep -c "Path traversal attempt blocked" "$SYNC_LOG" 2>/dev/null)
C_BLOCKED=${C_BLOCKED:-0}
C_UNCHANGED=$(jq -r '.steps[] | select(.id == "s3") | .actual.updated_at // ""' "$PLAN" 2>/dev/null)
if [[ "${C_BLOCKED:-0}" -ge 1 ]]; then
  ok "root-boundary sibling (<root>-2) rejected by the boundary check"
else
  bad "prefix sibling admitted ('<root>-2' matched '<root>*') — traversal guard bypassed"
fi
if [[ -z "$C_UNCHANGED" ]]; then
  ok "out-of-root file never mutated its OWN step (s3 discriminates: it is spec'd in the plan)"
else
  bad "out-of-root file mutated the plan — the boundary let evil.ts reach step s3"
fi
cleanup "$MAIN_DIR" "$WT_DIR" "${WT_DIR}-2" "$ISO_HOME_W4"

echo "=== T99-W5: lifecycle survives CONTAMINATED stat output (GNU -f trap, RETURN dominant 1) ==="
# `stat -f %m file` on GNU/Linux does not fail: it prints multi-line,
# non-numeric filesystem info. STAT_PROBE replays that output
# deterministically; the hook must SKIP the staleness decision with a
# logged reason instead of feeding garbage into $(( )).
FIX=$(make_worktree_fixtures)
MAIN_DIR=$(printf '%s\n' "$FIX" | sed -n 1p)
WT_DIR=$(printf '%s\n' "$FIX" | sed -n 2p)
require_fixtures
PLAN="$WT_DIR/.claude/plan-state.json"
mkdir -p "$WT_DIR/.claude"
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat > "$PLAN" <<EOF
{"version":"1.0","task":"t99 fresh plan","last_updated":"$NOW_ISO","steps":[{"id":"s1","name":"step","status":"pending"}]}
EOF
FAKE_STAT="$WT_DIR/fake-stat.sh"
cat > "$FAKE_STAT" <<'EOF'
#!/bin/bash
# Emulates GNU `stat -f %m <file>` on Linux: fs listing + trailing number.
echo '  File: "%m"'
echo '  ID: 6e30d1c2 Namelen: 255 Type: ext2/ext3'
echo 'Block size: 4096 Fundamental block size: 4096'
echo 'Inodes: total 1234 free 567'
echo '1748312000'
EOF
chmod +x "$FAKE_STAT"
ISO_HOME_W5=$(mktemp -d)
LIFE_LOG="$ISO_HOME_W5/.ralph/logs/plan-state-lifecycle.log"
OUT_W5=$(cd "$WT_DIR" && printf '{"userPromptContent": "%s"}' "continue with the current step please" | \
  HOME="$ISO_HOME_W5" RALPH_TEST_STAT_PROBE="$FAKE_STAT" /bin/bash "$WT_DIR/.claude/hooks/plan-state-lifecycle.sh" 2>/dev/null)
RC_W5=$?
if [[ "$RC_W5" -eq 0 && "$OUT_W5" == *'{"continue": true}'* && -f "$PLAN" ]] \
   && grep -q "skipping staleness" "$LIFE_LOG" 2>/dev/null; then
  ok "contaminated stat output: hook skipped staleness cleanly (no archive, logged reason)"
else
  bad "contaminated stat output broke the hook: rc=$RC_W5 plan_archived=$( [[ -f "$PLAN" ]] && echo no || echo yes )"
fi

# T99 r3 finding 4: the probe name is TEST-NAMESPACED. The OLD generic name
# must be IGNORED by production: set it with the same contaminating script
# and the hook must behave exactly as if nothing was exported.
rm -f "$LIFE_LOG"
OUT_W5B=$(cd "$WT_DIR" && printf '{"userPromptContent": "%s"}' "continue with the current step please" | \
  HOME="$ISO_HOME_W5" STAT_PROBE="$FAKE_STAT" /bin/bash "$WT_DIR/.claude/hooks/plan-state-lifecycle.sh" 2>/dev/null)
if ! grep -q "skipping staleness" "$LIFE_LOG" 2>/dev/null; then
  ok "old un-namespaced STAT_PROBE is ignored (production stat not hijacked)"
else
  bad "un-namespaced STAT_PROBE still hijacks production stat — namespace fix missing"
fi
cleanup "$MAIN_DIR" "$WT_DIR" "$ISO_HOME_W5"

echo "=== T99-W6: anti-rat adopts the NESTED project root (cwd below a marked dir) ==="
# dotfiles-style container repo > nested non-git project (has .claude/) >
# session subdirectory. The plan lives in the NESTED project; Modo B must
# fire. Pre-fix, PROJECT_ROOT stayed on raw CWD and the plan was invisible
# (RETURN 3: the T87 symptom one level deeper).
CONTAINER=$(mktemp -d)
git -C "$CONTAINER" init -q
git -C "$CONTAINER" config user.email t99@test
git -C "$CONTAINER" config user.name t99
mkdir -p "$CONTAINER/.claude/hooks"
cp "$HOOKS_SRC/anti-rationalization-gate.sh" "$CONTAINER/.claude/hooks/"
NESTED="$CONTAINER/projects/toolbox"
mkdir -p "$NESTED/.claude/state" "$NESTED/sub"
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '{"last_updated":"%s","task":"nested","steps":[{"name":"step","status":"in_progress"}]}' "$NOW_ISO" \
  > "$NESTED/.claude/plan-state.json"
OUT_W6=$(cd "$CONTAINER" && printf '{"stop_hook_active": false, "cwd": "%s/sub", "transcript": "Should I continue?"}' "$NESTED" | \
  /bin/bash "$CONTAINER/.claude/hooks/anti-rationalization-gate.sh" 2>/dev/null || true)
if [[ "$OUT_W6" == *"Plan-immutability gate"* ]]; then
  ok "nested project plan detected from its subdirectory (Modo B fires)"
else
  bad "nested project plan INVISIBLE from subdirectory — boundary not adopted as root"
fi
rm -rf "$CONTAINER"

echo "=== T99-W7: anti-rat logs BROKEN git, stays silent on true no-git (RETURN 4) ==="
# Both cases fail rev-parse with the same "not a git repository" text; only
# the presence of a .git on the walk up distinguishes them.
BROKEN=$(mktemp -d)
git -C "$BROKEN" init -q
mkdir -p "$BROKEN/.claude/hooks"
cp "$HOOKS_SRC/anti-rationalization-gate.sh" "$BROKEN/.claude/hooks/"
echo "garbage" > "$BROKEN/.git/HEAD"   # corrupt HEAD: rev-parse fails
ISO_HOME_W7=$(mktemp -d)
RC_W7=0
(cd "$BROKEN" && printf '{"stop_hook_active": false, "cwd": "%s", "transcript": "hello"}' "$BROKEN" | \
  HOME="$ISO_HOME_W7" /bin/bash "$BROKEN/.claude/hooks/anti-rationalization-gate.sh" >/dev/null 2>&1) || RC_W7=$?
if [[ "$RC_W7" -eq 0 ]] && grep -q "git present but broken" "$ISO_HOME_W7/.ralph/logs/anti-rationalization-gate.log" 2>/dev/null; then
  ok "broken git (corrupt HEAD): allowed AND logged for the operator"
else
  bad "broken git NOT logged (rc=$RC_W7) — silent Modo B off, promise unmet"
fi
rm -rf "$BROKEN" "$ISO_HOME_W7"

# Control leg: a TRUE no-git dir emits the same rev-parse failure but must
# stay SILENT (no log noise for a normal condition).
TRUE_NOGIT=$(mktemp -d)
mkdir -p "$TRUE_NOGIT/plain" "$TRUE_NOGIT/.claude/hooks"
cp "$HOOKS_SRC/anti-rationalization-gate.sh" "$TRUE_NOGIT/.claude/hooks/"
ISO_HOME_W7B=$(mktemp -d)
(cd "$TRUE_NOGIT/plain" && printf '{"stop_hook_active": false, "cwd": "%s", "transcript": "hello"}' "$TRUE_NOGIT/plain" | \
  HOME="$ISO_HOME_W7B" /bin/bash "$TRUE_NOGIT/.claude/hooks/anti-rationalization-gate.sh" >/dev/null 2>&1) || true
if [[ ! -f "$ISO_HOME_W7B/.ralph/logs/anti-rationalization-gate.log" ]]; then
  ok "true no-git directory stays silent (no false alarm)"
else
  bad "true no-git directory was LOGGED as broken — noisy false positive"
fi
rm -rf "$TRUE_NOGIT" "$ISO_HOME_W7B"

echo "=== T99-W8: plan-sync in a NON-GIT project — logical CLAUDE_PROJECT_DIR vs physical realpath (RETURN dominant 2) ==="
# mktemp on macOS returns the LOGICAL path (/var/...) while realpath resolves
# the PHYSICAL one (/private/var/...). A non-git project has no git to
# canonize the root, so pre-fix the boundary compared logical vs physical and
# rejected EVERY edit as "Path traversal" — the hook became a no-op with
# false security alarms.
NG_DIR=$(mktemp -d)   # logical form; intentionally NOT git-initialized
mkdir -p "$NG_DIR/.claude" "$NG_DIR/src"
cat > "$NG_DIR/src/plain.md" <<'EOF'
# plain project file
EOF
# The PLAN is written by whoever resolved paths with realpath — PHYSICAL
# form; CLAUDE_PROJECT_DIR arrives from the caller in LOGICAL form. That
# asymmetry is exactly what the pre-fix hook compared and rejected.
NG_PHYS=$(cd "$NG_DIR" && pwd -P)
cat > "$NG_DIR/.claude/plan-state.json" <<EOF
{"version":"1.0","task":"t99 nongit","steps":[{"id":"n1","name":"write plain","status":"in_progress","spec":{"file":"$NG_PHYS/src/plain.md","exports":[]},"actual":{}}]}
EOF
ISO_HOME_W8=$(mktemp -d)
SYNC_LOG_W8="$ISO_HOME_W8/.ralph/logs/plan-sync.log"
NG_OUT=$(cd "$NG_DIR" && printf '{"tool_input": {"file_path": "%s"}}' "$NG_DIR/src/plain.md" | \
  HOME="$ISO_HOME_W8" CLAUDE_PROJECT_DIR="$NG_DIR" /bin/bash "$HOOKS_SRC/plan-sync-post-step.sh" 2>/dev/null)
RC_W8=$?
NG_WROTE=$(jq -r '.steps[] | select(.id == "n1") | .actual.updated_at // ""' "$NG_DIR/.claude/plan-state.json" 2>/dev/null)
if [[ "$RC_W8" -eq 0 && -n "$NG_WROTE" ]]; then
  ok "non-git project edit accepted (logical root canonized before comparison)"
else
  bad "non-git project edit REJECTED as traversal (rc=$RC_W8) — logical-vs-physical mismatch back"
fi
if ! grep -q "Path traversal attempt blocked" "$SYNC_LOG_W8" 2>/dev/null; then
  ok "no false security alarm for the accepted edit"
else
  bad "false 'Path traversal' alarm logged for an in-project edit"
fi
cleanup "$NG_DIR" "$ISO_HOME_W8"

echo "=== T99-W9: a bare tests/.claude/ directory is NOT a project root marker (RETURN r3 finding 1) ==="
# THIS repo carries tests/.claude/ (a bare directory). With the previous
# marker (any .claude dir), a session running under tests/ adopted tests/
# as PROJECT_ROOT: plan invisible, Modo A and B silently OFF — the exact
# T87/T99 class, a regression vs v2.0.1. Only real .claude CONTENT (a plan,
# settings, hooks/) marks a project.
CONTAINER_W9=$(mktemp -d)
git -C "$CONTAINER_W9" init -q
git -C "$CONTAINER_W9" config user.email t99@test
git -C "$CONTAINER_W9" config user.name t99
mkdir -p "$CONTAINER_W9/.claude/hooks" "$CONTAINER_W9/tests/.claude" "$CONTAINER_W9/tests/sub"
cp "$HOOKS_SRC/anti-rationalization-gate.sh" "$CONTAINER_W9/.claude/hooks/"
NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '{"last_updated":"%s","task":"w9","steps":[{"name":"step","status":"in_progress"}]}' "$NOW_ISO" \
  > "$CONTAINER_W9/.claude/plan-state.json"
OUT_W9=$(cd "$CONTAINER_W9" && printf '{"stop_hook_active": false, "cwd": "%s/tests/sub", "transcript": "Should I continue?"}' "$CONTAINER_W9" | \
  /bin/bash "$CONTAINER_W9/.claude/hooks/anti-rationalization-gate.sh" 2>/dev/null || true)
if [[ "$OUT_W9" == *"Plan-immutability gate"* ]]; then
  ok "cwd under tests/ still sees the ROOT plan (bare tests/.claude ignored)"
else
  bad "bare tests/.claude/ adopted as root — Modo B silently OFF under tests/"
fi
rm -rf "$CONTAINER_W9"

echo
echo "=========================================="
echo "Passed: $PASS | Failed: $FAIL"
echo "=========================================="
exit $FAIL
