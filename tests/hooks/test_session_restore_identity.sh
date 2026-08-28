#!/usr/bin/env bash
# test_session_restore_identity.sh - Regression test for T67.
#
# T67: session-start-restore-context.sh selected the "most recent" ledger by
#     global mtime over ~/.ralph/ledgers, a directory shared by every session
#     of every worktree. Four defects stacked:
#     A. selection: most-recent-global, no session/worktree discriminant;
#     B. reader identity collapsed: PROJECT_DIR came from get_main_repo,
#        which maps every worktree of a repo to the same root;
#     C. dead filter: it grepped "^## Project:", a heading no writer emits
#        (context-extractor.py writes "Project: <cwd>" under ## Environment),
#        and an empty match failed OPEN via [[ -z ... || ... ]];
#     D. choose-then-filter order: a newer foreign ledger masked the
#        session's own older ledger even when the filter worked.
#     Measured 2026-08-26 from ~/.ralph/logs/session-start-restore.log:
#     4,668 of 7,916 restores since 2026-01-30 crossed identities.
#
# Contract under test (v3.3.1): a ledger is restored only when its recorded
# identity ("Project: <path>", writer cwd toplevel) equals this session's
# worktree toplevel (get_project_root). Foreign-but-newer does not win;
# no own ledger restores nothing (fail-closed). The annotated escape hatch
# RALPH_RESTORE_CROSS_WORKTREE=true in features.json restores legacy
# most-recent-global behaviour.
#
# Usage: bash tests/hooks/test_session_restore_identity.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1
HOOK=".claude/hooks/session-start-restore-context.sh"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d /tmp/t67-restore.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# Fixtures ------------------------------------------------------------

make_ledger() {
    # Emits the real writer format: context-extractor.py puts the session's
    # cwd toplevel as "Project: <path>" inside ## Environment.
    # T99 r4 (lead-authorized): get_project_root now returns the CANONICAL
    # root, so the fixture identity must be born canonical too — otherwise
    # a /tmp vs /private/tmp symlink pair makes writer and reader disagree.
    local file="$1" project_path="$2" goal="$3"
    project_path="$(cd "$project_path" && pwd -P)"
    cat > "$file" <<EOF
# CONTINUITY_RALPH: fixture

Generated: 2026-08-26T00:00:00+00:00

## CURRENT GOAL
${goal}

## Environment
Type: cli | Capabilities: full
Project: ${project_path}
EOF
}

run_hook() {
    # $1 = worktree toplevel to run as (CLAUDE_PROJECT_DIR, no git in cwd)
    # T99 r4: canonized, matching get_project_root's canonical output.
    local identity
    identity="$(cd "$1" && pwd -P)"
    (
        cd "$TMP" || exit 1
        CLAUDE_PROJECT_DIR="$identity" \
        RALPH_LEDGER_DIR="$TMP/ledgers" \
        RALPH_HANDOFF_DIR="$TMP/handoffs" \
        RALPH_FEATURES_FILE="$TMP/features.json" \
        RALPH_LOG_FILE="$TMP/hook.log" \
        bash "$REPO_ROOT/$HOOK" <<< '{"session_id":"t67-fixture","project_dir":"'"$identity"'"}'
    ) 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty'
}

fresh_fixtures() {
    rm -rf "$TMP/ledgers" "$TMP/handoffs" "$TMP/features.json"
    mkdir -p "$TMP/ledgers" "$TMP/handoffs" "$TMP/wt-mine" "$TMP/wt-other"
}

# Tests ----------------------------------------------------------------

# 1. Green over the legitimate tree: own ledger present -> restored.
test_own_ledger_restored() {
    fresh_fixtures
    make_ledger "$TMP/ledgers/CONTINUITY_RALPH-own.md" "$TMP/wt-mine" "GOAL-OWN-SOLE"
    touch -t 202601010000 "$TMP/ledgers/CONTINUITY_RALPH-own.md"
    local out
    out=$(run_hook "$TMP/wt-mine")
    if grep -q "GOAL-OWN-SOLE" <<< "$out"; then
        pass "own ledger is restored when it is the only one"
    else
        fail "own ledger was not restored" "output lacked GOAL-OWN-SOLE"
    fi
}

# 2. Red on a fresh violation: a foreign ledger NEWER than ours must not be
#    restored, and must not mask our own older ledger.
test_foreign_newer_loses_to_own_older() {
    fresh_fixtures
    make_ledger "$TMP/ledgers/CONTINUITY_RALPH-own.md" "$TMP/wt-mine" "GOAL-OWN-OLDER"
    make_ledger "$TMP/ledgers/CONTINUITY_RALPH-foreign.md" "$TMP/wt-other" "GOAL-FOREIGN-NEWER"
    touch -t 202601010000 "$TMP/ledgers/CONTINUITY_RALPH-own.md"
    touch -t 202601020000 "$TMP/ledgers/CONTINUITY_RALPH-foreign.md"   # newer
    local out
    out=$(run_hook "$TMP/wt-mine")
    if grep -q "GOAL-OWN-OLDER" <<< "$out" && ! grep -q "GOAL-FOREIGN-NEWER" <<< "$out"; then
        pass "foreign newer ledger neither restored nor masking own older ledger"
    else
        fail "foreign ledger won or masked own" "own=$(grep -c GOAL-OWN-OLDER <<< "$out") foreign=$(grep -c GOAL-FOREIGN-NEWER <<< "$out")"
    fi
}

# 2b. Fail-closed: no own ledger at all -> restore nothing, not even the
#     newest foreign one.
test_no_own_ledger_restores_nothing() {
    fresh_fixtures
    make_ledger "$TMP/ledgers/CONTINUITY_RALPH-foreign.md" "$TMP/wt-other" "GOAL-FOREIGN-ONLY"
    touch -t 202601020000 "$TMP/ledgers/CONTINUITY_RALPH-foreign.md"
    local out
    out=$(run_hook "$TMP/wt-mine")
    if grep -q "Context restored from most recent ledger" <<< "$out"; then
        fail "restored a foreign ledger with none of our own" "output contained a ledger restore"
    else
        pass "no own ledger -> no ledger restored (fail-closed)"
    fi
}

# 3. Escape hatch: RALPH_RESTORE_CROSS_WORKTREE=true silences the veto for
#    the annotated legacy case (cross-worktree restore on purpose).
test_escape_hatch_restores_foreign() {
    fresh_fixtures
    printf '{"RALPH_RESTORE_CROSS_WORKTREE": true}' > "$TMP/features.json"
    make_ledger "$TMP/ledgers/CONTINUITY_RALPH-foreign.md" "$TMP/wt-other" "GOAL-FOREIGN-HATCH"
    touch -t 202601020000 "$TMP/ledgers/CONTINUITY_RALPH-foreign.md"
    local out
    out=$(run_hook "$TMP/wt-mine")
    if grep -q "GOAL-FOREIGN-HATCH" <<< "$out"; then
        pass "escape hatch RALPH_RESTORE_CROSS_WORKTREE restores the foreign ledger"
    else
        fail "escape hatch did not restore the annotated foreign ledger" "output lacked GOAL-FOREIGN-HATCH"
    fi
}

# 4. The dead-filter pattern must not come back: the old code accepted any
#    ledger whose "^## Project:" grep was empty (fail-open), and compared it
#    to a get_main_repo-derived name (identity collapsed).
test_dead_filter_pattern_absent() {
    if grep -q 'get_most_recent_ledger_for_identity' "$HOOK" \
       && ! grep -q -- '-z "$LEDGER_PROJECT"' "$HOOK"; then
        pass "hook selects via identity filter; fail-open LEDGER_PROJECT branch is gone"
    else
        fail "dead-filter pattern regressed" "identity selector missing or -z LEDGER_PROJECT branch present"
    fi
}

test_own_ledger_restored
test_foreign_newer_loses_to_own_older
test_no_own_ledger_restores_nothing
test_escape_hatch_restores_foreign
test_dead_filter_pattern_absent

echo
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
