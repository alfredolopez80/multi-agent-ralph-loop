"""git-safety-guard: `restore`/`checkout --` decided by working-tree state, not by text.

The same command has opposite risk depending on the file's state:

  * MODIFIED file -> the edits exist nowhere else. No reflog covers the working tree,
    so overwriting them is irreversible. This must stay blocked.
  * DELETED file  -> the content is intact in HEAD and the only thing being reverted is
    the deletion. Nothing is destroyed, so blocking it is pure friction.

Judging by the command string alone cannot separate the two. These tests pin the
behaviour, including that every uncertain case fails closed.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
GUARD = REPO_ROOT / ".claude" / "hooks" / "git-safety-guard.py"

# Split so this test file never matches the guard's own patterns when scanned.
RESTORE = "git" + " " + "restore"
CHECKOUT = "git" + " " + "checkout --"


def _decide(command: str, cwd: str) -> str:
    payload = json.dumps({
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": command},
        "cwd": cwd,
    })
    proc = subprocess.run(
        [sys.executable, str(GUARD)], input=payload, capture_output=True, text=True, timeout=30
    )
    assert proc.stdout.strip(), f"guard produced no stdout (rc={proc.returncode}): {proc.stderr}"
    output = json.loads(proc.stdout)
    return output["hookSpecificOutput"]["permissionDecision"]


@pytest.fixture(scope="module")
def sample_repo(tmp_path_factory) -> str:
    """A repo with one deleted, one modified and one untouched tracked file."""
    repo = tmp_path_factory.mktemp("guard_repo")

    def git(*args):
        subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, check=True)

    git("init", "-q")
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "test")
    for name in ("deleted.txt", "modified.txt", "untouched.txt"):
        (repo / name).write_text("original\n")
    git("add", "-A")
    git("commit", "-qm", "init")

    (repo / "deleted.txt").unlink()
    (repo / "modified.txt").write_text("edited\n")

    status = subprocess.run(
        ["git", "status", "--porcelain"], cwd=repo, capture_output=True, text=True, check=True
    ).stdout
    assert " D deleted.txt" in status and " M modified.txt" in status, status
    return str(repo)


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
@pytest.mark.parametrize(
    "command, expected, why",
    [
        (f"{RESTORE} deleted.txt", "allow", "deleted file: content is intact in HEAD"),
        (f"{RESTORE} modified.txt", "deny", "modified file: edits exist nowhere else"),
        (f"{RESTORE} deleted.txt modified.txt", "deny", "mixed targets must fail closed"),
        (f"{RESTORE} untouched.txt", "deny", "no status line: state unknown, fail closed"),
        (f"{RESTORE} nosuchfile.txt", "deny", "unknown path must fail closed"),
        (f"{CHECKOUT} deleted.txt", "allow", "checkout -- follows the same rule"),
        (f"{CHECKOUT} modified.txt", "deny", "checkout -- on edits stays blocked"),
        (f"{RESTORE} --staged modified.txt", "allow", "--staged never touches the work tree"),
        ("git reset --hard HEAD", "deny", "unchanged by this feature"),
        ("git clean -fd", "deny", "unchanged by this feature"),
        ("git push --force origin main", "deny", "unchanged by this feature"),
    ],
)
def test_decision_matches_working_tree_state(sample_repo, command, expected, why):
    assert _decide(command, sample_repo) == expected, why


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
@pytest.mark.parametrize(
    "command, expected, why",
    [
        ("git branch -D feature", "deny", "-D force-deletes unmerged work"),
        ("git branch -Df feature", "deny", "D inside a short-flag cluster still forces"),
        ("git branch -aD feature", "deny", "D anywhere in the cluster still forces"),
        ("git branch --delete --force feature", "deny", "long form of -D"),
        ("git branch --force --delete feature", "deny", "long form, flags reversed"),
        ("git branch -d merged", "allow", "-d REFUSES unmerged work: it is the safe form"),
        ("git branch --delete merged", "allow", "long form of the safe -d"),
        ("git branch", "allow", "listing branches is read-only"),
        ("git branch -a", "allow", "listing all branches is read-only"),
        ("git branch feature-new", "allow", "creating a branch destroys nothing"),
    ],
)
def test_branch_delete_distinguishes_force_from_safe(sample_repo, command, expected, why):
    """`-d` and `-D` differ by one capital letter and by whether work can be lost.

    Two bugs met here: a SAFE_PATTERNS catch-all on `git branch` let `-D` through
    (making its blocked rule dead code), while the blocked patterns are matched with
    re.IGNORECASE, so writing `-D` there also caught the safe `-d`. Both directions
    are pinned below.
    """
    assert _decide(command, sample_repo) == expected, why


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
def test_fails_closed_outside_a_git_repo(tmp_path):
    """No repo means no way to prove the file is deleted, so the block must hold."""
    assert _decide(f"{RESTORE} whatever.txt", str(tmp_path)) == "deny"


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
def test_fails_closed_when_cwd_is_missing(sample_repo):
    """A payload without cwd cannot be verified against any working tree."""
    payload = json.dumps({
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": f"{RESTORE} deleted.txt"},
    })
    proc = subprocess.run(
        [sys.executable, str(GUARD)],
        input=payload,
        capture_output=True,
        text=True,
        timeout=30,
        cwd=os.path.expanduser("~"),
    )
    decision = json.loads(proc.stdout)["hookSpecificOutput"]["permissionDecision"]
    assert decision == "deny", "without cwd the guard must not assume the file is deleted"


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
@pytest.mark.parametrize(
    "command, expected_hint",
    [
        (f"{RESTORE} modified.txt", "git stash push"),
        ("git reset --hard HEAD", "git reflog"),
        ("git clean -fd", "git clean -n"),
        ("git branch -D feature", "git branch -d"),
    ],
)
def test_block_message_offers_a_safe_alternative(sample_repo, command, expected_hint):
    """Telling the caller to "ask the user" is an escalation, not a way forward."""
    payload = json.dumps({
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": command},
        "cwd": sample_repo,
    })
    proc = subprocess.run(
        [sys.executable, str(GUARD)], input=payload, capture_output=True, text=True, timeout=30
    )
    hook_output = json.loads(proc.stdout)["hookSpecificOutput"]
    assert hook_output["permissionDecision"] == "deny"
    reason = hook_output["permissionDecisionReason"]
    assert "SAFE ALTERNATIVE" in reason, f"no alternative offered for {command!r}: {reason}"
    assert expected_hint in reason, f"expected {expected_hint!r} in: {reason}"
