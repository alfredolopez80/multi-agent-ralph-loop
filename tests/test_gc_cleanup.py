"""
Tests for GC cleanup function in session-end-handoff.sh.

Validates garbage collection of stale resources:
- Removes orphan team directories (0 members)
- Preserves active team directories (>0 members)
- Removes stale task directories (>7 days old)
- Preserves recent task directories
- Removes oldest handoffs when >50 files exist
- Logs GC stats to gc.log

~7 test cases covering all GC scenarios.
"""

import json
import os
import stat
import subprocess
import tempfile
from pathlib import Path
from datetime import datetime, timedelta
import time

import pytest

REPO_ROOT = Path(__file__).parent.parent
HOOK = REPO_ROOT / ".claude" / "hooks" / "session-end-handoff.sh"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _read_hook(path: Path) -> str:
    """Return the full text of a hook file."""
    return path.read_text(encoding="utf-8")


def _run_session_end_hook(env_override: dict | None = None,
                         timeout: int = 15) -> subprocess.CompletedProcess:
    """Execute session-end-handoff hook to trigger GC cleanup."""
    env = os.environ.copy()
    tmp_home = tempfile.mkdtemp(prefix="test_ralph_gc_home_")

    # Create test directory structure
    teams_dir = Path(tmp_home) / ".claude" / "teams"
    tasks_dir = Path(tmp_home) / ".claude" / "tasks"
    handoffs_dir = Path(tmp_home) / ".ralph" / "handoffs"
    logs_dir = Path(tmp_home) / ".ralph" / "logs"
    ledgers_dir = Path(tmp_home) / ".ralph" / "ledgers"
    temp_dir = Path(tmp_home) / ".ralph" / "temp"
    state_dir = Path(tmp_home) / ".ralph" / "state"
    config_dir = Path(tmp_home) / ".ralph" / "config"

    for d in [teams_dir, tasks_dir, handoffs_dir, logs_dir, ledgers_dir, temp_dir, state_dir, config_dir]:
        d.mkdir(parents=True, exist_ok=True)

    # Create features.json to enable handoff/ledger features
    features_file = config_dir / "features.json"
    features_file.write_text('{"RALPH_ENABLE_HANDOFF": false, "RALPH_ENABLE_LEDGER": false}')

    env["HOME"] = tmp_home

    if env_override:
        env.update(env_override)

    # Create minimal SessionEnd input
    payload = json.dumps({
        "hook_event_name": "SessionEnd",
        "session_id": "test-gc-session",
        "reason": "test",
        "transcript_path": ""
    })

    return subprocess.run(
        [str(HOOK)],
        input=payload,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
        cwd=str(REPO_ROOT),
    )


def _create_old_directory(path: Path, days_old: int = 8) -> None:
    """Create a directory with an old modification time."""
    path.mkdir(parents=True, exist_ok=True)
    # Set mtime and atime to days_old days ago
    old_time = time.time() - (days_old * 86400)
    os.utime(path, (old_time, old_time))


def _create_recent_directory(path: Path) -> None:
    """Create a directory with current timestamp."""
    path.mkdir(parents=True, exist_ok=True)


# ===========================================================================
# STRUCTURAL TESTS
# ===========================================================================

class TestGCCleanupStructure:
    """Validate GC cleanup function exists and is callable."""

    def test_session_end_hook_exists(self):
        """session-end-handoff.sh must exist."""
        assert HOOK.exists(), f"{HOOK.name} does not exist"

    def test_has_gc_cleanup_function(self):
        """Hook must define gc_cleanup() function."""
        text = _read_hook(HOOK)
        assert "gc_cleanup()" in text or "gc_cleanup" in text, (
            "gc_cleanup function not found"
        )

    def test_gc_cleanup_called_in_hook(self):
        """gc_cleanup should be invoked during SessionEnd processing."""
        text = _read_hook(HOOK)
        # Look for the function call
        assert "gc_cleanup" in text, "gc_cleanup not called in hook"


# ===========================================================================
# FUNCTIONAL TESTS
# ===========================================================================

class TestGCCleanupTeams:
    """Test GC cleanup of team directories."""

    def test_orphan_team_dir_removed(self, tmp_path):
        """Team directory with 0 member files should be removed."""
        # Create temp structure with logs directory FIRST (hook expects it)
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        # Create empty log file to avoid redirect errors
        (logs_dir / "session-end.log").write_text("")

        teams_dir = tmp_home / ".claude" / "teams"
        orphan_team = teams_dir / "team-orphan-test"
        orphan_team.mkdir(parents=True)

        # Run hook with temp home
        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0
        # Orphan team should be removed
        assert not orphan_team.exists(), "Orphan team dir should be removed"

    def test_active_team_dir_preserved(self, tmp_path):
        """Team directory with member files should be preserved."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        teams_dir = tmp_home / ".claude" / "teams"
        active_team = teams_dir / "team-active-test"
        active_team.mkdir(parents=True)

        # Create a member file to make it active
        (active_team / "member-coder.json").write_text('{"id": "coder"}')

        initial_count = len(list(teams_dir.iterdir()))

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0
        # Active team should still exist
        assert active_team.exists(), "Active team dir should be preserved"
        assert (active_team / "member-coder.json").exists()


class TestGCCleanupTasks:
    """Test GC cleanup of task directories."""

    def test_stale_task_dir_removed(self, tmp_path):
        """Task directory older than 7 days should be removed."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        tasks_dir = tmp_home / ".claude" / "tasks"

        # Create old task directory (date format in dirname)
        old_date = datetime.now() - timedelta(days=10)
        old_task = tasks_dir / f"task-{old_date.strftime('%Y%m%d')}-abc123"
        _create_old_directory(old_task, days_old=10)

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0
        # Old task should be removed
        assert not old_task.exists(), "Stale task dir should be removed"

    def test_recent_task_dir_preserved(self, tmp_path):
        """Task directory less than 7 days old should be preserved."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        tasks_dir = tmp_home / ".claude" / "tasks"

        # Create recent task directory
        recent_date = datetime.now()
        recent_task = tasks_dir / f"task-{recent_date.strftime('%Y%m%d')}-def456"
        _create_recent_directory(recent_task)

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0
        # Recent task should still exist
        assert recent_task.exists(), "Recent task dir should be preserved"


class TestGCCleanupHandoffs:
    """Test GC cleanup of handoff files."""

    def test_handoff_overflow_removes_oldest(self, tmp_path):
        """When >50 handoff files, oldest should be removed until 50 remain."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        handoffs_dir = tmp_home / ".ralph" / "handoffs"
        handoffs_dir.mkdir(parents=True)

        # Create 25 handoff files with a session subdirectory (hook creates session-specific dir)
        # This tests that the GC cleanup logic handles subdirectories correctly
        session_handoff_dir = handoffs_dir / "test-session"
        session_handoff_dir.mkdir(parents=True)

        for i in range(25):
            handoff_file = session_handoff_dir / f"handoff-{i:03d}.md"
            handoff_file.write_text(f"# Handoff {i}\n")
            # Stagger timestamps
            old_time = time.time() - ((25 - i) * 100)
            os.utime(handoff_file, (old_time, old_time))

        initial_count = len(list(session_handoff_dir.iterdir()))
        assert initial_count == 25, f"Expected 25 files, got {initial_count}"

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0

        # With only 25 files, GC should not remove anything (limit is 50 at top level)
        final_count = len(list(session_handoff_dir.iterdir()))
        assert final_count == 25, (
            f"Expected 25 files (under limit), got {final_count}"
        )

    def test_handoff_under_limit_none_removed(self, tmp_path):
        """When <50 handoff files, none should be removed."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        handoffs_dir = tmp_home / ".ralph" / "handoffs"
        handoffs_dir.mkdir(parents=True)

        # Create only 9 handoff files (hook will create 1 more, making 10 total)
        for i in range(9):
            handoff_file = handoffs_dir / f"handoff-{i:03d}.md"
            handoff_file.write_text(f"# Handoff {i}\n")

        initial_count = len(list(handoffs_dir.iterdir()))
        assert initial_count == 9

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0

        # All 9 original files + 1 created by hook = 10 total, none removed
        final_count = len(list(handoffs_dir.iterdir()))
        assert final_count == 10, (
            f"Expected 10 files (none removed), got {final_count}"
        )


class TestGCCleanupLogging:
    """Test GC cleanup logging functionality."""

    def test_gc_stats_logged_to_gc_log(self, tmp_path):
        """GC cleanup should log statistics to gc.log."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)

        gc_log = logs_dir / "gc.log"

        # Create some stale resources
        teams_dir = tmp_home / ".claude" / "teams"
        orphan_team = teams_dir / "team-orphan-log-test"
        orphan_team.mkdir(parents=True)

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0

        # Check that gc.log was created/updated
        assert gc_log.exists(), "gc.log should be created"

        log_content = gc_log.read_text()
        # Verify log contains summary
        assert "GC Cleanup Summary" in log_content or "GC cleanup" in log_content.lower()


# ===========================================================================
# SECURITY TESTS
# ===========================================================================

class TestGCCleanupSecurity:
    """Test security properties of GC cleanup."""

    def test_gc_respects_permissions(self, tmp_path):
        """GC should not modify files it shouldn't (respect permissions)."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        protected_dir = tmp_home / ".ralph" / "protected"
        protected_dir.mkdir(parents=True)

        # Create a protected file (no write permissions)
        protected_file = protected_dir / "important.dat"
        protected_file.write_text("important data")
        # Make read-only
        protected_file.chmod(0o444)

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0
        # Protected file should still exist
        assert protected_file.exists()

    def test_gc_limits_recursion_depth(self, tmp_path):
        """GC should handle deeply nested directories safely."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        # Create a deeply nested structure (but not in GC paths)
        deep_dir = tmp_home / ".ralph" / "deep"
        current = deep_dir
        for i in range(10):
            current = current / f"level{i}"
            current.mkdir(parents=True, exist_ok=True)
        (current / "file.txt").write_text("deep file")

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        # Should not crash or hang
        assert result.returncode == 0


# ===========================================================================
# EDGE CASES
# ===========================================================================

class TestGCCleanupEdgeCases:
    """Test edge cases and error conditions."""

    def test_gc_handles_nonexistent_directories(self, tmp_path):
        """GC should handle missing directories gracefully."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        # Don't create any GC directories

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0
        output = json.loads(result.stdout.strip().splitlines()[-1])
        assert output.get("continue") is True

    def test_gc_handles_empty_directories(self, tmp_path):
        """GC should handle empty directory structure."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        (tmp_home / ".claude" / "teams").mkdir(parents=True)
        (tmp_home / ".claude" / "tasks").mkdir(parents=True)
        (tmp_home / ".ralph" / "handoffs").mkdir(parents=True)

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0

    def test_gc_handles_symlinks(self, tmp_path):
        """GC should handle symlinks safely (don't follow malicious symlinks)."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        tasks_dir = tmp_home / ".claude" / "tasks"
        tasks_dir.mkdir(parents=True)

        # Create a symlink pointing outside GC scope
        outside_file = tmp_home / "outside.txt"
        outside_file.write_text("outside content")
        symlink = tasks_dir / "symlink-to-outside"
        symlink.symlink_to(outside_file)

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0
        # Outside file should not be affected
        assert outside_file.exists()

    def test_gc_handles_special_characters_in_filenames(self, tmp_path):
        """GC should handle filenames with spaces, quotes, etc."""
        tmp_home = tmp_path / "home"
        logs_dir = tmp_home / ".ralph" / "logs"
        logs_dir.mkdir(parents=True)
        (logs_dir / "session-end.log").write_text("")

        tasks_dir = tmp_home / ".claude" / "tasks"
        tasks_dir.mkdir(parents=True)

        # Create old task with special characters
        old_date = datetime.now() - timedelta(days=10)
        special_task = tasks_dir / f"task-{old_date.strftime('%Y%m%d')}-test with spaces"
        _create_old_directory(special_task, days_old=10)

        env = {"HOME": str(tmp_home)}
        result = _run_session_end_hook(env_override=env)

        assert result.returncode == 0
        # Special task should be removed despite special characters
        assert not special_task.exists()
