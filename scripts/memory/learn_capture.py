#!/usr/bin/env python3
"""Ralph learning capture -- turn a validated session lesson into a MemoryNode v2.

Phase B3 wiring: the ``continuous-learning.sh`` Stop hook invokes this module to
persist *validated* learnings as typed memory nodes (via ``tree_store``) instead
of (or in addition to) writing a free-form lesson ``.md``.

The validation logic (keyword + section-header detection, RED-gate, validated-line
extraction) is ported from
``codex-ralph-vault-loop/.codex/hooks/shared/learning.py``. The codex original
imported ``redaction.safe_preview`` and ``context_budget.text_is_toxic`` from its
own hook package; those modules do not exist in the ralph repo, so the minimal
behavior we depend on (RED redaction preview + a toxicity guard built on the
8-pattern RED scanner) is reimplemented here on top of the ralph
``sensitive_content`` module -- one source of truth for "what is RED".

Pipeline (``capture``):
    1. ``extract_validated_learning(text)`` -> None if no validated lesson.
    2. RED-gate: reject if the extracted text contains secret material.
    3. Build a MemoryNode v2 payload (sensitivity=YELLOW by default, domain
       inferred at creation, provenance from session/branch/source).
    4. Persist via ``TreeStore.create_node`` (idempotent: an already-existing
       deterministic node_id is treated as success, not an error).

CLI / stdin contract (used by the bash hook):
    Reads a JSON object from stdin (or ``--text``) with optional fields:
        {"text": "...", "branch": "...", "session_id": "...",
         "project_id": "...", "project_root": "...", "source_description": "...",
         "source_paths": [...], "commit": "...", "ralph_home": "..."}
    Prints a JSON result object to stdout and exits 0 on a clean run (whether or
    not a node was created); exits non-zero only on an unexpected internal error.
    Result: {"status": "...", "node_id": "...|null", "reason": "...|null"}
        status in {"created", "exists", "skipped", "rejected_red", "error"}.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any, Iterable

if __package__:
    from .sensitive_content import is_red, redact_text
    from .tree_store import (
        TreeStore,
        TreeStoreError,
        compute_project_id,
        default_ralph_home,
        workspace_instance_id,
    )
    from .memory_node import MemoryNode, MemoryNodeValidationError, deterministic_node_id
else:  # pragma: no cover - script-style import support.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from sensitive_content import is_red, redact_text
    from tree_store import (
        TreeStore,
        TreeStoreError,
        compute_project_id,
        default_ralph_home,
        workspace_instance_id,
    )
    from memory_node import MemoryNode, MemoryNodeValidationError, deterministic_node_id


# ---------------------------------------------------------------------------
# Learning detection (ported from codex learning.py).
# ---------------------------------------------------------------------------

LEARNING_KEYWORDS: tuple[str, ...] = (
    "learned",
    "aprendido",
    "aprendizaje",
    "decision",
    "fixed",
    "corregido",
    "root cause",
    "causa raiz",
    "checkpoint",
    "validated",
    "validado",
    "pass",
    "passed",
    "paso",
    "failed",
    "fallo",
    "blocker",
    "bloqueador",
    "resultado",
    "conclusion",
)

SECTION_HEADERS: tuple[str, ...] = (
    "conclusion",
    "root cause",
    "causa raiz",
    "decision",
    "fact",
    "validated fact",
    "result",
    "resultado",
    "validation",
    "validacion",
)


def normalize_learning_text(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text)
    ascii_text = normalized.encode("ascii", "ignore").decode("ascii")
    return ascii_text.lower()


def _keyword_pattern(keyword: str) -> "re.Pattern[str]":
    escaped = re.escape(keyword)
    escaped = escaped.replace(r"\ ", r"\s+")
    return re.compile(rf"(?<![a-z0-9_]){escaped}(?![a-z0-9_])")


def _section_pattern(headers: Iterable[str]) -> "re.Pattern[str]":
    body = "|".join(re.escape(header).replace(r"\ ", r"\s+") for header in headers)
    return re.compile(rf"(?im)^\s*(?:{body})\s*:")


KEYWORD_PATTERNS: tuple["re.Pattern[str]", ...] = tuple(
    _keyword_pattern(keyword) for keyword in LEARNING_KEYWORDS
)
SECTION_PATTERN: "re.Pattern[str]" = _section_pattern(SECTION_HEADERS)


def should_persist_learning(text: str) -> bool:
    """True when *text* names a learning signal (keyword or section header)."""
    if not text.strip():
        return False
    normalized = normalize_learning_text(text)
    if SECTION_PATTERN.search(normalized):
        return True
    return any(pattern.search(normalized) for pattern in KEYWORD_PATTERNS)


# ---------------------------------------------------------------------------
# Toxicity / preview guard (reimplemented on the ralph RED scanner, since the
# codex redaction/context_budget modules are not present in this repo).
# ---------------------------------------------------------------------------

_DATA_IMAGE_RE = re.compile(r"data:image/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=]{64,}")
_BASE64_RE = re.compile(r"[A-Za-z0-9+/]{512,}={0,2}")
_LONG_LINE_LIMIT = 2_000


def safe_preview(value: object, limit: int = 1_000) -> str:
    """Redact RED material, then truncate to *limit* characters."""
    text, _ = redact_text(str(value))
    if len(text) > limit:
        return text[:limit].rstrip() + "...[truncated]"
    return text


def toxic_text_reasons(text: str, *, line_limit: int = _LONG_LINE_LIMIT) -> list[str]:
    """Reasons *text* is unsafe to persist (oversized payloads, RED material)."""
    reasons: list[str] = []
    if not text:
        return reasons
    if _DATA_IMAGE_RE.search(text):
        reasons.append("inline data image base64")
    elif _BASE64_RE.search(text):
        reasons.append("very long base64-like payload")
    for line in text.splitlines() or [text]:
        if len(line) > line_limit:
            reasons.append("single line exceeds safe transcript length")
            break
    if is_red(text):
        reasons.append("red-sensitive content")
    return reasons


def text_is_toxic(text: str) -> bool:
    return bool(toxic_text_reasons(text))


def extract_validated_learning(text: str) -> str | None:
    """Return the validated-lesson lines from *text*, or None if none qualify.

    Mirrors the codex algorithm: a RED/toxic input yields None; a single-line
    input that already names a learning signal is returned whole; a multi-line
    input keeps only section-header lines and lines that pair a "validated"
    marker with a "decision/fact/conclusion" marker.
    """
    if not text.strip() or is_red(text) or text_is_toxic(text):
        return None
    preview = safe_preview(text, limit=2_000).strip()
    if not should_persist_learning(preview):
        return None

    lines = [line.strip() for line in preview.splitlines() if line.strip()]
    if len(lines) <= 1:
        return preview

    validated: list[str] = []
    for line in lines:
        normalized = normalize_learning_text(line)
        if SECTION_PATTERN.search(normalized):
            validated.append(line)
        elif any(
            marker in normalized for marker in ("validated", "validado", "pass", "passed", "paso")
        ) and any(
            marker in normalized
            for marker in ("decision", "fact", "root cause", "causa raiz", "conclusion", "resultado")
        ):
            validated.append(line)
    if not validated:
        return None
    return "\n".join(validated)


# ---------------------------------------------------------------------------
# Node construction + persistence.
# ---------------------------------------------------------------------------

def _summary_and_detail(learning: str) -> tuple[str, str]:
    """Derive a one-line summary and a (possibly multi-line) detail body."""
    collapsed = re.sub(r"\s+", " ", learning).strip()
    first_line = next((ln.strip() for ln in learning.splitlines() if ln.strip()), collapsed)
    summary = first_line if len(first_line) <= 280 else first_line[:277].rstrip() + "..."
    detail = learning.strip() if learning.strip() != summary else ""
    return summary, detail


def build_payload(
    learning: str,
    *,
    project_id: str,
    branch: str,
    session_id: str = "",
    commit: str = "",
    source_description: str = "",
    source_paths: list[str] | None = None,
    workspace_id: str = "",
    repo_hash: str = "",
) -> dict[str, Any]:
    """Assemble a MemoryNode v2 payload for a validated learning (YELLOW)."""
    summary, detail = _summary_and_detail(learning)
    paths = list(source_paths or [])
    description = source_description or ("continuous-learning Stop hook" if not paths else "")
    payload: dict[str, Any] = {
        "project_id": project_id,
        "workspace_instance_id": workspace_id,
        "repo_remote_hash": repo_hash,
        "branch": branch or "unknown",
        "commit": commit,
        "session_id": session_id,
        "memory_type": "session_learning",
        "sensitivity": "YELLOW",
        "authority": "non_authoritative",
        "summary": summary,
        "detailed_summary": detail,
        "trigger": {"text": summary},
        "topic_tags": ["session-learning", "continuous-learning"],
        "source_paths": paths,
        "source_description": description,
        "quality": {"confidence": 0.5, "needs_review": True},
    }
    return payload


def capture(
    text: str,
    *,
    project_id: str = "",
    project_root: str = ".",
    branch: str = "",
    session_id: str = "",
    commit: str = "",
    source_description: str = "",
    source_paths: list[str] | None = None,
    ralph_home: Path | None = None,
) -> dict[str, Any]:
    """Validate, RED-gate, and persist *text* as a MemoryNode v2.

    Returns a result dict (never raises for the expected outcomes):
        status in {"created", "exists", "skipped", "rejected_red", "error"}.
    Idempotent: persisting the same validated learning twice reports "exists".
    """
    if not text or not text.strip():
        return {"status": "skipped", "node_id": None, "reason": "empty_text"}

    if is_red(text):
        return {"status": "rejected_red", "node_id": None, "reason": "red_material"}

    learning = extract_validated_learning(text)
    if learning is None:
        return {"status": "skipped", "node_id": None, "reason": "no_validated_learning"}

    # Defense in depth: the extracted lesson must itself be RED-free.
    if is_red(learning):
        return {"status": "rejected_red", "node_id": None, "reason": "red_material"}

    root = Path(project_root).expanduser().resolve()
    resolved_project_id = project_id or compute_project_id(root)
    resolved_workspace = workspace_instance_id(root)
    try:
        from tree_store import repo_remote_hash as _repo_remote_hash  # local import
    except ImportError:  # pragma: no cover - package-mode fallback
        from .tree_store import repo_remote_hash as _repo_remote_hash
    resolved_repo_hash = _repo_remote_hash(root)

    payload = build_payload(
        learning,
        project_id=resolved_project_id,
        branch=branch,
        session_id=session_id,
        commit=commit,
        source_description=source_description,
        source_paths=source_paths,
        workspace_id=resolved_workspace,
        repo_hash=resolved_repo_hash,
    )

    store = TreeStore(ralph_home or default_ralph_home())
    try:
        node_id = deterministic_node_id({**payload, "node_id": ""})
        if store.node_exists(resolved_project_id, node_id):
            return {"status": "exists", "node_id": node_id, "reason": None}
        written = store.create_node(payload)
        return {"status": "created", "node_id": written["node_id"], "reason": None}
    except TreeStoreError as exc:
        # Likely a concurrent create of the same deterministic id -> idempotent.
        if "already exists" in str(exc):
            return {"status": "exists", "node_id": None, "reason": "already_exists"}
        return {"status": "error", "node_id": None, "reason": str(exc)}
    except MemoryNodeValidationError as exc:
        return {"status": "error", "node_id": None, "reason": str(exc)}


# ---------------------------------------------------------------------------
# CLI.
# ---------------------------------------------------------------------------

def _load_request(args: argparse.Namespace) -> dict[str, Any]:
    """Build the capture request from --text or a JSON stdin payload."""
    if args.text:
        return {"text": args.text}
    raw = sys.stdin.read(200_000)
    if not raw.strip():
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        # Treat non-JSON stdin as the raw lesson text itself.
        return {"text": raw}
    return data if isinstance(data, dict) else {}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Capture a validated session learning into the Ralph memory tree."
    )
    parser.add_argument("--text", default="")
    parser.add_argument("--project-root", default=".")
    parser.add_argument("--project-id", default="")
    parser.add_argument("--branch", default="")
    parser.add_argument("--session-id", default="")
    parser.add_argument("--commit", default="")
    parser.add_argument("--source-description", default="")
    parser.add_argument("--ralph-home", default="")
    args = parser.parse_args(argv)

    request = _load_request(args)
    text = str(request.get("text", "") or "")
    source_paths_raw = request.get("source_paths")
    source_paths = (
        [str(p) for p in source_paths_raw] if isinstance(source_paths_raw, list) else None
    )
    ralph_home_value = args.ralph_home or str(request.get("ralph_home", "") or "")
    ralph_home = Path(ralph_home_value).expanduser() if ralph_home_value else None

    try:
        result = capture(
            text,
            project_id=args.project_id or str(request.get("project_id", "") or ""),
            project_root=args.project_root
            if args.project_root != "."
            else str(request.get("project_root", ".") or "."),
            branch=args.branch or str(request.get("branch", "") or ""),
            session_id=args.session_id or str(request.get("session_id", "") or ""),
            commit=args.commit or str(request.get("commit", "") or ""),
            source_description=args.source_description
            or str(request.get("source_description", "") or ""),
            source_paths=source_paths,
            ralph_home=ralph_home,
        )
    except Exception as exc:  # pragma: no cover - last-resort guard for the hook.
        print(json.dumps({"status": "error", "node_id": None, "reason": str(exc)}))
        return 1

    print(json.dumps(result, ensure_ascii=True, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
