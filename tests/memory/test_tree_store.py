"""Tests for the Ralph Memory Tree store (Phase B2).

Covers: per-project isolation, path-traversal rejection, RED never reaching
raw storage, corrupt-file tolerance (load_node -> None), raw read re-checking
RED, and listings never carrying raw bodies.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
sys.path.insert(0, str(_MEMORY_DIR))

from memory_node import MemoryNodeValidationError  # noqa: E402
from tree_store import (  # noqa: E402
    TreeStore,
    TreeStorePathError,
    compute_project_id,
    ensure_within,
    safe_segment,
)


def _payload(project_id: str, **overrides):
    payload = {
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
        "source_description": "migrated from rules.json",
        "trigger": {"text": "writing SQL"},
        "topic_tags": ["database", "sql"],
        "quality": {"confidence": 0.9},
    }
    payload.update(overrides)
    return payload


@pytest.fixture()
def store(tmp_path) -> TreeStore:
    return TreeStore(tmp_path / "ralph_home")


# --- create / load round trip ----------------------------------------------

def test_create_and_load_node(store):
    written = store.create_node(_payload("projA"))
    loaded = store.load_node("projA", written["node_id"])
    assert loaded is not None
    assert loaded["node_id"] == written["node_id"]
    assert loaded["domain"] == "database"


def test_layout_paths(store):
    store.create_node(_payload("projA"))
    root = store.project_tree("projA")
    assert (root / "nodes").is_dir()
    assert (root / "raw").is_dir()
    assert store.index_path("projA").exists()
    assert store.usage_path("projA").exists()
    # tree lives under ~/.ralph/memory_tree/projects/<id>
    assert root.parent.name == "projects"
    assert root.parent.parent.name == "memory_tree"


def test_create_duplicate_rejected(store):
    written = store.create_node(_payload("projA"))
    with pytest.raises(Exception):
        store.create_node(_payload("projA", node_id=written["node_id"]))


def test_update_node(store):
    written = store.create_node(_payload("projA"))
    updated = store.update_node(
        "projA", written["node_id"], {"summary": "Always index foreign keys in the database."}
    )
    assert updated["summary"].startswith("Always index")
    reloaded = store.load_node("projA", written["node_id"])
    assert reloaded is not None
    assert reloaded["summary"].startswith("Always index")


# --- per-project isolation --------------------------------------------------

def test_project_isolation(store):
    a = store.create_node(_payload("projA", summary="Project A rule about hooks stdin."))
    b = store.create_node(_payload("projB", summary="Project B rule about pytest fixtures."))
    a_nodes = {n["node_id"] for n in store.list_nodes("projA")}
    b_nodes = {n["node_id"] for n in store.list_nodes("projB")}
    assert a["node_id"] in a_nodes
    assert b["node_id"] in b_nodes
    assert a_nodes.isdisjoint(b_nodes)
    # a node is not visible from the other project's namespace
    assert store.load_node("projB", a["node_id"]) is None


def test_compute_project_id_is_worktree_isolated(tmp_path):
    # Two sibling directories (simulating two worktrees) yield different ids
    # even though neither is a git repo (path fallback differs by name).
    wt1 = tmp_path / "worktree-one"
    wt2 = tmp_path / "worktree-two"
    wt1.mkdir()
    wt2.mkdir()
    assert compute_project_id(wt1) != compute_project_id(wt2)
    # And deterministic for the same path.
    assert compute_project_id(wt1) == compute_project_id(wt1)


# --- path traversal ---------------------------------------------------------

def test_safe_segment_rejects_traversal():
    for bad in ("..", "../etc", "a/b", "a\\b", "/abs", ""):
        with pytest.raises(TreeStorePathError):
            safe_segment(bad, "seg")


def test_node_path_rejects_traversal(store):
    with pytest.raises(TreeStorePathError):
        store.node_path("projA", "../../escape")
    with pytest.raises(TreeStorePathError):
        store.project_tree("../../etc")


def test_ensure_within_rejects_escape(tmp_path):
    base = tmp_path / "root"
    base.mkdir()
    with pytest.raises(TreeStorePathError):
        ensure_within(base, tmp_path / "outside" / "file.txt")
    # a child path is accepted
    assert ensure_within(base, base / "nodes" / "x.json")


# --- RED never reaches raw --------------------------------------------------

def test_save_raw_rejects_red(store):
    red = "export API_KEY=sk-ABCDEF0123456789ABCDEF0123"
    with pytest.raises(MemoryNodeValidationError):
        store.save_raw("projA", red, sensitivity="YELLOW")


def test_save_raw_rejects_bad_sensitivity(store):
    with pytest.raises(MemoryNodeValidationError):
        store.save_raw("projA", "harmless content", sensitivity="RED")


def test_save_and_read_raw_green(store):
    ref = store.save_raw("projA", "a perfectly safe note about testing", "GREEN")
    assert len(ref["sha256"]) == 64
    content = store.read_raw("projA", ref["sha256"])
    assert content == "a perfectly safe note about testing"


def test_read_raw_rechecks_red(store):
    # Write a safe raw blob, then tamper the on-disk file with RED material.
    ref = store.save_raw("projA", "safe content placeholder", "GREEN")
    raw_file = store.raw_path("projA", ref["sha256"])
    raw_file.write_text("token = sk-DEADBEEF0123456789ABCDEF0123", encoding="utf-8")
    assert store.read_raw("projA", ref["sha256"]) is None


# --- corrupt file tolerance -------------------------------------------------

def test_load_node_corrupt_json_returns_none(store):
    store.create_node(_payload("projA"))
    nodes_dir = store.nodes_dir("projA")
    corrupt = nodes_dir / "corrupt.json"
    corrupt.write_text("{ this is not valid json", encoding="utf-8")
    assert store.load_node("projA", "corrupt") is None


def test_load_node_invalid_schema_returns_none(store):
    nodes_dir = store.nodes_dir("projA")
    store.ensure_layout("projA")
    bad = nodes_dir / "bad.json"
    bad.write_text('{"node_id": "bad", "summary": "missing everything"}', encoding="utf-8")
    assert store.load_node("projA", "bad") is None


def test_list_nodes_skips_corrupt(store):
    good = store.create_node(_payload("projA"))
    (store.nodes_dir("projA") / "broken.json").write_text("not json", encoding="utf-8")
    ids = {n["node_id"] for n in store.list_nodes("projA")}
    assert good["node_id"] in ids
    assert "broken" not in ids


# --- listings never carry raw bodies ---------------------------------------

def test_list_nodes_has_no_raw_bodies(store):
    ref = store.save_raw("projA", "raw body content here", "GREEN")
    store.create_node(
        _payload("projA", raw_ref={"sha256": ref["sha256"], "sensitivity": "GREEN"})
    )
    entries = store.list_nodes("projA")
    assert entries
    for entry in entries:
        # only the sha256 reference is present, never the raw text
        raw_ref = entry.get("raw_ref")
        if raw_ref is not None:
            assert set(raw_ref.keys()) == {"sha256"}
        flat = str(entry)
        assert "raw body content here" not in flat
