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


def test_gate_has_no_parallel_fallback():
    """anti-rationalization-gate.sh carries no hardcoded parallel fallback
    (plan C2): neither the PARALLEL_EXCUSES block nor a pointer to the
    removed rule file."""
    text = (REPO / ".claude/hooks/anti-rationalization-gate.sh").read_text(encoding="utf-8")
    assert "PARALLEL_EXCUSES" not in text
    assert "parallel-first.md" not in text


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
