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
persist nodes into the real per-project memory tree via
``tree_store.TreeStore.create_node``.

Persistence (``--apply``) targets the real tree for the current worktree,
keyed by ``tree_store.compute_project_id(repo_root)`` so the migrated nodes are
immediately recallable by ``recall_v2`` (which rejects any node whose
``project_id`` differs from the active context). The migration overrides each
payload's provenance fields (``project_id``, ``workspace_instance_id``,
``repo_remote_hash``, ``branch``, ``created_on_branch``) with the real-tree
context before writing.

Idempotency: each node uses a deterministic ``node_id`` (derived from the
sanitized rule id, or the content-hashed fallback in ``memory_node``). A second
run never duplicates a node -- an existing node is UPDATED in place (refreshing
fields) rather than re-created, and is counted under ``updated``.
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
from tree_store import (  # noqa: E402
    TreeStore,
    TreeStoreError,
    compute_project_id,
    repo_remote_hash,
    workspace_instance_id,
)

DEFAULT_RULES_PATH = Path.home() / ".ralph" / "procedural" / "rules.json"
DEFAULT_REJECTS_PATH = Path.home() / ".ralph" / "cache" / "migration-rejects.jsonl"

# Stable provenance for migrated nodes (used only when not persisting into a
# real per-project tree, e.g. JSONL-only emission).
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


def _tree_provenance(repo_root: Path) -> dict[str, str]:
    """Real-tree provenance overrides keyed by ``compute_project_id``.

    Migrated nodes must carry the active context's ``project_id`` so that
    ``recall_v2`` (which hard-rejects mismatched projects) can return them.
    """
    root = repo_root.expanduser().resolve()
    return {
        "project_id": compute_project_id(root),
        "workspace_instance_id": workspace_instance_id(root),
        "repo_remote_hash": repo_remote_hash(root),
        "branch": MIGRATION_BRANCH,
        "created_on_branch": MIGRATION_BRANCH,
    }


def _persist_node(
    store: TreeStore, node: MemoryNode, stats: dict[str, int]
) -> None:
    """Idempotently write *node* into the tree: create, or update if it exists.

    The node_id is deterministic (sanitized rule id or content hash), so a
    re-run never duplicates: an existing node is updated in place.
    """
    payload = node.to_dict()
    try:
        store.create_node(payload)
        stats["created"] += 1
    except TreeStoreError:
        # Already present -> update in place (idempotent re-run).
        store.update_node(node.project_id, node.node_id, payload)
        stats["updated"] += 1


def migrate(
    rules_path: Path,
    rejects_path: Path,
    apply: bool,
    store: TreeStore | None = None,
    repo_root: Path | None = None,
) -> dict[str, Any]:
    raw = json.loads(rules_path.read_text(encoding="utf-8"))
    rules = raw.get("rules", raw) if isinstance(raw, dict) else raw
    if not isinstance(rules, list):
        raise ValueError("rules.json did not contain a list of rules")

    stats: dict[str, Any] = {
        "total": len(rules),
        "passed": 0,
        "red": 0,
        "failed": 0,
        "created": 0,
        "updated": 0,
    }
    rejects: list[dict[str, Any]] = []
    nodes_out: list[dict[str, Any]] = []

    overrides: dict[str, str] = {}
    if apply and store is not None and repo_root is not None:
        overrides = _tree_provenance(repo_root)
        stats["project_id"] = overrides["project_id"]

    def process_rule(index: int, rule: object) -> None:
        """Classify, validate, and (on --apply) persist a single rule."""
        if not isinstance(rule, dict):
            stats["failed"] += 1
            rejects.append(
                {"index": index, "reason": "not_an_object", "rule": str(rule)[:200]}
            )
            return

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
            return

        if not str(behavior).strip():
            stats["failed"] += 1
            rejects.append(
                {
                    "index": index,
                    "rule_id": rule.get("rule_id") or rule.get("id"),
                    "reason": "empty_behavior",
                }
            )
            return

        payload = rule_to_payload(rule)
        # When persisting into the real tree, stamp the active-context
        # provenance so recall_v2 accepts the node.
        if overrides:
            payload.update(overrides)

        try:
            node = MemoryNode.from_dict(payload)
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
            return

        stats["passed"] += 1
        if not apply:
            return

        if store is not None:
            try:
                _persist_node(store, node, stats)
            except (MemoryNodeValidationError, TreeStoreError, OSError) as exc:
                stats["passed"] -= 1
                stats["failed"] += 1
                rejects.append(
                    {
                        "index": index,
                        "rule_id": rule.get("rule_id") or rule.get("id"),
                        "reason": "persist_error",
                        "error": str(exc),
                    }
                )
                return
        nodes_out.append(node.to_dict())

    # Bulk-write performance: defer the aggregate index.json rebuild to a single
    # pass at the end instead of rewriting it per node (O(n^2) -> O(n)). The
    # context manager is a no-op when not persisting to a tree.
    if apply and store is not None:
        with store.deferred_index():
            for index, rule in enumerate(rules):
                process_rule(index, rule)
    else:
        for index, rule in enumerate(rules):
            process_rule(index, rule)

    # Always write rejects (even on dry-run) so they are never lost silently.
    if rejects:
        rejects_path.parent.mkdir(parents=True, exist_ok=True)
        with rejects_path.open("w", encoding="utf-8") as fh:
            for entry in rejects:
                fh.write(json.dumps(entry, ensure_ascii=True) + "\n")

    if apply and nodes_out:
        out_path = rejects_path.parent / "migrated-nodes.jsonl"
        with out_path.open("w", encoding="utf-8") as fh:
            for node_payload in nodes_out:
                fh.write(json.dumps(node_payload, ensure_ascii=True) + "\n")
        stats["written_to"] = str(out_path)

    if store is not None and stats.get("project_id"):
        stats["tree_path"] = str(store.project_tree(str(stats["project_id"])))

    stats["rejects_logged_to"] = str(rejects_path) if rejects else ""
    return stats


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rules", type=Path, default=DEFAULT_RULES_PATH)
    parser.add_argument("--rejects", type=Path, default=DEFAULT_REJECTS_PATH)
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        help="Repo root used to derive the per-project tree (compute_project_id).",
    )
    parser.add_argument(
        "--ralph-home",
        type=Path,
        default=None,
        help="Override the ~/.ralph home for the tree store (testing).",
    )
    parser.add_argument(
        "--jsonl-only",
        action="store_true",
        help="On --apply, only emit migrated-nodes.jsonl; do NOT persist to tree.",
    )
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
        help="Persist migrated nodes into the real per-project memory tree.",
    )
    args = parser.parse_args(argv)

    apply = bool(args.apply)
    if not args.rules.exists():
        print(f"ERROR: rules file not found: {args.rules}", file=sys.stderr)
        return 2

    store: TreeStore | None = None
    repo_root: Path | None = None
    if apply and not args.jsonl_only:
        store = TreeStore(args.ralph_home) if args.ralph_home else TreeStore()
        repo_root = args.repo_root

    stats = migrate(
        args.rules, args.rejects, apply=apply, store=store, repo_root=repo_root
    )

    mode_label = "APPLY" if apply else "DRY-RUN"
    print(f"=== Migration {mode_label} ===")
    print(f"total rules:   {stats['total']}")
    print(f"passed:        {stats['passed']}")
    print(f"created:       {stats['created']}")
    print(f"updated:       {stats['updated']}")
    print(f"failed (val):  {stats['failed']}")
    print(f"RED (blocked): {stats['red']}")
    if stats.get("project_id"):
        print(f"project_id:    {stats['project_id']}")
    if stats.get("tree_path"):
        print(f"tree path:     {stats['tree_path']}")
    if stats.get("rejects_logged_to"):
        print(f"rejects log:   {stats['rejects_logged_to']}")
    if stats.get("written_to"):
        print(f"nodes jsonl:   {stats['written_to']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
