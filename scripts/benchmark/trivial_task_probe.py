#!/usr/bin/env python3
"""Trivial Task Probe (T96) — baseline for PLAN_CERT_METRICS row 6.

Question this probe answers:

  "Does any hook in the active PreToolUse pipeline BLOCK direct Edit/Write
   for a trivial task, forcing the model to spawn a Task/Agent subagent?"

Method:

  For each of 3 trivial fixtures, synthesize the stdin that Claude Code
  would deliver to a PreToolUse hook when the model invokes Edit|Write on
  a small, well-defined change. Run the relevant PreToolUse hooks in
  isolation (isolated HOME, no model, no real session). Parse each hook's
  JSON output and classify it as one of:

    ALLOW   = empty {} or explicit {"permissionDecision":"allow"} or
              {"continue":true}
    DENY    = explicit deny ({"permissionDecision":"deny"} or exit 2 with
              {"decision":"block"})
    ASK     = explicit ask / defer to user
    OTHER   = any other JSON shape (informational, hookSpecificOutput
              without a permissionDecision, etc.)

The baseline is the table itself: if every cell is ALLOW or OTHER (i.e.
no DENY on direct work), there is no technical enforcement forcing
subagents for trivial tasks. The model's choice to spawn a Task is a
process rule, not a coerced one.

Why this lives as a permanent script (not results/):

  Row 6 of the certification matrix has no baseline yet. M2 may try to
  claim "subagent enforcement was retired" — the only way to falsify or
  verify that is to re-run this same probe against the post-M2 tree.
  Same instrument before/after is the only honest comparison.

Run:

  # No setup needed (stdlib only — no tiktoken / venv).
  scripts/benchmark/trivial_task_probe.py

  # Optional:
  #   --out <dir>  output dir for trivial-task-probe.{json,txt}
  #                (default: results/)
  #   --strict     exit 1 if any cell is DENY (used by CI gates when
  #                 the row is later upgraded from "baseline" to "rule")

Output schema (results/trivial-task-probe.json):

  {
    "fixtures": [
      {
        "name": "fix-typo",
        "tool": "Edit",
        "payload": { ... synthetic stdin ... },
        "results": [
          {"hook": "permission-guard.sh", "event": "PreToolUse",
           "exit": 0, "decision": "ALLOW", "reason": "..."},
          ...
        ],
        "any_deny": false,
        "any_ask":  false,
        "conclusion": "no technical enforcement forces subagent for this fixture"
      },
      ...
    ],
    "summary": {
      "total_cells": ...,
      "allow": ..., "deny": ..., "ask": ..., "other": ...,
      "fixtures_with_deny": 0
    }
  }
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
HOOKS = REPO / ".claude" / "hooks"
ISOLATED_HOME = Path(__file__).resolve().parent / ".probe-home-trivial"
TIMEOUT_S = 10

# PreToolUse hooks that fire on Edit|Write|Bash for an ordinary prompt,
# taken from the live global settings dump on 2026-08-28.
# (event, matcher, hook_basename)
PIPELINE = [
    ("PreToolUse", "Edit|Write", "permission-guard.sh"),
    ("PreToolUse", "Edit|Write", "repo-boundary-guard.sh"),
    ("PreToolUse", "Edit|Write", "checkpoint-auto-save.sh"),
    ("PreToolUse", "Edit|Write", "universal-aristotle-gate.sh"),
    # Bash chain (some fixtures route via Bash heredoc / sed)
    ("PreToolUse", "Bash",       "git-safety-guard.py"),
    ("PreToolUse", "Bash",       "permission-guard.sh"),
    ("PreToolUse", "Bash",       "repo-boundary-guard.sh"),
    ("PreToolUse", "Bash",       "k8s-context-guard-v2.py"),
    ("PreToolUse", "Bash",       "universal-aristotle-gate.sh"),
    # The ONLY hook in this codebase that touches subagent dispatch:
    # PreToolUse:Task only — does NOT fire on Edit|Write|Bash, so by
    # construction it cannot force subagents for direct work.
    # Listed here so the report is explicit about why we exclude it.
]


def fixture(name: str, tool: str, tool_input: dict, description: str) -> dict:
    """Build a synthetic stdin payload for a PreToolUse invocation."""
    return {
        "name": name,
        "description": description,
        "tool": tool,
        "payload": {
            "session_id": "trivial-task-probe",
            "transcript_path": "/tmp/trivial-task-probe/transcript.jsonl",
            "cwd": str(REPO),
            "hook_event_name": "PreToolUse",
            "tool_name": tool,
            "tool_input": tool_input,
        },
    }


FIXTURES = [
    fixture(
        name="fix-typo",
        tool="Edit",
        tool_input={
            "file_path": "docs/README.md",
            "old_string": "Teh quick brown fox.",
            "new_string": "The quick brown fox.",
        },
        description="Trivial: fix typo 'Teh' -> 'The' in a single README line.",
    ),
    fixture(
        name="add-test",
        tool="Edit",
        tool_input={
            "file_path": "scripts/lib/util.sh",
            "old_string": "# end of util.sh",
            "new_string": (
                "# end of util.sh\n"
                "\n"
                "# Added by trivial-task-probe fixture 'add-test'.\n"
                "test_dummy() { return 0; }\n"
            ),
        },
        description="Trivial: append a dummy test function to an existing shell script.",
    ),
    fixture(
        name="update-constant",
        tool="Edit",
        tool_input={
            "file_path": "scripts/benchmark/hotpath_probe.py",
            "old_string": "DEFAULT_RUNS = 12",
            "new_string": "DEFAULT_RUNS = 12  # baseline (T93 M1)",
        },
        description="Trivial: add a trailing comment to a numeric constant in the existing probe.",
    ),
]


def classify(stdout: str, stderr: str, exit_code: int) -> tuple[str, str]:
    """Parse a hook's stdout JSON and return (decision, reason)."""
    text = (stdout or "").strip()
    if not text:
        # Some hooks only emit on stderr; treat silent allow as ALLOW.
        return ("ALLOW", "empty stdout (default pass)")
    try:
        obj = json.loads(text.splitlines()[0])
    except (json.JSONDecodeError, IndexError):
        return ("OTHER", f"non-JSON output ({len(text)} bytes)")
    if "permissionDecision" in obj.get("hookSpecificOutput", {}):
        d = obj["hookSpecificOutput"]["permissionDecision"]
        r = obj["hookSpecificOutput"].get("permissionDecisionReason", "")
        if d == "allow":
            return ("ALLOW", r or "explicit allow")
        if d == "deny":
            return ("DENY", r or "explicit deny")
        if d == "ask":
            return ("ASK", r or "explicit ask")
        return ("OTHER", f"permissionDecision={d!r} reason={r!r}")
    if "continue" in obj:
        return ("ALLOW", "continue=true" if obj["continue"] else "ALLOW (continue=false but no decision)")
    if "decision" in obj:
        d = obj["decision"]
        return ("ALLOW" if d == "approve" else "DENY" if d == "block" else "OTHER",
                f"decision={d}")
    return ("OTHER", f"unrecognized JSON keys: {sorted(obj)}")


def run_one_hook(hook: Path, payload: str, home: Path):
    env = dict(os.environ)
    env["HOME"] = str(home)
    try:
        p = subprocess.run(
            ["bash", str(hook)],
            input=payload.encode(),
            capture_output=True,
            env=env,
            timeout=TIMEOUT_S,
            cwd=str(REPO),
        )
        return p.returncode, p.stdout.decode(errors="replace"), p.stderr.decode(errors="replace")
    except subprocess.TimeoutExpired:
        return -1, "", f"TIMEOUT after {TIMEOUT_S}s"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, default=REPO / "results",
                    help="output dir for trivial-task-probe.{json,txt}")
    ap.add_argument("--strict", action="store_true",
                    help="exit 1 if any cell is DENY")
    args = ap.parse_args()

    ISOLATED_HOME.mkdir(parents=True, exist_ok=True)
    (ISOLATED_HOME / ".ralph").mkdir(exist_ok=True)
    (ISOLATED_HOME / ".claude").mkdir(exist_ok=True)

    out = {"fixtures": [], "summary": {"allow": 0, "deny": 0, "ask": 0, "other": 0}}
    any_deny_overall = False

    for fx in FIXTURES:
        payload = json.dumps(fx["payload"])
        results = []
        any_deny = False
        any_ask = False
        for event, matcher, basename in PIPELINE:
            hook = HOOKS / basename
            if not hook.exists():
                results.append({"event": event, "matcher": matcher, "hook": basename,
                                 "decision": "OTHER", "reason": "HOOK_NOT_FOUND"})
                continue
            exit_code, stdout, stderr = run_one_hook(hook, payload, ISOLATED_HOME)
            decision, reason = classify(stdout, stderr, exit_code)
            results.append({"event": event, "matcher": matcher, "hook": basename,
                            "exit": exit_code, "decision": decision, "reason": reason})
            if decision == "DENY":
                any_deny = True
            elif decision == "ASK":
                any_ask = True
            out["summary"][decision.lower()] = out["summary"].get(decision.lower(), 0) + 1
        conclusion = (
            "no technical enforcement forces subagent for this fixture"
            if not any_deny
            else "AT LEAST ONE HOOK DENIED DIRECT WORK — investigate before M2"
        )
        out["fixtures"].append({
            "name": fx["name"],
            "description": fx["description"],
            "tool": fx["tool"],
            "results": results,
            "any_deny": any_deny,
            "any_ask": any_ask,
            "conclusion": conclusion,
        })
        if any_deny:
            any_deny_overall = True
        print(f"\n=== fixture: {fx['name']} ({fx['tool']}) ===")
        print(f"  {fx['description']}")
        for r in results:
            tag = "  " + r["decision"].ljust(5)
            print(f"    {tag} {r['hook']:<28} ({r['matcher']}) :: {r['reason'][:80]}")
        print(f"  -> any_deny={any_deny} any_ask={any_ask}")
        print(f"  -> {conclusion}")

    out["summary"]["total_cells"] = sum(out["summary"].values())
    out["summary"]["fixtures_with_deny"] = sum(
        1 for f in out["fixtures"] if f["any_deny"]
    )

    args.out.mkdir(parents=True, exist_ok=True)
    json_path = args.out / "trivial-task-probe.json"
    txt_path = args.out / "trivial-task-probe.txt"
    json_path.write_text(json.dumps(out, indent=2))

    lines = ["| Fixture | Tool | DENY? | ASK? | Conclusion |",
             "|---|---|---|---|---|"]
    for f in out["fixtures"]:
        lines.append(f"| {f['name']} | {f['tool']} | "
                     f"{'YES' if f['any_deny'] else 'no'} | "
                     f"{'YES' if f['any_ask'] else 'no'} | "
                     f"{f['conclusion'][:60]} |")
    lines.append("")
    lines.append("Summary:")
    lines.append(f"  total_cells         = {out['summary']['total_cells']}")
    lines.append(f"  allow               = {out['summary'].get('allow', 0)}")
    lines.append(f"  deny                = {out['summary'].get('deny', 0)}")
    lines.append(f"  ask                 = {out['summary'].get('ask', 0)}")
    lines.append(f"  other (non-JSON / unrecognized) = {out['summary'].get('other', 0)}")
    lines.append(f"  fixtures_with_deny  = {out['summary']['fixtures_with_deny']}")
    txt_path.write_text("\n".join(lines) + "\n")

    print(f"\nSUMMARY: cells={out['summary']['total_cells']} "
          f"allow={out['summary'].get('allow',0)} "
          f"deny={out['summary'].get('deny',0)} "
          f"ask={out['summary'].get('ask',0)} "
          f"other={out['summary'].get('other',0)} "
          f"fixtures_with_deny={out['summary']['fixtures_with_deny']}")
    print(f"wrote {json_path}")
    print(f"wrote {txt_path}")

    if args.strict and any_deny_overall:
        print("\n--strict: at least one DENY, exiting 1", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
