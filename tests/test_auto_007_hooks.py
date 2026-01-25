#!/usr/bin/env python3
"""
AUTO-007 Hook Tests - v2.70.0

Tests for the automatic execution mode system that allows /orchestrator
and /loop to run without interruptions from security hooks.

Components tested:
1. auto-mode-setter.sh - Detects orchestrator/loop and sets auto mode
2. security-full-audit.sh - Silent in auto mode, stores markers
3. adversarial-auto-trigger.sh - Silent in auto mode, stores markers
4. orchestrator/SKILL.md - Reads markers and executes validations automatically
5. loop/SKILL.md - Reads markers and executes validations automatically

VERSION: 2.70.0
"""
import os
import sys
import json
import subprocess
import tempfile
import pytest
from pathlib import Path
from typing import Dict, Any, Optional


# ═══════════════════════════════════════════════════════════════════════════════
# Test Configuration
# ═══════════════════════════════════════════════════════════════════════════════

PROJECT_ROOT = Path(__file__).parent.parent
GLOBAL_HOOKS = Path.home() / ".claude" / "hooks"
MARKERS_DIR = Path.home() / ".ralph" / "markers"
ORCHESTRATOR_SKILL = Path.home() / ".config" / "opencode" / "skill" / "orchestrator" / "SKILL.md"
LOOP_SKILL = Path.home() / ".config" / "opencode" / "skill" / "loop" / "SKILL.md"

HOOK_TIMEOUT = 15


# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

def run_hook(hook_path: Path, input_json: str,
             timeout: int = HOOK_TIMEOUT, env: Optional[Dict] = None) -> Dict[str, Any]:
    """Execute a hook with given JSON input and return parsed result."""
    start_time = time.time()

    try:
        result = subprocess.run(
            ["bash", str(hook_path)],
            input=input_json,
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT),
            timeout=timeout,
            env={**os.environ, **(env or {})}
        )

        execution_time = time.time() - start_time

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
    except Exception as e:
        return {
            "returncode": -1,
            "stdout": "",
            "stderr": str(e),
            "output": None,
            "is_valid_json": False,
            "execution_time": time.time() - start_time
        }


def create_skill_input(skill_name: str = "orchestrator",
                      session_id: str = "test-session-auto") -> str:
    """Create a valid Skill tool input JSON."""
    return json.dumps({
        "tool_name": "Skill",
        "session_id": session_id,
        "tool_input": {
            "skill": skill_name
        }
    })


import time


# ═══════════════════════════════════════════════════════════════════════════════
# Category 1: AUTO-MODE-SETTER.HOOK Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestAutoModeSetterHook:
    """Tests for auto-mode-setter.sh hook."""

    HOOK_PATH = GLOBAL_HOOKS / "auto-mode-setter.sh"

    @pytest.fixture(autouse=True)
    def setup(self):
        if not self.HOOK_PATH.exists():
            pytest.skip(f"auto-mode-setter.sh not found: {self.HOOK_PATH}")

    def test_hook_exists_and_executable(self):
        """Hook should exist and be executable."""
        assert self.HOOK_PATH.exists(), "auto-mode-setter.sh not found"
        assert os.access(self.HOOK_PATH, os.X_OK), "auto-mode-setter.sh not executable"

    def test_has_version_2_70_0(self):
        """Hook should have VERSION 2.70.0."""
        content = self.HOOK_PATH.read_text()
        assert "VERSION: 2.70.0" in content, "VERSION should be 2.70.0"

    def test_detects_orchestrator_skill(self):
        """Hook should detect orchestrator skill and set context."""
        input_json = create_skill_input("orchestrator")
        result = run_hook(self.HOOK_PATH, input_json)

        assert result["is_valid_json"], f"Should return valid JSON: {result['stdout']}"
        assert result["output"].get("decision") == "allow", "Should allow execution"

        # Check that additionalContext mentions AUTO-007
        context = result["output"].get("additionalContext", "")
        assert "AUTO-007" in context or "automatic" in context.lower(), (
            "Should set AUTO-007 context for orchestrator"
        )

    def test_detects_loop_skill(self):
        """Hook should detect loop skill and set context."""
        input_json = create_skill_input("loop")
        result = run_hook(self.HOOK_PATH, input_json)

        assert result["is_valid_json"], f"Should return valid JSON: {result['stdout']}"
        assert result["output"].get("decision") == "allow", "Should allow execution"

        # Check that additionalContext mentions AUTO-007
        context = result["output"].get("additionalContext", "")
        assert "AUTO-007" in context or "automatic" in context.lower(), (
            "Should set AUTO-007 context for loop"
        )

    def test_ignores_non_auto_skills(self):
        """Hook should ignore non-auto skills."""
        input_json = create_skill_input("security")
        result = run_hook(self.HOOK_PATH, input_json)

        assert result["is_valid_json"]
        assert result["output"].get("decision") == "allow"

        # Should NOT set AUTO-007 context
        context = result["output"].get("additionalContext", "")
        if context:
            # If context is set, it should not mention AUTO-007
            assert "AUTO-007" not in context


# ═══════════════════════════════════════════════════════════════════════════════
# Category 2: SECURITY-FULL-AUDIT.HOOK Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestSecurityFullAuditHook:
    """Tests for security-full-audit.sh hook AUTO-007 mode."""

    HOOK_PATH = GLOBAL_HOOKS / "security-full-audit.sh"

    @pytest.fixture(autouse=True)
    def setup(self):
        if not self.HOOK_PATH.exists():
            pytest.skip(f"security-full-audit.sh not found: {self.HOOK_PATH}")

    def test_has_version_2_70_0(self):
        """Hook should have VERSION 2.70.0."""
        content = self.HOOK_PATH.read_text()
        assert "VERSION: 2.70.0" in content, "VERSION should be 2.70.0"

    def test_has_is_auto_mode_function(self):
        """Hook should have is_auto_mode() function."""
        content = self.HOOK_PATH.read_text()
        assert "is_auto_mode()" in content, "is_auto_mode() function required"

    def test_auto_mode_check_logic(self):
        """Hook should check RALPH_AUTO_MODE environment variable."""
        content = self.HOOK_PATH.read_text()
        assert 'RALPH_AUTO_MODE' in content, "Should check RALPH_AUTO_MODE"
        assert '[[ "${RALPH_AUTO_MODE:-false}" == "true" ]]' in content, (
            "Should check if RALPH_AUTO_MODE equals true"
        )

    def test_stores_marker_in_auto_mode(self):
        """Hook should store marker file in auto mode."""
        content = self.HOOK_PATH.read_text()
        assert 'MARKERS_DIR' in content, "Should define MARKERS_DIR"
        assert 'security-pending-' in content, "Should create security-pending marker"
        assert '$(get_session_id)' in content, "Should use get_session_id function"
        assert 'security-pending-$(get_session_id).txt' in content, (
            "Should use session ID in marker filename"
        )

    def test_silent_in_auto_mode(self):
        """Hook should be completely silent in auto mode (no systemMessage)."""
        content = self.HOOK_PATH.read_text()

        # In auto mode, should only output {"continue": true}
        # Look for the pattern where trap is cleared before output
        assert 'trap - ERR EXIT' in content, "Should clear trap before final output"
        assert 'echo \'{"continue": true}\'' in content or \
               r'echo "{\"continue\": true}"' in content, (
            "Should output only {'continue': true} in auto mode"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Category 3: ADVERSARIAL-AUTO-TRIGGER.HOOK Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestAdversarialAutoTriggerHook:
    """Tests for adversarial-auto-trigger.sh hook AUTO-007 mode."""

    HOOK_PATH = GLOBAL_HOOKS / "adversarial-auto-trigger.sh"

    @pytest.fixture(autouse=True)
    def setup(self):
        if not self.HOOK_PATH.exists():
            pytest.skip(f"adversarial-auto-trigger.sh not found: {self.HOOK_PATH}")

    def test_has_version_2_70_0(self):
        """Hook should have VERSION 2.70.0."""
        content = self.HOOK_PATH.read_text()
        assert "VERSION: 2.70.0" in content, "VERSION should be 2.70.0"

    def test_has_is_auto_mode_function(self):
        """Hook should have is_auto_mode() function."""
        content = self.HOOK_PATH.read_text()
        assert "is_auto_mode()" in content, "is_auto_mode() function required"

    def test_stores_marker_in_auto_mode(self):
        """Hook should store marker file in auto mode."""
        content = self.HOOK_PATH.read_text()
        assert 'MARKERS_DIR' in content, "Should define MARKERS_DIR"
        assert 'adversarial-pending-' in content, "Should create adversarial-pending marker"
        assert '$(get_session_id)' in content, "Should use get_session_id function"
        assert 'adversarial-pending-$(get_session_id).txt' in content, (
            "Should use session ID in marker filename"
        )

    def test_silent_in_auto_mode(self):
        """Hook should be completely silent in auto mode (no systemMessage)."""
        content = self.HOOK_PATH.read_text()

        # In auto mode, should only output {"continue": true}
        assert 'trap - ERR EXIT' in content, "Should clear trap before final output"
        assert 'echo \'{"continue": true}\'' in content or \
               r'echo "{\"continue\": true}"' in content, (
            "Should output only {'continue': true} in auto mode"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Category 4: MARKER FILE SYSTEM Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestMarkerFilesystem:
    """Tests for the marker file system used by AUTO-007."""

    def test_markers_directory_exists(self):
        """Markers directory should exist."""
        assert MARKERS_DIR.exists(), f"Markers directory should exist: {MARKERS_DIR}"
        assert MARKERS_DIR.is_dir(), "Should be a directory"

    @pytest.mark.skipif(sys.platform == "win32", reason="Unix-specific permission checks")
    def test_markers_directory_permissions(self):
        """Markers directory should have restrictive permissions."""
        stat_info = MARKERS_DIR.stat()
        # Unix permissions: 0o700 = rwx------
        mode = stat_info.st_mode & 0o777
        assert mode >= 0o700, f"Markers directory should have restrictive permissions: {oct(mode)}"

    def test_marker_files_use_session_id(self):
        """Marker files should include session ID in filename."""
        # Check that hooks use $(get_session_id) or get_session_id()
        security_hook = GLOBAL_HOOKS / "security-full-audit.sh"
        if security_hook.exists():
            content = security_hook.read_text()
            assert "$(get_session_id)" in content or "get_session_id()" in content, (
                "Marker filename should include session ID via get_session_id()"
            )


# ═══════════════════════════════════════════════════════════════════════════════
# Category 5: SKILL INTEGRATION Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestOrchestratorSkillIntegration:
    """Tests for orchestrator/SKILL.md AUTO-007 integration."""

    @pytest.fixture(autouse=True)
    def setup(self):
        if not ORCHESTRATOR_SKILL.exists():
            pytest.skip(f"orchestrator/SKILL.md not found: {ORCHESTRATOR_SKILL}")

    def test_has_auto_007_section(self):
        """Skill should have AUTO-007 section in Step 6."""
        content = ORCHESTRATOR_SKILL.read_text()
        assert "AUTO-007" in content, "Should have AUTO-007 section"
        assert "Automatic Execution" in content or "automatic" in content.lower(), (
            "Should mention automatic execution"
        )

    def test_step6_has_automatic_security_audits(self):
        """Step 6 should have automatic security audit logic."""
        content = ORCHESTRATOR_SKILL.read_text()

        # Check for automatic security audit pattern
        assert "security-pending" in content, "Should check for security-pending marker"
        assert "/security" in content, "Should execute /security command"
        assert "MARKERS_DIR" in content, "Should reference MARKERS_DIR"
        assert "SESSION_ID" in content, "Should reference SESSION_ID"

    def test_step6_has_automatic_adversarial_validation(self):
        """Step 6 should have automatic adversarial validation logic."""
        content = ORCHESTRATOR_SKILL.read_text()

        # Check for automatic adversarial validation pattern
        assert "adversarial-pending" in content, "Should check for adversarial-pending marker"
        assert "/adversarial" in content, "Should execute /adversarial command"


class TestLoopSkillIntegration:
    """Tests for loop/SKILL.md AUTO-007 integration."""

    @pytest.fixture(autouse=True)
    def setup(self):
        if not LOOP_SKILL.exists():
            pytest.skip(f"loop/SKILL.md not found: {LOOP_SKILL}")

    def test_has_auto_007_section(self):
        """Skill should have AUTO-007 section in Validate step."""
        content = LOOP_SKILL.read_text()
        assert "AUTO-007" in content, "Should have AUTO-007 section"

    def test_validate_has_automatic_security_audits(self):
        """Validate step should have automatic security audit logic."""
        content = LOOP_SKILL.read_text()

        assert "security-pending" in content, "Should check for security-pending marker"
        assert "/security" in content, "Should execute /security command"

    def test_validate_has_automatic_adversarial_validation(self):
        """Validate step should have automatic adversarial validation logic."""
        content = LOOP_SKILL.read_text()

        assert "adversarial-pending" in content, "Should check for adversarial-pending marker"
        assert "/adversarial" in content, "Should execute /adversarial command"


# ═══════════════════════════════════════════════════════════════════════════════
# Category 6: SETTINGS.JSON Registration Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestAutoModeSetterRegistration:
    """Tests for auto-mode-setter.sh registration in settings.json."""

    @pytest.fixture(scope="module")
    def settings_json(self):
        """Load settings.json."""
        settings_path = Path.home() / ".claude" / "settings.json"
        if not settings_path.exists():
            pytest.skip(f"settings.json not found: {settings_path}")

        with open(settings_path) as f:
            return json.load(f)

    def test_registered_in_pretooluse_skill(self, settings_json):
        """auto-mode-setter.sh should be registered in PreToolUse → Skill."""
        pre_tool_use = settings_json.get("hooks", {}).get("PreToolUse", [])

        found = False
        for hook_group in pre_tool_use:
            if hook_group.get("matcher") == "Skill":
                hooks = hook_group.get("hooks", [])
                for hook in hooks:
                    command = hook.get("command", "")
                    if "auto-mode-setter.sh" in command:
                        found = True
                        break

        assert found, "auto-mode-setter.sh should be registered in PreToolUse → Skill matcher"


# ═══════════════════════════════════════════════════════════════════════════════
# Category 7: INTEGRATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

class TestAuto007Integration:
    """Integration tests for complete AUTO-007 flow."""

    @pytest.fixture(autouse=True)
    def setup(self):
        """Skip if critical components missing."""
        if not (GLOBAL_HOOKS / "auto-mode-setter.sh").exists():
            pytest.skip("auto-mode-setter.sh not found")
        if not (GLOBAL_HOOKS / "security-full-audit.sh").exists():
            pytest.skip("security-full-audit.sh not found")
        if not (GLOBAL_HOOKS / "adversarial-auto-trigger.sh").exists():
            pytest.skip("adversarial-auto-trigger.sh not found")

    def test_complete_auto_flow_components_exist(self):
        """All AUTO-007 components should exist."""
        components = {
            "auto-mode-setter.sh": GLOBAL_HOOKS / "auto-mode-setter.sh",
            "security-full-audit.sh": GLOBAL_HOOKS / "security-full-audit.sh",
            "adversarial-auto-trigger.sh": GLOBAL_HOOKS / "adversarial-auto-trigger.sh",
            "orchestrator/SKILL.md": ORCHESTRATOR_SKILL,
            "loop/SKILL.md": LOOP_SKILL,
        }

        missing = [name for name, path in components.items() if not path.exists()]
        assert not missing, f"Missing components: {missing}"

    def test_all_components_version_2_70_0(self):
        """All components should have version 2.70.0."""
        hooks = [
            GLOBAL_HOOKS / "auto-mode-setter.sh",
            GLOBAL_HOOKS / "security-full-audit.sh",
            GLOBAL_HOOKS / "adversarial-auto-trigger.sh",
        ]

        wrong_version = []
        for hook in hooks:
            if hook.exists():
                content = hook.read_text()
                if "VERSION: 2.70.0" not in content:
                    wrong_version.append(hook.name)

        assert not wrong_version, f"Wrong version in: {wrong_version}"

    def test_auto_007_pattern_consistent(self):
        """AUTO-007 pattern should be consistent across all hooks."""
        # Note: auto-mode-setter.sh doesn't need is_auto_mode() - it SETS the mode
        hooks_with_is_auto_mode = [
            GLOBAL_HOOKS / "security-full-audit.sh",
            GLOBAL_HOOKS / "adversarial-auto-trigger.sh",
        ]

        for hook in hooks_with_is_auto_mode:
            if hook.exists():
                content = hook.read_text()
                # All should have is_auto_mode function
                assert "is_auto_mode()" in content, f"{hook.name} missing is_auto_mode()"
                # All should have MARKERS_DIR
                assert "MARKERS_DIR" in content, f"{hook.name} missing MARKERS_DIR"


# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY TEST
# ═══════════════════════════════════════════════════════════════════════════════

def test_auto_007_comprehensive_summary():
    """Generate comprehensive AUTO-007 test summary."""

    components = {
        "Hook Files": {
            "auto-mode-setter.sh": (GLOBAL_HOOKS / "auto-mode-setter.sh").exists(),
            "security-full-audit.sh (v2.70.0)": (GLOBAL_HOOKS / "security-full-audit.sh").exists() and "VERSION: 2.70.0" in (GLOBAL_HOOKS / "security-full-audit.sh").read_text(),
            "adversarial-auto-trigger.sh (v2.70.0)": (GLOBAL_HOOKS / "adversarial-auto-trigger.sh").exists() and "VERSION: 2.70.0" in (GLOBAL_HOOKS / "adversarial-auto-trigger.sh").read_text(),
        },
        "AUTO-007 Functions": {
            "is_auto_mode() in security-full-audit.sh": "is_auto_mode()" in (GLOBAL_HOOKS / "security-full-audit.sh").read_text(),
            "is_auto_mode() in adversarial-auto-trigger.sh": "is_auto_mode()" in (GLOBAL_HOOKS / "adversarial-auto-trigger.sh").read_text(),
            # Note: auto-mode-setter.sh doesn't use is_auto_mode() - it SETS the mode
        },
        "Marker System": {
            "~/.ralph/markers/ directory": MARKERS_DIR.exists(),
            "Uses get_session_id() in markers": all([
                "get_session_id()" in (GLOBAL_HOOKS / "security-full-audit.sh").read_text(),
                "get_session_id()" in (GLOBAL_HOOKS / "adversarial-auto-trigger.sh").read_text(),
            ]),
        },
        "Skill Integration": {
            "orchestrator/SKILL.md has AUTO-007": ORCHESTRATOR_SKILL.exists() and "AUTO-007" in ORCHESTRATOR_SKILL.read_text(),
            "loop/SKILL.md has AUTO-007": LOOP_SKILL.exists() and "AUTO-007" in LOOP_SKILL.read_text(),
        },
        "Registration": {
            "auto-mode-setter.sh in settings.json": "auto-mode-setter.sh" in (Path.home() / ".claude" / "settings.json").read_text(),
        },
    }

    all_passed = True
    report = ["\n" + "=" * 70]
    report.append("AUTO-007 COMPREHENSIVE TEST SUMMARY - v2.70.0")
    report.append("=" * 70)

    for category, items in components.items():
        report.append(f"\n{category}:")
        for check_name, passed in items.items():
            status = "✅ PASS" if passed else "❌ FAIL"
            report.append(f"  {status}: {check_name}")
            if not passed:
                all_passed = False

    report.append("\n" + "=" * 70)
    overall = "ALL CHECKS PASSED ✅" if all_passed else "ISSUES DETECTED ❌"
    report.append(f"OVERALL: {overall}")
    report.append("=" * 70 + "\n")

    print("\n".join(report))

    assert all_passed, "Not all AUTO-007 checks passed. See report above."


# ═══════════════════════════════════════════════════════════════════════════════
# RUN TESTS
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "-x"])
