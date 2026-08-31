#!/usr/bin/env python3
"""count_active_hooks.py — reproducible per-event tally of an active Claude settings JSON.

Outputs the count of matcher tuples and hook commands grouped by event
(PreToolUse, PostToolUse, SessionStart, SessionEnd, SubagentStart,
SubagentStop, ...) for a Claude Code settings.json-like file. Designed for
"delete-first" simplifications (#69 Phase 2 / PR 4): before removing any
default registration, you need a number that says "this is what's active
today", and that number must be reproducible from git, not from whatever
happens to be in your working tree.

METHOD (single source of truth):

  The script reads the file via one of two paths:
    1. With --ref <git-ref>    →   git show <ref>:<path>  (RECOMMENDED)
    2. Without --ref           →   read <path> from the working tree
                                    (convenience; do NOT use for audits)

  The JSON shape is documented for Claude Code hooks: top-level
  "hooks": { <event>: [ { "matcher": ..., "hooks": [ { "type": "command",
  "command": ... }, ... ] }, ... ] }. Per-event totals are:

      tuples(ev)   = len(<event-array>)
      commands(ev) = sum(len(matcher["hooks"]) for matcher in <event-array>)

WARNING — read this before trusting the output:

  The HEAD or main-branch ref is authoritative. The working tree may be
  ahead of, behind, or simply different from main (e.g. a worktree with
  local edits, a rebase mid-flight, a stash). Counting from the working
  tree yields a number that no other machine will reproduce. For audits,
  PR reviews, or any "what is the active registration today" claim, use
  --ref main (or --ref HEAD once you have committed). Without --ref, the
  number is a LOCAL SNAPSHOT ONLY.

Exit codes (fail loud, fail fast):

  0  ok, output produced
  2  path not readable (missing, not a file, or git ref unreadable)
  3  JSON parse failure on the input
  4  JSON parsed but has no top-level "hooks" object (shape mismatch)

Usage:

  # Local snapshot (working tree) — convenience, NOT for audits
  scripts/benchmark/count_active_hooks.py \\
      --path .claude/settings.json.example

  # Audit-grade: read from a specific git ref
  scripts/benchmark/count_active_hooks.py \\
      --path .claude/settings.json.example --ref main

  # Machine-readable output (pipe to jq / json.tool)
  scripts/benchmark/count_active_hooks.py --ref main --json \\
      | python3 -m json.tool

  # Compare two refs
  for ref in main HEAD origin/main; do
      echo "=== $ref ==="
      scripts/benchmark/count_active_hooks.py --ref "$ref"
  done

Feeds: PR 4 / Phase 2 of issue #69 (pre-deletion measurement baseline).
Companion: docs/benchmark/M2_APPLIED.md headline row (line 10) and
docs/benchmark/SETTINGS_OPTIN.md "Compare to active" line. Both cite this
script via the one-liner at the bottom of M2_APPLIED.md "Verification of
the change".
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


EXIT_OK = 0
EXIT_NO_INPUT = 2
EXIT_BAD_JSON = 3
EXIT_BAD_SHAPE = 4


def load_settings(path: str, ref: str | None) -> tuple[dict, str]:
    """Return (parsed_json, source_label). source_label describes where
    the bytes came from so the caller can show it in the text output."""

    if ref:
        # git show <ref>:<path> — authoritative for audits.
        proc = subprocess.run(
            ["git", "show", f"{ref}:{path}"],
            capture_output=True,
            check=False,
        )
        if proc.returncode != 0:
            sys.stderr.write(
                f"ERROR: git show {ref}:{path} failed "
                f"(exit {proc.returncode}): {proc.stderr.decode(errors='replace').strip()}\n"
            )
            sys.exit(EXIT_NO_INPUT)
        try:
            data = json.loads(proc.stdout)
        except json.JSONDecodeError as exc:
            sys.stderr.write(
                f"ERROR: JSON parse failure on git show {ref}:{path}: {exc}\n"
            )
            sys.exit(EXIT_BAD_JSON)
        return data, f"git:{ref}:{path}"

    # Working tree snapshot — convenience only.
    p = Path(path)
    if not p.is_file():
        sys.stderr.write(f"ERROR: {path} is not a readable file\n")
        sys.exit(EXIT_NO_INPUT)
    try:
        text = p.read_text(encoding="utf-8")
    except OSError as exc:
        sys.stderr.write(f"ERROR: cannot read {path}: {exc}\n")
        sys.exit(EXIT_NO_INPUT)
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"ERROR: JSON parse failure on {path}: {exc}\n")
        sys.exit(EXIT_BAD_JSON)
    return data, f"file:{path}"


def tally(data: dict) -> dict[str, dict[str, int]]:
    """Return {event: {matchers: N, commands: M, hook_files: [..]}}.

    hook_files lists the basenames of every command under each event so
    machine consumers can diff per-file between refs without re-parsing
    the JSON."""

    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        sys.stderr.write(
            "ERROR: top-level 'hooks' object missing or not a dict "
            "(shape mismatch — is this a Claude Code settings file?)\n"
        )
        sys.exit(EXIT_BAD_SHAPE)

    out: dict[str, dict[str, int | list[str]]] = {}
    for event in sorted(hooks.keys()):
        matchers = hooks[event]
        if not isinstance(matchers, list):
            continue
        files: list[str] = []
        commands_total = 0
        for m in matchers:
            inner = m.get("hooks", []) if isinstance(m, dict) else []
            for h in inner:
                cmd = h.get("command", "") if isinstance(h, dict) else ""
                files.append(Path(cmd).name if cmd else "<empty>")
                commands_total += 1
        out[event] = {
            "matchers": len(matchers),
            "commands": commands_total,
            "hook_files": files,
        }
    return out


def render_text(tally_data: dict, source: str) -> str:
    name_w = max(22, max((len(k) for k in tally_data.keys()), default=22))
    lines = [
        f"# active hook registration — {source}",
        "",
        f"{'event'.ljust(name_w)}{'matchers'.rjust(10)}{'commands'.rjust(11)}",
        "-" * (name_w + 21),
    ]
    total_t = total_c = 0
    for ev, stats in tally_data.items():
        lines.append(
            f"{ev.ljust(name_w)}{str(stats['matchers']).rjust(10)}{str(stats['commands']).rjust(11)}"
        )
        total_t += stats["matchers"]
        total_c += stats["commands"]
    lines.append("-" * (name_w + 21))
    lines.append(f"{'TOTAL'.ljust(name_w)}{str(total_t).rjust(10)}{str(total_c).rjust(11)}")
    lines.append("")
    lines.append("# authoritative ref: use --ref main for audits (HEAD or main,")
    lines.append("# never the working tree — see module docstring).")
    return "\n".join(lines) + "\n"


def render_json(tally_data: dict, source: str) -> str:
    total_t = sum(s["matchers"] for s in tally_data.values())
    total_c = sum(s["commands"] for s in tally_data.values())
    payload = {
        "source": source,
        "events": tally_data,
        "total": {"matchers": total_t, "commands": total_c},
    }
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="count_active_hooks.py",
        description=(
            "Per-event tally of matcher tuples and hook commands in a Claude "
            "Code settings JSON. Use --ref for audits."
        ),
    )
    p.add_argument(
        "--path",
        default=".claude/settings.json.example",
        help="path to the settings JSON (default: .claude/settings.json.example)",
    )
    p.add_argument(
        "--ref",
        default=None,
        help="git ref to read from via 'git show <ref>:<path>' (RECOMMENDED for audits)",
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="emit machine-readable JSON instead of a text table",
    )
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    data, source = load_settings(args.path, args.ref)
    tallied = tally(data)
    if args.json:
        sys.stdout.write(render_json(tallied, source))
    else:
        sys.stdout.write(render_text(tallied, source))
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
