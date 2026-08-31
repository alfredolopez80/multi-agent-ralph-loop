#!/usr/bin/env bash
# run-experiment.sh — MCP PreToolUse surface experiment (PR3-C3a, gap mcp-egress).
#
# Proves, with raw evidence, whether the active harness exposes MCP tool calls
# to PreToolUse hooks (and whether the mcp__.* matcher targets them).
#
#   Run A: PreToolUse hook WITHOUT matcher  -> must capture BOTH the Bash
#          control probe AND the MCP call (positive control: if Bash is not
#          captured, the hook never loaded and the run proves nothing).
#   Run B: PreToolUse hook with "matcher": "mcp__.*" -> must capture ONLY the
#          MCP call (negative control: Bash and ToolSearch must be absent).
#
# NOT registered in tests/run-all-unit-tests.sh by design: every run launches a
# nested headless Claude session (minutes, network, auth) — not CI-eligible.
# This script is versioned EVIDENCE: the manifest's mcp-egress entry cites it.
#
# Usage:  bash scripts/experiments/mcp-surface/run-experiment.sh [A|B]
# Output: evidence under results/pr3-c3a-run/ (gitignored): settings used,
#         hook log (JSONL), nested session output.
set -uo pipefail

RUN="${1:-A}"
case "$RUN" in
  A) MATCHER="" ;;
  B) MATCHER="mcp__.*" ;;
  *) echo "usage: $0 [A|B]" >&2 ; exit 2 ;;
esac

SB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(git rev-parse --show-toplevel)" || { echo "FATAL: not in a git repo" >&2 ; exit 2 ; }
OUT_DIR="${MCP_SURFACE_OUT:-$ROOT/results/pr3-c3a-run}"
mkdir -p "$OUT_DIR"

HOOK="$SB/hook-logger.sh"
LOG="$OUT_DIR/hook-log-run$RUN.jsonl"
OUT="$OUT_DIR/run$RUN-output.txt"
SETTINGS="$OUT_DIR/settings-run$RUN.json"

# Generate the experiment settings at run time: the hook path is absolute and
# machine-specific, so it is never versioned.
python3 - "$SETTINGS" "$HOOK" "$MATCHER" <<'PY'
import json, sys
settings_path, hook, matcher = sys.argv[1], sys.argv[2], sys.argv[3]
entry = {"hooks": [{"type": "command", "command": f"bash {hook}"}]}
if matcher:
    entry = {"matcher": matcher, **entry}
json.dump({"hooks": {"PreToolUse": [entry]}}, open(settings_path, "w"), indent=2)
PY

export MCP_SURFACE_LOG="$LOG"
rm -f "$LOG"

(cd "$OUT_DIR" && claude --settings "$SETTINGS" -p "Do these three steps in order and nothing else: (1) Run this exact bash command: echo control-probe-ok. (2) Call the tool mcp__context7__resolve-library-id with argument query set to 'react'. (3) Reply with exactly: PROBES-DONE" --allowedTools "Bash" "mcp__context7__resolve-library-id" > "$OUT" 2>&1)
RC=$?

echo "RUN${RUN}_EXIT=$RC"
echo "--- nested session output (tail 3) ---"
tail -3 "$OUT"
echo "--- hook log ($LOG) ---"
if [ -f "$LOG" ]; then
  cat "$LOG"
else
  echo "FAIL: no hook log produced — the experiment captured no evidence" >&2
  exit 1
fi
