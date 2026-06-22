"""
Tests for v3.0 vault system (Phase 6: Vault).

Validates scripts/setup-obsidian-vault.sh, scripts/vault-weekly-compile.sh,
and the vault directory structure.
"""

import os
import subprocess
import stat
import pytest
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
HOME = Path.home()
SCRIPTS_DIR = REPO_ROOT / "scripts"
VAULT_DIR = HOME / "Documents" / "Obsidian" / "MiVault"


def read_file(path: Path) -> str:
    """Read file content, skip if missing."""
    if not path.exists():
        pytest.skip(f"File not found: {path}")
    return path.read_text(encoding="utf-8")


# ============================================================
# setup-obsidian-vault.sh tests
# ============================================================

class TestSetupObsidianVault:
    """Tests for scripts/setup-obsidian-vault.sh."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = SCRIPTS_DIR / "setup-obsidian-vault.sh"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_is_executable(self):
        mode = self.path.stat().st_mode
        assert mode & stat.S_IXUSR, "setup-obsidian-vault.sh must be executable"

    def test_creates_global_wiki_dir(self):
        assert "global/wiki" in self.content, \
            "Must create global/wiki directory"

    def test_creates_projects_dir(self):
        assert "projects" in self.content and "mkdir" in self.content, \
            "Must create projects/ directory"

    def test_creates_templates_dir(self):
        assert "_templates" in self.content and "mkdir" in self.content, \
            "Must create _templates/ directory"

    def test_creates_vault_index(self):
        assert "_vault-index.md" in self.content, "Must create _vault-index.md"

    def test_creates_project_index(self):
        assert "_project-index.md" in self.content, "Must create _project-index.md"

    def test_has_with_obsidian_flag(self):
        assert "--with-obsidian" in self.content, "Must have --with-obsidian flag"

    def test_has_with_git_flag(self):
        assert "--with-git" in self.content, "Must have --with-git flag"

    def test_does_not_hardcode_username(self):
        # Must use $HOME or $VAULT_DIR, not hardcoded /Users/alfredolopez
        # Check that the VAULT_DIR assignment uses $HOME or env var
        assert "VAULT_DIR=" in self.content, "Must define VAULT_DIR variable"
        # Find VAULT_DIR assignment line
        for line in self.content.splitlines():
            if line.strip().startswith("VAULT_DIR=") and not line.strip().startswith("#"):
                assert "$HOME" in line or "${HOME}" in line or \
                       "${VAULT_DIR:-" in line or "$VAULT_DIR" in line, \
                    f"VAULT_DIR must use $HOME or env var, not hardcoded path: {line}"
                # Ensure no literal /Users/<username>
                assert "/Users/alfredolopez" not in line, \
                    f"Must not hardcode /Users/alfredolopez in VAULT_DIR: {line}"
                break

    def test_mkdir_commands_use_vault_dir_variable(self):
        # All mkdir commands should reference $VAULT_DIR, not a hardcoded path
        for line in self.content.splitlines():
            if "mkdir" in line and "/Users/" in line:
                pytest.fail(f"mkdir command hardcodes path: {line.strip()}")


# ============================================================
# vault-weekly-compile.sh tests
# ============================================================

class TestVaultWeeklyCompile:
    """Tests for scripts/vault-weekly-compile.sh."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = SCRIPTS_DIR / "vault-weekly-compile.sh"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_is_executable(self):
        mode = self.path.stat().st_mode
        assert mode & stat.S_IXUSR, "vault-weekly-compile.sh must be executable"

    def test_has_lock_file_mechanism(self):
        assert "LOCK_FILE" in self.content, "Must have lock file mechanism"
        assert "lock" in self.content.lower(), "Must reference locking"

    def test_has_week_deduplication(self):
        assert "LAST_RUN_FILE" in self.content, "Must have LAST_RUN_FILE for deduplication"

    def test_checks_already_compiled_this_week(self):
        assert "already compiled this week" in self.content.lower() or \
               "current_week" in self.content, \
            "Must check if already compiled this week"

    def test_updates_vault_index(self):
        assert "_vault-index.md" in self.content, "Must update _vault-index.md"

    def test_updates_project_index(self):
        assert "_project-index.md" in self.content, "Must update _project-index.md"

    def test_has_git_add_commit_push(self):
        assert "git add" in self.content, "Must have git add"
        assert "git commit" in self.content, "Must have git commit"
        assert "git push" in self.content, "Must have git push"


# ============================================================
# Vault directory existence tests
# ============================================================

class TestVaultDirectoryStructure:
    """Test that setup-obsidian-vault.sh produces the expected structure.

    These tests do NOT depend on the developer's personal vault at
    ``~/Documents/Obsidian/MiVault`` (absent in CI). Instead they run the
    versioned ``scripts/setup-obsidian-vault.sh`` against a temp ``VAULT_DIR``
    and assert the structure the script actually creates — so the script's
    output is what is under test, which is CI-safe on a clean machine.
    """

    @pytest.fixture
    def built_vault(self, tmp_path):
        """Build a temp vault by running the real setup script.

        The script honors ``$VAULT_DIR`` (``VAULT_DIR="${VAULT_DIR:-$HOME/...}"``),
        so we point it at a temp dir and run it for real. Skips only when the
        script itself is missing (it ships in the repo, so this is unreachable
        in normal runs) — never to mask a real failure.
        """
        script = SCRIPTS_DIR / "setup-obsidian-vault.sh"
        if not script.exists():
            pytest.skip(f"setup script not found: {script}")
        vault = tmp_path / "MiVault"
        env = {**os.environ, "VAULT_DIR": str(vault)}
        result = subprocess.run(
            ["bash", str(script)],
            env=env,
            capture_output=True,
            text=True,
            timeout=60,
        )
        assert result.returncode == 0, (
            f"setup-obsidian-vault.sh failed (rc={result.returncode}):\n"
            f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )
        return vault

    def test_vault_root_exists(self, built_vault):
        assert built_vault.exists(), \
            f"setup script must create vault root at {built_vault}"

    def test_global_wiki_exists(self, built_vault):
        wiki_dir = built_vault / "global" / "wiki"
        assert wiki_dir.exists(), \
            f"global/wiki/ must exist in vault at {wiki_dir}"

    def test_projects_dir_exists(self, built_vault):
        projects_dir = built_vault / "projects"
        assert projects_dir.exists(), \
            f"projects/ must exist in vault at {projects_dir}"

    def test_templates_dir_exists(self, built_vault):
        templates_dir = built_vault / "_templates"
        assert templates_dir.exists(), \
            f"_templates/ must exist in vault at {templates_dir}"

    def test_vault_entry_template_exists(self, built_vault):
        template = built_vault / "_templates" / "vault-entry.md"
        assert template.exists(), \
            f"_templates/vault-entry.md must exist at {template}"
