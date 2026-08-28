"""#47 C5 — suppression of content already held by the caller's live context.

recall() accepts active_context: nodes whose EMITTED vocabulary is >= 80%
covered by it AND has >= MIN_COVERED_TOKENS tokens covered are suppressed
with trace reason "already_in_context" -- before spending budget or a slot.

Two honesty constraints (T92 review items 1-2):
  * "Emitted" means the fields render_context puts in front of the model AT
    THE QUERY'S RISK LEVEL (low: summary + topic_tags; medium/high: summary +
    detailed_summary + source_paths). Suppressing over non-emitted fields
    withholds new summaries the caller never received.
  * Containment alone lets a short generic summary (5 tokens) vanish into any
    long operational context. The absolute floor is what follows REAL quotes.

Containment, not Jaccard: the active context is typically far longer than
the node, so symmetric overlap would suppress by context size, not by
duplication. Opt-in: an empty active_context must change nothing.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
_TESTS_DIR = Path(__file__).resolve().parent
for _p in (_MEMORY_DIR, _TESTS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from recall_v2 import already_in_context, recall  # noqa: E402
from tree_store import TreeStore  # noqa: E402
from _recall_fixtures import (  # noqa: E402
    ACTIVE_CONTEXT,
    DISTINCT_RULE,
    GENERIC_CONTEXT,
    QUERIED_RULE,
    make_context,
    make_payload,
)

QUERIED_QUERY = "parameterized queries database backups encrypt"


def _seed(tmp_path):
    home = tmp_path / "ralph_home"
    store = TreeStore(home)
    dup = store.create_node(
        make_payload("projA", node_id="rule_dup", summary=QUERIED_RULE)
    )
    keep = store.create_node(
        make_payload("projA", node_id="rule_keep", summary=DISTINCT_RULE)
    )
    return home, store, dup, keep


# --- unit: the two-part boundary ---------------------------------------------

def test_boundary_ratio_and_absolute_floor():
    """Both conditions must hold: ratio >= 0.8 AND >= 6 tokens covered.
    8/10 (0.8, 8) in; 7/10 (0.7) out by ratio; 5/5 (1.0 but 5 < 6) out by
    the floor -- a five-token generic summary can never vanish a node."""
    context_tokens = frozenset(
        "alpha beta gamma delta epsilon zeta eta theta iota kappa".split()
    )
    at_ratio_edge = make_payload(
        "projA", summary="alpha beta gamma delta epsilon zeta eta theta omega lambda"
    )
    assert already_in_context(at_ratio_edge, context_tokens, "low") is True  # 8/10

    below_ratio = make_payload(
        "projA", summary="alpha beta gamma delta epsilon zeta eta sigma omega lambda"
    )
    assert already_in_context(below_ratio, context_tokens, "low") is False  # 7/10

    all_covered_but_short = make_payload("projA", summary="alpha beta gamma delta epsilon")
    assert already_in_context(all_covered_but_short, context_tokens, "low") is False  # 5 < 6


def test_empty_active_context_suppresses_nothing():
    assert (
        already_in_context(
            make_payload("projA", summary=QUERIED_RULE), frozenset(), "low"
        )
        is False
    )


# --- integration: the failure scenarios from the review ----------------------

def test_low_risk_never_suppresses_over_non_emitted_fields(tmp_path):
    """Review item 1, red demonstration. At low risk render_context emits
    summary+topic_tags only. A detailed_summary quoted verbatim in the
    caller's context must NOT suppress a node whose emitted summary is new."""
    home = tmp_path / "ralph_home"
    store = TreeStore(home)
    node = store.create_node(
        make_payload(
            "projA",
            node_id="rule_low",
            summary="database indexes",  # NEW to the caller
            detailed_summary=QUERIED_RULE,  # quoted in context, NEVER emitted at low risk
        )
    )
    report = recall(
        "database indexes",
        make_context("projA"),
        home,
        limit=5,
        active_context=ACTIVE_CONTEXT,
    )
    assert report["analysis"]["risk_level"] == "low"
    ids = report["MEMORY_TRACE"]["selected_memory_ids"]
    assert node["node_id"] in ids, (
        "suppressed over non-emitted detailed_summary: the caller would have "
        "received this NEW summary -- C5 withheld it for nothing"
    )
    reasons = {r["node_id"]: r["reason"] for r in report["MEMORY_TRACE"]["rejected"]}
    assert reasons.get(node["node_id"]) != "already_in_context"


def test_low_risk_counts_emitted_topic_tags(tmp_path):
    """The flip side of item 1: topic_tags ARE emitted at low risk, so they
    must count toward containment. Without them this node sits at 5 covered
    tokens -- under the absolute floor -- and would survive."""
    home = tmp_path / "ralph_home"
    store = TreeStore(home)
    node = store.create_node(
        make_payload(
            "projA",
            node_id="rule_tags",
            summary="use staged rollout windows tuesday",
            topic_tags=["database"],
        )
    )
    tags_context = ACTIVE_CONTEXT + (
        " Release process note: use staged rollout windows tuesday for the"
        " shared cluster."
    )
    report = recall(
        "staged rollout windows",
        make_context("projA"),
        home,
        limit=5,
        active_context=tags_context,
    )
    assert report["analysis"]["risk_level"] == "low"
    ids = report["MEMORY_TRACE"]["selected_memory_ids"]
    reasons = {r["node_id"]: r["reason"] for r in report["MEMORY_TRACE"]["rejected"]}
    assert reasons.get(node["node_id"]) == "already_in_context", (
        "topic_tags are emitted at low risk: containment must see them"
    )
    assert node["node_id"] not in ids


def test_short_generic_summary_survives_unquoted_context(tmp_path):
    """Review item 2, red demonstration. A 5-token summary whose tokens all
    appear somewhere in a long generic context is NOT a real quote: the
    absolute floor keeps it (containment alone would say 5/5 = 1.0)."""
    home = tmp_path / "ralph_home"
    store = TreeStore(home)
    node = store.create_node(
        make_payload(
            "projA",
            node_id="rule_generic",
            summary="never bypass the security hooks guard",
        )
    )
    report = recall(
        "bypass security hooks",
        make_context("projA"),
        home,
        limit=5,
        active_context=GENERIC_CONTEXT,
    )
    ids = report["MEMORY_TRACE"]["selected_memory_ids"]
    assert node["node_id"] in ids, (
        "suppressed a short generic summary over scattered vocabulary: that "
        "is context-size suppression, not duplication"
    )


# --- the original dual test + CLI --------------------------------------------

def test_duplicate_is_suppressed_distinct_passes(tmp_path):
    """The dual test: a node the context already quotes is suppressed; an
    unrelated node survives with its untouched score."""
    home, _store, dup, keep = _seed(tmp_path)

    baseline = recall(QUERIED_QUERY, make_context("projA"), home, limit=5)
    suppressed = recall(
        QUERIED_QUERY,
        make_context("projA"),
        home,
        limit=5,
        active_context=ACTIVE_CONTEXT,
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
    home, _store, dup, keep = _seed(tmp_path)
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
            QUERIED_QUERY,
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
