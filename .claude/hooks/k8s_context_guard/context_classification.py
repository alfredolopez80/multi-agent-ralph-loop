"""Dev/prod classification for non-minikube contexts.

Sources, in precedence order (deny > ask):
  1. obvious-prod pattern OR AGENTS.md `prod:` list (exact match) -> "prod"  (deny)
  2. AGENTS.md `dev:` list (exact match)                          -> "dev"   (ask)
  3. low-confidence memory clarification                          -> "memory"(ask)
  4. otherwise                                                    -> "unknown" (deny, fail-closed)

Matching against the declared lists is EXACT (full-string). Never substring/prefix:
`gke_..._clerum` (prod) must not be captured by `gke_..._clerum-dev` (dev) or vice-versa.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

_BEGIN = "<!-- k8s-guard:begin -->"
_END = "<!-- k8s-guard:end -->"

# Conservative "obvious prod" signals. Does NOT match this org's `gke_..._clerum`
# (prod) or `gke_..._clerum-dev` (dev) — those carry no `prod` token, so both fall
# through to the declared lists / fail-closed. Only names carrying an explicit
# prod marker (or an AWS ARN) are treated as unconditional prod.
_OBVIOUS_PROD = re.compile(r"(?i)(^arn:aws:|(^|[-_:])prod(uction)?([-_:]|$))")

_MEMORY_PATH = Path.home() / ".ralph" / "k8s-context-memory.json"


def is_obvious_prod(context: str) -> bool:
    return bool(context) and bool(_OBVIOUS_PROD.search(context))


def load_context_lists(cwd: Path) -> tuple[set[str], set[str]]:
    """Parse the `k8s-guard` block from the cwd's AGENTS.md.

    Returns (dev, prod) as sets of EXACT context names. A missing or malformed
    block yields empty sets, which upstream treats as fail-closed (only
    verified-minikube passes; every declared-remote path denies).

    SECURITY (trust boundary): AGENTS.md is a repo-local file writable by the same agent
    this guard restrains. A compromised/prompt-injected turn could add a context under
    `dev:` to turn its OWN destructive command from deny into ASK — but never into allow
    (classify() has no allow-mapping), and obvious-prod / declared-prod are checked BEFORE
    dev, so a prod context can never be downgraded. The ask prompt is the backstop; treat
    AGENTS.md edits in a PR as security-relevant review surface.
    """
    agents = cwd / "AGENTS.md"
    try:
        text = agents.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return (set(), set())

    start = text.find(_BEGIN)
    end = text.find(_END)
    if start == -1 or end == -1 or end < start:
        return (set(), set())

    block = text[start + len(_BEGIN) : end]
    dev: set[str] = set()
    prod: set[str] = set()
    current: set[str] | None = None
    for raw in block.splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        # Check list ITEM before section KEY: an item whose text happens to end in ':'
        # (a plausible typo) must not be mistaken for a section header — that would reset
        # the current section and silently drop every following item in it.
        if stripped.startswith("-"):
            if current is not None:
                item = stripped[1:].strip().strip('"').strip("'")
                if item:
                    current.add(item)
            continue
        if stripped.endswith(":"):
            key = stripped[:-1].strip().lower()
            current = dev if key == "dev" else prod if key == "prod" else None
    return (dev, prod)


def memory_clarification(context: str) -> dict | None:
    """Return the stored clarification dict for `context`, or None.

    The memory store is a LOW-CONFIDENCE, third-tier source (it can go stale), so
    any hit must lead to `ask` — never an automatic allow/deny. The stored value is
    only used to enrich the confirmation message, not to decide.
    """
    if not context:
        return None
    try:
        data = json.loads(_MEMORY_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None
    contexts = data.get("contexts") if isinstance(data, dict) else None
    if isinstance(contexts, dict):
        entry = contexts.get(context)
        return entry if isinstance(entry, dict) else None
    return None


def classify(context: str, cwd: Path) -> str:
    """Classify a non-minikube context for a mutating/destructive command.

    Precedence enforces the invariant `deny > ask`: obvious-prod / declared-prod is
    evaluated BEFORE declared-dev so a mis-declaration in `dev:` can never degrade a
    prod context to `ask`. Memory only elevates an otherwise-`unknown` (deny) to
    `ask`; it never produces `allow` and never overrides prod.
    """
    dev, prod = load_context_lists(cwd)
    if is_obvious_prod(context) or context in prod:
        return "prod"
    if context in dev:
        return "dev"
    if memory_clarification(context) is not None:
        return "memory"
    return "unknown"
