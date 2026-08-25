#!/usr/bin/env bash
#===============================================================================
# test-wt-lead-scripts.sh - Scope and provenance guards in the wt-lead scripts
#
# These two scripts are the only thing standing between a worker branch and
# `main`, and both guards they implement failed open when the skills were first
# integrated. Each case below was reproduced against the unfixed scripts before
# being written down:
#
#   review.sh    `git diff --name-only` runs with rename detection on (git's
#                default; diff.renames=99 on the author's machine), which
#                collapses a rename to its DESTINATION alone. A worker could
#                delete any file in the repository by moving it into its own
#                allowed directory, and the allowed-paths check printed
#                "OK: all changed files inside allowed paths".
#
#   review.sh    An allowed path written in the directory form the skill itself
#                documents (`strategies/`) was compared as `strategies//*` and
#                matched nothing, so in-scope work was reported OUTSIDE and
#                would have been returned to the worker for no reason.
#
#   integrate.sh `git cherry-pick` resolves any commit it is handed. A stale or
#                mistyped sha landed an unreviewed commit from an unrelated
#                branch on `main` while the script printed OK -- the review
#                covered the branch, never that sha.
#
# The control case at the end matters as much as the guards: a fix that refuses
# everything would pass the first three checks and be useless.
#===============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REVIEW="${REPO_ROOT}/.claude/skills/wt-lead/scripts/review.sh"
INTEGRATE="${REPO_ROOT}/.claude/skills/wt-lead/scripts/integrate.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
PASS=0
FAIL=0

check() { # check <label> <expected-rc> <actual-rc>
    if [[ "$2" == "$3" ]]; then
        printf "  ${GREEN}PASS${NC}  %-52s\n" "$1"
        PASS=$((PASS + 1))
    else
        printf "  ${RED}FAIL${NC}  %-52s expected=%s actual=%s\n" "$1" "$2" "$3"
        FAIL=$((FAIL + 1))
    fi
}

for f in "$REVIEW" "$INTEGRATE"; do
    [[ -x "$f" ]] || { echo "FAIL: $f missing or not executable" >&2; exit 1; }
done

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

cd "$SB" || exit 1
git init -q .
git config user.email test@example.invalid
git config user.name "wt-lead test"
mkdir -p allowed outside
echo a > allowed/keep.txt
echo b > outside/data.txt
git add -A && git commit -qm "init"
git branch -M main

# Worker branch: one out-of-scope rename, one legitimate in-scope commit.
git checkout -qb worktree-zc
git mv outside/data.txt allowed/data.txt
git commit -qm "zc: move data into allowed"
echo c > allowed/filter.py
git add -A && git commit -qm "zc: add filter"
LEGIT="$(git rev-parse HEAD)"

# A branch the lead must not be able to cherry-pick while naming worktree-zc.
git checkout -q main
git checkout -qb rama-ajena
echo x > outside/evil.txt
git add -A && git commit -qm "unrelated commit"
ALIEN="$(git rev-parse HEAD)"
git checkout -q main

echo "== review.sh: a rename out of scope is reported, not hidden"
out="$(bash "$REVIEW" worktree-zc "allowed" 2>&1)"
grep -q "OUTSIDE: outside/data.txt" <<< "$out"; check "deleted source endpoint is flagged" 0 $?
grep -q "OK: all changed files inside" <<< "$out"; check "the OK line is withheld" 1 $?

echo "== review.sh: the documented 'dir/' form still matches"
out="$(bash "$REVIEW" worktree-zc "allowed/,outside/" 2>&1)"
grep -q "OUTSIDE:" <<< "$out"; check "no false OUTSIDE for trailing slashes" 1 $?
grep -q "OK: all changed files inside" <<< "$out"; check "OK when everything is in scope" 0 $?

echo "== integrate.sh: a sha outside the named branch is refused"
bash "$INTEGRATE" worktree-zc "$ALIEN" > /dev/null 2>&1
check "alien sha refused" 1 $?
[[ "$(git log -1 --format=%s)" == "init" ]]; check "main is untouched after the refusal" 0 $?

echo "== control: a sha that IS on the branch still integrates"
bash "$INTEGRATE" worktree-zc "$LEGIT" > /dev/null 2>&1
check "legitimate sha accepted" 0 $?
[[ -f allowed/filter.py ]]; check "the cherry-picked file landed on main" 0 $?

TOTAL=$((PASS + FAIL))
echo
echo "Total: ${TOTAL}  |  Pass: ${PASS}  |  Fail: ${FAIL}"

# Two conditions, not one: a run that asserted nothing is not a pass.
if [[ "$TOTAL" -eq 0 ]]; then
    echo -e "${RED}FAIL: zero checks executed${NC}" >&2
    exit 1
fi
[[ "$FAIL" -eq 0 ]] || exit 1
echo -e "${GREEN}All checks passed${NC}"
