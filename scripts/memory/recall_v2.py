#!/usr/bin/env python3
"""Ralph Memory Tree recall v2 -- typed scoring retrieval (replaces grep).

Ported and adapted from codex-ralph-vault-loop/scripts/memory/recall_v2.py.

Adaptation notes vs. the codex original:
  * Self-contained: this B2 deliverable is a *library + CLI*, not hook glue.
    The codex version imported ``usage_ledger.record_usage`` and an
    ``active_context`` module; both belong to hook integration (B3) and are
    intentionally NOT wired here. recall() emits the MEMORY_TRACE in its
    return value -- persistence is a separate concern.
  * Reuses ``MemoryNode`` / ``contains_red_material`` (B1) and ``TreeStore`` /
    ``compute_project_id`` (this phase) -- nothing is redefined.

Public API:
    analyze_query(query) -> dict      query classification + risk level
    recall(query, ctx, home, ...) -> dict   {analysis, memory_context, MEMORY_TRACE}

Scoring (per spec):
    summary x5, trigger x8, entity/path/tags/links x6,
    recency 2.0 (<=30d) / 0.5 (older), salience x2,
    graph_bonus = min(len(links), 3),
    negative_bonus = 6 for negative_rule when query mentions
        {avoid, repeat, mistake, risk, unsafe, shortcut},
    penalties: stale -12, deprecated -25, merge_candidate -8.
    FINAL = sum(bonuses) - sum(penalties).

Hard-reject reasons:
    invalid_node, wrong_project, red, deprecated, missing_provenance,
    authority, conflict.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

if __package__:
    from .memory_node import (
        MemoryNode,
        MemoryNodeValidationError,
        contains_red_material,
    )
    from .tree_store import TreeStore, compute_project_id, workspace_instance_id
else:  # pragma: no cover - script-style import support.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from memory_node import (
        MemoryNode,
        MemoryNodeValidationError,
        contains_red_material,
    )
    from tree_store import TreeStore, compute_project_id, workspace_instance_id

STOPWORDS = {
    "the", "and", "for", "with", "from", "that", "this", "what", "when",
    "where", "into", "node", "memory", "does", "exist", "exists",
}
LOW_SIGNAL_TERMS = {"fixture", "marker", "placeholder", "reject", "rejection"}
HIGH_RISK = {
    "exact", "raw", "quote", "quoted", "reproduce", "version", "date",
    "metric", "command", "path", "function", "class", "benchmark", "number",
}
MEDIUM_RISK = {
    "why", "how", "risk", "validate", "compare", "should", "migration",
    "debug", "failure",
}
NEGATIVE_QUERY_TERMS = {"avoid", "repeat", "mistake", "risk", "unsafe", "shortcut"}
EXACT_PATTERNS = (
    r"\bexact\s+(?:command|file\s+path|path|function|class|metric|date|version|number)\b",
    r"\b(?:quote|quoted|reproduce)\b",
    r"\b(?:config|key)\b.{0,40}\b(?:exists|exist|present|set)\b",
    r"\bselected_memory_ids\b",
    r"\b\d+(?:\.\d+)?\b",
    r"\b20\d\d-\d\d-\d\d\b",
    r"\bv?\d+\.\d+(?:\.\d+)?\b",
)


@dataclass(frozen=True)
class Context:
    project_root: Path
    project_id: str
    workspace_instance_id: str
    branch: str


def compact_space(value: object) -> str:
    return re.sub(r"\s+", " ", "" if value is None else str(value)).strip()


def terms(value: str) -> list[str]:
    found: list[str] = []
    seen: set[str] = set()
    for item in re.findall(r"[A-Za-z0-9_./-]+", value.lower()):
        if len(item) < 3 or item in STOPWORDS or item in seen:
            continue
        seen.add(item)
        found.append(item)
    return found


def context_for(
    project_root: Path,
    project_id: str = "",
    branch: str = "",
    instance_id: str = "",
) -> Context:
    root = project_root.expanduser().resolve()
    return Context(
        project_root=root,
        project_id=project_id or compute_project_id(root),
        workspace_instance_id=instance_id or workspace_instance_id(root),
        branch=branch or "unknown",
    )


def analyze_query(query: str) -> dict[str, Any]:
    query_terms = terms(query)
    term_set = set(query_terms)
    temporal = re.findall(
        r"\b(?:20\d\d-\d\d-\d\d|20\d\d|today|yesterday|tomorrow)\b", query.lower()
    )
    intent = [item for item in query_terms if item in HIGH_RISK or item in MEDIUM_RISK]
    exact_fact = any(
        re.search(pattern, query, re.IGNORECASE) for pattern in EXACT_PATTERNS
    ) or ("exact" in term_set and any(item in HIGH_RISK for item in query_terms))
    search_terms = [
        item for item in query_terms if item not in HIGH_RISK and item not in MEDIUM_RISK
    ]
    if exact_fact or any(item in HIGH_RISK for item in query_terms):
        risk = "high"
    elif any(item in MEDIUM_RISK for item in query_terms):
        risk = "medium"
    else:
        risk = "low"
    return {
        "semantic_terms": query_terms,
        "search_terms": search_terms,
        "intent_terms": intent,
        "temporal_terms": temporal,
        "risk_level": risk,
        "exact_fact_mode": exact_fact,
    }


# ---------------------------------------------------------------------------
# Node iteration + hard rejection.
# ---------------------------------------------------------------------------

def node_id_for(payload: object, path: Path) -> str:
    if isinstance(payload, dict):
        node_id = payload.get("node_id")
        if isinstance(node_id, str) and node_id:
            return node_id
    return path.stem


def iter_node_payloads(store: TreeStore, project_id: str) -> list[tuple[Path, Any]]:
    directory = store.nodes_dir(project_id)
    if not directory.exists():
        return []
    payloads: list[tuple[Path, Any]] = []
    for path in sorted(directory.glob("*.json")):
        if path.name.startswith("."):
            continue
        try:
            payloads.append((path, json.loads(path.read_text(encoding="utf-8"))))
        except (OSError, json.JSONDecodeError, ValueError):
            payloads.append((path, None))
    return payloads


def _as_dict(value: object) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def deprecated(node: dict[str, Any]) -> bool:
    quality = _as_dict(node.get("quality"))
    return (
        quality.get("deprecated") is True
        or str(quality.get("status", "")).lower() == "deprecated"
    )


def provenance_complete(node: dict[str, Any]) -> bool:
    return bool(node.get("source_paths") or node.get("source_description")) and bool(
        node.get("session_id") or node.get("commit")
    )


def safe_fields(node: dict[str, Any]) -> dict[str, Any]:
    keys = (
        "summary", "detailed_summary", "trigger", "topic_tags", "entities",
        "source_paths", "links", "quality", "promotion_evidence",
    )
    return {key: node.get(key) for key in keys}


def hard_reject_reason(
    node: object, context: Context, include_deprecated: bool
) -> str:
    if not isinstance(node, dict):
        return "invalid_node"
    if node.get("project_id") != context.project_id:
        return "wrong_project"
    if node.get("sensitivity") == "RED" or contains_red_material(safe_fields(node)):
        return "red"
    if str(node.get("visibility") or "branch_local") == "conflict":
        return "conflict"
    if deprecated(node) and not include_deprecated:
        return "deprecated"
    if not provenance_complete(node):
        return "missing_provenance"
    if node.get("authority") != "non_authoritative":
        return "authority"
    try:
        MemoryNode.from_dict(node)
    except MemoryNodeValidationError:
        return "invalid_node"
    return ""


# ---------------------------------------------------------------------------
# Scoring.
# ---------------------------------------------------------------------------

def text_score(query_terms: list[str], text: object, weight: int) -> int:
    haystack = compact_space(text).lower()
    return sum(weight for item in query_terms if item and item in haystack)


def parse_time(value: object) -> datetime | None:
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed


def score_node(
    node: dict[str, Any], analysis: dict[str, Any]
) -> tuple[float, dict[str, float]]:
    raw_terms = analysis.get("search_terms")
    query_terms: list[str] = list(raw_terms) if isinstance(raw_terms, list) else []
    strong_terms = [item for item in query_terms if item not in LOW_SIGNAL_TERMS]
    scoring_terms = query_terms if analysis.get("risk_level") == "high" else strong_terms

    trigger = _as_dict(node.get("trigger"))
    summary_score = float(text_score(scoring_terms, node.get("summary"), 5))
    trigger_score = float(text_score(scoring_terms, trigger, 8))
    entity_path_score = float(
        text_score(
            scoring_terms,
            {
                "entities": node.get("entities"),
                "paths": node.get("source_paths"),
                "tags": node.get("topic_tags"),
                "links": node.get("links"),
            },
            6,
        )
    )

    if summary_score + trigger_score + entity_path_score <= 0:
        return 0.0, {
            "summary_score": summary_score,
            "trigger_score": trigger_score,
            "entity_path_score": entity_path_score,
        }

    updated = parse_time(node.get("updated_at")) or parse_time(node.get("created_at"))
    if updated is None:
        recency_score = 0.0
    elif (datetime.now(timezone.utc) - updated).days <= 30:
        recency_score = 2.0
    else:
        recency_score = 0.5

    salience = _as_dict(node.get("salience"))
    salience_score = round(
        sum(float(v) for v in salience.values() if isinstance(v, (int, float))) * 2, 2
    )

    links = node.get("links")
    graph_bonus = float(min(len(links) if isinstance(links, list) else 0, 3))

    semantic_terms = analysis.get("semantic_terms")
    semantic_set = set(semantic_terms) if isinstance(semantic_terms, list) else set()
    negative_bonus = (
        6.0
        if node.get("memory_type") == "negative_rule"
        and (semantic_set & NEGATIVE_QUERY_TERMS)
        else 0.0
    )

    quality = _as_dict(node.get("quality"))
    stale_penalty = 12.0 if quality.get("stale") is True else 0.0
    deprecated_penalty = 25.0 if deprecated(node) else 0.0
    merge_penalty = 8.0 if node.get("visibility") == "merge_candidate" else 0.0

    parts: dict[str, float] = {
        "summary_score": summary_score,
        "trigger_score": trigger_score,
        "entity_path_score": entity_path_score,
        "recency_score": recency_score,
        "salience_score": salience_score,
        "graph_bonus": graph_bonus,
        "negative_bonus": negative_bonus,
        "stale_penalty": stale_penalty,
        "deprecated_penalty": deprecated_penalty,
        "merge_candidate_penalty": merge_penalty,
    }
    base_score = (
        summary_score
        + trigger_score
        + entity_path_score
        + recency_score
        + salience_score
        + graph_bonus
        + negative_bonus
    )
    final = base_score - stale_penalty - deprecated_penalty - merge_penalty
    return final, parts


# ---------------------------------------------------------------------------
# Output rendering by risk level.
# ---------------------------------------------------------------------------

def raw_read_command(node_id: str) -> str:
    return (
        "python3 scripts/memory/recall_v2.py "
        f"--project-root . --read-raw --node-id {node_id}"
    )


def render_context(node: dict[str, Any], risk: str, score: float) -> dict[str, Any]:
    quality = _as_dict(node.get("quality"))
    base: dict[str, Any] = {
        "node_id": node["node_id"],
        "score": round(score, 2),
        "confidence": quality.get("confidence"),
        "summary": node.get("summary", ""),
    }
    if risk == "low":
        base["topic_tags"] = node.get("topic_tags", [])
    elif risk == "medium":
        base["detailed_summary"] = node.get("detailed_summary", "")
        base["source_paths"] = node.get("source_paths", [])
    else:  # high
        base["detailed_summary"] = node.get("detailed_summary", "")
        base["source_paths"] = node.get("source_paths", [])
        base["RAW_RECOMMENDED"] = bool(node.get("raw_ref"))
        base["suggested_read_command"] = raw_read_command(str(node["node_id"]))
    if node.get("memory_type") == "negative_rule":
        base["NEGATIVE_MEMORY"] = True
        base["warning_reason"] = quality.get("reason", "")
    return base


def estimate_units(item: dict[str, Any]) -> int:
    return max(1, len(json.dumps(item, ensure_ascii=True).split()))


# ---------------------------------------------------------------------------
# Recall.
# ---------------------------------------------------------------------------

def recall(
    query: str,
    context: Context,
    ralph_home: Path,
    limit: int = 5,
    budget_limit: int = 1200,
    include_deprecated: bool = False,
) -> dict[str, Any]:
    started = time.perf_counter()
    store = TreeStore(ralph_home)
    analysis = analyze_query(query)
    risk = str(analysis["risk_level"])
    rejected: list[dict[str, str]] = []
    scored: list[tuple[float, dict[str, Any], dict[str, float]]] = []

    for path, payload in iter_node_payloads(store, context.project_id):
        node_id = node_id_for(payload, path)
        reason = hard_reject_reason(payload, context, include_deprecated)
        if reason:
            rejected.append({"node_id": node_id, "reason": reason})
            continue
        assert isinstance(payload, dict)  # narrowed by hard_reject_reason
        score, parts = score_node(payload, analysis)
        if score <= 0:
            rejected.append({"node_id": node_id, "reason": "no_match"})
            continue
        scored.append((score, payload, parts))

    scored.sort(key=lambda item: (-item[0], str(item[1].get("node_id", ""))))

    selected: list[dict[str, Any]] = []
    used = 0
    for score, node, _parts in scored:
        if len(selected) >= limit:
            break
        item = render_context(node, risk, score)
        needed = estimate_units(item)
        if used + needed > budget_limit:
            rejected.append({"node_id": str(node["node_id"]), "reason": "budget_exceeded"})
            continue
        used += needed
        selected.append(item)

    latency_ms = max(0, int((time.perf_counter() - started) * 1000))
    trace = {
        "engine": "tree",
        "selected_memory_ids": [item["node_id"] for item in selected],
        "rejected": rejected,
        "token_budget": {"limit": budget_limit, "used": used},
        "risk_level": risk,
        "latency_ms": latency_ms,
    }
    return {"analysis": analysis, "memory_context": selected, "MEMORY_TRACE": trace}


# ---------------------------------------------------------------------------
# CLI.
# ---------------------------------------------------------------------------

def render_markdown(report: dict[str, Any]) -> str:
    analysis = report["analysis"]
    trace = report["MEMORY_TRACE"]
    lines = [
        "# Ralph Memory Tree Recall v2",
        "",
        f"- risk_level: `{analysis['risk_level']}`",
        f"- latency_ms: `{trace['latency_ms']}`",
        "",
        "## Selected",
        "",
    ]
    if not report["memory_context"]:
        lines.append("No MemoryNode v2 matches selected.")
    for item in report["memory_context"]:
        lines.append(
            f"- `{item['node_id']}` score={item['score']} "
            f"confidence={item.get('confidence')}: {item.get('summary', '')}"
        )
        if item.get("RAW_RECOMMENDED"):
            lines.append(f"  RAW_RECOMMENDED=true read: {item.get('suggested_read_command', '')}")
    lines.extend(
        ["", "MEMORY_TRACE=" + json.dumps(trace, ensure_ascii=True, sort_keys=True)]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Recall from the Ralph Memory Tree v2 (library + CLI; no hook glue)."
    )
    parser.add_argument("--project-root", default=".")
    parser.add_argument("--query", default="")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--project-id", default=os.environ.get("RALPH_PROJECT_ID", ""))
    parser.add_argument(
        "--ralph-home", default=os.environ.get("RALPH_HOME", "~/.ralph")
    )
    parser.add_argument("--branch", default="")
    parser.add_argument("--workspace-instance-id", default="")
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--budget", type=int, default=1200)
    parser.add_argument("--include-deprecated", action="store_true")
    parser.add_argument("--read-raw", action="store_true")
    parser.add_argument("--node-id", default="")
    args = parser.parse_args()

    context = context_for(
        Path(args.project_root),
        args.project_id,
        args.branch,
        args.workspace_instance_id,
    )

    if args.read_raw:
        store = TreeStore(Path(args.ralph_home))
        node = store.load_node(context.project_id, args.node_id)
        if node is None:
            print("node not found", file=sys.stderr)
            return 1
        raw_ref = node.get("raw_ref") if isinstance(node.get("raw_ref"), dict) else None
        digest = raw_ref.get("sha256") if raw_ref else None
        if not digest:
            print("node has no raw_ref", file=sys.stderr)
            return 1
        content = store.read_raw(context.project_id, str(digest))
        if content is None:
            print("raw unavailable or RED", file=sys.stderr)
            return 1
        print(content, end="")
        return 0

    report = recall(
        args.query,
        context,
        Path(args.ralph_home),
        max(0, args.limit),
        max(0, args.budget),
        args.include_deprecated,
    )
    if args.json:
        print(json.dumps(report, ensure_ascii=True, indent=2, sort_keys=True))
    else:
        print(render_markdown(report), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
