#!/usr/bin/env python3
"""
optimize-settings.py — Safe, idempotent hardener for ~/.claude/settings.json hooks.

What it does (mechanical, low-risk):
  1. Adds an event-appropriate `timeout` (seconds) to every hook entry that lacks one,
     so a hung hook degrades to a bounded wait instead of Claude Code's 60s default.

  (An earlier version also "normalized" the context-mode `.mjs` command, but that hook
   entry is owned by the context-mode plugin — it re-registers the quoted form every
   session, and that quoted path executes fine — so normalizing it was futile churn and
   has been removed. Only the timeout backfill is durable here.)

Safety model (matches the user's requested workflow):
  * DEFAULT = --dry-run: prints exactly what WOULD change, validates the resulting
    JSON in memory, and WRITES NOTHING.
  * --apply: makes a timestamped backup, writes, then re-reads and re-validates.

Idempotent: re-running adds nothing once timeouts/fix are present.

Usage:
  python3 optimize-settings.py            # dry-run (default)
  python3 optimize-settings.py --apply    # apply after you've reviewed the dry-run
"""
from __future__ import annotations
import argparse
import datetime as _dt
import json
import os
import shutil
import sys
from copy import deepcopy

SETTINGS = os.path.expanduser("~/.claude/settings.json")
BACKUP_DIR = os.path.expanduser(
    "~/Documents/GitHub/multi-agent-ralph-loop/.ralph/backups"
)

# Timeout policy (seconds) per hook event. Tight on hot/ blocking paths,
# more generous on rare maintenance events that legitimately do more work.
TIMEOUT_POLICY = {
    "PreToolUse": 5,        # blocks the tool — must stay tight
    "UserPromptSubmit": 5,  # blocks every message
    "PostToolUse": 10,      # most are async already; sync ones get a ceiling
    "Stop": 10,
    "SessionStart": 10,
    "SessionEnd": 15,       # vault writes
    "PreCompact": 15,
    "SubagentStart": 10,
    "SubagentStop": 10,
    "TeammateIdle": 10,
    "TaskCompleted": 10,
    "TaskCreated": 10,
}
DEFAULT_TIMEOUT = 10


def canonical_hook(h: dict) -> dict:
    """Return a hook dict with keys in a tidy, stable order."""
    out = {}
    for k in ("type", "command", "timeout", "async"):
        if k in h:
            out[k] = h[k]
    for k in h:  # preserve any unexpected keys
        if k not in out:
            out[k] = h[k]
    return out


def short(cmd: str) -> str:
    return cmd.replace('"', "").split("/")[-1].strip() or cmd


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true",
                    help="write changes (default is dry-run)")
    args = ap.parse_args()
    dry = not args.apply

    if not os.path.isfile(SETTINGS):
        print(f"❌ settings.json not found at {SETTINGS}", file=sys.stderr)
        return 1

    with open(SETTINGS, encoding="utf-8") as f:
        original_text = f.read()
    try:
        data = json.loads(original_text)
    except json.JSONDecodeError as e:
        print(f"❌ settings.json is not valid JSON: {e}", file=sys.stderr)
        return 1

    patched = deepcopy(data)
    timeouts_added = 0
    per_event: dict[str, int] = {}

    hooks_section = patched.get("hooks", {})
    if not isinstance(hooks_section, dict):
        print(f"❌ 'hooks' in settings.json is not a JSON object "
              f"(got {type(hooks_section).__name__})", file=sys.stderr)
        return 1
    for event, groups in hooks_section.items():
        for group in groups:
            new_hooks = []
            for h in group.get("hooks", []):
                # timeout backfill (the only durable, non-plugin-owned change)
                if "timeout" not in h:
                    t = TIMEOUT_POLICY.get(event, DEFAULT_TIMEOUT)
                    h["timeout"] = t
                    timeouts_added += 1
                    per_event[event] = per_event.get(event, 0) + 1
                new_hooks.append(canonical_hook(h))
            group["hooks"] = new_hooks

    # Validate the would-be result in memory.
    new_text = json.dumps(patched, indent=2, ensure_ascii=False) + "\n"
    try:
        json.loads(new_text)
    except json.JSONDecodeError as e:
        print(f"❌ patched JSON failed validation (aborting): {e}", file=sys.stderr)
        return 1

    # Report
    print("=" * 64)
    print(f"  optimize-settings.py  [{'DRY-RUN' if dry else 'APPLY'}]")
    print("=" * 64)
    print(f"  Target: {SETTINGS}")
    print(f"  timeouts added:     {timeouts_added}")
    if per_event:
        for ev in sorted(per_event):
            print(f"      {ev:<18} +{per_event[ev]} (timeout={TIMEOUT_POLICY.get(ev, DEFAULT_TIMEOUT)}s)")
    if timeouts_added == 0:
        print("\n  ✅ Nothing to change — settings.json already hardened (idempotent).")
        return 0

    if dry:
        print("\n  DRY-RUN: no file written. Review above, then re-run with --apply.")
        return 0

    # APPLY: backup -> write -> re-validate
    try:
        os.makedirs(BACKUP_DIR, exist_ok=True)
        stamp = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = os.path.join(BACKUP_DIR, f"settings-{stamp}.json")
        shutil.copy2(SETTINGS, backup)
        print(f"\n  📦 backup: {backup}")
    except OSError as e:
        print(f"❌ backup failed ({e}) — aborting; settings.json unchanged", file=sys.stderr)
        return 1

    tmp = SETTINGS + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(new_text)
        os.replace(tmp, SETTINGS)
        # Re-read + re-validate from disk
        with open(SETTINGS, encoding="utf-8") as f:
            json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        try:
            if os.path.exists(tmp):
                os.remove(tmp)
        except OSError:
            pass
        print(f"❌ write/validate failed ({e}).\n   Restore with: cp {backup} {SETTINGS}",
              file=sys.stderr)
        return 1
    print("  ✅ written and re-validated (valid JSON on disk).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
