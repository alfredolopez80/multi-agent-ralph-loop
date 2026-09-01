#!/usr/bin/env python3
"""CLAUDE.md Scope-Budget Probe (PR10 C3, #69 Phase 4) — permanent, unregistered.

Question this probe answers:

  "Do the CLAUDE.md instruction scopes stay inside the per-scope <=1200-token
   budget (and Anthropic's <=200-line guidance), or has context crept back?"

Method:

  Measure each scope with tiktoken cl100k_base (the same encoder every other
  budget figure in this repo is measured with — wc -w lies under BPE):

    1. repo CLAUDE.md                 — in scope, gated
    2. ~/.claude/CLAUDE.md            — in scope, gated (when present)
    3. this project's native-memory
       MEMORY.md                      — INFORMATIONAL ONLY: its startup cost
                                        is governed by the D3/D4 policy
                                        (auto-memory disabled + archived), not
                                        by the <=1200 gate

  --gate N exits 1 when any GATED surface exceeds N — fail-loud, reason
  printed; a probe that cannot import tiktoken also exits 1 with the exact
  command to run it, never a silent pass.

This is a standalone probe, deliberately NOT registered in hooks or runtime
(#69 line 359): measuring is on-demand, paying on every session would be the
same net-negative the wake-up probes already ruled out.

Run:
  uv run --with tiktoken python3 scripts/benchmark/claude_md_tokens.py --gate 1200
"""
import argparse
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# This repo's native-memory index (informational surface). Kept as a literal
# tail so the probe works from any checkout of this project.
_MEMORY_DIR_TAIL = (
    "-Users-alfredolopez-Documents-GitHub-multi-agent-ralph-loop", "memory", "MEMORY.md"
)


def _measure(enc, text):
    return len(enc.encode(text)), text.count("\n") + 1


def main():
    parser = argparse.ArgumentParser(
        description="Measure CLAUDE.md scope budgets (tiktoken cl100k_base)."
    )
    parser.add_argument(
        "--gate", type=int, default=None, metavar="N",
        help="exit 1 when a gated CLAUDE.md surface exceeds N tokens",
    )
    args = parser.parse_args()

    try:
        import tiktoken
    except ImportError:
        print(
            "FAIL: tiktoken not importable — run via:\n"
            "  uv run --with tiktoken python3 scripts/benchmark/claude_md_tokens.py",
            file=sys.stderr,
        )
        return 1
    enc = tiktoken.get_encoding("cl100k_base")

    surfaces = []  # (name, text, gated)
    repo_md = REPO / "CLAUDE.md"
    if not repo_md.exists():
        print(f"FAIL: repo CLAUDE.md not found at {repo_md}", file=sys.stderr)
        return 1
    surfaces.append((str(repo_md), repo_md.read_text(errors="ignore"), True))

    global_md = Path.home() / ".claude" / "CLAUDE.md"
    if global_md.exists():
        surfaces.append((str(global_md), global_md.read_text(errors="ignore"), True))
    else:
        print(f"INFO: no global CLAUDE.md at {global_md} — skipped")

    memory_md = Path.home() / ".claude" / "projects" / Path(*_MEMORY_DIR_TAIL)
    if memory_md.exists():
        surfaces.append((f"{memory_md}  [informational, not gated]",
                         memory_md.read_text(errors="ignore"), False))
    else:
        print("INFO: native-memory MEMORY.md not present (D3/D4 landed or n/a)")

    print(f"{'surface':<78} {'tokens':>7} {'lines':>6}")
    over = []
    for name, text, gated in surfaces:
        tok, lines = _measure(enc, text)
        print(f"{name[:76]:<78} {tok:>7} {lines:>6}")
        if gated and lines > 200:
            print(f"NOTE: {name} exceeds the 200-line guidance ({lines} lines)")
        if gated and args.gate is not None and tok > args.gate:
            over.append((name, tok))

    if args.gate is not None:
        if over:
            for name, tok in over:
                print(f"FAIL: {name} = {tok} tokens EXCEEDS the gate of {args.gate}",
                      file=sys.stderr)
            return 1
        gated_count = sum(1 for _, _, gated in surfaces if gated)
        if gated_count == 0:
            print("FAIL: zero gated surfaces measured — nothing was asserted",
                  file=sys.stderr)
            return 1
        print(f"GATE PASS: all {gated_count} CLAUDE.md surface(s) <= {args.gate} tokens")
    return 0


if __name__ == "__main__":
    sys.exit(main())
