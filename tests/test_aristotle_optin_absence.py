"""No-recreation assertions for the unconditional Aristotle pipeline removal
(PR 6, #69 Phase 3 Slice B; plan: results/PR6-PREP-plan.md).

The methodology survives ONLY as the opt-in /aristotle skill (C2) and its
reference doc. A failure here means someone re-introduced the mandatory
pipeline (rule, distribution, hooks or registrations) — re-triage against
#69 before touching this test.
"""

from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

RETIRED_HOOKS = [
    "universal-prompt-classifier.sh",
    "aristotle-analysis-display.sh",
    "universal-aristotle-gate.sh",
]


def test_rule_file_absent():
    """The rule source was deleted (C4); the /aristotle skill replaces it."""
    assert not (REPO / ".claude/rules-src/aristotle-methodology.md").exists()


def test_sync_script_forgot_the_rule():
    """sync-rules-from-source.sh no longer distributes the rule."""
    text = (REPO / ".claude/scripts/sync-rules-from-source.sh").read_text(encoding="utf-8")
    assert "aristotle-methodology" not in text


def test_validator_rules_array_forgot_the_rule():
    """validate-global-infrastructure.sh RULES no longer expects the rule."""
    text = (REPO / "scripts/validate-global-infrastructure.sh").read_text(encoding="utf-8")
    assert "aristotle-methodology" not in text


def test_pipeline_hooks_absent():
    """The three per-prompt Aristotle hooks are deleted (plan C3)."""
    for name in RETIRED_HOOKS:
        assert not (REPO / ".claude/hooks" / name).exists(), f"{name} re-appeared"


def test_example_profile_registers_no_aristotle_pipeline():
    """settings.json.example must not re-register the retired hooks."""
    text = (REPO / ".claude/settings.json.example").read_text(encoding="utf-8")
    for name in ("universal-prompt-classifier", "aristotle-analysis-display", "universal-aristotle-gate"):
        assert name not in text, f"{name} re-registered in the install profile"


def test_claude_md_has_no_aristotle_threshold():
    """CLAUDE.md no longer carries the Aristotle process threshold (plan C1)."""
    text = (REPO / "CLAUDE.md").read_text(encoding="utf-8")
    assert "Aristotle >= 4" not in text
    assert "rules-src/aristotle-methodology.md" not in text
