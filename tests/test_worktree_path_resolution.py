"""Path resolution must follow the CWD, not a session variable frozen at startup.

`CLAUDE_PROJECT_DIR` is captured once when the session begins and never moves. Inside a
worktree it points at THAT worktree, not at the main repo. `get_main_repo` used to return
it before consulting git, so once the CWD moved the answer described a directory nobody
was in.

The concrete failure this caused: repo-boundary-guard.sh resolves "the current repo"
through `get_main_repo`, so with a frozen variable every sibling worktree of the SAME
repository — and the parent repository itself — was reported as external and blocked.

These tests pin both directions: git wins while there is a repository, and the frozen
variable is used only when there is no git context at all.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
UTILS = REPO_ROOT / ".claude" / "hooks" / "lib" / "worktree-utils.sh"
GUARD = REPO_ROOT / ".claude" / "hooks" / "repo-boundary-guard.sh"


def _call(func: str, cwd: Path, env_value: str | None) -> str:
    """Run one worktree-utils function with a controlled CLAUDE_PROJECT_DIR."""
    setup = (
        f'export CLAUDE_PROJECT_DIR="{env_value}"' if env_value is not None
        else "unset CLAUDE_PROJECT_DIR"
    )
    script = f'source "{UTILS}"\n{setup}\n{func}\n'
    result = subprocess.run(
        ["bash", "-c", script], cwd=str(cwd), capture_output=True, text=True, timeout=30
    )
    assert result.returncode == 0, f"{func} failed: {result.stderr}"
    return result.stdout.strip()


@pytest.fixture(scope="module")
def paths() -> dict:
    def git(*args: str) -> str:
        return subprocess.run(
            ["git", *args], cwd=str(REPO_ROOT), capture_output=True, text=True, check=True
        ).stdout.strip()

    main_repo = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir")).parent
    return {
        "main": str(main_repo),
        "tree": git("rev-parse", "--show-toplevel"),
        # A plausible sibling worktree path that is NOT the current working tree.
        "frozen": str(main_repo / ".claude" / "worktrees" / "__frozen_env_fixture__"),
    }


@pytest.mark.skipif(not UTILS.is_file(), reason="worktree-utils.sh not present")
@pytest.mark.parametrize("env_key", ["frozen", "main", None], ids=["frozen-elsewhere", "main-repo", "unset"])
def test_get_main_repo_ignores_a_stale_env_var(paths, env_key):
    """Whatever the variable says, the main repo comes from git."""
    if env_key == "frozen":
        Path(paths["frozen"]).mkdir(parents=True, exist_ok=True)
    env_value = paths[env_key] if env_key else None
    assert _call("get_main_repo", REPO_ROOT, env_value) == paths["main"]


@pytest.mark.skipif(not UTILS.is_file(), reason="worktree-utils.sh not present")
@pytest.mark.parametrize("env_key", ["frozen", "main", None], ids=["frozen-elsewhere", "main-repo", "unset"])
def test_get_project_root_reports_the_current_tree(paths, env_key):
    """`get_project_root` must name the tree the CWD is actually in."""
    if env_key == "frozen":
        Path(paths["frozen"]).mkdir(parents=True, exist_ok=True)
    env_value = paths[env_key] if env_key else None
    assert _call("get_project_root", REPO_ROOT, env_value) == paths["tree"]


@pytest.mark.skipif(not UTILS.is_file(), reason="worktree-utils.sh not present")
def test_env_var_is_still_the_fallback_without_git(paths, tmp_path):
    """With no repository under the CWD there is nothing to ask git — only then does the
    session variable become the answer."""
    Path(paths["frozen"]).mkdir(parents=True, exist_ok=True)
    assert _call("get_main_repo", tmp_path, paths["frozen"]) == paths["frozen"]


@pytest.mark.skipif(not GUARD.is_file(), reason="repo-boundary-guard.sh not present")
def test_guard_allows_the_parent_repo_from_a_worktree(paths):
    """The end-to-end symptom: reaching the parent repo from its own worktree.

    This is a no-op when the tests run from the main repo (main == tree); it only has
    something to prove from inside a linked worktree.
    """
    if paths["main"] == paths["tree"]:
        pytest.skip("not running from a worktree — nothing to distinguish")

    payload = json.dumps({
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": f'ls {paths["main"]}/.claude/hooks'},
        "cwd": paths["tree"],
    })
    result = subprocess.run(
        ["bash", str(GUARD)],
        input=payload,
        capture_output=True,
        text=True,
        timeout=30,
        cwd=paths["tree"],
        env={"PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin", "HOME": str(Path.home())},
    )
    decision = json.loads(result.stdout)["hookSpecificOutput"]["permissionDecision"]
    assert decision == "allow", (
        "the parent repository is not external to its own worktree; "
        f"guard said {decision}: {result.stdout}"
    )
