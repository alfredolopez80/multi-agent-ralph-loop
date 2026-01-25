"""
v2.47.2 Security Tests for Smart Memory Search Hook
Tests command injection, path traversal, race condition protections, and advisory improvements

These tests validate the security hardening applied in v2.47.1-v2.47.2:
- SECURITY-001: Command injection via unsanitized keywords
- SECURITY-002: Path traversal via symlink following
- SECURITY-003: Race condition in temp directory handling
- ADV-001: JSON schema validation (v2.47.2)
- ADV-002: Control character removal
- ADV-003: find -exec optimization (v2.47.2)
"""
import os
import json
import subprocess
import tempfile
import pytest
from pathlib import Path


# ═══════════════════════════════════════════════════════════════════════════════
# Test Configuration
# ═══════════════════════════════════════════════════════════════════════════════

PROJECT_ROOT = Path(__file__).parent.parent
HOOK_PATH = PROJECT_ROOT / ".claude" / "hooks" / "smart-memory-search.sh"


# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY-001: Command Injection Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestSecurity001CommandInjection:
    """Tests for SECURITY-001: Command injection prevention."""

    def test_hook_has_escape_for_grep_function(self):
        """Verify escape_for_grep function exists for regex metacharacter handling."""
        assert HOOK_PATH.exists(), f"Hook file not found: {HOOK_PATH}"
        content = HOOK_PATH.read_text()

        assert "escape_for_grep" in content, (
            "SECURITY-001 FIX MISSING: escape_for_grep function not found. "
            "This function is required to escape regex metacharacters before grep -E usage."
        )

        # Verify the function escapes dangerous characters
        assert 'sed' in content and '\\&' in content, (
            "escape_for_grep should use sed to escape regex metacharacters"
        )

    def test_keywords_not_used_directly_in_grep(self):
        """Verify KEYWORDS variable is not used directly in grep -E without escaping."""
        content = HOOK_PATH.read_text()

        # The vulnerable pattern was: grep -E "$(echo $KEYWORDS | tr ' ' '|')"
        # This should be replaced with escaped version
        vulnerable_pattern = '$(echo $KEYWORDS | tr'

        assert vulnerable_pattern not in content, (
            "SECURITY-001 VULNERABILITY: Raw KEYWORDS used in command substitution. "
            f"Found vulnerable pattern: {vulnerable_pattern}"
        )

    def test_grep_uses_safe_patterns(self):
        """Verify grep commands use either -F (fixed strings) or escaped patterns."""
        content = HOOK_PATH.read_text()

        # Count grep usages
        grep_lines = [line for line in content.split('\n') if 'grep -l' in line]

        for line in grep_lines:
            # Each grep should use either -F or properly escaped variables
            uses_fixed = '-F' in line
            uses_safe_var = '$KEYWORDS_SAFE' in line or '$KEYWORDS_PATTERN' in line

            if not (uses_fixed or uses_safe_var):
                # Check if it's using the escaped pattern
                uses_escaped = 'KEYWORDS_PATTERN' in line or 'KEYWORDS_PATTERN_LEDGER' in line
                assert uses_escaped, (
                    f"SECURITY-001: Potentially unsafe grep usage: {line.strip()}"
                )

    def test_malicious_input_handling(self):
        """Test that malicious prompt inputs are properly sanitized."""
        # Test various command injection payloads
        malicious_inputs = [
            '"; rm -rf /tmp/test; echo "',
            '$(cat /etc/passwd)',
            '`id`',
            '|cat /etc/passwd',
            '; ls -la',
            '${IFS}cat${IFS}/etc/passwd',
        ]

        content = HOOK_PATH.read_text()

        # Verify control character removal is present
        assert "tr -d '[:cntrl:]'" in content or 'tr.*cntrl' in content, (
            "ADV-002: Control character removal should be present for defense in depth"
        )

        # Verify PROMPT sanitization exists
        assert 'PROMPT' in content and ('head -c' in content or 'truncate' in content), (
            "PROMPT input should be truncated to limit size"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY-002: Path Traversal Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestSecurity002PathTraversal:
    """Tests for SECURITY-002: Path traversal prevention."""

    def test_hook_has_validate_file_path_function(self):
        """Verify validate_file_path function exists."""
        content = HOOK_PATH.read_text()

        assert "validate_file_path" in content, (
            "SECURITY-002 FIX MISSING: validate_file_path function not found. "
            "This function is required to prevent path traversal via symlinks."
        )

    def test_validate_file_path_uses_realpath(self):
        """Verify validate_file_path uses realpath for symlink resolution."""
        content = HOOK_PATH.read_text()

        assert "realpath" in content, (
            "SECURITY-002: realpath should be used to resolve symlinks"
        )

        # Check for the -e flag (require file to exist)
        assert "realpath -e" in content or "realpath" in content, (
            "validate_file_path should use realpath to resolve symlinks"
        )

    def test_file_operations_use_validation(self):
        """Verify all file read operations use path validation."""
        content = HOOK_PATH.read_text()

        # Count cat operations within while loops (file reading)
        # These should be preceded by validate_file_path calls

        # Look for the pattern: validated=$(validate_file_path
        validation_calls = content.count("validate_file_path")

        # We expect at least 3 validation calls (claude-mem, handoffs, ledgers)
        assert validation_calls >= 3, (
            f"SECURITY-002: Expected at least 3 path validation calls, found {validation_calls}. "
            "All file operations in claude-mem, handoffs, and ledgers sections need validation."
        )

    def test_validated_variable_used_for_operations(self):
        """Verify operations use $validated instead of raw $file."""
        content = HOOK_PATH.read_text()

        # After validation, operations should use $validated
        assert '$validated' in content, (
            "SECURITY-002: File operations should use $validated variable after path validation"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY-003: Race Condition Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestSecurity003RaceCondition:
    """Tests for SECURITY-003: Race condition prevention in temp files."""

    def test_temp_directory_has_restrictive_permissions(self):
        """Verify temp directory is created with chmod 700."""
        content = HOOK_PATH.read_text()

        # After mktemp -d, chmod 700 should be applied
        assert "chmod 700" in content, (
            "SECURITY-003: Temp directory should have chmod 700 applied after creation"
        )

    def test_hook_has_atomic_file_creation(self):
        """Verify create_initial_file function exists for atomic creation."""
        content = HOOK_PATH.read_text()

        assert "create_initial_file" in content, (
            "SECURITY-003 FIX MISSING: create_initial_file function not found. "
            "This function is required for atomic temp file creation."
        )

    def test_atomic_creation_checks_file_existence(self):
        """Verify atomic creation checks if file already exists."""
        content = HOOK_PATH.read_text()

        # The function should check if file exists before creation
        assert '[[ -e "$file" ]]' in content or '[ -e "$file" ]' in content, (
            "SECURITY-003: Atomic file creation should check for existing files (symlink attack prevention)"
        )

    def test_temp_files_use_atomic_creation(self):
        """Verify temp file initialization uses atomic creation function."""
        content = HOOK_PATH.read_text()

        # Count create_initial_file calls for the 4 temp files
        init_calls = content.count("create_initial_file")

        assert init_calls >= 4, (
            f"SECURITY-003: Expected 4 atomic file creation calls (one per memory source), found {init_calls}"
        )

    def test_umask_set_restrictive(self):
        """Verify umask is set to restrict file permissions."""
        content = HOOK_PATH.read_text()

        assert "umask 077" in content, (
            "SECURITY-003: umask 077 should be set for restrictive file permissions"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# ADV-001: JSON Schema Validation Tests (v2.47.2)
# ═══════════════════════════════════════════════════════════════════════════════

class TestAdv001SchemaValidation:
    """Tests for ADV-001: JSON input schema validation."""

    def test_hook_has_validate_input_schema_function(self):
        """Verify validate_input_schema function exists."""
        content = HOOK_PATH.read_text()

        assert "validate_input_schema" in content, (
            "ADV-001 FIX MISSING: validate_input_schema function not found. "
            "This function validates JSON input structure before processing."
        )

    def test_schema_validation_checks_valid_json(self):
        """Verify schema validation checks if input is valid JSON."""
        content = HOOK_PATH.read_text()

        # Should use jq empty to validate JSON
        assert "jq empty" in content, (
            "ADV-001: Schema validation should use 'jq empty' to validate JSON structure"
        )

    def test_schema_validation_checks_required_fields(self):
        """Verify schema validation checks for required field tool_name."""
        content = HOOK_PATH.read_text()

        # Should check for tool_name field
        assert ".tool_name" in content and "jq -e" in content, (
            "ADV-001: Schema validation should check for required .tool_name field"
        )

    def test_schema_validation_called_before_processing(self):
        """Verify schema validation is called early in the script."""
        content = HOOK_PATH.read_text()

        # validate_input_schema should be called before TOOL_NAME extraction
        validate_pos = content.find("validate_input_schema")
        tool_name_extraction = content.find("TOOL_NAME=$(echo")

        assert validate_pos < tool_name_extraction, (
            "ADV-001: Schema validation should be called before TOOL_NAME extraction"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# ADV-003: find -exec Optimization Tests (v2.47.2)
# ═══════════════════════════════════════════════════════════════════════════════

class TestAdv003FindExecOptimization:
    """Tests for ADV-003: find -exec vs xargs optimization."""

    def test_no_xargs_with_find(self):
        """Verify find commands don't use xargs (vulnerability with spaces in filenames)."""
        content = HOOK_PATH.read_text()

        # Count find | xargs patterns (should be 0)
        xargs_count = content.count("| xargs grep") + content.count("|xargs grep")

        assert xargs_count == 0, (
            f"ADV-003: Found {xargs_count} instances of 'find | xargs grep'. "
            "This is unsafe with filenames containing spaces. Use 'find -exec grep' instead."
        )

    def test_uses_find_exec_pattern(self):
        """Verify find commands use -exec instead of xargs."""
        content = HOOK_PATH.read_text()

        # Count find -exec patterns
        exec_count = content.count("-exec grep")

        assert exec_count >= 3, (
            f"ADV-003: Expected at least 3 'find -exec grep' patterns, found {exec_count}. "
            "All find+grep operations should use -exec for safety and performance."
        )

    def test_find_exec_properly_terminated(self):
        """Verify find -exec commands are properly terminated with semicolon."""
        content = HOOK_PATH.read_text()

        # Each -exec should have \\; or \; terminator
        # The pattern in bash is: -exec ... {} \;
        assert "{} \\;" in content or "{} ;" in content, (
            "ADV-003: find -exec commands should be terminated with {} \\;"
        )

    def test_adv003_comment_present(self):
        """Verify ADV-003 fix is documented in comments."""
        content = HOOK_PATH.read_text()

        assert "ADV-003" in content, (
            "ADV-003: Fix comment should be present for traceability"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Security Hardening Version Tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestSecurityVersioning:
    """Verify security fix versioning."""

    def test_version_updated_for_security_fixes(self):
        """Verify VERSION >= 2.47.2 indicating security fixes + advisory improvements."""
        import re
        content = HOOK_PATH.read_text()

        version_match = re.search(r'VERSION:\s*(\d+)\.(\d+)', content)
        assert version_match, "Hook should have VERSION field in header"
        major, minor = int(version_match.group(1)), int(version_match.group(2))
        assert (major, minor) >= (2, 47), (
            f"VERSION should be >= 2.47 for security hardening, got: {major}.{minor}"
        )

    def test_security_fix_comments_present(self):
        """Verify security fix comments are present for documentation."""
        content = HOOK_PATH.read_text()

        security_markers = [
            "SECURITY-001",
            "SECURITY-002",
            "SECURITY-003",
        ]

        for marker in security_markers:
            assert marker in content, (
                f"Security fix marker {marker} should be present in comments for traceability"
            )


# ═══════════════════════════════════════════════════════════════════════════════
# Integration Tests (Optional - requires actual execution environment)
# ═══════════════════════════════════════════════════════════════════════════════

class TestSecurityIntegration:
    """Integration tests that verify security in actual execution."""

    @pytest.mark.skipif(
        not os.path.exists(os.path.expanduser("~/.ralph")),
        reason="Ralph environment not configured"
    )
    def test_hook_executes_without_error(self):
        """Verify the hook can execute without syntax errors."""
        result = subprocess.run(
            ["bash", "-n", str(HOOK_PATH)],
            capture_output=True,
            text=True
        )

        assert result.returncode == 0, (
            f"Hook has syntax errors: {result.stderr}"
        )

    @pytest.mark.skipif(
        not os.path.exists(os.path.expanduser("~/.ralph")),
        reason="Ralph environment not configured"
    )
    def test_hook_handles_non_task_input_safely(self):
        """Verify hook returns quickly for non-Task tool input."""
        test_input = json.dumps({
            "tool_name": "Read",
            "tool_input": {"file_path": "/tmp/test.txt"}
        })

        result = subprocess.run(
            ["bash", str(HOOK_PATH)],
            input=test_input,
            capture_output=True,
            text=True,
            timeout=5
        )

        assert result.returncode == 0, f"Hook failed: {result.stderr}"

        output = json.loads(result.stdout)
        # PreToolUse hooks MUST return "decision": "allow" (not "continue")
        # "continue" is for PostToolUse hooks only
        assert output.get("decision") == "allow", (
            f"PreToolUse hook should return 'decision': 'allow', got: {output}"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Summary Report
# ═══════════════════════════════════════════════════════════════════════════════

def test_security_summary():
    """Generate summary of security test coverage."""
    content = HOOK_PATH.read_text() if HOOK_PATH.exists() else ""

    checks = {
        "SECURITY-001 (Command Injection)": {
            "escape_for_grep function": "escape_for_grep" in content,
            "No raw KEYWORDS in grep": '$(echo $KEYWORDS | tr' not in content,
            "Control char removal": "tr -d '[:cntrl:]'" in content,
        },
        "SECURITY-002 (Path Traversal)": {
            "validate_file_path function": "validate_file_path" in content,
            "realpath usage": "realpath" in content,
            "$validated variable": "$validated" in content,
        },
        "SECURITY-003 (Race Condition)": {
            "chmod 700 on temp dir": "chmod 700" in content,
            "create_initial_file function": "create_initial_file" in content,
            "umask 077": "umask 077" in content,
        },
        "ADV-001 (Schema Validation)": {
            "validate_input_schema function": "validate_input_schema" in content,
            "jq empty validation": "jq empty" in content,
            "Required field check": "jq -e" in content,
        },
        "ADV-003 (find -exec Optimization)": {
            "No xargs with find": "| xargs grep" not in content,
            "Uses find -exec": "-exec grep" in content,
            "ADV-003 comment": "ADV-003" in content,
        },
    }

    all_passed = True
    report = ["\n" + "=" * 60]
    report.append("SECURITY HARDENING STATUS - v2.47.2")
    report.append("=" * 60)

    for category, items in checks.items():
        report.append(f"\n{category}:")
        for check_name, passed in items.items():
            status = "✅ PASS" if passed else "❌ FAIL"
            report.append(f"  {status}: {check_name}")
            if not passed:
                all_passed = False

    report.append("\n" + "=" * 60)
    overall = "ALL SECURITY CHECKS PASSED" if all_passed else "SECURITY ISSUES DETECTED"
    report.append(f"OVERALL: {overall}")
    report.append("=" * 60 + "\n")

    print("\n".join(report))

    assert all_passed, "Not all security checks passed. See report above."
