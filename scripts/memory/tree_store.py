"""Ralph Memory Tree store -- per-project, worktree-isolated node storage.

Ported and adapted from codex-ralph-vault-loop/scripts/memory/tree_store.py.

Adaptation notes vs. the codex original:
  * Layout follows the Ralph B2 spec exactly:
        ~/.ralph/memory_tree/projects/{project_id}/
            nodes/        one *.json per node
            raw/          *.txt named by sha256 of content
            index.json    node_id -> metadata (no raw bodies)
            usage.jsonl   append-only event log
    (codex nested ``memory_tree`` under each project and carried snapshot /
    links machinery; those are out of B2 scope and were dropped.)
  * ``compute_project_id(repo_root)`` derives the project id from the git
    remote URL hash + the MAIN-REPO directory name. Worktrees are unwrapped to
    their main repository first (Addendum 2, 2026-06-17), so every worktree of
    a repo shares ONE durable memory tree -- knowledge is a property of the
    project, not of an ephemeral branch/worktree. ``resolve_main_repo_root`` is
    the single source of truth for that unwrapping (``project_memory`` imports
    it rather than duplicating the logic). This replaces codex's reliance on a
    shared ``active_context`` module.
  * RED-gate, validation, and node schema are reused from ``memory_node`` and
    ``sensitive_content`` (the B1 modules) -- nothing is redefined here.

Safety invariants:
  * Atomic writes: mkstemp + fsync + os.replace, with a directory fsync.
  * ``safe_segment`` rejects ``/``, ``\\``, ``..``, and empty segments.
  * ``ensure_within`` proves every resolved path stays under the tree root.
  * RED material can never be written to ``raw/`` (save_raw rejects it) and is
    re-checked on read (read_raw returns None for tampered RED content).
  * ``load_node`` returns None for missing/corrupt/invalid files; never raises
    on a bad file.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

# Make sibling modules importable both as a package and as loose scripts.
if __package__:
    from .memory_node import (
        MemoryNode,
        MemoryNodeValidationError,
        contains_red_material,
        sha256_text,
        validate_node,
    )
else:  # pragma: no cover - script-style import support.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from memory_node import (
        MemoryNode,
        MemoryNodeValidationError,
        contains_red_material,
        sha256_text,
        validate_node,
    )

ALLOWED_RAW_SENSITIVITY = {"GREEN", "YELLOW"}
INDEX_SCHEMA_VERSION = "ralph_memory_tree_index_v1"
SHA256_RE = re.compile(r"[a-f0-9]{64}")


class TreeStoreError(ValueError):
    pass


class TreeStorePathError(TreeStoreError):
    pass


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def default_ralph_home() -> Path:
    return Path("~/.ralph").expanduser()


# ---------------------------------------------------------------------------
# Canonical project id derivation (main-repo, worktree-unwrapped).
# ---------------------------------------------------------------------------

def _git_remote_url(repo_root: Path) -> str:
    """Best-effort git remote URL for *repo_root*; '' if none / not a repo."""
    try:
        result = subprocess.run(
            ["git", "-C", str(repo_root), "remote", "get-url", "origin"],
            capture_output=True,
            text=True,
            check=False,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def resolve_main_repo_root(repo_root: Path) -> Path:
    """Return the MAIN repository root for *repo_root*, unwrapping worktrees.

    Single source of truth for "which project does this path belong to". For a
    normal checkout this is ``git rev-parse --show-toplevel``. For a linked
    worktree the top-level ``.git`` is a *file* pointing at
    ``<main>/.git/worktrees/<name>``; the main repo root is three levels up from
    that gitdir. Outside a git repo (or on any git error) the resolved input
    path is returned verbatim as a stable fallback.

    Both ``project_memory`` and the per-project tree id derivation use this so
    every worktree maps to one canonical project (Addendum 2, 2026-06-17).
    """
    start = repo_root.expanduser().resolve()
    try:
        result = subprocess.run(
            ["git", "-C", str(start), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=False,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return start
    if result.returncode != 0:
        return start
    toplevel = Path(result.stdout.strip())
    git_marker = toplevel / ".git"
    if not git_marker.is_file():
        # Normal checkout: .git is a directory, toplevel IS the main repo.
        return toplevel
    try:
        content = git_marker.read_text(encoding="utf-8").strip()
    except OSError:
        return toplevel
    gitdir = content.split("gitdir:", 1)[-1].strip()
    gitdir_path = (
        Path(gitdir) if Path(gitdir).is_absolute() else (toplevel / gitdir).resolve()
    )
    # .git/worktrees/<name> -> up 3 levels to the main repo root.
    if "worktrees" in gitdir_path.parts:
        return gitdir_path.parent.parent.parent
    return toplevel


def repo_remote_hash(repo_root: Path) -> str:
    """Stable 16-char hash of the main repo's remote URL (path as fallback)."""
    main_repo = resolve_main_repo_root(repo_root)
    remote = _git_remote_url(main_repo)
    material = remote or str(main_repo)
    return sha256_text(material)[:16]


def workspace_instance_id(repo_root: Path) -> str:
    """Identity of the PROJECT: the main-repo directory name (worktree-unwrapped).

    Despite the historical name, this is now derived from the MAIN repository
    (not the worktree) so all worktrees of a repo share one canonical id.
    """
    return safe_segment(resolve_main_repo_root(repo_root).name, "workspace_instance_id")


def compute_project_id(repo_root: Path) -> str:
    """Canonical project id: main-repo remote-hash + main-repo dir name.

    Worktrees are unwrapped to their main repository first, so two worktrees of
    the same repo resolve to the SAME project id -- they share one durable
    memory tree (Addendum 2). Distinct repos still get distinct ids via the
    remote-hash and/or directory name.
    """
    main_repo = resolve_main_repo_root(repo_root)
    return safe_segment(
        f"{repo_remote_hash(main_repo)}_{workspace_instance_id(main_repo)}",
        "project_id",
    )


# ---------------------------------------------------------------------------
# Path safety.
# ---------------------------------------------------------------------------

def safe_segment(value: object, label: str) -> str:
    text = "" if value is None else str(value).strip()
    if not text or text.startswith("/") or "\\" in text or "/" in text or ".." in text:
        raise TreeStorePathError(f"{label} is not a safe path segment")
    return text


def ensure_within(base: Path, candidate: Path) -> Path:
    base_resolved = base.resolve(strict=False)
    candidate_resolved = candidate.resolve(strict=False)
    if (
        candidate_resolved != base_resolved
        and base_resolved not in candidate_resolved.parents
    ):
        raise TreeStorePathError(f"path escapes memory tree root: {candidate}")
    return candidate


# ---------------------------------------------------------------------------
# Atomic writes.
# ---------------------------------------------------------------------------

def fsync_dir(path: Path) -> None:
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(fd)
    except OSError:
        pass
    finally:
        os.close(fd)


def atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ensure_within(path.parent, path)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_path, path)
        fsync_dir(path.parent)
    finally:
        try:
            tmp_path.unlink()
        except FileNotFoundError:
            pass


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    atomic_write_text(
        path, json.dumps(payload, ensure_ascii=True, indent=2, sort_keys=True) + "\n"
    )


# ---------------------------------------------------------------------------
# Store.
# ---------------------------------------------------------------------------

class TreeStore:
    """File-backed store for MemoryNode v2, isolated per project_id."""

    def __init__(self, ralph_home: Path | None = None) -> None:
        self.ralph_home = (ralph_home or default_ralph_home()).expanduser()
        # Deferred-index batch state. When > 0 the index is NOT rewritten on
        # every node write (which is O(n) per write -> O(n^2) for a bulk
        # migration); instead dirty projects are tracked and flushed once.
        self._defer_index_depth = 0
        self._dirty_projects: set[str] = set()

    # --- batch index (bulk-write performance) -----------------------------

    @contextmanager
    def deferred_index(self) -> "Iterator[TreeStore]":
        """Batch index writes: skip per-node index rewrites, flush once on exit.

        Node JSON files are still written (and fsynced) immediately, so the
        per-node duplicate check (``node_exists``) stays correct. Only the
        aggregate ``index.json`` rebuild is deferred to the end, turning the
        bulk-migration cost from O(n^2) into O(n). The flush runs even if the
        body raises, so a partial migration still leaves a consistent index.
        """
        self._defer_index_depth += 1
        try:
            yield self
        finally:
            self._defer_index_depth -= 1
            if self._defer_index_depth == 0:
                dirty = sorted(self._dirty_projects)
                self._dirty_projects.clear()
                for project_id in dirty:
                    self._write_index(project_id)

    # --- layout -----------------------------------------------------------

    def projects_root(self) -> Path:
        return self.ralph_home / "memory_tree" / "projects"

    def project_tree(self, project_id: str) -> Path:
        safe_project = safe_segment(project_id, "project_id")
        root = self.projects_root() / safe_project
        return ensure_within(self.projects_root(), root)

    def nodes_dir(self, project_id: str) -> Path:
        return self.project_tree(project_id) / "nodes"

    def raw_dir(self, project_id: str) -> Path:
        return self.project_tree(project_id) / "raw"

    def index_path(self, project_id: str) -> Path:
        return self.project_tree(project_id) / "index.json"

    def usage_path(self, project_id: str) -> Path:
        return self.project_tree(project_id) / "usage.jsonl"

    def node_path(self, project_id: str, node_id: str) -> Path:
        safe_node = safe_segment(node_id, "node_id")
        path = self.nodes_dir(project_id) / f"{safe_node}.json"
        return ensure_within(self.project_tree(project_id), path)

    def raw_path(self, project_id: str, digest: str) -> Path:
        if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
            raise TreeStorePathError("raw digest must be a sha256 hex digest")
        path = self.raw_dir(project_id) / f"{digest}.txt"
        return ensure_within(self.project_tree(project_id), path)

    def ensure_layout(self, project_id: str) -> Path:
        root = self.project_tree(project_id)
        for directory in (root / "nodes", root / "raw"):
            directory.mkdir(parents=True, exist_ok=True)
            ensure_within(root, directory)
        for filename, default in (("usage.jsonl", ""), ("index.json", "{}\n")):
            path = root / filename
            ensure_within(root, path)
            if not path.exists():
                atomic_write_text(path, default)
        return root

    # --- node ops ---------------------------------------------------------

    def create_node(self, payload: dict[str, Any]) -> dict[str, Any]:
        node = MemoryNode.from_dict(payload)
        if self.node_exists(node.project_id, node.node_id):
            raise TreeStoreError(f"node already exists: {node.node_id}")
        return self._write_node(node)

    def update_node(
        self, project_id: str, node_id: str, updates: dict[str, Any]
    ) -> dict[str, Any]:
        current = self.load_node(project_id, node_id)
        if current is None:
            raise TreeStoreError(f"node not found: {node_id}")
        merged: dict[str, Any] = {
            **current,
            **updates,
            "node_id": current["node_id"],
            "project_id": current["project_id"],
            "updated_at": now_iso(),
        }
        node = MemoryNode.from_dict(merged)
        return self._write_node(node)

    def _write_node(self, node: MemoryNode) -> dict[str, Any]:
        node = validate_node(node)
        root = self.ensure_layout(node.project_id)
        path = self.node_path(node.project_id, node.node_id)
        payload = node.to_dict()
        atomic_write_json(path, payload)
        if self._defer_index_depth > 0:
            self._dirty_projects.add(node.project_id)
        else:
            self._write_index(node.project_id)
        self._append_usage(
            root,
            {"event": "node_written", "node_id": node.node_id, "at": now_iso()},
        )
        return payload

    def load_node(self, project_id: str, node_id: str) -> dict[str, Any] | None:
        """Return the node payload, or None if missing / corrupt / invalid.

        Never raises on a bad file: a corrupt JSON body or a node that fails
        schema validation yields None rather than propagating an exception.
        """
        path = self.node_path(project_id, node_id)
        if not path.exists():
            return None
        ensure_within(self.nodes_dir(project_id), path)
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError, ValueError):
            return None
        if not isinstance(payload, dict):
            return None
        try:
            return MemoryNode.from_dict(payload).to_dict()
        except MemoryNodeValidationError:
            return None

    def list_nodes(self, project_id: str) -> list[dict[str, Any]]:
        """Return index-style metadata for every valid node (NO raw bodies).

        Each entry carries only ``raw_ref`` (the sha256 reference), never the
        raw text itself, so listings cannot leak raw content.
        """
        directory = self.nodes_dir(project_id)
        if not directory.exists():
            return []
        nodes: list[dict[str, Any]] = []
        for path in sorted(directory.glob("*.json")):
            if path.name.startswith("."):
                continue
            try:
                ensure_within(directory, path)
            except TreeStorePathError:
                continue
            node = self.load_node(project_id, path.stem)
            if node is not None:
                nodes.append(self._index_entry(node))
        return nodes

    def node_exists(self, project_id: str, node_id: str) -> bool:
        return self.load_node(project_id, node_id) is not None

    # --- raw ops ----------------------------------------------------------

    def save_raw(
        self, project_id: str, content: str, sensitivity: str = "YELLOW"
    ) -> dict[str, str]:
        if sensitivity not in ALLOWED_RAW_SENSITIVITY:
            raise MemoryNodeValidationError("raw sensitivity must be GREEN or YELLOW")
        if contains_red_material(content):
            raise MemoryNodeValidationError("raw content contains RED material")
        self.ensure_layout(project_id)
        digest = sha256_text(content)
        path = self.raw_path(project_id, digest)
        atomic_write_text(path, content)
        return {"sha256": digest, "path": str(path), "sensitivity": sensitivity}

    def read_raw(self, project_id: str, digest: str) -> str | None:
        """Return raw content, or None if missing / unreadable / RED.

        RED is re-checked at read time so on-disk tampering that injects secret
        material is never returned to a caller.
        """
        path = self.raw_path(project_id, digest)
        if not path.exists():
            return None
        try:
            content = path.read_text(encoding="utf-8")
        except OSError:
            return None
        return None if contains_red_material(content) else content

    # --- index / usage ----------------------------------------------------

    @staticmethod
    def _index_entry(node: dict[str, Any]) -> dict[str, Any]:
        raw_ref = node.get("raw_ref") if isinstance(node.get("raw_ref"), dict) else None
        ref = {"sha256": raw_ref.get("sha256")} if raw_ref else None
        return {
            "node_id": node["node_id"],
            "memory_type": node.get("memory_type", ""),
            "domain": node.get("domain", "general"),
            "branch": node.get("branch", ""),
            "created_on_branch": node.get("created_on_branch", node.get("branch", "")),
            "visibility": node.get("visibility", "branch_local"),
            "promotion_status": node.get("promotion_status", "not_promoted"),
            "summary": node.get("summary", ""),
            "trigger": node.get("trigger", {}),
            "topic_tags": node.get("topic_tags", []),
            "entities": node.get("entities", []),
            "source_paths": node.get("source_paths", []),
            "links": node.get("links", []),
            "quality": node.get("quality", {}),
            "raw_ref": ref,
            "updated_at": node.get("updated_at", ""),
            "created_at": node.get("created_at", ""),
        }

    def _write_index(self, project_id: str) -> None:
        root = self.ensure_layout(project_id)
        index = {
            "schema_version": INDEX_SCHEMA_VERSION,
            "project_id": project_id,
            "updated_at": now_iso(),
            "nodes": self.list_nodes(project_id),
        }
        atomic_write_json(root / "index.json", index)

    def _append_usage(self, root: Path, event: dict[str, Any]) -> None:
        path = root / "usage.jsonl"
        line = json.dumps(event, ensure_ascii=True, sort_keys=True) + "\n"
        existing = path.read_text(encoding="utf-8") if path.exists() else ""
        atomic_write_text(path, existing + line)
