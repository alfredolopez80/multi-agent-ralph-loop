#!/usr/bin/env bash
# hook-logger.sh — PreToolUse probe for the MCP-surface experiment (PR3-C3a).
# Appends every event it receives to $MCP_SURFACE_LOG (JSONL), then allows the
# tool call by silence (no stdout output, exit 0).
# Fail loud if the log path is missing: evidence without a destination is lost.
umask 077
if [ -z "${MCP_SURFACE_LOG:-}" ]; then
  echo "MCP_SURFACE_LOG is required (the runner sets it)" >&2
  exit 1
fi
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stdin_data="$(cat)"
printf '{"ts":"%s","event":%s}\n' "$ts" "$stdin_data" >> "$MCP_SURFACE_LOG"
exit 0
