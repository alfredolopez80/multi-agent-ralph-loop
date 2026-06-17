#!/usr/bin/env python3
"""Ralph offline consolidation (dream) -- builds the absent L3 layer.

Ported and adapted from codex-ralph-vault-loop/scripts/memory/dream.py.

Consolidates the project's own learning sources (session handoffs, continuity
ledgers, and vault lessons) into reviewable L3 consolidation candidates. RED
material is filtered at the source -- it never enters a candidate.

The codex original emitted a generic candidate report and refused to ``--apply``;
Ralph has no L3 layer, so this CLI's job is to construct it. Behaviour:

  * ``--dry-run`` (DEFAULT): report candidate counts by target layer; write
    nothing. Safe to run from a SessionStart/SessionEnd hook.
  * ``--apply``: write the consolidated L3 layer to ``~/.ralph/layers/L3_dream.md``
    (GREEN/YELLOW candidates only; never RED).
  * ``--emit-patch``: print the rendered L3 markdown to stdout for review
    without writing the file.

Library lives in ``_dream_core``; this module is argument parsing + I/O only.

Examples:
    python3 scripts/memory/dream.py --dry-run
    python3 scripts/memory/dream.py --since-days 30 --dry-run --json
    python3 scripts/memory/dream.py --apply
    python3 scripts/memory/dream.py --emit-patch
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

if __package__:
    from ._dream_core import (
        DEFAULT_MAX_ITEMS,
        DEFAULT_VAULT_ROOT,
        L3_LAYER_NAME,
        build_report,
        l3_candidates,
        render_l3,
    )
else:  # pragma: no cover - script-style import support.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from _dream_core import (
        DEFAULT_MAX_ITEMS,
        DEFAULT_VAULT_ROOT,
        L3_LAYER_NAME,
        build_report,
        l3_candidates,
        render_l3,
    )


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _write_l3(ralph_home: Path, report: dict[str, object]) -> Path:
    """Write the rendered L3 layer atomically; return its path."""
    layers_dir = ralph_home.expanduser() / "layers"
    layers_dir.mkdir(parents=True, exist_ok=True)
    path = layers_dir / L3_LAYER_NAME
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(render_l3(report), encoding="utf-8")
    os.replace(tmp, path)
    return path


def _summary_line(report: dict[str, object]) -> str:
    by_layer = report.get("by_target_layer", {})
    by_layer_str = (
        " ".join(f"{layer}={count}" for layer, count in sorted(by_layer.items()))
        if isinstance(by_layer, dict)
        else ""
    )
    return (
        f"sources={report.get('safe_source_count', 0)} "
        f"red_skipped={report.get('red_skipped', 0)} "
        f"candidates={report.get('candidate_count', 0)} "
        f"by_layer[{by_layer_str}] "
        f"l3_eligible={len(l3_candidates(report))}"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Consolidate Ralph learning sources into the L3 dream layer. "
            "Dry-run by default; --apply to write L3_dream.md."
        )
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report candidates without writing any layer. This is the default.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write the consolidated L3 layer to ~/.ralph/layers/L3_dream.md.",
    )
    parser.add_argument(
        "--emit-patch",
        action="store_true",
        help="Print the rendered L3 markdown to stdout without writing it.",
    )
    parser.add_argument("--since-days", type=int, default=None)
    parser.add_argument("--max-items", type=int, default=DEFAULT_MAX_ITEMS)
    parser.add_argument(
        "--ralph-home",
        default=os.environ.get("RALPH_HOME", "~/.ralph"),
        help="Ralph runtime home (handoffs/ledgers/layers live here).",
    )
    parser.add_argument(
        "--vault-root",
        default=os.environ.get("RALPH_VAULT_ROOT", str(DEFAULT_VAULT_ROOT)),
        help="Obsidian vault root (projects/<project>/lessons are scanned).",
    )
    parser.add_argument(
        "--project",
        default=os.environ.get("RALPH_VAULT_PROJECT", ""),
        help="Limit vault lessons to a single project slug (default: all).",
    )
    parser.add_argument("--json", action="store_true", help="Emit the report as JSON.")
    args = parser.parse_args(argv)

    ralph_home = Path(args.ralph_home).expanduser()
    vault_root = Path(args.vault_root).expanduser()
    project = args.project or None

    report = build_report(
        ralph_home,
        args.since_days,
        max(0, args.max_items),
        now_iso(),
        vault_root=vault_root,
        project=project,
    )

    if args.emit_patch:
        report["mode"] = "emit-patch"
        sys.stdout.write(render_l3(report))
        return 0

    if args.apply:
        report["mode"] = "apply"
        path = _write_l3(ralph_home, report)
        if args.json:
            report["l3_path"] = str(path)
            print(json.dumps(report, ensure_ascii=True, indent=2, sort_keys=True))
        else:
            print(f"DREAM_APPLY_OK {path}")
            print(f"DREAM_SUMMARY {_summary_line(report)}")
        return 0

    # Default: dry-run (writes nothing).
    if args.json:
        print(json.dumps(report, ensure_ascii=True, indent=2, sort_keys=True))
    else:
        print(f"DREAM_DRY_RUN_OK {_summary_line(report)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
