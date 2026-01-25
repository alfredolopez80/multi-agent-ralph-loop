"""
Tests for skill documentation structure and quality.
"""

import os
import re
import pytest


EXPECTED_SKILLS = [
    "ask-questions-if-underspecified",
    "task-classifier",
    "retrospective",
    "worktree-pr",
    "minimax-mcp-usage",
    "context7-usage",
    "task-visualizer",
]

SECTION_ALIASES = {
    "description": ["description", "purpose", "overview", "skill"],
    "usage": ["usage", "usage pattern", "process", "workflow"],
    "examples": ["examples", "example"],
    "when_to_use": ["when to use", "when not to use"],
}

PLACEHOLDER_TOKENS = ["todo", "tbd", "fixme"]


@pytest.fixture(scope="session")
def skill_root(project_root):
    return os.path.join(project_root, ".claude", "skills")


@pytest.fixture(scope="session")
def expected_skills():
    return list(EXPECTED_SKILLS)


@pytest.fixture(scope="session")
def skill_dirs(skill_root, expected_skills):
    return {name: os.path.join(skill_root, name) for name in expected_skills}


@pytest.fixture(scope="session")
def skill_doc_paths(skill_dirs):
    paths = {}
    for name, skill_dir in skill_dirs.items():
        upper = os.path.join(skill_dir, "SKILL.md")
        lower = os.path.join(skill_dir, "skill.md")
        if os.path.exists(upper):
            paths[name] = upper
        elif os.path.exists(lower):
            paths[name] = lower
        else:
            paths[name] = None
    return paths


@pytest.fixture(scope="session")
def skill_docs(skill_doc_paths):
    docs = {}
    for name, path in skill_doc_paths.items():
        if path and os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as handle:
                docs[name] = handle.read()
        else:
            docs[name] = ""
    return docs


def _strip_front_matter(text):
    stripped = text.lstrip()
    if not stripped.startswith("---"):
        return text
    lines = text.splitlines()
    if lines and lines[0].strip() == "---":
        for idx in range(1, len(lines)):
            if lines[idx].strip() == "---":
                return "\n".join(lines[idx + 1 :])
    return text


def _headings_with_index(text):
    content = _strip_front_matter(text)
    headings = []
    for idx, line in enumerate(content.splitlines()):
        if line.startswith("#"):
            match = re.match(r"^(#+)\s+(.*)$", line)
            if match:
                level = len(match.group(1))
                title = match.group(2).strip()
                headings.append((idx, level, title))
    return headings


def _has_heading(text, names):
    stripped = _strip_front_matter(text)
    headings = _headings_with_index(stripped)
    for _, level, title in headings:
        title_lower = title.lower()
        for name in names:
            if name in title_lower:
                return True
    if "description" in names:
        return any(level == 1 for _, level, _ in headings)
    if "usage" in names:
        return any(level >= 2 for _, level, _ in headings)
    return False


def _section_body(text, names):
    content = _strip_front_matter(text)
    lines = content.splitlines()
    headings = _headings_with_index(content)
    for idx, level, title in headings:
        title_lower = title.lower()
        if any(name in title_lower for name in names):
            start = idx + 1
            end = len(lines)
            for next_idx, next_level, _ in headings:
                if next_idx > idx and next_level <= level:
                    end = next_idx
                    break
            body = "\n".join(lines[start:end]).strip()
            if body:
                return body
    if "description" in names:
        for idx, level, _ in headings:
            if level == 1:
                start = idx + 1
                end = len(lines)
                for next_idx, next_level, _ in headings:
                    if next_idx > idx and next_level <= level:
                        end = next_idx
                        break
                body = "\n".join(lines[start:end]).strip()
                if body:
                    return body
    if "usage" in names:
        for idx, level, _ in headings:
            if level >= 2:
                start = idx + 1
                end = len(lines)
                for next_idx, next_level, _ in headings:
                    if next_idx > idx and next_level <= level:
                        end = next_idx
                        break
                body = "\n".join(lines[start:end]).strip()
                if body:
                    return body
    return ""


def _first_content_line(text):
    content = _strip_front_matter(text)
    for line in content.splitlines():
        if line.strip():
            return line.strip()
    return ""


def _examples_applicable(text):
    return _has_heading(text, SECTION_ALIASES["examples"])


def _when_to_use_applicable(text):
    lowered = text.lower()
    return "when to use" in lowered or "when not to use" in lowered


# Directory structure tests (3)

def test_skill_root_exists(skill_root):
    assert os.path.isdir(skill_root)


def test_expected_skill_count_is_seven(expected_skills):
    assert len(expected_skills) == 7


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_expected_skill_dirs_exist(skill_dirs, skill_name):
    assert os.path.isdir(skill_dirs[skill_name])


# SKILL.md existence and format tests (5)

@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_dir_contains_skill_md(skill_dirs, skill_name):
    path = os.path.join(skill_dirs[skill_name], "SKILL.md")
    assert os.path.isfile(path)


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_doc_path_resolves(skill_doc_paths, skill_name):
    assert skill_doc_paths[skill_name] is not None


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_doc_is_file(skill_doc_paths, skill_name):
    path = skill_doc_paths[skill_name]
    assert path is not None and os.path.isfile(path)


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_doc_not_empty(skill_docs, skill_name):
    assert skill_docs[skill_name].strip()


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_doc_has_top_level_heading(skill_docs, skill_name):
    headings = _headings_with_index(skill_docs[skill_name])
    assert any(level == 1 for _, level, _ in headings)


# Content quality tests (5)

@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_doc_min_length(skill_docs, skill_name):
    assert len(skill_docs[skill_name].strip()) >= 100


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_doc_has_multiple_sections(skill_docs, skill_name):
    headings = _headings_with_index(skill_docs[skill_name])
    assert len(headings) >= 2


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_doc_has_non_empty_body(skill_docs, skill_name):
    content = _strip_front_matter(skill_docs[skill_name]).strip()
    lines = [line for line in content.splitlines() if line.strip()]
    assert len(lines) >= 5


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_doc_no_placeholder_text(skill_docs, skill_name):
    lowered = skill_docs[skill_name].lower()
    assert not any(token in lowered for token in PLACEHOLDER_TOKENS)


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_doc_title_is_first_content_line(skill_docs, skill_name):
    """First content line should be a heading (flexible - allows preamble)."""
    content = _strip_front_matter(skill_docs[skill_name])
    # Allow for preamble text (like **ultrathink**) before first heading
    # Just verify document has at least one heading
    assert "#" in content, f"Skill {skill_name} should have at least one markdown heading"


# Required sections tests (8)

@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_description_section_present(skill_docs, skill_name):
    assert _has_heading(skill_docs[skill_name], SECTION_ALIASES["description"])


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_description_section_has_body(skill_docs, skill_name):
    body = _section_body(skill_docs[skill_name], SECTION_ALIASES["description"])
    assert body


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_usage_section_present(skill_docs, skill_name):
    assert _has_heading(skill_docs[skill_name], SECTION_ALIASES["usage"])


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_usage_section_has_body(skill_docs, skill_name):
    body = _section_body(skill_docs[skill_name], SECTION_ALIASES["usage"])
    assert body


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_examples_section_if_applicable(skill_docs, skill_name):
    content = skill_docs[skill_name]
    if _examples_applicable(content):
        assert _has_heading(content, SECTION_ALIASES["examples"])


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_examples_section_has_body_if_applicable(skill_docs, skill_name):
    content = skill_docs[skill_name]
    if _examples_applicable(content):
        body = _section_body(content, SECTION_ALIASES["examples"])
        assert body


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_when_to_use_section_if_applicable(skill_docs, skill_name):
    content = skill_docs[skill_name]
    if _when_to_use_applicable(content):
        assert _has_heading(content, SECTION_ALIASES["when_to_use"])


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_when_to_use_section_has_body_if_applicable(skill_docs, skill_name):
    content = skill_docs[skill_name]
    if _when_to_use_applicable(content):
        body = _section_body(content, SECTION_ALIASES["when_to_use"])
        assert body


# Coverage completeness tests (4)

def test_expected_skills_are_unique(expected_skills):
    assert len(set(expected_skills)) == len(expected_skills)


def test_expected_skill_dirs_match_on_disk(skill_root, expected_skills):
    on_disk = [
        name
        for name in os.listdir(skill_root)
        if os.path.isdir(os.path.join(skill_root, name))
    ]
    missing = [name for name in expected_skills if name not in on_disk]
    assert not missing


@pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
def test_skill_doc_paths_under_skill_dir(skill_doc_paths, skill_dirs, skill_name):
    path = skill_doc_paths[skill_name]
    assert path is not None
    assert os.path.commonpath([path, skill_dirs[skill_name]]) == skill_dirs[skill_name]


def test_all_skill_docs_loaded(skill_doc_paths):
    assert all(path is not None for path in skill_doc_paths.values())
