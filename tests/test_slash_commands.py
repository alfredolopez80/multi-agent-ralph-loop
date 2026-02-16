#!/usr/bin/env python3
"""
Tests for slash command definitions in .claude/skills.

Validates SKILL.md structure and content for all skills.
Run with: pytest tests/test_slash_commands.py -v

VERSION: 2.0.0
UPDATED: 2026-02-16 - Migrated from commands to skills (v2.87+ architecture)

NOTE: As of v2.87.0, commands are unified as skills under .claude/skills/<name>/SKILL.md.
The old .claude/commands/ directory is deprecated.
"""

import re
from pathlib import Path

import pytest

SKILLS_DIR = Path(".claude/skills")

# Core skills that must exist (v2.89.2+)
EXPECTED_SKILLS = [
    "adversarial",
    "audit",
    "bugs",
    "clarify",
    "code-reviewer",
    "codex-cli",
    "create-task-batch",
    "curator",
    "curator-repo-learn",
    "edd",
    "gates",
    "gemini-cli",
    "glm5",
    "glm5-parallel",
    "loop",
    "minimax",
    "orchestrator",
    "parallel",
    "plan",
    "prd",
    "quality-gates-parallel",
    "research",
    "retrospective",
    "security",
    "task-batch",
]


@pytest.fixture(scope="session")
def skill_paths():
    return {name: SKILLS_DIR / name / "SKILL.md" for name in EXPECTED_SKILLS}


@pytest.fixture(scope="session")
def all_skill_dirs():
    if not SKILLS_DIR.exists():
        return []
    return [d for d in SKILLS_DIR.iterdir() if d.is_dir() and (d / "SKILL.md").exists()]


def test_skills_directory_exists():
    """Skills directory should exist (v2.87+ architecture)."""
    assert SKILLS_DIR.exists(), ".claude/skills directory should exist"


def test_expected_skills_present(skill_paths):
    """All expected core skills should have SKILL.md files."""
    missing = []
    for name, path in skill_paths.items():
        if not path.exists():
            missing.append(name)
    assert not missing, f"Missing skills: {missing}"


def test_expected_skill_count():
    """Verify expected skills count."""
    assert len(EXPECTED_SKILLS) >= 25, (
        f"Expected at least 25 core skills, got {len(EXPECTED_SKILLS)}"
    )


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_has_content(skill_name, skill_paths):
    """Each skill SKILL.md should have meaningful content."""
    path = skill_paths[skill_name]
    if not path.exists():
        pytest.skip(f"Skill {skill_name} not found")
    content = path.read_text(encoding="utf-8")
    assert len(content) > 50, f"Skill {skill_name} SKILL.md has too little content"


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_has_title(skill_name, skill_paths):
    """Each skill should have a markdown title."""
    path = skill_paths[skill_name]
    if not path.exists():
        pytest.skip(f"Skill {skill_name} not found")
    content = path.read_text(encoding="utf-8")
    assert re.search(r"^#\s+", content, re.MULTILINE), (
        f"Skill {skill_name} should have a markdown title"
    )


# Legacy compatibility - skip if old commands directory doesn't exist
def test_commands_directory_deprecated():
    """The old .claude/commands directory should not exist (migrated to skills in v2.87)."""
    commands_dir = Path(".claude/commands")
    if commands_dir.exists():
        pytest.skip(
            ".claude/commands still exists - legacy directory, "
            "commands migrated to .claude/skills/ in v2.87"
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
