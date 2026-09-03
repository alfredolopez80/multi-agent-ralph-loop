"""The Codex→Claude agents/skills are distributed as COPIES, and copies must not drift.

PR #31 converted a set of review/bug agents and the bugs/security skills to be Claude-native
(no hard Codex dependency). They are distributed to ~/.claude as COPIES rather than symlinks so
a stale or moved repo checkout cannot resurrect their old Codex-dependent version
(docs/architecture/DISTRIBUTION_POLICY.md). The inverse risk of a copy is SILENT drift, so the
installer ships a `--check` parity gate — these tests keep it honest.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALLER = REPO_ROOT / "scripts" / "install-claude-native-agents.sh"

EXPECTED_AGENTS = [
    "debugger", "docs-writer", "frontend-reviewer", "ralph-security", "orchestrator",
    "codex-reviewer", "adversarial-plan-validator",
]
EXPECTED_SKILLS = ["bugs", "security"]


def test_installer_exists_and_is_valid_bash():
    assert INSTALLER.is_file(), f"missing installer: {INSTALLER}"
    proc = subprocess.run(["bash", "-n", str(INSTALLER)], capture_output=True, text=True)
    assert proc.returncode == 0, f"syntax error in installer:\n{proc.stderr}"


def test_installer_covers_the_full_conversion_set():
    """If an agent/skill was converted off Codex, it must be in the copy set — else it stays a
    symlink and can silently revert to the stale Codex version."""
    text = INSTALLER.read_text(encoding="utf-8")
    for name in EXPECTED_AGENTS + EXPECTED_SKILLS:
        assert name in text, f"{name} missing from the Claude-native copy set in {INSTALLER.name}"


def test_installer_has_a_zero_work_guard():
    """A sync/check that touched nothing must never report success (repo rule)."""
    text = INSTALLER.read_text(encoding="utf-8")
    assert "$total -eq 0" in text or "total -eq 0" in text, (
        "installer lacks a zero-work guard: a run that synced/checked nothing could exit 0"
    )


@pytest.mark.skipif(
    not (Path.home() / ".claude" / "agents").is_dir(),
    reason="no local ~/.claude/agents install (expected on CI; parity is a local-install gate)",
)
def test_installed_copies_match_the_repo():
    """`--check` must pass: every installed copy is byte-identical to the repo source."""
    proc = subprocess.run(
        ["bash", str(INSTALLER), "--check"], capture_output=True, text=True, timeout=60
    )
    output = proc.stdout + proc.stderr
    assert proc.returncode == 0, (
        f"Claude-native copies drifted (or are still symlinks). "
        f"Fix: bash scripts/install-claude-native-agents.sh\n{output[-1500:]}"
    )
