#!/usr/bin/env bash
# skill-lint-wrapper.sh - Run the skill lint against the actual corpus.
#
# This is the gate entry: tests/run-all-unit-tests.sh invokes it. The
# wrapper points the lint at the worktree's real skills and hooks dirs,
# with the ignore file in .claude/skills/.skill-lint-ignore silencing
# known issues that are tracked elsewhere (e.g. Fable 5's smart-skill-reminder
# redesign).
#
# Exit codes:
#   0 = lint passed (no errors, scanned > 0)
#   1 = lint found errors OR scanned 0 skills
#
# `set -uo pipefail` per repo convention. We use `VAR=$((VAR+1))`, not
# `((VAR++))`, to avoid the zero-counter abort under set -e (see
# testing-zero-tests-is-never-success).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINT="$PROJECT_ROOT/scripts/skill-lint.py"
SKILLS_DIR="$PROJECT_ROOT/.claude/skills"
HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"

if [[ ! -x "$LINT" ]]; then
    echo "ERROR: lint not found at $LINT" >&2
    exit 2
fi
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "ERROR: skills dir not found at $SKILLS_DIR" >&2
    exit 2
fi
if [[ ! -d "$HOOKS_DIR" ]]; then
    echo "ERROR: hooks dir not found at $HOOKS_DIR" >&2
    exit 2
fi

python3 "$LINT" \
    --skills-dir "$SKILLS_DIR" \
    --hooks-dir "$HOOKS_DIR"
rc=$?
if [[ $rc -eq 0 ]]; then
    echo "Results: 1 passed, 0 failed"
fi
exit $rc
