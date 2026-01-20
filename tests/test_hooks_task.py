#!/usr/bin/env python3
"""
Task Hook Testing Suite - v2.57.3

Tests for hooks that execute on PreToolUse(Task) and PostToolUse(Task) events:

PreToolUse:Task:
1. orchestrator-auto-learn.sh - Knowledge gap detection
2. fast-path-check.sh - Trivial task fast-path
3. inject-session-context.sh - Context injection
4. smart-memory-search.sh - Parallel memory search
5. procedural-inject.sh - Learned behaviors injection
6. agent-memory-auto-init.sh - Agent memory initialization

PostToolUse:Task:
1. parallel-explore.sh - Parallel exploration
2. recursive-decompose.sh - Task decomposition
3. todo-plan-sync.sh - Todo synchronization

All tests validate:
- JSON output is ALWAYS valid
- Correct format per OFFICIAL Claude Code documentation:
  * PostToolUse/PreToolUse: {"continue": true, ...}
  * Stop hooks ONLY: {"decision": "approve|block", ...}
- No timeout (< configured seconds)
- Proper error handling
- Security patterns

VERSION: 2.57.3
SEC-038: CORRECTED - PostToolUse/PreToolUse hooks use {"continue": true}
         The string "decision": "continue" is NEVER valid per official docs.
"""
import os
import json
import subprocess
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

# PreToolUse:Task hooks
PRE_TOOLUSE_TASK_HOOKS = [
    "orchestrator-auto-learn.sh",
    "fast-path-check.sh",
    "inject-session-context.sh",
    "smart-memory-search.sh",
    "procedural-inject.sh",
    "agent-memory-auto-init.sh",
]

# PostToolUse:Task hooks
POST_TOOLUSE_TASK_HOOKS = [
    "parallel-explore.sh",
    "recursive-decompose.sh",
    "todo-plan-sync.sh",
]

# Default timeout
HOOK_TIMEOUT = 15  # seconds


# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

def run_hook(hook_name: str, input_json: Dict[str, Any], timeout: int = HOOK_TIMEOUT,
             prefer_global: bool = True) -> Dict[str, Any]:
    """
    Execute a hook with given JSON input and return parsed result.

    Returns dict with:
        - returncode: Exit code
        - stdout: Raw stdout
        - stderr: Raw stderr
        - output: Parsed JSON output (or None if invalid)
        - is_valid_json: Whether output is valid JSON
        - execution_time: Time in seconds
        - has_correct_format: Whether uses {"decision": "..."} format
    """
    # Find hook path
    global_path = GLOBAL_HOOKS_DIR / hook_name
    local_path = PROJECT_HOOKS_DIR / hook_name

    if prefer_global and global_path.exists():
        hook_path = global_path
    elif local_path.exists():
        hook_path = local_path
    else:
        return {
            "returncode": -2,
            "stdout": "",
            "stderr": f"Hook not found: {hook_name}",
            "output": None,
            "is_valid_json": False,
            "execution_time": 0,
            "has_correct_format": False
        }

    start_time = time.time()
    input_str = json.dumps(input_json)

    try:
        result = subprocess.run(
            ["bash", str(hook_path)],
            input=input_str,
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT),
            timeout=timeout,
            env={**os.environ}
        )

        execution_time = time.time() - start_time

        # Parse JSON output
        is_valid_json = False
        output = None
        has_correct_format = False

        try:
            output = json.loads(result.stdout)
            is_valid_json = True
            # SEC-038: Correct format is {"continue": true} for PostToolUse/PreToolUse
            # Empty {} is also acceptable, or "continue" must be boolean
            has_correct_format = (
                output == {} or
                ("continue" in output and isinstance(output.get("continue"), bool))
            )
        except (json.JSONDecodeError, ValueError):
            pass

        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "output": output,
            "is_valid_json": is_valid_json,
            "execution_time": execution_time,
            "has_correct_format": has_correct_format
        }
    except subprocess.TimeoutExpired:
        return {
            "returncode": -1,
            "stdout": "",
            "stderr": "TIMEOUT",
            "output": None,
            "is_valid_json": False,
            "execution_time": timeout,
            "has_correct_format": False
        }


def make_pretooluse_input(prompt: str = "test task", description: str = "test",
                          subagent_type: str = "general-purpose") -> Dict[str, Any]:
    """Create a standard PreToolUse:Task input JSON."""
    return {
        "tool_name": "Task",
        "tool_input": {
            "prompt": prompt,
            "description": description,
            "subagent_type": subagent_type
        }
    }


def make_posttooluse_input(prompt: str = "test task", result: str = "completed") -> Dict[str, Any]:
    """Create a standard PostToolUse:Task input JSON."""
    return {
        "tool_name": "Task",
        "tool_input": {
            "prompt": prompt,
            "description": "test"
        },
        "tool_result": result
    }


# ═══════════════════════════════════════════════════════════════════════════════
# PRETOOLUSE:TASK HOOKS TESTS
# ═══════════════════════════════════════════════════════════════════════════════

class TestPreToolUseTaskHooks:
    """Tests for all PreToolUse:Task hooks"""

    @pytest.mark.parametrize("hook_name", PRE_TOOLUSE_TASK_HOOKS)
    def test_returns_valid_json(self, hook_name):
        """All PreToolUse:Task hooks MUST return valid JSON"""
        input_json = make_pretooluse_input()
        result = run_hook(hook_name, input_json)

        if result["returncode"] == -2:
            pytest.skip(f"Hook not found: {hook_name}")

        assert result["is_valid_json"], (
            f"Hook {hook_name} returned invalid JSON:\n"
            f"stdout: {result['stdout'][:500]}\n"
            f"stderr: {result['stderr'][:500]}"
        )

    @pytest.mark.parametrize("hook_name", PRE_TOOLUSE_TASK_HOOKS)
    def test_has_correct_format(self, hook_name):
        """PreToolUse hooks must use {"continue": true} format (per official docs)"""
        input_json = make_pretooluse_input()
        result = run_hook(hook_name, input_json)

        if result["returncode"] == -2:
            pytest.skip(f"Hook not found: {hook_name}")

        if not result["is_valid_json"]:
            pytest.fail(f"Hook {hook_name} did not return valid JSON")

        # Empty {} is acceptable
        if result["output"] == {}:
            return

        # SEC-038: PreToolUse hooks use {"continue": true}, NOT {"decision": "continue"}
        # The string "continue" is NEVER valid for the decision field per official docs
        assert "decision" not in result["output"] or result["output"].get("decision") not in ("continue",), (
            f"Hook {hook_name} uses WRONG format 'decision: continue'.\n"
            f"PreToolUse hooks must use {{'continue': true}}.\n"
            f"Got: {result['output']}"
        )

    @pytest.mark.parametrize("hook_name", PRE_TOOLUSE_TASK_HOOKS)
    def test_no_timeout(self, hook_name):
        """Hooks MUST complete within timeout"""
        input_json = make_pretooluse_input()
        result = run_hook(hook_name, input_json, timeout=15)

        if result["returncode"] == -2:
            pytest.skip(f"Hook not found: {hook_name}")

        assert result["returncode"] != -1, f"Hook {hook_name} timed out"
        assert result["execution_time"] < 15, (
            f"Hook {hook_name} took {result['execution_time']:.2f}s"
        )

    @pytest.mark.parametrize("hook_name", PRE_TOOLUSE_TASK_HOOKS)
    def test_handles_empty_input(self, hook_name):
        """Hooks handle empty/minimal input gracefully"""
        input_json = {"tool_name": "Task", "tool_input": {}}
        result = run_hook(hook_name, input_json)

        if result["returncode"] == -2:
            pytest.skip(f"Hook not found: {hook_name}")

        assert result["is_valid_json"], (
            f"Hook {hook_name} failed on empty input:\n"
            f"stdout: {result['stdout'][:500]}"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# POSTTOOLUSE:TASK HOOKS TESTS
# ═══════════════════════════════════════════════════════════════════════════════

class TestPostToolUseTaskHooks:
    """Tests for all PostToolUse:Task hooks"""

    @pytest.mark.parametrize("hook_name", POST_TOOLUSE_TASK_HOOKS)
    def test_returns_valid_json(self, hook_name):
        """All PostToolUse:Task hooks MUST return valid JSON"""
        input_json = make_posttooluse_input()
        result = run_hook(hook_name, input_json)

        if result["returncode"] == -2:
            pytest.skip(f"Hook not found: {hook_name}")

        assert result["is_valid_json"], (
            f"Hook {hook_name} returned invalid JSON:\n"
            f"stdout: {result['stdout'][:500]}\n"
            f"stderr: {result['stderr'][:500]}"
        )

    @pytest.mark.parametrize("hook_name", POST_TOOLUSE_TASK_HOOKS)
    def test_has_correct_format_continue_true(self, hook_name):
        """SEC-038: PostToolUse hooks MUST use {"continue": true} (per official docs)"""
        input_json = make_posttooluse_input()
        result = run_hook(hook_name, input_json)

        if result["returncode"] == -2:
            pytest.skip(f"Hook not found: {hook_name}")

        if not result["is_valid_json"]:
            pytest.fail(f"Hook {hook_name} did not return valid JSON")

        # Empty {} is acceptable
        if result["output"] == {}:
            return

        # SEC-038: PostToolUse hooks use {"continue": true}, NOT {"decision": "continue"}
        # The string "decision": "continue" is NEVER valid per official Claude Code docs
        assert "decision" not in result["output"] or result["output"].get("decision") not in ("continue",), (
            f"SEC-038: Hook {hook_name} uses WRONG format 'decision: continue'.\n"
            f"PostToolUse hooks must use {{'continue': true}}.\n"
            f"Got: {result['output']}"
        )

    @pytest.mark.parametrize("hook_name", POST_TOOLUSE_TASK_HOOKS)
    def test_has_continue_key(self, hook_name):
        """PostToolUse hooks must have 'continue' boolean key (per official docs)"""
        input_json = make_posttooluse_input()
        result = run_hook(hook_name, input_json)

        if result["returncode"] == -2:
            pytest.skip(f"Hook not found: {hook_name}")

        if not result["is_valid_json"]:
            pytest.fail(f"Hook {hook_name} did not return valid JSON")

        # Empty {} is acceptable
        if result["output"] == {}:
            return

        # SEC-038: PostToolUse hooks use {"continue": true} per official docs
        assert "continue" in result["output"], (
            f"Hook {hook_name} missing 'continue' key.\n"
            f"PostToolUse hooks must use {{'continue': true}}.\n"
            f"Got: {result['output']}"
        )
        assert isinstance(result["output"]["continue"], bool), (
            f"Hook {hook_name}: 'continue' must be boolean, not string.\n"
            f"Got: {result['output']}"
        )

    @pytest.mark.parametrize("hook_name", POST_TOOLUSE_TASK_HOOKS)
    def test_no_timeout(self, hook_name):
        """Hooks MUST complete within timeout"""
        input_json = make_posttooluse_input()
        result = run_hook(hook_name, input_json, timeout=20)

        if result["returncode"] == -2:
            pytest.skip(f"Hook not found: {hook_name}")

        assert result["returncode"] != -1, f"Hook {hook_name} timed out"
        assert result["execution_time"] < 20, (
            f"Hook {hook_name} took {result['execution_time']:.2f}s"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# SPECIFIC HOOK TESTS
# ═══════════════════════════════════════════════════════════════════════════════

class TestProceduralInjectHook:
    """Tests for procedural-inject.sh (SEC-032)"""

    def test_json_newlines_properly_escaped(self):
        """SEC-032: JSON should have properly escaped newlines"""
        input_json = make_pretooluse_input(prompt="implement feature with patterns")
        result = run_hook("procedural-inject.sh", input_json)

        if result["returncode"] == -2:
            pytest.skip("Hook not found")

        assert result["is_valid_json"], (
            f"Invalid JSON (newline issue?):\n{result['stdout'][:300]}"
        )

    def test_additionalcontext_is_string(self):
        """additionalContext should be a string, not object"""
        input_json = make_pretooluse_input(prompt="implement patterns learned")
        result = run_hook("procedural-inject.sh", input_json)

        if result["returncode"] == -2:
            pytest.skip("Hook not found")

        if result["is_valid_json"] and result["output"]:
            if "additionalContext" in result["output"]:
                assert isinstance(result["output"]["additionalContext"], str), (
                    "additionalContext must be a string"
                )


class TestTodoPlanSyncHook:
    """Tests for todo-plan-sync.sh (SEC-038)"""

    def test_uses_continue_not_decision(self):
        """SEC-038: Must use 'continue: true' not 'decision: continue' (per official docs)"""
        input_json = {
            "tool_name": "TodoWrite",
            "tool_input": {"todos": []},
            "tool_result": "success"
        }
        result = run_hook("todo-plan-sync.sh", input_json)

        if result["returncode"] == -2:
            pytest.skip("Hook not found")

        assert result["is_valid_json"], "Invalid JSON output"

        # Empty {} is acceptable
        if result["output"] == {}:
            return

        # SEC-038: PostToolUse hooks use {"continue": true} per official docs
        assert "continue" in result["output"], (
            f"Expected 'continue' key, got: {result['output']}"
        )
        assert result["output"]["continue"] is True, (
            f"'continue' must be boolean true, got: {result['output']['continue']}"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY TESTS
# ═══════════════════════════════════════════════════════════════════════════════

class TestTaskHooksSecurity:
    """Security tests for Task hooks"""

    @pytest.mark.parametrize("hook_name", PRE_TOOLUSE_TASK_HOOKS + POST_TOOLUSE_TASK_HOOKS)
    def test_command_injection_via_prompt(self, hook_name):
        """Hooks should not execute commands from prompt input"""
        malicious_prompts = [
            "$(rm -rf /tmp/test)",
            "`rm -rf /tmp/test`",
            "; rm -rf /tmp/test",
            "| rm -rf /tmp/test",
        ]

        for prompt in malicious_prompts:
            if hook_name in POST_TOOLUSE_TASK_HOOKS:
                input_json = make_posttooluse_input(prompt=prompt)
            else:
                input_json = make_pretooluse_input(prompt=prompt)

            result = run_hook(hook_name, input_json)

            if result["returncode"] == -2:
                pytest.skip(f"Hook not found: {hook_name}")

            # Should still return valid JSON
            assert result["is_valid_json"], (
                f"Hook {hook_name} failed on malicious input: {prompt}"
            )


# ═══════════════════════════════════════════════════════════════════════════════
# REGRESSION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

class TestTaskHooksRegressions:
    """Regression tests for previously fixed bugs"""

    def test_procedural_inject_no_literal_newlines(self):
        """Regression: procedural-inject.sh had literal newlines in JSON"""
        input_json = make_pretooluse_input(prompt="implement with learned patterns")
        result = run_hook("procedural-inject.sh", input_json)

        if result["returncode"] == -2:
            pytest.skip("Hook not found")

        # The raw stdout should be valid JSON
        assert result["is_valid_json"], (
            f"JSON parsing failed (literal newlines?):\n{result['stdout'][:200]}"
        )

    def test_todo_plan_sync_correct_format(self):
        """SEC-038: todo-plan-sync.sh must use {"continue": true} (per official docs)"""
        input_json = {
            "tool_name": "TodoWrite",
            "tool_input": {"todos": []},
            "tool_result": "success"
        }
        result = run_hook("todo-plan-sync.sh", input_json)

        if result["returncode"] == -2:
            pytest.skip("Hook not found")

        assert result["is_valid_json"], "Invalid JSON"

        # Empty {} is acceptable
        if result["output"] == {}:
            return

        # SEC-038: PostToolUse hooks use {"continue": true} per official docs
        # The string "decision": "continue" is NEVER valid
        assert "decision" not in result["output"] or result["output"].get("decision") not in ("continue",), (
            f"Wrong format - 'decision: continue' is NEVER valid.\n"
            f"PostToolUse hooks must use {{'continue': true}}.\n"
            f"Got: {result['output']}"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
