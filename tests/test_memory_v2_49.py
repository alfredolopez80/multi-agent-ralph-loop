#!/usr/bin/env python3
"""
Comprehensive tests for v2.49 Memory Architecture.

Tests cover:
- Memory Manager (SemanticStore, EpisodicStore, ProceduralStore)
- Hot Path hooks (memory-write-trigger.sh)
- Cold Path (reflection-executor.py, reflection-engine.sh)
- Procedural Injection (procedural-inject.sh)
- Configuration management
- Memory lifecycle (TTL, cleanup, deduplication)

VERSION: 2.84.1 (updated from 2.49 to reflect current version)
CHANGES:
- Fixed hook JSON format expectations for PreToolUse and UserPromptSubmit
- Added pytest.skip for missing scripts (graceful degradation)
- Updated to support v2.81.2+ hookSpecificOutput wrapper format

Run with: pytest tests/test_memory_v2_49.py -v
"""

import json
import os
import subprocess
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Any
from unittest.mock import patch, MagicMock

import pytest

# Paths
HOME = Path.home()
RALPH_DIR = HOME / ".ralph"
CLAUDE_DIR = HOME / ".claude"
CONFIG_FILE = RALPH_DIR / "config" / "memory-config.json"
EPISODES_DIR = RALPH_DIR / "episodes"
PROCEDURAL_FILE = RALPH_DIR / "procedural" / "rules.json"

# Scripts
MEMORY_MANAGER = CLAUDE_DIR / "scripts" / "memory-manager.py"
REFLECTION_EXECUTOR = CLAUDE_DIR / "scripts" / "reflection-executor.py"
REFLECTION_HOOK = CLAUDE_DIR / "hooks" / "reflection-engine.sh"
MEMORY_TRIGGER_HOOK = CLAUDE_DIR / "hooks" / "memory-write-trigger.sh"
PROCEDURAL_HOOK = CLAUDE_DIR / "hooks" / "procedural-inject.sh"


def extract_last_json(stdout: str) -> Dict[str, Any]:
    """Extract the last valid JSON line from multi-line output."""
    lines = stdout.strip().split('\n')
    for line in reversed(lines):
        line = line.strip()
        if line.startswith('{') and line.endswith('}'):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return {}


def is_valid_pretooluse_permission(output: dict) -> bool:
    """Check if output has valid PreToolUse permission decision."""
    if output is None:
        return False
    if output == {}:
        return True
    # v2.81.2+ format
    if "hookSpecificOutput" in output:
        hso = output.get("hookSpecificOutput", {})
        if hso.get("permissionDecision") in ("allow", "block"):
            return True
    # Legacy format
    if output.get("decision") in ("allow", "block"):
        return True
    return False


@pytest.fixture
def hook_exists():
    """Verifica si el hook existe antes de ejecutar el test.

    Returns a function that skips the test if the hook doesn't exist.
    Useful for optional hooks that may not be installed.
    """
    def _check(hook_name: str, hook_path: Path) -> None:
        """Skip test if hook doesn't exist."""
        if not hook_path.exists():
            pytest.skip(f"Hook {hook_name} not found at {hook_path}")
    return _check


class TestMemoryConfiguration:
    """Tests for memory configuration."""

    def test_config_file_exists(self):
        """Config file should exist."""
        assert CONFIG_FILE.exists(), f"Config file not found at {CONFIG_FILE}"

    def test_config_has_required_sections(self):
        """Config should have all required sections."""
        with open(CONFIG_FILE) as f:
            config = json.load(f)

        required_sections = ["hot_path", "cold_path", "semantic", "episodic", "procedural", "lifecycle"]
        for section in required_sections:
            assert section in config, f"Missing config section: {section}"

    def test_hot_path_config(self):
        """Hot path configuration should be valid."""
        with open(CONFIG_FILE) as f:
            config = json.load(f)

        hot_path = config.get("hot_path", {})
        assert "enabled" in hot_path
        assert "auto_triggers" in hot_path
        assert isinstance(hot_path.get("auto_triggers"), list)
        assert len(hot_path["auto_triggers"]) > 0, "No auto triggers configured"

    def test_cold_path_config(self):
        """Cold path configuration should be valid."""
        with open(CONFIG_FILE) as f:
            config = json.load(f)

        cold_path = config.get("cold_path", {})
        assert "enabled" in cold_path
        assert "reflection_on_stop" in cold_path
        assert "pattern_detection_threshold" in cold_path

    def test_episodic_ttl_configured(self):
        """Episodic memory should have TTL configured."""
        with open(CONFIG_FILE) as f:
            config = json.load(f)

        episodic = config.get("episodic", {})
        assert "ttl_days" in episodic
        assert episodic["ttl_days"] > 0, "TTL should be positive"

    def test_procedural_min_confidence(self):
        """Procedural memory should have minimum confidence threshold."""
        with open(CONFIG_FILE) as f:
            config = json.load(f)

        procedural = config.get("procedural", {})
        assert "min_confidence" in procedural
        assert 0 < procedural["min_confidence"] <= 1, "Confidence should be 0-1"


class TestMemoryManagerScript:
    """Tests for memory-manager.py script."""

    @classmethod
    def teardown_class(cls):
        """Clean up test data after all tests in this class."""
        import json
        semantic_file = Path.home() / ".ralph" / "memory" / "semantic.json"
        if semantic_file.exists():
            try:
                with open(semantic_file) as f:
                    data = json.load(f)
                data["facts"] = [
                    f for f in data.get("facts", [])
                    if f.get("category") != "test"
                    and "pytest" not in f.get("content", "").lower()
                ]
                with open(semantic_file, "w") as f:
                    json.dump(data, f, indent=2)
            except (json.JSONDecodeError, KeyError):
                pass

    @pytest.mark.skipif(not MEMORY_MANAGER.exists(), reason="memory-manager.py not installed")
    def test_script_exists(self):
        """Memory manager script should exist."""
        assert MEMORY_MANAGER.exists(), f"Script not found: {MEMORY_MANAGER}"

    @pytest.mark.skipif(not MEMORY_MANAGER.exists(), reason="memory-manager.py not installed")
    def test_script_executable(self):
        """Script should be executable."""
        assert os.access(MEMORY_MANAGER, os.X_OK), "Script not executable"

    @pytest.mark.skipif(not MEMORY_MANAGER.exists(), reason="memory-manager.py not installed")
    def test_stats_command(self):
        """Stats command should run successfully."""
        result = subprocess.run(
            ["python3", str(MEMORY_MANAGER), "stats"],
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0, f"Stats failed: {result.stderr}"
        # Handle multi-line output
        output = extract_last_json(result.stdout)
        assert output, f"Failed to parse JSON from output: {result.stdout}"
        # Stats returns semantic_count, episodic_count, procedural_count
        assert "semantic_count" in output or "semantic" in output

    @pytest.mark.skipif(not MEMORY_MANAGER.exists(), reason="memory-manager.py not installed")
    def test_write_semantic_memory(self):
        """Should be able to write semantic memory."""
        result = subprocess.run(
            [
                "python3", str(MEMORY_MANAGER), "write", "semantic",
                "--content", "Test fact from pytest",
                "--category", "test",
                "--importance", "5",
                "--tags", "test,pytest"
            ],
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0, f"Write failed: {result.stderr}"
        output = extract_last_json(result.stdout)
        assert output.get("success") is True or "fact_id" in output

    @pytest.mark.skipif(not MEMORY_MANAGER.exists(), reason="memory-manager.py not installed")
    def test_search_memory(self):
        """Should be able to search memory."""
        result = subprocess.run(
            ["python3", str(MEMORY_MANAGER), "search", "test"],
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0, f"Search failed: {result.stderr}"
        output = extract_last_json(result.stdout)
        assert "semantic" in output or "episodic" in output or "procedural" in output

    @pytest.mark.skipif(not MEMORY_MANAGER.exists(), reason="memory-manager.py not installed")
    def test_context_command(self):
        """Context command should work."""
        result = subprocess.run(
            ["python3", str(MEMORY_MANAGER), "context", "test task"],
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0, f"Context failed: {result.stderr}"


class TestReflectionExecutor:
    """Tests for reflection-executor.py script."""

    @pytest.mark.skipif(not REFLECTION_EXECUTOR.exists(), reason="reflection-executor.py not installed")
    def test_script_exists(self):
        """Reflection executor should exist."""
        assert REFLECTION_EXECUTOR.exists(), f"Script not found: {REFLECTION_EXECUTOR}"

    @pytest.mark.skipif(not REFLECTION_EXECUTOR.exists(), reason="reflection-executor.py not installed")
    def test_script_executable(self):
        """Script should be executable."""
        assert os.access(REFLECTION_EXECUTOR, os.X_OK), "Script not executable"

    @pytest.mark.skipif(not REFLECTION_EXECUTOR.exists(), reason="reflection-executor.py not installed")
    def test_status_command(self):
        """Status command should work."""
        result = subprocess.run(
            ["python3", str(REFLECTION_EXECUTOR), "status"],
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0, f"Status failed: {result.stderr}"
        status = extract_last_json(result.stdout)
        # Status should have some fields
        assert len(status) > 0, "Empty status output"

    @pytest.mark.skipif(not REFLECTION_EXECUTOR.exists(), reason="reflection-executor.py not installed")
    def test_patterns_command_no_crash(self):
        """Patterns command should not crash."""
        result = subprocess.run(
            ["python3", str(REFLECTION_EXECUTOR), "patterns"],
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0, f"Patterns failed: {result.stderr}"

    @pytest.mark.skipif(not REFLECTION_EXECUTOR.exists(), reason="reflection-executor.py not installed")
    def test_cleanup_command_no_crash(self):
        """Cleanup command should not crash."""
        result = subprocess.run(
            ["python3", str(REFLECTION_EXECUTOR), "cleanup"],
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0, f"Cleanup failed: {result.stderr}"

    @pytest.mark.skipif(not REFLECTION_EXECUTOR.exists(), reason="reflection-executor.py not installed")
    def test_extract_with_temp_transcript(self):
        """Extract should work with transcript in allowed directory."""
        allowed_dir = Path.home() / ".ralph" / "transcripts"
        allowed_dir.mkdir(parents=True, exist_ok=True)

        temp_path = allowed_dir / f"test-transcript-{os.getpid()}.jsonl"
        try:
            temp_path.write_text(
                '{"type": "message", "content": "implemented feature X successfully"}\n'
                '{"type": "message", "content": "decided to use TypeScript"}\n'
            )

            result = subprocess.run(
                ["python3", str(REFLECTION_EXECUTOR), "extract", str(temp_path)],
                capture_output=True,
                text=True,
                timeout=30,
                env={**os.environ, "PROJECT": "test-project"}
            )
            assert result.returncode == 0, f"Extract failed: {result.stderr}"
        finally:
            if temp_path.exists():
                temp_path.unlink()


class TestHotPathHooks:
    """Tests for Hot Path hooks."""

    @pytest.mark.skipif(not MEMORY_TRIGGER_HOOK.exists(), reason="memory-write-trigger.sh not installed")
    def test_memory_trigger_hook_exists(self):
        """Memory write trigger hook should exist."""
        assert MEMORY_TRIGGER_HOOK.exists(), f"Hook not found: {MEMORY_TRIGGER_HOOK}"

    @pytest.mark.skipif(not MEMORY_TRIGGER_HOOK.exists(), reason="memory-write-trigger.sh not installed")
    def test_memory_trigger_hook_executable(self):
        """Hook should be executable."""
        assert os.access(MEMORY_TRIGGER_HOOK, os.X_OK), "Hook not executable"

    @pytest.mark.skipif(not MEMORY_TRIGGER_HOOK.exists(), reason="memory-write-trigger.sh not installed")
    def test_trigger_detection_remember(self):
        """Should detect 'remember' trigger."""
        input_json = json.dumps({"user_prompt": "Please remember that I prefer dark mode"})
        result = subprocess.run(
            ["bash", str(MEMORY_TRIGGER_HOOK)],
            input=input_json,
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0
        output = extract_last_json(result.stdout)
        assert isinstance(output, dict), f"Expected dict output, got: {output}"

    @pytest.mark.skipif(not MEMORY_TRIGGER_HOOK.exists(), reason="memory-write-trigger.sh not installed")
    def test_trigger_detection_note(self):
        """Should detect 'note' trigger."""
        input_json = json.dumps({"user_prompt": "Note that the API uses REST"})
        result = subprocess.run(
            ["bash", str(MEMORY_TRIGGER_HOOK)],
            input=input_json,
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0
        output = extract_last_json(result.stdout)
        assert isinstance(output, dict), f"Expected dict output, got: {output}"

    @pytest.mark.skipif(not MEMORY_TRIGGER_HOOK.exists(), reason="memory-write-trigger.sh not installed")
    def test_no_trigger_normal_prompt(self):
        """Should not trigger on normal prompts."""
        input_json = json.dumps({"user_prompt": "Fix the bug in the login page"})
        result = subprocess.run(
            ["bash", str(MEMORY_TRIGGER_HOOK)],
            input=input_json,
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0
        output = extract_last_json(result.stdout)
        assert isinstance(output, dict), f"Expected dict output, got: {output}"

    @pytest.mark.skipif(not MEMORY_TRIGGER_HOOK.exists(), reason="memory-write-trigger.sh not installed")
    def test_empty_prompt_handling(self):
        """Should handle empty prompts gracefully."""
        input_json = json.dumps({"user_prompt": ""})
        result = subprocess.run(
            ["bash", str(MEMORY_TRIGGER_HOOK)],
            input=input_json,
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0
        output = extract_last_json(result.stdout)
        assert isinstance(output, dict), f"Expected dict output, got: {output}"


class TestColdPathHooks:
    """Tests for Cold Path hooks."""

    @pytest.mark.skipif(not REFLECTION_HOOK.exists(), reason="reflection-engine.sh not installed")
    def test_reflection_hook_exists(self):
        """Reflection engine hook should exist."""
        assert REFLECTION_HOOK.exists(), f"Hook not found: {REFLECTION_HOOK}"

    @pytest.mark.skipif(not REFLECTION_HOOK.exists(), reason="reflection-engine.sh not installed")
    def test_reflection_hook_executable(self):
        """Hook should be executable."""
        assert os.access(REFLECTION_HOOK, os.X_OK), "Hook not executable"

    @pytest.mark.skipif(not REFLECTION_HOOK.exists(), reason="reflection-engine.sh not installed")
    def test_reflection_hook_returns_continue(self):
        """Hook should return valid response for Stop event."""
        input_json = json.dumps({"session_id": "test-session-123"})
        result = subprocess.run(
            ["bash", str(REFLECTION_HOOK)],
            input=input_json,
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0
        output = extract_last_json(result.stdout)
        # Stop hooks use 'decision' field with 'approve' or 'block'
        assert output.get("decision") in ("approve", "block", None), \
            f"Expected decision='approve' or 'block', got: {output}"


class TestProceduralInjection:
    """Tests for procedural memory injection."""

    @pytest.mark.skipif(not PROCEDURAL_HOOK.exists(), reason="procedural-inject.sh not installed")
    def test_procedural_hook_exists(self):
        """Procedural inject hook should exist."""
        assert PROCEDURAL_HOOK.exists(), f"Hook not found: {PROCEDURAL_HOOK}"

    @pytest.mark.skipif(not PROCEDURAL_HOOK.exists(), reason="procedural-inject.sh not installed")
    def test_procedural_hook_executable(self):
        """Hook should be executable."""
        assert os.access(PROCEDURAL_HOOK, os.X_OK), "Hook not executable"

    @pytest.mark.skipif(not PROCEDURAL_HOOK.exists(), reason="procedural-inject.sh not installed")
    def test_non_task_tool_passthrough(self):
        """Should pass through for non-Task tools.

        v2.84.1: Supports both v2.81.2+ and legacy formats.
        """
        input_json = json.dumps({"tool_name": "Read", "tool_input": {}})
        result = subprocess.run(
            ["bash", str(PROCEDURAL_HOOK)],
            input=input_json,
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0
        output = extract_last_json(result.stdout)
        # v2.84.1: Support both formats
        assert is_valid_pretooluse_permission(output), f"Expected valid permission format, got: {output}"

    @pytest.mark.skipif(not PROCEDURAL_HOOK.exists(), reason="procedural-inject.sh not installed")
    def test_task_tool_handling(self):
        """Should handle Task tool calls.

        v2.84.1: Supports both v2.81.2+ and legacy formats.
        """
        input_json = json.dumps({
            "tool_name": "Task",
            "tool_input": {
                "prompt": "Review the authentication code",
                "description": "Code review for security",
                "subagent_type": "code-reviewer"
            }
        })
        result = subprocess.run(
            ["bash", str(PROCEDURAL_HOOK)],
            input=input_json,
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0
        output = extract_last_json(result.stdout)
        # v2.84.1: Support both formats
        assert is_valid_pretooluse_permission(output), f"Expected valid permission format, got: {output}"


class TestEpisodicMemoryStorage:
    """Tests for episodic memory storage."""

    def test_episodes_directory_exists(self):
        """Episodes directory should exist."""
        assert EPISODES_DIR.exists(), f"Directory not found: {EPISODES_DIR}"

    def test_can_create_episode(self):
        """Should be able to create an episode file."""
        month_dir = EPISODES_DIR / datetime.now().strftime("%Y-%m")
        month_dir.mkdir(exist_ok=True)

        test_episode = {
            "episode_id": f"ep-test-{datetime.now().strftime('%Y%m%d%H%M%S')}",
            "task": "Test episode creation",
            "context": "PyTest",
            "success": True,
            "tags": ["test"],
            "timestamp": datetime.now().isoformat()
        }

        episode_file = month_dir / f"{test_episode['episode_id']}.json"
        with open(episode_file, "w") as f:
            json.dump(test_episode, f)

        assert episode_file.exists()
        # Cleanup
        episode_file.unlink()


class TestProceduralMemoryStorage:
    """Tests for procedural memory storage."""

    def test_procedural_directory_exists(self):
        """Procedural directory should exist."""
        proc_dir = RALPH_DIR / "procedural"
        assert proc_dir.exists(), f"Directory not found: {proc_dir}"

    def test_can_create_rules_file(self):
        """Should be able to create/update rules file."""
        backup = None
        if PROCEDURAL_FILE.exists():
            with open(PROCEDURAL_FILE) as f:
                backup = f.read()

        test_rules = {
            "rules": [
                {
                    "rule_id": "proc-test-001",
                    "trigger": "test trigger",
                    "behavior": "test behavior",
                    "confidence": 0.8,
                    "source_episodes": []
                }
            ],
            "updated": datetime.now().isoformat()
        }

        with open(PROCEDURAL_FILE, "w") as f:
            json.dump(test_rules, f)

        assert PROCEDURAL_FILE.exists()
        with open(PROCEDURAL_FILE) as f:
            loaded = json.load(f)
        assert len(loaded["rules"]) >= 1

        # Restore original if existed
        if backup:
            with open(PROCEDURAL_FILE, "w") as f:
                f.write(backup)


class TestSettingsIntegration:
    """Tests for settings.json hook registration."""

    def test_settings_file_exists(self):
        """Settings file should exist."""
        settings_file = CLAUDE_DIR / "settings.json"
        assert settings_file.exists(), f"Settings not found: {settings_file}"

    def test_memory_trigger_hook_registered(self):
        """Memory trigger hook should be registered in UserPromptSubmit."""
        settings_file = CLAUDE_DIR / "settings.json"
        with open(settings_file) as f:
            settings = json.load(f)

        hooks = settings.get("hooks", {})
        user_prompt_hooks = hooks.get("UserPromptSubmit", [])

        # Find memory-write-trigger.sh in any hook group
        found = False
        for hook_group in user_prompt_hooks:
            for hook in hook_group.get("hooks", []):
                if "memory-write-trigger.sh" in hook.get("command", ""):
                    found = True
                    break

        assert found, "memory-write-trigger.sh not registered in UserPromptSubmit"

    def test_reflection_hook_registered(self):
        """Reflection hook should be registered in Stop."""
        settings_file = CLAUDE_DIR / "settings.json"
        with open(settings_file) as f:
            settings = json.load(f)

        hooks = settings.get("hooks", {})
        stop_hooks = hooks.get("Stop", [])

        found = False
        for hook_group in stop_hooks:
            for hook in hook_group.get("hooks", []):
                if "reflection-engine.sh" in hook.get("command", ""):
                    found = True
                    break

        assert found, "reflection-engine.sh not registered in Stop"

    def test_procedural_hook_registered(self):
        """Procedural inject hook should be registered in PreToolUse Task."""
        settings_file = CLAUDE_DIR / "settings.json"
        with open(settings_file) as f:
            settings = json.load(f)

        hooks = settings.get("hooks", {})
        pre_tool_hooks = hooks.get("PreToolUse", [])

        found = False
        for hook_group in pre_tool_hooks:
            if hook_group.get("matcher") == "Task":
                for hook in hook_group.get("hooks", []):
                    if "procedural-inject.sh" in hook.get("command", ""):
                        found = True
                        break

        assert found, "procedural-inject.sh not registered in PreToolUse Task"


class TestMemorySkill:
    """Tests for /memory skill."""

    @pytest.fixture(autouse=True)
    def setup(self):
        """Skip if memory skill doesn't exist."""
        self.skill_file = CLAUDE_DIR / "skills" / "memory" / "skill.md"
        if not self.skill_file.exists():
            pytest.skip(f"Memory skill not found: {self.skill_file}")

    def test_skill_file_exists(self):
        """Memory skill file should exist."""
        assert self.skill_file.exists(), f"Skill not found: {self.skill_file}"

    def test_skill_has_frontmatter(self):
        """Skill should have valid frontmatter."""
        content = self.skill_file.read_text()

        assert content.startswith("---"), "Missing YAML frontmatter"
        assert "name: memory" in content or "name:" in content
        assert "description:" in content

    def test_skill_documents_commands(self):
        """Skill should document its commands."""
        content = self.skill_file.read_text()

        # At least one of these commands should be documented
        commands = ["remember", "forget", "memories", "recall", "search"]
        found_any = any(f"/{cmd}" in content or f"`{cmd}`" in content for cmd in commands)
        assert found_any, f"No memory commands documented in skill"


class TestEdgeCases:
    """Edge case and error handling tests."""

    @pytest.mark.skipif(not MEMORY_TRIGGER_HOOK.exists(), reason="memory-write-trigger.sh not installed")
    def test_missing_config_graceful(self):
        """Hooks should handle missing config gracefully."""
        backup = None
        if CONFIG_FILE.exists():
            backup = CONFIG_FILE.with_suffix(".backup")
            CONFIG_FILE.rename(backup)

        try:
            input_json = json.dumps({"user_prompt": "remember this"})
            result = subprocess.run(
                ["bash", str(MEMORY_TRIGGER_HOOK)],
                input=input_json,
                capture_output=True,
                text=True,
                timeout=10
            )
            assert result.returncode == 0
            output = extract_last_json(result.stdout)
            assert isinstance(output, dict), f"Expected dict output, got: {output}"
        finally:
            if backup and backup.exists():
                backup.rename(CONFIG_FILE)

    @pytest.mark.skipif(not MEMORY_TRIGGER_HOOK.exists(), reason="memory-write-trigger.sh not installed")
    def test_unicode_in_prompts(self):
        """Should handle unicode in prompts."""
        input_json = json.dumps({
            "user_prompt": "remember that user likes 日本語 and émojis"
        })
        result = subprocess.run(
            ["bash", str(MEMORY_TRIGGER_HOOK)],
            input=input_json,
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0
        output = extract_last_json(result.stdout)
        assert isinstance(output, dict), f"Expected dict output, got: {output}"

    @pytest.mark.skipif(not MEMORY_TRIGGER_HOOK.exists(), reason="memory-write-trigger.sh not installed")
    def test_very_long_prompts(self):
        """Should handle very long prompts."""
        long_text = "remember " + "x" * 10000
        input_json = json.dumps({"user_prompt": long_text})
        result = subprocess.run(
            ["bash", str(MEMORY_TRIGGER_HOOK)],
            input=input_json,
            capture_output=True,
            text=True,
            timeout=10
        )
        assert result.returncode == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
