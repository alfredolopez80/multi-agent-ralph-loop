"""Three-assertion rule for the T57 Skills Drift section in
scripts/validate-global-infrastructure.sh.

T55/T56 found 11 of 61 skills drifted silently between repo and
~/.claude/skills/. The drift check makes that visible: it scans every
repo skill, distinguishes a symlinked entry (cannot drift) from an
independent copy (can), and FAILS on divergence.

The three assertions below prove the section behaves correctly:

  1. PASS over a synced tree (T56b guarantees this state)
  2. FAIL on a fresh drift violation (introduced, caught, removed)
  3. Escape hatch in $REPO/.claude/.skill-drift-ignore silences
     a named skill, with reason

Asserting on real artifacts in ~/.claude/skills/ is intentional: this
is a validator over the user's install, not a hermetic unit. Each
mutating test backs up and restores the file it touches, and the
ignore-file test deletes itself on teardown.
"""
from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

import pytest

# Compute the repo root from this file's location so the test works
# whether the runner is in the worktree or the main checkout — without
# depending on conftest's module-level REPO_ROOT (pytest auto-loads
# conftest but doesn't expose it as an importable module).
_REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = _REPO_ROOT / "scripts" / "validate-global-infrastructure.sh"
IGNORE_FILE = _REPO_ROOT / ".claude" / ".skill-drift-ignore"

# A skill that is normally an INDEPENDENT COPY in the global (not a
# symlink) — drift detection is meaningful only for these. Pick
# something we know is a copy from the T56b sync.
A_REAL_COPY_SKILL = "adversarial"


def _real_home() -> Path:
    """The HOME whose install is under test.

    Inside the unit runner, $HOME is a sandbox (run-all-unit-tests.sh) and
    the sandbox has no skills install; the runner exports the pre-sandbox
    home as RALPH_TEST_REAL_HOME for exactly these deployment-aware suites
    (fix-sweep-flaky, 2026-09-01). Standalone, $HOME is already the real
    home and the variable is unset.
    """
    return Path(os.environ.get("RALPH_TEST_REAL_HOME") or Path.home())


def _global_skills() -> Path:
    return _real_home() / ".claude" / "skills"


if not (_global_skills() / A_REAL_COPY_SKILL / "SKILL.md").is_file():
    pytest.skip(
        "deployment-aware suite: no ~/.claude/skills install under the tested "
        f"HOME ({_real_home()}) — the drift section validates the user's "
        "install, not a hermetic fixture",
        allow_module_level=True,
    )


def _run_validator() -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=str(_REPO_ROOT),
        capture_output=True,
        text=True,
        timeout=180,
        # The validator reads the install under $HOME — point it at the same
        # home whose skills the fixtures above mutate, not at whatever sandbox
        # the invoking runner happens to export.
        env={**os.environ, "HOME": str(_real_home())},
    )


def _strip_ansi(text: str) -> str:
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def _drift_section(stdout: str) -> str:
    """Return the Skills Drift section text."""
    m = re.search(
        r"=== Skills Drift.*?(?=\n=== |\Z)",
        stdout,
        re.DOTALL,
    )
    return m.group(0) if m else ""


def _results_line(stdout: str) -> str | None:
    m = re.search(r"RESULTS:\s*(\d+)/(\d+)\s+passed,\s*(\d+)\s+failed", stdout)
    return m.group(0) if m else None


# ─── Assertion 1: passes over synced tree ──────────────────────────────


def test_drift_section_passes_on_synced_tree():
    """T56b left 61/61 identical. The new section must report all pass
    and the validator must exit 0 with > 0 checks."""
    result = _run_validator()
    output = _strip_ansi(result.stdout + result.stderr)
    section = _drift_section(output)

    assert "Skills Drift" in section, (
        f"Skills Drift section missing from validator output:\n{output[-2000:]}"
    )
    assert "DRIFT" not in section, (
        f"validator reports drift on a synced tree — T56b sync was undone?\n{section}"
    )
    assert result.returncode == 0, (
        f"validator exited {result.returncode} on synced tree:\n{output[-2000:]}"
    )
    results = _results_line(output)
    assert results is not None, f"RESULTS line missing:\n{output[-2000:]}"
    m = re.match(r"RESULTS:\s*(\d+)/(\d+)\s+passed,\s*(\d+)\s+failed", results)
    assert m, f"RESULTS line malformed: {results!r}"
    executed = int(m.group(2))
    failed = int(m.group(3))
    assert executed > 0, "validator executed 0 checks — fail-open"
    assert failed == 0, f"validator reports failures on synced tree:\n{section}"


# ─── Assertion 2: FAILS on a fresh drift violation ──────────────────────


@pytest.fixture
def restored_skill_after_drift():
    """Introduce drift on one skill, yield, then restore from backup."""
    target = _global_skills() / A_REAL_COPY_SKILL / "SKILL.md"
    assert target.is_file(), (
        f"{A_REAL_COPY_SKILL} not a real copy in global — pick another"
    )
    backup = target.read_bytes()
    try:
        # Mutate the global copy so it differs from the repo.
        target.write_bytes(b"# tampered\ndrift injected for test\n")
        yield target
    finally:
        target.write_bytes(backup)


def test_drift_section_fails_on_fresh_violation(restored_skill_after_drift):
    """A change in the global copy must produce a [FAIL] in the
    Skills Drift section AND a non-zero exit."""
    result = _run_validator()
    output = _strip_ansi(result.stdout + result.stderr)
    section = _drift_section(output)

    assert f"{A_REAL_COPY_SKILL} → DRIFT" in section, (
        f"expected {A_REAL_COPY_SKILL} to be flagged DRIFT:\n{section}"
    )
    assert result.returncode != 0, (
        f"validator must exit non-zero when drift detected (got {result.returncode}):\n"
        f"{output[-1000:]}"
    )
    results = _results_line(output)
    assert results is not None
    m = re.match(r"RESULTS:\s*(\d+)/(\d+)\s+passed,\s*(\d+)\s+failed", results)
    failed = int(m.group(3))
    assert failed >= 1, f"expected at least 1 failure in RESULTS, got {results}"


# ─── Assertion 3: escape hatch silences an annotated case ──────────────


@pytest.fixture
def ignore_file():
    """Create a temporary ignore file with one entry, yield, then remove."""
    if IGNORE_FILE.exists():
        # Don't clobber a real one — back it up
        backup = IGNORE_FILE.read_bytes()
        had_pre_existing = True
    else:
        backup = None
        had_pre_existing = False
    IGNORE_FILE.parent.mkdir(parents=True, exist_ok=True)
    # T62: APPEND, never replace — a populated ignore (the T58 archive list)
    # is legitimate state; clobbering it made the validator see 24 archived
    # skills as drift and the exit-0 assertion failed. The fixture writes its
    # own entry on top of whatever already exists, and the finally-block
    # restores the original bytes as before.
    existing = backup.decode() if had_pre_existing else ""
    IGNORE_FILE.write_text(existing + f"{A_REAL_COPY_SKILL} | tampered drift test\n")
    try:
        yield IGNORE_FILE
    finally:
        if had_pre_existing:
            IGNORE_FILE.write_bytes(backup)
        else:
            IGNORE_FILE.unlink()


def test_escape_hatch_silences_annotated_skill(restored_skill_after_drift, ignore_file):
    """An entry in .skill-drift-ignore turns the same drift into PASS
    (ignored), and the validator exits 0 again."""
    result = _run_validator()
    output = _strip_ansi(result.stdout + result.stderr)
    section = _drift_section(output)

    assert f"{A_REAL_COPY_SKILL} → ignored (escape hatch)" in section, (
        f"expected {A_REAL_COPY_SKILL} silenced by ignore file:\n{section}"
    )
    assert f"{A_REAL_COPY_SKILL} → DRIFT" not in section, (
        f"silenced skill should not appear as DRIFT:\n{section}"
    )
    assert result.returncode == 0, (
        f"validator must exit 0 when the only drift is ignored (got {result.returncode}):\n"
        f"{output[-1000:]}"
    )


# ─── Bonus: empty ignore file / comment-only ────────────────────────────


def test_empty_ignore_file_is_a_noop(tmp_path):
    """An ignore file with only comments must not silence anything."""
    backup = IGNORE_FILE.read_bytes() if IGNORE_FILE.exists() else None
    IGNORE_FILE.parent.mkdir(parents=True, exist_ok=True)
    IGNORE_FILE.write_text("# nothing ignored\n\n")
    try:
        result = _run_validator()
        output = _strip_ansi(result.stdout + result.stderr)
        section = _drift_section(output)
        # All skills either "in sync" or "symlinked" — nothing silenced
        assert "ignored (escape hatch)" not in section, (
            f"empty ignore file silenced something:\n{section}"
        )
    finally:
        if backup is not None:
            IGNORE_FILE.write_bytes(backup)
        elif IGNORE_FILE.exists():
            IGNORE_FILE.unlink()
