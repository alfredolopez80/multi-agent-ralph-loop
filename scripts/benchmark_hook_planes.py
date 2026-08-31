#!/usr/bin/env python3
"""T82 (#46 C6) — per-hook latency attribution by plane, both profiles.

Measures the WALL TIME of one full hook invocation (exactly what the harness
pays synchronously at that event), 5 runs each, median reported, for:

  - variant A: the security-only profile
    (.claude/security/settings.security-only.json — READ ONLY here)
  - live: every hook registered in ~/.claude/settings.json (READ ONLY)

Events measured (the ordinary hot path): PreToolUse, PostToolUse,
UserPromptSubmit, Stop. SessionStart is warm-once (three of its maintenance
hooks self-background; see T71) and SessionEnd is cold by definition — both
out of this table, stated in the report.

Plane map is DECLARED below (basename -> plane). 'security' means a manifest
control (SECURITY_BASELINE.json is the definition of the plane); everything
else is classified honestly, with Aristotle separated because it is
user-mandated methodology, neither security nor memory.

No guard is modified: measuring around, never inside (lead's constraint).

Run: python3 scripts/benchmark_hook_planes.py   (stdlib only)
"""
import json
import statistics
import subprocess
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LIVE_SETTINGS = Path("~/.claude/settings.json").expanduser()
PROFILE_PATH = REPO / ".claude" / "security" / "settings.security-only.json"
RUNS = 5

PAYLOADS = {
    "PreToolUse": json.dumps({
        "session_id": "t82-bench", "tool_name": "Bash",
        "tool_input": {"command": "ls -la"},
    }),
    "PostToolUse": json.dumps({
        "session_id": "t82-bench", "tool_name": "Bash",
        "tool_input": {"command": "ls -la"},
        "tool_response": {"stdout": "file1\nfile2"},
    }),
    "UserPromptSubmit": json.dumps({"session_id": "t82-bench", "prompt": "run the tests"}),
    "Stop": json.dumps({"session_id": "t82-bench", "stop_hook_active": False}),
}

HOT_EVENTS = ("PreToolUse", "PostToolUse", "UserPromptSubmit", "Stop")

# Declared plane map (basename -> plane). Manifest controls = 'security'.
PLANES = {
    # security plane (SECURITY_BASELINE controls)
    "permission-guard.sh": "security",
    "git-safety-guard.py": "security",
    "repo-boundary-guard.sh": "security",
    "k8s-context-guard-v2.py": "security",
    "skill-validator.sh": "security",
    # security-adjacent (security-flavored, outside the manifest)
    "audit-secrets.js": "security-adjacent",
    "promptify-security.sh": "security-adjacent",
    # memory plane (vault / learning / recall / projection / diaries)
    "vault-fact-extractor.sh": "memory",
    "session-accumulator.sh": "memory",
    "smart-memory-search.sh": "memory",
    "orchestrator-auto-learn.sh": "memory",
    "memory-projection.sh": "memory",
    "vault-index-updater.sh": "memory",
    "vault-wing-compiler.sh": "memory",
    "vault-log-writer.sh": "memory",
    "vault-weekly-compile.sh": "memory",
    "vault-graduation.sh": "memory",
    "vault-promotion.sh": "memory",
    "vault-writeback.sh": "memory",
    # user-mandated methodology (neither security nor memory)
    "universal-aristotle-gate.sh": "aristotle",
    "aristotle-analysis-display.sh": "aristotle",
}

DEFAULT_PLANE = "orchestration+state"


def plane_of(command: str) -> str:
    base = command.strip().split("/")[-1]
    return PLANES.get(base, DEFAULT_PLANE)


def hooks_by_event(settings: dict, events) -> dict:
    out = {}
    for event in events:
        entries = []
        for block in settings.get("hooks", {}).get(event, []):
            for hook in block.get("hooks", []):
                command = hook.get("command", "")
                if command:
                    entries.append((command, block.get("matcher", "(none)")))
        out[event] = entries
    return out


def resolve_command(command: str) -> str:
    """Variant A commands are $CLAUDE_PROJECT_DIR-prefixed; the live ones are
    absolute. Expand the prefix to this repo for direct bash execution."""
    prefix = "$CLAUDE_PROJECT_DIR/"
    if command.startswith(prefix):
        return str(REPO / command[len(prefix):])
    return command


def measure(command: str, event: str):
    cmd = resolve_command(command)
    if cmd.endswith(".js"):
        argv = ["node", cmd]
    elif cmd.endswith(".mjs"):
        argv = ["node", cmd]
    elif cmd.endswith(".py"):
        argv = ["python3", cmd]
    else:
        argv = ["bash", cmd]
    times = []
    for _ in range(RUNS):
        started = time.perf_counter()
        proc = subprocess.run(
            argv, input=PAYLOADS[event], capture_output=True, text=True,
            timeout=30, cwd=str(REPO),
        )
        times.append((time.perf_counter() - started) * 1000.0)
        if proc.returncode != 0:
            return {"median_ms": None, "error": f"exit {proc.returncode}: {proc.stderr.strip()[:120]}"}
    return {"median_ms": round(statistics.median(times), 1),
            "min_ms": round(min(times), 1), "max_ms": round(max(times), 1)}


def matcher_fires(matcher: str, tool: str) -> bool:
    """Would this registration fire for the given tool name? A missing
    matcher matches everything; a pipe-alternation matches any member.
    (Same lesson as T71-v2: summing registrations without matchers counts
    hooks that never run for that tool.)"""
    if matcher in ("(none)", "", "*"):
        return True
    return tool in [part.strip() for part in matcher.split("|")]


def main() -> int:
    variant_a = json.loads(PROFILE_PATH.read_text())
    live = json.loads(LIVE_SETTINGS.read_text())

    report = {"runs": RUNS, "stat": "median", "profiles": {}}
    for name, settings in (("variant_A", variant_a), ("live_full", live)):
        rows = []
        for event, entries in hooks_by_event(settings, HOT_EVENTS).items():
            for command, matcher in entries:
                res = measure(command, event)
                rows.append({
                    "event": event, "matcher": matcher,
                    "command": command.split("/")[-1],
                    "plane": plane_of(command), **res,
                })
        report["profiles"][name] = rows

    # Matcher-aware aggregation: what an ORDINARY Bash tool call costs.
    # PreToolUse/PostToolUse rows count only when the matcher fires for
    # Bash; UserPromptSubmit/Stop have no tool matchers (all fire).
    for name in report["profiles"]:
        print(f"\n== {name} ==  (cost of one ordinary Bash tool call + turn)")
        planes = {}
        for row in report["profiles"][name]:
            if row["median_ms"] is None:
                print(f"  ERROR {row['event']:16s} {row['command']:34s} {row['error']}")
                continue
            if row["event"] in ("PreToolUse", "PostToolUse"):
                if not matcher_fires(row["matcher"], "Bash"):
                    continue
            planes.setdefault(row["plane"], {}).setdefault(row["event"], [0.0, 0])
            agg = planes[row["plane"]][row["event"]]
            agg[0] += row["median_ms"]
            agg[1] += 1
        print(f"  {'plane':20s} {'event':16s} {'hooks':>5} {'ms':>8}")
        grand = {}
        for plane in sorted(planes):
            for event in HOT_EVENTS:
                if event in planes[plane]:
                    total, count = planes[plane][event]
                    print(f"  {plane:20s} {event:16s} {count:>5} {total:>8.1f}")
                    grand[plane] = grand.get(plane, 0.0) + total
        print(f"  {'TOTAL/plane':20s} {'bash+turn':16s} {'':>5} {'':>8}")
        for plane, total in sorted(grand.items(), key=lambda kv: -kv[1]):
            print(f"  {plane:20s} {'':16s} {'':>5} {total:>8.1f}")

    # Per-hook detail for the dominant plane (T85): what the aggregate is
    # made of, most expensive first. Every row is a REGISTRATION; whether it
    # fires for a given tool is its matcher (shown).
    print("\n== orchestration+state, hook by hook (live profile) ==")
    rows = [r for r in report["profiles"]["live_full"]
            if r["plane"] == DEFAULT_PLANE and r["median_ms"] is not None]
    for row in sorted(rows, key=lambda r: -r["median_ms"]):
        print(f"  {row['median_ms']:>7.1f}ms  {row['event']:16s} "
              f"{row['matcher']:14s} {row['command']}")

    out = REPO / "results" / "t82-hook-planes.json"
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(f"\nJSON: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
