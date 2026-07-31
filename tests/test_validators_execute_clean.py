"""The repo's validate-*.sh scripts must run under CI, and must actually check something.

Three of these were broken for a long time without anyone noticing, because nothing ran
them automatically:

  * validate-hooks-registration.sh reported 0 of 49 (a matcher written with the field
    separator, plus paths resolved to the worktree instead of the main repo)
  * validate-skills-unification.sh died on its FIRST counter — `set -e` with `((PASS++))`
    on a variable holding 0 returns exit status 1 — and looked like a single failed check
  * validate-skills-registration.sh looked for a skill renamed two versions earlier

A validator nobody executes is documentation, not verification. These tests execute them
and enforce two conditions, per `testing-zero-tests-is-never-success`:

  1. exit status 0
  2. the run reports MORE THAN ZERO checks — a validator that silently aborts leaves its
     counters at zero, and "0 failed" would otherwise read as success
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"

# Validators that must pass cleanly on a healthy checkout, with the regex that finds the
# count of executed checks in their output. Each reports its tally differently.
VALIDATORS = [
    ("validate-hooks-registration.sh", re.compile(r"Total:\s*(\d+)", re.I)),
    ("validate-skills-registration.sh", re.compile(r"Total:\s*(\d+)", re.I)),
    ("validate-skills-unification.sh", re.compile(r"Passed[^:]*:\s*(\d+)", re.I)),
    ("validate-global-infrastructure.sh", re.compile(r"RESULTS:\s*(\d+)/", re.I)),
    ("validate-agents-registration.sh", re.compile(r"Passed:\s*(\d+)", re.I)),
]


def _strip_ansi(text: str) -> str:
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


# These validators inspect the local Claude install (~/.claude/skills, ~/.claude/agents,
# ~/.ralph). On a clean CI runner there is nothing to validate, so they skip — explicitly,
# never as a silent pass. The static check below (the `set -e` counter trap) has no such
# dependency and always runs.
requires_local_install = pytest.mark.skipif(
    not (Path.home() / ".claude" / "settings.json").is_file(),
    reason="no local Claude install (expected on CI; these validate an installation)",
)


@requires_local_install
@pytest.mark.parametrize("script_name, count_pattern", VALIDATORS, ids=[v[0] for v in VALIDATORS])
def test_validator_exits_clean(script_name: str, count_pattern: re.Pattern):
    script = SCRIPTS_DIR / script_name
    assert script.is_file(), f"validator missing: {script}"

    result = subprocess.run(
        ["bash", str(script)],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
        timeout=180,
    )
    output = _strip_ansi(result.stdout + result.stderr)

    assert result.returncode == 0, (
        f"{script_name} exited {result.returncode}:\n{output[-2000:]}"
    )

    match = count_pattern.search(output)
    assert match, (
        f"{script_name} produced no check count matching {count_pattern.pattern!r}. "
        f"Either the summary format changed or the script aborted before printing it:\n"
        f"{output[-2000:]}"
    )
    executed = int(match.group(1))
    assert executed > 0, (
        f"{script_name} exited 0 having executed {executed} checks. Zero checks is never "
        f"a pass — the script almost certainly aborted early (a classic cause is `set -e` "
        f"with `((COUNTER++))` on a counter holding 0).\n{output[-2000:]}"
    )


def test_no_validator_uses_the_set_e_counter_trap():
    """`((VAR++))` under `set -e` aborts the script when VAR is 0.

    The post-increment evaluates to the OLD value; 0 is exit status 1. Scripts must use
    `VAR=$((VAR+1))`, whose assignment always succeeds.
    """
    # Every shell script, not just validate-*.sh: the trap lived undetected in
    # ralph-doctor.sh, the setup-*.sh installers and gc-stale-worktrees.sh precisely
    # because the sweep only looked at validators. The guard is only as wide as its glob.
    offenders = {}
    for script in sorted(SCRIPTS_DIR.glob("*.sh")):
        text = script.read_text(encoding="utf-8", errors="replace")
        if not re.search(r"^\s*set\s+-[a-z]*e", text, re.M):
            continue
        bad = [
            line.strip()
            for line in text.splitlines()
            if re.search(r"\(\(\s*\w+\s*\+\+\s*\)\)", line) and not line.strip().startswith("#")
        ]
        if bad:
            offenders[script.name] = bad[:3]
    assert not offenders, (
        f"`set -e` scripts using `((VAR++))`, which aborts the run when VAR is 0: "
        f"{offenders}. Use `VAR=$((VAR+1))`."
    )
