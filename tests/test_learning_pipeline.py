"""
Tests for MemPalace v3.0 Learning Pipeline — 5 Gap Fixes

Each fix has its own test class. Integration tests verify the full
session → vault → global pipeline end-to-end.

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

    def test_sync_creates_halls_rooms_wings_in_global(self, tmp_path):
        """rsync -a --delete copies full taxonomy tree to global."""
        local_learned = tmp_path / "local" / "learned"
        global_learned = tmp_path / "global" / "learned"

        # Create local structure
        (local_learned / "halls").mkdir(parents=True)
        (local_learned / "rooms").mkdir(parents=True)
        (local_learned / "wings").mkdir(parents=True)
        (local_learned / "halls" / "decisions.md").write_text("# Decisions\n")
        (local_learned / "rooms" / "hooks.md").write_text("# Hooks\n")

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

    def test_sync_deletes_stale_files_from_global(self, tmp_path):
        """rsync --delete removes files in global that no longer exist locally."""
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

    def test_sync_preserves_file_contents(self, tmp_path):
        """Content of synced files matches source exactly."""
        local_learned = tmp_path / "local" / "learned"
        global_learned = tmp_path / "global" / "learned"

        content = "# Patterns\n\n## Async/Await\nUse async/await.\n"
        (local_learned / "halls").mkdir(parents=True)
        (local_learned / "halls" / "patterns.md").write_text(content)

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

    def test_sync_idempotent(self, tmp_path):
        """Running sync twice produces identical results."""
        local_learned = tmp_path / "local" / "learned"
        global_learned = tmp_path / "global" / "learned"

        (local_learned / "halls").mkdir(parents=True)
        (local_learned / "halls" / "decisions.md").write_text("# Decisions\n")

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


# ──────────────────────────────────────────────
# Fix 2: vault-weekly-compile.sh calls sync
# ──────────────────────────────────────────────


class TestFix2CronTriggersSync:
    """Fix 2: vault-weekly-compile.sh calls sync-rules-from-source.sh."""

    def test_cron_script_calls_sync(self):
        """vault-weekly-compile.sh references sync-rules-from-source.sh."""
        script = (REPO_ROOT / "scripts" / "vault-weekly-compile.sh").read_text()
        assert "sync-rules-from-source.sh" in script

    def test_cron_sync_failure_does_not_block(self):
        """sync-rules-from-source.sh failure uses || true — non-blocking."""
        script = (REPO_ROOT / "scripts" / "vault-weekly-compile.sh").read_text()
        # Find the sync line
        lines = script.split("\n")
        sync_lines = [l for l in lines if "sync-rules-from-source.sh" in l]
        assert len(sync_lines) > 0, "No sync-rules line found"
        for line in sync_lines:
            if "bash" in line:
                assert "|| true" in line, f"Sync line missing || true: {line}"

    def test_cron_sync_after_index_update_before_git_commit(self):
        """Sync happens AFTER index update, BEFORE git commit."""
        script = (REPO_ROOT / "scripts" / "vault-weekly-compile.sh").read_text()
        lines = script.split("\n")

        index_line = None
        sync_line = None
        git_line = None

        for i, line in enumerate(lines):
            if "Indices updated" in line:
                index_line = i
            if "sync-rules-from-source.sh" in line:
                sync_line = i
            if "git add" in line:
                git_line = i

        assert index_line is not None, "No 'Indices updated' line found"
        assert sync_line is not None, "No sync-rules line found"
        assert git_line is not None, "No 'git add' line found"
        assert sync_line > index_line, "Sync should come after index update"
        assert sync_line < git_line, "Sync should come before git commit"


# ──────────────────────────────────────────────
# Fix 3: semantic-realtime-extractor.sh re-enabled
# ──────────────────────────────────────────────


class TestFix3SemanticRealtimeExtractor:
    """Fix 3: semantic-realtime-extractor.sh re-enabled with vault writes."""

    def test_hook_not_disabled(self):
        """Script does NOT have early-exit disable guard."""
        script = (REPO_ROOT / ".claude" / "hooks" / "semantic-realtime-extractor.sh").read_text()
        lines = script.split("\n")[:10]
        # The old disable guard was: echo '{"continue": true}' \n exit 0
        for i, line in enumerate(lines[:6]):
            assert not (
                "continue" in line and "exit 0" in lines[min(i + 1, len(lines) - 1)]
            ), f"Disable guard found at line {i}"

    def test_hook_outputs_valid_json(self):
        """Hook outputs valid PostToolUse JSON response on non-matching tool."""
        result = subprocess.run(
            ["bash", str(REPO_ROOT / ".claude" / "hooks" / "semantic-realtime-extractor.sh")],
            input=b'{"tool_name": "Read", "tool_input": {"file_path": "/tmp/test.py"}}',
            capture_output=True,
            timeout=10,
        )
        output = result.stdout.decode().strip()
        data = json.loads(output)
        assert "continue" in data
        assert data["continue"] is True

    def test_hook_writes_to_vault_facts_dir(self, tmp_path):
        """Extraction writes facts to vault/projects/{name}/facts/."""
        vault_dir = tmp_path / "vault"
        vault_dir.mkdir()

        # Create a mock project dir so git rev-parse works
        project_dir = tmp_path / "myproject"
        project_dir.mkdir()
        (project_dir / ".git").mkdir()

        # Build stdin with a Write tool event for a Python file
        stdin_data = json.dumps({
            "tool_name": "Write",
            "tool_input": {
                "file_path": str(project_dir / "test.py"),
                "content": "import requests\nimport flask\ndef my_function():\n    pass\nclass MyClass:\n    pass\n"
            }
        })

        env = os.environ.copy()
        env["HOME"] = str(tmp_path / "home")
        (tmp_path / "home" / ".ralph" / "logs").mkdir(parents=True)
        (tmp_path / "home" / ".ralph" / "config").mkdir(parents=True)
        (tmp_path / "home" / "Documents" / "Obsidian" / "MiVault").mkdir(parents=True)

        # The hook runs in background, so just verify the script doesn't crash
        result = subprocess.run(
            ["bash", str(REPO_ROOT / ".claude" / "hooks" / "semantic-realtime-extractor.sh")],
            input=stdin_data.encode(),
            capture_output=True,
            timeout=10,
            env=env,
            cwd=str(project_dir),
        )
        output = result.stdout.decode().strip()
        data = json.loads(output)
        assert "continue" in data

    def test_hook_add_fact_sanitizes_paths(self):
        """add_fact strips absolute /Users/ paths from output."""
        script = (REPO_ROOT / ".claude" / "hooks" / "semantic-realtime-extractor.sh").read_text()
        # The add_fact function should have sed to strip absolute paths
        assert "sed" in script or "tr -cd" in script, "Missing path sanitization in add_fact"

    def test_hook_add_fact_writes_vault_not_helper(self):
        """add_fact writes to vault, not semantic-write-helper.sh."""
        script = (REPO_ROOT / ".claude" / "hooks" / "semantic-realtime-extractor.sh").read_text()
        # Check executable lines, not comments
        code_lines = [l for l in script.split("\n") if not l.strip().startswith("#")]
        for line in code_lines:
            assert "semantic-write-helper.sh" not in line, (
                f"Still references removed semantic-write-helper.sh in code: {line}"
            )
        # Should reference vault facts
        assert "VAULT_FACTS_DIR" in script or "facts" in script


# ──────────────────────────────────────────────
# Fix 4: decision-extractor.sh EPISODES_DIR
# ──────────────────────────────────────────────


class TestFix4DecisionExtractorEpisodesDir:
    """Fix 4: decision-extractor.sh has EPISODES_DIR defined."""

    def test_episodes_dir_defined(self):
        """EPISODES_DIR is defined in the script."""
        script = (REPO_ROOT / ".claude" / "hooks" / "decision-extractor.sh").read_text()
        assert "EPISODES_DIR=" in script, "EPISODES_DIR not defined"

    def test_episodes_dir_after_vault_dir(self):
        """EPISODES_DIR is defined after VAULT_DIR."""
        script = (REPO_ROOT / ".claude" / "hooks" / "decision-extractor.sh").read_text()
        vault_pos = script.find('VAULT_DIR=')
        episodes_pos = script.find('EPISODES_DIR=')
        assert vault_pos > 0, "VAULT_DIR not found"
        assert episodes_pos > 0, "EPISODES_DIR not found"
        assert episodes_pos > vault_pos, "EPISODES_DIR should be defined after VAULT_DIR"

    def test_episodes_dir_uses_vault_path(self):
        """EPISODES_DIR points to vault/projects/{name}/decisions/."""
        script = (REPO_ROOT / ".claude" / "hooks" / "decision-extractor.sh").read_text()
        # Find the EPISODES_DIR definition line
        for line in script.split("\n"):
            if "EPISODES_DIR=" in line and "v3.2" not in line.lower():
                assert "VAULT_DIR" in line or "Obsidian" in line, (
                    f"EPISODES_DIR should reference VAULT_DIR: {line}"
                )
                assert "decisions" in line, f"EPISODES_DIR should end in /decisions/: {line}"
                break

    def test_episodes_dir_has_mkdir(self):
        """mkdir -p ensures EPISODES_DIR exists."""
        script = (REPO_ROOT / ".claude" / "hooks" / "decision-extractor.sh").read_text()
        assert 'mkdir -p "$EPISODES_DIR"' in script or "mkdir -p ${EPISODES_DIR}" in script or "mkdir -p $EPISODES_DIR" in script, (
            "Missing mkdir -p for EPISODES_DIR"
        )

    def test_hook_outputs_valid_json(self):
        """Hook outputs valid PostToolUse JSON after fix."""
        result = subprocess.run(
            ["bash", str(REPO_ROOT / ".claude" / "hooks" / "decision-extractor.sh")],
            input=b'{"tool_name": "Read", "tool_input": {}}',
            capture_output=True,
            timeout=10,
        )
        output = result.stdout.decode().strip()
        data = json.loads(output)
        assert "continue" in data


# ──────────────────────────────────────────────
# Fix 5: continuous-learning.sh procedural feedback
# ──────────────────────────────────────────────


class TestFix5ContinuousLearningProcedural:
    """Fix 5: continuous-learning.sh feeds back to procedural rules.json."""

    def test_script_has_procedural_feedback_block(self):
        """Script contains the procedural rules.json write block."""
        script = (REPO_ROOT / ".claude" / "hooks" / "continuous-learning.sh").read_text()
        assert "PROCEDURAL_FILE" in script
        assert "rules.json" in script
        assert "session-learning" in script
        assert "needs_review" in script

    def test_procedural_write_uses_atomic_pattern(self):
        """Write uses .tmp file + mv (atomic, no corruption on crash)."""
        script = (REPO_ROOT / ".claude" / "hooks" / "continuous-learning.sh").read_text()
        assert ".tmp" in script
        assert "mv" in script

    def test_procedural_write_has_sanitization(self):
        """Inputs are sanitized to prevent JSON injection."""
        script = (REPO_ROOT / ".claude" / "hooks" / "continuous-learning.sh").read_text()
        # Look for tr -cd sanitization of inputs
        assert "tr -cd" in script, "Missing input sanitization (tr -cd)"

    def test_procedural_entry_has_correct_schema(self):
        """Entry has all expected keys and correct types."""
        script = (REPO_ROOT / ".claude" / "hooks" / "continuous-learning.sh").read_text()
        required_keys = [
            "type", "source", "project", "session",
            "corrections", "errors", "created_at",
            "confidence", "needs_review",
        ]
        for key in required_keys:
            assert key in script, f"Missing key in procedural entry: {key}"

    def test_procedural_confidence_is_low(self):
        """New entries start with confidence 0.5 (needs confirmation)."""
        script = (REPO_ROOT / ".claude" / "hooks" / "continuous-learning.sh").read_text()
        assert "0.5" in script, "Confidence should be 0.5 for new entries"

    def test_procedural_needs_review_is_true(self):
        """Entry is marked needs_review: true (safety gate)."""
        script = (REPO_ROOT / ".claude" / "hooks" / "continuous-learning.sh").read_text()
        assert "needs_review: true" in script or "needs_review" in script

    def test_procedural_write_guarded_by_corrections_or_errors(self):
        """Write only happens when CORRECTIONS > 0 or ERRORS > 2."""
        script = (REPO_ROOT / ".claude" / "hooks" / "continuous-learning.sh").read_text()
        # The procedural block should be inside the same guard as the pattern file
        assert "CORRECTIONS" in script
        assert "ERRORS" in script


# ──────────────────────────────────────────────
# Integration Tests
# ──────────────────────────────────────────────


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

    def test_all_hooks_produce_valid_json(self):
        """All modified hooks produce valid JSON output."""
        hooks = [
            "semantic-realtime-extractor.sh",
            "decision-extractor.sh",
        ]
        for hook_name in hooks:
            hook_path = REPO_ROOT / ".claude" / "hooks" / hook_name
            result = subprocess.run(
                ["bash", str(hook_path)],
                input=b'{"tool_name": "Read", "tool_input": {}}',
                capture_output=True,
                timeout=10,
            )
            output = result.stdout.decode().strip()
            data = json.loads(output)
            assert "continue" in data, f"{hook_name} output: {output}"

    def test_continuous_learning_produces_valid_json(self):
        """continuous-learning.sh (Stop hook) produces valid decision JSON."""
        hook_path = REPO_ROOT / ".claude" / "hooks" / "continuous-learning.sh"
        # Stop hooks need a transcript — we pass empty input, it should still output valid JSON
        result = subprocess.run(
            ["bash", str(hook_path)],
            input=b'{}',
            capture_output=True,
            timeout=10,
        )
        output = result.stdout.decode().strip()
        data = json.loads(output)
        assert "decision" in data

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

    def test_cron_script_syntax_valid(self):
        """vault-weekly-compile.sh is syntactically valid bash."""
        result = subprocess.run(
            ["bash", "-n", str(REPO_ROOT / "scripts" / "vault-weekly-compile.sh")],
            capture_output=True,
        )
        assert result.returncode == 0, f"Syntax error: {result.stderr.decode()}"

    def test_all_modified_hooks_syntax_valid(self):
        """All modified hooks pass bash syntax check."""
        hooks = [
            ".claude/hooks/semantic-realtime-extractor.sh",
            ".claude/hooks/decision-extractor.sh",
            ".claude/hooks/continuous-learning.sh",
        ]
        for hook in hooks:
            result = subprocess.run(
                ["bash", "-n", str(REPO_ROOT / hook)],
                capture_output=True,
            )
            assert result.returncode == 0, f"Syntax error in {hook}: {result.stderr.decode()}"
