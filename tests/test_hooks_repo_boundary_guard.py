"""Regression tests for repo-boundary-guard.sh v2.99.0 (T23, issue #61).

One test per defect uncovered by the SECURITY_BASELINE fixture work. The
semantics that make these tests valid (manifest property): the boundary is
GITHUB_DIR-scoped BY DESIGN — paths outside ~/Documents/GitHub are allowed
on purpose, so every deny fixture targets a path under an isolated
GITHUB_DIR (HOME override on a PHYSICALLY resolved temp dir — macOS symlinks
/tmp and /var, and a non-physical path silently fails the prefix match).
"""
import json
import os
import subprocess
import tempfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
GUARD = REPO / ".claude" / "hooks" / "repo-boundary-guard.sh"


def _tmpdir_physical():
    """mktemp dir resolved through symlinks (what pwd -P gives in shell)."""
    return Path(os.path.realpath(tempfile.mkdtemp()))


def run_boundary(home, file_path):
    payload = json.dumps({"tool_name": "Edit",
                          "tool_input": {"file_path": str(file_path)}})
    env = dict(os.environ)
    env["HOME"] = str(home)
    return subprocess.run(
        ["bash", str(GUARD)],
        input=payload, capture_output=True, text=True,
        env=env, cwd=str(REPO), timeout=30,
    )


def decision_of(result):
    return json.loads(result.stdout)["hookSpecificOutput"]["permissionDecision"]


def test_defect1_sentinel_is_consulted_and_denies(tmp_path):
    # Defect 1 (#61): __CANONICALIZE_FAILED__ was emitted and never compared —
    # log said "denying as precaution", verdict was ALLOW. Deterministic
    # trigger: a realpath stub that always fails, prepended to PATH (the guard
    # calls realpath only inside canonicalize, so nothing else is affected).
    # Note: exotic paths (symlink loops) no longer reach the sentinel — the
    # v2.99.0 ancestor walk reconstructs them textually — which is why the
    # stub is the honest way to exercise the sentinel contract.
    d = _tmpdir_physical()
    stub_dir = d / "bin"
    stub_dir.mkdir()
    stub = stub_dir / "realpath"
    stub.write_text("#!/bin/sh\nexit 1\n")
    stub.chmod(0o755)
    payload = json.dumps({"tool_name": "Edit",
                          "tool_input": {"file_path": str(d / "x" / "y.md")}})
    env = dict(os.environ)
    env["HOME"] = str(d)
    env["PATH"] = f"{stub_dir}:{env['PATH']}"
    result = subprocess.run(
        ["bash", str(GUARD)],
        input=payload, capture_output=True, text=True,
        env=env, cwd=str(REPO), timeout=30,
    )
    assert decision_of(result) == "deny", (
        "a path canonicalize cannot resolve must deny, not flow into "
        "'Allow other paths'"
    )


def test_defect2_multilevel_missing_path_resolves_and_denies(tmp_path):
    # Defect 2 (#61): both `realpath -m` branches were dead on macOS
    # ("illegal option -- m"), and the single dirname+basename fallback could
    # not resolve multi-level misses — the path fell to the sentinel and
    # ALLOWED. The portable ancestor walk now resolves it, and being under
    # GITHUB_DIR (isolated HOME) it denies as another repo path.
    d = _tmpdir_physical()
    target = d / "Documents" / "GitHub" / "a" / "b" / "c" / "x.md"
    result = run_boundary(d, target)
    assert decision_of(result) == "deny"


def test_defect3_symlinked_home_github_dir_denies(tmp_path):
    # Defect 3 (#61): GITHUB_DIR was built from raw $HOME while paths were
    # canonicalized — through a symlinked HOME the other-repo branch silently
    # failed to match. With GITHUB_DIR canonicalized, a symlinked HOME still
    # denies a path under it (resolved through the symlink).
    d = _tmpdir_physical()
    (d / "real" / "Documents" / "GitHub").mkdir(parents=True)
    os.symlink(d / "real", d / "ln")
    target = d / "ln" / "Documents" / "GitHub" / "fr" / "x.md"
    result = run_boundary(d / "ln", target)
    assert decision_of(result) == "deny"


def test_ephemeral_sibling_repo_still_denies(tmp_path):
    # The canonical positive-deny (manifest fixture semantics): another git
    # repo under an isolated GITHUB_DIR.
    d = _tmpdir_physical()
    fr = d / "Documents" / "GitHub" / "fr"
    fr.mkdir(parents=True)
    subprocess.run(["git", "-C", str(fr), "init", "-q"], check=True)
    result = run_boundary(d, fr / "x.md")
    assert decision_of(result) == "deny"
    assert "REPO BOUNDARY" in result.stdout


def test_in_repo_edit_still_allows():
    # No over-blocking: a legitimate in-repo Edit with the real HOME allows.
    result = run_boundary(Path.home(), REPO / "CLAUDE.md")
    assert decision_of(result) == "allow"
