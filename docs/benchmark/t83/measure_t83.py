#!/usr/bin/env python3
"""
T83 — rigorous measurement (v2: fixed sin_gate replication).

Pre-T81 hooks are extracted with `git show <sha>:.claude/hooks/X.sh` (read-only,
no working-tree change). Today-version hooks run from the live path. Gate-only
uses the live library at WORKTREE/.claude/hooks/lib/daily-gate.sh.

No `| tail` / `| head` / `| grep`. Median primary; min/max/mean/sd auxiliary.
"""

from __future__ import annotations

import json
import os
import statistics
import subprocess
import sys
import time
from pathlib import Path

WORKTREE = Path(
    "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/worktrees/mmx"
)
HOOKS_DIR = WORKTREE / ".claude" / "hooks"
LIB_PATH = HOOKS_DIR / "lib" / "daily-gate.sh"
MARKERS_DIR = Path.home() / ".ralph" / "markers"
TMPDIR = WORKTREE / "results" / "_tmp_t83"
TMPDIR.mkdir(parents=True, exist_ok=True)
TODAY_SHA = "91939d8"  # last commit BEFORE T81 (T75 commit, hook files unchanged since)

N = int(os.environ.get("T83_N", "10"))
WARMUP = 3

# Per-hook pre-T81 SHA: last commit that touched the hook BEFORE 76d5a59 (T81).
# These are the SHAs whose blobs are guaranteed to NOT contain the T81 daily-gate.
PRE_T81_SHA = {
    "vault-graduation.sh":       "057c6ca",  # zc: graduation writes to learned-src
    "vault-promotion.sh":        "fde9ec8",  # bash 3.2 silent corruption
    "auto-sync-global.sh":       "720bf46",  # codex review follow-ups
    "project-backup-metadata.sh":"523257b",  # stop format guards
}

HOOKS = list(PRE_T81_SHA.keys())


def git_show_pre_t81(hook_name: str) -> str:
    """Read the pre-T81 version of a hook from git without touching the worktree.

    Asserts (per lead's mandate): the blob extracted from the pre-T81 SHA MUST
    NOT contain 'daily-gate' AND MUST be shorter than the current live hook.
    Both conditions fail loudly if violated — a silent fallback here would
    measure something the script claims it isn't, exactly the failure mode lead
    warned about.
    """
    sha = PRE_T81_SHA[hook_name]
    blob = subprocess.check_output(
        ["git", "show", f"{sha}:.claude/hooks/{hook_name}"],
        cwd=str(WORKTREE),
        text=True,
    )
    live = (HOOKS_DIR / hook_name).read_text()
    blob_lines = blob.splitlines()
    live_lines = live.splitlines()

    if "daily-gate" in blob:
        sys.stderr.write(
            f"FATAL: pre-T81 blob of {hook_name} (sha {sha}) contains "
            f"'daily-gate'. The SHA is wrong; abort.\n"
        )
        sys.exit(2)

    if len(blob_lines) >= len(live_lines):
        sys.stderr.write(
            f"FATAL: pre-T81 blob of {hook_name} (sha {sha}) is {len(blob_lines)} "
            f"lines, NOT shorter than the live hook ({len(live_lines)} lines). "
            f"The SHA selection is wrong; abort.\n"
        )
        sys.exit(2)

    print(
        f"  pre-T81 verification OK for {hook_name}: "
        f"sha={sha[:7]}, lines={len(blob_lines)}<{len(live_lines)}, "
        f"no 'daily-gate' substring"
    )
    return blob


def write_sin_gate_script(hook_name: str) -> Path:
    """Extract pre-T81 hook text and write it to tmp."""
    src = git_show_pre_t81(hook_name)
    tmp = TMPDIR / f"sin-gate-{hook_name}"
    tmp.write_text(src)
    tmp.chmod(0o755)
    return tmp


def write_gate_only_script(hook_basename: str) -> Path:
    """Write a script that runs ONLY the gate path, no hook body."""
    body = (
        "#!/bin/bash\n"
        f'source "{LIB_PATH}"\n'
        f'if ! daily_gate_check "{hook_basename}"; then\n'
        f"    exit 0\n"
        f"fi\n"
        f"exit 0\n"
    )
    tmp = TMPDIR / f"gate-only-{hook_basename}.sh"
    tmp.write_text(body)
    tmp.chmod(0o755)
    return tmp


def set_marker(hook_basename: str, present: bool) -> None:
    MARKERS_DIR.mkdir(parents=True, exist_ok=True)
    marker = MARKERS_DIR / f"daily-gate-{hook_basename}-{time.strftime('%Y%m%d', time.gmtime())}"
    if present:
        marker.touch()
    else:
        marker.unlink(missing_ok=True)


def run_script(path: Path, extra_args: tuple = ()) -> float:
    args = ["bash", str(path), *extra_args]
    start = time.perf_counter()
    subprocess.run(
        args,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
        timeout=60,
    )
    return time.perf_counter() - start


def run_bash_c(cmd: str) -> float:
    start = time.perf_counter()
    subprocess.run(
        ["bash", "-c", cmd],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
        timeout=30,
    )
    return time.perf_counter() - start


def measure(samples: int, runner) -> list[float]:
    for _ in range(WARMUP):
        runner()
    return [runner() for _ in range(samples)]


def stats(samples: list[float]) -> dict[str, float]:
    ms = [s * 1000.0 for s in samples]
    return {
        "n": len(ms),
        "mean_ms": round(statistics.mean(ms), 2),
        "median_ms": round(statistics.median(ms), 2),
        "min_ms": round(min(ms), 2),
        "max_ms": round(max(ms), 2),
        "sd_ms": round(statistics.pstdev(ms), 2),
    }


def measure_control() -> dict:
    samples = measure(N, lambda: run_bash_c("true"))
    return stats(samples)


def measure_hook(hook_name: str) -> dict:
    hook_path = HOOKS_DIR / hook_name
    hook_basename = hook_name.removesuffix(".sh")
    extra = ("SessionStart",) if hook_name == "project-backup-metadata.sh" else ()

    sin_gate_script = write_sin_gate_script(hook_name)
    gate_only_script = write_gate_only_script(hook_basename)
    states = {}

    # sin_gate: pre-T81 hook extracted from git. No source lib, no check.
    set_marker(hook_basename, False)
    states["sin_gate"] = stats(measure(N, lambda: run_script(sin_gate_script, extra)))

    # con_gate_open: today's hook, marker absent.
    set_marker(hook_basename, False)
    states["con_gate_open"] = stats(measure(N, lambda: run_script(hook_path, extra)))

    # con_gate_skip: today's hook, marker present.
    set_marker(hook_basename, True)
    states["con_gate_skip"] = stats(measure(N, lambda: run_script(hook_path, extra)))

    # gate_only: only source lib + check + skip + exit (no hook body).
    set_marker(hook_basename, True)
    states["gate_only"] = stats(measure(N, lambda: run_script(gate_only_script)))

    return states


def main() -> int:
    print(f"T83 v2 daily-gate measurement: N={N}, WARMUP={WARMUP}")
    print(f"Today (UTC): {time.strftime('%Y%m%d', time.gmtime())}")
    print(f"Pre-T81 SHA: {TODAY_SHA}")
    print(f"tmp dir: {TMPDIR}")
    print()

    results: dict = {}

    print("== control (bash -c true) ==")
    control = measure_control()
    print(f"  {control}")
    print()
    results["__control__"] = control

    for hook_name in HOOKS:
        print(f"== {hook_name} ==")
        s = measure_hook(hook_name)
        for state, v in s.items():
            print(f"  {state:<18s} {v}")
        results[hook_name] = s
        print()

    json_path = WORKTREE / "results" / "T83-measurements.json"
    json_path.write_text(json.dumps(results, indent=2, sort_keys=True))
    print(f"JSON saved: {json_path}")

    csv_path = WORKTREE / "results" / "T83-measurements.csv"
    with csv_path.open("w") as f:
        f.write("hook,state,n,mean_ms,median_ms,min_ms,max_ms,sd_ms\n")
        for k, v in results.items():
            if k == "__control__":
                f.write(
                    f"control,control,{v['n']},{v['mean_ms']},{v['median_ms']},"
                    f"{v['min_ms']},{v['max_ms']},{v['sd_ms']}\n"
                )
                continue
            for state, s in v.items():
                f.write(
                    f"{k},{state},{s['n']},{s['mean_ms']},{s['median_ms']},"
                    f"{s['min_ms']},{s['max_ms']},{s['sd_ms']}\n"
                )
    print(f"CSV saved:  {csv_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
