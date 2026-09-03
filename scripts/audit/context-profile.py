#!/usr/bin/env python3
"""Context-cost profile of Claude Code sessions from the local transcript logs.

Reads ~/.claude/projects/*/*.jsonl, deduplicates assistant messages by id, and
reports per model: request count, token split (uncached input, cache write,
cache read, output), context-per-request percentiles, and the share of cache
reads carried by requests above 200K/400K context. No network, no API key.

Usage:
    python3 scripts/audit/context-profile.py --days 30
    python3 scripts/audit/context-profile.py --since 2026-09-04 --models claude-opus,claude-fable

The 2026-09-03 baseline (30 days, Opus): p50 408K, p90 848K, 78% of requests
above 200K carrying 94% of cache-read tokens. Levers applied that day:
CLAUDE_AUTOCOMPACT_PCT_OVERRIDE 65 -> 25 and read-size-guard.sh (250 lines).
Expected effect on a run --since 2026-09-04: p50 below 250K.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import glob
import json
import os
import sys


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = p.add_mutually_exclusive_group()
    g.add_argument("--days", type=int, help="look back N days from now (UTC)")
    g.add_argument("--since", help="ISO date (YYYY-MM-DD, UTC) to start from")
    p.add_argument("--models", default="claude-",
                   help="comma-separated model-id prefixes to include (default: every claude- model)")
    p.add_argument("--projects-dir", default=os.path.expanduser("~/.claude/projects"))
    return p.parse_args()


def cutoff(args: argparse.Namespace) -> str:
    if args.since:
        return args.since
    days = args.days if args.days is not None else 30
    return (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days)).isoformat()


def percentile(sorted_values: list[int], q: float) -> int:
    if not sorted_values:
        return 0
    idx = min(len(sorted_values) - 1, int(len(sorted_values) * q))
    return sorted_values[idx]


def main() -> int:
    args = parse_args()
    since = cutoff(args)
    prefixes = tuple(m.strip() for m in args.models.split(",") if m.strip())
    per_model: dict[str, collections.Counter] = collections.defaultdict(collections.Counter)
    contexts: dict[str, list[tuple[int, int]]] = collections.defaultdict(list)
    seen: set[str] = set()
    files = glob.glob(os.path.join(args.projects_dir, "*", "*.jsonl"))
    if not files:
        print(f"FAIL: no transcript files under {args.projects_dir}", file=sys.stderr)
        return 1
    for path in files:
        try:
            fh = open(path, errors="ignore")
        except OSError:
            continue
        with fh:
            for line in fh:
                if '"usage"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not isinstance(d, dict) or d.get("type") != "assistant" or d.get("timestamp", "") < since:
                    continue
                m = d.get("message") or {}
                u = m.get("usage") or {}
                mid = m.get("id")
                if not u or not mid or mid in seen:
                    continue
                seen.add(mid)
                model = m.get("model") or ""
                if not model.startswith(prefixes):
                    continue
                inp = u.get("input_tokens") or 0
                cw = u.get("cache_creation_input_tokens") or 0
                cr = u.get("cache_read_input_tokens") or 0
                out = u.get("output_tokens") or 0
                c = per_model[model]
                c["req"] += 1
                c["in"] += inp
                c["cw"] += cw
                c["cr"] += cr
                c["out"] += out
                contexts[model].append((inp + cw + cr, cr))
    if not per_model:
        print(f"FAIL: zero matching requests since {since} for prefixes {prefixes}", file=sys.stderr)
        return 1
    print(f"window since {since}  models {prefixes}")
    print(f"{'model':26s} {'req':>6s} {'uncached':>10s} {'cache_w':>11s} {'cache_r':>13s} {'output':>10s} "
          f"{'p50':>8s} {'p90':>8s} {'p99':>8s} {'>200K':>6s} {'cr>200K':>8s} {'>400K':>6s}")
    for model, c in sorted(per_model.items(), key=lambda kv: -kv[1]["req"]):
        rows = contexts[model]
        cs = sorted(ctx for ctx, _ in rows)
        n = len(cs)
        total_cr = sum(cr for _, cr in rows) or 1
        over200 = [cr for ctx, cr in rows if ctx > 200_000]
        over400 = [cr for ctx, cr in rows if ctx > 400_000]
        print(f"{model[:26]:26s} {c['req']:6d} {c['in']:10d} {c['cw']:11d} {c['cr']:13d} {c['out']:10d} "
              f"{percentile(cs, .5)//1000:7d}K {percentile(cs, .9)//1000:7d}K {percentile(cs, .99)//1000:7d}K "
              f"{100*len(over200)//n:5d}% {100*sum(over200)//total_cr:7d}% {100*len(over400)//n:5d}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
