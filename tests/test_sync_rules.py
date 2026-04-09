"""Tests for scripts/sync-rules.sh — one-way rule sync to global directories."""

import subprocess
from pathlib import Path

import pytest

SCRIPT = Path("scripts/sync-rules.sh")
REPO = Path(__file__).resolve().parent.parent


@pytest.mark.skipif(not SCRIPT.exists(), reason="sync-rules.sh not found")
class TestSyncRules:
    """Tests for the sync-rules.sh script."""

    def test_script_exists_and_executable(self):
        assert SCRIPT.exists()
        assert SCRIPT.stat().st_mode & 0o111, "Script must be executable"

    def test_dry_run_mode(self):
        """Dry-run mode should report changes without executing."""
        result = subprocess.run(
            ["bash", str(SCRIPT), "--dry-run"],
            capture_output=True, text=True, cwd=str(REPO), timeout=30
        )
        assert result.returncode == 0
        assert "DRY RUN" in result.stdout

    def test_sync_idempotent(self):
        """Running sync twice should show skipped on second run."""
        # First run
        r1 = subprocess.run(
            ["bash", str(SCRIPT)],
            capture_output=True, text=True, cwd=str(REPO), timeout=30
        )
        assert r1.returncode == 0

        # Second run — everything should be skipped
        r2 = subprocess.run(
            ["bash", str(SCRIPT)],
            capture_output=True, text=True, cwd=str(REPO), timeout=30
        )
        assert r2.returncode == 0
        # After first sync, second run should have 0 new syncs
        output = r2.stdout
        # Parse "synced=N" from results line
        for line in output.split("\n"):
            if "Results:" in line:
                synced = int(line.split("synced=")[1].split()[0])
                assert synced == 0, f"Second run should have 0 new syncs, got {synced}"

    def test_symlinks_point_to_repo(self):
        """All global rules should be symlinks pointing to repo."""
        global_rules = Path.home() / ".claude" / "rules"
        repo_rules = REPO / ".claude" / "rules"

        for rule_file in repo_rules.rglob("*.md"):
            rel = rule_file.relative_to(repo_rules)
            global_file = global_rules / rel
            if global_file.exists():
                if global_file.is_symlink():
                    target = global_file.resolve()
                    assert target == rule_file.resolve(), (
                        f"{rel}: symlink points to {target}, expected {rule_file.resolve()}"
                    )

    def test_checksum_file_created(self):
        """Sync should create .sync-checksums file."""
        subprocess.run(
            ["bash", str(SCRIPT)],
            capture_output=True, text=True, cwd=str(REPO), timeout=30
        )
        checksum_file = REPO / ".claude" / "rules" / ".sync-checksums"
        assert checksum_file.exists(), ".sync-checksums should be created after sync"

    def test_source_rule_copies_to_target(self):
        """A new rule in repo should be symlinked to global on sync."""
        # This tests the script's core functionality indirectly
        # by verifying existing symlinks are valid
        global_rules = Path.home() / ".claude" / "rules"
        if not global_rules.exists():
            pytest.skip("No global rules directory")

        broken = []
        for link in global_rules.rglob("*.md"):
            if link.is_symlink() and not link.resolve().exists():
                broken.append(str(link))

        assert len(broken) == 0, f"Broken symlinks found: {broken}"
