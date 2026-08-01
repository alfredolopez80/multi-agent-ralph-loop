"""Every registered hook must point at a file that exists.

A hook registered against a missing script fails on every matching event, silently.
That is how `auto-plan-state.sh` kept firing into nothing after being deleted from the
working tree, and how the retired `~/.cc-mirror` mirrors accumulated 29 dead entries
between them (17 in minimax, 12 in zai) as hooks were archived one by one.

This replaces the previous approach of hand-listing a handful of CRITICAL_HOOKS: an
exhaustive check needs no maintenance and cannot go stale.
"""

from __future__ import annotations

import json
import os
import shlex
from pathlib import Path

import pytest

SETTINGS_FILES = [Path.home() / ".claude" / "settings.json"]

# Commands whose path is resolved by the harness at runtime, not by us.
RUNTIME_PREFIXES = ("$", "~")


def _registered_hooks(settings_path: Path) -> list[tuple[str, str, str]]:
    """(event, matcher, command) for every hook in a settings file."""
    data = json.loads(settings_path.read_text(encoding="utf-8"))
    out = []
    for event, groups in data.get("hooks", {}).items():
        for group in groups:
            matcher = group.get("matcher", "*")
            for hook in group.get("hooks", []):
                out.append((event, matcher, hook.get("command", "")))
    return out


def _script_path(command: str) -> str | None:
    """The hook script referenced by a command, or None when it names no script."""
    try:
        tokens = shlex.split(command)
    except ValueError:
        return None
    for token in tokens:
        if ".claude/hooks" in token:
            return token
    return None


# The host's Claude install is not present on a clean CI runner. These checks are about
# the INSTALLATION, so they skip there — but the skip must be explicit and visible, never
# a silent pass, and when the file IS present the checks must prove they examined
# something (per `testing-zero-tests-is-never-success`).
requires_settings = pytest.mark.skipif(
    not SETTINGS_FILES[0].is_file(),
    reason=f"{SETTINGS_FILES[0]} not present (expected on CI; these validate a local install)",
)


@requires_settings
@pytest.mark.parametrize("settings_path", SETTINGS_FILES, ids=lambda p: p.name)
def test_settings_file_exists(settings_path: Path):
    assert settings_path.is_file(), f"{settings_path} not found"


@requires_settings
@pytest.mark.parametrize("settings_path", SETTINGS_FILES, ids=lambda p: p.name)
def test_every_registered_hook_script_exists(settings_path: Path):
    if not settings_path.is_file():
        pytest.skip(f"{settings_path} not present")

    examined = 0
    broken = []
    for event, matcher, command in _registered_hooks(settings_path):
        path = _script_path(command)
        if path is None or path.startswith(RUNTIME_PREFIXES):
            continue
        examined += 1
        if not os.path.isfile(path):
            broken.append(f"{event}/{matcher} -> {os.path.basename(path)}")

    # Zero hooks examined is not a pass: it means the settings shape changed (e.g. every
    # command now written with a runtime prefix) and this check silently stopped covering
    # anything, which is exactly what justified trimming the hand-maintained list.
    assert examined > 0, (
        f"{settings_path} yielded 0 examinable hook paths — the settings format likely "
        f"changed and this check is no longer covering anything."
    )
    assert not broken, (
        f"{settings_path} registers {len(broken)} hook(s) whose script does not exist:\n  "
        + "\n  ".join(sorted(broken))
        + "\nA registered-but-missing hook fails on every matching event. Either restore "
        "the script or deregister it."
    )


@requires_settings
@pytest.mark.parametrize("settings_path", SETTINGS_FILES, ids=lambda p: p.name)
def test_every_registered_hook_script_is_executable(settings_path: Path):
    """A shell hook that is not executable fails the same way a missing one does."""
    if not settings_path.is_file():
        pytest.skip(f"{settings_path} not present")

    not_exec = []
    for event, matcher, command in _registered_hooks(settings_path):
        path = _script_path(command)
        if path is None or path.startswith(RUNTIME_PREFIXES) or not os.path.isfile(path):
            continue
        # Interpreted via an explicit runner (`node x.mjs`, `python3 x.py`) does not
        # need the executable bit; a bare path does.
        tokens = shlex.split(command)
        if tokens and tokens[0] != path:
            continue
        if not os.access(path, os.X_OK):
            not_exec.append(f"{event}/{matcher} -> {os.path.basename(path)}")

    assert not not_exec, f"Registered hooks missing the executable bit: {sorted(not_exec)}"


def test_no_cc_mirror_settings_remain():
    """~/.cc-mirror was removed on 2026-07-31; nothing may resurrect it.

    The mirrors duplicated every hook registration and drifted out of sync, holding
    29 dead entries. They also duplicated plaintext API keys across settings files.
    """
    mirror = Path.home() / ".cc-mirror"
    assert not mirror.exists(), (
        f"{mirror} exists again. The project is single-target (Claude Code); model "
        "selection goes through CLI env vars, not mirrored settings trees."
    )


@requires_settings
def test_no_hook_command_references_cc_mirror():
    """No registered hook may reach into the removed mirror tree."""
    offenders = []
    for settings_path in SETTINGS_FILES:
        if not settings_path.is_file():
            continue
        for event, matcher, command in _registered_hooks(settings_path):
            if "cc-mirror" in command:
                offenders.append(f"{settings_path.name}: {event}/{matcher}")
    assert not offenders, f"Hook commands still referencing ~/.cc-mirror: {offenders}"
