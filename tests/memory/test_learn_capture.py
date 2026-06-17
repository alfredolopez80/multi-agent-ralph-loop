"""Tests for the Ralph learning-capture wiring (Phase B3).

Covers the three contract cases from the plan:
  * a valid validated learning -> a MemoryNode v2 is created (sensitivity YELLOW,
    domain inferred, persisted and loadable);
  * RED text -> rejected, no node written;
  * text with no learning keywords/headers -> skipped, no node written.

Plus: idempotency (same learning twice -> "exists", one node) and the JSON CLI
contract over stdin.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
sys.path.insert(0, str(_MEMORY_DIR))

import learn_capture  # noqa: E402
from learn_capture import (  # noqa: E402
    capture,
    extract_validated_learning,
    should_persist_learning,
)
from tree_store import TreeStore  # noqa: E402


_VALID_LESSON = "Decision: use bcrypt cost 12.\nValidated: passed."


# --- detection helpers ------------------------------------------------------

def test_should_persist_learning_detects_keyword():
    assert should_persist_learning("We fixed the race condition.") is True


def test_should_persist_learning_detects_section_header():
    assert should_persist_learning("Root cause: missing index on user_id.") is True


def test_should_persist_learning_rejects_plain_text():
    assert should_persist_learning("Just refactored a function name today.") is False


def test_extract_validated_learning_returns_validated_lines():
    learning = extract_validated_learning(_VALID_LESSON)
    assert learning is not None
    assert "Decision: use bcrypt cost 12." in learning


def test_extract_validated_learning_rejects_red():
    red = "Decision: ship it. Validated: passed. api_key=AKIA1234567890ABCDEF"
    assert extract_validated_learning(red) is None


# --- capture pipeline -------------------------------------------------------

def test_capture_valid_lesson_creates_node(tmp_path):
    home = tmp_path / "ralph_home"
    result = capture(
        _VALID_LESSON,
        project_id="projA",
        project_root=str(tmp_path),
        branch="feat/auth",
        session_id="sess-1",
        ralph_home=home,
    )
    assert result["status"] == "created"
    assert result["node_id"]

    store = TreeStore(home)
    loaded = store.load_node("projA", result["node_id"])
    assert loaded is not None
    assert loaded["sensitivity"] == "YELLOW"
    assert loaded["authority"] == "non_authoritative"
    assert loaded["memory_type"] == "session_learning"
    # domain is classified at creation -- always a member of the closed
    # vocabulary, never UNSET.
    from memory_node import DOMAIN_VALUES  # noqa: PLC0415

    assert loaded["domain"] in DOMAIN_VALUES
    assert "bcrypt" in loaded["summary"]


def test_capture_red_text_is_rejected(tmp_path):
    home = tmp_path / "ralph_home"
    red = (
        "Decision: store the token. Validated: passed.\n"
        "Authorization: Bearer abcdef0123456789abcdef0123456789"
    )
    result = capture(
        red,
        project_id="projRED",
        project_root=str(tmp_path),
        branch="main",
        session_id="sess-red",
        ralph_home=home,
    )
    assert result["status"] == "rejected_red"
    assert result["node_id"] is None
    # Nothing persisted for this project.
    assert TreeStore(home).list_nodes("projRED") == []


def test_capture_no_keywords_does_not_persist(tmp_path):
    home = tmp_path / "ralph_home"
    result = capture(
        "I renamed a variable and moved a file around.",
        project_id="projNoise",
        project_root=str(tmp_path),
        branch="main",
        session_id="sess-noise",
        ralph_home=home,
    )
    assert result["status"] == "skipped"
    assert result["node_id"] is None
    assert TreeStore(home).list_nodes("projNoise") == []


def test_capture_empty_text_is_skipped(tmp_path):
    home = tmp_path / "ralph_home"
    result = capture(
        "   \n  ",
        project_id="projEmpty",
        project_root=str(tmp_path),
        branch="main",
        ralph_home=home,
    )
    assert result["status"] == "skipped"
    assert result["node_id"] is None


def test_capture_is_idempotent(tmp_path):
    home = tmp_path / "ralph_home"

    def _do() -> dict[str, object]:
        return capture(
            _VALID_LESSON,
            project_id="projIdem",
            project_root=str(tmp_path),
            branch="main",
            session_id="sess-idem",
            ralph_home=home,
        )

    first = _do()
    second = _do()
    assert first["status"] == "created"
    assert second["status"] == "exists"
    assert second["node_id"] == first["node_id"]
    assert len(TreeStore(home).list_nodes("projIdem")) == 1


# --- CLI / stdin contract ---------------------------------------------------

def test_cli_stdin_json_creates_node(tmp_path):
    home = tmp_path / "ralph_home"
    request = {
        "text": _VALID_LESSON,
        "project_id": "projCLI",
        "project_root": str(tmp_path),
        "branch": "main",
        "session_id": "sess-cli",
        "ralph_home": str(home),
    }
    proc = subprocess.run(
        [sys.executable, str(_MEMORY_DIR / "learn_capture.py")],
        input=json.dumps(request),
        capture_output=True,
        text=True,
        check=True,
    )
    out = json.loads(proc.stdout)
    assert out["status"] == "created"
    assert out["node_id"]
    assert TreeStore(home).load_node("projCLI", out["node_id"]) is not None


def test_cli_empty_stdin_skips(tmp_path):
    proc = subprocess.run(
        [sys.executable, str(_MEMORY_DIR / "learn_capture.py")],
        input="",
        capture_output=True,
        text=True,
        check=True,
    )
    out = json.loads(proc.stdout)
    assert out["status"] == "skipped"


def test_main_returns_zero_on_skip(monkeypatch, tmp_path):
    monkeypatch.setattr("sys.stdin", _StdinStub(""))
    rc = learn_capture.main([])
    assert rc == 0


class _StdinStub:
    def __init__(self, data: str) -> None:
        self._data = data

    def read(self, _size: int = -1) -> str:
        return self._data


@pytest.mark.parametrize(
    "text,expected",
    [
        ("Conclusion: the cache TTL was too low.", "created"),
        ("just some chatter without signal", "skipped"),
    ],
)
def test_capture_status_matrix(tmp_path, text, expected):
    home = tmp_path / "ralph_home"
    result = capture(
        text,
        project_id="projMatrix",
        project_root=str(tmp_path),
        branch="main",
        session_id="sess-m",
        ralph_home=home,
    )
    assert result["status"] == expected
