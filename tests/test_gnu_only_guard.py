"""Tests for scripts/check-gnu-only-commands.sh (T10-gnuguard, issue #54).

Proves the three faces every gate change must show (see QTEAM rules):
  1. Passes over the real tree (with the committed allowlist).
  2. FAILS on a freshly created violation, with file:line.
  3. The escape hatch ('gnu-ok') silences an annotated line.
Plus the two structural guarantees:
  4. Zero-scope is FAILURE, not pass (a gate that scanned nothing did not run).
  5. The allowlist is a ratchet: a stale entry fails until removed.
And the CI wiring stays in place.
"""
import re
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
GUARD = REPO / "scripts" / "check-gnu-only-commands.sh"
CI = REPO / ".github" / "workflows" / "ci.yml"


def _run_guard(cwd, *args):
    return subprocess.run(
        ["bash", str(GUARD), *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
        timeout=60,
    )


def _init_repo(tmp_path, files):
    """Create a throwaway git repo with the given {name: content} tracked."""
    for name, content in files.items():
        p = tmp_path / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
    subprocess.run(["git", "init", "-q"], cwd=str(tmp_path), check=True)
    subprocess.run(["git", "add", "-A"], cwd=str(tmp_path), check=True)
    return tmp_path


def test_guard_passes_over_tree():
    result = _run_guard(REPO, "--all")
    assert result.returncode == 0, result.stderr
    assert "OK" in result.stdout
    # Non-zero scope is part of the contract: 0 scanned files must not pass.
    assert "0 ficheros" not in result.stdout


def test_new_violation_fails_with_file_and_line(tmp_path):
    _init_repo(
        tmp_path,
        {
            "evil.sh": (
                "#!/usr/bin/env bash\n"
                "declare -A map\n"
                "find . -printf '%p\\n'\n"
            )
        },
    )
    result = _run_guard(tmp_path, "--all")
    assert result.returncode == 1, result.stdout + result.stderr
    combined = result.stdout + result.stderr
    assert "[GNU:declare-A] evil.sh:2" in combined
    assert "[GNU:find-printf] evil.sh:3" in combined


def test_escape_hatch_silences_annotated_line(tmp_path):
    _init_repo(
        tmp_path,
        {
            "probed.sh": (
                "#!/usr/bin/env bash\n"
                "declare -A map  # gnu-ok: CI image ships bash 4 (#49)\n"
            )
        },
    )
    result = _run_guard(tmp_path, "--all")
    assert result.returncode == 0, result.stdout + result.stderr


def test_zero_scope_is_failure_not_pass(tmp_path):
    # A repo with no tracked shell files: the guard must FAIL loudly, not
    # report green over an empty set.
    _init_repo(tmp_path, {"README.md": "no shell files here"})
    result = _run_guard(tmp_path, "--all")
    assert result.returncode == 1
    assert "0 ficheros" in result.stderr


def test_stale_allowlist_entry_fails_until_removed(tmp_path):
    # Ratchet: an allowlist entry whose file no longer violates must be
    # deleted. Simulated on a copy of the guard living in the temp repo's
    # scripts/ dir (so OWNING_REPO is true), with a fabricated entry.
    scripts_dir = tmp_path / "scripts"
    scripts_dir.mkdir(parents=True)
    text = GUARD.read_text()
    patched = re.sub(
        r"__GNU_ONLY_ALLOWLIST_START__.*?__GNU_ONLY_ALLOWLIST_END__",
        "__GNU_ONLY_ALLOWLIST_START__\nclean.sh|declare-A\n"
        "__GNU_ONLY_ALLOWLIST_END__",
        text,
        flags=re.DOTALL,
    )
    assert patched != text, "allowlist markers not found in guard source"
    (scripts_dir / "check-gnu-only-commands.sh").write_text(patched)
    _init_repo(tmp_path, {"clean.sh": "#!/usr/bin/env bash\necho clean\n"})

    result = subprocess.run(
        ["bash", "scripts/check-gnu-only-commands.sh", "--all"],
        cwd=str(tmp_path),
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert result.returncode == 1
    combined = result.stdout + result.stderr
    assert "obsoletas" in combined
    assert "clean.sh|declare-A" in combined


def test_ci_wiring_present():
    content = CI.read_text()
    assert "check-gnu-only-commands.sh --all" in content
    # Wired in the same job, right after the literal-tildes guard.
    tilde = content.index("check-literal-tilde.sh --all")
    gnu = content.index("check-gnu-only-commands.sh --all")
    assert gnu > tilde
