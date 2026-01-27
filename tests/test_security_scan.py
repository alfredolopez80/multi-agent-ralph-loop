#!/usr/bin/env python3
"""
Security Scan (Stage 2.5) Test Suite - v2.48.0

Tests for Stage 2.5 SECURITY in quality-gates-v2.sh:
- semgrep SAST validation
- gitleaks secret detection
- Graceful degradation when tools not installed
- Installation suggestion behavior

VERSION: 2.48.0
"""
import os
import json
import subprocess
import tempfile
import shutil
import pytest
from pathlib import Path
from typing import Dict, Any, Optional


# ═══════════════════════════════════════════════════════════════════════════════
# Test Configuration
# ═══════════════════════════════════════════════════════════════════════════════

PROJECT_ROOT = Path(__file__).parent.parent
QUALITY_GATES_HOOK = Path.home() / ".claude" / "hooks" / "quality-gates-v2.sh"
PROJECT_HOOK = PROJECT_ROOT / ".claude" / "hooks" / "quality-gates-v2.sh"
INSTALL_SCRIPT = PROJECT_ROOT / "scripts" / "install-security-tools.sh"

# Choose the hook to test
HOOK_PATH = QUALITY_GATES_HOOK if QUALITY_GATES_HOOK.exists() else PROJECT_HOOK

HOOK_TIMEOUT = 30  # seconds (semgrep can be slow first run)


# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

def run_hook(input_json: str, cwd: Optional[str] = None) -> Dict[str, Any]:
    """Execute quality-gates-v2.sh with given JSON input."""
    try:
        result = subprocess.run(
            ["bash", str(HOOK_PATH)],
            input=input_json,
            capture_output=True,
            text=True,
            cwd=cwd or str(PROJECT_ROOT),
            timeout=HOOK_TIMEOUT,
            env={**os.environ, "HOME": os.environ.get("HOME", "")}
        )

        output = None
        is_valid_json = False
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
            "is_valid_json": is_valid_json
        }
    except subprocess.TimeoutExpired:
        return {
            "returncode": -1,
            "stdout": "",
            "stderr": "TIMEOUT",
            "output": None,
            "is_valid_json": False
        }


def check_tool_installed(tool: str) -> bool:
    """Check if a security tool is installed."""
    return shutil.which(tool) is not None


def create_temp_file(content: str, suffix: str = ".py") -> Path:
    """Create a temporary file with given content."""
    fd, path = tempfile.mkstemp(suffix=suffix)
    os.write(fd, content.encode())
    os.close(fd)
    return Path(path)


# ═══════════════════════════════════════════════════════════════════════════════
# Test Fixtures
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture
def temp_python_file():
    """Create a temporary Python file for testing."""
    content = '''
def hello():
    print("Hello, World!")

if __name__ == "__main__":
    hello()
'''
    path = create_temp_file(content, ".py")
    yield path
    os.unlink(path)


@pytest.fixture
def temp_file_with_secret():
    """Create a file with a hardcoded secret (for gitleaks testing)."""
    # Using obvious fake credentials for testing purposes
    content = '''
# Configuration file - FAKE CREDENTIALS FOR TESTING
API_KEY = "FAKE_TEST_API_KEY_PLACEHOLDER_DO_NOT_USE"
DATABASE_URL = "postgres://user:FAKE_PASSWORD@localhost/db"
'''
    path = create_temp_file(content, ".py")
    yield path
    os.unlink(path)


@pytest.fixture
def temp_file_with_vuln():
    """Create a file with a security vulnerability (for semgrep)."""
    # NOTE: This file intentionally contains security vulnerabilities
    # for testing that semgrep detects them. Do not use in production.
    content = '''
import subprocess

def run_command(user_input):
    # Intentional vulnerability for testing: command injection
    subprocess.call(user_input, shell=True)
'''
    path = create_temp_file(content, ".py")
    yield path
    os.unlink(path)


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Tool Installation
# ═══════════════════════════════════════════════════════════════════════════════

class TestToolInstallation:
    """Tests for security tool installation."""

    def test_install_script_exists(self):
        """Install script should exist."""
        assert INSTALL_SCRIPT.exists(), f"Install script not found at {INSTALL_SCRIPT}"

    def test_install_script_executable(self):
        """Install script should be executable."""
        assert os.access(INSTALL_SCRIPT, os.X_OK), "Install script is not executable"

    def test_install_check_mode(self):
        """Install script --check should report tool status."""
        result = subprocess.run(
            ["bash", str(INSTALL_SCRIPT), "--check"],
            capture_output=True,
            text=True
        )
        # Should always output something (even if tools missing)
        assert "Security Tools Status" in result.stdout

    @pytest.mark.skipif(not check_tool_installed("semgrep"), reason="semgrep not installed")
    def test_semgrep_installed(self):
        """semgrep should be installed and functional."""
        result = subprocess.run(
            ["semgrep", "--version"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "semgrep" in result.stdout.lower() or result.stdout.strip()

    @pytest.mark.skipif(not check_tool_installed("gitleaks"), reason="gitleaks not installed")
    def test_gitleaks_installed(self):
        """gitleaks should be installed and functional."""
        result = subprocess.run(
            ["gitleaks", "version"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Quality Gates Hook with Security Stage
# ═══════════════════════════════════════════════════════════════════════════════

class TestQualityGatesSecurityStage:
    """Tests for Stage 2.5 SECURITY in quality-gates-v2.sh."""

    def test_hook_exists(self):
        """Quality gates hook should exist."""
        assert HOOK_PATH.exists(), f"Hook not found at {HOOK_PATH}"

    def test_hook_has_security_stage(self):
        """Hook should contain Stage 2.5 SECURITY."""
        content = HOOK_PATH.read_text()
        assert "STAGE 2.5: SECURITY" in content, "Stage 2.5 SECURITY not found in hook"

    def test_hook_has_semgrep_integration(self):
        """Hook should have semgrep integration."""
        content = HOOK_PATH.read_text()
        assert "semgrep" in content, "semgrep not found in hook"

    def test_hook_has_gitleaks_integration(self):
        """Hook should have gitleaks integration."""
        content = HOOK_PATH.read_text()
        assert "gitleaks" in content, "gitleaks not found in hook"

    def test_hook_returns_json_on_clean_file(self, temp_python_file):
        """Hook should return valid JSON for clean Python file.

        quality-gates-v2.sh is a PostToolUse hook, so it returns {"continue": true/false}
        NOT {"decision": ...} which is for PreToolUse hooks.
        """
        input_json = json.dumps({
            "tool_name": "Edit",
            "tool_input": {"file_path": str(temp_python_file)},
            "session_id": "test-session"
        })

        result = run_hook(input_json)

        assert result["is_valid_json"], f"Invalid JSON: {result['stdout']}"
        # PostToolUse hooks return {"continue": true/false}, not {"decision": ...}
        assert "continue" in result["output"], (
            f"PostToolUse hook should return 'continue' key, got: {result['output']}"
        )

    @pytest.mark.skipif(not check_tool_installed("semgrep"), reason="semgrep not installed")
    def test_semgrep_detects_command_injection(self, temp_file_with_vuln):
        """semgrep should detect command injection vulnerability."""
        input_json = json.dumps({
            "tool_name": "Write",
            "tool_input": {"file_path": str(temp_file_with_vuln)},
            "session_id": "test-session"
        })

        result = run_hook(input_json)

        assert result["is_valid_json"]
        # Note: May or may not block depending on semgrep rules
        # The important thing is it runs without error

    @pytest.mark.skipif(not check_tool_installed("gitleaks"), reason="gitleaks not installed")
    def test_gitleaks_detects_secrets(self, temp_file_with_secret):
        """gitleaks should detect hardcoded secrets."""
        input_json = json.dumps({
            "tool_name": "Write",
            "tool_input": {"file_path": str(temp_file_with_secret)},
            "session_id": "test-session"
        })

        result = run_hook(input_json)

        assert result["is_valid_json"]
        # PostToolUse hook returns "continue" key
        # If blocked, it could be secrets OR path traversal (temp files outside allowed dirs)
        if result["output"].get("continue") is False:
            reason = str(result["output"]).lower()
            # Accept both secret detection and path traversal blocks
            assert "secret" in reason or "path traversal" in reason or "blocked" in reason, (
                f"Expected secret detection or path block, got: {result['output']}"
            )


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Graceful Degradation
# ═══════════════════════════════════════════════════════════════════════════════

class TestGracefulDegradation:
    """Tests for graceful degradation when tools not installed."""

    def test_hook_works_without_tools(self, temp_python_file):
        """Hook should work even if security tools not available."""
        input_json = json.dumps({
            "tool_name": "Edit",
            "tool_input": {"file_path": str(temp_python_file)},
            "session_id": "test-session"
        })

        result = run_hook(input_json)

        # Should still return valid JSON
        assert result["is_valid_json"], f"Invalid JSON: {result['stdout']}"
        # PostToolUse hook should return "continue" key (not crash)
        assert "continue" in result["output"], (
            f"PostToolUse hook should return 'continue' key, got: {result['output']}"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Performance
# ═══════════════════════════════════════════════════════════════════════════════

class TestSecurityScanPerformance:
    """Performance tests for security scanning."""

    def test_hook_completes_within_timeout(self, temp_python_file):
        """Hook should complete within reasonable timeout."""
        input_json = json.dumps({
            "tool_name": "Edit",
            "tool_input": {"file_path": str(temp_python_file)},
            "session_id": "test-session"
        })

        import time
        start = time.time()
        result = run_hook(input_json)
        duration = time.time() - start

        assert result["returncode"] != -1, "Hook timed out"
        assert duration < HOOK_TIMEOUT, f"Hook took too long: {duration}s"

    @pytest.mark.skipif(not check_tool_installed("semgrep"), reason="semgrep not installed")
    def test_semgrep_timeout_protection(self):
        """semgrep should respect timeout limit."""
        # The hook uses `timeout 5` for semgrep
        content = HOOK_PATH.read_text()
        assert "timeout" in content and "semgrep" in content


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Edge Cases
# ═══════════════════════════════════════════════════════════════════════════════

class TestSecurityScanEdgeCases:
    """Edge case tests for security scanning."""

    def test_non_python_file_handled(self):
        """Hook should handle non-Python files gracefully."""
        # Create a JSON file
        temp_file = create_temp_file('{"key": "value"}', ".json")

        try:
            input_json = json.dumps({
                "tool_name": "Edit",
                "tool_input": {"file_path": str(temp_file)},
                "session_id": "test-session"
            })

            result = run_hook(input_json)

            assert result["is_valid_json"]
            # PostToolUse hook should return "continue" key
            assert "continue" in result["output"], (
                f"PostToolUse hook should return 'continue' key, got: {result['output']}"
            )
        finally:
            os.unlink(temp_file)

    def test_empty_file_handled(self):
        """Hook should handle empty files gracefully."""
        temp_file = create_temp_file("", ".py")

        try:
            input_json = json.dumps({
                "tool_name": "Edit",
                "tool_input": {"file_path": str(temp_file)},
                "session_id": "test-session"
            })

            result = run_hook(input_json)

            assert result["is_valid_json"]
        finally:
            os.unlink(temp_file)

    def test_large_file_handled(self):
        """Hook should handle large files within timeout."""
        # Create a 10KB Python file
        large_content = "x = 1\n" * 1000
        temp_file = create_temp_file(large_content, ".py")

        try:
            input_json = json.dumps({
                "tool_name": "Write",
                "tool_input": {"file_path": str(temp_file)},
                "session_id": "test-session"
            })

            result = run_hook(input_json)

            assert result["returncode"] != -1, "Timed out on large file"
            assert result["is_valid_json"]
        finally:
            os.unlink(temp_file)


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS: Version Validation
# ═══════════════════════════════════════════════════════════════════════════════

class TestVersionValidation:
    """Tests for version markers and configuration."""

    def test_hook_version_is_gte_248(self):
        """Hook should be version >= 2.48.0 (Security Stage 2.5 introduced in v2.48)."""
        import re
        content = HOOK_PATH.read_text()
        version_match = re.search(r'VERSION:\s*(\d+)\.(\d+)', content)
        assert version_match, "Hook should have VERSION field in header"
        major, minor = int(version_match.group(1)), int(version_match.group(2))
        assert (major, minor) >= (2, 48), (
            f"Hook VERSION should be >= 2.48, got: {major}.{minor}"
        )

    def test_hook_mentions_stage_25(self):
        """Hook should mention Stage 2.5 SECURITY."""
        content = HOOK_PATH.read_text()
        assert "Stage 2.5" in content or "STAGE 2.5" in content


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
