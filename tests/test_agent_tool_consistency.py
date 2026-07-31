"""Consistency tests between what an agent's prompt orders and what its frontmatter allows.

An agent is misconfigured when its body instructs an action its `tools` field forbids.
That contradiction is silent at runtime: the agent reads the instruction, cannot execute
it, and improvises. These tests turn it into a build failure.

Covers the defect classes found in the 2026-07-31 agent audit:
  1. `allowed-tools:` used instead of `tools:` (skill/command field, ignored on agents ->
     the agent silently inherits EVERY tool).
  2. Body orders spawning another agent (`subagent_type: "other"`) without the Task tool.
  3. Body contains executable shell blocks without any Bash tool.
  4. Body orders an MCP server the declared tools do not cover.
  5. Body invokes an existing skill (`/name`) without the Skill tool.
  6. `name:` disagreeing with the filename, or frontmatter that is not valid YAML.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
AGENTS_DIR = REPO_ROOT / ".claude" / "agents"
SKILLS_DIR = REPO_ROOT / ".claude" / "skills"
MCP_CONFIG = Path.home() / ".claude.json"

# Files in .claude/agents/ that are not agent definitions.
NON_AGENT_FILES = {"CLAUDE.md"}

# Gaps accepted for a documented reason. Each entry is verified in BOTH directions:
# the gap must still be present. When it is fixed, test_known_gaps_are_still_gaps
# fails so the exemption is removed instead of quietly outliving the problem.
KNOWN_GAPS: dict[tuple[str, str], str] = {
    # Both prior exemptions were resolved on 2026-07-31:
    #   glm-reviewer  — the agent was retired with the rest of the GLM/MiniMax surface.
    #   plan-sync     — its body ordered `jq` while the frontmatter sets
    #                   `disallowedTools: Bash`. The prompt was the bug, not the tools:
    #                   plan-state.json is JSON and is now read with the Read tool.
}

# MCP servers referenced by agent prompts but absent from ~/.claude.json. Declaring them
# in `tools` would grant nothing, so they are excluded from the citation check. If one
# ever gets installed, test_uninstalled_mcp_are_still_absent fails so it is declared
# properly instead of staying invisible.
# Empty on purpose. It previously exempted MiniMax, blender and nanobanana so that
# prompts could keep ordering servers that are not installed. Exempting a live defect is
# not coverage: blender-3d-creator was archived (all three of its servers were missing,
# so it could not work) and orchestrator's dead MiniMax instructions were removed. If an
# entry is ever needed again, it must name a server the prompts genuinely cannot drop.
UNINSTALLED_MCP: dict[str, str] = {}

def _agent_files() -> list[Path]:
    files = sorted(p for p in AGENTS_DIR.glob("*.md") if p.name not in NON_AGENT_FILES)
    if not files:
        raise AssertionError(f"No agent definitions found in {AGENTS_DIR}")
    return files


def _split_frontmatter(path: Path) -> tuple[str, str]:
    """Return (frontmatter, body). Raises if the file has no frontmatter block."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        raise AssertionError(f"{path.name}: missing YAML frontmatter block")
    end = text.find("\n---", 3)
    if end < 0:
        raise AssertionError(f"{path.name}: frontmatter block is never closed")
    return text[3:end], text[end + 4 :]


def _parse_tools(frontmatter: str) -> list[str] | None:
    """Declared tools, or None when the agent declares none (inherits everything).

    Accepts the three syntaxes present in the repo: CSV inline, JSON array and YAML list.
    """
    # `[ \t]*` and not `\s*`: `\s` matches newlines, so on a YAML list the group would
    # swallow the line break and capture the first item ("- Read") as an inline value.
    match = re.search(r"^tools:[ \t]*(.*)$", frontmatter, re.M)
    if not match:
        return None
    inline = match.group(1).strip()
    if inline.startswith("["):
        return [str(t).strip() for t in json.loads(inline)]
    if inline:
        return [t.strip() for t in inline.split(",") if t.strip()]
    items = []
    for line in frontmatter[match.end() :].splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            items.append(stripped[2:].strip())
        elif stripped and not stripped.startswith("#"):
            break
    return items


def _has_tool(tools: list[str], name: str) -> bool:
    """True when `name` is granted, ignoring any `Tool(pattern)` restriction suffix."""
    return any(re.sub(r"\(.*", "", t).strip() == name for t in tools)


def _shell_commands(body: str) -> list[str]:
    """Executable lines inside ```bash/sh/shell fences, excluding comments."""
    commands = []
    for block in re.finditer(r"```(?:bash|sh|shell)\n(.*?)```", body, re.S):
        for line in block.group(1).splitlines():
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                commands.append(stripped)
    return commands


def _existing_skill_names() -> set[str]:
    return {p.name for p in SKILLS_DIR.iterdir() if (p / "SKILL.md").is_file()}


requires_mcp_config = pytest.mark.skipif(
    not MCP_CONFIG.is_file(),
    reason=f"{MCP_CONFIG} not present (expected on CI; this validates a local install)",
)


def _installed_mcp_servers() -> set[str]:
    if not MCP_CONFIG.is_file():
        raise AssertionError(f"MCP config not found at {MCP_CONFIG}")
    return set(json.loads(MCP_CONFIG.read_text(encoding="utf-8")).get("mcpServers", {}))


AGENT_FILES = _agent_files()
AGENT_IDS = [p.stem for p in AGENT_FILES]


def _exempt(agent: str, rule: str) -> bool:
    return (agent, rule) in KNOWN_GAPS


# --------------------------------------------------------------------------------------
# Structural checks
# --------------------------------------------------------------------------------------


@pytest.mark.parametrize("path", AGENT_FILES, ids=AGENT_IDS)
def test_frontmatter_is_valid_yaml(path: Path):
    frontmatter, _ = _split_frontmatter(path)
    parsed = yaml.safe_load(frontmatter)
    assert isinstance(parsed, dict), (
        f"{path.name}: frontmatter must parse to a mapping, got {type(parsed).__name__}. "
        "A common cause is an unquoted `description:` containing a colon."
    )


@pytest.mark.parametrize("path", AGENT_FILES, ids=AGENT_IDS)
def test_name_matches_filename(path: Path):
    frontmatter, _ = _split_frontmatter(path)
    declared = yaml.safe_load(frontmatter).get("name")
    assert declared == path.stem, (
        f"{path.name}: frontmatter name is {declared!r} but the filename implies "
        f"{path.stem!r}. Claude Code resolves agents by filename, so they must agree."
    )


# Values Claude Code accepts for an agent's `model:`. A tier alias, `inherit`, or a
# concrete model id. Anything else makes the agent fail to launch.
VALID_MODEL_TIERS = {"opus", "sonnet", "haiku", "fable", "inherit"}


@pytest.mark.parametrize("path", AGENT_FILES, ids=AGENT_IDS)
def test_model_field_is_launchable(path: Path):
    """An unrecognised `model:` makes the agent uninvocable — it fails at launch.

    Found on 2026-07-31: ralph-security declared `model: default`, which is not a valid
    value, so spawning it errored with "issue with the selected model (default)". One of
    the six ralph teammates could not be launched at all, and nothing flagged it.
    """
    frontmatter, _ = _split_frontmatter(path)
    match = re.search(r"^model:\s*(.+)$", frontmatter, re.M)
    if not match:
        return  # no field: inherits from the session, which is valid
    model = match.group(1).strip().strip("\"'")
    is_tier = model in VALID_MODEL_TIERS
    is_concrete = model.startswith(("claude-", "glm-", "gpt-", "kimi-"))
    assert is_tier or is_concrete, (
        f"{path.name}: `model: {model}` is not launchable. Use one of "
        f"{sorted(VALID_MODEL_TIERS)}, a concrete model id, or omit the field to inherit."
    )


# Permission modes Claude Code accepts. Note `default` IS valid here but NOT for
# `model:` — that asymmetry is very likely how `model: default` got written.
VALID_PERMISSION_MODES = {
    "default", "acceptEdits", "plan", "bypassPermissions", "dontAsk", "auto",
}


@pytest.mark.parametrize("path", AGENT_FILES, ids=AGENT_IDS)
def test_permission_mode_is_valid(path: Path):
    frontmatter, _ = _split_frontmatter(path)
    match = re.search(r"^permissionMode:\s*(.+)$", frontmatter, re.M)
    if not match:
        return
    mode = match.group(1).strip().strip("\"'")
    assert mode in VALID_PERMISSION_MODES, (
        f"{path.name}: `permissionMode: {mode}` is not a recognised mode. "
        f"Valid: {sorted(VALID_PERMISSION_MODES)}."
    )


@pytest.mark.parametrize("path", AGENT_FILES, ids=AGENT_IDS)
def test_does_not_use_allowed_tools_field(path: Path):
    """`allowed-tools:` belongs to skills/commands. On an agent it is ignored entirely,
    so the agent silently inherits every tool instead of the intended sandbox."""
    frontmatter, _ = _split_frontmatter(path)
    assert not re.search(r"^allowed-tools:", frontmatter, re.M), (
        f"{path.name}: uses `allowed-tools:`, which Claude Code ignores on agents. "
        "The agent therefore inherits ALL tools rather than the declared sandbox. "
        "Rename the field to `tools:`."
    )


# --------------------------------------------------------------------------------------
# Prompt-vs-tools contradiction checks
# --------------------------------------------------------------------------------------


@pytest.mark.parametrize("path", AGENT_FILES, ids=AGENT_IDS)
def test_spawning_another_agent_requires_task_tool(path: Path):
    frontmatter, body = _split_frontmatter(path)
    tools = _parse_tools(frontmatter)
    if tools is None or _has_tool(tools, "Task") or _exempt(path.stem, "task"):
        return
    # `subagent_type: "<own name>"` documents how to invoke THIS agent; only a foreign
    # name is an order for this agent to spawn something.
    foreign = {s for s in re.findall(r'subagent_type:\s*["\']([^"\']+)', body) if s != path.stem}
    assert not foreign, (
        f"{path.name}: body orders spawning {sorted(foreign)} but does not declare the "
        f"Task tool (declares: {', '.join(tools)}). Add Task or remove the instruction."
    )


@pytest.mark.parametrize("path", AGENT_FILES, ids=AGENT_IDS)
def test_shell_blocks_require_bash_tool(path: Path):
    frontmatter, body = _split_frontmatter(path)
    tools = _parse_tools(frontmatter)
    if tools is None or _has_tool(tools, "Bash") or _exempt(path.stem, "bash"):
        return
    commands = _shell_commands(body)
    assert not commands, (
        f"{path.name}: body contains {len(commands)} executable shell line(s) but "
        f"declares no Bash tool (declares: {', '.join(tools)}). "
        f"First command: {commands[0]!r}"
    )


@pytest.mark.parametrize("path", AGENT_FILES, ids=AGENT_IDS)
def test_cited_mcp_servers_are_declared(path: Path):
    frontmatter, body = _split_frontmatter(path)
    tools = _parse_tools(frontmatter)
    if tools is None or _exempt(path.stem, "mcp"):
        return
    cited = {m.split("__")[1] for m in re.findall(r"mcp__[A-Za-z0-9_-]+__", body)}
    declared = {t.split("__")[1] for t in tools if t.startswith("mcp__")}
    missing = cited - declared - set(UNINSTALLED_MCP)
    assert not missing, (
        f"{path.name}: body orders MCP server(s) {sorted(missing)} that the tools field "
        f"does not grant (declares: {', '.join(tools)}). Add `mcp__<server>__*` entries."
    )


@pytest.mark.parametrize("path", AGENT_FILES, ids=AGENT_IDS)
def test_invoked_skills_require_skill_tool(path: Path):
    frontmatter, body = _split_frontmatter(path)
    tools = _parse_tools(frontmatter)
    if tools is None or _has_tool(tools, "Skill") or _exempt(path.stem, "skill"):
        return
    # Only count slash names that resolve to a real skill, so file paths and prose
    # cannot masquerade as invocations.
    existing = _existing_skill_names()
    invoked = {m for m in re.findall(r"(?:^|\s)/([a-z][a-z0-9-]{2,})", body) if m in existing}
    assert not invoked, (
        f"{path.name}: body invokes skill(s) {sorted(invoked)} but does not declare the "
        f"Skill tool (declares: {', '.join(tools)})."
    )


# --------------------------------------------------------------------------------------
# Exemption hygiene
# --------------------------------------------------------------------------------------


def test_known_gaps_reference_existing_agents():
    names = set(AGENT_IDS)
    unknown = {agent for agent, _ in KNOWN_GAPS if agent not in names}
    assert not unknown, (
        f"KNOWN_GAPS references agents that no longer exist: {sorted(unknown)}. "
        "Remove the stale entries."
    )


def test_known_gaps_are_still_gaps():
    """An exemption that no longer describes a real gap must be deleted.

    Without this, KNOWN_GAPS rots into a permanent allowlist that hides regressions.
    """
    stale = []
    for agent, rule in KNOWN_GAPS:
        path = AGENTS_DIR / f"{agent}.md"
        frontmatter, body = _split_frontmatter(path)
        tools = _parse_tools(frontmatter)
        if tools is None:
            stale.append(f"{agent}/{rule} (agent now declares no tools)")
            continue
        if rule == "task":
            foreign = {
                s for s in re.findall(r'subagent_type:\s*["\']([^"\']+)', body) if s != agent
            }
            if _has_tool(tools, "Task") or not foreign:
                stale.append(f"{agent}/{rule}")
        elif rule == "bash":
            if _has_tool(tools, "Bash") or not _shell_commands(body):
                stale.append(f"{agent}/{rule}")
        elif rule == "mcp":
            cited = {m.split("__")[1] for m in re.findall(r"mcp__[A-Za-z0-9_-]+__", body)}
            declared = {t.split("__")[1] for t in tools if t.startswith("mcp__")}
            if not cited - declared - set(UNINSTALLED_MCP):
                stale.append(f"{agent}/{rule}")
        elif rule == "skill":
            existing = _existing_skill_names()
            invoked = {
                m for m in re.findall(r"(?:^|\s)/([a-z][a-z0-9-]{2,})", body) if m in existing
            }
            if _has_tool(tools, "Skill") or not invoked:
                stale.append(f"{agent}/{rule}")
        else:
            raise AssertionError(f"KNOWN_GAPS uses unknown rule {rule!r} for {agent}")
    assert not stale, (
        f"These exemptions no longer describe a real gap: {sorted(stale)}. "
        "The underlying issue was fixed — delete the KNOWN_GAPS entry."
    )


@requires_mcp_config
def test_uninstalled_mcp_are_still_absent():
    """Once a cited-but-missing server is installed, it must be declared in `tools`."""
    now_installed = set(UNINSTALLED_MCP) & _installed_mcp_servers()
    assert not now_installed, (
        f"These MCP servers are now installed: {sorted(now_installed)}. Remove them from "
        "UNINSTALLED_MCP and add `mcp__<server>__*` to the agents that cite them."
    )


@requires_mcp_config
def test_declared_mcp_servers_are_installed():
    """A tools entry naming an uninstalled MCP server grants nothing at runtime."""
    installed = _installed_mcp_servers()
    offenders = {}
    for path in AGENT_FILES:
        frontmatter, _ = _split_frontmatter(path)
        tools = _parse_tools(frontmatter)
        if tools is None:
            continue
        missing = {t.split("__")[1] for t in tools if t.startswith("mcp__")} - installed
        if missing:
            offenders[path.stem] = sorted(missing)
    assert not offenders, (
        f"Agents declare MCP servers that are not installed in {MCP_CONFIG}: {offenders}. "
        "Install the server or remove the tools entry."
    )
