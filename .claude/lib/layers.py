#!/usr/bin/env python3
"""
4-Layer Memory Stack for Ralph Multi-Agent System
=================================================

Inspired by mempalace/layers.py (https://github.com/milla-jovovich/mempalace).
Adapted for the Ralph vault-first architecture with Obsidian KG backend.

Layers:
    Layer0  — Identity layer. Manual file at ~/.ralph/layers/L0_identity.md (~100 tokens).
               Loaded at every session start. Static, human-maintained.

    Layer1  — Essential layer. Auto-generated top-25 high-value procedural rules,
               stored as plain markdown at ~/.ralph/layers/L1_essential.md.
               Rebuilt by build() from ~/.ralph/procedural/rules.json.
               Scoring uses confidence × usage, recency bonus (14d decay),
               criticality floor, and domain diversity (max 3 per domain).
               (Original plan used AAAK encoding, but tiktoken cl100k_base
               measurement showed AAAK INCREASES tokens by ~20% — see
               docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md.)

    Layer2  — Project wings. On-demand per-project context stored under
               ~/.ralph/layers/L2_wings/<project_name>/context.md.
               Loaded only when a project is explicitly requested.

    Layer3  — Vault queries. Direct Obsidian vault queries via grep + frontmatter.
               NOTE: claude-mem MCP was removed in Wave 0. All queries use
               ~/Documents/Obsidian/MiVault/ via grep (corrected from original plan).

Wake-up cost target: <1500 tokens for L0+L1 combined.

Usage:
    from layers import Layer0, Layer1, Layer2, Layer3

    # Load identity at session start
    ctx = Layer0().load()

    # Build L1 from procedural rules (call once to refresh)
    Layer1().build()

    # Load L1 essentials
    essentials = Layer1().load()

    # Check if project wing exists
    if Layer2().has("my-project"):
        wing = Layer2().load("my-project")

    # Query vault
    results = Layer3().query("hook json format")
"""

import json
import re
import subprocess
import sys
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Path constants
# ---------------------------------------------------------------------------

LAYERS_DIR = Path.home() / ".ralph" / "layers"
L0_PATH = LAYERS_DIR / "L0_identity.md"
L1_PATH = LAYERS_DIR / "L1_essential.md"
L2_DIR = LAYERS_DIR / "L2_wings"
PROCEDURAL_RULES_JSON = Path.home() / ".ralph" / "procedural" / "rules.json"
VAULT_DIR = Path.home() / "Documents" / "Obsidian" / "MiVault"

# Graduation: proven rules directory (promoted from rules.json to always-on)
PROVEN_RULES_DIR = Path.home() / ".claude" / "rules" / "proven"

# Graduation thresholds — rules must meet ALL criteria
GRADUATE_MIN_CONFIDENCE = 0.9
GRADUATE_MIN_USAGE = 20          # max(usage_count, applied_count)
GRADUATE_MIN_BEHAVIOR_LEN = 50  # chars — reject trivial one-liners

# Number of top rules to include in L1
L1_RULE_COUNT = 25

# Max snippet length returned by Layer3
L3_SNIPPET_MAX = 200


# ---------------------------------------------------------------------------
# Layer 0 — Identity
# ---------------------------------------------------------------------------

class Layer0:
    """
    Identity layer. Manual file at ~/.ralph/layers/L0_identity.md.

    This file is ~100 tokens of minimal identity context: who we are,
    what we do, and the 5 core principles. It is loaded at every session
    start and never auto-generated.
    """

    def __init__(self, path: Optional[Path] = None):
        self.path = path or L0_PATH

    def exists(self) -> bool:
        """Return True if the L0 identity file exists."""
        return self.path.is_file()

    def load(self) -> str:
        """
        Load and return the identity content.

        Returns:
            Contents of L0_identity.md as a string.

        Raises:
            FileNotFoundError: If the identity file does not exist.
        """
        if not self.exists():
            raise FileNotFoundError(
                f"L0 identity file not found at {self.path}. "
                "Create it manually with the system identity content."
            )
        return self.path.read_text(encoding="utf-8")

    def token_estimate(self) -> int:
        """Rough token estimate for L0 content (1 token ~ 4 chars)."""
        if not self.exists():
            return 0
        return max(1, len(self.path.read_text(encoding="utf-8")) // 4)


# ---------------------------------------------------------------------------
# Layer 1 — Essential rules (plain markdown)
# ---------------------------------------------------------------------------

class Layer1:
    """
    Essential layer. Auto-generated from top-25 high-value procedural rules.

    Source: ~/.ralph/procedural/rules.json
    Output: ~/.ralph/layers/L1_essential.md  (plain markdown, not AAAK)

    Rules are scored by: confidence * usage (max of usage_count, applied_count)
    with criticality bonus (1.5x), score floor (50 for critical rules),
    and recency bonus (2.0x linear decay over 14 days).
    Domain diversity caps at 3 rules per domain.
    The top 25 are written as plain markdown.
    See docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md for the
    full analysis of why AAAK was abandoned for L1.
    """

    # Max rules per domain in L1 output (prevents domain saturation)
    _MAX_RULES_PER_DOMAIN = 3

    # Curated sources with lower substantive threshold (trusted sources)
    _CURATED_SOURCES = ("seed-rule", "learned-from-incident", "claude-code-official-docs")

    def __init__(self, path: Optional[Path] = None, rule_count: int = L1_RULE_COUNT):
        self.path = path or L1_PATH
        self.rule_count = rule_count

    def _load_rules_from_json(self) -> list[dict]:
        """Load rules from rules.json."""
        with PROCEDURAL_RULES_JSON.open(encoding="utf-8") as f:
            data = json.load(f)
        rules = data.get("rules", [])
        if not isinstance(rules, list):
            raise ValueError(
                f"Expected 'rules' to be a list in {PROCEDURAL_RULES_JSON}, "
                f"got {type(rules).__name__}"
            )
        return rules

    def _load_source_rules(self) -> list[dict]:
        """Load rules from rules.json."""
        if not PROCEDURAL_RULES_JSON.is_file():
            raise FileNotFoundError(
                f"No procedural rules source found at {PROCEDURAL_RULES_JSON}."
            )
        return self._load_rules_from_json()

    # Rules matching these id prefixes are mechanical auto-extractions
    # from curator-learn.sh regex patterns. They have high usage_count
    # (fire on every file scan) but ZERO actionable leverage at wake-up.
    # Examples: "Implements caching strategy", "Uses async/await".
    # These are excluded from L1 selection until W2.3 (ai-driven-save)
    # refactors curator to filter them at the source.
    _MECHANICAL_ID_PREFIXES = ("ep-auto-", "ep-rule-")

    # Keywords that indicate an actionable, critical rule (earn scoring bonus).
    _CRITICALITY_KEYWORDS = (
        "CRITICAL", "MUST", "NEVER", "ALWAYS", "REQUIRED",
        "Never", "Always", "Must",
    )

    def _is_mechanical(self, rule: dict) -> bool:
        """Return True if rule_id matches a known mechanical auto-extraction prefix."""
        rule_id = str(rule.get("rule_id", rule.get("rule", rule.get("name", "")))).lower()
        return any(rule_id.startswith(p) for p in self._MECHANICAL_ID_PREFIXES)

    @staticmethod
    def _get_behavior(rule: dict) -> str:
        """Extract behavior text from a rule, falling back to description."""
        return str(rule.get("behavior", rule.get("description", ""))).strip()

    @staticmethod
    def _safe_int(val, default: int = 0) -> int:
        """Safely convert to int, returning default on failure."""
        try:
            return int(val)
        except (TypeError, ValueError):
            return default

    @staticmethod
    def _safe_float(val, default: float = 0.5) -> float:
        """Safely convert to float, returning default on failure."""
        try:
            return float(val)
        except (TypeError, ValueError):
            return default

    @staticmethod
    def _get_usage(rule: dict) -> int:
        """Extract effective usage count (max of usage_count and applied_count)."""
        return max(
            Layer1._safe_int(rule.get("usage_count", 0)),
            Layer1._safe_int(rule.get("applied_count", 0)),
        )

    def _is_substantive(self, rule: dict) -> bool:
        """
        Return True if the rule has enough substance to be useful at wake-up.

        Rejects rules with no meaningful behavior text.
        Default threshold: 20 chars. Lowered to 10 chars for curated sources
        (seed-rule, learned-from-incident, claude-code-official-docs) since
        these are pre-validated and even short rules carry actionable signal.
        """
        behavior = self._get_behavior(rule)
        source = str(rule.get("source_repo", ""))
        threshold = 10 if source in self._CURATED_SOURCES else 20
        return len(behavior) >= threshold

    def _score_rule(self, rule: dict, newest_created: Optional[str] = None) -> float:
        """
        Score a rule with improved multi-factor ranking.

        Factors:
          1. Base score: confidence x max(usage_count, applied_count)
          2. Criticality bonus: 1.5x if behavior contains CRITICAL/MUST/NEVER.
          3. Score floor: min 50.0 for critical rules (confidence>=0.9 + severity=critical).
          4. Recency bonus: 2.0x for newest, linear decay to 1.0x over 14 days.
        """
        usage = self._get_usage(rule)
        confidence = self._safe_float(rule.get("confidence", 0.5))
        base = confidence * usage

        # Criticality bonus (1.5x)
        behavior = self._get_behavior(rule)
        has_critical = any(kw in behavior for kw in self._CRITICALITY_KEYWORDS)
        if has_critical:
            base *= 1.5

        # Score floor: confidence >= 0.9 + critical keywords + severity=critical
        severity = str(rule.get("severity", "")).lower()
        if confidence >= 0.9 and has_critical and severity == "critical":
            base = max(base, 50.0)

        # Recency bonus: linear decay from 2.0x (newest) to 1.0x (14 days old)
        if newest_created:
            base = self._apply_recency_bonus(rule, newest_created, base)

        return base

    @staticmethod
    def _apply_recency_bonus(rule: dict, newest_created: str, score: float) -> float:
        """Apply linear recency decay: 2.0x for newest, 1.0x after 14 days."""
        created = rule.get("created_at", "")
        if not created:
            return score
        try:
            created_dt = datetime.fromisoformat(created.replace("Z", "+00:00"))
            newest_dt = datetime.fromisoformat(newest_created.replace("Z", "+00:00"))
            age_days = max(0, (newest_dt - created_dt).days)
            if age_days < 14:
                return score * (2.0 - age_days / 14.0)
        except (ValueError, TypeError):
            pass  # Silently skip recency bonus for malformed dates (non-critical)
        return score

    def _format_rule_as_markdown(self, rule: dict, idx: int) -> str:
        """Format a single rule as a markdown section with domain tag."""
        rule_id = rule.get("rule_id", rule.get("rule", rule.get("name", f"rule_{idx}")))
        behavior = self._get_behavior(rule)
        confidence = rule.get("confidence", 0.0)
        usage = self._get_usage(rule)
        domain = rule.get("domain", "uncategorized") or "uncategorized"
        out = [f"## {idx}. {rule_id} [{domain}]"]
        if behavior:
            out.append(behavior)
        out.append(f"_confidence: {confidence} · usage: {usage}_")
        out.append("")
        return "\n".join(out)

    def _apply_domain_diversity(self, scored_rules: list[dict], max_rules: int) -> list[dict]:
        """
        Apply domain diversity cap: max _MAX_RULES_PER_DOMAIN rules per domain.

        After scoring and sorting, ensures no single domain saturates the L1
        output. Missing domains are grouped as 'uncategorized'.
        """
        domain_counts: dict[str, int] = {}
        selected: list[dict] = []
        for rule in scored_rules:
            domain = rule.get("domain", "uncategorized") or "uncategorized"
            if domain_counts.get(domain, 0) >= self._MAX_RULES_PER_DOMAIN:
                continue
            selected.append(rule)
            domain_counts[domain] = domain_counts.get(domain, 0) + 1
            if len(selected) >= max_rules:
                break
        return selected

    def _compose_content(
        self, top_rules: list[dict], total_input: int, total_actionable: int,
        pipeline_suffix: str,
    ) -> str:
        """Compose the full L1 markdown content from rules and header metadata."""
        lines = [
            f"# L1 Essential Rules ({len(top_rules)} actionable, top by scoring)",
            "",
            f"**Generated**: {self._today_iso()}",
            "**Source**: ~/.ralph/procedural/rules.json",
            f"**Pipeline**: {total_input} total rules -> "
            f"{total_actionable} actionable (excl. mechanical+empty) -> "
            f"top {len(top_rules)} ({pipeline_suffix})",
            "**Scoring**: confidence x max(usage_count, applied_count), x1.5 criticality, "
            "score floor 50 for critical, recency 2.0x->1.0x (14d), domain diversity",
            "",
        ]
        for i, rule in enumerate(top_rules, 1):
            lines.append(self._format_rule_as_markdown(rule, i))
        return "\n".join(lines)

    def build(self) -> Path:
        """
        Build L1_essential.md from the top rules in the procedural store.

        Steps:
          1. Load all rules from rules.json.
          2. Filter out mechanical + non-substantive rules.
          3. Compute newest_created timestamp for recency scoring.
          4. Score each rule with improved multi-factor ranking.
          5. Apply domain diversity (max 3 per domain).
          6. Apply token budget safety trim if L0+L1 > 1400 tokens.
          7. Write as plain markdown to self.path (L1_essential.md).

        Returns:
            Path to the written L1_essential.md file.
        """
        LAYERS_DIR.mkdir(parents=True, exist_ok=True)
        all_rules = self._load_source_rules()

        # Filter out mechanical auto-extracted rules (curator regex patterns)
        # AND empty-behavior rules. Both have zero wake-up leverage.
        actionable_rules = [
            r for r in all_rules
            if not self._is_mechanical(r) and self._is_substantive(r)
        ]

        # Compute newest created_at for recency bonus calculation
        created_dates = [r["created_at"] for r in actionable_rules if r.get("created_at")]
        newest_created: Optional[str] = max(created_dates) if created_dates else None

        # Score with improved multi-factor ranking
        scored = sorted(
            actionable_rules,
            key=lambda r: self._score_rule(r, newest_created),
            reverse=True,
        )

        # Apply domain diversity (max 3 per domain)
        top_rules = self._apply_domain_diversity(scored, self.rule_count)

        total_input = len(all_rules)
        total_actionable = len(actionable_rules)

        content = self._compose_content(
            top_rules, total_input, total_actionable,
            f"max: {self.rule_count}, domain cap: {self._MAX_RULES_PER_DOMAIN}",
        )

        # Token budget safety: trim rules if L0+L1 exceeds 1400 tokens
        l0_tokens = Layer0().token_estimate()
        l1_tokens = len(content) // 4
        while (l0_tokens + l1_tokens) > 1400 and len(top_rules) > 5:
            top_rules = top_rules[:-1]
            content = self._compose_content(
                top_rules, total_input, total_actionable,
                "trimmed for token budget",
            )
            l1_tokens = len(content) // 4
            print(f"  L1 token budget trim: {l0_tokens + l1_tokens} tokens, {len(top_rules)} rules remaining", file=sys.stderr)

        self.path.write_text(content, encoding="utf-8")
        return self.path

    @staticmethod
    def _today_iso() -> str:
        """Return today's date in ISO format."""
        return date.today().isoformat()

    def exists(self) -> bool:
        """Return True if L1_essential.md has been built."""
        return self.path.is_file()

    def load(self) -> str:
        """
        Read and return the essential rules content.

        Returns:
            Plain markdown text of the L1 essentials block.

        Raises:
            FileNotFoundError: If L1 has not been built yet (call build() first).
        """
        if not self.exists():
            raise FileNotFoundError(
                f"L1 essential file not found at {self.path}. "
                "Call Layer1().build() first."
            )
        return self.path.read_text(encoding="utf-8")

    def token_estimate(self) -> int:
        """Rough token estimate for L1 content (1 token ~ 4 chars)."""
        if not self.exists():
            return 0
        return max(1, len(self.path.read_text(encoding="utf-8")) // 4)


# ---------------------------------------------------------------------------
# Layer 2 — Project wings (on-demand)
# ---------------------------------------------------------------------------

class Layer2:
    """
    Project wings layer. On-demand per-project context.

    Context files live at: ~/.ralph/layers/L2_wings/<project_name>/context.md

    These files are written externally (by the learning pipeline or manually)
    and loaded here when a specific project is active.
    """

    def __init__(self, wings_dir: Optional[Path] = None):
        self.wings_dir = wings_dir or L2_DIR

    def _wing_path(self, project_name: str) -> Path:
        """Return the context.md path for a project wing."""
        safe_name = re.sub(r"[^a-zA-Z0-9_\-]", "_", project_name)
        return self.wings_dir / safe_name / "context.md"

    def has(self, project_name: str) -> bool:
        """Return True if a wing context file exists for the given project."""
        return self._wing_path(project_name).is_file()

    def load(self, project_name: str) -> str:
        """
        Load and return the project wing context.

        Args:
            project_name: Project name (used as directory name).

        Returns:
            Content of the project context.md.

        Raises:
            FileNotFoundError: If no wing exists for the project.
        """
        wing_path = self._wing_path(project_name)
        if not wing_path.is_file():
            raise FileNotFoundError(
                f"No L2 wing found for project '{project_name}' at {wing_path}. "
                "Create the wing directory and context.md manually or via the learning pipeline."
            )
        return wing_path.read_text(encoding="utf-8")

    def list_projects(self) -> list[str]:
        """Return a list of project names that have wing context files."""
        if not self.wings_dir.is_dir():
            return []
        return [
            d.name
            for d in self.wings_dir.iterdir()
            if d.is_dir() and (d / "context.md").is_file()
        ]

    def write(self, project_name: str, content: str) -> Path:
        """
        Write or overwrite a project wing context file.

        Args:
            project_name: Project name.
            content: Context content to write.

        Returns:
            Path to the written context.md file.
        """
        wing_path = self._wing_path(project_name)
        wing_path.parent.mkdir(parents=True, exist_ok=True)
        wing_path.write_text(content, encoding="utf-8")
        return wing_path


# ---------------------------------------------------------------------------
# Layer 3 — Vault queries (Obsidian grep-based)
# ---------------------------------------------------------------------------

class Layer3:
    """
    Vault queries layer. Direct Obsidian vault queries via grep + frontmatter.

    NOTE: claude-mem MCP was removed in Wave 0 for security reasons.
    All queries use ~/Documents/Obsidian/MiVault/ via filesystem grep.
    This is the corrected implementation per the W2.2 critical correction.

    Returns structured results with file path, matched line, and snippet context.
    """

    def __init__(self, vault_dir: Optional[Path] = None):
        self.vault_dir = vault_dir or VAULT_DIR

    def _vault_exists(self) -> bool:
        return self.vault_dir.is_dir()

    def _grep_vault(self, pattern: str, file_glob: str = "*.md") -> list[dict]:
        """
        Run grep recursively over the vault directory.

        Args:
            pattern: Grep pattern (case-insensitive).
            file_glob: File pattern to search (default: *.md).

        Returns:
            List of match dicts with keys: file, line_number, line, snippet.
        """
        if not self._vault_exists():
            return []

        try:
            result = subprocess.run(
                [
                    "grep",
                    "--include=" + file_glob,
                    "-r",
                    "-i",
                    "-n",
                    "--with-filename",
                    "-m", "5",  # Max 5 matches per file
                    pattern,
                    str(self.vault_dir),
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode not in (0, 1):
                return []

            matches = []
            for raw_line in result.stdout.splitlines():
                # Format: /path/to/file.md:42:matched line content
                parts = raw_line.split(":", 2)
                if len(parts) < 3:
                    continue
                file_path = parts[0]
                try:
                    line_number = int(parts[1])
                except ValueError:
                    continue
                matched_text = parts[2]

                snippet = matched_text.strip()
                if len(snippet) > L3_SNIPPET_MAX:
                    snippet = snippet[:L3_SNIPPET_MAX] + "..."

                matches.append(
                    {
                        "file": file_path,
                        "line_number": line_number,
                        "line": matched_text.strip(),
                        "snippet": snippet,
                    }
                )
            return matches

        except (subprocess.TimeoutExpired, FileNotFoundError):
            return []

    def _grep_json(self, pattern: str) -> list[dict]:
        """
        Grep JSON files in the migrated-from-claude-mem directory.

        Args:
            pattern: Case-insensitive grep pattern.

        Returns:
            List of match dicts.
        """
        json_dir = self.vault_dir / "migrated-from-claude-mem"
        if not json_dir.is_dir():
            return []

        try:
            result = subprocess.run(
                [
                    "grep",
                    "--include=*.json",
                    "-r",
                    "-i",
                    "-n",
                    "--with-filename",
                    "-m", "3",
                    pattern,
                    str(json_dir),
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode not in (0, 1):
                return []

            matches = []
            for raw_line in result.stdout.splitlines():
                parts = raw_line.split(":", 2)
                if len(parts) < 3:
                    continue
                file_path = parts[0]
                try:
                    line_number = int(parts[1])
                except ValueError:
                    continue
                matched_text = parts[2]

                snippet = matched_text.strip()
                if len(snippet) > L3_SNIPPET_MAX:
                    snippet = snippet[:L3_SNIPPET_MAX] + "..."

                matches.append(
                    {
                        "file": file_path,
                        "line_number": line_number,
                        "line": matched_text.strip(),
                        "snippet": snippet,
                    }
                )
            return matches

        except (subprocess.TimeoutExpired, FileNotFoundError):
            return []

    def query(self, question: str, max_results: int = 10) -> list[dict]:
        """
        Query the Obsidian vault for relevant content.

        Implementation: grep over ~/Documents/Obsidian/MiVault/ for keywords
        extracted from the question. Searches both .md files and migrated JSON.

        Args:
            question: Natural-language question or keyword string.
            max_results: Maximum number of results to return.

        Returns:
            List of match dicts, each with:
              - file: absolute path to matching file
              - line_number: line number of match
              - line: matched line text
              - snippet: truncated snippet (max L3_SNIPPET_MAX chars)

        Notes:
            - Vault queries are read-only (vault is treated as immutable per Wave 0).
            - Uses case-insensitive grep; not semantic search (semantic is Wave 2.3+).
            - Results are deduplicated by file path.
        """
        if not question or not question.strip():
            return []

        # Extract keywords: words >= 4 chars, skip stop words
        stop_words = {
            "what", "when", "where", "which", "that", "this", "with",
            "from", "have", "about", "will", "been", "does", "into",
            "they", "their", "there", "were",
        }
        words = re.findall(r"[a-zA-Z]{4,}", question)
        keywords = [w for w in words if w.lower() not in stop_words]

        # Use all keywords joined as an alternation for a single grep pass,
        # or fall back to the full question as a phrase.
        if keywords:
            pattern = "|".join(re.escape(kw) for kw in keywords[:5])
        else:
            pattern = re.escape(question.strip())

        md_matches = self._grep_vault(pattern, file_glob="*.md")
        json_matches = self._grep_json(pattern)
        all_matches = md_matches + json_matches

        # Deduplicate: keep first match per file
        seen_files: set[str] = set()
        deduped: list[dict] = []
        for match in all_matches:
            if match["file"] not in seen_files:
                seen_files.add(match["file"])
                deduped.append(match)
            if len(deduped) >= max_results:
                break

        return deduped

    def query_with_keywords(self, keywords: list[str], max_results: int = 10) -> list[dict]:
        """
        Query vault using explicit keywords (alternative to natural-language query).

        Args:
            keywords: List of keyword strings to search for.
            max_results: Maximum number of results to return.

        Returns:
            Same structure as query().
        """
        if not keywords:
            return []
        pattern = "|".join(re.escape(kw) for kw in keywords[:5])
        md_matches = self._grep_vault(pattern, file_glob="*.md")
        json_matches = self._grep_json(pattern)
        all_matches = md_matches + json_matches

        seen_files: set[str] = set()
        deduped: list[dict] = []
        for match in all_matches:
            if match["file"] not in seen_files:
                seen_files.add(match["file"])
                deduped.append(match)
            if len(deduped) >= max_results:
                break

        return deduped


# ---------------------------------------------------------------------------
# Wake-up loader (used by wake-up-layer-stack.sh via Python call)
# ---------------------------------------------------------------------------

def load_wake_up_context() -> str:
    """
    Load L0 + L1 context for session wake-up.

    Returns a formatted string combining identity (L0) and essential rules (L1),
    suitable for injection as additionalContext in a SessionStart hook.

    Target: <1500 tokens total.
    """
    parts = []

    l0 = Layer0()
    if l0.exists():
        parts.append("## Identity (L0)\n\n" + l0.load().strip())
    else:
        parts.append("## Identity (L0)\n\n[L0 file missing — run Layer0 setup]")

    l1 = Layer1()
    if l1.exists():
        try:
            parts.append("## Essential Rules (L1)\n\n" + l1.load().strip())
        except Exception as exc:
            parts.append(f"## Essential Rules (L1)\n\n[L1 decode error: {exc}]")
    else:
        parts.append(
            "## Essential Rules (L1)\n\n"
            "[L1 not built — run: python3 .claude/lib/layers.py --build-l1]"
        )

    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# Rule Graduation: promote proven rules to ~/.claude/rules/proven/
# ---------------------------------------------------------------------------

def graduate_rules(dry_run: bool = False) -> tuple[list[Path], list[str]]:
    """
    Graduate high-quality rules from rules.json to always-on ~/.claude/rules/proven/.

    A rule qualifies when it meets ALL of:
      - confidence >= 0.9
      - max(usage_count, applied_count) >= 20
      - behavior text >= 50 chars (substantive, not trivial)
      - NOT a mechanical auto-extraction (ep-auto-*, ep-rule-*)
      - domain is defined

    Each graduated rule becomes a standalone .md file:
      ~/.claude/rules/proven/{domain}-{rule_id}.md

    Returns:
      (promoted_paths, skipped_reasons) for reporting.
    """
    layer1 = Layer1()
    try:
        all_rules = layer1._load_source_rules()
    except FileNotFoundError:
        return [], ["No rules.json found"]
    except json.JSONDecodeError as e:
        return [], [f"rules.json corrupt: {e}"]

    promoted: list[Path] = []
    skipped: list[str] = []
    proven_dir = PROVEN_RULES_DIR

    if not dry_run:
        proven_dir.mkdir(parents=True, exist_ok=True)

    for rule in all_rules:
        rule_id = str(rule.get("rule_id", "")).strip()
        if not rule_id:
            continue

        # --- Filters ---
        if layer1._is_mechanical(rule):
            continue

        confidence = Layer1._safe_float(rule.get("confidence", 0), default=0.0)
        if confidence < GRADUATE_MIN_CONFIDENCE:
            continue

        usage = Layer1._get_usage(rule)
        if usage < GRADUATE_MIN_USAGE:
            continue

        behavior = Layer1._get_behavior(rule)
        if len(behavior) < GRADUATE_MIN_BEHAVIOR_LEN:
            skipped.append(f"{rule_id}: behavior too short ({len(behavior)} chars)")
            continue

        domain = str(rule.get("domain", "")).strip().lower() or "general"

        # --- Generate file ---
        safe_id = rule_id.replace("/", "-").replace(" ", "-")
        filename = f"{domain}-{safe_id}.md"
        filepath = proven_dir / filename

        trigger = str(rule.get("trigger", "")).strip()

        content = (
            f"# {rule_id}\n"
            f"\n"
            f"{behavior}\n"
            f"\n"
            f"**Trigger**: {trigger or 'N/A'}  \n"
            f"**Domain**: {domain}  \n"
            f"**Confidence**: {confidence}  \n"
            f"**Usage**: {usage}  \n"
        )

        if dry_run:
            promoted.append(filepath)
        else:
            try:
                existing = filepath.read_text(encoding="utf-8") if filepath.exists() else ""
            except (PermissionError, OSError) as e:
                skipped.append(f"{rule_id}: read failed ({e})")
                continue
            if existing == content:
                skipped.append(f"{rule_id}: unchanged (already graduated)")
                # Still track as qualifying — don't let cleanup delete it
                promoted.append(filepath)
                continue
            try:
                filepath.write_text(content, encoding="utf-8")
                promoted.append(filepath)
            except (PermissionError, OSError) as e:
                skipped.append(f"{rule_id}: write failed ({e})")
                continue

    # Clean stale files (rules that no longer qualify but still have files)
    if not dry_run and proven_dir.is_dir():
        promoted_ids = {p.name for p in promoted}
        for existing_file in proven_dir.glob("*.md"):
            if existing_file.name not in promoted_ids:
                try:
                    existing_file.unlink()
                    skipped.append(f"CLEANUP: removed {existing_file.name}")
                except (PermissionError, OSError) as e:
                    skipped.append(f"CLEANUP FAILED: {existing_file.name}: {e}")

    return promoted, skipped


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys

    args = sys.argv[1:]

    if "--build-l1" in args:
        print("Building L1 essential rules...")
        path = Layer1().build()
        content = Layer1().load()
        token_est = max(1, len(content) // 4)
        print(f"Written to: {path}")
        print(f"Decoded token estimate: {token_est}")

    elif "--load-l0" in args:
        print(Layer0().load())

    elif "--load-l1" in args:
        print(Layer1().load())

    elif "--wake-up" in args:
        print(load_wake_up_context())

    elif "--query" in args:
        idx = args.index("--query")
        if idx + 1 < len(args):
            question = args[idx + 1]
            results = Layer3().query(question)
            print(json.dumps(results, indent=2))
        else:
            print("Usage: layers.py --query <question>", file=sys.stderr)
            sys.exit(1)

    elif "--install-cron" in args:
        # Install daily L1 rebuild cron job at 6:00 AM
        script_path = Path(__file__).resolve().parent.parent.parent / "scripts" / "l1-rebuild.sh"
        cron_entry = f"0 6 * * * {script_path} >> ~/.ralph/logs/l1-rebuild.log 2>&1  # ralph-l1-rebuild"
        # Check if already installed
        result = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
        if result.returncode == 0:
            current_cron = result.stdout
        elif "no crontab" in result.stderr.lower() or "not found" in result.stderr.lower():
            current_cron = ""  # No crontab exists yet — safe to proceed
        else:
            print(f"Warning: crontab -l failed: {result.stderr.strip()}", file=sys.stderr)
            current_cron = ""  # Fallback: don't destroy, start fresh
        if "ralph-l1-rebuild" in current_cron:
            print("L1 rebuild cron already installed.")
        else:
            new_cron = current_cron.rstrip("\n") + "\n" + cron_entry + "\n"
            process = subprocess.run(["crontab", "-"], input=new_cron, text=True)
            if process.returncode == 0:
                print(f"L1 rebuild cron installed: daily at 6:00 AM")
                print(f"  Script: {script_path}")
            else:
                print("Failed to install cron job.", file=sys.stderr)
                sys.exit(1)

    elif "--remove-cron" in args:
        # Remove L1 rebuild cron job
        result = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
        if result.returncode == 0:
            current_cron = result.stdout
        elif "no crontab" in result.stderr.lower() or "not found" in result.stderr.lower():
            current_cron = ""  # No crontab exists yet — safe to proceed
        else:
            print(f"Warning: crontab -l failed: {result.stderr.strip()}", file=sys.stderr)
            current_cron = ""  # Fallback: don't destroy, start fresh
        if "ralph-l1-rebuild" not in current_cron:
            print("No L1 rebuild cron found.")
        else:
            new_lines = [
                line for line in current_cron.splitlines()
                if "ralph-l1-rebuild" not in line
            ]
            new_cron = "\n".join(new_lines) + "\n" if new_lines else ""
            process = subprocess.run(["crontab", "-"], input=new_cron, text=True)
            if process.returncode == 0:
                print("L1 rebuild cron removed.")
            else:
                print("Failed to remove cron job.", file=sys.stderr)
                sys.exit(1)

    elif "--graduate" in args:
        dry_run = "--dry-run" in args
        promoted, skipped = graduate_rules(dry_run=dry_run)
        if dry_run:
            print(f"[DRY RUN] {len(promoted)} rules would be promoted:")
        else:
            print(f"Graduated {len(promoted)} rules to {PROVEN_RULES_DIR}/")
        for p in promoted:
            print(f"  + {p.name}")
        if skipped:
            print(f"\nSkipped ({len(skipped)}):")
            for s in skipped:
                print(f"  - {s}")

    else:
        print("Usage:")
        print("  python3 layers.py --build-l1       Build L1 essential rules from procedural store")
        print("  python3 layers.py --load-l0        Print L0 identity")
        print("  python3 layers.py --load-l1        Print decoded L1 essentials")
        print("  python3 layers.py --wake-up        Print L0+L1 combined wake-up context")
        print("  python3 layers.py --query <q>      Query vault (Layer3)")
        print("  python3 layers.py --install-cron   Install daily L1 rebuild cron at 6:00 AM")
        print("  python3 layers.py --remove-cron    Remove L1 rebuild cron")
        print("  python3 layers.py --graduate       Promote proven rules to ~/.claude/rules/proven/")
        print("  python3 layers.py --graduate --dry-run  Preview what would be promoted")
