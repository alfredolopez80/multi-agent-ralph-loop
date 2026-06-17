"""Consolidated threat-model invariants for the Ralph Memory Tree (Phase B4).

Ported from
``codex-ralph-vault-loop/tests/unit/test_memory_threat_model_invariants.py``
and adapted to the Ralph ``tree_store`` API (the codex original relied on
``snapshot_tree`` / ``find_by_hash`` machinery that is out of B2 scope and not
present here).

This file gathers the security/safety invariants into ONE named suite
(``TestThreatModelInvariants``) so the threat model is checked as a single,
auditable unit -- even where an individual invariant is also exercised in
``test_tree_store.py`` or ``test_recall_v2.py``. Each invariant is numbered to
match the Phase B4 spec:

  1. RED is never persisted (node create + raw save).
  2. authority is always ``non_authoritative`` (anything else rejected).
  3. provenance is always present (source + identity required).
  4. raw bodies never appear in listings (only the sha256 ref).
  5. node_id / hashes are safe to log (charset-constrained; no raw leakage).
  6. per-project isolation (one project never reads another's nodes/raw).
  7. path traversal is rejected (node_id / project_id segments).
  8. a corrupt node file does not crash load_node / list_nodes.

Two additional invariants are bundled because they belong to the same threat
surface and are cheap to assert here:

  9. recall hard-rejects cross-project nodes (the recall_v2 enforcement point).
 10. recall never emits raw bodies in its MEMORY_TRACE / memory_context.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import pytest

_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
if str(_MEMORY_DIR) not in sys.path:
    sys.path.insert(0, str(_MEMORY_DIR))

from memory_node import MemoryNodeValidationError  # noqa: E402
from recall_v2 import Context, recall  # noqa: E402
from tree_store import TreeStore, TreeStorePathError  # noqa: E402

PROJECT = "p-threat-model-project"
OTHER_PROJECT = "p-threat-model-other"
SAFE_LOG_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
SHA256_RE = re.compile(r"^[a-f0-9]{64}$")


def _red_text() -> str:
    # Built at runtime so the literal secret never appears in source.
    return "tok" + "en=abcd1234567890"


def _base_node(**overrides):
    payload = {
        "schema_version": "ralph_memory_node_v2",
        "node_id": "node_threat_001",
        "project_id": PROJECT,
        "workspace_instance_id": "workspace-threat",
        "repo_remote_hash": "remotehash",
        "branch": "main",
        "commit": "abc123",
        "session_id": "session-threat",
        "memory_type": "fact",
        "sensitivity": "YELLOW",
        "authority": "non_authoritative",
        "summary": "Threat invariant storage remains non-authoritative.",
        "detailed_summary": "Safe detail for deterministic invariant tests.",
        "trigger": {"terms": ["threat-model", "invariant"]},
        "topic_tags": ["memory-tree"],
        "entities": ["TreeStore"],
        "source_paths": ["docs/architecture/memory-threat-model-v2.md"],
        "source_description": "",
        "raw_ref": None,
        "links": [],
        "salience": {"recency": 0.5},
        "quality": {"confidence": 0.9, "validation_status": "pass"},
        "created_at": "2026-06-07T00:00:00+00:00",
        "updated_at": "2026-06-07T00:00:00+00:00",
        "compaction_reason": "phase_b4_invariant_test",
    }
    payload.update(overrides)
    return payload


def _empty_or_missing(path: Path) -> bool:
    return not path.exists() or not any(path.iterdir())


@pytest.fixture()
def store(tmp_path) -> TreeStore:
    return TreeStore(tmp_path / "ralph_home")


class TestThreatModelInvariants:
    """The Ralph Memory Tree threat-model, asserted as one named suite."""

    # --- Invariant 1: RED is never persisted -------------------------------

    def test_invariant_01_red_node_is_never_persisted(self, store: TreeStore) -> None:
        with pytest.raises(MemoryNodeValidationError):
            store.create_node(_base_node(sensitivity="RED"))
        # RED smuggled into a GREEN/YELLOW text field is also blocked.
        with pytest.raises(MemoryNodeValidationError):
            store.create_node(_base_node(summary=_red_text()))
        assert _empty_or_missing(store.nodes_dir(PROJECT))

    def test_invariant_01_red_raw_is_never_persisted(self, store: TreeStore) -> None:
        with pytest.raises(MemoryNodeValidationError):
            store.save_raw(PROJECT, _red_text(), sensitivity="YELLOW")
        with pytest.raises(MemoryNodeValidationError):
            store.save_raw(PROJECT, "safe body", sensitivity="RED")
        assert _empty_or_missing(store.raw_dir(PROJECT))

    # --- Invariant 2: authority is always non_authoritative ----------------

    def test_invariant_02_authority_must_be_non_authoritative(
        self, store: TreeStore
    ) -> None:
        for bad in ("authoritative", "trusted", ""):
            with pytest.raises(MemoryNodeValidationError):
                store.create_node(_base_node(authority=bad))
        assert _empty_or_missing(store.nodes_dir(PROJECT))

        written = store.create_node(_base_node())
        assert written["authority"] == "non_authoritative"

    # --- Invariant 3: provenance is always present -------------------------

    def test_invariant_03_provenance_is_required(self, store: TreeStore) -> None:
        # No source_paths and no source_description -> rejected.
        with pytest.raises(MemoryNodeValidationError):
            store.create_node(_base_node(source_paths=[], source_description=""))
        # No session_id and no commit -> rejected.
        with pytest.raises(MemoryNodeValidationError):
            store.create_node(_base_node(session_id="", commit=""))
        assert _empty_or_missing(store.nodes_dir(PROJECT))

        written = store.create_node(_base_node())
        assert written["source_paths"] or written["source_description"]
        assert written["session_id"] or written["commit"]

    # --- Invariant 4: raw bodies never appear in listings ------------------

    def test_invariant_04_raw_body_never_in_listings(self, store: TreeStore) -> None:
        raw_body = "safe raw body for explicit depth-two diagnostics only"
        saved = store.save_raw(PROJECT, raw_body, sensitivity="YELLOW")
        store.create_node(
            _base_node(
                raw_ref={"sha256": saved["sha256"], "safe": True, "sensitivity": "YELLOW"}
            )
        )

        listed = store.list_nodes(PROJECT)
        serialized = json.dumps(listed, ensure_ascii=True, sort_keys=True)

        assert [node["node_id"] for node in listed] == ["node_threat_001"]
        assert saved["sha256"] in serialized  # the reference is exposed...
        assert raw_body not in serialized  # ...but never the body.

        index = json.loads(store.index_path(PROJECT).read_text(encoding="utf-8"))
        assert raw_body not in json.dumps(index, ensure_ascii=True, sort_keys=True)

    # --- Invariant 5: node_id / hashes are safe to log ---------------------

    def test_invariant_05_node_ids_and_hashes_are_safe_to_log(
        self, store: TreeStore
    ) -> None:
        raw_body = "safe raw detail that must not enter log-shaped data"
        saved = store.save_raw(PROJECT, raw_body, sensitivity="YELLOW")
        written = store.create_node(
            _base_node(raw_ref={"sha256": saved["sha256"], "safe": True})
        )

        assert SHA256_RE.fullmatch(saved["sha256"])
        assert SAFE_LOG_ID_RE.fullmatch(written["node_id"])

        # The append-only usage log must never carry raw bodies or fs paths.
        usage_text = (store.project_tree(PROJECT) / "usage.jsonl").read_text(
            encoding="utf-8"
        )
        assert raw_body not in usage_text
        assert saved["path"] not in usage_text
        for line in (ln for ln in usage_text.splitlines() if ln.strip()):
            event = json.loads(line)
            assert SAFE_LOG_ID_RE.fullmatch(event["node_id"])

    # --- Invariant 6: per-project isolation --------------------------------

    def test_invariant_06_per_project_isolation(self, store: TreeStore) -> None:
        saved = store.save_raw(PROJECT, "safe project-scoped raw body", sensitivity="YELLOW")
        store.create_node(_base_node(raw_ref={"sha256": saved["sha256"], "safe": True}))

        # Another project sees nothing of this project's data.
        assert store.load_node(OTHER_PROJECT, "node_threat_001") is None
        assert store.list_nodes(OTHER_PROJECT) == []
        assert store.read_raw(OTHER_PROJECT, saved["sha256"]) is None
        assert store.project_tree(PROJECT) != store.project_tree(OTHER_PROJECT)

    # --- Invariant 7: path traversal is rejected ---------------------------

    def test_invariant_07_path_traversal_is_rejected(self, store: TreeStore) -> None:
        with pytest.raises(MemoryNodeValidationError):
            store.create_node(_base_node(node_id="../escape"))
        with pytest.raises(TreeStorePathError):
            store.load_node(PROJECT, "../escape")
        with pytest.raises(TreeStorePathError):
            store.list_nodes("../project")
        with pytest.raises(TreeStorePathError):
            store.node_path(PROJECT, "a/b")
        assert _empty_or_missing(store.nodes_dir(PROJECT))

    # --- Invariant 8: corrupt files do not crash load ----------------------

    def test_invariant_08_corrupt_file_does_not_crash_load(
        self, store: TreeStore
    ) -> None:
        store.ensure_layout(PROJECT)
        # Truncated JSON.
        store.node_path(PROJECT, "node_corrupt_001").write_text("{", encoding="utf-8")
        # Valid JSON but schema-invalid.
        store.node_path(PROJECT, "node_corrupt_002").write_text(
            json.dumps({"node_id": "node_corrupt_002"}), encoding="utf-8"
        )

        assert store.load_node(PROJECT, "node_corrupt_001") is None
        assert store.load_node(PROJECT, "node_corrupt_002") is None
        # A valid node alongside the corrupt ones still lists; corrupt ones drop.
        store.create_node(_base_node())
        listed = store.list_nodes(PROJECT)
        assert [n["node_id"] for n in listed] == ["node_threat_001"]

    # --- Invariant 9: recall hard-rejects cross-project nodes --------------

    def test_invariant_09_recall_rejects_cross_project(self, store: TreeStore) -> None:
        store.create_node(
            _base_node(
                summary="Threat model invariant about parameterized database queries.",
                trigger={"text": "threat model invariant database"},
            )
        )
        # Recall under a DIFFERENT project id must reject the node, not return it.
        ctx = Context(
            project_root=Path("."),
            project_id=OTHER_PROJECT,
            workspace_instance_id="ws-other",
            branch="main",
        )
        report = recall("threat model invariant database", ctx, store.ralph_home)
        assert report["memory_context"] == []

        # Under the OWNER project, the same query returns it.
        ctx_owner = Context(
            project_root=Path("."),
            project_id=PROJECT,
            workspace_instance_id="workspace-threat",
            branch="main",
        )
        report_owner = recall("threat model invariant database", ctx_owner, store.ralph_home)
        assert [it["node_id"] for it in report_owner["memory_context"]] == ["node_threat_001"]

    # --- Invariant 10: recall never emits raw bodies -----------------------

    def test_invariant_10_recall_trace_has_no_raw_body(self, store: TreeStore) -> None:
        raw_body = "secret-free but explicit raw content reserved for raw-open only"
        saved = store.save_raw(PROJECT, raw_body, sensitivity="YELLOW")
        store.create_node(
            _base_node(
                summary="Threat model parameterized query node with raw reference.",
                trigger={"text": "threat model parameterized query"},
                raw_ref={"sha256": saved["sha256"], "safe": True},
            )
        )
        ctx = Context(
            project_root=Path("."),
            project_id=PROJECT,
            workspace_instance_id="workspace-threat",
            branch="main",
        )
        report = recall("threat model parameterized query", ctx, store.ralph_home)
        serialized = json.dumps(report, ensure_ascii=True, sort_keys=True)

        assert report["memory_context"], "expected a match for the invariant query"
        assert raw_body not in serialized
        assert saved["path"] not in serialized
