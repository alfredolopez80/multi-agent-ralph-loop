"""Tests for read-size-guard.sh (PreToolUse, Read).

Cost guard: a Read of a text file longer than READ_SIZE_GUARD_MAX_LINES
(default 250) without `offset`/`limit` must be DENIED with a schema-valid
PreToolUse `deny`; everything else must be ALLOWED. Format reference:
tests/HOOK_FORMAT_REFERENCE.md rule #4.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
HOOK = REPO_ROOT / ".claude" / "hooks" / "read-size-guard.sh"

DEFAULT_MAX = 250


def run_hook(payload: dict, env_extra: dict | None = None) -> dict:
    env = {**os.environ, **(env_extra or {})}
    proc = subprocess.run(
        ["bash", str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        timeout=10,
        env=env,
    )
    assert proc.returncode == 0, f"hook exited {proc.returncode}: {proc.stderr}"
    assert proc.stdout.strip(), "hook produced no JSON"
    return json.loads(proc.stdout)


def read_payload(path: Path, **extra) -> dict:
    return {
        "session_id": "t",
        "tool_name": "Read",
        "tool_input": {"file_path": str(path), **extra},
        "cwd": str(REPO_ROOT),
    }


def decision(out: dict) -> str:
    hso = out.get("hookSpecificOutput", {})
    assert hso.get("hookEventName") == "PreToolUse"
    d = hso.get("permissionDecision")
    assert d in ("allow", "deny", "ask"), f"invalid permissionDecision: {d!r}"
    return d


@pytest.fixture
def big_file(tmp_path: Path) -> Path:
    p = tmp_path / "big.py"
    p.write_text("\n".join(f"line {i}" for i in range(DEFAULT_MAX + 50)) + "\n")
    return p


@pytest.fixture
def small_file(tmp_path: Path) -> Path:
    p = tmp_path / "small.py"
    p.write_text("\n".join(f"line {i}" for i in range(DEFAULT_MAX - 50)) + "\n")
    return p


def test_hook_exists_and_executable():
    assert HOOK.is_file()
    assert os.access(HOOK, os.X_OK)


def test_unbounded_read_of_big_file_is_denied(big_file: Path):
    out = run_hook(read_payload(big_file))
    assert decision(out) == "deny"
    reason = out["hookSpecificOutput"]["permissionDecisionReason"]
    assert "read-size-guard" in reason
    assert str(DEFAULT_MAX + 50) in reason, "reason must state the line count"
    assert "offset" in reason and "limit" in reason


def test_exact_threshold_is_allowed(tmp_path: Path):
    p = tmp_path / "edge.txt"
    p.write_text("\n".join("x" for _ in range(DEFAULT_MAX)) + "\n")
    assert decision(run_hook(read_payload(p))) == "allow"


def test_one_over_threshold_is_denied(tmp_path: Path):
    p = tmp_path / "edge.txt"
    p.write_text("\n".join("x" for _ in range(DEFAULT_MAX + 1)) + "\n")
    assert decision(run_hook(read_payload(p))) == "deny"


def test_small_file_is_allowed(small_file: Path):
    assert decision(run_hook(read_payload(small_file))) == "allow"


@pytest.mark.parametrize("bound", [{"limit": 100}, {"offset": 300}, {"offset": 10, "limit": 50}])
def test_bounded_read_of_big_file_is_allowed(big_file: Path, bound: dict):
    assert decision(run_hook(read_payload(big_file, **bound))) == "allow"


def test_missing_file_is_allowed(tmp_path: Path):
    assert decision(run_hook(read_payload(tmp_path / "nope.txt"))) == "allow"


@pytest.mark.parametrize("ext", ["png", "pdf", "ipynb", "JPG"])
def test_media_files_are_allowed(tmp_path: Path, ext: str):
    p = tmp_path / f"blob.{ext}"
    p.write_bytes(b"\n" * (DEFAULT_MAX + 100))
    assert decision(run_hook(read_payload(p))) == "allow"


def test_other_tools_are_allowed(big_file: Path):
    payload = read_payload(big_file)
    payload["tool_name"] = "Grep"
    assert decision(run_hook(payload)) == "allow"


def test_env_override_raises_threshold(big_file: Path):
    out = run_hook(read_payload(big_file), {"READ_SIZE_GUARD_MAX_LINES": "100000"})
    assert decision(out) == "allow"


def test_env_override_lowers_threshold(small_file: Path):
    out = run_hook(read_payload(small_file), {"READ_SIZE_GUARD_MAX_LINES": "10"})
    assert decision(out) == "deny"


def test_never_emits_block():
    src = HOOK.read_text()
    assert '"permissionDecision": "block"' not in src
