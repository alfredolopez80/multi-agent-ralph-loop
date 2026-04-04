"""
Tests for v3.0 documentation (Phase 4: Docs).

Validates docs/templates/DESIGN.md.template, docs/reference/*.md files.
"""

import os
import re
import pytest
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
DOCS_DIR = REPO_ROOT / "docs"
TEMPLATES_DIR = DOCS_DIR / "templates"
REFERENCE_DIR = DOCS_DIR / "reference"


def read_file(path: Path) -> str:
    """Read file content, skip if missing."""
    if not path.exists():
        pytest.skip(f"File not found: {path}")
    return path.read_text(encoding="utf-8")


def count_table_rows(content: str) -> int:
    """Count table data rows (lines starting with | that are not headers or separators)."""
    count = 0
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith("|") and not re.match(r"^\|[\s\-:]+\|", stripped):
            # Not a separator row
            count += 1
    return count


# ============================================================
# DESIGN.md.template tests
# ============================================================

class TestDesignTemplate:
    """Tests for docs/templates/DESIGN.md.template."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = TEMPLATES_DIR / "DESIGN.md.template"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_has_9_numbered_sections(self):
        for i in range(1, 10):
            pattern = f"## {i}."
            assert pattern in self.content, f"Must have section '## {i}.'"

    def test_has_color_palette_table(self):
        assert "Color Palette" in self.content, "Must have Color Palette section"
        # Check for table with color tokens
        assert "--color-primary" in self.content, "Must have color-primary token"

    def test_has_typography_table(self):
        assert "Typography" in self.content, "Must have Typography section"
        assert "--font-heading" in self.content, "Must have font-heading token"

    def test_has_agent_prompt_guide_section(self):
        assert "Agent Prompt Guide" in self.content, "Must have Agent Prompt Guide section"

    def test_has_responsive_breakpoints(self):
        assert "Breakpoint" in self.content, "Must have breakpoint definitions"
        # Check for specific breakpoints
        assert "640px" in self.content or "640" in self.content, "Must define sm breakpoint"
        assert "1024px" in self.content or "1024" in self.content, "Must define lg breakpoint"

    def test_has_layout_section(self):
        assert "Layout" in self.content, "Must have Layout section"

    def test_has_responsive_behavior_section(self):
        assert "Responsive Behavior" in self.content or "Responsive" in self.content


# ============================================================
# aristotle-first-principles.md tests
# ============================================================

class TestAristotleFirstPrinciples:
    """Tests for docs/reference/aristotle-first-principles.md."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REFERENCE_DIR / "aristotle-first-principles.md"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_has_phase_1_assumption_autopsy(self):
        assert "Assumption Autopsy" in self.content

    def test_has_phase_2_irreducible_truths(self):
        assert "Irreducible Truths" in self.content

    def test_has_phase_3_reconstruction(self):
        assert "Reconstruction" in self.content

    def test_has_phase_4_map(self):
        assert "Assumption vs Truth Map" in self.content or "Map" in self.content

    def test_has_phase_5_aristotelian_move(self):
        assert "Aristotelian Move" in self.content

    def test_has_complexity_table(self):
        assert "Complexity" in self.content
        # Check for complexity ranges
        assert "1-3" in self.content, "Must have complexity range 1-3"
        assert "4-6" in self.content or "4+" in self.content, "Must have complexity range 4+"

    def test_has_integration_with_orchestrator(self):
        assert "Orchestrator" in self.content or "orchestrator" in self.content, \
            "Must reference orchestrator integration"
        assert "Step 0" in self.content, "Must reference Step 0"


# ============================================================
# anti-rationalization.md tests
# ============================================================

class TestAntiRationalization:
    """Tests for docs/reference/anti-rationalization.md."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REFERENCE_DIR / "anti-rationalization.md"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_has_30_plus_table_entries(self):
        # Count pipe characters at start of lines (table rows) excluding headers and separators
        pipe_lines = []
        for line in self.content.splitlines():
            stripped = line.strip()
            if stripped.startswith("|") and "---" not in stripped:
                pipe_lines.append(stripped)
        # Subtract header rows (one per table section)
        # Each table has a header row with column names
        header_keywords = ["Excuse", "Rebuttal", "Severity", "Affected", "#"]
        headers = [l for l in pipe_lines if any(kw in l for kw in header_keywords)]
        data_rows = len(pipe_lines) - len(headers)
        assert data_rows >= 30, f"Must have 30+ table entries, found {data_rows}"

    def test_covers_general_category(self):
        assert "### General" in self.content, "Must have General category"

    def test_covers_orchestrator_category(self):
        assert "Orchestrator" in self.content, "Must have Orchestrator category"

    def test_covers_iterate_category(self):
        assert "Iterate" in self.content or "Loop" in self.content, \
            "Must have Iterate/Loop category"

    def test_covers_task_batch_category(self):
        assert "Task-Batch" in self.content or "task-batch" in self.content.lower(), \
            "Must have Task-Batch category"

    def test_covers_gates_category(self):
        assert "Gates" in self.content or "Quality Gates" in self.content, \
            "Must have Gates category"

    def test_covers_autoresearch_category(self):
        assert "Autoresearch" in self.content or "autoresearch" in self.content.lower(), \
            "Must have Autoresearch category"

    def test_covers_frontend_category(self):
        assert "Frontend" in self.content, "Must have Frontend category"


# ============================================================
# security-checklist.md tests
# ============================================================

class TestSecurityChecklist:
    """Tests for docs/reference/security-checklist.md."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REFERENCE_DIR / "security-checklist.md"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_has_owasp_a01(self):
        assert "A01" in self.content, "Must have OWASP A01"

    def test_has_owasp_a02(self):
        assert "A02" in self.content, "Must have OWASP A02"

    def test_has_owasp_a03(self):
        assert "A03" in self.content, "Must have OWASP A03"

    def test_has_owasp_a04(self):
        assert "A04" in self.content, "Must have OWASP A04"

    def test_has_owasp_a05(self):
        assert "A05" in self.content, "Must have OWASP A05"

    def test_has_owasp_a06(self):
        assert "A06" in self.content, "Must have OWASP A06"

    def test_has_owasp_a07(self):
        assert "A07" in self.content, "Must have OWASP A07"

    def test_has_owasp_a08(self):
        assert "A08" in self.content, "Must have OWASP A08"

    def test_has_owasp_a09(self):
        assert "A09" in self.content, "Must have OWASP A09"

    def test_has_owasp_a10(self):
        assert "A10" in self.content, "Must have OWASP A10"


# ============================================================
# accessibility-checklist.md tests
# ============================================================

class TestAccessibilityChecklist:
    """Tests for docs/reference/accessibility-checklist.md."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REFERENCE_DIR / "accessibility-checklist.md"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_has_perceivable(self):
        assert "Perceivable" in self.content, "Must have WCAG Perceivable section"

    def test_has_operable(self):
        assert "Operable" in self.content, "Must have WCAG Operable section"

    def test_has_understandable(self):
        assert "Understandable" in self.content, "Must have WCAG Understandable section"

    def test_has_robust(self):
        assert "Robust" in self.content, "Must have WCAG Robust section"


# ============================================================
# testing-patterns.md tests
# ============================================================

class TestTestingPatterns:
    """Tests for docs/reference/testing-patterns.md."""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.path = REFERENCE_DIR / "testing-patterns.md"
        self.content = read_file(self.path)

    def test_file_exists(self):
        assert self.path.exists()

    def test_has_20_plus_items(self):
        # Count numbered items (lines starting with a number followed by period)
        numbered = re.findall(r"^\d+\.", self.content, re.MULTILINE)
        assert len(numbered) >= 20, f"Must have 20+ numbered items, found {len(numbered)}"
