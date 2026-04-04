"""
Tests for v3.0 skills — both NEW and MODIFIED.

Validates SKILL.md structure, frontmatter, versioning,
anti-rationalization tables, and integration markers.
"""

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
SKILLS_DIR = REPO_ROOT / ".claude" / "skills"

# ---------------------------------------------------------------------------
# Skill lists
# ---------------------------------------------------------------------------

NEW_V3_SKILLS = [
    "design-system",
    "spec",
    "context-engineer",
    "browser-test",
    "vault",
    "exit-review",
    "adr",
    "perf",
    "ship",
]

MODIFIED_V3_SKILLS = [
    "orchestrator",
    "adversarial",
    "clarify",
    "task-batch",
    "iterate",
    "gates",
    "autoresearch",
    "create-task-batch",
]

ALL_V3_SKILLS = NEW_V3_SKILLS + MODIFIED_V3_SKILLS

# Skills that have an Anti-Rationalization section with a table (>= 3 rows)
SKILLS_WITH_ANTI_RATIONALIZATION = [
    "spec",
    "context-engineer",
    "browser-test",
    "vault",
    "ship",
    "orchestrator",
    "iterate",
    "task-batch",
    "gates",
    "autoresearch",
]

# Skills expected to have Aristotle integration content
ARISTOTLE_SKILLS = [
    "orchestrator",
    "adversarial",
    "clarify",
]

# Modified skills that do NOT have user-invocable: true in frontmatter
SKILLS_WITHOUT_USER_INVOCABLE = [
    "adversarial",
]

# Deleted hooks that must NOT be referenced
DELETED_HOOKS = [
    "validate-lsp-servers",
    "plan-state-init",
    "semantic-auto-extractor",
    "auto-save-context",
    "context-injector",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _read_skill(name: str) -> str:
    """Return the full text of a SKILL.md file."""
    path = SKILLS_DIR / name / "SKILL.md"
    return path.read_text(encoding="utf-8")


def _frontmatter(text: str) -> str:
    """Extract YAML frontmatter between --- delimiters."""
    match = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    assert match, "No YAML frontmatter found"
    return match.group(1)


def _count_anti_rationalization_rows(text: str) -> int:
    """Count data rows in the Anti-Rationalization markdown table.

    A data row starts with '|' and is NOT the header or separator row.
    We look for the section header first, then count table data rows.
    """
    # Find the Anti-Rationalization section
    pattern = r"(?i)## Anti-Rationalization"
    match = re.search(pattern, text)
    if not match:
        return 0

    section_text = text[match.start():]
    # Stop at next ## heading or end of file
    next_heading = re.search(r"\n## (?!Anti-Rationalization)", section_text[1:])
    if next_heading:
        section_text = section_text[:next_heading.start() + 1]

    # Count table rows: lines starting with | that are not the header separator
    rows = 0
    in_table = False
    for line in section_text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("|") and stripped.endswith("|"):
            # Skip separator rows (|---|---|)
            if re.match(r"^\|[\s\-:|]+\|$", stripped):
                continue
            # Skip header row (first row with text)
            if not in_table:
                in_table = True
                continue
            rows += 1
    return rows


# ===========================================================================
# NEW v3.0 SKILLS — basic structural tests
# ===========================================================================


class TestNewV3SkillsExistence:
    """Test 1: SKILL.md exists for each new v3 skill."""

    @pytest.mark.parametrize("skill", NEW_V3_SKILLS)
    def test_skill_md_exists(self, skill: str) -> None:
        path = SKILLS_DIR / skill / "SKILL.md"
        assert path.exists(), f"{path} does not exist"


class TestNewV3SkillsFrontmatter:
    """Test 2: Each new v3 skill has YAML frontmatter with --- delimiters."""

    @pytest.mark.parametrize("skill", NEW_V3_SKILLS)
    def test_has_yaml_frontmatter(self, skill: str) -> None:
        text = _read_skill(skill)
        assert text.startswith("---\n"), f"{skill}: missing opening ---"
        # Must have a closing --- after the opening one
        second_delim = text.index("---", 4)
        assert second_delim > 4, f"{skill}: missing closing ---"


class TestNewV3SkillsVersion:
    """Test 3: VERSION is 3.0.0 in every new v3 skill."""

    @pytest.mark.parametrize("skill", NEW_V3_SKILLS)
    def test_version_3_0_0(self, skill: str) -> None:
        fm = _frontmatter(_read_skill(skill))
        assert "VERSION: 3.0.0" in fm, f"{skill}: VERSION is not 3.0.0"


class TestNewV3SkillsName:
    """Test 4: 'name' field matches directory name."""

    @pytest.mark.parametrize("skill", NEW_V3_SKILLS)
    def test_name_matches_directory(self, skill: str) -> None:
        fm = _frontmatter(_read_skill(skill))
        match = re.search(r"^name:\s*(.+)$", fm, re.MULTILINE)
        assert match, f"{skill}: no 'name' field in frontmatter"
        name_value = match.group(1).strip().strip('"').strip("'")
        assert name_value == skill, (
            f"{skill}: name field is '{name_value}', expected '{skill}'"
        )


class TestNewV3SkillsDescription:
    """Test 5: 'description' field is present and non-empty."""

    @pytest.mark.parametrize("skill", NEW_V3_SKILLS)
    def test_has_description(self, skill: str) -> None:
        fm = _frontmatter(_read_skill(skill))
        match = re.search(r"^description:\s*(.+)", fm, re.MULTILINE)
        assert match, f"{skill}: no 'description' field in frontmatter"
        desc = match.group(1).strip().strip('"').strip("'")
        assert len(desc) > 0, f"{skill}: description is empty"


class TestNewV3SkillsUserInvocable:
    """Test 6: 'user-invocable: true' is present."""

    @pytest.mark.parametrize("skill", NEW_V3_SKILLS)
    def test_user_invocable_true(self, skill: str) -> None:
        fm = _frontmatter(_read_skill(skill))
        assert "user-invocable: true" in fm, (
            f"{skill}: missing 'user-invocable: true'"
        )


class TestNewV3SkillsAntiRationalization:
    """Test 7: Skills that have Anti-Rationalization section have >= 3 rows."""

    # Only test skills that actually have the section
    NEW_SKILLS_WITH_AR = [
        s for s in NEW_V3_SKILLS if s in SKILLS_WITH_ANTI_RATIONALIZATION
    ]

    @pytest.mark.parametrize("skill", NEW_SKILLS_WITH_AR)
    def test_anti_rationalization_rows(self, skill: str) -> None:
        text = _read_skill(skill)
        row_count = _count_anti_rationalization_rows(text)
        assert row_count >= 3, (
            f"{skill}: Anti-Rationalization table has {row_count} data rows, "
            f"expected >= 3"
        )

    # Skills without Anti-Rationalization should not claim to have one
    NEW_SKILLS_WITHOUT_AR = [
        s for s in NEW_V3_SKILLS if s not in SKILLS_WITH_ANTI_RATIONALIZATION
    ]

    @pytest.mark.parametrize("skill", NEW_SKILLS_WITHOUT_AR)
    def test_no_anti_rationalization_section(self, skill: str) -> None:
        """Skills without Anti-Rationalization do not have the section."""
        text = _read_skill(skill)
        has_section = bool(re.search(r"(?i)## Anti-Rationalization", text))
        assert not has_section, (
            f"{skill}: unexpectedly has Anti-Rationalization section"
        )


class TestNewV3SkillsNoDeletedHooks:
    """Test 8: No reference to deleted hooks."""

    @pytest.mark.parametrize("skill", NEW_V3_SKILLS)
    def test_no_deleted_hook_references(self, skill: str) -> None:
        text = _read_skill(skill)
        for hook in DELETED_HOOKS:
            assert hook not in text, (
                f"{skill}: references deleted hook '{hook}'"
            )


# ===========================================================================
# MODIFIED v3.0 SKILLS
# ===========================================================================


class TestModifiedSkillsVersion:
    """Test 1 (modified): VERSION 3.0.0."""

    @pytest.mark.parametrize("skill", MODIFIED_V3_SKILLS)
    def test_version_3_0_0(self, skill: str) -> None:
        fm = _frontmatter(_read_skill(skill))
        assert "VERSION: 3.0.0" in fm, f"{skill}: VERSION is not 3.0.0"


class TestModifiedSkillsAristotle:
    """Test 2 (modified): Aristotle integration present."""

    @pytest.mark.parametrize("skill", ARISTOTLE_SKILLS)
    def test_aristotle_integration(self, skill: str) -> None:
        text = _read_skill(skill)
        assert re.search(r"(?i)aristotl", text), (
            f"{skill}: missing Aristotle integration content"
        )


class TestModifiedSkillsAntiRationalization:
    """Test 3 (modified): Anti-Rationalization section present with >= 3 rows."""

    MODIFIED_SKILLS_WITH_AR = [
        s for s in MODIFIED_V3_SKILLS if s in SKILLS_WITH_ANTI_RATIONALIZATION
    ]

    @pytest.mark.parametrize("skill", MODIFIED_SKILLS_WITH_AR)
    def test_anti_rationalization_rows(self, skill: str) -> None:
        text = _read_skill(skill)
        row_count = _count_anti_rationalization_rows(text)
        assert row_count >= 3, (
            f"{skill}: Anti-Rationalization table has {row_count} data rows, "
            f"expected >= 3"
        )


class TestModifiedSkillsSlicesFlag:
    """Test 4 (modified): task-batch has --slices flag."""

    def test_task_batch_slices_flag(self) -> None:
        text = _read_skill("task-batch")
        assert "--slices" in text, "task-batch: missing --slices flag"


class TestModifiedSkillsDesignSystemQuestion:
    """Test 5 (modified): create-task-batch asks about design system."""

    def test_create_task_batch_design_system(self) -> None:
        text = _read_skill("create-task-batch")
        assert re.search(r"(?i)design.system", text), (
            "create-task-batch: missing design system question"
        )
        # Specifically check for the DESIGN.md question in Phase 1
        assert "DESIGN.md" in text, (
            "create-task-batch: missing DESIGN.md reference"
        )


class TestModifiedSkillsNoDeletedHooks:
    """Modified skills must not reference deleted hooks."""

    @pytest.mark.parametrize("skill", MODIFIED_V3_SKILLS)
    def test_no_deleted_hook_references(self, skill: str) -> None:
        text = _read_skill(skill)
        for hook in DELETED_HOOKS:
            assert hook not in text, (
                f"{skill}: references deleted hook '{hook}'"
            )


# ===========================================================================
# Cross-cutting tests
# ===========================================================================


class TestAllV3SkillsExist:
    """Every v3 skill directory + SKILL.md exists."""

    @pytest.mark.parametrize("skill", ALL_V3_SKILLS)
    def test_skill_directory_exists(self, skill: str) -> None:
        d = SKILLS_DIR / skill
        assert d.is_dir(), f"{d} is not a directory"

    @pytest.mark.parametrize("skill", ALL_V3_SKILLS)
    def test_skill_md_exists(self, skill: str) -> None:
        path = SKILLS_DIR / skill / "SKILL.md"
        assert path.is_file(), f"{path} does not exist"


class TestAllV3SkillsVersion:
    """Every v3 skill has VERSION 3.0.0."""

    @pytest.mark.parametrize("skill", ALL_V3_SKILLS)
    def test_version_3_0_0(self, skill: str) -> None:
        fm = _frontmatter(_read_skill(skill))
        assert "VERSION: 3.0.0" in fm, f"{skill}: VERSION is not 3.0.0"


class TestAllV3SkillsFrontmatterIntegrity:
    """Frontmatter is well-formed across all v3 skills."""

    @pytest.mark.parametrize("skill", ALL_V3_SKILLS)
    def test_frontmatter_has_name(self, skill: str) -> None:
        fm = _frontmatter(_read_skill(skill))
        assert re.search(r"^name:", fm, re.MULTILINE), (
            f"{skill}: missing 'name' in frontmatter"
        )

    @pytest.mark.parametrize("skill", ALL_V3_SKILLS)
    def test_frontmatter_has_description(self, skill: str) -> None:
        fm = _frontmatter(_read_skill(skill))
        assert re.search(r"^description:", fm, re.MULTILINE), (
            f"{skill}: missing 'description' in frontmatter"
        )

    SKILLS_WITH_USER_INVOCABLE = [
        s for s in ALL_V3_SKILLS if s not in SKILLS_WITHOUT_USER_INVOCABLE
    ]

    @pytest.mark.parametrize("skill", SKILLS_WITH_USER_INVOCABLE)
    def test_frontmatter_has_user_invocable(self, skill: str) -> None:
        fm = _frontmatter(_read_skill(skill))
        assert "user-invocable: true" in fm, (
            f"{skill}: missing 'user-invocable: true'"
        )
