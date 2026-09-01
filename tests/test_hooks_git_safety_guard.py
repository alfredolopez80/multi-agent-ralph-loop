"""Regression tests for git-safety-guard.py v2.71.0 (T25).

Two behavior changes, each tested in BOTH directions (a test that only
checks that what used to fail now passes leaves the door open to having
broken the protection):

  1. Rebase on shared branches is context-aware: `git rebase main` is
     allowed from a worktree-* branch (the documented wt-worker protocol)
     and denied from any other branch — main itself above all, which is
     the case the rule existed for. Empty branch (detached HEAD / not a
     repo / git failure) fails closed: no exemption.
  2. The DESTRUCTIVE_INNER `rm` token is word-anchored: "confirm the
     change", "platform notes", "perform a check" and "transform data"
     are plain text, while `rm -rf <absolute path>` still denies.
"""
import json
import os
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
GUARD = REPO / ".claude" / "hooks" / "git-safety-guard.py"


def make_repo(tmp_path, branch):
    """A real git repo checked out on `branch` (with one commit)."""
    repo = tmp_path / branch
    repo.mkdir()
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=str(repo), check=True)
    (repo / "f.txt").write_text("x")
    subprocess.run(["git", "add", "-A"], cwd=str(repo), check=True)
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "init"],
        cwd=str(repo), check=True,
    )
    if branch != "main":
        subprocess.run(["git", "checkout", "-q", "-b", branch], cwd=str(repo), check=True)
    return repo


def run_guard(cwd, command):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
    result = subprocess.run(
        ["python3", str(GUARD)],
        input=payload, capture_output=True, text=True,
        cwd=str(cwd), timeout=30,
    )
    return json.loads(result.stdout)["hookSpecificOutput"]


# --- Rebase context-aware: both directions ---

def test_rebase_main_from_worktree_branch_allows(tmp_path):
    repo = make_repo(tmp_path, "worktree-zc")
    decision = run_guard(repo, "git rebase main")["permissionDecision"]
    assert decision == "allow"


def test_rebase_main_from_main_denies(tmp_path):
    repo = make_repo(tmp_path, "main")
    decision = run_guard(repo, "git rebase main")["permissionDecision"]
    assert decision == "deny"


def test_rebase_master_from_feature_branch_denies(tmp_path):
    repo = make_repo(tmp_path, "feature-x")
    decision = run_guard(repo, "git rebase master")["permissionDecision"]
    assert decision == "deny"


def test_rebase_shared_from_detached_head_denies(tmp_path):
    # Empty branch name (detached HEAD) fails closed: no worktree exemption.
    repo = make_repo(tmp_path, "worktree-zc")
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=str(repo),
                          capture_output=True, text=True, check=True).stdout.strip()
    subprocess.run(["git", "checkout", "-q", "--detach", head], cwd=str(repo), check=True)
    decision = run_guard(repo, "git rebase main")["permissionDecision"]
    assert decision == "deny"


def test_rebase_nonshared_target_unchanged(tmp_path):
    # A non-shared rebase target never matched the rule — still allowed.
    repo = make_repo(tmp_path, "main")
    decision = run_guard(repo, "git rebase feature-x")["permissionDecision"]
    assert decision == "allow"


# --- rm anchored: false positives gone, real rm intact ---

@pytest.mark.parametrize("text", [
    "echo confirm the change",
    "echo platform notes",
    "echo 'perform a check'",
    "echo transform data",
])
def test_rm_false_positives_allow(tmp_path, text):
    repo = make_repo(tmp_path, "main")
    decision = run_guard(repo, text)["permissionDecision"]
    assert decision == "allow"


def test_rm_rf_absolute_path_still_denies(tmp_path):
    repo = make_repo(tmp_path, "main")
    # The target must be an ABSOLUTE NON-TEMP path on every platform: pytest's
    # tmp_path is /tmp/pytest-of-*/ on Linux (inside the guard's safe-temp
    # prefixes, so the guard would correctly ALLOW it) and /private/var/folders/
    # on macOS (non-temp, deny). A synthetic non-existent path pins the intent
    # — the guard matches text, not the filesystem — and stays deterministic.
    decision = run_guard(repo, "rm -rf /home/definitely/not/temp/versionado")["permissionDecision"]
    assert decision == "deny"
