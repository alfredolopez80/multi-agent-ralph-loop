"""
Tests for the surviving MemPalace v3.0 learning pipeline pieces.

Fix 1 (sync-rules-from-source.sh learned/ sync) keeps its class. The Fix 2-5
classes tested vault-weekly-compile.sh, semantic-realtime-extractor.sh,
decision-extractor.sh and continuous-learning.sh — all removed by #69 Slice D
(automatic memory writers); those classes died with their subjects. The
end-to-end tests that exercised the deleted hooks died with them too.

Run: pytest tests/test_learning_pipeline.py -v --tb=short
"""

import json
import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent


# ──────────────────────────────────────────────
# Fix 1: sync-rules-from-source.sh learned/ sync
# ──────────────────────────────────────────────


class TestFix1SyncRulesLearnedTaxonomy:
    """Fix 1: sync-rules-from-source.sh syncs learned/ taxonomy to global."""

    def test_sync_creates_halls_rooms_wings_in_global(self, tmp_path, requires_tool):
        """rsync -a --delete copies full taxonomy tree to global."""
        requires_tool("rsync")
        local_learned = tmp_path / "local" / "learned"
        global_learned = tmp_path / "global" / "learned"

        # Create local structure
        (local_learned / "halls").mkdir(parents=True)
        (local_learned / "rooms").mkdir(parents=True)
        (local_learned / "wings").mkdir(parents=True)
        (local_learned / "halls" / "decisions.md").write_text("# Decisions\n")
        (local_learned / "rooms" / "hooks.md").write_text("# Hooks\n")

        # Mirror the production script (sync-rules-from-source.sh): ensure the
        # destination's parent chain exists. GNU rsync (Linux CI) returns exit 11
        # if the dest parent is missing; openrsync (macOS) tolerates it.
        global_learned.parent.mkdir(parents=True, exist_ok=True)

        # Simulate rsync
        subprocess.run(
            ["rsync", "-a", "--delete", f"{local_learned}/", f"{global_learned}/"],
            check=True,
            capture_output=True,
        )

        assert (global_learned / "halls" / "decisions.md").exists()
        assert (global_learned / "rooms" / "hooks.md").exists()
        assert (global_learned / "halls").is_dir()
        assert (global_learned / "rooms").is_dir()
        assert (global_learned / "wings").is_dir()

    def test_sync_deletes_stale_files_from_global(self, tmp_path, requires_tool):
        """rsync --delete removes files in global that no longer exist locally."""
        requires_tool("rsync")
        local_learned = tmp_path / "local" / "learned"
        global_learned = tmp_path / "global" / "learned"

        # Create local structure
        (local_learned / "halls").mkdir(parents=True)
        (local_learned / "halls" / "decisions.md").write_text("# Decisions\n")

        # Create global with stale file
        (global_learned / "halls").mkdir(parents=True)
        (global_learned / "halls" / "decisions.md").write_text("# Decisions\n")
        (global_learned / "halls" / "stale.md").write_text("# Stale\n")

        # Rsync with --delete
        subprocess.run(
            ["rsync", "-a", "--delete", f"{local_learned}/", f"{global_learned}/"],
            check=True,
            capture_output=True,
        )

        assert (global_learned / "halls" / "decisions.md").exists()
        assert not (global_learned / "halls" / "stale.md").exists()

    def test_sync_preserves_file_contents(self, tmp_path, requires_tool):
        """Content of synced files matches source exactly."""
        requires_tool("rsync")
        local_learned = tmp_path / "local" / "learned"
        global_learned = tmp_path / "global" / "learned"

        content = "# Patterns\n\n## Async/Await\nUse async/await.\n"
        (local_learned / "halls").mkdir(parents=True)
        (local_learned / "halls" / "patterns.md").write_text(content)

        # Mirror the production script: ensure the dest parent chain exists so
        # GNU rsync (Linux CI) does not fail with exit 11.
        global_learned.parent.mkdir(parents=True, exist_ok=True)

        subprocess.run(
            ["rsync", "-a", "--delete", f"{local_learned}/", f"{global_learned}/"],
            check=True,
            capture_output=True,
        )

        assert (global_learned / "halls" / "patterns.md").read_text() == content

    def test_sync_no_secrets_in_learned_files(self):
        """Learned taxonomy files contain NO repo-specific secrets."""
        learned_dir = REPO_ROOT / ".claude" / "rules" / "learned"
        if not learned_dir.exists():
            pytest.skip("No learned/ directory in repo")

        # These patterns are checked in non-security files only.
        # Security docs legitimately MENTION patterns like "secret", "sk-"
        # as part of anti-pattern documentation — those are NOT leaks.
        sensitive_patterns = [
            "api_key", "API_KEY", "password=",
            "sk_live", "ghp_", "gho_",
        ]

        for md_file in learned_dir.rglob("*.md"):
            # Skip security documentation — they document patterns, not secrets
            if "security" in str(md_file).lower():
                continue
            content = md_file.read_text(errors="ignore").lower()
            for pattern in sensitive_patterns:
                assert pattern.lower() not in content, (
                    f"Sensitive pattern '{pattern}' found in {md_file.relative_to(learned_dir)}"
                )

    def test_sync_idempotent(self, tmp_path, requires_tool):
        """Running sync twice produces identical results."""
        requires_tool("rsync")
        local_learned = tmp_path / "local" / "learned"
        global_learned = tmp_path / "global" / "learned"

        (local_learned / "halls").mkdir(parents=True)
        (local_learned / "halls" / "decisions.md").write_text("# Decisions\n")

        # Mirror the production script: ensure the dest parent chain exists so
        # GNU rsync (Linux CI) does not fail with exit 11.
        global_learned.parent.mkdir(parents=True, exist_ok=True)

        # First sync
        subprocess.run(
            ["rsync", "-a", "--delete", f"{local_learned}/", f"{global_learned}/"],
            check=True,
            capture_output=True,
        )
        first_hash = (global_learned / "halls" / "decisions.md").read_text()

        # Second sync
        subprocess.run(
            ["rsync", "-a", "--delete", f"{local_learned}/", f"{global_learned}/"],
            check=True,
            capture_output=True,
        )
        second_hash = (global_learned / "halls" / "decisions.md").read_text()

        assert first_hash == second_hash

    def test_sync_script_has_learned_block(self):
        """sync-rules-from-source.sh contains learned/ taxonomy sync block."""
        script = (REPO_ROOT / ".claude" / "scripts" / "sync-rules-from-source.sh").read_text()
        assert "LEARNED_SOURCE" in script
        assert "LEARNED_TARGET" in script
        assert "rsync -a --delete" in script
        assert "learned/" in script


class TestEndToEndPipeline:
    """Full pipeline integration tests."""

    def test_sync_script_executes_without_error(self):
        """sync-rules-from-source.sh runs successfully."""
        result = subprocess.run(
            ["bash", str(REPO_ROOT / ".claude" / "scripts" / "sync-rules-from-source.sh")],
            capture_output=True,
            timeout=30,
        )
        assert result.returncode == 0, f"Script failed: {result.stderr.decode()}"


    def test_no_sensitive_patterns_in_learned_taxonomy(self):
        """Global learned files have no sensitive data patterns."""
        global_learned = Path.home() / ".claude" / "rules" / "learned"
        if not global_learned.exists():
            pytest.skip("Global learned/ not yet synced")

        sensitive = ["api_key", "ghp_", "password=", "token="]
        for md_file in global_learned.rglob("*.md"):
            # Skip security docs — they document patterns, not secrets
            if "security" in str(md_file).lower():
                continue
            content = md_file.read_text(errors="ignore").lower()
            for pattern in sensitive:
                assert pattern not in content, (
                    f"Sensitive '{pattern}' in {md_file.relative_to(global_learned)}"
                )
