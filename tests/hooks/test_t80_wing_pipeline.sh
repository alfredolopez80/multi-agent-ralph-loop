#!/usr/bin/env bash
# test_t80_wing_pipeline.sh - Regression tests for T80 (three fixes).
#
# T80(a): extractors derived the project from `git rev-parse --show-toplevel`
#     of their cwd — a worker in a worktree landed its facts under
#     projects/<worktree>/, so the wing compiler (which reads the root
#     project) never saw the team's work: the Wing was alive but blind.
#     Fix: project identity = get_main_repo (git-common-dir), the same
#     mechanism used everywhere else. Third member of the "cwd-derived
#     project key" family (ledger T67, PROJECT_NAME T64, extractors here).
# T80(b): facts file names stamped in UTC by extractors AND compiler, so a
#     session crossing midnight can never miss the other side's file.
# T80(c): the wing header is regenerated on every write. The append-only
#     body kept the first-ever "Compiled" line frozen (2026-04-09 for
#     months), which read as a stale artifact and produced two false
#     "fossil" conclusions. Now Created (stable) and Compiled (per-write)
#     are distinct fields.
#
# Sandbox-safe: exports its own HOME and RALPH_* paths; provisions fixture
# repos, worktrees, vaults and wings under mktemp.
#
# Usage: bash tests/hooks/test_t80_wing_pipeline.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d /tmp/t80-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME/.ralph/logs"
export RALPH_VAULT_DIR="$TMP/vault"
mkdir -p "$RALPH_VAULT_DIR/projects"

# ---------------------------------------------------------------------------
# (a) A fact produced FROM a worktree must land in the ROOT project.
# ---------------------------------------------------------------------------
test_fact_from_worktree_lands_in_root_project() {
    local R="$TMP/t80root" WT="$TMP/wt-t80wt"
    git init -q "$R" && git -C "$R" commit -q --allow-empty -m init \
        && git -C "$R" worktree add -q "$WT" -b t80wt >/dev/null 2>&1
    if [[ ! -d "$WT" ]]; then
        fail "(a) could not provision fixture worktree" "git worktree add failed"
        return
    fi
    local INPUT
    INPUT=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/lib.sh","content":"#!/bin/bash\\nfn_t80_marker() { echo x; }\\n"}}' "$WT")
    ( cd "$WT" && echo "$INPUT" | bash "$REPO_ROOT/.claude/hooks/semantic-realtime-extractor.sh" >/dev/null 2>&1 )
    sleep 1   # extractor backgrounds its writes
    local day root_fact wt_dir
    day=$(date -u +%Y%m%d)
    root_fact="$RALPH_VAULT_DIR/projects/t80root/facts/facts-${day}.md"
    wt_dir="$RALPH_VAULT_DIR/projects/t80wt"
    if [[ -f "$root_fact" ]] && grep -q "fn_t80_marker" "$root_fact"; then
        pass "(a) fact from worktree landed in ROOT project facts"
    else
        fail "(a) fact from worktree did not land in root project" "expected $root_fact with fn_t80_marker"
    fi
    if [[ -e "$wt_dir" ]]; then
        fail "(a) fragmenting worktree-keyed project dir exists" "$wt_dir should not exist"
    else
        pass "(a) no worktree-keyed project dir created"
    fi
}

# ---------------------------------------------------------------------------
# (b) The facts day stamp is timezone-invariant (UTC).
# ---------------------------------------------------------------------------
test_facts_today_is_tz_invariant() {
    local fn_semantic fn_decision a b u
    # One-line helper: extract with grep -m1 (an awk-to-} scan would swallow
    # the whole script body and execute it).
    fn_semantic=$(grep -m1 '^facts_today() {' .claude/hooks/semantic-realtime-extractor.sh)
    fn_decision=$(grep -m1 '^facts_today() {' .claude/hooks/decision-extractor.sh)
    if [[ -z "$fn_semantic" || -z "$fn_decision" ]]; then
        fail "(b) facts_today helper not found in extractors" "extraction returned empty"
        return
    fi
    a=$(TZ=Pacific/Kiritimati bash -c "$fn_semantic; facts_today")
    b=$(TZ=America/Anchorage bash -c "$fn_semantic; facts_today")
    u=$(date -u +%Y%m%d)
    if [[ "$a" == "$b" && "$a" == "$u" ]]; then
        pass "(b) semantic facts_today is UTC across adversarial timezones"
    else
        fail "(b) semantic facts_today varies with TZ" "kiritimati=$a anchorage=$b utc=$u"
    fi
    a=$(TZ=Pacific/Kiritimati bash -c "$fn_decision; facts_today")
    if [[ "$a" == "$u" ]]; then
        pass "(b) decision facts_today is UTC"
    else
        fail "(b) decision facts_today varies with TZ" "kiritimati=$a utc=$u"
    fi
}

# ---------------------------------------------------------------------------
# (c) Two successive compilations -> two distinct Compiled stamps, stable
#     Created; and a pre-T80 wing (stale Compiled-only header) migrates.
# ---------------------------------------------------------------------------
run_compiler() {
    echo '{}' | RALPH_VAULT_DIR="$TMP/vault" RALPH_L2_DIR="$TMP/l2" \
        RALPH_LOG_FILE="$TMP/wing.log" \
        bash .claude/hooks/vault-wing-compiler.sh >/dev/null 2>&1
}

seed_fact() {  # $1 = fact line
    local day p
    day=$(date -u +%Y%m%d)
    p="$RALPH_VAULT_DIR/projects/multi-agent-ralph-loop/facts/facts-${day}.md"
    mkdir -p "$(dirname "$p")"
    printf -- '- [code_structure] %s (fixture)\n' "$1" >> "$p"
}

test_two_compilations_two_stamps() {
    export RALPH_L2_DIR="$TMP/l2" RALPH_LOG_FILE="$TMP/wing.log"
    mkdir -p "$RALPH_L2_DIR"
    seed_fact "fn_compile_one"
    run_compiler
    sleep 1
    seed_fact "fn_compile_two"
    run_compiler
    local f="$RALPH_L2_DIR/multi-agent-ralph-loop/context.md"
    local c1 c2
    c1=$(grep -m1 '^\*\*Created\*\*:' "$f" | sed 's/.*: //')
    c2=$(grep -m1 '^\*\*Compiled\*\*:' "$f" | sed 's/.*: //')
    if [[ -n "$c1" && -n "$c2" && "$c1" != "$c2" ]]; then
        pass "(c) successive compilations carry distinct stamps (Created=$c1 Compiled=$c2)"
    else
        fail "(c) stamps not distinct" "Created=$c1 Compiled=$c2"
    fi
    if grep -q "fn_compile_one" "$f" && grep -q "fn_compile_two" "$f"; then
        pass "(c) both facts present after recompilation"
    else
        fail "(c) a fact was lost on recompilation" "body not preserved"
    fi
}

test_pret80_wing_migrates_created() {
    local f="$TMP/l2/multi-agent-ralph-loop/context.md"
    mkdir -p "$(dirname "$f")"
    cat > "$f" <<'EOF'
# Wing: multi-agent-ralph-loop

**Project**: multi-agent-ralph-loop
**Compiled**: 2026-04-09T17:40:19Z
**Source**: vault-wing-compiler.sh (auto-generated)


- [code_structure] Shell function: legacy_fn (old/path.sh)
EOF
    seed_fact "fn_after_migration"
    run_compiler
    local created compiled
    created=$(grep -m1 '^\*\*Created\*\*:' "$f" | sed 's/.*: //')
    compiled=$(grep -m1 '^\*\*Compiled\*\*:' "$f" | sed 's/.*: //')
    if [[ "$created" == "2026-04-09T17:40:19Z" && "$compiled" != "2026-04-09T17:40:19Z" ]]; then
        pass "(c) pre-T80 wing: stale Compiled migrates to Created, fresh Compiled stamp"
    else
        fail "(c) migration wrong" "Created=$created Compiled=$compiled"
    fi
    if grep -q "legacy_fn" "$f" && grep -q "fn_after_migration" "$f"; then
        pass "(c) pre-T80 body preserved through migration"
    else
        fail "(c) body lost in migration" "old or new fact missing"
    fi
}

test_fact_from_worktree_lands_in_root_project
test_facts_today_is_tz_invariant
test_two_compilations_two_stamps
test_pret80_wing_migrates_created

echo
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
