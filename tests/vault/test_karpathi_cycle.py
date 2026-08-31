"""
Tests for the Karpathy cycle pieces that survive #69 Phase 3 Slice D.

The automatic memory writers (wing compiler, writeback, promotion, decision
filter, log writer, projections) were deleted by Slice D; their test classes
died with them. What remains is W1: wake-up layer stack output and the L3
query inside smart-memory-search.sh.
"""

import json
import os
import subprocess

import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HOOKS_DIR = os.path.join(PROJECT_ROOT, ".claude", "hooks")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run_hook(script_name, stdin_data="", timeout=10, env=None):
    """Run a hook script and return (stdout, returncode).

    ``env`` overrides the subprocess environment. The vault hooks resolve
    their vault under ``${HOME}/Documents/Obsidian/MiVault`` and their logs
    under ``${HOME}/.ralph``, so passing ``env={**os.environ, "HOME": tmp}``
    redirects them at an isolated, CI-built vault instead of the developer's
    real ``~`` (absent in CI).
    """
    script_path = os.path.join(HOOKS_DIR, script_name)
    if not os.path.exists(script_path):
        pytest.skip(f"{script_name} not found")
    result = subprocess.run(
        ["bash", script_path],
        input=stdin_data,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    )
    return result.stdout.strip(), result.returncode


def build_vault(home_dir):
    """Build a real vault under ``home_dir`` via the versioned setup script.

    Returns the vault path (``<home>/Documents/Obsidian/MiVault``). This runs
    ``scripts/setup-obsidian-vault.sh`` for real, honoring ``$VAULT_DIR``, so
    the hooks under test reach their vault-present code paths in CI.
    """
    setup_script = os.path.join(PROJECT_ROOT, "scripts", "setup-obsidian-vault.sh")
    if not os.path.exists(setup_script):
        pytest.skip("setup-obsidian-vault.sh not found")
    vault_dir = os.path.join(home_dir, "Documents", "Obsidian", "MiVault")
    env = {**os.environ, "HOME": home_dir, "VAULT_DIR": vault_dir}
    result = subprocess.run(
        ["bash", setup_script],
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert result.returncode == 0, (
        f"setup-obsidian-vault.sh failed (rc={result.returncode}):\n"
        f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )
    os.makedirs(os.path.join(home_dir, ".ralph", "logs"), exist_ok=True)
    return vault_dir


def create_minimal_vault(base_dir):
    """Create a minimal vault structure for testing."""
    dirs = [
        "global/wiki",
        "global/output/reports",
        "projects/test-project/wiki",
        "projects/test-project/facts",
        "projects/test-project/decisions",
        "agents/ralph-coder/diary",
        "agents/ralph-reviewer/diary",
    ]
    for d in dirs:
        os.makedirs(os.path.join(base_dir, d), exist_ok=True)

    # Create _vault-index.md
    index_path = os.path.join(base_dir, "global", "_vault-index.md")
    with open(index_path, "w", encoding="utf-8") as f:
        f.write("## Statistics\n- Total lessons: 5\n- Global wiki articles: 3\n")

    return base_dir


# ---------------------------------------------------------------------------
# W1: Vault Stats + L3 Query
# ---------------------------------------------------------------------------

class TestWakeUpVaultStats:
    """W1.1: Vault stats loaded at session start."""

    def test_wake_up_script_exists(self):
        assert os.path.exists(os.path.join(HOOKS_DIR, "wake-up-layer-stack.sh"))

    def test_wake_up_produces_output(self):
        stdout, rc = run_hook("wake-up-layer-stack.sh")
        assert rc == 0
        assert len(stdout) > 0

    def test_wake_up_contains_identity(self):
        stdout, rc = run_hook("wake-up-layer-stack.sh")
        assert "Identity" in stdout or "L0" in stdout


class TestL3VaultQuery:
    """W1.2: L3 query integration in smart-memory-search."""

    def test_smart_memory_search_exists(self):
        assert os.path.exists(os.path.join(HOOKS_DIR, "smart-memory-search.sh"))

    def test_smart_memory_search_has_l3_section(self):
        """Verify L3 query code was added to smart-memory-search."""
        with open(os.path.join(HOOKS_DIR, "smart-memory-search.sh"), encoding="utf-8") as f:
            content = f.read()
        assert "layers.py" in content
        assert "last-query-hits" in content

    def test_smart_memory_search_valid_json_output(self):
        """Hook must produce valid JSON even on no-op run."""
        stdin_data = json.dumps({"tool_name": "Task", "tool_input": {"prompt": "test"}})
        stdout, rc = run_hook("smart-memory-search.sh", stdin_data=stdin_data)
        # The hook outputs JSON in PreToolUse format
        if stdout:
            parsed = json.loads(stdout)
            assert "hookSpecificOutput" in parsed or "continue" in parsed

