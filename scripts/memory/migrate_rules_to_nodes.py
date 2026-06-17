#!/usr/bin/env python3
"""One-shot migration: wrap each procedural rule in a MemoryNode v2.

Reads ``~/.ralph/procedural/rules.json`` (the 2028-rule procedural corpus) and
wraps EACH rule in a validated ``MemoryNode`` v2, mapping:

    rule_id      -> node_id (sanitized; falls back to deterministic id)
    behavior     -> summary
    trigger      -> trigger.text
    confidence   -> quality.confidence
    tags         -> topic_tags
    (inferred)   -> domain   (fixes the 1881 UNSET rules at the root)

Rules that fail the RED-gate or schema validation are NOT silently dropped:
they are appended to ``~/.ralph/cache/migration-rejects.jsonl`` with the reason.

By default this runs in ``--dry-run`` mode: it reports how many rules would
pass / fail / are RED, WITHOUT writing any nodes. Pass ``--apply`` to actually
write nodes (writing of the node store is the responsibility of B2 / tree_store;
this script only builds + validates and emits a JSONL stream on --apply).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# Allow running directly: add this script's dir to the import path.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from memory_node import (  # noqa: E402
    MemoryNode,
    MemoryNodeValidationError,
    infer_domain,
    safe_identifier,
)
from sensitive_content import classify_text  # noqa: E402

DEFAULT_RULES_PATH = Path.home() / ".ralph" / "procedural" / "rules.json"
DEFAULT_REJECTS_PATH = Path.home() / ".ralph" / "cache" / "migration-rejects.jsonl"

# Stable provenance for migrated nodes.
MIGRATION_PROJECT_ID = "multi-agent-ralph-loop"
MIGRATION_BRANCH = "procedural-migration"
MIGRATION_SESSION = "rules-json-migration-v2"


def _coerce_node_id(rule: dict[str, Any]) -> str | None:
    """Return a safe node_id derived from rule_id/id, or None to defer to the
    deterministic id generator."""
    raw = rule.get("rule_id") or rule.get("id") or rule.get("name")
    if not raw:
        return None
    candidate = "rule_" + str(raw)
    # Sanitize to the safe-id charset; collapse anything illegal to '-'.
    cleaned = "".join(c if (c.isalnum() or c in "._-") else "-" for c in candidate)
    cleaned = cleaned[:128].strip("-") or None
    if cleaned is None:
        return None
    try:
        safe_identifier(cleaned, "node_id")
    except MemoryNodeValidationError:
        return None
    return cleaned


def rule_to_payload(rule: dict[str, Any]) -> dict[str, Any]:
    """Map a procedural rule dict to a MemoryNode payload."""
    behavior = rule.get("behavior") or rule.get("pattern") or rule.get("name") or ""
    trigger_text = rule.get("trigger") or ""
    tags = rule.get("tags") or []
    if not isinstance(tags, list):
        tags = [str(tags)]
    confidence = rule.get("confidence")
    try:
        confidence = float(confidence) if confidence is not None else 0.75
    except (TypeError, ValueError):
        confidence = 0.75
    confidence = max(0.0, min(1.0, confidence))

    existing_domain = rule.get("domain")
    domain = (
        existing_domain
        if existing_domain
        and existing_domain not in ("UNSET", "unset")
        else infer_domain(f"{behavior} {trigger_text}", tags)
    )

    source_repo = rule.get("source_repo") or "procedural-memory"

    payload: dict[str, Any] = {
        "project_id": MIGRATION_PROJECT_ID,
        "workspace_instance_id": "migration",
        "repo_remote_hash": "procedural",
        "branch": MIGRATION_BRANCH,
        "commit": "",
        "session_id": MIGRATION_SESSION,
        "memory_type": "procedural_rule",
        "sensitivity": "GREEN",
        "authority": "non_authoritative",
        "summary": str(behavior).strip(),
        "domain": domain,
        "trigger": {"text": str(trigger_text).strip()} if trigger_text else {},
        "topic_tags": [str(t) for t in tags],
        "source_description": f"Migrated from procedural rules.json ({source_repo})",
        "quality": {
            "confidence": confidence,
            "usage_count": rule.get("usage_count", 0),
            "severity": rule.get("severity"),
        },
        "created_at": rule.get("created_at") or "",
    }
    node_id = _coerce_node_id(rule)
    if node_id:
        payload["node_id"] = node_id
    return payload


def migrate(
    rules_path: Path,
    rejects_path: Path,
    apply: bool,
) -> dict[str, int]:
    raw = json.loads(rules_path.read_text(encoding="utf-8"))
    rules = raw.get("rules", raw) if isinstance(raw, dict) else raw
    if not isinstance(rules, list):
        raise ValueError("rules.json did not contain a list of rules")

    stats = {"total": len(rules), "passed": 0, "red": 0, "failed": 0}
    rejects: list[dict[str, Any]] = []
    nodes_out: list[dict[str, Any]] = []

    for index, rule in enumerate(rules):
        if not isinstance(rule, dict):
            stats["failed"] += 1
            rejects.append(
                {"index": index, "reason": "not_an_object", "rule": str(rule)[:200]}
            )
            continue

        behavior = rule.get("behavior") or rule.get("pattern") or rule.get("name") or ""
        trigger_text = rule.get("trigger") or ""

        # RED-gate first: never even attempt to build a node from RED material.
        red_blob = f"{behavior}\n{trigger_text}\n{' '.join(str(t) for t in (rule.get('tags') or []))}"
        report = classify_text(red_blob)
        if report.classification == "RED":
            stats["red"] += 1
            rejects.append(
                {
                    "index": index,
                    "rule_id": rule.get("rule_id") or rule.get("id"),
                    "reason": "RED_gate",
                    "findings": [f.public_dict() for f in report.findings],
                }
            )
            continue

        if not str(behavior).strip():
            stats["failed"] += 1
            rejects.append(
                {
                    "index": index,
                    "rule_id": rule.get("rule_id") or rule.get("id"),
                    "reason": "empty_behavior",
                }
            )
            continue

        try:
            node = MemoryNode.from_dict(rule_to_payload(rule))
        except (MemoryNodeValidationError, ValueError, TypeError) as exc:
            stats["failed"] += 1
            rejects.append(
                {
                    "index": index,
                    "rule_id": rule.get("rule_id") or rule.get("id"),
                    "reason": "validation_error",
                    "error": str(exc),
                }
            )
            continue

        stats["passed"] += 1
        if apply:
            nodes_out.append(node.to_dict())

    # Always write rejects (even on dry-run) so they are never lost silently.
    if rejects:
        rejects_path.parent.mkdir(parents=True, exist_ok=True)
        with rejects_path.open("w", encoding="utf-8") as fh:
            for entry in rejects:
                fh.write(json.dumps(entry, ensure_ascii=True) + "\n")

    if apply and nodes_out:
        out_path = rejects_path.parent / "migrated-nodes.jsonl"
        with out_path.open("w", encoding="utf-8") as fh:
            for node in nodes_out:
                fh.write(json.dumps(node, ensure_ascii=True) + "\n")
        stats["written_to"] = str(out_path)  # type: ignore[assignment]

    stats["rejects_logged_to"] = str(rejects_path) if rejects else ""  # type: ignore[assignment]
    return stats


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rules", type=Path, default=DEFAULT_RULES_PATH)
    parser.add_argument("--rejects", type=Path, default=DEFAULT_REJECTS_PATH)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run",
        action="store_true",
        default=True,
        help="Report counts only; do not write nodes (DEFAULT).",
    )
    mode.add_argument(
        "--apply",
        action="store_true",
        help="Build and emit migrated nodes to migrated-nodes.jsonl.",
    )
    args = parser.parse_args(argv)

    apply = bool(args.apply)
    if not args.rules.exists():
        print(f"ERROR: rules file not found: {args.rules}", file=sys.stderr)
        return 2

    stats = migrate(args.rules, args.rejects, apply=apply)

    mode_label = "APPLY" if apply else "DRY-RUN"
    print(f"=== Migration {mode_label} ===")
    print(f"total rules:   {stats['total']}")
    print(f"passed:        {stats['passed']}")
    print(f"failed (val):  {stats['failed']}")
    print(f"RED (blocked): {stats['red']}")
    if stats.get("rejects_logged_to"):
        print(f"rejects log:   {stats['rejects_logged_to']}")
    if stats.get("written_to"):
        print(f"nodes written: {stats['written_to']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
