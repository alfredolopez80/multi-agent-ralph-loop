#!/usr/bin/env bash
umask 077
# qteam-blocked-notify.sh — surface a worker stopped on a permission prompt.
# Hook: Notification
# VERSION: 1.0.0
#
# Why this exists (issue #66): while a permission prompt is pending, the
# worker's MODEL IS FROZEN — it cannot run any tool, SendMessage included.
# It is not declining to report; it has no turn in which to report. So the
# notice has to come from outside the model's turn, which means a hook.
#
# Measured before this existed: a worker sat 30 minutes waiting for approval
# on a read-only `grep`, and it surfaced only because a human mentioned it in
# passing. The only detection the lead had was inspecting the transcript for a
# `tool_use` with no matching `tool_result`.
#
# Transport: `osascript`, not a terminal escape sequence. Both OSC 9 and OSC
# 777 were tested through tmux with `allow-passthrough on` and neither
# arrived; `osascript` did. It also does not care which pane is focused, and
# the message content is ours to shape — which the escalation format needs.
#
# This hook NEVER answers the prompt and carries no mechanism that could.
# The harness is asking the human in that pane; if the lead could approve from
# another, three permission boundaries would collapse into one. All this does
# is make the wait visible.

set -uo pipefail

INPUT=$(head -c 100000)

# Never let a notification failure interfere with the session it reports on.
emit_and_exit() {
    echo '{"continue": true}'
    exit 0
}
trap emit_and_exit ERR

command -v jq >/dev/null 2>&1 || emit_and_exit

MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // empty' 2>/dev/null)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

# Only worker panes are of interest: the lead's own prompts are in front of
# whoever is already reading this session.
case "$CWD" in
    */.claude/worktrees/*) ;;
    *) emit_and_exit ;;
esac

# .../.claude/worktrees/<name>[/...] -> <name>
WORKER="${CWD##*/.claude/worktrees/}"
WORKER="${WORKER%%/*}"
[[ -n "$WORKER" ]] || WORKER="unknown"

# Keep it inside a desktop notification: title, one line, no report.
BODY="${MESSAGE:-waiting for approval}"
[[ ${#BODY} -gt 120 ]] && BODY="${BODY:0:117}..."

# Quote for AppleScript: backslashes first, then double quotes.
as_quote() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$(as_quote "$BODY")\" \
        with title \"Q-team: $(as_quote "$WORKER") is blocked\" \
        subtitle \"answer in its pane — the lead cannot\" \
        sound name \"Ping\"" >/dev/null 2>&1 || true
fi

# Drop-box for the lead. The worker cannot message while frozen; this hook
# can write. The lead reads it, triages, and decides whether the human is
# needed at all — most blocks so far have been guard defects, not decisions.
DROP_DIR="${HOME}/.ralph/blocked"
mkdir -p "$DROP_DIR" 2>/dev/null || true
if [[ -d "$DROP_DIR" ]]; then
    printf '%s\t%s\t%s\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        "$WORKER" \
        "${MESSAGE:-<no message>}" \
        >> "$DROP_DIR/pending.tsv" 2>/dev/null || true
fi

emit_and_exit
