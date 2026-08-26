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
    attribution,
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


# --- T69: mechanical exclusion + emission-level dedup ----------------------

def test_reject_mechanical_prefix(store):
    node = _payload("projA", node_id="rule_ep-auto-1772663931-20800")
    assert hard_reject_reason(node, _ctx("projA"), False) == "mechanical"
    # escape hatch: explicitly admitted
    assert hard_reject_reason(node, _ctx("projA"), False, include_mechanical=True) == ""


def test_reject_mechanical_ep_rule_variant(store):
    node = _payload("projA", node_id="rule_ep-rule-42-1")
    assert hard_reject_reason(node, _ctx("projA"), False) == "mechanical"


def test_recall_broad_query_spends_no_slot_on_mechanical(store, tmp_path):
    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    real = s.create_node(
        _payload("projA", summary="database parameterized queries rule")
    )
    # the two dominant mechanical fillers of the retired curator era
    s.create_node(
        _payload("projA", node_id="rule_ep-auto-1772663931-20800",
                 summary="Uses async/await for asynchronous operations")
    )
    s.create_node(
        _payload("projA", node_id="rule_ep-auto-1772664000-99999",
                 summary="Implements caching strategy")
    )
    report = recall("database queries rule caching", _ctx("projA"), home, limit=5)
    selected = report["MEMORY_TRACE"]["selected_memory_ids"]
    assert selected == [real["node_id"]]
    reasons = {r["reason"] for r in report["MEMORY_TRACE"]["rejected"]}
    assert "mechanical" in reasons


def test_recall_include_mechanical_escape_hatch(store, tmp_path):
    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    s.create_node(_payload("projA", summary="database parameterized queries rule"))
    mech = s.create_node(
        _payload("projA", node_id="rule_ep-auto-1772663931-20800",
                 summary="Uses caching strategy database queries")
    )
    report = recall(
        "database queries caching", _ctx("projA"), home, limit=5,
        include_mechanical=True,
    )
    assert mech["node_id"] in report["MEMORY_TRACE"]["selected_memory_ids"]


def test_recall_dedup_collapses_identical_summary(store, tmp_path):
    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    s.create_node(
        _payload("projA", node_id="rule_real-1",
                 summary="always use parameterized SQL   queries")
    )
    # same content, different casing/whitespace and node_id (non-mechanical:
    # duplicates can also come from hand-written rules)
    s.create_node(
        _payload("projA", node_id="rule_real-2",
                 summary="Always use parameterized SQL queries")
    )
    report = recall("parameterized SQL queries", _ctx("projA"), home, limit=5)
    selected = report["MEMORY_TRACE"]["selected_memory_ids"]
    assert len(selected) == 1
    reasons = [r["reason"] for r in report["MEMORY_TRACE"]["rejected"]]
    assert "duplicate_summary" in reasons


def test_recall_keeps_distinct_summaries_separate(store, tmp_path):
    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    a = s.create_node(
        _payload("projA", node_id="rule_real-1",
                 summary="always use parameterized SQL queries")
    )
    # one word different: legitimately distinct knowledge, must NOT be fused
    b = s.create_node(
        _payload("projA", node_id="rule_real-2",
                 summary="always use parameterized NoSQL queries")
    )
    report = recall("parameterized queries", _ctx("projA"), home, limit=5)
    selected = report["MEMORY_TRACE"]["selected_memory_ids"]
    assert set(selected) == {a["node_id"], b["node_id"]}


# --- T73: source attribution in the emitted context (#47 C4) ---------------

def test_attribution_prefers_first_path_bounded():
    node = {
        "source_paths": [
            "/very/long/path/that/goes/on/and/on/and/on/and/on/and/on/and/on/x.md",
            "/second/path.md",
        ],
        "source_description": "fallback description",
    }
    src = attribution(node)
    assert src.startswith("/very/long/path")
    assert "/second/path" not in src
    assert len(src) <= 80


def test_attribution_falls_back_to_description():
    node = {
        "source_paths": [],
        "source_description": "Migrated from procedural rules.json (user-global-rules)",
    }
    assert attribution(node) == "Migrated from procedural rules.json (user-global-rules)"
    long = "x" * 200
    assert attribution({"source_paths": [], "source_description": long}) == "x" * 77 + "..."


def test_attribution_empty_when_no_provenance():
    # unreachable via recall() (missing_provenance rejects it first), but the
    # helper must not invent attribution
    assert attribution({"source_paths": [], "source_description": ""}) == ""


def test_recall_low_risk_emits_source(store, tmp_path):
    # the C4 gap: low-risk render shipped no attribution at all; migrated
    # nodes carry empty source_paths and a populated source_description
    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    s.create_node(
        _payload(
            "projA",
            summary="database parameterized queries rule",
            source_paths=[],
            source_description="Migrated from procedural rules.json",
        )
    )
    report = recall("database parameterized queries", _ctx("projA"), home, limit=5)
    assert report["analysis"]["risk_level"] == "low"
    item = report["memory_context"][0]
    assert item["source"] == "Migrated from procedural rules.json"


# --- budget default (C8, #47): measured, not intuitive -----------------------

def test_default_budget_is_the_measured_plateau():
    """800, not 1200 (T70+T72 over this project's corpus): the real top-5
    needs 418 units, 800 is the benefit plateau on both the broad hook query
    and directed queries, and 1200 bought exactly nothing over it."""
    import inspect

    assert inspect.signature(recall).parameters["budget_limit"].default == 800


def test_cli_default_budget_is_800():
    """The wake-up hook invokes the CLI without --budget, so the CLI default
    is the operative number. MEMORY_TRACE reports the limit actually
    applied."""
    import json
    import subprocess

    proc = subprocess.run(
        [
            sys.executable,
            str(_MEMORY_DIR / "recall_v2.py"),
            "--project-root",
            ".",
            "--query",
            "database parameterized queries",
            "--json",
        ],
        capture_output=True,
        text=True,
        timeout=30,
        check=True,
    )
    trace = json.loads(proc.stdout)["MEMORY_TRACE"]
    assert trace["token_budget"]["limit"] == 800


def test_budget_valley_is_real_and_documented(tmp_path):
    """A middling budget can select WORSE than a smaller one (T72 finding).

    Geometry measured on the real corpus: one high-ranked rule renders huge
    (zero-tests-is-never-success: 257 units alone) while its rank neighbors
    are small. At 400 the greedy admits it and crowds out two smaller rules
    that together outscore it; at 256 it never fits and the smaller ones
    fill the limit. This pins the behavior so nobody later "fixes" the
    default by picking a middling value for safety — that is the worst
    point of the range. Monotonicity would require ranking by score/units
    inside the budget, which is an engine decision, not a default change.
    """
    from recall_v2 import estimate_units

    home = tmp_path / "ralph_home"
    s = TreeStore(home)
    words = "rollback savepoint migration index trigger constraint".split()

    def node(trigger_terms, summary_terms, pad=0):
        return _payload(
            "projA",
            summary=("filler " * pad + " ".join(summary_terms)).strip(),
            trigger={"text": " ".join(trigger_terms)},
        )

    # Strict score order (trigger weight 8, summary weight 5):
    # A 48 > B 40 > C 32 > D 29 > E 26 > F 23, with E+F = 49 > B = 40 —
    # the valley condition: the big item is worth LESS than the two smalls
    # it displaces.
    s.create_node(node(words[0:6], ["rule", "alpha"], pad=25))
    s.create_node(node(words[1:6], ["rule", "beta"], pad=260))
    s.create_node(node(words[2:6], ["rule", "gamma"], pad=25))
    s.create_node(node(words[3:6], [words[0]], pad=25))
    s.create_node(node(words[4:6], [words[0], words[1]], pad=25))
    s.create_node(node(words[5:6], [words[0], words[1], words[2]], pad=25))

    ctx = _ctx("projA")
    query = " ".join(words)

    full = recall(query, ctx, home, limit=10, budget_limit=10**9)["memory_context"]
    units = [estimate_units(i) for i in full]
    scores = [i["score"] for i in full]
    # Preconditions: the fixture reproduces the measured geometry (T72 real
    # corpus: big rule 257u, smalls 33-48u). If these fail, the padding
    # drifted — fix the fixture, do not relax the asserts.
    assert scores == sorted(scores, reverse=True) and len(set(scores)) == 6
    big, smalls = units[1], units[0:1] + units[2:]
    assert 265 <= big <= 290, f"big item drifted: {big} units"
    assert all(30 <= u <= 55 for u in smalls), f"small items drifted: {units}"

    sel_256 = recall(query, ctx, home, limit=5, budget_limit=256)["memory_context"]
    sel_400 = recall(query, ctx, home, limit=5, budget_limit=400)["memory_context"]
    sum_256 = sum(i["score"] for i in sel_256)
    sum_400 = sum(i["score"] for i in sel_400)

    assert len(sel_256) == 5, "256 must fill the limit with small items"
    assert len(sel_400) < len(sel_256), (
        "400 must admit the big item and crowd out small ones (exact count "
        "depends on rendering overhead; 3-4 observed)"
    )
    assert units[1] == estimate_units(sel_400[1]), "the big item must be in at 400"
    assert all(estimate_units(i) != units[1] for i in sel_256), "big item must not fit at 256"
    assert sum_256 > sum_400, (
        f"THE VALLEY: 400 selects worse than 256 ({sum_400} vs {sum_256}) — "
        f"if this ever fails, the engine became monotone and the default "
        f"comment in recall() is stale"
    )


# --- quality states (#47 C6): never silently trusted -------------------------

def test_reject_conflicting_status(store):
    """"conflicting" must not be silently promoted into context."""
    written = store.create_node(
        _payload("projA", quality={"confidence": 0.9, "status": "conflicting"})
    )
    node = store.load_node("projA", written["node_id"])
    assert node is not None
    assert hard_reject_reason(node, _ctx("projA"), False) == "conflict"


def test_stale_risk_status_penalized_like_the_stale_flag():
    analysis = analyze_query("rollback savepoint")
    clean = _payload("projA", trigger={"text": "rollback savepoint"})
    risky = _payload(
        "projA",
        trigger={"text": "rollback savepoint"},
        quality={"confidence": 0.9, "status": "stale-risk"},
    )
    s_clean, _ = score_node(clean, analysis)
    s_risky, _ = score_node(risky, analysis)
    assert s_clean - s_risky == 12.0


def test_stale_items_are_marked_not_just_penalized(store):
    """The binary stale flag used to only lower the score — the item still
    entered context with no visible warning (semi-silent trust). Now both
    the flag and the stale-risk status mark NEGATIVE_MEMORY."""
    from recall_v2 import render_context

    items = []
    for marker, quality in (("flag", {"confidence": 0.9, "stale": True}),
                            ("risk", {"confidence": 0.9, "status": "stale-risk"})):
        written = store.create_node(
            _payload("projA", summary=f"stale marker {marker}", quality=quality)
        )
        node = store.load_node("projA", written["node_id"])
        assert node is not None
        items.append(render_context(node, "low", 10.0))
    for item in items:
        assert item["NEGATIVE_MEMORY"] is True
        assert item["warning_reason"], "the warning must say why, not just flag"

    written = store.create_node(_payload("projA"))
    clean = store.load_node("projA", written["node_id"])
    assert clean is not None
    assert "NEGATIVE_MEMORY" not in render_context(clean, "low", 10.0)


def test_verified_unverified_carried_visibly(store):
    """"verified"/"unverified" ride along as a field: visible, unpenalized."""
    from recall_v2 import render_context

    rendered = {}
    for status in ("verified", "unverified"):
        written = store.create_node(
            _payload("projA", summary=f"marker {status}",
                     quality={"confidence": 0.9, "status": status})
        )
        node = store.load_node("projA", written["node_id"])
        assert node is not None
        rendered[status] = render_context(node, "low", 10.0)
    assert rendered["verified"]["verification"] == "verified"
    assert rendered["unverified"]["verification"] == "unverified"
    for item in rendered.values():
        assert "NEGATIVE_MEMORY" not in item, "unverified is not negative"
