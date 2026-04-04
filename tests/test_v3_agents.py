"""
Tests for v3.0 agent definitions (Phase 3: Agents).

Validates ralph-frontend.md and ralph-security.md in .claude/agents/.
"""

import os
import re
import pytest
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
AGENTS_DIR = REPO_ROOT / ".claude" / "agents"


def read_file(path: Path) -> str:
    """Read file content, skip if missing."""
    if not path.exists():
        pytest.skip(f"File not found: {path}")
    return path.read_text(encoding="utf-8")


# ============================================================
# ralph-frontend.md tests
# ============================================================

class TestRalphFrontend:
    """Tests for ralph-frontend agent definition."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = AGENTS_DIR / "ralph-frontend.md"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists(), "ralph-frontend.md must exist in .claude/agents/"

    def test_has_version_3(self):
        assert "VERSION: 3.0.0" in self.content, "Must have VERSION 3.0.0"

    def test_has_allowed_tools_lsp(self):
        assert "LSP" in self.content, "Must list LSP in allowed-tools"

    def test_has_allowed_tools_read(self):
        assert "Read" in self.content, "Must list Read in allowed-tools"

    def test_has_allowed_tools_edit(self):
        assert "Edit" in self.content, "Must list Edit in allowed-tools"

    def test_has_allowed_tools_write(self):
        assert "Write" in self.content, "Must list Write in allowed-tools"

    def test_has_allowed_tools_bash(self):
        assert "Bash" in self.content, "Must list Bash in allowed-tools"

    def test_references_design_md(self):
        assert "DESIGN.md" in self.content, "Must reference DESIGN.md"

    def test_has_5_quality_pillars(self):
        pillars = ["CORRECTNESS", "TYPES", "ACCESSIBILITY", "RESPONSIVE", "UI CONSISTENCY"]
        for pillar in pillars:
            assert pillar in self.content, f"Must list quality pillar: {pillar}"

    def test_pillar_count_is_5(self):
        assert "Quality Pillars (5)" in self.content, "Must indicate 5 quality pillars"

    def test_has_8_component_states(self):
        states = ["Default", "Hover", "Focus", "Active", "Disabled", "Loading", "Error", "Success"]
        for state in states:
            assert state.lower() in self.content.lower(), f"Must list component state: {state}"

    def test_component_states_count(self):
        # Check that all 8 numbered states appear
        for i in range(1, 9):
            assert f"{i}." in self.content, f"Must have numbered state {i}."

    def test_has_ralph_naming_convention(self):
        assert "ralph-*" in self.content, "Must reference ralph-* naming convention"

    def test_identified_by_ralph_naming(self):
        assert "naming convention" in self.content.lower(), \
            "Must mention identification by naming convention"


# ============================================================
# ralph-security.md tests
# ============================================================

class TestRalphSecurity:
    """Tests for ralph-security agent definition."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = AGENTS_DIR / "ralph-security.md"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists(), "ralph-security.md must exist in .claude/agents/"

    def test_has_version_3(self):
        assert "VERSION: 3.0.0" in self.content, "Must have VERSION 3.0.0"

    def test_has_allowed_tools_lsp(self):
        assert "LSP" in self.content, "Must list LSP in allowed-tools"

    def test_has_allowed_tools_read(self):
        assert "Read" in self.content, "Must list Read in allowed-tools"

    def test_has_allowed_tools_grep(self):
        assert "Grep" in self.content, "Must list Grep in allowed-tools"

    def test_has_allowed_tools_glob(self):
        assert "Glob" in self.content, "Must list Glob in allowed-tools"

    def test_has_allowed_tools_bash(self):
        assert "Bash" in self.content, "Must list Bash in allowed-tools"

    def test_has_6_quality_pillars(self):
        pillars = [
            "THREAT MODEL",
            "CODE AUDIT",
            "SECRETS",
            "DEPENDENCIES",
            "PLAN REVIEW",
            "HOOKS INTEGRITY",
        ]
        for pillar in pillars:
            assert pillar in self.content, f"Must list quality pillar: {pillar}"

    def test_pillar_count_is_6(self):
        assert "Quality Pillars (6)" in self.content, "Must indicate 6 quality pillars"

    def test_references_sec_context_depth(self):
        assert "sec-context-depth" in self.content, "Must reference sec-context-depth"

    def test_references_security_threat_model(self):
        assert "security-threat-model" in self.content, "Must reference security-threat-model"

    def test_has_anti_rationalization_section(self):
        assert "Anti-Rationalization" in self.content, "Must have Anti-Rationalization section"

    def test_anti_rationalization_has_table_entries(self):
        # Count table rows (lines starting with |) in Anti-Rationalization section
        in_section = False
        table_rows = 0
        for line in self.content.splitlines():
            if "Anti-Rationalization" in line:
                in_section = True
                continue
            if in_section and line.startswith("|") and "---" not in line and "Excuse" not in line:
                table_rows += 1
            if in_section and line.startswith("#") and "Anti-Rationalization" not in line:
                break
        assert table_rows >= 3, f"Anti-Rationalization must have at least 3 table entries, found {table_rows}"
