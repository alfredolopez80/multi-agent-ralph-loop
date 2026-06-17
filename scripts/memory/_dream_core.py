"""Ralph offline consolidation (dream) core -- builds the absent L3 layer.

Ported and adapted from codex-ralph-vault-loop/scripts/memory/_dream_core.py.

What this does (and how it differs from the codex original):
  * codex consolidated handoffs/ledgers/codex-memories/local-notes into a
    generic "candidates" report and never built a layer. Ralph has L0/L1/L2 but
    NO L3 (consolidations). This module produces L3: a reviewable, deduplicated
    set of consolidated learnings drawn from the project's own learning sources.
  * Sources scanned (Ralph-specific):
        ~/.ralph/handoffs/**/*.md       (session handoffs)
        ~/.ralph/ledgers/*.md           (continuity ledgers)
        ~/Documents/Obsidian/MiVault/projects/{project}/lessons/**/*.md
    RED sources are skipped wholesale via ``sensitive_content.is_red`` -- secret
    material never enters a candidate, never gets scored, never gets written.
  * Layer classification (``target_layer``) and scoring (``score_candidate``)
    follow the B3 spec markers, not codex's MARKERS list.
  * Dedup is by content hash against the existing canonical layer markdown
    (L0/L1/L3) so a consolidation already present in any layer is flagged
    ``duplicate_existing`` and excluded from the emitted L3.

This is library only: no I/O side effects beyond reading sources and the
existing layer files. The CLI (``dream.py``) owns dry-run vs --apply.
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sensitive_content import is_red

# ---------------------------------------------------------------------------
# Default source / layer locations (overridable for tests).
# ---------------------------------------------------------------------------

DEFAULT_RALPH_HOME = Path("~/.ralph").expanduser()
DEFAULT_VAULT_ROOT = Path("~/Documents/Obsidian/MiVault").expanduser()
L3_LAYER_NAME = "L3_dream.md"
CANONICAL_LAYER_NAMES = ("L0_identity.md", "L1_essential.md", L3_LAYER_NAME)

DEFAULT_MAX_ITEMS = 10_000

# ---------------------------------------------------------------------------
# Layer-classification + scoring markers (per B3 spec).
# ---------------------------------------------------------------------------

# A line is a candidate only if it carries one of these learning markers.
MARKERS: tuple[str, ...] = (
    "decision",
    "learned",
    "root cause",
    "validated",
    "fixed",
    "checkpoint",
    "rule",
    "must",
    "should",
    "always",
    "never",
    "migration",
    "index",
)
L1_MARKERS: tuple[str, ...] = ("always", "never", "must", "red", "secret", "security")
L2_MARKERS: tuple[str, ...] = ("repo", "project", "migration", "checkpoint", "tests")
L3_MARKERS: tuple[str, ...] = ("vault", "index", "external")

_STRONG_SCORE_MARKERS: tuple[str, ...] = ("decision", "root cause", "validated")
_LOW_SIGNAL_MARKERS: tuple[str, ...] = ("thing", "stuff", "todo")

# Path filters: never scan a source that looks like it holds secrets.
SKIP_PATH_PARTS: tuple[str, ...] = (".env", "id_rsa", "id_ed25519")
SKIP_PATH_SUBSTRINGS: tuple[str, ...] = (
    "secrets",
    "token",
    "credential",
    "wallet",
    "keystore",
)

_STRIP_PREFIX = re.compile(r"^\s*(?:[-*]\s+|\d+\.\s+|#{1,6}\s+|>\s+|\[[ xX]\]\s+)?")
_PUNCTUATION = re.compile(r"[^a-z0-9]+")
_CHECKBOX = re.compile(r"^\[[ xX]\]\s*")


# ---------------------------------------------------------------------------
# Data classes.
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class SourcePath:
    """A discovered source file plus its human-readable label."""

    path: Path
    label: str


@dataclass(frozen=True)
class SourceItem:
    """A safe (non-RED) source's text, ready for candidate extraction."""

    label: str
    text: str
    classification: str


@dataclass
class Candidate:
    """A consolidation candidate destined for a target layer."""

    target_layer: str
    classification: str
    text: str
    source_paths: list[str] = field(default_factory=list)
    source_groups: list[str] = field(default_factory=list)
    confidence: float = 0.5
    hash: str = ""
    duplicate_existing: bool = False
    duplicate_count: int = 1

    def public_dict(self) -> dict[str, object]:
        return {
            "target_layer": self.target_layer,
            "classification": self.classification,
            "text": self.text,
            "source_paths": self.source_paths,
            "source_groups": self.source_groups,
            "confidence": self.confidence,
            "hash": self.hash,
            "duplicate_existing": self.duplicate_existing,
            "duplicate_count": self.duplicate_count,
        }


# ---------------------------------------------------------------------------
# Small helpers.
# ---------------------------------------------------------------------------

def content_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def normalize_candidate(text: str) -> str:
    """Lowercase + collapse punctuation to a single space for dedup keys."""
    return _PUNCTUATION.sub(" ", text.lower()).strip()


def path_is_sensitive(path: Path) -> bool:
    lowered_parts = [part.lower() for part in path.parts]
    lowered_text = str(path).lower()
    return any(part in lowered_parts for part in SKIP_PATH_PARTS) or any(
        part in lowered_text for part in SKIP_PATH_SUBSTRINGS
    )


def safe_relative(path: Path, root: Path) -> str:
    """Render *path* relative to *root*, falling back to ~ then basename."""
    try:
        return str(path.relative_to(root))
    except ValueError:
        home = Path.home()
        try:
            return "~/" + str(path.relative_to(home))
        except ValueError:
            return path.name


def source_group(label: str) -> str:
    return label.split("/", 1)[0]


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def parse_created_at(text: str) -> datetime | None:
    """Parse a ``created_at`` / ``Timestamp`` / ``Generated`` time from a source.

    Recognizes YAML frontmatter (``created_at:``) and the plain ``Timestamp:`` /
    ``Generated:`` lines that Ralph handoffs and ledgers use. Returns the first
    parseable timezone-aware datetime, or None.
    """
    lines = text.splitlines()
    if text.startswith("---"):
        for line in lines[1:25]:
            if line.strip() == "---":
                break
            if line.startswith("created_at:"):
                return _parse_iso(line.split(":", 1)[1])
    for line in lines[:25]:
        for key in ("Timestamp:", "Generated:", "created_at:"):
            if line.strip().startswith(key):
                parsed = _parse_iso(line.split(key, 1)[1])
                if parsed is not None:
                    return parsed
    return None


def _parse_iso(value: str) -> datetime | None:
    cleaned = value.strip().strip('"').strip("'")
    if not cleaned:
        return None
    try:
        parsed = datetime.fromisoformat(cleaned.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed


def strip_frontmatter(text: str) -> str:
    if not text.startswith("---"):
        return text
    lines = text.splitlines()
    for index, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            return "\n".join(lines[index + 1 :])
    return text


# ---------------------------------------------------------------------------
# Source discovery.
# ---------------------------------------------------------------------------

def _iter_markdown_tree(base: Path, label_root: Path, label_prefix: str) -> list[SourcePath]:
    if not base.exists() or path_is_sensitive(base):
        return []
    sources: list[SourcePath] = []
    for path in sorted(base.rglob("*.md")):
        if path.is_file() and not path_is_sensitive(path):
            sources.append(
                SourcePath(path=path, label=f"{label_prefix}/{safe_relative(path, label_root)}")
            )
    return sources


def _vault_lessons_sources(vault_root: Path, project: str | None) -> list[SourcePath]:
    projects_dir = vault_root / "projects"
    if not projects_dir.exists() or path_is_sensitive(projects_dir):
        return []
    sources: list[SourcePath] = []
    if project:
        lessons = projects_dir / project / "lessons"
        sources.extend(_iter_markdown_tree(lessons, lessons, f"lessons/{project}"))
        return sources
    for project_dir in sorted(p for p in projects_dir.iterdir() if p.is_dir()):
        lessons = project_dir / "lessons"
        sources.extend(_iter_markdown_tree(lessons, lessons, f"lessons/{project_dir.name}"))
    return sources


def source_paths(
    ralph_home: Path,
    vault_root: Path,
    project: str | None,
) -> list[SourcePath]:
    """All learning sources to scan, newest first, de-duplicated by path."""
    paths: list[SourcePath] = []
    for relative in ("handoffs", "ledgers"):
        base = ralph_home / relative
        paths.extend(_iter_markdown_tree(base, base, relative))
    paths.extend(_vault_lessons_sources(vault_root, project))

    unique: dict[str, SourcePath] = {}
    for source in paths:
        try:
            key = str(source.path.resolve())
        except OSError:
            key = str(source.path)
        unique.setdefault(key, source)

    def _mtime(source: SourcePath) -> float:
        try:
            return source.path.stat().st_mtime
        except OSError:
            return 0.0

    return sorted(unique.values(), key=_mtime, reverse=True)


def collect_sources(
    ralph_home: Path,
    since_days: int | None,
    max_items: int,
    vault_root: Path | None = None,
    project: str | None = None,
) -> tuple[list[SourceItem], list[dict[str, object]]]:
    """Read every learning source, filter by age, and SKIP RED material.

    Returns ``(safe_sources, skipped)`` where ``skipped`` records each RED file
    by hash + reason so the report can prove no secret leaked through.
    """
    home = ralph_home.expanduser()
    vault = (vault_root or DEFAULT_VAULT_ROOT).expanduser()
    cutoff = (
        datetime.now(timezone.utc) - timedelta(days=since_days) if since_days else None
    )
    sources: list[SourceItem] = []
    skipped: list[dict[str, object]] = []
    for source_path in source_paths(home, vault, project):
        if len(sources) + len(skipped) >= max_items:
            break
        path = source_path.path
        text = read_text(path)
        if not text.strip():
            continue
        created_at = parse_created_at(text)
        if cutoff and created_at and created_at < cutoff:
            continue
        digest = content_hash(text)
        if is_red(text):
            skipped.append({"hash": digest, "reason": "RED", "label": source_path.label})
            continue
        sources.append(
            SourceItem(label=source_path.label, text=text, classification="GREEN")
        )
    return sources, skipped


# ---------------------------------------------------------------------------
# Candidate extraction.
# ---------------------------------------------------------------------------

def candidate_lines(text: str) -> list[str]:
    """Marker-bearing, table/heading-free lines from a source body."""
    lines: list[str] = []
    for raw_line in strip_frontmatter(text).splitlines():
        line = _CHECKBOX.sub("", _STRIP_PREFIX.sub("", raw_line)).strip()
        if not line or line.startswith("|") or line.startswith("---"):
            continue
        if any(marker in line.lower() for marker in MARKERS):
            lines.append(line)
    return lines


def target_layer(text: str) -> str:
    """Classify a candidate line into L1 / L2 / L3 / report-only.

    L1 markers (always/never/must/red/secret/security) win first because they
    are the highest-criticality always-on signals; then L2 (repo/project/
    migration/checkpoint/tests); then L3 (vault/index/external). No marker ->
    report-only (recorded but never written to a layer).
    """
    lowered = text.lower()
    if any(marker in lowered for marker in L1_MARKERS):
        return "L1"
    if any(marker in lowered for marker in L2_MARKERS):
        return "L2"
    if any(marker in lowered for marker in L3_MARKERS):
        return "L3"
    return "report-only"


def score_candidate(text: str, source_count: int, source_kinds: set[str]) -> float:
    """Score a candidate in [0.0, 0.95].

    base 0.5; +0.1 if seen in >=2 sources; +0.1 if it carries a strong marker
    (decision/root cause/validated); +0.05 if corroborated across both a Ralph
    runtime source (handoffs/ledgers) and the vault (lessons); -0.2 if the line
    is too long (>220 chars) or too short (<5 words) or low-signal.
    """
    lowered = text.lower()
    score = 0.5
    if source_count >= 2:
        score += 0.1
    if any(marker in lowered for marker in _STRONG_SCORE_MARKERS):
        score += 0.1
    runtime_kinds = {"handoffs", "ledgers"}
    if runtime_kinds.intersection(source_kinds) and "lessons" in source_kinds:
        score += 0.05
    if len(text) > 220:
        score -= 0.2
    if len(text.split()) < 5 or any(marker in lowered for marker in _LOW_SIGNAL_MARKERS):
        score -= 0.2
    return round(min(0.95, max(0.0, score)), 2)


def existing_layer_blob(layers_dir: Path) -> str:
    """Concatenated normalized text of the canonical layers, for dedup."""
    blob_parts: list[str] = []
    for name in CANONICAL_LAYER_NAMES:
        path = layers_dir / name
        if path.is_file():
            blob_parts.append(read_text(path))
    return normalize_candidate("\n".join(blob_parts))


def extract_candidates(
    sources: list[SourceItem], layers_dir: Path
) -> tuple[list[Candidate], int]:
    """Group marker lines into deduplicated, scored candidates.

    Identical normalized lines (across sources) collapse into one candidate
    that accumulates source paths/groups. A candidate already present in the
    canonical layer blob is flagged ``duplicate_existing``.
    """
    normalized_layers = existing_layer_blob(layers_dir)
    grouped: dict[str, Candidate] = {}
    for source in sources:
        for line in candidate_lines(source.text):
            normalized = normalize_candidate(line)
            if not normalized:
                continue
            digest = content_hash(normalized)
            candidate = grouped.get(digest)
            if candidate is None:
                candidate = Candidate(
                    target_layer=target_layer(line),
                    classification=source.classification,
                    text=line,
                    hash=digest,
                    duplicate_existing=bool(normalized) and normalized in normalized_layers,
                )
                grouped[digest] = candidate
            if source.label not in candidate.source_paths:
                candidate.source_paths.append(source.label)
            group = source_group(source.label)
            if group not in candidate.source_groups:
                candidate.source_groups.append(group)
            if source.classification == "YELLOW":
                candidate.classification = "YELLOW"

    duplicate_count = _finalize_candidates(list(grouped.values()))
    candidates = sorted(
        grouped.values(),
        key=lambda item: (-item.confidence, item.target_layer, item.text.lower()),
    )
    return candidates, duplicate_count


def _finalize_candidates(candidates: list[Candidate]) -> int:
    duplicate_count = 0
    for candidate in candidates:
        candidate.duplicate_count = len(candidate.source_paths)
        candidate.source_groups = sorted(candidate.source_groups)
        source_kinds = set(candidate.source_groups)
        candidate.confidence = score_candidate(
            candidate.text, candidate.duplicate_count, source_kinds
        )
        if candidate.duplicate_count > 1 or candidate.duplicate_existing:
            duplicate_count += 1
    return duplicate_count


# ---------------------------------------------------------------------------
# Report + L3 rendering.
# ---------------------------------------------------------------------------

def build_report(
    ralph_home: Path,
    since_days: int | None,
    max_items: int,
    created_at: str,
    vault_root: Path | None = None,
    project: str | None = None,
) -> dict[str, object]:
    """Build the full dry-run report: counts, candidates, RED-skip ledger."""
    home = ralph_home.expanduser()
    layers_dir = home / "layers"
    sources, skipped = collect_sources(
        home, since_days, max_items, vault_root=vault_root, project=project
    )
    candidates, duplicate_count = extract_candidates(sources, layers_dir)
    by_layer: dict[str, int] = {}
    for candidate in candidates:
        by_layer[candidate.target_layer] = by_layer.get(candidate.target_layer, 0) + 1
    return {
        "created_at": created_at,
        "mode": "dry-run",
        "classification": "YELLOW",
        "source_count": len(sources) + len(skipped),
        "safe_source_count": len(sources),
        "red_skipped": len(skipped),
        "duplicate_count": duplicate_count,
        "candidate_count": len(candidates),
        "by_target_layer": by_layer,
        "candidates": [candidate.public_dict() for candidate in candidates],
        "skipped": skipped,
    }


def l3_candidates(report: dict[str, object]) -> list[dict[str, object]]:
    """The subset of candidates eligible to be written to L3.

    Eligible = target_layer == "L3", not a duplicate of an existing layer entry,
    and classification is GREEN or YELLOW (RED never reaches here -- already
    filtered at source). Defense-in-depth: re-check ``is_red`` on the text.
    """
    eligible: list[dict[str, object]] = []
    raw_candidates = report.get("candidates", [])
    candidates = raw_candidates if isinstance(raw_candidates, list) else []
    for candidate in candidates:
        if not isinstance(candidate, dict):
            continue
        if candidate.get("target_layer") != "L3":
            continue
        if candidate.get("duplicate_existing"):
            continue
        if candidate.get("classification") not in ("GREEN", "YELLOW"):
            continue
        if is_red(str(candidate.get("text", ""))):
            continue
        eligible.append(candidate)
    return eligible


def render_l3(report: dict[str, object]) -> str:
    """Render the L3 consolidation layer markdown.

    Mirrors the L1 markdown shape (numbered entries, ``_confidence_`` line) so
    the wake-up loader can present L3 alongside L0/L1 without special casing.
    Each entry records confidence + its source_paths for provenance.
    """
    entries = l3_candidates(report)
    created_at = str(report.get("created_at", ""))
    lines = [
        f"# L3 Dream Consolidations ({len(entries)} entries)",
        "",
        f"**Generated**: {created_at}",
        "**Source**: ~/.ralph/handoffs, ~/.ralph/ledgers, vault lessons "
        "(RED-filtered)",
        f"**Safe sources**: {report.get('safe_source_count', 0)} · "
        f"**RED skipped**: {report.get('red_skipped', 0)} · "
        f"**Duplicates excluded**: {report.get('duplicate_count', 0)}",
        "**Classification**: GREEN/YELLOW only (offline consolidation)",
        "",
    ]
    if not entries:
        lines.append("_No L3 consolidations met the threshold this run._")
        lines.append("")
    for index, candidate in enumerate(entries, 1):
        text = str(candidate.get("text", "")).strip()
        confidence = candidate.get("confidence", 0.0)
        classification = str(candidate.get("classification", "GREEN"))
        source_paths_value = candidate.get("source_paths") or []
        source_list = (
            ", ".join(str(p) for p in source_paths_value)
            if isinstance(source_paths_value, list)
            else str(source_paths_value)
        )
        lines.append(f"## {index}. {text}")
        lines.append(
            f"_confidence: {confidence} · class: {classification} · "
            f"sources: {source_list}_"
        )
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"
