#!/usr/bin/env python3
"""
Unit tests for git-safety-guard.py

Tests security patterns, command normalization, and fail-closed behavior.

Run with: pytest tests/test_git_safety_guard.py -v
"""

import json
import os
import sys
import pytest
from io import StringIO
from unittest.mock import patch

# Add the hooks directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".claude", "hooks"))

# Import the module under test
import importlib.util

spec = importlib.util.spec_from_file_location(
    "git_safety_guard",
    os.path.join(
        os.path.dirname(__file__), "..", ".claude", "hooks", "git-safety-guard.py"
    ),
)
git_safety_guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(git_safety_guard)


class TestNormalizeCommand:
    """Tests for normalize_command() function."""

    def test_normalizes_multiple_spaces(self):
        """Multiple spaces should be collapsed to single space."""
        result = git_safety_guard.normalize_command("git   checkout   --   file.txt")
        assert "  " not in result

    def test_strips_leading_trailing_whitespace(self):
        """Leading and trailing whitespace should be removed."""
        result = git_safety_guard.normalize_command("  git status  ")
        assert result == "git status"

    def test_removes_quotes_around_paths(self):
        """Quotes around paths should be removed for pattern matching."""
        result = git_safety_guard.normalize_command('rm -rf "/tmp/test"')
        assert result == "rm -rf /tmp/test"

    def test_expands_environment_variables(self):
        """Environment variables should be expanded."""
        os.environ["TEST_VAR"] = "/test/path"
        result = git_safety_guard.normalize_command("rm -rf $TEST_VAR/file")
        assert "/test/path" in result
        del os.environ["TEST_VAR"]

    def test_handles_empty_string(self):
        """Empty string should return empty string."""
        result = git_safety_guard.normalize_command("")
        assert result == ""

    def test_handles_tabs_and_newlines(self):
        """Tabs and newlines should be normalized to spaces."""
        result = git_safety_guard.normalize_command("git\tcheckout\n-b")
        assert "\t" not in result
        assert "\n" not in result


class TestSafePatterns:
    """Tests for safe command patterns that should ALWAYS be allowed."""

    @pytest.mark.parametrize(
        "command",
        [
            "git checkout -b new-branch",
            "git checkout --orphan orphan-branch",
            "git switch -c new-feature",
            "git switch --create feature-branch",
            "git restore --staged file.txt",
            "git clean -n",
            "git clean --dry-run",
            "git status",
            "git log --oneline",
            "git diff HEAD~1",
            "git show abc123",
            "git branch -a",
            "git remote -v",
            "git fetch origin",
            "git add .",
            "git commit -m 'test'",
            "git pull origin main",
            "git stash push",
            "git stash save 'work in progress'",
            "rm -rf /tmp/test-dir",
            "rm -rf /var/tmp/cache",
            "rm -rf /private/tmp/session",
        ],
    )
    def test_safe_commands_allowed(self, command):
        """Safe commands should return True from is_safe_pattern."""
        normalized = git_safety_guard.normalize_command(command)
        assert git_safety_guard.is_safe_pattern(normalized) is True


class TestBlockedPatterns:
    """Tests for blocked command patterns that should NEVER be allowed."""

    @pytest.mark.parametrize(
        "command,expected_reason",
        [
            ("git checkout -- file.txt", "discards uncommitted changes"),
            ("git restore file.txt", "overwrites working tree"),
            ("git reset --hard", "destroys all uncommitted changes"),
            ("git reset --hard HEAD~1", "destroys all uncommitted changes"),
            ("git reset --merge", "can lose uncommitted changes"),
            ("git clean -f", "removes untracked files"),
            ("git clean -fd", "removes untracked files"),
            ("git branch -D old-branch", "force-deletes branch"),
            ("git stash drop", "permanently deletes stashed changes"),
            ("git stash drop stash@{0}", "permanently deletes stashed changes"),
            ("git stash clear", "permanently deletes ALL stashed changes"),
            ("rm -rf /home/user/important", "recursive deletion"),
            ("rm -rf ./src", "recursive deletion"),
            ("git rebase main", "rebasing shared branches"),
            ("git rebase origin/master", "rebasing shared branches"),
        ],
    )
    def test_blocked_commands_detected(self, command, expected_reason):
        """Blocked commands should be detected with appropriate reason."""
        normalized = git_safety_guard.normalize_command(command)
        blocked, reason = git_safety_guard.check_blocked_pattern(normalized)
        assert blocked is True, f"Command '{command}' should be blocked"
        assert expected_reason.lower() in reason.lower()


class TestConfirmationPatterns:
    """Tests for commands that require user confirmation."""

    @pytest.mark.parametrize(
        "command",
        [
            "git push --force origin main",
            "git push -f origin feature",
            "git push origin +main",
            "git push origin +feature:feature",
        ],
    )
    def test_force_push_requires_confirmation(self, command):
        """Force push commands should require confirmation."""
        normalized = git_safety_guard.normalize_command(command)
        needs_confirm, reason = git_safety_guard.check_confirmation_pattern(normalized)
        assert needs_confirm is True
        assert "force push" in reason.lower() or "remote history" in reason.lower()

    def test_normal_push_no_confirmation(self):
        """Normal push should NOT require confirmation."""
        command = "git push origin main"
        normalized = git_safety_guard.normalize_command(command)
        needs_confirm, _ = git_safety_guard.check_confirmation_pattern(normalized)
        assert needs_confirm is False


class TestMainFunction:
    """Integration tests for the main() function."""

    def create_hook_input(self, command: str) -> str:
        """Create JSON input as would be provided by Claude Code hook system."""
        return json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})

    def test_allows_safe_command(self):
        """Safe commands should exit with code 0."""
        input_data = self.create_hook_input("git status")
        with patch("sys.stdin", StringIO(input_data)):
            with pytest.raises(SystemExit) as exc_info:
                git_safety_guard.main()
            assert exc_info.value.code == 0

    def test_blocks_destructive_command(self, capsys):
        """Destructive commands should exit with code 1 and output JSON."""
        input_data = self.create_hook_input("git reset --hard")
        with patch("sys.stdin", StringIO(input_data)):
            with pytest.raises(SystemExit) as exc_info:
                git_safety_guard.main()
            assert exc_info.value.code == 1

            captured = capsys.readouterr()
            response = json.loads(captured.out)
            # v2.69.0+: Uses hookSpecificOutput format
            hook_output = response.get("hookSpecificOutput", response)
            decision = hook_output.get("permissionDecision", hook_output.get("decision"))
            reason = hook_output.get("permissionDecisionReason", hook_output.get("reason", ""))
            assert decision == "block"
            assert "BLOCKED" in reason or "blocked" in reason.lower()

    def test_non_bash_tool_allowed(self):
        """Non-Bash tools should be allowed through."""
        input_data = json.dumps(
            {"tool_name": "Read", "tool_input": {"file_path": "/etc/passwd"}}
        )
        with patch("sys.stdin", StringIO(input_data)):
            with pytest.raises(SystemExit) as exc_info:
                git_safety_guard.main()
            assert exc_info.value.code == 0

    def test_empty_input_allowed(self):
        """Empty input should be allowed (exit 0)."""
        with patch("sys.stdin", StringIO("")):
            with pytest.raises(SystemExit) as exc_info:
                git_safety_guard.main()
            assert exc_info.value.code == 0

    def test_invalid_json_blocks(self, capsys):
        """Invalid JSON should fail-closed (block)."""
        with patch("sys.stdin", StringIO("not valid json {")):
            with pytest.raises(SystemExit) as exc_info:
                git_safety_guard.main()
            assert exc_info.value.code == 1

            captured = capsys.readouterr()
            response = json.loads(captured.out)
            # v2.69.0+: Uses hookSpecificOutput format
            hook_output = response.get("hookSpecificOutput", response)
            decision = hook_output.get("permissionDecision", hook_output.get("decision"))
            assert decision == "block"

    def test_confirmed_force_push_allowed(self):
        """Force push with confirmation env var should be allowed."""
        input_data = self.create_hook_input("git push --force origin main")
        os.environ["GIT_FORCE_PUSH_CONFIRMED"] = "1"
        try:
            with patch("sys.stdin", StringIO(input_data)):
                with pytest.raises(SystemExit) as exc_info:
                    git_safety_guard.main()
                assert exc_info.value.code == 0
        finally:
            del os.environ["GIT_FORCE_PUSH_CONFIRMED"]


class TestBypassPrevention:
    """Tests to ensure regex bypass attempts are blocked."""

    @pytest.mark.parametrize(
        "bypass_attempt",
        [
            "git   reset   --hard",  # Extra spaces
            "git\treset\t--hard",  # Tabs instead of spaces
            'git reset "--hard"',  # Quoted flag
            "git reset  --hard  ",  # Trailing spaces
        ],
    )
    def test_whitespace_bypass_blocked(self, bypass_attempt):
        """Whitespace variations should not bypass blocking."""
        normalized = git_safety_guard.normalize_command(bypass_attempt)
        blocked, _ = git_safety_guard.check_blocked_pattern(normalized)
        assert blocked is True, f"Bypass attempt should be blocked: {bypass_attempt}"

    @pytest.mark.parametrize(
        "bypass_attempt",
        [
            'rm -rf "/etc"',  # Quoted path
            "rm -rf '/etc'",  # Single-quoted path
            'rm -rf "/home/user"',  # Various paths
        ],
    )
    def test_quoted_path_bypass_blocked(self, bypass_attempt):
        """Quoted paths should not bypass blocking."""
        normalized = git_safety_guard.normalize_command(bypass_attempt)
        blocked, _ = git_safety_guard.check_blocked_pattern(normalized)
        assert blocked is True, f"Bypass attempt should be blocked: {bypass_attempt}"


class TestCoverageGaps:
    """Tests to achieve 95%+ coverage on missing lines."""

    def create_hook_input(self, command: str) -> str:
        """Create JSON input as would be provided by Claude Code hook system."""
        return json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})

    def test_check_blocked_pattern_returns_false_for_safe_commands(self):
        """Line 197: check_blocked_pattern returns (False, '') for non-blocked commands."""
        # A command that doesn't match any blocked pattern
        command = "ls -la /home/user"
        blocked, reason = git_safety_guard.check_blocked_pattern(command)
        assert blocked is False
        assert reason == ""

    def test_confirmation_pattern_blocks_force_push(self, capsys):
        """Lines 239-248: Confirmation pattern should output JSON and exit 1."""
        input_data = self.create_hook_input("git push --force origin feature")
        # Ensure the env var is NOT set
        if "GIT_FORCE_PUSH_CONFIRMED" in os.environ:
            del os.environ["GIT_FORCE_PUSH_CONFIRMED"]

        with patch("sys.stdin", StringIO(input_data)):
            with pytest.raises(SystemExit) as exc_info:
                git_safety_guard.main()
            assert exc_info.value.code == 1

            captured = capsys.readouterr()
            response = json.loads(captured.out)
            # v2.69.0+: Uses hookSpecificOutput format
            hook_output = response.get("hookSpecificOutput", response)
            decision = hook_output.get("permissionDecision", hook_output.get("decision"))
            reason = hook_output.get("permissionDecisionReason", hook_output.get("reason", ""))
            assert decision == "block"
            assert "BLOCKED" in reason or "force push" in reason.lower() or "CONFIRMATION" in reason

    def test_command_passes_all_checks_exits_zero(self):
        """Line 265: Commands that pass all checks should exit 0."""
        # A command that:
        # 1. Is NOT in safe patterns (so it goes through all checks)
        # 2. Is NOT in blocked patterns
        # 3. Does NOT require confirmation
        input_data = self.create_hook_input("echo hello world")
        with patch("sys.stdin", StringIO(input_data)):
            with pytest.raises(SystemExit) as exc_info:
                git_safety_guard.main()
            assert exc_info.value.code == 0

    def test_unexpected_exception_blocks_command(self, capsys):
        """Lines 278-284: Unexpected exceptions should fail-closed."""
        input_data = self.create_hook_input("git status")

        # Mock normalize_command to raise an unexpected exception
        with patch.object(
            git_safety_guard,
            "normalize_command",
            side_effect=RuntimeError("Unexpected error"),
        ):
            with patch("sys.stdin", StringIO(input_data)):
                with pytest.raises(SystemExit) as exc_info:
                    git_safety_guard.main()
                assert exc_info.value.code == 1

                captured = capsys.readouterr()
                response = json.loads(captured.out)
                # v2.69.0+: Uses hookSpecificOutput format
                hook_output = response.get("hookSpecificOutput", response)
                decision = hook_output.get("permissionDecision", hook_output.get("decision"))
                reason = hook_output.get("permissionDecisionReason", hook_output.get("reason", ""))
                assert decision == "block"
                assert "Internal error" in reason or "internal error" in reason.lower() or "error" in reason.lower()

    def test_non_blocked_non_safe_command_allowed(self):
        """Test that regular commands pass through when not blocked."""
        # Commands like 'echo', 'pwd', etc. that aren't in safe or blocked patterns
        command = "pwd"
        normalized = git_safety_guard.normalize_command(command)
        blocked, reason = git_safety_guard.check_blocked_pattern(normalized)
        assert blocked is False
        assert reason == ""

    def test_multiple_non_blocked_commands(self):
        """Test multiple commands that should NOT be blocked."""
        non_blocked_commands = [
            "ls -la",
            "cat file.txt",
            "mkdir new_dir",
            "cp file1 file2",
            "mv old new",
            "touch newfile",
            "head -n 10 file",
            "tail -f log.txt",
            "grep pattern file",
        ]
        for cmd in non_blocked_commands:
            normalized = git_safety_guard.normalize_command(cmd)
            blocked, reason = git_safety_guard.check_blocked_pattern(normalized)
            assert blocked is False, f"Command '{cmd}' should NOT be blocked"
            assert reason == ""


class TestEdgeCases:
    """Tests for edge cases and boundary conditions."""

    def test_case_insensitive_matching(self):
        """Commands should match case-insensitively."""
        command = "GIT RESET --HARD"
        normalized = git_safety_guard.normalize_command(command)
        blocked, _ = git_safety_guard.check_blocked_pattern(normalized)
        assert blocked is True

    def test_long_command_handled(self):
        """Very long commands should be handled without error."""
        long_path = "/tmp/" + "a" * 1000
        command = f"rm -rf {long_path}"
        normalized = git_safety_guard.normalize_command(command)
        # Should not raise any exceptions
        git_safety_guard.is_safe_pattern(normalized)

    def test_unicode_in_command(self):
        """Unicode characters in commands should be handled."""
        command = "git commit -m 'Fixed bug in archivo.txt'"
        normalized = git_safety_guard.normalize_command(command)
        assert git_safety_guard.is_safe_pattern(normalized)

    def test_empty_command_in_input(self):
        """Empty command field should be allowed."""
        input_data = json.dumps({"tool_name": "Bash", "tool_input": {"command": ""}})
        with patch("sys.stdin", StringIO(input_data)):
            with pytest.raises(SystemExit) as exc_info:
                git_safety_guard.main()
            assert exc_info.value.code == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
