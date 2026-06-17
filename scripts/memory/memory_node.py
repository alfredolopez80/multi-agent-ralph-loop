"""Ralph MemoryNode v2 -- rigorous frozen schema with structural RED-gate.

Ported and adapted from codex-ralph-vault-loop/scripts/memory/memory_node.py.

Adaptation notes vs. the codex original:
  * RED detection delegates to ``sensitive_content`` (the 8-pattern scanner),
    rather than the codex inline term list, so both modules share one source of
    truth for what "RED material" means.
  * NEW field ``domain`` (the 23rd field) is classified AT NODE CREATION via
    ``infer_domain``. This fixes the historical problem of 1881 rules persisted
    with UNSET domain -- domain is now derived deterministically from summary,
    trigger, and tags at the moment the node is built.

Invariants enforced by ``validate_node``:
  * schema_version == SCHEMA_VERSION
  * sensitivity in {GREEN, YELLOW}        (RED -> error)
  * authority == "non_authoritative"      (literal)
  * provenance: source_paths OR source_description
  * identity: session_id OR commit
  * quality.confidence in [0, 1]
  * node_id matches ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$
  * raw_ref.sha256 (if present) is 64 lowercase hex chars
  * no RED material in any text field
  * negative_rule requires quality.reason + quality.validation_evidence
  * hub requires synthetic=true and raw_ref is None
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any

from sensitive_content import contains_red_material as _scan_red

SCHEMA_VERSION = "ralph_memory_node_v2"
ALLOWED_SENSITIVITY = {"GREEN", "YELLOW"}
REQUIRED_AUTHORITY = "non_authoritative"
VISIBILITY_VALUES = {
    "branch_local",
    "merge_candidate",
    "main_promoted",
    "deprecated_on_merge",
    "conflict",
}
LINK_RELATIONS = {
    "supports",
    "contradicts",
    "updates",
    "supersedes",
    "same_topic",
    "depends_on",
}
SAFE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
SHA256_RE = re.compile(r"[a-f0-9]{64}")

# Closed vocabulary for the domain classifier. "general" is the fallback bucket.
DOMAIN_VALUES = (
    "testing",
    "hooks",
    "security",
    "database",
    "backend",
    "frontend",
    "devops",
    "general",
)


class MemoryNodeError(ValueError):
    pass


class MemoryNodeValidationError(MemoryNodeError):
    pass


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def safe_identifier(value: object, label: str) -> str:
    text = "" if value is None else str(value).strip()
    if not text:
        raise MemoryNodeValidationError(f"{label} is required")
    if text.startswith("/") or "\\" in text or "/" in text or ".." in text:
        raise MemoryNodeValidationError(f"{label} is not a safe path segment")
    if not SAFE_ID_RE.fullmatch(text):
        raise MemoryNodeValidationError(f"{label} contains unsupported characters")
    return text


def contains_red_material(value: object) -> bool:
    """True if *value* (stringified) contains any RED secret material."""
    if value is None:
        return False
    if isinstance(value, (dict, list)):
        return _scan_red(json.dumps(value, ensure_ascii=True, default=str))
    return _scan_red(str(value))


def assert_not_red(value: object, label: str) -> None:
    if contains_red_material(value):
        raise MemoryNodeValidationError(f"{label} contains RED material")


def canonical_json(payload: dict[str, Any]) -> str:
    return json.dumps(payload, ensure_ascii=True, sort_keys=True, separators=(",", ":"))


def deterministic_node_id(payload: dict[str, Any]) -> str:
    material = {
        "project_id": payload.get("project_id", ""),
        "memory_type": payload.get("memory_type", ""),
        "summary": payload.get("summary", ""),
        "source_paths": payload.get("source_paths", []),
        "source_description": payload.get("source_description", ""),
    }
    return "node_" + sha256_text(canonical_json(material))[:32]


# ---------------------------------------------------------------------------
# Domain inference (NEW: improvement over codex). Deterministic keyword scoring.
# ---------------------------------------------------------------------------

# Ordered by specificity. Each domain maps to whole-word/substring signals.
_DOMAIN_KEYWORDS: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "testing",
        (
            "test", "tests", "pytest", "unittest", "assert", "assertion",
            "coverage", "fixture", "mock", "expectation", "tdd", "bats",
            "test case", "regression test",
        ),
    ),
    (
        "hooks",
        (
            "hook", "hooks", "pretooluse", "posttooluse", "userpromptsubmit",
            "subagentstop", "subagentstart", "stop hook", "stdin", "validate-hooks",
            "hook json", "settings.json", "teammateidle", "taskcompleted",
        ),
    ),
    (
        "security",
        (
            "security", "secret", "secrets", "auth", "authentication",
            "authorization", "crypto", "encryption", "bcrypt", "xss",
            "injection", "sql injection", "cwe", "vulnerability", "sanitize",
            "rate limiting", "input validation", "credential", "umask",
            "permission", "redact",
        ),
    ),
    (
        "database",
        (
            "database", "sql", "query", "queries", "index", "indexes",
            "migration", "migrations", "transaction", "rollback", "schema",
            "postgres", "mysql", "mongodb", "explain analyze", "select",
            "foreign key", "savepoint",
        ),
    ),
    (
        "frontend",
        (
            "frontend", "react", "component", "css", "html", "ui",
            "accessibility", "wcag", "aria", "design token", "tailwind",
            "vue", "svelte", "dom", "browser", "responsive", "viewport",
        ),
    ),
    (
        "backend",
        (
            "backend", "api", "endpoint", "async", "await", "server",
            "rest", "graphql", "middleware", "controller", "service",
            "observability", "metrics", "caching", "cache", "rate limit",
            "webhook", "microservice",
        ),
    ),
    (
        "devops",
        (
            "devops", "docker", "kubernetes", "k8s", "ci", "cd", "pipeline",
            "deploy", "deployment", "terraform", "ansible", "helm",
            "github action", "workflow", "container", "minikube", "infra",
            "infrastructure",
        ),
    ),
)


def infer_domain(text: object, tags: object = None) -> str:
    """Classify a memory node into one of ``DOMAIN_VALUES``.

    Deterministic keyword scoring over the combined *text* and *tags*. Tags are
    weighted higher (3x) than free text because they are curated signals. Ties
    resolve toward the more specific domain (earlier in ``_DOMAIN_KEYWORDS``).
    Returns ``"general"`` when no signal is found -- never UNSET.
    """
    body = "" if text is None else str(text)
    tag_list: list[str] = []
    if isinstance(tags, (list, tuple, set)):
        tag_list = [str(t) for t in tags]
    elif tags:
        tag_list = [str(tags)]
    tag_blob = " ".join(tag_list)

    body_lc = body.lower()
    tag_lc = tag_blob.lower()

    scores: dict[str, int] = {}
    for domain, keywords in _DOMAIN_KEYWORDS:
        score = 0
        for kw in keywords:
            # Exact tag match is the strongest signal.
            if kw in {t.lower() for t in tag_list}:
                score += 5
            elif kw in tag_lc:
                score += 3
            if kw in body_lc:
                score += 1
        if score:
            scores[domain] = score

    if not scores:
        return "general"

    # Highest score wins; ties broken by specificity order in _DOMAIN_KEYWORDS.
    order = {d: i for i, (d, _) in enumerate(_DOMAIN_KEYWORDS)}
    best = max(scores.items(), key=lambda kv: (kv[1], -order[kv[0]]))
    return best[0]


# Field groups by declared type, used to normalize an untyped payload dict into
# correctly-typed constructor kwargs (so the frozen schema's str/list/dict
# annotations are honored without `# type: ignore` or forced casts).
_STR_FIELDS: frozenset[str] = frozenset(
    {
        "schema_version",
        "node_id",
        "project_id",
        "workspace_instance_id",
        "repo_remote_hash",
        "branch",
        "commit",
        "session_id",
        "memory_type",
        "sensitivity",
        "authority",
        "summary",
        "domain",
        "created_on_branch",
        "visibility",
        "promotion_status",
        "detailed_summary",
        "source_description",
        "created_at",
        "updated_at",
        "compaction_reason",
    }
)
_LIST_FIELDS: frozenset[str] = frozenset(
    {"topic_tags", "entities", "source_paths", "links"}
)
_DICT_FIELDS: frozenset[str] = frozenset(
    {"promotion_evidence", "trigger", "salience", "quality"}
)


def _normalize_fields(
    cls: type["MemoryNode"], data: dict[str, Any]
) -> dict[str, Any]:
    """Coerce a raw payload into constructor kwargs matching declared field types.

    Each declared field is normalized to its annotated type so the frozen
    dataclass is constructed with concrete ``str``/``list``/``dict`` values
    instead of ``Any | None``:

      * ``str`` fields  -> ``str(value)``; ``None`` becomes ``""`` (the same
        empty string ``validate_node`` already treats as "missing", preserving
        the existing required-field failure paths).
      * ``list`` fields -> the value if non-None, else ``[]``. A non-list value
        is passed through unchanged so ``validate_node`` still rejects it.
      * ``dict`` fields -> the value if non-None, else ``{}``. A non-dict value
        is passed through unchanged so ``validate_node`` still rejects it.
      * ``raw_ref``     -> passed through unchanged (``dict`` or ``None``);
        ``_validate_raw_ref`` enforces its shape.

    Semantic validation (required-ness, vocabularies, malformed types, RED-gate)
    remains the job of ``validate_node``; this only fixes the static types at
    the boundary without altering any runtime acceptance/rejection behavior.
    """
    kwargs: dict[str, Any] = {}
    for name in cls.__dataclass_fields__:
        value = data.get(name)
        if name in _STR_FIELDS:
            kwargs[name] = "" if value is None else str(value)
        elif name in _LIST_FIELDS:
            kwargs[name] = [] if value is None else value
        elif name in _DICT_FIELDS:
            kwargs[name] = {} if value is None else value
        else:
            # raw_ref: dict | None — pass through; validated downstream.
            kwargs[name] = value
    return kwargs


@dataclass(frozen=True)
class MemoryNode:
    # --- required core (no defaults) ---
    schema_version: str
    node_id: str
    project_id: str
    workspace_instance_id: str
    repo_remote_hash: str
    branch: str
    commit: str
    session_id: str
    memory_type: str
    sensitivity: str
    authority: str
    summary: str
    # --- optional with defaults ---
    domain: str = "general"  # NEW: classified at creation, fixes UNSET problem
    created_on_branch: str = ""
    visibility: str = "branch_local"
    promotion_status: str = "not_promoted"
    promotion_evidence: dict[str, Any] = field(default_factory=dict)
    detailed_summary: str = ""
    trigger: dict[str, Any] = field(default_factory=dict)
    topic_tags: list[str] = field(default_factory=list)
    entities: list[str] = field(default_factory=list)
    source_paths: list[str] = field(default_factory=list)
    source_description: str = ""
    raw_ref: dict[str, Any] | None = None
    links: list[dict[str, Any]] = field(default_factory=list)
    salience: dict[str, Any] = field(default_factory=dict)
    quality: dict[str, Any] = field(default_factory=dict)
    created_at: str = ""
    updated_at: str = ""
    compaction_reason: str = ""

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "MemoryNode":
        data = dict(payload)
        data.setdefault("schema_version", SCHEMA_VERSION)
        data.setdefault("node_id", deterministic_node_id(data))
        data.setdefault("created_on_branch", data.get("branch", ""))
        data.setdefault("visibility", "branch_local")
        data.setdefault("promotion_status", "not_promoted")
        data.setdefault("promotion_evidence", {})
        data.setdefault("detailed_summary", "")
        data.setdefault("trigger", {})
        data.setdefault("topic_tags", [])
        data.setdefault("entities", [])
        data.setdefault("source_paths", [])
        data.setdefault("source_description", "")
        data.setdefault("raw_ref", None)
        data.setdefault("links", [])
        data.setdefault("salience", {})
        data.setdefault("quality", {})
        stamp = now_iso()
        data.setdefault("created_at", stamp)
        data.setdefault("updated_at", data.get("created_at") or stamp)
        data.setdefault("compaction_reason", "")
        # NEW: infer domain at creation if not provided or invalid.
        if data.get("domain") not in DOMAIN_VALUES:
            signal = " ".join(
                str(data.get(k, ""))
                for k in ("summary", "detailed_summary", "source_description")
            )
            trig = data.get("trigger")
            if isinstance(trig, dict):
                signal += " " + " ".join(str(v) for v in trig.values())
            elif trig:
                signal += " " + str(trig)
            data["domain"] = infer_domain(signal, data.get("topic_tags"))
        return validate_node(cls(**_normalize_fields(cls, data)))

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _confidence(node: MemoryNode) -> float:
    value = node.quality.get("confidence") if isinstance(node.quality, dict) else None
    if value is None:
        raise MemoryNodeValidationError("quality.confidence is required")
    try:
        confidence = float(value)
    except (TypeError, ValueError) as exc:
        raise MemoryNodeValidationError("quality.confidence must be numeric") from exc
    if not 0.0 <= confidence <= 1.0:
        raise MemoryNodeValidationError("quality.confidence must be between 0 and 1")
    return confidence


def _validate_raw_ref(raw_ref: object) -> None:
    if raw_ref is None:
        return
    if not isinstance(raw_ref, dict):
        raise MemoryNodeValidationError("raw_ref must be an object or null")
    if raw_ref.get("unsafe") is True or raw_ref.get("safe") is False:
        raise MemoryNodeValidationError("raw_ref is marked unsafe")
    digest = raw_ref.get("sha256")
    if digest is not None and not SHA256_RE.fullmatch(str(digest)):
        raise MemoryNodeValidationError("raw_ref.sha256 must be a sha256 hex digest")


def _validate_string_list(value: object, label: str) -> list[str]:
    if not isinstance(value, list):
        raise MemoryNodeValidationError(f"{label} must be a list")
    output: list[str] = []
    for item in value:
        text = str(item).strip()
        if text:
            assert_not_red(text, label)
            output.append(text)
    return output


def _validate_links(value: object) -> None:
    if not isinstance(value, list):
        raise MemoryNodeValidationError("links must be a list")
    for item in value:
        if not isinstance(item, dict):
            raise MemoryNodeValidationError("links entries must be objects")
        relation = str(item.get("relation", "")).strip()
        if relation and relation not in LINK_RELATIONS:
            raise MemoryNodeValidationError("links relation is invalid")
        target = item.get("target_node_id", item.get("node_id"))
        if target:
            safe_identifier(target, "links.node_id")
        assert_not_red(item, "links")


def validate_node(node: MemoryNode) -> MemoryNode:
    if node.schema_version != SCHEMA_VERSION:
        raise MemoryNodeValidationError(f"schema_version must be {SCHEMA_VERSION}")
    safe_identifier(node.node_id, "node_id")
    safe_identifier(node.project_id, "project_id")
    if node.domain not in DOMAIN_VALUES:
        raise MemoryNodeValidationError(f"domain must be one of {sorted(DOMAIN_VALUES)}")
    if not str(node.branch or "").strip():
        raise MemoryNodeValidationError("branch is required")
    if not str(node.created_on_branch or "").strip():
        raise MemoryNodeValidationError("created_on_branch is required")
    if node.visibility not in VISIBILITY_VALUES:
        raise MemoryNodeValidationError("visibility is invalid")
    if not isinstance(node.promotion_evidence, dict):
        raise MemoryNodeValidationError("promotion_evidence must be an object")
    if not str(node.session_id or "").strip() and not str(node.commit or "").strip():
        raise MemoryNodeValidationError("session_id or commit is required")
    if not node.source_paths and not str(node.source_description or "").strip():
        raise MemoryNodeValidationError("source_paths or source_description is required")
    if node.sensitivity not in ALLOWED_SENSITIVITY:
        raise MemoryNodeValidationError("sensitivity must be GREEN or YELLOW")
    if node.authority != REQUIRED_AUTHORITY:
        raise MemoryNodeValidationError("authority must be non_authoritative")
    if not str(node.summary or "").strip():
        raise MemoryNodeValidationError("summary is required")
    if not isinstance(node.trigger, dict):
        raise MemoryNodeValidationError("trigger must be an object")
    if not isinstance(node.salience, dict):
        raise MemoryNodeValidationError("salience must be an object")
    if not isinstance(node.quality, dict):
        raise MemoryNodeValidationError("quality must be an object")
    if node.memory_type == "negative_rule" and (
        not node.quality.get("reason") or not node.quality.get("validation_evidence")
    ):
        raise MemoryNodeValidationError(
            "negative_rule requires reason and validation_evidence"
        )
    if node.memory_type == "hub" and (
        node.raw_ref is not None or node.quality.get("synthetic") is not True
    ):
        raise MemoryNodeValidationError("hub nodes must be synthetic and raw-free")
    _confidence(node)
    _validate_raw_ref(node.raw_ref)
    _validate_links(node.links)
    _validate_string_list(node.source_paths, "source_paths")
    for label, value in (
        ("summary", node.summary),
        ("detailed_summary", node.detailed_summary),
        ("created_on_branch", node.created_on_branch),
        ("visibility", node.visibility),
        ("promotion_status", node.promotion_status),
        ("promotion_evidence", node.promotion_evidence),
        ("source_description", node.source_description),
        ("trigger", node.trigger),
        ("topic_tags", node.topic_tags),
        ("entities", node.entities),
        ("compaction_reason", node.compaction_reason),
    ):
        assert_not_red(value, label)
    return node
