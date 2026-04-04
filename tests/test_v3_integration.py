"""
Tests for v3.0 cross-component integration (Phase 5: Integration).

Validates that all v3.0 components reference each other correctly,
settings are synced, and the system is internally consistent.
"""

import json
import os
import re
import pytest
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
HOME = Path.home()


def read_file(path: Path) -> str:
    """Read file content, skip if missing."""
    if not path.exists():
        pytest.skip(f"File not found: {path}")
    return path.read_text(encoding="utf-8")


def load_json(path: Path) -> dict:
    """Load JSON file, skip if missing."""
    if not path.exists():
        pytest.skip(f"File not found: {path}")
    with open(path) as f:
        return json.load(f)


def get_all_hook_commands(settings: dict) -> list:
    """Extract all hook command strings from nested settings.json hooks structure."""
    commands = []
    hooks_dict = settings.get("hooks", {})
    for event, entries in hooks_dict.items():
        if isinstance(entries, list):
            for entry in entries:
                inner_hooks = entry.get("hooks", [])
                for h in inner_hooks:
                    cmd = h.get("command", "")
                    if cmd:
                        commands.append(cmd)
    return commands


# ============================================================
# Skill cross-references
# ============================================================

class TestOrchestratorReferences:
    """Test that orchestrator/SKILL.md references Aristotle correctly."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".claude" / "skills" / "orchestrator" / "SKILL.md"
        self.content = read_file(self.path)

    def test_mentions_aristotle(self):
        assert "Aristotle" in self.content, "Orchestrator must reference Aristotle methodology"

    def test_mentions_assumption_autopsy_in_step_0(self):
        assert "Assumption Autopsy" in self.content, \
            "Orchestrator must reference Assumption Autopsy"

    def test_step_0_evaluate_exists(self):
        assert "Step 0" in self.content or "EVALUATE" in self.content, \
            "Orchestrator must have Step 0 (EVALUATE)"

    def test_references_spec_for_complexity(self):
        # The orchestrator should reference /spec or complexity-based routing
        assert "complexity" in self.content.lower(), \
            "Orchestrator must reference complexity-based routing"


class TestAdversarialReferences:
    """Test that adversarial/SKILL.md has Aristotle Integration."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".claude" / "skills" / "adversarial" / "SKILL.md"
        self.content = read_file(self.path)

    def test_has_aristotle_integration_section(self):
        assert "Aristotle Integration" in self.content, \
            "Adversarial must have Aristotle Integration section"

    def test_references_assumption_autopsy(self):
        assert "Assumption Autopsy" in self.content or "Phase 1" in self.content, \
            "Adversarial must reference Assumption Autopsy or Phase 1"


class TestClarifyReferences:
    """Test that clarify/SKILL.md has Aristotle-First Clarification."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".claude" / "skills" / "clarify" / "SKILL.md"
        self.content = read_file(self.path)

    def test_has_aristotle_first_clarification(self):
        assert "Aristotle-First Clarification" in self.content or \
               "Aristotle" in self.content, \
            "Clarify must reference Aristotle methodology"


class TestTaskBatchReferences:
    """Test that task-batch/SKILL.md has --slices flag."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".claude" / "skills" / "task-batch" / "SKILL.md"
        self.content = read_file(self.path)

    def test_has_slices_flag(self):
        assert "--slices" in self.content, "task-batch must support --slices flag"


class TestCreateTaskBatchReferences:
    """Test that create-task-batch/SKILL.md has design system question."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".claude" / "skills" / "create-task-batch" / "SKILL.md"
        self.content = read_file(self.path)

    def test_has_design_system_question(self):
        assert "DESIGN.md" in self.content or "design system" in self.content.lower(), \
            "create-task-batch must ask about design system"


class TestShipReferences:
    """Test that ship/SKILL.md references quality checks."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".claude" / "skills" / "ship" / "SKILL.md"
        self.content = read_file(self.path)

    def test_references_gates(self):
        assert "/gates" in self.content, "ship must reference /gates"

    def test_references_security(self):
        assert "/security" in self.content, "ship must reference /security"

    def test_references_browser_test(self):
        assert "/browser-test" in self.content or "browser" in self.content.lower(), \
            "ship must reference browser testing"


# ============================================================
# CLAUDE.md v3.0 references
# ============================================================

class TestClaudeMdV3References:
    """Test that CLAUDE.md references v3.0 components."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / "CLAUDE.md"
        self.content = read_file(self.path)

    def test_references_v3(self):
        assert "v3.0" in self.content or "3.0.0" in self.content, \
            "CLAUDE.md must reference v3.0"

    def test_references_ralph_frontend(self):
        assert "ralph-frontend" in self.content, \
            "CLAUDE.md must reference ralph-frontend agent"

    def test_references_ralph_security(self):
        assert "ralph-security" in self.content, \
            "CLAUDE.md must reference ralph-security agent"

    def test_references_aristotle(self):
        assert "Aristotle" in self.content or "aristotle" in self.content, \
            "CLAUDE.md must reference Aristotle methodology"


# ============================================================
# Rules files
# ============================================================

class TestPlanImmutabilityRule:
    """Test .claude/rules/plan-immutability.md exists with anti-rationalization."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".claude" / "rules" / "plan-immutability.md"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_has_anti_rationalization_table(self):
        pipe_lines = [l for l in self.content.splitlines()
                      if l.strip().startswith("|") and "---" not in l]
        # Should have header + at least 3 entries
        assert len(pipe_lines) >= 4, \
            f"Must have anti-rationalization table with entries, found {len(pipe_lines)} rows"


class TestAristotleMethodologyRule:
    """Test .claude/rules/aristotle-methodology.md exists with 5 phases."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".claude" / "rules" / "aristotle-methodology.md"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_has_5_phases(self):
        phases = [
            "Assumption Autopsy",
            "Irreducible Truths",
            "Reconstruction",
            "Assumption vs Truth Map",
            "Aristotelian Move",
        ]
        for phase in phases:
            assert phase in self.content, f"Must list phase: {phase}"


# ============================================================
# .gitignore vault exclusions
# ============================================================

class TestGitignoreVaultExclusions:
    """Test .gitignore has vault-related exclusions."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".gitignore"
        self.content = read_file(self.path)

    def test_excludes_claude_vault(self):
        assert ".claude/vault/" in self.content, \
            ".gitignore must exclude .claude/vault/"

    def test_excludes_claude_rules_learned(self):
        assert ".claude/rules/learned/" in self.content, \
            ".gitignore must exclude .claude/rules/learned/"

    def test_has_vault_section(self):
        assert "VAULT" in self.content.upper() or "vault" in self.content.lower(), \
            ".gitignore must have vault-related section"


# ============================================================
# plan-state.json
# ============================================================

class TestPlanState:
    """Test .claude/plan-state.json has version 3.0.0 and completed steps."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".claude" / "plan-state.json"
        self.data = load_json(self.path)

    def test_has_version_3(self):
        assert self.data.get("version") == "3.0.0", \
            "plan-state.json must have version 3.0.0"

    def test_has_16_steps(self):
        steps = self.data.get("steps", [])
        assert len(steps) == 16, f"plan-state.json must have 16 steps, found {len(steps)}"

    def test_all_steps_completed(self):
        steps = self.data.get("steps", [])
        for step in steps:
            status = step.get("status", "")
            assert status == "completed", \
                f"Step '{step.get('id', '?')}' ({step.get('name', '?')}) " \
                f"must be completed, got '{status}'"


# ============================================================
# statusline-ralph.sh
# ============================================================

class TestStatuslineRalph:
    """Test .claude/scripts/statusline-ralph.sh has current_step_name extraction."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REPO_ROOT / ".claude" / "scripts" / "statusline-ralph.sh"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_has_current_step_name_extraction(self):
        assert "current_step_name" in self.content, \
            "statusline-ralph.sh must extract current_step_name"


# ============================================================
# Settings sync tests
# ============================================================

class TestSettingsSyncClaude:
    """Test critical hooks are registered in ~/.claude/settings.json."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = HOME / ".claude" / "settings.json"
        if not self.path.exists():
            pytest.skip("~/.claude/settings.json not found")
        self.settings = load_json(self.path)
        self.all_commands = get_all_hook_commands(self.settings)
        self.basenames = [os.path.basename(c.split()[0]) if c else "" for c in self.all_commands]

    def test_has_hooks_section(self):
        assert "hooks" in self.settings, "settings.json must have hooks section"

    def test_sanitize_secrets_registered(self):
        assert any("sanitize-secrets.js" in b for b in self.basenames), \
            "sanitize-secrets.js must be registered in ~/.claude/settings.json"

    def test_session_accumulator_registered(self):
        assert any("session-accumulator.sh" in b for b in self.basenames), \
            "session-accumulator.sh must be registered in ~/.claude/settings.json"

    def test_vault_graduation_registered(self):
        assert any("vault-graduation.sh" in b for b in self.basenames), \
            "vault-graduation.sh must be registered in ~/.claude/settings.json"

    def test_git_safety_guard_registered(self):
        assert any("git-safety-guard.py" in b for b in self.basenames), \
            "git-safety-guard.py must be registered in ~/.claude/settings.json"

    def test_pre_compact_handoff_registered(self):
        assert any("pre-compact-handoff.sh" in b for b in self.basenames), \
            "pre-compact-handoff.sh must be registered in ~/.claude/settings.json"


class TestSettingsSyncMinimax:
    """Test critical hooks are registered in ~/.cc-mirror/minimax/config/settings.json."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = HOME / ".cc-mirror" / "minimax" / "config" / "settings.json"
        if not self.path.exists():
            pytest.skip("~/.cc-mirror/minimax/config/settings.json not found")
        self.settings = load_json(self.path)
        self.all_commands = get_all_hook_commands(self.settings)
        self.basenames = [os.path.basename(c.split()[0]) if c else "" for c in self.all_commands]

    def test_has_hooks_section(self):
        assert "hooks" in self.settings, "minimax settings.json must have hooks section"

    def test_sanitize_secrets_registered(self):
        assert any("sanitize-secrets.js" in b for b in self.basenames), \
            "sanitize-secrets.js must be registered in minimax settings.json"

    def test_session_accumulator_registered(self):
        assert any("session-accumulator.sh" in b for b in self.basenames), \
            "session-accumulator.sh must be registered in minimax settings.json"

    def test_vault_graduation_registered(self):
        assert any("vault-graduation.sh" in b for b in self.basenames), \
            "vault-graduation.sh must be registered in minimax settings.json"
