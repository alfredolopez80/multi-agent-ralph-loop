#!/usr/bin/env python3
"""Permanent hot-path probe (T93 M1, #48 Phase 3 prereq).

Measures the synchronous cost of hot-path mechanisms for an ordinary
Claude Code session: per-mechanism wall time (N>=10, median + p90 + max)
plus tiktoken cl100k_base token count of stdout. NO mutation of any hook
or settings — observation only.

Why this exists as a permanent script (not a results/ artifact):
  #48 Phase 3 retires mechanisms from the hot path "unless measured
  evidence proves material benefit". The before/after comparison MUST
  use the same instrument — a one-shot probe in results/ breaks
  comparability (two different artifacts measuring "hot path" with
  different N, different payloads, different metrics is not a
  comparison, it's two independent measurements).

Run:

  # one-time setup (idempotent; PEP 668 compliant — venv lives next to
  # the script and is gitignored via scripts/benchmark/.venv/)
  scripts/benchmark/hotpath_probe.py --setup

  # the measurement itself
  scripts/benchmark/hotpath_probe.py            # writes:
                                               #   results/hotpath-probe.json
                                               #   results/hotpath-probe.txt
  scripts/benchmark/hotpath_probe.py --out /tmp # custom output dir

  # convenience: dry-run on the 9-metric BASELINE_A comparison
  scripts/benchmark/hotpath_probe.py --variant-a  # use the security-only
                                                  # profile as the variant

Environment:
  HOME is redirected to a probe-local directory (scripts/benchmark/.probe-home/)
  so writes do not touch the real ~/.ralph / ~/.claude. The probe creates
  the directory on first run and never deletes it (debugging).

Tokens:
  Uses tiktoken cl100k_base (the repo rule on token measurement forbids
  wc-w/0.75 — see feedback_demand_before_after_measurement.md). If
  tiktoken is not importable, --setup creates the venv. There is no
  tokenizer fallback: tokens reported as -1 means "could not measure",
  not an estimate.

Why stdlib + tiktoken (no other deps): the probe must be reproducible
on any machine with Python 3.10+ and `python3 -m venv`. No global pip
install (PEP 668). No virtualenv-tooling beyond stdlib.

Output schema (results/hotpath-probe.json):

  [
    {
      "label": "permission-guard",
      "plane": "security",
      "event": "PreToolUse",
      "hook": "permission-guard.sh",
      "note": "PreToolUse:Bash,E|W,A|T (manifest control)",
      "status": "OK" | "TIMEOUT_n/N" | "HOOK_NOT_FOUND",
      "n": 12,
      "min_ms": ..., "median_ms": ..., "p90_ms": ..., "max_ms": ..., "mean_ms": ...,
      "stdout_tokens_min/median/max": ...
    },
    ...
  ]

The companion `results/hotpath-probe.txt` is the same data as a
markdown table for embedding into docs/benchmark/.

Pre-registered thresholds for #48 Phase 3 live in
docs/benchmark/PLAN_CERT_METRICS.md — the probe's job is to produce
comparable numbers, not to evaluate the thresholds.
"""
import argparse
import json
import os
import statistics
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent  # scripts/benchmark/X -> repo root
HOOKS = REPO / ".claude" / "hooks"
BENCH_DIR = Path(__file__).resolve().parent
VENV = BENCH_DIR / ".venv"
RUNNER = VENV / "bin" / "python"
PROBE_HOME = BENCH_DIR / ".probe-home"
TRANSCRIPT = "/tmp/hotpath-probe/transcript.jsonl"

DEFAULT_RUNS = 12
DEFAULT_TIMEOUT_S = 15


def payload(event: str) -> str:
    """Synthetic JSON payload matching the hook event shape."""
    base = {
        "session_id": "hotpath-probe",
        "transcript_path": TRANSCRIPT,
        "cwd": str(REPO),
    }
    if event == "PreToolUse":
        return json.dumps({**base, "hook_event_name": "PreToolUse",
                           "tool_name": "Bash",
                           "tool_input": {"command": "echo hello"}})
    if event == "PostToolUse":
        return json.dumps({**base, "hook_event_name": "PostToolUse",
                           "tool_name": "Bash",
                           "tool_input": {"command": "echo hello"},
                           "tool_response": {"stdout": "hello\n", "stderr": "",
                                             "interrupted": False}})
    if event == "UserPromptSubmit":
        return json.dumps({**base, "hook_event_name": "UserPromptSubmit",
                           "prompt": "run the tests"})
    if event == "Stop":
        return json.dumps({**base, "hook_event_name": "Stop",
                           "stop_hook_active": False})
    if event == "PreCompact":
        return json.dumps({**base, "hook_event_name": "PreCompact",
                           "trigger": "auto", "custom_instructions": ""})
    if event == "SessionStart":
        return json.dumps({**base, "hook_event_name": "SessionStart",
                           "source": "startup"})
    if event == "SessionStart:compact":
        return json.dumps({**base, "hook_event_name": "SessionStart",
                           "source": "compact"})
    if event == "SessionEnd":
        return json.dumps({**base, "hook_event_name": "SessionEnd",
                           "reason": "exit"})
    raise ValueError(event)


# (event, hook_basename, label, plane, note)
TARGETS = [
    # --- lead's named mechanisms (T93 M1 mapping) ---------------------------
    ("PreCompact",         "aristotle-analysis-display.sh", "aristotle-analysis-display", "aristotle",    "PreCompact:*; fires on compaction"),
    ("PreCompact",         "pre-compact-handoff.sh",        "pre-compact-handoff",        "lifecycle",    "PreCompact:*"),
    ("SessionStart:compact","post-compact-restore.sh",       "post-compact-restore",       "lifecycle",    "SessionStart:compact"),
    ("SessionEnd",         "session-end-handoff.sh",        "session-end-handoff",        "lifecycle",    "SessionEnd:*"),
    ("PreToolUse",         "orchestrator-auto-learn.sh",    "orchestrator-auto-learn",    "memory",       "PreToolUse:A|T only; 0ms in plain Bash/Edit"),
    # --- hot-path PostToolUse chain -----------------------------------------
    ("PostToolUse",        "audit-secrets.js",              "audit-secrets",              "security-adjacent", "PostToolUse:*"),
    ("PostToolUse",        "vault-fact-extractor.sh",       "vault-fact-extractor",       "memory",       "PostToolUse:E|W|B"),
    ("PostToolUse",        "plan-sync-post-step.sh",        "plan-sync-post-step",        "orchestration","PostToolUse:E|W|B"),
    ("PostToolUse",        "progress-tracker.sh",           "progress-tracker",           "orchestration","PostToolUse:E|W|B"),
    ("PostToolUse",        "status-auto-check.sh",          "status-auto-check",          "orchestration","PostToolUse:E|W|B"),
    ("PostToolUse",        "console-log-detector.sh",       "console-log-detector",       "orchestration","PostToolUse:E|W|B"),
    ("PostToolUse",        "ai-code-audit.sh",              "ai-code-audit",              "orchestration","PostToolUse:E|W|B"),
    ("PostToolUse",        "auto-format-prettier.sh",       "auto-format-prettier",       "orchestration","PostToolUse:E|W|B"),
    ("PostToolUse",        "session-accumulator.sh",        "session-accumulator",        "memory",       "PostToolUse:E|W|B"),
    # --- hot-path PreToolUse chain ------------------------------------------
    ("PreToolUse",         "universal-aristotle-gate.sh",   "universal-aristotle-gate",   "aristotle",    "PreToolUse:*"),
    ("PreToolUse",         "git-safety-guard.py",           "git-safety-guard",           "security",     "PreToolUse:Bash"),
    ("PreToolUse",         "permission-guard.sh",           "permission-guard",           "security",     "PreToolUse:Bash,E|W,A|T (manifest control)"),
    ("PreToolUse",         "repo-boundary-guard.sh",        "repo-boundary-guard",        "security",     "PreToolUse:Bash,E|W,A|T"),
    ("PreToolUse",         "k8s-context-guard-v2.py",       "k8s-context-guard",          "security",     "PreToolUse:Bash; skips fast when no kubectl"),
]


def setup_venv() -> None:
    """Create scripts/benchmark/.venv and install tiktoken (idempotent)."""
    import venv  # noqa: F401  (ensure available)
    if VENV.exists() and (VENV / "bin" / "python").exists():
        # verify tiktoken importable; install if not
        try:
            subprocess.check_call([str(RUNNER), "-c", "import tiktoken"],
                                  stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)
            print(f"venv already ready: {VENV}")
            return
        except subprocess.CalledProcessError:
            pass  # need to install
    print(f"creating venv at {VENV} ...")
    subprocess.check_call([sys.executable, "-m", "venv", str(VENV)])
    print("installing tiktoken ...")
    subprocess.check_call([str(RUNNER), "-m", "pip", "install", "--quiet",
                          "tiktoken"])
    print("setup complete.")


def get_tiktoken():
    """Re-exec self under the venv python if tiktoken missing (lazy setup).

    Two cases:
      - venv does not exist -> create it, install tiktoken, re-exec self.
      - venv exists but tiktoken still missing (PEP 668: system python
        has no tiktoken, only the venv does) -> re-exec self directly.
    """
    try:
        import tiktoken as _t
        return _t.get_encoding("cl100k_base")
    except ImportError:
        if not VENV.exists():
            setup_venv()
        os.execv(str(RUNNER), [str(RUNNER), __file__, *sys.argv[1:]])


def run_once(hook: Path, stdin_payload: str, home: Path, enc):
    env = dict(os.environ)
    env["HOME"] = str(home)
    start = time.perf_counter()
    try:
        p = subprocess.run(
            ["bash", str(hook)],
            input=stdin_payload.encode(),
            capture_output=True,
            env=env,
            timeout=DEFAULT_TIMEOUT_S,
            cwd=str(REPO),
        )
        elapsed = time.perf_counter() - start
        stdout = p.stdout.decode(errors="replace")
        return {
            "elapsed_s": elapsed,
            "exit": p.returncode,
            "stdout_bytes": len(p.stdout),
            "stdout_tokens": len(enc.encode(stdout)),
        }
    except subprocess.TimeoutExpired:
        return {"elapsed_s": float(DEFAULT_TIMEOUT_S), "exit": -1,
                "stdout_bytes": 0, "stdout_tokens": 0, "TIMEOUT": True}


def measure(out_dir: Path, runs: int):
    enc = get_tiktoken()
    PROBE_HOME.mkdir(parents=True, exist_ok=True)
    (PROBE_HOME / ".ralph").mkdir(exist_ok=True)
    (PROBE_HOME / ".claude").mkdir(exist_ok=True)
    rows = []
    for event, basename, label, plane, note in TARGETS:
        hook = HOOKS / basename
        if not hook.exists():
            rows.append({"label": label, "plane": plane, "event": event,
                         "hook": basename, "status": "HOOK_NOT_FOUND"})
            continue
        run_data = [run_once(hook, payload(event), PROBE_HOME, enc)
                    for _ in range(runs)]
        times = sorted(r["elapsed_s"] for r in run_data)
        tokens = [r["stdout_tokens"] for r in run_data]
        bytes_out = [r["stdout_bytes"] for r in run_data]
        timeouts = sum(1 for r in run_data if r.get("TIMEOUT"))
        rows.append({
            "label": label, "plane": plane, "event": event,
            "hook": basename, "note": note,
            "status": "OK" if not timeouts else f"TIMEOUT_{timeouts}/{runs}",
            "n": runs, "n_timeout": timeouts,
            "min_ms": times[0] * 1000,
            "median_ms": statistics.median(times) * 1000,
            "p90_ms": times[int(0.9 * (runs - 1))] * 1000,
            "max_ms": times[-1] * 1000,
            "mean_ms": statistics.mean(times) * 1000,
            "stdout_bytes_min": min(bytes_out),
            "stdout_bytes_max": max(bytes_out),
            "stdout_tokens_min": min(tokens),
            "stdout_tokens_median": statistics.median(tokens),
            "stdout_tokens_max": max(tokens),
        })
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "hotpath-probe.json"
    txt_path = out_dir / "hotpath-probe.txt"
    json_path.write_text(json.dumps(rows, indent=2))
    lines = ["| Hook | Plane | Event | N | median ms | p90 ms | max ms | stdout tok (med) | status |",
             "|---|---|---|---:|---:|---:|---:|---:|---|"]
    for r in rows:
        if r["status"] != "OK":
            lines.append(f"| {r['label']} | {r['plane']} | {r['event']} | - | - | - | - | - | {r['status']} |")
            continue
        lines.append(
            f"| {r['label']} | {r['plane']} | {r['event']} | {r['n']} | "
            f"{r['median_ms']:.1f} | {r['p90_ms']:.1f} | {r['max_ms']:.1f} | "
            f"{int(r['stdout_tokens_median'])} | {r['status']} |"
        )
    txt_path.write_text("\n".join(lines) + "\n")
    return json_path, txt_path


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--setup", action="store_true",
                    help="create scripts/benchmark/.venv and install tiktoken")
    ap.add_argument("--runs", type=int, default=DEFAULT_RUNS,
                    help=f"runs per row (default {DEFAULT_RUNS})")
    ap.add_argument("--out", type=Path,
                    default=REPO / "results",
                    help="output directory for hotpath-probe.{json,txt}")
    args = ap.parse_args()

    if args.setup:
        setup_venv()
        return

    json_path, txt_path = measure(args.out, args.runs)
    print(f"wrote {json_path}")
    print(f"wrote {txt_path}")


if __name__ == "__main__":
    main()
