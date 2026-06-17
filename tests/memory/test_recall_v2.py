"""Tests for recall_v2 typed scoring retrieval (Phase B2).

Covers: query analysis + risk levels, hard-reject reasons, scoring order
(trigger-match outranks summary-only-match), per-project isolation in recall,
and a well-formed MEMORY_TRACE.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
sys.path.insert(0, str(_MEMORY_DIR))

from recall_v2 import (  # noqa: E402
    Context,
    analyze_query,
    hard_reject_reason,
    recall,
    score_node,
)
from tree_store import TreeStore  # noqa: E402


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
        "summary": "A rule summary.",
        "source_description": "migrated from rules.json",
        "quality": {"confidence": 0.9},
    }
    payload.update(overrides)
    return payload


@pytest.fixture()
def store(tmp_path) -> TreeStore:
    return TreeStore(tmp_path / "ralph_home")


def _ctx(project_id: str) -> Context:
    return Context(
        project_root=Path("."),
        project_id=project_id,
        workspace_instance_id="ws1",
        branch="main",
    )


# --- query analysis ---------------------------------------------------------

def test_analyze_query_low_risk():
    a = analyze_query("how do hooks read stdin")
    # "how" is medium-risk -> medium
    assert a["risk_level"] == "medium"
    assert "stdin" in a["semantic_terms"]


def test_analyze_query_high_risk_exact_fact():
    a = analyze_query("what is the exact command to run pytest")
    assert a["risk_level"] == "high"
    assert a["exact_fact_mode"] is True


def test_analyze_query_plain_low():
    a = analyze_query("database parameterized queries")
    assert a["risk_level"] == "low"
    assert "database" in a["search_terms"]


def test_analyze_query_temporal():
    a = analyze_query("what changed on 2026-06-17")
    assert "2026-06-17" in a["temporal_terms"]


# --- hard reject reasons ----------------------------------------------------

def test_reject_invalid_node():
    assert hard_reject_reason("not a dict", _ctx("projA"), False) == "invalid_node"


def test_reject_wrong_project(store):
    written = store.create_node(_payload("projA", summary="database indexes matter"))
    node = store.load_node("projA", written["node_id"])
    assert node is not None
    assert hard_reject_reason(node, _ctx("projB"), False) == "wrong_project"


def test_reject_red():
    node = _payload("projA")
    node["sensitivity"] = "RED"
    assert hard_reject_reason(node, _ctx("projA"), False) == "red"


def test_reject_deprecated(store):
    written = store.create_node(
        _payload("projA", quality={"confidence": 0.9, "deprecated": True})
    )
    node = store.load_node("projA", written["node_id"])
    assert node is not None
    assert hard_reject_reason(node, _ctx("projA"), False) == "deprecated"
    # included when requested
    assert hard_reject_reason(node, _ctx("projA"), True) == ""


def test_reject_missing_provenance():
    # Build a dict that has summary but no source/identity provenance.
    node = {
        "project_id": "projA",
        "authority": "non_authoritative",
        "sensitivity": "GREEN",
        "summary": "x",
    }
    assert hard_reject_reason(node, _ctx("projA"), False) == "missing_provenance"


def test_reject_authority(store):
    written = store.create_node(_payload("projA"))
    node = store.load_node("projA", written["node_id"])
    assert node is not None
    node["authority"] = "authoritative"
    assert hard_reject_reason(node, _ctx("projA"), False) == "authority"


def test_reject_conflict(store):
    written = store.create_node(_payload("projA", visibility="conflict"))
    node = store.load_node("projA", written["node_id"])
    assert node is not None
    assert hard_reject_reason(node, _ctx("projA"), False) == "conflict"


# --- scoring order ----------------------------------------------------------

def test_trigger_match_outranks_summary_only():
    analysis = analyze_query("savepoint rollback")
    summary_only = _payload(
        "projA",
        summary="a rule that mentions savepoint and rollback in the summary",
        trigger={},
    )
    trigger_match = _payload(
        "projA",
        summary="unrelated wording",
        trigger={"text": "savepoint rollback when transactions fail"},
    )
    s_summary, _ = score_node(summary_only, analysis)
    s_trigger, _ = score_node(trigger_match, analysis)
    # trigger weight (8) > summary weight (5) per matched term
    assert s_trigger > s_summary > 0


def test_negative_bonus_applies():
    # "avoid" is a semantic term that triggers the negative bonus; "shortcuts"
    # is a non-risk search term so the node also clears the base-match guard.
    analysis = analyze_query("avoid dangerous database shortcuts")
    node = _payload(
        "projA",
        memory_type="negative_rule",
        summary="never take dangerous database shortcuts",
        quality={
            "confidence": 0.9,
            "reason": "caused an outage",
            "validation_evidence": "incident report",
        },
    )
    score, parts = score_node(node, analysis)
    assert parts["negative_bonus"] == 6.0
    assert score > 0


def test_deprecated_penalty_in_parts(store):
    analysis = analyze_query("database indexes")
    node = _payload(
        "projA",
        summary="database indexes speed queries",
        quality={"confidence": 0.9, "deprecated": True},
    )
    _, parts = score_node(node, analysis)
    assert parts["deprecated_penalty"] == 25.0


# --- end to end recall + MEMORY_TRACE --------------------------------------

def test_recall_ranks_and_emits_trace(store, tmp_path):
    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    summary_node = s.create_node(
        _payload(
            "projA",
            summary="rollback savepoint mentioned in summary only",
            trigger={},
        )
    )
    trigger_node = s.create_node(
        _payload(
            "projA",
            summary="unrelated",
            trigger={"text": "rollback savepoint in transaction handling"},
        )
    )
    s.create_node(_payload("projA", summary="completely irrelevant frontend css rule"))

    report = recall("rollback savepoint", _ctx("projA"), home, limit=5)
    selected = report["MEMORY_TRACE"]["selected_memory_ids"]
    assert selected, "expected at least one selected node"
    # trigger-match must rank above summary-only-match
    assert selected.index(trigger_node["node_id"]) < selected.index(
        summary_node["node_id"]
    )

    trace = report["MEMORY_TRACE"]
    assert trace["engine"] == "tree"
    assert isinstance(trace["selected_memory_ids"], list)
    assert isinstance(trace["rejected"], list)
    assert set(trace["token_budget"].keys()) == {"limit", "used"}
    assert trace["risk_level"] in {"low", "medium", "high"}
    assert isinstance(trace["latency_ms"], int) and trace["latency_ms"] >= 0


def test_recall_project_isolation(store, tmp_path):
    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    s.create_node(_payload("projA", summary="database parameterized queries rule"))
    s.create_node(_payload("projB", summary="database parameterized queries rule"))
    report = recall("database parameterized queries", _ctx("projA"), home)
    # only projA nodes are eligible; projB nodes never enter the candidate set
    assert report["MEMORY_TRACE"]["selected_memory_ids"]
    for entry in report["MEMORY_TRACE"]["rejected"]:
        assert entry["reason"] != "wrong_project"


def test_recall_high_risk_adds_raw_recommendation(store, tmp_path):
    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    ref = s.save_raw("projA", "safe raw body", "GREEN")
    s.create_node(
        _payload(
            "projA",
            summary="the deployment rollback procedure",
            trigger={"text": "deployment rollback steps"},
            raw_ref={"sha256": ref["sha256"], "sensitivity": "GREEN"},
        )
    )
    # "exact" makes this high-risk; "deployment"/"rollback" are content terms
    # that survive into search_terms so the node still matches.
    report = recall("exact deployment rollback steps", _ctx("projA"), home)
    assert report["analysis"]["risk_level"] == "high"
    ctx = report["memory_context"]
    assert ctx
    assert ctx[0]["RAW_RECOMMENDED"] is True
    assert ctx[0]["suggested_read_command"]
