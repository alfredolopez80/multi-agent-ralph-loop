#!/usr/bin/env python3
"""
Tests for slash command definitions in .claude/commands.

Validates frontmatter structure, metadata, and content for all commands.
Run with: pytest tests/test_slash_commands.py -v
"""

import re
from pathlib import Path

import pytest
import yaml

COMMANDS_DIR = Path(".claude/commands")

EXPECTED_COMMANDS = [
    "adversarial.md",
    "ast-search.md",
    "audit.md",
    "blender-3d.md",
    "blender-status.md",
    "browse.md",
    "bugs.md",
    "checkpoint-clear.md",
    "checkpoint-list.md",
    "checkpoint-restore.md",
    "checkpoint-save.md",
    "clarify.md",
    "commands.md",
    "diagram.md",
    "full-review.md",
    "gates.md",
    "image-analyze.md",
    "image-to-3d.md",
    "improvements.md",
    "library-docs.md",
    "loop.md",
    "minimax-search.md",
    "minimax.md",
    "orchestrator.md",
    "parallel.md",
    "prd.md",
    "refactor.md",
    "research.md",
    "retrospective.md",
    "security-loop.md",
    "security.md",
    "skill.md",
    "unit-tests.md",
]

CATEGORY_COLORS = {
    "orchestration": "purple",
    "review": "red",
    "research": "blue",
    "tools": "green",
}

PREFIX_RE = re.compile(r"^@[a-z0-9][a-z0-9_-]*$", re.IGNORECASE)


@pytest.fixture(scope="session")
def command_paths():
    return {name: COMMANDS_DIR / name for name in EXPECTED_COMMANDS}


@pytest.fixture(scope="session")
def all_command_files():
    return list(COMMANDS_DIR.glob("*.md"))


def extract_frontmatter(text: str):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, text.strip()

    end_index = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_index = i
            break

    if end_index is None:
        return None, ""

    frontmatter_text = "\n".join(lines[1:end_index]).strip()
    content = "\n".join(lines[end_index + 1 :]).strip()
    return frontmatter_text, content


def load_command(path: Path):
    text = path.read_text(encoding="utf-8")
    frontmatter_text, content = extract_frontmatter(text)
    frontmatter = None
    if frontmatter_text is not None:
        frontmatter = yaml.safe_load(frontmatter_text)
    return frontmatter_text, frontmatter, content


def test_expected_command_files_present(command_paths):
    for name, path in command_paths.items():
        assert path.exists(), f"Missing command file: {name}"


def test_all_command_files_are_expected(all_command_files):
    found = sorted([p.name for p in all_command_files])
    expected = sorted(EXPECTED_COMMANDS)
    assert found == expected, (
        "Command files in .claude/commands do not match expected list"
    )


def test_commands_directory_exists():
    assert COMMANDS_DIR.exists(), ".claude/commands directory should exist"


def test_expected_command_count():
    assert len(EXPECTED_COMMANDS) == 33, "Expected exactly 33 command files"


@pytest.mark.parametrize("command_name", EXPECTED_COMMANDS)
def test_command_has_frontmatter_and_content(command_name, command_paths):
    path = command_paths[command_name]
    frontmatter_text, frontmatter, content = load_command(path)
    assert frontmatter_text is not None, f"Missing frontmatter in {command_name}"
    assert frontmatter is not None, (
        f"Frontmatter YAML failed to parse in {command_name}"
    )
    assert content, f"No content beyond frontmatter in {command_name}"


@pytest.mark.parametrize("command_name", EXPECTED_COMMANDS)
def test_frontmatter_fields_and_values(command_name, command_paths):
    path = command_paths[command_name]
    _, frontmatter, _ = load_command(path)
    assert isinstance(frontmatter, dict), (
        f"Frontmatter should be a mapping in {command_name}"
    )

    required = ["name", "prefix", "category", "color", "description"]
    for key in required:
        assert key in frontmatter, f"Missing '{key}' in frontmatter for {command_name}"
        assert frontmatter[key], f"Empty '{key}' in frontmatter for {command_name}"

    prefix = frontmatter["prefix"]
    assert PREFIX_RE.match(prefix), f"Invalid prefix format in {command_name}: {prefix}"

    category = frontmatter["category"]
    assert category in CATEGORY_COLORS, (
        f"Invalid category in {command_name}: {category}"
    )

    color = frontmatter["color"]
    assert color == CATEGORY_COLORS[category], (
        f"Color '{color}' does not match category '{category}' in {command_name}"
    )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
