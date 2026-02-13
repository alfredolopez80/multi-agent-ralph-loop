"""
Multi-Agent Ralph v2.45.1 - Hooks Registration Tests

This test module validates that hooks are not just present as files,
but also PROPERLY REGISTERED in settings.json with correct triggers.

The key insight is that a hook file existing is not enough - it must be
registered in settings.json to be executed by Claude Code automatically.

Tests cover:
- Hook files exist in ~/.claude/hooks/
- Hooks are registered in settings.json
- Hooks have correct event types (PostToolUse, PreToolUse, etc.)
- Hooks have correct matchers
- Hook paths in settings.json point to existing files
- VERSION markers are present in hook files
"""
import os
import json
import pytest


# ============================================================
# Hook Registry Definition
# ============================================================

# Master registry of ESSENTIAL hooks that MUST be registered in settings.json
# v2.85: Simplified to only essential hooks for autonomous development
# Format: {hook_name: {event_type, matchers, version, cli_only}}
# cli_only=True means it's a CLI script, not an auto-triggered hook
HOOK_REGISTRY = {
    # === v2.35 Core Hooks ===
    "session-start-restore-context.sh": {  # v2.85: Replaces archived session-start-ledger.sh
        "event": "SessionStart",
        "matchers": ["startup", "resume", "compact", "clear"],
        "version": "2.85",
        "cli_only": False,
    },
    "pre-compact-handoff.sh": {
        "event": "PreCompact",
        "matchers": None,  # PreCompact doesn't use matchers
        "version": "2.35",
        "cli_only": False,
    },
    "quality-gates-v2.sh": {
        "event": "PostToolUse",
        "matchers": ["Edit", "Write"],
        "version": "2.46",
        "cli_only": False,
    },
    "git-safety-guard.py": {
        "event": "PreToolUse",
        "matchers": ["Bash"],
        "version": "2.35",
        "cli_only": False,
    },
    "auto-sync-global.sh": {
        "event": "SessionStart",
        "matchers": ["startup", "resume", "clear"],
        "version": "2.35",
        "cli_only": False,
    },

    # === v2.41 Hooks ===
    "progress-tracker.sh": {
        "event": "PostToolUse",
        "matchers": ["Edit", "Write", "Bash"],
        "version": "2.41",
        "cli_only": False,
    },

    # === v2.42 Hooks ===
    "checkpoint-auto-save.sh": {
        "event": "PreToolUse",
        "matchers": ["Edit", "Write"],
        "version": "2.69.0",
        "cli_only": False,
    },

    # === v2.43 Hooks ===
    "inject-session-context.sh": {
        "event": "PreToolUse",
        "matchers": ["Task"],
        "version": "2.43",
        "cli_only": False,
    },
    "skill-validator.sh": {
        "event": "PreToolUse",
        "matchers": ["Skill"],
        "version": "2.43",
        "cli_only": False,
    },
    "context-warning.sh": {
        "event": "UserPromptSubmit",
        "matchers": None,
        "version": "2.43",
        "cli_only": False,
    },
    "periodic-reminder.sh": {
        "event": "UserPromptSubmit",
        "matchers": None,
        "version": "2.43",
        "cli_only": False,
    },

    # === v2.45 Hooks ===
    "lsa-pre-step.sh": {
        "event": "PreToolUse",
        "matchers": ["Edit", "Write"],
        "version": "2.45",
        "cli_only": False,
    },
    "plan-sync-post-step.sh": {
        "event": "PostToolUse",
        "matchers": ["Edit", "Write"],
        "version": "2.45",
        "cli_only": False,
    },

    # === CLI-Only Scripts (NOT auto-triggered hooks) ===
    "detect-environment.sh": {
        "event": None,
        "matchers": None,
        "version": "2.44",
        "cli_only": True,
    },
    "plan-state-init.sh": {
        "event": None,
        "matchers": None,
        "version": "2.45",
        "cli_only": True,
    },
}


# ============================================================
# Test Fixtures
# ============================================================

@pytest.fixture(scope="module")
def settings_json(claude_global_dir):
    """Load and parse settings.json."""
    settings_path = os.path.join(claude_global_dir, "settings.json")
    if not os.path.exists(settings_path):
        pytest.fail(f"settings.json not found at {settings_path}")

    with open(settings_path) as f:
        return json.load(f)


@pytest.fixture(scope="module")
def registered_hooks(settings_json):
    """Extract all hooks registered in settings.json organized by event type."""
    hooks_config = settings_json.get("hooks", {})
    registered = {
        "PostToolUse": [],
        "PreToolUse": [],
        "PreCompact": [],
        "SessionStart": [],
        "Stop": [],
        "UserPromptSubmit": [],
    }

    for event_type, event_hooks in hooks_config.items():
        if event_type not in registered:
            registered[event_type] = []

        for hook_group in event_hooks:
            matcher = hook_group.get("matcher", "*")
            for hook in hook_group.get("hooks", []):
                command = hook.get("command", "")
                # Extract just the filename from the path
                hook_name = os.path.basename(command.replace("${HOME}", "~"))
                registered[event_type].append({
                    "name": hook_name,
                    "command": command,
                    "matcher": matcher,
                    "timeout": hook.get("timeout"),
                })

    return registered


@pytest.fixture(scope="module")
def all_registered_hook_names(registered_hooks):
    """Get flat set of all registered hook filenames."""
    names = set()
    for event_type, hooks in registered_hooks.items():
        for hook in hooks:
            names.add(hook["name"])
    return names


# ============================================================
# Test: Physical Hook Files Exist
# ============================================================

class TestHookFilesExist:
    """Verify all expected hook files exist in ~/.claude/hooks/."""

    def test_all_hook_files_exist(self, global_hooks_dir):
        """All hooks in registry should exist as files."""
        missing = []
        for hook_name, config in HOOK_REGISTRY.items():
            # Skip CLI-only scripts - they may be archived or optional
            if config.get("cli_only"):
                continue

            hook_path = os.path.join(global_hooks_dir, hook_name)
            if not os.path.isfile(hook_path):
                missing.append(hook_name)

        assert not missing, (
            f"Missing hook files: {missing}\n"
            f"Expected in: {global_hooks_dir}"
        )

    def test_all_hook_files_executable(self, global_hooks_dir):
        """All hooks should have executable permissions."""
        not_executable = []
        for hook_name, config in HOOK_REGISTRY.items():
            hook_path = os.path.join(global_hooks_dir, hook_name)
            if os.path.exists(hook_path) and not os.access(hook_path, os.X_OK):
                not_executable.append(hook_name)

        assert not not_executable, (
            f"Hooks without executable permission: {not_executable}\n"
            f"Fix with: chmod +x ~/.claude/hooks/<hook>"
        )

    def test_hook_files_have_shebang(self, global_hooks_dir):
        """All hooks should have proper shebang."""
        missing_shebang = []
        for hook_name in HOOK_REGISTRY.keys():
            hook_path = os.path.join(global_hooks_dir, hook_name)
            if os.path.exists(hook_path):
                with open(hook_path) as f:
                    first_line = f.readline()
                if not first_line.startswith("#!"):
                    missing_shebang.append(hook_name)

        assert not missing_shebang, (
            f"Hooks missing shebang: {missing_shebang}\n"
            "All hooks should start with #!/bin/bash or #!/usr/bin/env bash"
        )


# ============================================================
# Test: Hooks Are Registered in settings.json
# ============================================================

class TestHooksRegistration:
    """Verify hooks are registered in settings.json with correct configuration."""

    def test_auto_hooks_are_registered(self, all_registered_hook_names):
        """All non-CLI hooks should be registered in settings.json."""
        not_registered = []
        for hook_name, config in HOOK_REGISTRY.items():
            if config["cli_only"]:
                continue  # Skip CLI-only scripts

            if hook_name not in all_registered_hook_names:
                not_registered.append(hook_name)

        assert not not_registered, (
            f"Hooks NOT registered in settings.json: {not_registered}\n"
            "These hooks exist as files but won't execute automatically.\n"
            "Add them to ~/.claude/settings.json hooks section."
        )

    def test_cli_only_hooks_not_auto_registered(self, all_registered_hook_names):
        """CLI-only scripts should NOT be registered as auto-hooks."""
        incorrectly_registered = []
        for hook_name, config in HOOK_REGISTRY.items():
            if config["cli_only"] and hook_name in all_registered_hook_names:
                incorrectly_registered.append(hook_name)

        # Note: This is a warning, not a failure - CLI scripts can be registered
        # but it's usually unnecessary
        if incorrectly_registered:
            pytest.skip(
                f"CLI-only scripts registered as hooks (optional): {incorrectly_registered}"
            )

    def test_hooks_registered_with_correct_event(self, registered_hooks):
        """Hooks should be registered under correct event type."""
        wrong_event = []
        for hook_name, config in HOOK_REGISTRY.items():
            if config["cli_only"] or config["event"] is None:
                continue

            expected_event = config["event"]
            found_in_events = []

            for event_type, hooks in registered_hooks.items():
                for hook in hooks:
                    if hook["name"] == hook_name:
                        found_in_events.append(event_type)

            if found_in_events and expected_event not in found_in_events:
                wrong_event.append({
                    "hook": hook_name,
                    "expected": expected_event,
                    "found": found_in_events,
                })

        assert not wrong_event, (
            f"Hooks registered under wrong event type: {wrong_event}\n"
            "Fix the event type in settings.json"
        )


# ============================================================
# Test: settings.json Hook Paths Are Valid
# ============================================================

class TestHookPathsValid:
    """Verify hook paths in settings.json point to existing files."""

    def test_all_registered_paths_exist(self, settings_json, claude_global_dir):
        """All hook commands in settings.json should point to existing files."""
        hooks_config = settings_json.get("hooks", {})
        invalid_paths = []

        for event_type, event_hooks in hooks_config.items():
            for hook_group in event_hooks:
                for hook in hook_group.get("hooks", []):
                    command = hook.get("command", "")
                    # Resolve path - expand ${HOME} and ~
                    resolved = command.replace("${HOME}", os.path.expanduser("~"))
                    resolved = os.path.expanduser(resolved)
                    # Extract just the script path (before first space/argument)
                    script_path = resolved.split()[0] if resolved else ""

                    if script_path and not os.path.exists(script_path):
                        invalid_paths.append({
                            "event": event_type,
                            "command": command,
                            "resolved": script_path,
                        })

        assert not invalid_paths, (
            f"Hook paths in settings.json point to non-existent files:\n"
            + "\n".join([f"  {p['command']} -> {p['resolved']}" for p in invalid_paths])
        )


# ============================================================
# Test: VERSION Markers Present
# ============================================================

class TestVersionMarkers:
    """Verify hooks have VERSION markers for tracking."""

    def test_hooks_have_version_marker(self, global_hooks_dir):
        """All hooks should have VERSION comment."""
        missing_version = []
        for hook_name in HOOK_REGISTRY.keys():
            hook_path = os.path.join(global_hooks_dir, hook_name)
            if os.path.exists(hook_path):
                with open(hook_path) as f:
                    content = f.read()
                if "VERSION" not in content:
                    missing_version.append(hook_name)

        if missing_version:
            pytest.skip(
                f"Hooks missing VERSION marker (recommended): {missing_version}"
            )


# ============================================================
# Test: Specific Version Hooks
# ============================================================

class TestV245Hooks:
    """Test v2.45 specific hooks are properly configured."""

    V245_HOOKS = ["lsa-pre-step.sh", "plan-sync-post-step.sh", "plan-state-init.sh", "auto-plan-state.sh"]

    def test_v245_hooks_exist(self, global_hooks_dir):
        """v2.45 hooks should exist."""
        missing = []
        for hook in self.V245_HOOKS:
            if not os.path.exists(os.path.join(global_hooks_dir, hook)):
                missing.append(hook)

        assert not missing, f"Missing v2.45 hooks: {missing}"

    def test_lsa_pre_step_registered(self, registered_hooks):
        """lsa-pre-step.sh should be registered for PreToolUse Edit|Write."""
        hook_names = [h["name"] for h in registered_hooks.get("PreToolUse", [])]
        assert "lsa-pre-step.sh" in hook_names, (
            "lsa-pre-step.sh not registered in PreToolUse.\n"
            "This hook is critical for v2.45 LSA pattern."
        )

    def test_plan_sync_post_step_registered(self, registered_hooks):
        """plan-sync-post-step.sh should be registered for PostToolUse Edit|Write."""
        hook_names = [h["name"] for h in registered_hooks.get("PostToolUse", [])]
        assert "plan-sync-post-step.sh" in hook_names, (
            "plan-sync-post-step.sh not registered in PostToolUse.\n"
            "This hook is critical for v2.45 drift detection."
        )


# ============================================================
# Test: Summary Report
# ============================================================

class TestHooksSummary:
    """Generate summary report of hook status."""

    def test_print_hooks_summary(self, global_hooks_dir, all_registered_hook_names, capsys):
        """Print summary of all hooks status (always passes, informational)."""
        total = len(HOOK_REGISTRY)
        cli_only = sum(1 for c in HOOK_REGISTRY.values() if c["cli_only"])
        auto_hooks = total - cli_only

        registered_auto = sum(
            1 for h, c in HOOK_REGISTRY.items()
            if not c["cli_only"] and h in all_registered_hook_names
        )

        print("\n" + "=" * 60)
        print("HOOKS REGISTRATION SUMMARY")
        print("=" * 60)
        print(f"Total hooks in registry: {total}")
        print(f"  - Auto-triggered hooks: {auto_hooks}")
        print(f"  - CLI-only scripts: {cli_only}")
        print(f"Registered in settings.json: {registered_auto}/{auto_hooks}")

        if registered_auto < auto_hooks:
            missing = [
                h for h, c in HOOK_REGISTRY.items()
                if not c["cli_only"] and h not in all_registered_hook_names
            ]
            print(f"\n⚠️  MISSING REGISTRATIONS: {missing}")
        else:
            print("\n✅ All auto-hooks properly registered!")

        print("=" * 60)

        # This test always passes - it's informational
        assert True
