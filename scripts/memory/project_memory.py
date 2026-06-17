#!/usr/bin/env python3
"""Project memory projection -- read-only GREEN-node view into Claude native memory.

Part of plan B4 ("Reconciliar memoria nativa Claude + vault"): the native
``MEMORY.md`` is no longer a parallel source of truth. Instead, the top GREEN
nodes of the project's tree store are *projected* (read-only) into a single
delimited block inside Claude's native project ``MEMORY.md``. This keeps the
native integration the user wants, with zero drift, because the block is
regenerated from the tree store rather than hand-edited.

CRITICAL safety contract (the reason this script exists at all):
  * The native ``MEMORY.md`` may contain the user's own hand-written notes.
    This script NEVER clobbers it. It inserts/updates ONLY the content between
    the two sentinel comments::

        <!-- ralph-green-nodes:start (auto-generated, do not edit) -->
        ...
        <!-- ralph-green-nodes:end -->

  * Everything outside the block is preserved byte-for-byte (modulo a single
    trailing newline normalization).
  * If the file or the block does not exist, they are created without touching
    any pre-existing content.
  * The operation is idempotent: running it twice with the same nodes yields
    the same file.

The Claude native project id is the project's absolute path with every ``/``
and ``.`` replaced by ``-`` (e.g. ``/Users/x/Documents/GitHub/repo`` ->
``-Users-x-Documents-GitHub-repo``). The projection deliberately targets the
*main repository* project id (not the worktree's own) so all worktrees feed the
single canonical native memory file -- unless an explicit ``--project-path`` is
given.

Examples::

    python3 scripts/memory/project_memory.py --apply
    python3 scripts/memory/project_memory.py --dry-run --json
    python3 scripts/memory/project_memory.py --project-path /path/to/repo --apply
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

if __package__:
    from .tree_store import TreeStore, compute_project_id, resolve_main_repo_root
else:  # pragma: no cover - script-style import support.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from tree_store import TreeStore, compute_project_id, resolve_main_repo_root

BLOCK_START = "<!-- ralph-green-nodes:start (auto-generated, do not edit) -->"
BLOCK_END = "<!-- ralph-green-nodes:end -->"
# Matches the whole delimited block (including the sentinels), non-greedy so
# only the first block is touched. DOTALL so the body can span newlines.
_BLOCK_RE = re.compile(
    re.escape(BLOCK_START) + r".*?" + re.escape(BLOCK_END),
    re.DOTALL,
)
DEFAULT_TOP_N = 10
DEFAULT_CLAUDE_HOME = Path("~/.claude")


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


# ---------------------------------------------------------------------------
# Native Claude project id derivation.
# ---------------------------------------------------------------------------

def native_project_id(project_path: Path) -> str:
    """Claude native project id for *project_path*.

    Claude Code names each project directory by its absolute path with every
    ``/`` and ``.`` replaced by ``-``. This reproduces that mapping so the
    projection writes to the same ``MEMORY.md`` Claude itself reads.
    """
    resolved = str(project_path.expanduser().resolve())
    return resolved.replace("/", "-").replace(".", "-")


def resolve_main_repo(project_path: Path | None) -> Path:
    """Return the main repo root (worktree-aware) or *project_path* verbatim.

    Worktree unwrapping is delegated to ``tree_store.resolve_main_repo_root``,
    the single source of truth shared with the tree id derivation, so the
    projection always targets the SAME canonical project as the stored nodes.
    """
    here = project_path if project_path is not None else Path.cwd()
    return resolve_main_repo_root(here.expanduser())


def memory_md_path(claude_home: Path, native_id: str) -> Path:
    return claude_home.expanduser() / "projects" / native_id / "memory" / "MEMORY.md"


# ---------------------------------------------------------------------------
# GREEN node selection + rendering.
# ---------------------------------------------------------------------------

def _as_dict(value: object) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _confidence(node: dict[str, Any]) -> float:
    quality = _as_dict(node.get("quality"))
    value = quality.get("confidence")
    try:
        return float(value) if value is not None else 0.0
    except (TypeError, ValueError):
        return 0.0


def _salience(node: dict[str, Any]) -> float:
    salience = _as_dict(node.get("salience"))
    return sum(float(v) for v in salience.values() if isinstance(v, (int, float)))


def green_node_score(node: dict[str, Any]) -> float:
    """Ranking score for a GREEN node: confidence + salience nudge.

    Confidence is the primary signal (0..1). Salience adds a small, bounded
    nudge so frequently-reinforced nodes float to the top without dominating.
    """
    return round(_confidence(node) + min(_salience(node), 1.0) * 0.5, 4)


def select_green_nodes(
    store: TreeStore, project_id: str, top_n: int
) -> list[dict[str, Any]]:
    """Return up to *top_n* GREEN, non-deprecated nodes, ranked by score.

    Only ``sensitivity == "GREEN"`` nodes are projected (YELLOW/RED never reach
    native memory). ``list_nodes`` already excludes raw bodies and corrupt
    files, so this can never leak raw content.
    """
    candidates: list[tuple[float, str, dict[str, Any]]] = []
    for entry in store.list_nodes(project_id):
        # list_nodes entries omit raw bodies and sensitivity; load the full
        # node to read sensitivity/quality (still no raw content is exposed).
        full = store.load_node(project_id, str(entry.get("node_id", "")))
        if full is None:
            continue
        if full.get("sensitivity") != "GREEN":
            continue
        quality = _as_dict(full.get("quality"))
        if quality.get("deprecated") is True:
            continue
        if str(quality.get("status", "")).lower() == "deprecated":
            continue
        score = green_node_score(full)
        candidates.append((score, str(full.get("node_id", "")), full))
    candidates.sort(key=lambda item: (-item[0], item[1]))
    return [node for _score, _nid, node in candidates[: max(0, top_n)]]


def _escape_inline(text: str) -> str:
    """Collapse whitespace for a single markdown table/list cell."""
    return re.sub(r"\s+", " ", text).strip()


def render_block(nodes: list[dict[str, Any]], project_id: str) -> str:
    """Render the delimited GREEN-nodes block (sentinels included).

    The body is fully derived from *nodes* so the output is deterministic for
    a given input (idempotent re-runs produce identical text).
    """
    lines: list[str] = [
        BLOCK_START,
        "",
        "## Ralph GREEN Memory Nodes (read-only projection)",
        "",
        f"Source: Ralph memory tree (`project_id={project_id}`). "
        "Regenerated by `scripts/memory/project_memory.py`. Do not edit by hand.",
        "",
    ]
    if not nodes:
        lines.append("_No GREEN nodes available yet._")
    else:
        lines.append("| Node | Domain | Confidence | Summary |")
        lines.append("|------|--------|-----------|---------|")
        for node in nodes:
            node_id = _escape_inline(str(node.get("node_id", "")))
            domain = _escape_inline(str(node.get("domain", "general")))
            confidence = _confidence(node)
            summary = _escape_inline(str(node.get("summary", "")))
            # Keep cells single-line; markdown tables forbid raw pipes.
            summary = summary.replace("|", "\\|")
            node_id = node_id.replace("|", "\\|")
            domain = domain.replace("|", "\\|")
            lines.append(
                f"| `{node_id}` | {domain} | {confidence:.2f} | {summary} |"
            )
    lines.extend(["", BLOCK_END])
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Block insertion (non-destructive, idempotent).
# ---------------------------------------------------------------------------

def upsert_block(existing: str, block: str) -> str:
    """Insert or replace the delimited block, preserving all other content.

    * If a block already exists, only its span is replaced.
    * If no block exists, the new block is appended after the existing content
      (separated by a blank line), leaving prior content intact.
    * Empty/whitespace-only input yields just the block.
    """
    if _BLOCK_RE.search(existing):
        updated = _BLOCK_RE.sub(lambda _m: block, existing, count=1)
        return updated.rstrip("\n") + "\n"
    head = existing.rstrip("\n")
    if not head.strip():
        return block.rstrip("\n") + "\n"
    return head + "\n\n" + block.rstrip("\n") + "\n"


def _atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_path, path)
    finally:
        try:
            tmp_path.unlink()
        except FileNotFoundError:
            pass


def project_memory(
    *,
    project_path: Path | None,
    ralph_home: Path,
    claude_home: Path,
    top_n: int,
    apply: bool,
) -> dict[str, Any]:
    """Compute (and optionally write) the native MEMORY.md GREEN projection."""
    main_repo = resolve_main_repo(project_path)
    native_id = native_project_id(main_repo)
    tree_project_id = compute_project_id(main_repo)

    store = TreeStore(ralph_home)
    nodes = select_green_nodes(store, tree_project_id, top_n)
    block = render_block(nodes, tree_project_id)

    target = memory_md_path(claude_home, native_id)
    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    new_content = upsert_block(existing, block)
    changed = new_content != existing

    if apply and changed:
        _atomic_write_text(target, new_content)

    return {
        "mode": "apply" if apply else "dry-run",
        "main_repo": str(main_repo),
        "native_project_id": native_id,
        "tree_project_id": tree_project_id,
        "memory_md_path": str(target),
        "green_node_count": len(nodes),
        "green_node_ids": [str(n.get("node_id", "")) for n in nodes],
        "changed": changed,
        "wrote": bool(apply and changed),
        "preserved_existing_bytes": len(existing),
        "generated_at": now_iso(),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Project the top GREEN memory nodes (read-only) into a delimited "
            "block inside Claude's native project MEMORY.md. Dry-run by default."
        )
    )
    parser.add_argument(
        "--project-path",
        default="",
        help="Repo path to project (default: auto-detect the main repo, "
        "unwrapping git worktrees).",
    )
    parser.add_argument(
        "--ralph-home",
        default=os.environ.get("RALPH_HOME", "~/.ralph"),
        help="Ralph runtime home (memory_tree/ lives here).",
    )
    parser.add_argument(
        "--claude-home",
        default=os.environ.get("CLAUDE_HOME", str(DEFAULT_CLAUDE_HOME)),
        help="Claude config home (projects/<id>/memory/MEMORY.md lives here).",
    )
    parser.add_argument("--top-n", type=int, default=DEFAULT_TOP_N)
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "--dry-run",
        action="store_true",
        help="Compute the projection without writing. This is the default.",
    )
    group.add_argument(
        "--apply",
        action="store_true",
        help="Write the projection block into the native MEMORY.md.",
    )
    parser.add_argument("--json", action="store_true", help="Emit the report as JSON.")
    args = parser.parse_args(argv)

    project_path = Path(args.project_path).expanduser() if args.project_path else None
    report = project_memory(
        project_path=project_path,
        ralph_home=Path(args.ralph_home).expanduser(),
        claude_home=Path(args.claude_home).expanduser(),
        top_n=max(0, args.top_n),
        apply=bool(args.apply),
    )

    if args.json:
        print(json.dumps(report, ensure_ascii=True, indent=2, sort_keys=True))
    else:
        verb = "WROTE" if report["wrote"] else ("CHANGED" if report["changed"] else "NOOP")
        print(
            f"PROJECT_MEMORY_{report['mode'].upper().replace('-', '_')}_OK "
            f"{verb} nodes={report['green_node_count']} "
            f"target={report['memory_md_path']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
