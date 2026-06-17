"""Tests for the native MEMORY.md GREEN-node projection (Phase B4).

Covers the safety contract that motivates the script:
  * The delimited block is inserted when absent.
  * Pre-existing user content OUTSIDE the block is preserved byte-for-byte.
  * Re-running is idempotent (no drift on a second pass).
  * Only GREEN, non-deprecated nodes are projected (YELLOW excluded).
  * Native project id matches Claude's path->dashes mapping.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import pytest

_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
sys.path.insert(0, str(_MEMORY_DIR))

from project_memory import (  # noqa: E402
    BLOCK_END,
    BLOCK_START,
    native_project_id,
    project_memory,
    select_green_nodes,
    upsert_block,
)
from tree_store import TreeStore, compute_project_id  # noqa: E402


def _payload(project_id: str, **overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "project_id": project_id,
        "workspace_instance_id": "ws1",
        "repo_remote_hash": "abc123",
        "branch": "main",
        "commit": "deadbeef",
        "session_id": "sess-1",
        "memory_type": "procedural_rule",
        "sensitivity": "GREEN",
        "authority": "non_authoritative",
        "summary": "Use parameterized queries for all database operations.",
        "source_description": "synthetic test node",
        "trigger": {"text": "writing SQL"},
        "topic_tags": ["database", "sql"],
        "quality": {"confidence": 0.9},
    }
    payload.update(overrides)
    return payload


@pytest.fixture()
def store(tmp_path: Path) -> TreeStore:
    return TreeStore(tmp_path / "ralph_home")


# --- native id mapping -------------------------------------------------------

def test_native_project_id_maps_slashes_and_dots(tmp_path: Path) -> None:
    # The mapping uses the *resolved* absolute path; build under tmp_path so it
    # is real, then assert the dash/dot transform on the resolved string.
    target = tmp_path / "repo.name"
    target.mkdir()
    native = native_project_id(target)
    resolved = str(target.resolve())
    assert native == resolved.replace("/", "-").replace(".", "-")
    assert "/" not in native and "." not in native


# --- block upsert primitives -------------------------------------------------

def test_upsert_inserts_into_empty() -> None:
    block = f"{BLOCK_START}\nbody\n{BLOCK_END}"
    out = upsert_block("", block)
    assert BLOCK_START in out and BLOCK_END in out
    assert out.endswith("\n")


def test_upsert_preserves_user_content_outside_block() -> None:
    user = "# My Notes\n\nImportant hand-written memory.\n"
    block = f"{BLOCK_START}\nbody\n{BLOCK_END}"
    out = upsert_block(user, block)
    assert "# My Notes" in out
    assert "Important hand-written memory." in out
    assert BLOCK_START in out


def test_upsert_is_idempotent_and_replaces_only_block() -> None:
    user = "# My Notes\n\nKeep me.\n"
    block_v1 = f"{BLOCK_START}\nversion-1\n{BLOCK_END}"
    block_v2 = f"{BLOCK_START}\nversion-2\n{BLOCK_END}"
    once = upsert_block(user, block_v1)
    twice = upsert_block(once, block_v2)
    # User content survives both passes; only the block body changed.
    assert "Keep me." in twice
    assert "version-1" not in twice
    assert "version-2" in twice
    # A third pass with the same block is a true no-op on content.
    thrice = upsert_block(twice, block_v2)
    assert thrice == twice


# --- node selection ----------------------------------------------------------

def test_select_green_nodes_excludes_yellow_and_deprecated(store: TreeStore) -> None:
    pid = "projSelect"
    green = store.create_node(_payload(pid, summary="Green keep me one."))
    store.create_node(
        _payload(pid, sensitivity="YELLOW", summary="Yellow stays out two.")
    )
    store.create_node(
        _payload(
            pid,
            summary="Deprecated green out three.",
            quality={"confidence": 0.95, "deprecated": True},
        )
    )
    selected = select_green_nodes(store, pid, top_n=10)
    ids = {n["node_id"] for n in selected}
    assert green["node_id"] in ids
    assert len(selected) == 1  # only the live GREEN node


# --- end-to-end projection ---------------------------------------------------

def test_project_memory_inserts_block_and_is_idempotent(
    store: TreeStore, tmp_path: Path
) -> None:
    repo = tmp_path / "myrepo"
    repo.mkdir()
    pid = compute_project_id(repo)
    store.create_node(_payload(pid, summary="Validate inputs at API boundaries."))

    claude_home = tmp_path / "claude"

    # Seed pre-existing native MEMORY.md with user content.
    native_id = native_project_id(repo)
    mem_path = claude_home / "projects" / native_id / "memory" / "MEMORY.md"
    mem_path.parent.mkdir(parents=True, exist_ok=True)
    user_content = "# Memory Index\n\n## User\n- hand-written note that must survive\n"
    mem_path.write_text(user_content, encoding="utf-8")

    report1 = project_memory(
        project_path=repo,
        ralph_home=store.ralph_home,
        claude_home=claude_home,
        top_n=10,
        apply=True,
    )
    assert report1["wrote"] is True
    assert report1["green_node_count"] == 1

    written = mem_path.read_text(encoding="utf-8")
    # User content preserved.
    assert "hand-written note that must survive" in written
    # Block inserted with our projected summary.
    assert BLOCK_START in written and BLOCK_END in written
    assert "Validate inputs at API boundaries." in written

    # Second run with identical nodes: idempotent (no change written).
    report2 = project_memory(
        project_path=repo,
        ralph_home=store.ralph_home,
        claude_home=claude_home,
        top_n=10,
        apply=True,
    )
    assert report2["changed"] is False
    assert report2["wrote"] is False
    assert mem_path.read_text(encoding="utf-8") == written


def test_project_memory_creates_file_when_absent(
    store: TreeStore, tmp_path: Path
) -> None:
    repo = tmp_path / "freshrepo"
    repo.mkdir()
    pid = compute_project_id(repo)
    store.create_node(_payload(pid, summary="Never log secrets or tokens."))

    claude_home = tmp_path / "claude"
    report = project_memory(
        project_path=repo,
        ralph_home=store.ralph_home,
        claude_home=claude_home,
        top_n=10,
        apply=True,
    )
    assert report["wrote"] is True
    target = Path(report["memory_md_path"])
    assert target.exists()
    body = target.read_text(encoding="utf-8")
    assert BLOCK_START in body
    assert "Never log secrets or tokens." in body


def test_project_memory_dry_run_writes_nothing(
    store: TreeStore, tmp_path: Path
) -> None:
    repo = tmp_path / "dryrepo"
    repo.mkdir()
    pid = compute_project_id(repo)
    store.create_node(_payload(pid))

    claude_home = tmp_path / "claude"
    report = project_memory(
        project_path=repo,
        ralph_home=store.ralph_home,
        claude_home=claude_home,
        top_n=10,
        apply=False,
    )
    assert report["mode"] == "dry-run"
    assert report["changed"] is True  # would change
    assert report["wrote"] is False
    assert not Path(report["memory_md_path"]).exists()
