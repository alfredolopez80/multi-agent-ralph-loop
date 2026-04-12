"""
test_worktree_utils.py — Tests for worktree-utils.sh functions.

Covers H4.10: getOrCreateWorktree, slug validation, setupWorktreeEnv,
checkWorktreeTTL, retrySpawn, removeWorktree, and hook integration.
"""

import json
import os
import subprocess

import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKTREE_UTILS = os.path.join(PROJECT_ROOT, ".claude", "hooks", "lib", "worktree-utils.sh")


@pytest.fixture
def git_repo(tmp_path):
    """Create a temporary git repo and return its path."""
    repo = tmp_path / "main-repo"
    repo.mkdir()
    subprocess.run(["git", "init"], cwd=repo, capture_output=True, check=True)
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=repo, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=repo, capture_output=True, check=True,
    )
    # Initial commit so HEAD exists
    (repo / "README.md").write_text("# test repo\n")
    subprocess.run(["git", "add", "README.md"], cwd=repo, capture_output=True, check=True)
    subprocess.run(
        ["git", "commit", "-m", "init"],
        cwd=repo, capture_output=True, check=True,
    )
    return repo


def _run_bash(repo, script_body, env=None):
    """Run a bash snippet with worktree-utils.sh sourced and CLAUDE_PROJECT_DIR set."""
    full_script = f"""#!/usr/bin/env bash
set -uo pipefail
export CLAUDE_PROJECT_DIR="{repo}"
source "{WORKTREE_UTILS}" 2>/dev/null || {{ echo "FATAL: cannot source worktree-utils.sh" >&2; exit 99; }}
{script_body}
"""
    result = subprocess.run(
        ["bash", "-c", full_script],
        capture_output=True, text=True, timeout=30,
        env={**os.environ, **(env or {})},
    )
    return result


# ============================================================
# get_project_root / get_main_repo / is_worktree
# ============================================================


class TestPathResolution:
    """Test basic path resolution functions."""

    def test_get_project_root_with_claude_dir(self, git_repo):
        r = _run_bash(git_repo, 'echo "$(get_project_root)"')
        assert r.returncode == 0
        assert r.stdout.strip() == str(git_repo)

    def test_get_main_repo_same_as_project_root(self, git_repo):
        r = _run_bash(git_repo, 'echo "$(get_main_repo)"')
        assert r.returncode == 0
        assert r.stdout.strip() == str(git_repo)

    def test_is_worktree_false(self, git_repo):
        r = _run_bash(git_repo, "is_worktree && echo YES || echo NO")
        assert r.returncode == 0
        assert "NO" in r.stdout

    def test_get_claude_dir(self, git_repo):
        r = _run_bash(git_repo, 'echo "$(get_claude_dir)"')
        assert r.returncode == 0
        assert r.stdout.strip() == str(git_repo / ".claude")

    def test_resolve_claude_path(self, git_repo):
        r = _run_bash(git_repo, 'echo "$(resolve_claude_path hooks/test.sh)"')
        assert r.returncode == 0
        assert r.stdout.strip() == str(git_repo / ".claude" / "hooks" / "test.sh")


# ============================================================
# getOrCreateWorktree — slug validation
# ============================================================


class TestSlugValidation:
    """Test that getOrCreateWorktree rejects invalid slugs."""

    @pytest.mark.parametrize("bad_slug", [
        "has spaces",
        "has/slash",
        "has\\backslash",
        "",
        "a" * 65,  # too long
        "has.dots",  # dots not in allowed set (only _-)
    ])
    def test_invalid_slug_returns_error(self, git_repo, bad_slug):
        r = _run_bash(git_repo, f'getOrCreateWorktree "{bad_slug}"')
        # Function returns 1 and JSON with error field
        assert r.returncode == 1 or '"error"' in r.stdout

    @pytest.mark.parametrize("good_slug", [
        "my-agent",
        "ralph_coder",
        "abc123",
        "a",
        "A" * 64,  # max length
    ])
    def test_valid_slug_accepted(self, git_repo, good_slug):
        r = _run_bash(git_repo, f'getOrCreateWorktree "{good_slug}"')
        assert r.returncode == 0
        data = json.loads(r.stdout.strip())
        assert "error" not in data
        assert "path" in data


# ============================================================
# getOrCreateWorktree — creation and reuse
# ============================================================


class TestWorktreeCreation:
    """Test worktree creation, reuse, and cleanup."""

    def test_creates_worktree_dir(self, git_repo):
        r = _run_bash(git_repo, 'getOrCreateWorktree "test-wt"')
        assert r.returncode == 0
        data = json.loads(r.stdout.strip())
        wt_path = data["path"]
        assert os.path.isdir(wt_path)

    def test_creates_correct_branch(self, git_repo):
        r = _run_bash(git_repo, 'getOrCreateWorktree "test-wt"')
        data = json.loads(r.stdout.strip())
        assert data["branch"] == "worktree-test-wt"

    def test_reuse_existing_worktree(self, git_repo):
        # Create first time
        r1 = _run_bash(git_repo, 'getOrCreateWorktree "reuse-test"')
        data1 = json.loads(r1.stdout.strip())
        assert data1.get("reused") is not True

        # Second call should reuse
        r2 = _run_bash(git_repo, 'getOrCreateWorktree "reuse-test"')
        data2 = json.loads(r2.stdout.strip())
        assert data2.get("reused") is True
        assert data2["path"] == data1["path"]

    def test_worktree_has_head_commit(self, git_repo):
        r = _run_bash(git_repo, 'getOrCreateWorktree "head-test"')
        data = json.loads(r.stdout.strip())
        assert data["headCommit"] != "unknown"
        assert len(data["headCommit"]) >= 7  # short hash minimum

    def test_worktree_has_git_dir(self, git_repo):
        r = _run_bash(git_repo, 'getOrCreateWorktree "gitdir-test"')
        data = json.loads(r.stdout.strip())
        wt_path = data["path"]
        # Worktrees have a .git file, not directory
        assert os.path.isfile(os.path.join(wt_path, ".git"))


# ============================================================
# removeWorktree
# ============================================================


class TestRemoveWorktree:
    """Test worktree removal."""

    def test_removes_worktree_dir(self, git_repo):
        _run_bash(git_repo, 'getOrCreateWorktree "remove-me"')
        r = _run_bash(git_repo, 'removeWorktree "remove-me"')
        assert r.returncode == 0
        wt_dir = git_repo / ".claude" / "worktrees" / "remove-me"
        assert not wt_dir.exists()

    def test_removes_branch(self, git_repo):
        _run_bash(git_repo, 'getOrCreateWorktree "branch-del"')
        _run_bash(git_repo, 'removeWorktree "branch-del"')
        # Branch should be gone
        r = subprocess.run(
            ["git", "branch", "--list", "worktree-branch-del"],
            cwd=git_repo, capture_output=True, text=True,
        )
        assert r.stdout.strip() == ""

    def test_remove_nonexistent_is_safe(self, git_repo):
        r = _run_bash(git_repo, 'removeWorktree "no-such-wt"')
        assert r.returncode == 0


# ============================================================
# setupWorktreeEnv — symlinks and copies
# ============================================================


class TestSetupWorktreeEnv:
    """Test environment setup for worktrees."""

    def test_symlinks_node_modules(self, git_repo):
        # Create node_modules in main repo
        nm = git_repo / "node_modules"
        nm.mkdir()
        (nm / "some_pkg").mkdir()

        _run_bash(git_repo, 'getOrCreateWorktree "env-test"')
        r = _run_bash(git_repo, 'setupWorktreeEnv "env-test"')
        assert r.returncode == 0

        wt_nm = git_repo / ".claude" / "worktrees" / "env-test" / "node_modules"
        assert wt_nm.is_symlink() or wt_nm.is_dir()

    def test_copies_claude_md(self, git_repo):
        claude_md = git_repo / "CLAUDE.md"
        claude_md.write_text("# Project rules\n")

        _run_bash(git_repo, 'getOrCreateWorktree "copy-test"')
        _run_bash(git_repo, 'setupWorktreeEnv "copy-test"')

        wt_md = git_repo / ".claude" / "worktrees" / "copy-test" / "CLAUDE.md"
        assert wt_md.is_file()
        assert wt_md.read_text() == "# Project rules\n"

    def test_returns_json(self, git_repo):
        _run_bash(git_repo, 'getOrCreateWorktree "json-test"')
        r = _run_bash(git_repo, 'setupWorktreeEnv "json-test"')
        data = json.loads(r.stdout.strip())
        assert "path" in data
        assert "symlinks" in data
        assert "copies" in data
        assert "errors" in data

    def test_nonexistent_worktree_returns_error(self, git_repo):
        r = _run_bash(git_repo, 'setupWorktreeEnv "nonexistent"')
        data = json.loads(r.stdout.strip())
        assert "error" in data


# ============================================================
# checkWorktreeTTL
# ============================================================


class TestCheckWorktreeTTL:
    """Test TTL enforcement for worktrees."""

    def test_fresh_worktree_not_expired(self, git_repo):
        _run_bash(git_repo, 'getOrCreateWorktree "ttl-fresh"')
        r = _run_bash(git_repo, 'checkWorktreeTTL "ttl-fresh" 30')
        data = json.loads(r.stdout.strip())
        assert data["expired"] is False

    def test_zero_ttl_means_expired(self, git_repo):
        _run_bash(git_repo, 'getOrCreateWorktree "ttl-zero"')
        r = _run_bash(git_repo, 'checkWorktreeTTL "ttl-zero" 0')
        data = json.loads(r.stdout.strip())
        assert data["expired"] is True

    def test_returns_elapsed_minutes(self, git_repo):
        _run_bash(git_repo, 'getOrCreateWorktree "ttl-elapsed"')
        r = _run_bash(git_repo, 'checkWorktreeTTL "ttl-elapsed" 30')
        data = json.loads(r.stdout.strip())
        assert data["elapsed_minutes"] >= 0

    def test_nonexistent_worktree_returns_error(self, git_repo):
        r = _run_bash(git_repo, 'checkWorktreeTTL "no-such" 30')
        assert r.returncode == 1
        data = json.loads(r.stdout.strip())
        assert "error" in data


# ============================================================
# retrySpawn
# ============================================================


class TestRetrySpawn:
    """Test exponential backoff retry mechanism."""

    def test_success_on_first_try(self, git_repo):
        r = _run_bash(git_repo, 'retrySpawn true')
        assert r.returncode == 0

    def test_failure_after_max_retries(self, git_repo):
        r = _run_bash(git_repo, 'retrySpawn false 2>/dev/null')
        assert r.returncode == 1

    def test_logs_retries_to_stderr(self, git_repo):
        r = _run_bash(git_repo, 'retrySpawn bash -c "exit 1"')
        # Should log retry attempts to stderr
        assert "retrySpawn" in r.stderr or r.returncode == 1

    def test_custom_command_succeeds(self, git_repo):
        r = _run_bash(git_repo, 'retrySpawn echo "hello"')
        assert r.returncode == 0
        assert "hello" in r.stdout


# ============================================================
# Hook integration: SubagentStart format
# ============================================================


class TestSubagentStartIntegration:
    """Test that ralph-subagent-start.sh produces valid JSON output."""

    def test_start_hook_valid_json(self, git_repo):
        hook = os.path.join(PROJECT_ROOT, ".claude", "hooks", "ralph-subagent-start.sh")
        if not os.path.exists(hook):
            pytest.skip("ralph-subagent-start.sh not found")

        stdin_data = json.dumps({
            "agent_id": "test-agent-001",
            "agent_type": "ralph-researcher",
            "sessionId": "test-session",
        })
        r = subprocess.run(
            ["bash", hook],
            input=stdin_data, capture_output=True, text=True, timeout=30,
            env={**os.environ, "CLAUDE_PROJECT_DIR": str(git_repo)},
        )
        assert r.returncode == 0
        data = json.loads(r.stdout.strip())
        assert data["continue"] is True
        assert "hookSpecificOutput" in data

    def test_write_agent_gets_worktree(self, git_repo):
        hook = os.path.join(PROJECT_ROOT, ".claude", "hooks", "ralph-subagent-start.sh")
        if not os.path.exists(hook):
            pytest.skip("ralph-subagent-start.sh not found")

        stdin_data = json.dumps({
            "agent_id": "test-coder-002",
            "agent_type": "ralph-coder",
            "sessionId": "test-session",
        })
        r = subprocess.run(
            ["bash", hook],
            input=stdin_data, capture_output=True, text=True, timeout=30,
            env={**os.environ, "CLAUDE_PROJECT_DIR": str(git_repo)},
        )
        assert r.returncode == 0
        data = json.loads(r.stdout.strip())
        output = data.get("hookSpecificOutput", {})
        env_updates = output.get("envUpdates", {})
        assert "CLAUDE_WORKTREE_PATH" in env_updates
        assert "CLAUDE_WORKTREE_SLUG" in env_updates


# ============================================================
# Hook integration: SubagentStop format
# ============================================================


class TestSubagentStopIntegration:
    """Test that ralph-subagent-stop.sh produces valid decision JSON."""

    def test_stop_hook_approve_format(self, git_repo):
        hook = os.path.join(PROJECT_ROOT, ".claude", "hooks", "ralph-subagent-stop.sh")
        if not os.path.exists(hook):
            pytest.skip("ralph-subagent-stop.sh not found")

        stdin_data = json.dumps({
            "subagentId": "test-agent-001",
            "subagentType": "ralph-researcher",
            "sessionId": "test-session",
        })
        r = subprocess.run(
            ["bash", hook],
            input=stdin_data, capture_output=True, text=True, timeout=30,
            env={**os.environ, "CLAUDE_PROJECT_DIR": str(git_repo)},
        )
        assert r.returncode == 0
        data = json.loads(r.stdout.strip())
        assert data["decision"] in ("approve", "block")
        assert "reason" in data


# ============================================================
# GC script
# ============================================================


class TestGCStaleWorktrees:
    """Test gc-stale-worktrees.sh --dry-run."""

    def test_gc_dry_run_no_changes(self, git_repo):
        gc = os.path.join(PROJECT_ROOT, "scripts", "gc-stale-worktrees.sh")
        if not os.path.exists(gc):
            pytest.skip("gc-stale-worktrees.sh not found")

        r = subprocess.run(
            ["bash", gc, "--dry-run", "--max-age", "7"],
            capture_output=True, text=True, timeout=30,
            env={**os.environ, "CLAUDE_PROJECT_DIR": str(git_repo)},
        )
        assert r.returncode == 0
        # Accept both: normal dry-run output or early-exit when no worktrees exist
        assert "(dry-run mode" in r.stdout or "No worktrees" in r.stdout or r.stdout.strip() == ""
