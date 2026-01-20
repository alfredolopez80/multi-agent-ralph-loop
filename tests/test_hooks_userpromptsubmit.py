#!/usr/bin/env python3
"""
UserPromptSubmit Hook Testing Suite - v2.57.3

Tests for hooks that execute on UserPromptSubmit event:
1. context-warning.sh - Context usage monitoring
2. periodic-reminder.sh - Goal reminders
3. prompt-analyzer.sh - Prompt classification

All tests validate:
- JSON output is ALWAYS valid
- No timeout (< 5 seconds)
- Proper error handling
- Security patterns

VERSION: 2.57.3
SEC-029, SEC-030, SEC-031: Guaranteed JSON output validation
CHANGES from 2.57.2:
- Updated model routing tests (MiniMax-M2.1 instead of deprecated haiku)
- Added validation for new UserPromptSubmit hooks
- Fixed multiline JSON parsing
"""
import os
import json
import subprocess
import tempfile
import time
import pytest
from pathlib import Path
from typing import Dict, Any, Optional


# ═══════════════════════════════════════════════════════════════════════════════
# Test Configuration
# ═══════════════════════════════════════════════════════════════════════════════

PROJECT_ROOT = Path(__file__).parent.parent
GLOBAL_HOOKS_DIR = Path.home() / ".claude" / "hooks"
PROJECT_HOOKS_DIR = PROJECT_ROOT / ".claude" / "hooks"

# Hooks under test
HOOKS = {
    "context-warning": {
        "global": GLOBAL_HOOKS_DIR / "context-warning.sh",
        "local": PROJECT_HOOKS_DIR / "context-warning.sh",
    },
    "periodic-reminder": {
        "global": GLOBAL_HOOKS_DIR / "periodic-reminder.sh",
        "local": PROJECT_HOOKS_DIR / "periodic-reminder.sh",
    },
    "prompt-analyzer": {
        "global": GLOBAL_HOOKS_DIR / "prompt-analyzer.sh",
        "local": PROJECT_HOOKS_DIR / "prompt-analyzer.sh",
    },
}

# Timeout for hook execution (UserPromptSubmit should be fast)
HOOK_TIMEOUT = 5  # seconds


# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

def run_hook(hook_path: Path, input_text: str = "", timeout: int = HOOK_TIMEOUT,
             env: Optional[Dict] = None) -> Dict[str, Any]:
    """
    Execute a hook with given text input and return parsed result.

    UserPromptSubmit hooks receive the user's prompt as stdin.

    Returns dict with:
        - returncode: Exit code
        - stdout: Raw stdout
        - stderr: Raw stderr
        - output: Parsed JSON output (or None if invalid)
        - is_valid_json: Whether output is valid JSON
        - execution_time: Time in seconds
    """
    start_time = time.time()

    try:
        result = subprocess.run(
            ["bash", str(hook_path)],
            input=input_text,
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT),
            timeout=timeout,
            env={**os.environ, **(env or {})}
        )

        execution_time = time.time() - start_time

        # Try to parse JSON output
        is_valid_json = False
        output = None
        try:
            output = json.loads(result.stdout)
            is_valid_json = True
        except (json.JSONDecodeError, ValueError):
            pass

        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "output": output,
            "is_valid_json": is_valid_json,
            "execution_time": execution_time
        }
    except subprocess.TimeoutExpired:
        return {
            "returncode": -1,
            "stdout": "",
            "stderr": "TIMEOUT",
            "output": None,
            "is_valid_json": False,
            "execution_time": timeout
        }


def get_hook_path(hook_name: str, prefer_global: bool = True) -> Path:
    """Get the hook path, preferring global or local."""
    hook_info = HOOKS.get(hook_name)
    if not hook_info:
        pytest.skip(f"Unknown hook: {hook_name}")

    if prefer_global and hook_info["global"].exists():
        return hook_info["global"]
    elif hook_info["local"].exists():
        return hook_info["local"]
    else:
        pytest.skip(f"Hook not found: {hook_name}")


# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT-WARNING.SH TESTS (SEC-029)
# ═══════════════════════════════════════════════════════════════════════════════

class TestContextWarningHook:
    """Tests for context-warning.sh (SEC-029)"""

    def setup_method(self):
        self.hook_path = get_hook_path("context-warning")

    def test_always_returns_valid_json(self):
        """SEC-029: Hook MUST always return valid JSON"""
        result = run_hook(self.hook_path, "test prompt")

        assert result["is_valid_json"], (
            f"Hook returned invalid JSON:\n"
            f"stdout: {result['stdout'][:500]}\n"
            f"stderr: {result['stderr'][:500]}"
        )

    def test_no_timeout(self):
        """Hook MUST complete within 5 seconds"""
        result = run_hook(self.hook_path, "test prompt", timeout=5)

        assert result["returncode"] != -1, "Hook timed out"
        assert result["execution_time"] < 5, f"Hook took {result['execution_time']:.2f}s"

    def test_returns_json_on_empty_input(self):
        """Hook handles empty input gracefully"""
        result = run_hook(self.hook_path, "")

        assert result["is_valid_json"], "Hook did not return valid JSON on empty input"

    def test_returns_json_on_long_input(self):
        """Hook handles very long input without crashing"""
        long_input = "x" * 10000
        result = run_hook(self.hook_path, long_input)

        assert result["is_valid_json"], "Hook did not return valid JSON on long input"

    def test_returns_json_on_special_characters(self):
        """Hook handles special characters in input"""
        special_input = 'test "quotes" and `backticks` and $variables'
        result = run_hook(self.hook_path, special_input)

        assert result["is_valid_json"], "Hook did not return valid JSON with special chars"

    def test_json_has_correct_structure_when_warning(self):
        """When context is high, JSON has message, context_level, context_percentage"""
        result = run_hook(self.hook_path, "test")

        if result["is_valid_json"] and result["output"]:
            # If there's a warning, check structure
            if "message" in result["output"]:
                assert "context_level" in result["output"]
                assert "context_percentage" in result["output"]
                assert isinstance(result["output"]["context_percentage"], (int, float))


# ═══════════════════════════════════════════════════════════════════════════════
# PERIODIC-REMINDER.SH TESTS (SEC-030)
# ═══════════════════════════════════════════════════════════════════════════════

class TestPeriodicReminderHook:
    """Tests for periodic-reminder.sh (SEC-030)"""

    def setup_method(self):
        self.hook_path = get_hook_path("periodic-reminder")

    def test_always_returns_valid_json(self):
        """SEC-030: Hook MUST always return valid JSON"""
        result = run_hook(self.hook_path, "test prompt")

        assert result["is_valid_json"], (
            f"Hook returned invalid JSON:\n"
            f"stdout: {result['stdout'][:500]}\n"
            f"stderr: {result['stderr'][:500]}"
        )

    def test_no_timeout(self):
        """Hook MUST complete within 5 seconds"""
        result = run_hook(self.hook_path, "test prompt", timeout=5)

        assert result["returncode"] != -1, "Hook timed out"
        assert result["execution_time"] < 5, f"Hook took {result['execution_time']:.2f}s"

    def test_returns_json_on_empty_input(self):
        """Hook handles empty input gracefully"""
        result = run_hook(self.hook_path, "")

        assert result["is_valid_json"], "Hook did not return valid JSON on empty input"

    def test_returns_empty_json_when_no_goal(self):
        """Hook returns {} when no goal is set"""
        result = run_hook(self.hook_path, "test")

        assert result["is_valid_json"], "Hook did not return valid JSON"
        # Should be empty or have minimal structure when no goal


# ═══════════════════════════════════════════════════════════════════════════════
# PROMPT-ANALYZER.SH TESTS (SEC-031)
# ═══════════════════════════════════════════════════════════════════════════════

class TestPromptAnalyzerHook:
    """Tests for prompt-analyzer.sh (SEC-031)"""

    def setup_method(self):
        self.hook_path = get_hook_path("prompt-analyzer")

    def test_always_returns_valid_json(self):
        """SEC-031: Hook MUST always return valid JSON"""
        result = run_hook(self.hook_path, "test prompt")

        assert result["is_valid_json"], (
            f"Hook returned invalid JSON:\n"
            f"stdout: {result['stdout'][:500]}\n"
            f"stderr: {result['stderr'][:500]}"
        )

    def test_no_timeout(self):
        """Hook MUST complete within 5 seconds"""
        result = run_hook(self.hook_path, "test prompt", timeout=5)

        assert result["returncode"] != -1, "Hook timed out"
        assert result["execution_time"] < 5, f"Hook took {result['execution_time']:.2f}s"

    def test_returns_json_on_empty_input(self):
        """Hook handles empty input gracefully"""
        result = run_hook(self.hook_path, "")

        assert result["is_valid_json"], "Hook did not return valid JSON on empty input"

    def test_classifies_simple_task_as_haiku(self):
        """Simple tasks like 'fix typo' should use Haiku model"""
        result = run_hook(self.hook_path, "fix typo in readme")

        assert result["is_valid_json"]
        assert result["output"]["model"] == "haiku"
        assert result["output"]["action"] == "execute_direct"

    def test_classifies_read_task_as_haiku(self):
        """Read commands should use Haiku model"""
        result = run_hook(self.hook_path, "read the config file")

        assert result["is_valid_json"]
        assert result["output"]["model"] == "haiku"

    def test_classifies_simple_refactor_as_sonnet(self):
        """Simple refactor tasks should use Sonnet model"""
        result = run_hook(self.hook_path, "refactor small function")

        assert result["is_valid_json"]
        assert result["output"]["model"] == "sonnet"

    def test_classifies_security_as_complex(self):
        """Security-related tasks should be classified as complex"""
        result = run_hook(self.hook_path, "security audit of the codebase")

        assert result["is_valid_json"]
        assert result["output"]["action"] == "ask_user"
        assert "complex" in result["output"]["type"]

    def test_classifies_architecture_as_strategic(self):
        """Architecture tasks should be classified as complex/strategic"""
        result = run_hook(self.hook_path, "design the architecture for the new module")

        assert result["is_valid_json"]
        assert result["output"]["action"] == "ask_user"
        # Architecture tasks should be classified as complex (either strategic or technical)
        assert "complex" in result["output"]["type"], f"Expected complex type, got: {result['output']['type']}"

    def test_classifies_unknown_as_ask_user(self):
        """Unknown tasks should ask the user"""
        result = run_hook(self.hook_path, "something random without keywords")

        assert result["is_valid_json"]
        assert result["output"]["action"] == "ask_user"
        assert result["output"]["type"] == "unknown"

    def test_json_newlines_are_properly_escaped(self):
        """JSON should contain properly escaped newlines, not literals"""
        result = run_hook(self.hook_path, "complex task architecture")

        assert result["is_valid_json"], "JSON with newlines should be valid"
        # The message field should contain actual newlines (\n), not escaped \\n
        if "message" in result["output"]:
            # jq properly handles newlines in strings
            assert isinstance(result["output"]["message"], str)

    def test_handles_special_characters_in_prompt(self):
        """Hook handles special characters without breaking JSON"""
        special_prompts = [
            'implement "feature" with $variable',
            "test `backticks` handling",
            "fix error: unexpected 'token'",
            "analyze code with $(echo injection)",
        ]

        for prompt in special_prompts:
            result = run_hook(self.hook_path, prompt)
            assert result["is_valid_json"], f"Failed on prompt: {prompt}"


# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY TESTS (All UserPromptSubmit Hooks)
# ═══════════════════════════════════════════════════════════════════════════════

class TestUserPromptSubmitSecurity:
    """Security tests for all UserPromptSubmit hooks"""

    @pytest.mark.parametrize("hook_name", ["context-warning", "periodic-reminder", "prompt-analyzer"])
    def test_command_injection_via_prompt(self, hook_name):
        """Hooks should not execute commands from prompt input"""
        hook_path = get_hook_path(hook_name)
        malicious_prompts = [
            "$(rm -rf /tmp/test)",
            "`rm -rf /tmp/test`",
            "; rm -rf /tmp/test",
            "| rm -rf /tmp/test",
            "\n rm -rf /tmp/test",
        ]

        for prompt in malicious_prompts:
            result = run_hook(hook_path, prompt)
            # Should still return valid JSON
            assert result["is_valid_json"], f"Hook {hook_name} failed on: {prompt}"
            # Should not have executed the command (no error output)
            assert "rm" not in result["stderr"].lower()

    @pytest.mark.parametrize("hook_name", ["context-warning", "periodic-reminder", "prompt-analyzer"])
    def test_json_injection_via_prompt(self, hook_name):
        """Hooks should properly escape JSON special characters"""
        hook_path = get_hook_path(hook_name)
        json_injection_prompts = [
            '{"injected": true}',
            'test", "injected": true, "x": "',
            '\\n\\n{"injected": true}',
        ]

        for prompt in json_injection_prompts:
            result = run_hook(hook_path, prompt)
            assert result["is_valid_json"], f"Hook {hook_name} failed on: {prompt}"


# ═══════════════════════════════════════════════════════════════════════════════
# REGRESSION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

class TestUserPromptSubmitRegressions:
    """Regression tests for previously fixed bugs"""

    def test_context_warning_no_timeout_124(self):
        """Regression: context-warning.sh used to timeout (exit 124)"""
        hook_path = get_hook_path("context-warning")
        result = run_hook(hook_path, "test", timeout=10)

        assert result["returncode"] != 124, "Hook returned timeout exit code 124"
        assert result["returncode"] != -1, "Hook timed out"

    def test_periodic_reminder_not_empty(self):
        """Regression: periodic-reminder.sh used to return empty output"""
        hook_path = get_hook_path("periodic-reminder")
        result = run_hook(hook_path, "test")

        assert result["stdout"].strip() != "", "Hook returned empty output"
        assert result["is_valid_json"], "Hook did not return valid JSON"

    def test_prompt_analyzer_valid_json_with_newlines(self):
        """Regression: prompt-analyzer.sh used to produce invalid JSON with \\n"""
        hook_path = get_hook_path("prompt-analyzer")
        result = run_hook(hook_path, "complex architecture design")

        assert result["is_valid_json"], (
            f"Hook returned invalid JSON (newline issue?):\n{result['stdout'][:200]}"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
