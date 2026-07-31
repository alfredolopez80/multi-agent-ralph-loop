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


@pytest.fixture(scope="module")
def other_repo(tmp_path_factory) -> str:
    """A SECOND repo where `f.txt` is modified, to catch judging the wrong working tree."""
    repo = tmp_path_factory.mktemp("other_repo")

    def git(*args):
        subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True, check=True)

    git("init", "-q")
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "test")
    (repo / "deleted.txt").write_text("original\n")
    git("add", "-A")
    git("commit", "-qm", "init")
    (repo / "deleted.txt").write_text("valuable local edit\n")
    return str(repo)


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
def test_cd_moves_the_verdict_to_the_directory_the_command_lands_in(sample_repo, other_repo):
    """`cd` is followed, not refused.

    Worktree work is full of `cd <worktree> && git ...`; refusing to judge whenever a
    chain changes directory blocked an entirely harmless restore. What the `cd` really
    changes is WHICH working tree decides, so the guard tracks it:

      * `cd <repo where the file is deleted>`  -> harmless, allow.
      * `cd <repo where the file is modified>` -> the edits exist nowhere else, deny.

    The second case is the original defect: `deleted.txt` is deleted in the payload's cwd
    and modified in `other_repo`, so judging by the payload's cwd would have destroyed a
    real edit.
    """
    assert _decide(f"cd {sample_repo} && {RESTORE} deleted.txt", sample_repo) == "allow"
    assert _decide(f"cd {other_repo} && {RESTORE} deleted.txt", sample_repo) == "deny"


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
@pytest.mark.parametrize(
    "command, expected, why",
    [
        ("cd - && " + RESTORE + " deleted.txt", "deny", "`cd -` destination is not tracked"),
        ("cd && " + RESTORE + " deleted.txt", "deny", "bare `cd` goes to $HOME, not a repo"),
        ("cd /nonexistent-dir && " + RESTORE + " deleted.txt", "deny", "unreadable destination"),
        # A directory change the tracker cannot parse must fail closed, not fall back to
        # the stale cwd. Returning the stale directory judged `git restore` against the
        # tree the shell had already left — a fail-OPEN that allowed a destructive restore.
        ("pushd /somewhere && " + RESTORE + " deleted.txt", "deny", "pushd is not tracked"),
        ("popd && " + RESTORE + " deleted.txt", "deny", "popd is not tracked"),
        ("cd -P /nonexistent && " + RESTORE + " deleted.txt", "deny", "cd with an option is not tracked"),
    ],
)
def test_untrackable_cd_fails_closed(sample_repo, command, expected, why):
    """An undeterminable destination withholds the exemption; it never blocks the `cd`."""
    assert _decide(command, sample_repo) == expected, why


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
def test_quoted_cd_target_does_not_fail_open(sample_repo, other_repo):
    """`cd "path with spaces"` must not be judged against the payload's cwd.

    normalize_command strips the quotes before the guard sees the chain, so a spaced
    target arrives split across tokens. That form is not confidently trackable, so the
    exemption is withheld — the destructive restore in `other_repo` is denied rather than
    allowed by judging `sample_repo`, where the file happens to be deleted.
    """
    # `deleted.txt` is deleted in sample_repo (exemption would apply) and modified in
    # other_repo (restore is destructive). A spaced path forces the split-token form.
    assert _decide(f'cd "{other_repo} x" && {RESTORE} deleted.txt', sample_repo) == "deny"


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
def test_newline_separates_commands(sample_repo):
    """A newline is a command separator; a safe verb before it must not whiten the tail.

    `git status\\ngit restore modified.txt` is two commands. Collapsing the newline to a
    space fused them into one, and the unanchored safe-pattern match on the leading
    `git status` then vouched for the destructive `git restore`, which never got judged.
    """
    nl = "\n"
    assert _decide(f"git status{nl}{RESTORE} modified.txt", sample_repo) == "deny"
    assert _decide(f"git diff{nl}{RESTORE} modified.txt", sample_repo) == "deny"
    # Two genuinely safe reads across a newline stay allowed.
    assert _decide(f"git status{nl}git log", sample_repo) == "allow"
    # A newline before a harmless restore-of-deleted is still allowed.
    assert _decide(f"git status{nl}{RESTORE} deleted.txt", sample_repo) == "allow"


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
def test_background_ampersand_separates_commands(sample_repo):
    """A single `&` backgrounds the left command and runs the right one — it is a separator.

    `git status & git restore modified.txt` executes the restore; a safe leading verb must
    not whiten it. Redirect operators (`2>&1`, `&>`) keep their `&` and are not split.
    """
    amp = "&"
    assert _decide(f"git status {amp} {RESTORE} modified.txt", sample_repo) == "deny"
    assert _decide(f"git diff {amp} git reset --hard HEAD", sample_repo) == "deny"
    # Redirects must survive — the `&` in `2>&1` is not a separator.
    assert _decide("git log 2>&1", sample_repo) == "allow"
    # Two genuinely safe commands backgrounded together stay allowed.
    assert _decide(f"ls {amp} git status", sample_repo) == "allow"


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
@pytest.mark.parametrize(
    "wrapper",
    [
        "command cd", "builtin cd", "eval cd", "\\cd",
        # Wrappers that stack or carry a backslash / `time` also move the shell.
        "time cd", "\\command cd", "command eval cd", "eval eval cd",
        # Wrappers carrying their own options, and a stack deeper than any fixed bound —
        # an unresolvable wrapping must fail closed, not fall through to the stale cwd.
        "command -p cd", "time -p cd", "eval " * 7 + "cd",
    ],
)
def test_wrapped_cd_forms_fail_closed(sample_repo, other_repo, wrapper):
    """`command cd` / `builtin cd` / `eval cd` / `\\cd` all move the shell.

    Only bare `cd` was recognised, so these wrapped forms left the tracker on the STALE
    directory and a later `git restore` was judged against the repo the shell had left —
    a fail-open. They are now recognised as directory changes the parser cannot resolve,
    so the restore exemption is withheld (deny) rather than granted against the wrong tree.
    `deleted.txt` is deleted in sample_repo (exemption would apply there) and modified in
    other_repo (restore is destructive).
    """
    assert _decide(f"{wrapper} {other_repo} && {RESTORE} deleted.txt", sample_repo) == "deny"


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
def test_cd_itself_is_never_blocked(sample_repo, other_repo):
    """Changing directory is routine worktree work and carries no risk on its own."""
    for command in (
        f"cd {other_repo}",
        f"cd {other_repo} && git status",
        f"cd {other_repo} && git log --oneline",
    ):
        assert _decide(command, sample_repo) == "allow", command


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
def test_fails_closed_outside_a_git_repo(tmp_path):
    """No repo means no way to prove the file is deleted, so the block must hold."""
    assert _decide(f"{RESTORE} whatever.txt", str(tmp_path)) == "deny"


@pytest.mark.skipif(not GUARD.is_file(), reason="git-safety-guard.py not present")
def test_brace_group_cd_fails_closed(sample_repo, other_repo):
    """`{ cd DIR; }` moves the current shell — it must not leave the tracker on the stale cwd.

    `deleted.txt` is deleted in sample_repo (exemption would apply there) and modified in
    other_repo (restore is destructive). Judging the restore against sample_repo would allow
    the destructive restore, so the brace-group cd must force the exemption closed.
    """
    assert _decide(f"{{ cd {other_repo}; }} && {RESTORE} deleted.txt", sample_repo) == "deny"


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
