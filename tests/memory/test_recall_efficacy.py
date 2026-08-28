"""#47 C3 — does recall find a relevant prior decision from a RELATED task?

Measured on a controlled corpus (tmp TreeStore, never the global vault):

  Q_LIT       reuses the node's own summary keywords      -> the baseline.
  Q_RELATED   shares only domain vocabulary carried by the node's structured
              fields (topic_tags / trigger / entities), never a substring of
              the summary -- the bridge a lexical engine can honestly cross.
  Q_PARA      shares no vocabulary with the node at all   -> the documented
              limit: score_node is substring matching over node text, so a
              true paraphrase mathematically cannot score > 0. Pinning that
              limit is deliberate: the engine must not fake semantics; a
              paraphrase-capable recall (embeddings / query expansion) is an
              engine change that consciously updates test 4.

The corpus (and the queries) live in _recall_fixtures.build_efficacy_corpus,
shared with results/t92_c3_probe.py: the pinned numbers below describe that
one definition, so probe and tests cannot drift apart (T92 review item 3).

Numbers from the T92 probe run: Q_LIT 42.0 (rank 1), Q_RELATED 24.0
(rank 1, via tags/trigger only), Q_PARA 0.0.
"""

from __future__ import annotations

import sys
from pathlib import Path

_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
_TESTS_DIR = Path(__file__).resolve().parent
for _p in (_MEMORY_DIR, _TESTS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from recall_v2 import analyze_query, recall  # noqa: E402
from tree_store import TreeStore  # noqa: E402
from _recall_fixtures import (  # noqa: E402
    Q_LIT,
    Q_PARA,
    Q_RELATED,
    TARGET_SUMMARY,
    TARGET_TAGS,
    TARGET_TRIGGER,
    build_efficacy_corpus,
    make_context,
)


def _corpus(home: Path) -> TreeStore:
    store = TreeStore(home)
    build_efficacy_corpus(store)
    return store


# --- the discriminant itself -------------------------------------------------

def test_c3_discriminant_related_query_never_touches_the_summary():
    """Guard for the probe's resolution: if any Q_RELATED search term were a
    substring of the summary, 'related retrieval' would be literal retrieval
    in disguise and tests 2-4 would prove nothing."""
    summary = TARGET_SUMMARY.lower()
    related_search_terms = analyze_query(Q_RELATED)["search_terms"]
    assert related_search_terms, "query must yield search terms"
    for term in related_search_terms:
        assert term not in summary, (
            f"discriminant broken: '{term}' from Q_RELATED is inside the "
            "target summary -- rewrite the fixture, not the assertion"
        )
    # ...and the bridge is real: the related query does overlap the node's
    # structured vocabulary (tags/trigger), which is what it must travel by.
    structured = " ".join(TARGET_TAGS + [TARGET_TRIGGER]).lower()
    assert any(term in structured for term in related_search_terms)


# --- measured outcomes -------------------------------------------------------

def test_c3_literal_query_recovers_the_decision(tmp_path):
    home = tmp_path / "ralph_home"
    _corpus(home)
    report = recall(Q_LIT, make_context("projA"), home, limit=5)
    selected = report["MEMORY_TRACE"]["selected_memory_ids"]
    assert selected, "literal query must retrieve the planted decision"
    assert selected[0] == "dec_daily_gate"
    top = report["memory_context"][0]
    assert top["node_id"] == "dec_daily_gate" and top["score"] > 0


def test_c3_related_query_recovers_via_structured_vocabulary(tmp_path):
    """The C3 claim, held where a lexical engine can honestly hold it: a task
    phrased differently but naming the same domain reaches the prior decision
    through its tags/trigger -- without any summary keyword."""
    home = tmp_path / "ralph_home"
    _corpus(home)
    report = recall(Q_RELATED, make_context("projA"), home, limit=5)
    selected = report["MEMORY_TRACE"]["selected_memory_ids"]
    assert "dec_daily_gate" in selected, (
        "related query failed to reach the prior decision -- if this ever "
        "fails, the vocabulary bridge narrowed; re-run results/t92_c3_probe.py "
        "and compare against the T92 numbers before touching scoring"
    )
    # Precision: the off-domain distractors must not ride along.
    assert "rule_db" not in selected and "rule_ui" not in selected
    top = report["memory_context"][0]
    assert top["node_id"] == "dec_daily_gate"


def test_c3_paraphrase_limit_is_pinned_not_faked(tmp_path):
    """The measured limit: zero vocabulary overlap -> no retrieval. This is
    the honest boundary of substring scoring, not a bug: recall must not
    fabricate semantic matches. Measured numbers (T92 probe run,
    results/t92_c3_probe.py): Q_LIT scores the target 42.0 (rank 1),
    Q_RELATED 24.0 (rank 1, via tags/trigger only), Q_PARA 0.0.

    Secondary finding pinned here: in the postings-index path a paraphrase
    leaves NO trace at all -- candidate_payloads pre-filters to an empty set,
    so the node never reaches the selection loop and never gets a no_match
    rejection reason. Silence, not error. Replacing this boundary
    (embeddings, expansion) is an engine decision with a measurement -- not a
    scoring tweak to make a test pass."""
    home = tmp_path / "ralph_home"
    _corpus(home)
    report = recall(Q_PARA, make_context("projA"), home, limit=5)
    assert report["memory_context"] == []
    assert "dec_daily_gate" not in report["MEMORY_TRACE"]["selected_memory_ids"]
    # The index path is silent about why: nothing was even scored.
    assert report["MEMORY_TRACE"]["rejected"] == []
