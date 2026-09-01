"""PR10 C4 (#69 Phase 4) — scope-correct CLAUDE.md absence/presence assertions.

Born green: every assertion below is already true of the consolidated tree,
and each one pins a cut (or a survivor) of the PR10 consolidation so a future
edit cannot silently regress it.

Interpretation notes (executor, zc-3):
  - A2's "no hook-registration tables" is implemented as the table-cell form
    ("| `git-safety-guard.py`"): the Security Hooks section legitimately names
    hooks in plain prose — naming what exists is not registering it.
  - A9's "bash -n-clean" for a Python file is implemented as an ast parse
    (the bash syntax check does not apply to .py sources).
"""

import ast
import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CLAUDE_MD = REPO / "CLAUDE.md"
EXAMPLE = REPO / ".claude" / "settings.json.example"
PROBE = REPO / "scripts" / "benchmark" / "claude_md_tokens.py"
HOOKS = REPO / ".claude" / "hooks"


def _content():
    return CLAUDE_MD.read_text()


def test_a1_no_repo_model_routing():
    """(A1) Model routing is a cross-project invariant — global scope only."""
    assert "## Model Routing" not in _content(), (
        "repo CLAUDE.md carries a Model Routing section again — that is global scope"
    )


def test_a2_no_hook_registration_tables():
    """(A2) The registration tables died once already; the authoritative lists
    are settings.json.example + validate-hooks-registration.sh."""
    content = _content()
    assert "| `git-safety-guard.py`" not in content, (
        "hook registration table row came back (table-cell form)"
    )
    assert "teammate-idle-quality-gate.sh" not in content, (
        "a hook name that rotted in the old table came back"
    )
    assert "Hook Events (12 configured)" not in content, (
        "the stale event-count claim came back"
    )


def test_a3_no_primary_settings_claim():
    """(A3) The ONLY-configuration-file claim is global scope; the repo copy
    duplicated it and the two drifted."""
    content = _content()
    assert "PRIMARY SETTINGS" not in content
    assert "ONLY configuration file" not in content


def test_a4_no_qteam_contract_rules_heading():
    """(A4) Contract-rule prose lives in the wt-lead/wt-worker skills and
    docs/qteam/QTEAM_FAILURE_MODES.md, not duplicated per-scope."""
    assert "### Q-team contract rules" not in _content()


def test_a5_session_coordination_pointers_present():
    """(A5) PRESENCE: the compression must not have eaten the load-bearing
    pointers — role detection, gate command, and the failure-mode catalog."""
    content = _content()
    for needle in (
        "wt-worker",
        "wt-lead",
        "QTEAM_TEST_CMD",
        "worktrees/<name>",
        "docs/qteam/QTEAM_FAILURE_MODES.md",
    ):
        assert needle in content, f"CLAUDE.md lost the {needle!r} pointer"


def test_a6_v3_integration_substrings_present():
    """(A6) PRESENCE: the four substrings tests/test_v3_integration.py pins.
    Cutting them would break that suite without this guard noticing why."""
    content = _content()
    for needle in ("3.0.0", "ralph-frontend", "ralph-security", "aristotle"):
        assert needle in content, (
            f"pinned substring {needle!r} lost — test_v3_integration will fail"
        )


def test_a7_line_budget():
    """(A7) Anthropic guidance: instruction files stay under 200 lines."""
    lines = _content().count("\n") + 1
    assert lines <= 200, f"CLAUDE.md grew to {lines} lines (guidance: <=200)"


def test_a8_example_records_memory_policy():
    """(A8, D5=yes) The example install profile carries the explicit-writes-
    only policy: native auto-memory off, belt-and-suspenders env var set."""
    data = json.loads(EXAMPLE.read_text())
    assert data.get("autoMemoryEnabled") is False, (
        "settings.json.example must set autoMemoryEnabled: false (D5)"
    )
    env = data.get("env", {})
    assert env.get("CLAUDE_CODE_DISABLE_AUTO_MEMORY") == "1", (
        "settings.json.example env must set CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 (D5)"
    )


def test_a9_probe_exists_and_unregistered():
    """(A9) The token probe exists, is syntax-clean, and NO hook references
    it — measuring stays on-demand (#69 line 359), never a per-session cost."""
    assert PROBE.exists(), f"probe missing: {PROBE}"
    ast.parse(PROBE.read_text())  # syntax-clean (bash -n does not apply to .py)
    offenders = [
        hook.name
        for hook in HOOKS.iterdir()
        if hook.is_file() and "claude_md_tokens" in hook.read_text(errors="ignore")
    ]
    assert offenders == [], f"hooks reference the probe (must stay unregistered): {offenders}"
