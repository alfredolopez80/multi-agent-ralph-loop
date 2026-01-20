#!/usr/bin/env python3
"""
test_hook_json_format_regression.py - CRITICAL Regression Tests for Hook JSON Formats
VERSION: 2.57.3

This test file exists because of a critical incident where incorrect JSON format
expectations in tests caused hooks to be "fixed" with WRONG formats, leading to
a cascade of back-and-forth corrections.

CRITICAL FORMAT RULES (per OFFICIAL Claude Code documentation):
- PostToolUse/PreToolUse/UserPromptSubmit/PreCompact: {"continue": true/false}
- Stop hooks ONLY: {"decision": "approve"/"block"}
- The string "continue" is NEVER valid for the "decision" field!

Reference: tests/HOOK_FORMAT_REFERENCE.md
Source: Claude Code official documentation via Context7 MCP
"""

import json
import subprocess
import os
from pathlib import Path
from typing import Tuple, Dict, Any, Optional
import pytest


# Configuration
HOOKS_DIR = Path(os.path.expanduser("~/.claude/hooks"))
PROJECT_HOOKS_DIR = Path(".claude/hooks")


def run_hook(hook_path: Path, input_json: str = "{}") -> Tuple[int, str, str]:
    """Execute a hook and return (exit_code, stdout, stderr)."""
    if not hook_path.exists():
        return -2, "", f"Hook not found: {hook_path}"

    result = subprocess.run(
        [str(hook_path)],
        input=input_json,
        capture_output=True,
        text=True,
        timeout=10,
        env={**os.environ, "HOME": os.path.expanduser("~")}
    )
    return result.returncode, result.stdout, result.stderr


def extract_json_from_output(stdout: str) -> Optional[Dict[str, Any]]:
    """Extract JSON from hook output (last line that looks like JSON)."""
    for line in reversed(stdout.strip().split('\n')):
        line = line.strip()
        if line.startswith('{') and line.endswith('}'):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def get_hook_type(hook_name: str) -> str:
    """Determine hook type from filename."""
    if any(x in hook_name for x in ['stop-', 'sentry-report', 'reflection-engine']):
        return 'Stop'
    elif any(x in hook_name for x in ['context-warning', 'periodic-reminder', 'prompt-analyzer', 'memory-write-trigger']):
        return 'UserPromptSubmit'
    elif any(x in hook_name for x in ['session-start', 'auto-sync', 'post-compact-restore', 'inject-context']):
        return 'SessionStart'
    elif 'pre-compact' in hook_name:
        return 'PreCompact'
    else:
        return 'PostToolUse'


class TestCriticalFormatRegression:
    """
    CRITICAL: These tests verify that hooks NEVER use the invalid format.

    The string "continue" is NEVER valid for the "decision" field.
    This mistake was the root cause of the v2.57.3 incident.
    """

    @pytest.fixture
    def all_hooks(self) -> list:
        """Get all hook files from both global and project directories."""
        hooks = []
        for hooks_dir in [HOOKS_DIR, PROJECT_HOOKS_DIR]:
            if hooks_dir.exists():
                hooks.extend(hooks_dir.glob("*.sh"))
        return hooks

    def test_no_decision_continue_in_any_hook(self, all_hooks):
        """
        CRITICAL REGRESSION TEST: No hook should EVER output {"decision": "continue"}.

        This is the primary test that prevents the v2.57.3 incident from recurring.
        """
        violations = []

        for hook_path in all_hooks:
            content = hook_path.read_text()
            import re

            # Check each line for the FORBIDDEN pattern, ignoring comments
            for line_num, line in enumerate(content.split('\n'), 1):
                # Skip comment lines (bash # comments)
                stripped = line.strip()
                if stripped.startswith('#'):
                    continue

                # Check for the exact invalid pattern in actual code
                if re.search(r'"decision":\s*"continue"', line):
                    violations.append(f"{hook_path.name}:{line_num}: Contains INVALID pattern 'decision: continue'")

        assert len(violations) == 0, (
            f"CRITICAL REGRESSION: {len(violations)} hook(s) contain INVALID 'decision: continue' pattern!\n"
            f"Violations:\n" + "\n".join(f"  - {v}" for v in violations) + "\n\n"
            f"FIX: Use {{'continue': true}} for PostToolUse/PreToolUse/UserPromptSubmit\n"
            f"     Use {{'decision': 'approve'}} for Stop hooks\n"
            f"Reference: tests/HOOK_FORMAT_REFERENCE.md"
        )

    def test_stop_hooks_use_approve_or_block(self, all_hooks):
        """Stop hooks must use {"decision": "approve"} or {"decision": "block"}."""
        violations = []

        for hook_path in all_hooks:
            hook_type = get_hook_type(hook_path.name)
            if hook_type != 'Stop':
                continue

            content = hook_path.read_text()

            # Stop hooks should have "decision": "approve" or "decision": "block"
            import re
            has_valid_stop_format = bool(re.search(r'"decision":\s*"(approve|block)"', content))

            # Should NOT have {"continue": true} as primary output
            has_continue_format = bool(re.search(r'"continue":\s*(true|false)', content))

            if not has_valid_stop_format and has_continue_format:
                violations.append(f"{hook_path.name}: Stop hook uses 'continue' instead of 'decision: approve/block'")

        assert len(violations) == 0, (
            f"STOP HOOK FORMAT ERROR: {len(violations)} Stop hook(s) use wrong format!\n"
            f"Violations:\n" + "\n".join(f"  - {v}" for v in violations) + "\n\n"
            f"Stop hooks MUST use: {{\"decision\": \"approve\"}} or {{\"decision\": \"block\"}}\n"
            f"Reference: tests/HOOK_FORMAT_REFERENCE.md"
        )

    def test_non_stop_hooks_use_continue(self, all_hooks):
        """PostToolUse/PreToolUse/UserPromptSubmit hooks must use {"continue": true/false}."""
        violations = []

        for hook_path in all_hooks:
            hook_type = get_hook_type(hook_path.name)
            if hook_type == 'Stop':
                continue

            content = hook_path.read_text()
            import re

            # Check each line, ignoring comments
            for line_num, line in enumerate(content.split('\n'), 1):
                stripped = line.strip()
                if stripped.startswith('#'):
                    continue

                # Check for WRONG use of "decision" field in non-Stop hooks
                if re.search(r'"decision":\s*"', line):
                    # Allow "decision": "block" for permission blocking in PreToolUse
                    if not re.search(r'"decision":\s*"block"', line):
                        violations.append(f"{hook_path.name}:{line_num}: {hook_type} hook uses 'decision' field (should use 'continue')")
                        break  # Only report first violation per file

        assert len(violations) == 0, (
            f"NON-STOP HOOK FORMAT ERROR: {len(violations)} hook(s) use wrong format!\n"
            f"Violations:\n" + "\n".join(f"  - {v}" for v in violations) + "\n\n"
            f"PostToolUse/PreToolUse/UserPromptSubmit hooks MUST use: {{\"continue\": true/false}}\n"
            f"Reference: tests/HOOK_FORMAT_REFERENCE.md"
        )


class TestRuntimeFormatValidation:
    """
    Runtime tests that actually execute hooks and validate their JSON output.
    """

    @pytest.fixture
    def test_input_posttooluse(self) -> str:
        return json.dumps({
            "tool_name": "Task",
            "tool_input": {"prompt": "test task"},
            "session_id": "test-session"
        })

    @pytest.fixture
    def test_input_userpromptsubmit(self) -> str:
        return json.dumps({
            "prompt": "test prompt",
            "session_id": "test-session"
        })

    @pytest.fixture
    def test_input_stop(self) -> str:
        return json.dumps({
            "session_id": "test-session",
            "reason": "test"
        })

    @pytest.mark.parametrize("hook_name", [
        "inject-session-context.sh",
        "procedural-inject.sh",
        "todo-plan-sync.sh",
        "status-auto-check.sh",
        "auto-save-context.sh",
    ])
    def test_posttooluse_hooks_output_continue_format(self, hook_name, test_input_posttooluse):
        """Verify PostToolUse hooks output {"continue": true/false} format."""
        hook_path = HOOKS_DIR / hook_name
        if not hook_path.exists():
            pytest.skip(f"Hook not found: {hook_name}")

        exit_code, stdout, stderr = run_hook(hook_path, test_input_posttooluse)

        # Should not crash
        assert exit_code == 0, f"Hook crashed: {stderr}"

        # Extract JSON
        output = extract_json_from_output(stdout)

        if output is None:
            # Empty output or no JSON is sometimes valid
            return

        # CRITICAL: Should NOT have {"decision": "continue"}
        if "decision" in output:
            assert output.get("decision") != "continue", (
                f"CRITICAL: {hook_name} outputs INVALID format: {{\"decision\": \"continue\"}}\n"
                f"Output: {output}\n"
                f"FIX: Use {{\"continue\": true}} instead"
            )

        # Should have "continue" field if not empty
        if output != {}:
            assert "continue" in output or "hookSpecificOutput" in output, (
                f"{hook_name} missing 'continue' field. Output: {output}"
            )

    @pytest.mark.parametrize("hook_name", [
        "stop-verification.sh",
        "sentry-report.sh",
    ])
    def test_stop_hooks_output_decision_format(self, hook_name, test_input_stop):
        """Verify Stop hooks output {"decision": "approve"/"block"} format."""
        hook_path = HOOKS_DIR / hook_name
        if not hook_path.exists():
            pytest.skip(f"Hook not found: {hook_name}")

        exit_code, stdout, stderr = run_hook(hook_path, test_input_stop)

        # Should not crash
        assert exit_code == 0, f"Hook crashed: {stderr}"

        # Extract JSON
        output = extract_json_from_output(stdout)

        if output is None:
            pytest.fail(f"Stop hook {hook_name} did not output JSON")

        # MUST have "decision" field
        assert "decision" in output, (
            f"Stop hook {hook_name} missing 'decision' field. Output: {output}"
        )

        # MUST be "approve" or "block", NEVER "continue"
        decision = output.get("decision")
        assert decision in ("approve", "block"), (
            f"Stop hook {hook_name} has invalid decision: '{decision}'\n"
            f"Must be 'approve' or 'block', NEVER 'continue'!\n"
            f"Output: {output}"
        )


class TestFormatDocumentation:
    """Verify that format documentation exists and is correct."""

    def test_hook_format_reference_exists(self):
        """HOOK_FORMAT_REFERENCE.md must exist."""
        ref_path = Path("tests/HOOK_FORMAT_REFERENCE.md")
        assert ref_path.exists(), (
            "CRITICAL: tests/HOOK_FORMAT_REFERENCE.md is missing!\n"
            "This file is the single source of truth for hook JSON formats."
        )

    def test_hook_format_reference_has_critical_rule(self):
        """Reference document must contain the critical rule about decision/continue."""
        ref_path = Path("tests/HOOK_FORMAT_REFERENCE.md")
        if not ref_path.exists():
            pytest.skip("Reference file missing")

        content = ref_path.read_text()

        # Must mention that "continue" is NEVER valid for decision
        assert "NEVER" in content and "decision" in content, (
            "HOOK_FORMAT_REFERENCE.md must explicitly state that "
            "'continue' is NEVER valid for the 'decision' field"
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
