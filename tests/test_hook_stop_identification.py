"""Every hook that can stop or block must say which hook it was.

A hook that halts a turn without naming itself turns a fixable problem into a mystery:
the transcript shows only "PreToolUse:Edit hook stopped continuation", and with several
hooks matching the same tool there is no way to tell which one fired. Hooks that DO name
themselves (git-safety-guard, repo-boundary-guard) are actionable immediately.

These tests also lock in the two mechanics that made `universal-aristotle-gate.sh` fail
silently on 2026-07-31:
  * `{"continue": false}` surfaces `stopReason`, NOT `reason`. Using `reason` discards
    the explanation.
  * PreToolUse vetoes a call with `permissionDecision: "deny"`. `continue: false` halts
    the turn *after* the tool already ran, which reads as "the edit applied but my turn
    was cut" — the exact symptom observed.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
HOOKS_DIR = REPO_ROOT / ".claude" / "hooks"
SETTINGS = Path.home() / ".claude" / "settings.json"

HOOK_SUFFIXES = {".sh", ".py", ".mjs", ".js"}

# Emissions that stop or veto something. Comment lines are stripped before matching.
BLOCK_PATTERNS = (
    re.compile(r'permissionDecision"?\s*:\s*\\?"?(deny|ask)'),
    re.compile(r'"decision"\s*:\s*"block"|decision:\s*"block"'),
    re.compile(r'"?continue"?\\?"?\s*:\s*\\?"?false'),
)

# Fields whose text reaches the user. A hook must name itself inside one of these.
MESSAGE_FIELDS = re.compile(
    r"permissionDecisionReason|stopReason|\breason\b|systemMessage|BLOCKED by"
)


def _hook_files() -> list[Path]:
    files = sorted(p for p in HOOKS_DIR.iterdir() if p.is_file() and p.suffix in HOOK_SUFFIXES)
    if not files:
        raise AssertionError(f"No hooks found in {HOOKS_DIR}")
    return files


def _code_lines(path: Path) -> list[str]:
    """Source lines with comment-only lines removed, so docs never satisfy a check."""
    out = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.strip()
        if stripped.startswith("#") or stripped.startswith("//"):
            continue
        out.append(line)
    return out


def _blocking_lines(path: Path) -> list[tuple[int, str]]:
    return [
        (i, line)
        for i, line in enumerate(_code_lines(path))
        if any(p.search(line) for p in BLOCK_PATTERNS)
    ]


def _message_context(path: Path) -> str:
    """Lines carrying a user-visible message, plus the lines that build them.

    Hooks that hold their identity in a variable (`HOOK_NAME="foo"` then `"[$HOOK_NAME]"`)
    are credited too: the variable's definition is appended when the message interpolates
    it, so the convention is satisfied without inlining the literal everywhere.
    """
    lines = _code_lines(path)
    chunk: list[str] = []
    for i, line in enumerate(lines):
        if MESSAGE_FIELDS.search(line):
            chunk.extend(lines[max(0, i - 8) : i + 3])
    interpolated = set(re.findall(r"\$\{?([A-Z_][A-Z0-9_]*)\}?", "\n".join(chunk)))
    for var in interpolated:
        for line in lines:
            if re.match(rf"\s*{var}=", line):
                chunk.append(line)
    return "\n".join(chunk)


HOOK_FILES = _hook_files()
HOOK_IDS = [p.name for p in HOOK_FILES]

BLOCKING_HOOKS = [p for p in HOOK_FILES if _blocking_lines(p)]
BLOCKING_IDS = [p.name for p in BLOCKING_HOOKS]


@pytest.mark.parametrize("path", BLOCKING_HOOKS, ids=BLOCKING_IDS)
def test_blocking_hook_names_itself(path: Path):
    """The stop message must contain the hook's own name.

    Convention: prefix the message with `[hook-name]` (git-safety-guard's
    "BLOCKED by git-safety-guard" also satisfies this).
    """
    assert path.stem in _message_context(path), (
        f"{path.name} can block or stop a turn but never names itself in the message the "
        f"user sees. With several hooks on the same matcher, the stop is untraceable. "
        f"Prefix the reason with '[{path.stem}] '."
    )


@pytest.mark.parametrize("path", HOOK_FILES, ids=HOOK_IDS)
def test_continue_false_uses_stop_reason(path: Path):
    """`{"continue": false}` surfaces `stopReason`; `reason` is silently dropped."""
    source = "\n".join(_code_lines(path))
    halts = re.search(r'"?continue"?\\?"?\s*:\s*\\?"?false', source)
    if not halts:
        return
    assert "stopReason" in source, (
        f"{path.name} emits `continue: false` but never sets `stopReason`. The harness "
        f"only surfaces `stopReason` for a halt, so the user sees an unexplained stop. "
        f"Use `stopReason`, or switch to permissionDecision 'deny' to veto the call."
    )


def _pretooluse_hook_names() -> set[str]:
    settings = json.loads(SETTINGS.read_text(encoding="utf-8"))
    names = set()
    for group in settings.get("hooks", {}).get("PreToolUse", []):
        for hook in group.get("hooks", []):
            for token in hook.get("command", "").split():
                if ".claude/hooks" in token:
                    names.add(Path(token.strip('"')).name)
    return names


def test_pretooluse_hooks_veto_with_permission_decision():
    """A PreToolUse hook must veto with `deny`, not by halting the turn.

    `continue: false` does not prevent the call; it stops Claude afterwards, so the tool
    has already run. That mismatch is what made the 2026-07-31 stop so confusing.
    """
    offenders = []
    for name in _pretooluse_hook_names():
        path = HOOKS_DIR / name
        if not path.is_file():
            continue
        source = "\n".join(_code_lines(path))
        if re.search(r'"?continue"?\\?"?\s*:\s*\\?"?false', source):
            offenders.append(name)
    assert not offenders, (
        f"PreToolUse hooks halting the turn with `continue: false` instead of vetoing "
        f"with permissionDecision 'deny': {sorted(offenders)}. `continue: false` lets the "
        f"tool run and then cuts the turn."
    )


def test_hooks_do_not_write_shared_global_state():
    """Hook state must live under the project, never in a directory shared by all repos.

    A shared ~/.claude/state file let a complexity scored in one repo gate tool calls in
    another. Per-project state is the rule; $CWD/.claude/state/ is already gitignored.
    """
    offenders = {}
    write_to_global = re.compile(r">\s*[\"']?(~|\$HOME)/\.claude/state/")
    for path in HOOK_FILES:
        hits = [line.strip() for line in _code_lines(path) if write_to_global.search(line)]
        if hits:
            offenders[path.name] = hits
    assert not offenders, (
        f"Hooks writing to the shared ~/.claude/state/: {offenders}. Write to "
        f"\"$CWD/.claude/state/\" instead — global state cross-contaminates projects."
    )


def test_every_hook_sets_restrictive_umask():
    """Defense in depth: hook output must not be world-readable (repo rule, umask 077)."""
    missing = [
        p.name
        for p in HOOK_FILES
        if p.suffix == ".sh" and "umask 077" not in p.read_text(encoding="utf-8", errors="replace")
    ]
    assert not missing, f"Shell hooks without `umask 077`: {sorted(missing)}"
