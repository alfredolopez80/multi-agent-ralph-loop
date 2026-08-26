"""Variant A smoke (#46 C4): native operations under the security-only profile.

The profile (.claude/security/settings.security-only.json) registers ONLY the
security plane. This suite proves, hook-by-hook, exactly what the harness
would experience per representative operation:

  - Read          -> NO hook fires (no matcher matches Read): zero overhead,
                     zero impedance.
  - Edit/Write    -> permission-guard + repo-boundary fire and ALLOW a benign
                     in-repo edit.
  - Bash          -> the four Bash-matched security hooks fire and ALLOW a
                     benign command — and BLOCK the destructive one.
  - Skill         -> skill-validator fires and ALLOWS a benign skill.

Also pins the context cost of an allow: the hooks answer with decision JSON
only — no additionalContext is injected, so variant A's model-visible hook
output is zero tokens by construction (measured, not assumed).

The LIVE variant (an actual `claude` session with the profile as its only
settings layer) is a separate probe: scripts + report under results/T82-*,
because it needs a sandboxed HOME and cannot run inside CI.
"""
import json
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
PROFILE_PATH = REPO / ".claude" / "security" / "settings.security-only.json"

PREFIX = "$CLAUDE_PROJECT_DIR/"


def profile_hooks() -> dict:
    """event -> [(matcher, command)] from the variant A profile."""
    profile = json.loads(PROFILE_PATH.read_text())
    out = {}
    for event, blocks in profile["hooks"].items():
        for block in blocks:
            for hook in block["hooks"]:
                out.setdefault(event, []).append(
                    (block["matcher"], hook["command"])
                )
    return out


def matcher_fires(matcher: str, tool: str) -> bool:
    if matcher in ("", "*"):
        return True
    return tool in [part.strip() for part in matcher.split("|")]


def run_hook(command: str, payload: dict) -> dict:
    cmd = str(REPO / command[len(PREFIX):])
    argv = (["python3", cmd] if cmd.endswith(".py") else ["bash", cmd])
    proc = subprocess.run(
        argv, input=json.dumps(payload), capture_output=True, text=True,
        timeout=30, cwd=str(REPO),
    )
    assert proc.returncode in (0, 1), f"{command}: unexpected exit {proc.returncode}"
    out = proc.stdout.strip()
    assert out, f"{command}: no stdout payload"
    first = out.splitlines()[0]
    return json.loads(first)


def decision_of(payload_out: dict) -> str:
    hso = payload_out.get("hookSpecificOutput", {})
    return hso.get("permissionDecision", "")


def hooks_for(event: str, tool: str) -> list:
    return [c for m, c in profile_hooks().get(event, []) if matcher_fires(m, tool)]


BENIGN_BASH = {"session_id": "t82-smoke", "tool_name": "Bash",
               "tool_input": {"command": "python3 -m pytest tests/ -q --co > /dev/null && echo tests-ran"}}
BENIGN_EDIT = {"session_id": "t82-smoke", "tool_name": "Edit",
               "tool_input": {"file_path": str(REPO / "README.md"),
                              "old_string": "a", "new_string": "b"}}
BENIGN_SKILL = {"session_id": "t82-smoke", "hook_event_name": "PreToolUse",
                "tool_name": "Skill",
                "tool_input": {"skill": "gates", "input": ""}}


def test_read_fires_nothing():
    """Read is untouched by the security plane: no matcher matches it."""
    assert hooks_for("PreToolUse", "Read") == []


def test_bash_benign_allowed_and_silent():
    """The four Bash-matched security hooks allow a benign test-run command
    and inject NO context: allow is decision-only."""
    hooks = hooks_for("PreToolUse", "Bash")
    assert len(hooks) == 4, f"expected the 4 Bash-matched hooks, got {hooks}"
    for command in hooks:
        out = run_hook(command, BENIGN_BASH)
        assert decision_of(out) in ("allow", ""), f"{command}: {out}"
        assert "additionalContext" not in out, (
            f"{command}: variant A allow must not inject context"
        )


def test_bash_destructive_blocked():
    """git reset --hard is denied by the plane (git-safety is the control)."""
    payload = {"session_id": "t82-smoke", "tool_name": "Bash",
               "tool_input": {"command": "git reset --hard HEAD"}}
    denied = False
    for command in hooks_for("PreToolUse", "Bash"):
        out = run_hook(command, payload)
        if decision_of(out) == "deny":
            denied = True
    assert denied, "the security plane must deny a destructive git command"


def test_edit_benign_allowed():
    hooks = hooks_for("PreToolUse", "Edit")
    assert len(hooks) == 2, f"expected permission-guard + repo-boundary, got {hooks}"
    for command in hooks:
        out = run_hook(command, BENIGN_EDIT)
        assert decision_of(out) in ("allow", ""), f"{command}: {out}"


def test_skill_benign_allowed():
    hooks = hooks_for("PreToolUse", "Skill")
    assert len(hooks) == 1
    out = run_hook(hooks[0], BENIGN_SKILL)
    assert decision_of(out) in ("allow", ""), f"{hooks[0]}: {out}"
