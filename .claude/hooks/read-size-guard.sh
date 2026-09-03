#!/usr/bin/env bash
umask 077
# read-size-guard.sh — Context-cost guard for unbounded Read calls
# Hook: PreToolUse (Read)
# VERSION: 3.2.0
#
# Why: over 30 days of session logs (2026-08/09), `Read` without `limit`
# injected 25 MB into context — 49% of all tool-result bytes — and every
# byte is re-read (cache read) on every later turn until compaction.
# Files above ~250 lines accounted for the bulk of it. Text hints
# (CLAUDE.md, context-mode tips) did not change the behaviour; a blocking
# guard does.
#
# Rule: a Read of a text file with more than READ_SIZE_GUARD_MAX_LINES
# lines (default 250) MUST carry `offset` or `limit`. Otherwise deny with
# a reason that names the line count and the three correct alternatives.
#
# Allowed without check: non-Read tools, missing/non-regular files (Read
# reports those itself), binary/media files (images, PDF, notebooks —
# rendered, not line-counted), and any call that already bounds the read.
#
# Override for one session:  READ_SIZE_GUARD_MAX_LINES=100000 claude

# SEC-111: stdin with 100KB limit
INPUT=$(head -c 100000)

set -euo pipefail

_emit_deny_on_crash() {
    trap - ERR EXIT
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "[read-size-guard] Guard crashed — failing closed. Re-run with READ_SIZE_GUARD_MAX_LINES=100000 to bypass while you inspect."}}'
}
trap '_emit_deny_on_crash' ERR EXIT

MAX_LINES="${READ_SIZE_GUARD_MAX_LINES:-250}"

allow() {
    trap - ERR EXIT
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
    exit 0
}

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
[[ "$TOOL_NAME" == "Read" ]] || allow

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ -n "$FILE_PATH" && -f "$FILE_PATH" ]] || allow

HAS_BOUND=$(printf '%s' "$INPUT" | jq -r '
    if (.tool_input.offset != null) or (.tool_input.limit != null) then "yes" else "no" end')
[[ "$HAS_BOUND" == "no" ]] || allow

case "${FILE_PATH,,}" in
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.bmp|*.svg|*.pdf|*.ipynb) allow ;;
esac

LINES=$(wc -l < "$FILE_PATH" | tr -d '[:space:]')
[[ "$LINES" =~ ^[0-9]+$ ]] || allow

if (( LINES <= MAX_LINES )); then
    allow
fi

trap - ERR EXIT
jq -cn --arg reason "[read-size-guard] ${FILE_PATH} has ${LINES} lines (> ${MAX_LINES}). Unbounded Read of large files is the #1 context-cost leak: every byte is re-read on every later turn. Use ONE of: (1) Read with offset+limit on the section you need, (2) Grep to locate the section first, (3) ctx_execute_file when you only need to analyse, not edit. Session override: READ_SIZE_GUARD_MAX_LINES=100000." \
    '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": $reason}}'
exit 0
