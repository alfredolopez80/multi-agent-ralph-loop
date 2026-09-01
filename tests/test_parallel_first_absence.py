"""No-recreation assertions for the parallel-first policy removal (PR 5,
#69 Phase 3 Slice A; plan: results/PR5-PREP-plan.md).

Single source of absence truth for the slice: the rule file, its
distribution chain, its gate enforcement and its normative documentation
must stay gone. A failure here means someone re-introduced the mandatory
parallel-first policy — re-triage against #69 before touching this test
(the expected-failure must not outlive the removal it guards, and the
removal must not be silently reverted either).
"""

from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

NORMATIVE_DOCS = [
    "CLAUDE.md",
    "README.md",
    "docs/reference/anti-rationalization.md",
    ".claude/skills/ralph-reference/SKILL.md",
    ".claude/skills/orchestrator/SKILL.md",
]


def test_rule_file_absent():
    """The rule source was deleted (plan C4) and must not come back."""
    assert not (REPO / ".claude/rules-src/parallel-first.md").exists()


def test_sync_script_forgot_the_rule():
    """sync-rules-from-source.sh no longer distributes the rule (plan C3)."""
    text = (REPO / ".claude/scripts/sync-rules-from-source.sh").read_text(encoding="utf-8")
    assert "parallel-first" not in text


def test_validator_forgot_the_rule():
    """validate-global-infrastructure.sh no longer expects the rule (plan C3)."""
    text = (REPO / "scripts/validate-global-infrastructure.sh").read_text(encoding="utf-8")
    assert "parallel-first" not in text


def test_normative_docs_are_clean():
    """None of the normative surfaces mandates the retired policy (plan C1)."""
    for rel in NORMATIVE_DOCS:
        text = (REPO / rel).read_text(encoding="utf-8")
        assert "parallel-first" not in text.lower(), f"{rel} still cites parallel-first"


def test_install_profile_has_no_parallel_first_registration():
    """settings.json.example must not re-register a parallel-first enforcer
    (guard against re-registration through the install profile)."""
    text = (REPO / ".claude/settings.json.example").read_text(encoding="utf-8")
    assert "parallel-first" not in text.lower()


def test_validator_runs_without_parallel_first():
    """Executing check (PR5-HOTFIX): string-greps cannot see a validator's OWN
    checklist — validate-global-infrastructure.sh still gated the user's
    CLAUDE.md on the removed rule after the file greps were pruned. Run the
    validator and assert NO failing check mentions parallel-first.

    The exit code is NOT asserted as 0 here: other failures (e.g. installed-
    copy drift repaired by the lead/user via --fix) are deployment state this
    test does not own. returncode == 2 would mean the validator itself is
    broken as a script — that still fails this test.

    Hermetic since fix-sweep-flaky (2026-09-01): the subprocess runs against
    its own throwaway HOME, so the assertion does not depend on whether the
    invoking environment is the real machine or the runner's sandbox — under
    a bare HOME the validator reports ~64 deployment FAILs, and the skill
    literally named `parallel` (missing from ~/.claude/skills/) used to trip
    the old grep. The tripwire matches the RETIRED POLICY's canonical name,
    parallel-first — the exact string every other test in this file greps
    for, and the only name a reintroduced gate would carry.
    """
    import os
    import subprocess
    import tempfile

    with tempfile.TemporaryDirectory(prefix="pr5-validator-home-") as sandbox:
        p = subprocess.run(
            ["bash", str(REPO / "scripts" / "validate-global-infrastructure.sh")],
            text=True, capture_output=True, timeout=300,
            env={**os.environ, "HOME": sandbox},
        )
    assert p.returncode != 2, f"Validator script error (rc=2): {(p.stdout + p.stderr)[-400:]}"
    parallel_fails = [
        line for line in (p.stdout + p.stderr).splitlines()
        if "parallel-first" in line.lower() and ("FAIL" in line or "missing" in line.lower())
    ]
    assert not parallel_fails, f"Validator still gates on parallel-first: {parallel_fails}"
