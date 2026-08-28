"""Shared recall fixtures (#47 T92, review item 3).

One definition of payload builder, context builder and the C3 efficacy
corpus, consumed by BOTH recall-style test modules and
results/t92_c3_probe.py. The probe's pinned numbers (42.0 / 24.0 / 0.0)
describe THIS corpus: change a scoring-relevant field here and every
consumer moves together, instead of three divergent copies silently
drifting apart.

Scope note (T103 mmx-3 #2): tests/memory/test_tree_store.py deliberately
keeps its OWN _payload() helper and does NOT import make_payload from
this module. The two helpers look superficially similar but serve
different test contracts:

  * recall tests parameterise the field under test per case (summary,
    trigger, quality, etc.) and benefit from generic defaults that
    force each test to set what matters.

  * tree_store tests assert on derived fields that depend on the payload
    content (e.g. `domain` derived from summary/trigger/topic_tags, the
    layout under nodes_dir, RED-on-raw re-checks). Those tests need a
    concrete payload — `summary="Use parameterized queries..."`,
    `trigger={"text":"writing SQL"}`, `topic_tags=["database","sql"]` —
    so that the derived fields are stable and the assertions make
    sense. Importing the generic helper would either lose the concrete
    assertions or push 20+ kwargs into every tree_store test call.

A parameterised helper that serves BOTH contracts was considered
(make_payload(project_id, summary=DEFAULT, trigger=None, ...)) and
rejected: every recall test would need to opt OUT of the rich defaults
to keep its "generic defaults force explicit intent" property, and
every tree_store test would need to opt IN with a long kwargs list.
The current split keeps each test family's contract local and explicit.
"""

from __future__ import annotations

import sys
from pathlib import Path

_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
if str(_MEMORY_DIR) not in sys.path:
    sys.path.insert(0, str(_MEMORY_DIR))

from recall_v2 import Context  # noqa: E402


def make_payload(project_id: str, **overrides):
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


def make_context(project_id: str) -> Context:
    return Context(
        project_root=Path("."),
        project_id=project_id,
        workspace_instance_id="ws1",
        branch="main",
    )


# --- the C3 efficacy corpus (shared by test + probe) ------------------------
# A prior DECISION (planted like a real one: specific summary, structured
# vocabulary in tags/trigger/entities) plus two off-domain distractors.

TARGET_SUMMARY = (
    "Retired the daily-gate hook after its before/after ledger showed "
    "net-negative latency across three of four hooks"
)
TARGET_TRIGGER = "starting a hook latency optimization or hook-removal task"
TARGET_TAGS = ["hooks", "measurement-discipline", "optimization"]
TARGET_ENTITIES = ["daily-gate", "T81", "QTEAM_FAILURE_MODES"]

Q_LIT = "daily-gate hook ledger net-negative"
Q_RELATED = "wake-up startup optimization task"
Q_PARA = "morning boot sequence performance regression"


def build_efficacy_corpus(store) -> None:
    base = {"memory_type": "decision", "source_description": "session ledger"}
    store.create_node(
        make_payload(
            "projA",
            **{
                **base,
                "node_id": "dec_daily_gate",
                "summary": TARGET_SUMMARY,
                "trigger": {"text": TARGET_TRIGGER},
                "topic_tags": TARGET_TAGS,
                "entities": TARGET_ENTITIES,
            },
        )
    )
    store.create_node(
        make_payload(
            "projA",
            node_id="rule_db",
            summary="always use parameterized queries and explicit transactions",
            trigger={"text": "writing sql by hand"},
            topic_tags=["database"],
        )
    )
    store.create_node(
        make_payload(
            "projA",
            node_id="rule_ui",
            summary="frontend components follow WCAG contrast rules",
            trigger={"text": "shipping user interface work"},
            topic_tags=["frontend"],
        )
    )


# --- the C5 active-context fixtures -----------------------------------------

QUERIED_RULE = "always use parameterized queries for database access"
DISTINCT_RULE = "encrypt sensitive backups at rest with managed keys"

# A realistic active context: the caller is mid-task and already quotes the
# queried rule verbatim (that is exactly the duplication C5 targets).
ACTIVE_CONTEXT = (
    "Task: add the orders repository. Team standard reminder: we "
    f"{QUERIED_RULE}, enforced in review. Out of scope: frontend."
)

# Deliberately generic operational prose: contains every token of the short
# generic summary below WITHOUT quoting it -- the false-suppression case.
GENERIC_CONTEXT = (
    "Rollout notes for the platform team: during a deploy never bypass the "
    "security hooks guard, even under time pressure; the checklist lives in "
    "the runbook and applies to every environment."
)
