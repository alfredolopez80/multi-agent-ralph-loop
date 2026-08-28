"""#47 C5 — suppression of content already held by the caller's live context.

recall() accepts active_context: nodes whose emitted vocabulary (summary +
detailed_summary) is >= 80% contained in it are suppressed with the trace
reason "already_in_context" -- before spending budget or a selection slot.
Containment, not Jaccard: the active context is typically far longer than
the node, so symmetric overlap would suppress by context size, not by
duplication. Opt-in: an empty active_context must change nothing.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
sys.path.insert(0, str(_MEMORY_DIR))

from recall_v2 import (  # noqa: E402
    already_in_context,
    recall,
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


def _ctx(project_id: str) -> object:
    from recall_v2 import Context

    return Context(
        project_root=Path("."),
        project_id=project_id,
        workspace_instance_id="ws1",
        branch="main",
    )


QUERIED_RULE = "always use parameterized queries for database access"
DISTINCT_RULE = "encrypt sensitive backups at rest with managed keys"

# A realistic active context: the caller is mid-task and already quotes the
# queried rule verbatim (that is exactly the duplication C5 targets).
ACTIVE_CONTEXT = (
    "Task: add the orders repository. Team standard reminder: we "
    f"{QUERIED_RULE}, enforced in review. Out of scope: frontend."
)


def test_containment_boundary_is_at_threshold_inclusive():
    """4/5 node tokens covered == 0.8 -> suppressed; 3/5 == 0.6 -> kept.

    The boundary is part of the contract: >= CONTEXT_CONTAINMENT_THRESHOLD.
    """
    context_tokens = frozenset({"alpha", "beta", "gamma", "delta"})
    covered = _payload(
        "projA", summary="alpha beta gamma delta omega"
    )
    assert already_in_context(covered, context_tokens) is True  # 4/5 == 0.8
    partial = _payload("projA", summary="alpha beta gamma zeta omega")
    assert already_in_context(partial, context_tokens) is False  # 3/5 == 0.6


def test_empty_active_context_suppresses_nothing():
    assert (
        already_in_context(_payload("projA", summary=QUERIED_RULE), frozenset())
        is False
    )


def test_duplicate_is_suppressed_distinct_passes(tmp_path):
    """The dual test: a node the context already quotes is suppressed; an
    unrelated node survives with its untouched score."""
    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    dup = s.create_node(_payload("projA", node_id="rule_dup", summary=QUERIED_RULE))
    keep = s.create_node(
        _payload("projA", node_id="rule_keep", summary=DISTINCT_RULE)
    )

    query = "parameterized queries database backups encrypt"
    baseline = recall(query, _ctx("projA"), home, limit=5)
    suppressed = recall(
        query, _ctx("projA"), home, limit=5, active_context=ACTIVE_CONTEXT
    )

    # Baseline (no active_context): both selected -- prior behaviour intact.
    assert set(baseline["MEMORY_TRACE"]["selected_memory_ids"]) == {
        dup["node_id"],
        keep["node_id"],
    }

    kept_ids = suppressed["MEMORY_TRACE"]["selected_memory_ids"]
    assert keep["node_id"] in kept_ids
    assert dup["node_id"] not in kept_ids

    # The suppression is auditable: trace says why, with the node id.
    reasons = {
        r["node_id"]: r["reason"] for r in suppressed["MEMORY_TRACE"]["rejected"]
    }
    assert reasons.get(dup["node_id"]) == "already_in_context"

    # "Passes intact" is measurable: same score as the baseline run.
    baseline_scores = {
        i["node_id"]: i["score"] for i in baseline["memory_context"]
    }
    kept_scores = {i["node_id"]: i["score"] for i in suppressed["memory_context"]}
    assert kept_scores[keep["node_id"]] == baseline_scores[keep["node_id"]]

    # Suppressed nodes never spend budget: used units drop accordingly.
    assert (
        suppressed["MEMORY_TRACE"]["token_budget"]["used"]
        < baseline["MEMORY_TRACE"]["token_budget"]["used"]
    )


def test_cli_active_context_file_suppresses(tmp_path):
    """The wake-up hook consumes the CLI: --active-context-file must reach
    the engine (memory dict is not enough)."""
    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    dup = s.create_node(_payload("projA", node_id="rule_dup", summary=QUERIED_RULE))
    keep = s.create_node(
        _payload("projA", node_id="rule_keep", summary=DISTINCT_RULE)
    )
    context_file = tmp_path / "active_context.txt"
    context_file.write_text(ACTIVE_CONTEXT, encoding="utf-8")

    proc = subprocess.run(
        [
            sys.executable,
            str(_MEMORY_DIR / "recall_v2.py"),
            "--project-root",
            ".",
            "--project-id",
            "projA",
            "--ralph-home",
            str(home),
            "--query",
            "parameterized queries database backups encrypt",
            "--active-context-file",
            str(context_file),
            "--json",
        ],
        capture_output=True,
        text=True,
        timeout=30,
        check=True,
    )
    trace = json.loads(proc.stdout)["MEMORY_TRACE"]
    assert keep["node_id"] in trace["selected_memory_ids"]
    assert dup["node_id"] not in trace["selected_memory_ids"]
    assert any(
        r["reason"] == "already_in_context" and r["node_id"] == dup["node_id"]
        for r in trace["rejected"]
    )
