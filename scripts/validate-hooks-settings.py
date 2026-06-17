#!/usr/bin/env python3
"""
validate-hooks-settings.py — Validate Claude Code hooks declared in settings.json.

Detects the two classes of failure that surface as runtime hook errors:

  1. "Failed with non-blocking status code" — the hook command cannot be
     launched (missing interpreter, missing target file, e.g. a stale plugin
     cache path like `.../latest/hooks/pretooluse.mjs`).

  2. "Hook JSON output validation failed — (root): Invalid input" — the hook
     runs but writes non-empty stdout that is NOT valid hook JSON for its event.

What it checks
--------------
  * Every settings source (global, project, local, managed) is parseable JSON.
  * Each hook command resolves to an existing executable / target file.
  * Each hook, fed a synthetic event payload, returns stdout that is either
    EMPTY (valid: "no decision") or JSON conforming to the event's root schema.
  * Hooks are exercised with cwd BOTH inside and outside the repo, because
    global hooks run in every project and may emit warnings when out-of-repo.

Exit code: 0 if no problems, 1 if any problem found.

Usage:
  python3 scripts/validate-hooks-settings.py            # validate all sources
  python3 scripts/validate-hooks-settings.py --json     # machine-readable report
  python3 scripts/validate-hooks-settings.py --event PreToolUse --matcher Bash
"""
from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HOME = Path.home()
REPO = Path(__file__).resolve().parent.parent

# Allowed top-level keys per hook event (Claude Code hook output schema).
# An empty stdout is always allowed (means "no decision / continue").
COMMON_KEYS = {
    "continue", "stopReason", "suppressOutput", "systemMessage",
    "hookSpecificOutput", "decision", "reason",
}
EVENT_ROOT_KEYS = {
    "PreToolUse": COMMON_KEYS,
    "PostToolUse": COMMON_KEYS,
    "UserPromptSubmit": COMMON_KEYS,
    "Stop": COMMON_KEYS,
    "SubagentStop": COMMON_KEYS,
    "SessionStart": COMMON_KEYS,
    "SessionEnd": COMMON_KEYS,
    "PreCompact": COMMON_KEYS,
    "Notification": COMMON_KEYS,
    "TeammateIdle": COMMON_KEYS,
    "TaskCompleted": COMMON_KEYS,
    "SubagentStart": COMMON_KEYS,
    "TaskCreated": COMMON_KEYS,
}

# Synthetic payloads per event. Kept minimal but realistic.
def sample_payload(event: str, cwd: str) -> dict:
    base: dict[str, object] = {
        "session_id": "validate", "cwd": cwd, "hook_event_name": event,
        "transcript_path": "/tmp/validate-transcript.jsonl"}
    if event in ("PreToolUse", "PostToolUse"):
        base.update({"tool_name": "Bash",
                     "tool_input": {"command": "echo validate"}})
        if event == "PostToolUse":
            base["tool_response"] = {"stdout": "validate", "stderr": "", "interrupted": False}
    elif event == "UserPromptSubmit":
        base["prompt"] = "validate hooks"
    elif event in ("Stop", "SubagentStop"):
        base["stop_hook_active"] = False
    elif event == "SessionStart":
        base["source"] = "startup"
    elif event == "PreCompact":
        base.update({"trigger": "manual", "custom_instructions": ""})
    return base


def settings_sources() -> list[Path]:
    """Ordered list of settings files Claude Code may merge."""
    cands = [
        HOME / ".claude" / "settings.json",
        HOME / ".claude" / "settings.local.json",
        REPO / ".claude" / "settings.json",
        REPO / ".claude" / "settings.local.json",
        Path("/Library/Application Support/ClaudeCode/managed-settings.json"),
    ]
    cfg = os.environ.get("CLAUDE_CONFIG_DIR")
    if cfg:
        cd = Path(os.path.expanduser(cfg))
        cands.insert(0, cd / "settings.json")
        cands.insert(1, cd / "settings.local.json")
    return [c for c in cands if c.exists()]


def resolve_target(command: str) -> tuple[str | None, str | None]:
    """
    Return (interpreter_or_none, target_file_path_or_none) for a hook command.
    Handles: `node X.mjs`, `bun X.mjs`, `"bun" "X.mjs"`, `python3 X.py`,
    quoted paths, and bare script paths.
    """
    try:
        parts = shlex.split(command)
    except ValueError:
        return (None, None)
    if not parts:
        return (None, None)
    interp_names = {"node", "bun", "deno", "python", "python3", "bash", "sh", "zsh"}
    head = os.path.basename(parts[0])
    if head in interp_names and len(parts) >= 2:
        return (parts[0], parts[1])
    # bare script
    return (None, parts[0])


def check_launchable(command: str) -> str | None:
    """Return an error string if the command cannot be launched, else None."""
    interp, target = resolve_target(command)
    if interp is not None:
        # interpreter must exist on PATH (or be an absolute path)
        if os.path.isabs(interp):
            if not Path(interp).exists():
                return f"interpreter not found: {interp}"
        elif shutil.which(interp) is None:
            return f"interpreter not on PATH: {interp}"
    if target is None:
        return "could not parse command"
    # Only validate existence for path-like targets (skip shell builtins/strings)
    if ("/" in target) or target.endswith((".sh", ".py", ".mjs", ".js")):
        if not Path(os.path.expanduser(target)).exists():
            return f"target file not found: {target}"
    return None


def run_hook(command: str, payload: dict, cwd: str, timeout: int = 10):
    try:
        proc = subprocess.run(
            command, shell=True, input=json.dumps(payload),
            capture_output=True, text=True, cwd=cwd, timeout=timeout,
            env={**os.environ},
        )
        return proc.returncode, proc.stdout, proc.stderr, None
    except subprocess.TimeoutExpired:
        return None, "", "", f"timeout after {timeout}s"
    except Exception as e:  # noqa: BLE001
        return None, "", "", f"launch error: {e}"


def validate_stdout(event: str, stdout: str) -> str | None:
    """Return an error string if stdout is not valid hook output, else None."""
    s = stdout.strip()
    if s == "":
        return None  # empty == no decision == valid
    try:
        obj = json.loads(s)
    except json.JSONDecodeError as e:
        preview = s.replace("\n", "\\n")[:120]
        return f"stdout is not JSON ({e.msg}); got: {preview!r}"
    if not isinstance(obj, dict):
        return f"stdout JSON root must be an object, got {type(obj).__name__}"
    allowed = EVENT_ROOT_KEYS.get(event, COMMON_KEYS)
    unknown = set(obj) - allowed
    if unknown:
        return f"unknown root key(s) for {event}: {sorted(unknown)}"
    # Per tests/HOOK_FORMAT_REFERENCE.md: "block" is the ONLY valid value for the
    # `decision` field. "approve"/"continue" are explicitly invalid.
    if "decision" in obj and obj["decision"] != "block":
        return (f"invalid decision value {obj['decision']!r} "
                f"(only \"block\" is valid; for allow, exit 0 with empty stdout)")
    # `continue`, if present, must be a boolean.
    if "continue" in obj and not isinstance(obj["continue"], bool):
        return f"`continue` must be a boolean, got {type(obj['continue']).__name__}"
    return None


def iter_hooks(settings: dict):
    for event, blocks in (settings.get("hooks") or {}).items():
        if not isinstance(blocks, list):
            continue
        for block in blocks:
            matcher = block.get("matcher", "")
            for hk in block.get("hooks", []) or []:
                if hk.get("type") != "command":
                    continue
                yield event, matcher, hk.get("command", "")


def main() -> int:
    ap = argparse.ArgumentParser(description="Validate Claude Code hooks in settings.json")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--event", help="only validate this hook event")
    ap.add_argument("--matcher", help="only validate blocks whose matcher contains this substring")
    ap.add_argument("--run", action="store_true", default=True,
                    help="execute hooks (default). Use --no-run to only check JSON+paths")
    ap.add_argument("--no-run", dest="run", action="store_false")
    args = ap.parse_args()

    problems: list[dict] = []
    info: list[str] = []

    sources = settings_sources()
    if not sources:
        print("No settings.json sources found.", file=sys.stderr)
        return 1

    # cwd contexts: inside repo + outside repo (a temp dir)
    out_dir = tempfile.mkdtemp(prefix="hookval-")
    cwd_contexts = [("in-repo", str(REPO)), ("out-of-repo", out_dir)]

    for src in sources:
        # 1) settings file must be valid JSON
        try:
            settings = json.loads(src.read_text())
        except json.JSONDecodeError as e:
            problems.append({"source": str(src), "kind": "settings-json",
                             "error": f"invalid JSON: {e}"})
            continue
        info.append(f"parsed OK: {src}")

        for event, matcher, command in iter_hooks(settings):
            if args.event and event != args.event:
                continue
            if args.matcher and args.matcher not in matcher:
                continue

            # 2) launchable?
            le = check_launchable(command)
            if le:
                problems.append({"source": str(src), "kind": "launch",
                                 "event": event, "matcher": matcher,
                                 "command": command, "error": le})
                continue

            if not args.run:
                continue

            # 3) run + validate stdout for each cwd context
            for label, cwd in cwd_contexts:
                payload = sample_payload(event, cwd)
                rc, stdout, stderr, runerr = run_hook(command, payload, cwd)
                if runerr:
                    problems.append({"source": str(src), "kind": "run",
                                     "event": event, "matcher": matcher,
                                     "command": command, "cwd": label,
                                     "error": runerr})
                    continue
                se = validate_stdout(event, stdout)
                if se:
                    problems.append({"source": str(src), "kind": "stdout",
                                     "event": event, "matcher": matcher,
                                     "command": command, "cwd": label,
                                     "rc": rc, "error": se,
                                     "stderr": stderr.strip()[:200]})

    shutil.rmtree(out_dir, ignore_errors=True)

    if args.json:
        print(json.dumps({"problems": problems, "checked_sources":
                          [str(s) for s in sources]}, indent=2))
        return 1 if problems else 0

    # human report
    print("Hook validation report")
    print("=" * 60)
    for line in info:
        print(f"  [src] {line}")
    print()
    if not problems:
        print("✅ No problems found. All hooks launch and emit valid JSON (or empty).")
        return 0

    print(f"❌ {len(problems)} problem(s) found:\n")
    for p in problems:
        print(f"  • [{p['kind']}] {p.get('event','')} matcher={p.get('matcher','')!r}"
              f" {('cwd='+p['cwd']) if 'cwd' in p else ''}")
        print(f"      source : {p['source']}")
        if "command" in p:
            print(f"      command: {p['command']}")
        print(f"      error  : {p['error']}")
        if p.get("stderr"):
            print(f"      stderr : {p['stderr']}")
        print()
    return 1


if __name__ == "__main__":
    sys.exit(main())
