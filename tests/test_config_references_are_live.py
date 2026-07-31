"""Configuration must not name things that no longer exist.

A reference to a retired agent, model or CLI does not raise an error — it simply never
resolves. The agent reads the instruction, the delegation fails, and it improvises.
`minimax-reviewer` was ordered as a `subagent_type` in five places for months while never
having existed as a file at all.

These tests pin the cleanup done on 2026-07-31 so the same references cannot drift back.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
AGENTS_DIR = REPO_ROOT / ".claude" / "agents"
SKILLS_DIR = REPO_ROOT / ".claude" / "skills"
SCRIPTS_DIR = REPO_ROOT / ".claude" / "scripts"
MODELS_JSON = REPO_ROOT / "config" / "models.json"

# Agent types resolved by the harness from outside .claude/agents/: built-ins and
# plugin-provided agents. Listing them explicitly keeps the check strict without
# flagging names that do resolve at runtime.
EXTERNAL_AGENT_TYPES = {
    "general-purpose",
    "Explore",
    "Plan",
    "claude",
    "statusline-setup",
    "code-simplicity-reviewer",
}

# Names retired on 2026-07-31 together with the GLM/MiniMax surface and the cc-mirror
# settings trees. None of them can resolve any more.
RETIRED_TOKENS = {
    "cc-mirror": "the ~/.cc-mirror settings trees were removed",
    "minimax-reviewer": "the agent never existed as a file and was retired",
    "glm-reviewer": "the agent was archived",
    "mmc --": "the MiniMax CLI is no longer installed",
    "/glm-mcp": "the glm-mcp skill was retired",
}

# Files that legitimately mention a retired name: archives, changelogs, dated audits and
# the notes explaining the retirement itself.
def _is_historical(path: Path) -> bool:
    parts = set(path.parts)
    return bool(
        parts & {"archive", "_archived", "audits", "plans"}
        or path.name in {"CHANGELOG.md"}
        or path.suffix == ".old"
    )


def _agent_files() -> list[Path]:
    return [p for p in sorted(AGENTS_DIR.glob("*.md")) if p.name != "CLAUDE.md"]


def _known_agent_types() -> set[str]:
    return {p.stem for p in _agent_files()} | EXTERNAL_AGENT_TYPES


def _config_surfaces() -> list[Path]:
    """Live configuration: agents, skills and the scripts they drive."""
    files: list[Path] = []
    files += _agent_files()
    files += [p for p in SKILLS_DIR.glob("*/SKILL.md")]
    files += [p for p in SCRIPTS_DIR.glob("*.sh")] if SCRIPTS_DIR.is_dir() else []
    return [p for p in files if not _is_historical(p)]


@pytest.mark.parametrize("path", _config_surfaces(), ids=lambda p: str(p.relative_to(REPO_ROOT)))
def test_subagent_type_names_an_existing_agent(path: Path):
    """Every `subagent_type` must resolve to an agent that exists."""
    known = _known_agent_types()
    text = path.read_text(encoding="utf-8", errors="replace")
    referenced = set(re.findall(r'subagent_type:\s*["\']([^"\']+)', text))
    unknown = {name for name in referenced if name not in known and not name.startswith("$")}
    assert not unknown, (
        f"{path.relative_to(REPO_ROOT)} orders subagent_type {sorted(unknown)}, which "
        f"resolve to no agent. The Task call fails and the caller improvises. Point them "
        f"at an existing agent or remove the instruction."
    )


def test_models_json_maps_only_existing_agents():
    """`subagent_models` documents routing; naming an absent agent misleads the reader."""
    if not MODELS_JSON.is_file():
        pytest.skip("config/models.json not present")
    mapping = json.loads(MODELS_JSON.read_text(encoding="utf-8")).get("subagent_models", {})
    known = _known_agent_types()
    ghosts = sorted(name for name in mapping if name not in known)
    assert not ghosts, (
        f"config/models.json maps agents that do not exist: {ghosts}. "
        f"Remove the entries or restore the agents."
    )


@pytest.mark.parametrize("path", _config_surfaces(), ids=lambda p: str(p.relative_to(REPO_ROOT)))
def test_no_retired_names_in_live_config(path: Path):
    """Retired tooling must not be named in configuration that is still executed."""
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    documented = re.compile(r"retir|removed|archiv|no longer|deprecat|2026-07-31", re.I)
    found = {}
    for token, why in RETIRED_TOKENS.items():
        for i, line in enumerate(lines):
            if token not in line:
                continue
            # Prose documenting the retirement is not a live reference. The marker may sit
            # a couple of lines earlier — a blockquote explaining a removal wraps across
            # lines, so only the first carries the word "Removed".
            window = lines[max(0, i - 3) : i + 1]
            if any(documented.search(w) for w in window):
                continue
            found.setdefault(token, (why, line.strip()[:100]))
    assert not found, (
        f"{path.relative_to(REPO_ROOT)} still references retired tooling: "
        + "; ".join(f"{tok} ({why}) at {line!r}" for tok, (why, line) in found.items())
    )
