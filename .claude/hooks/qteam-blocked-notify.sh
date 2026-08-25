#!/usr/bin/env bash
umask 077
# qteam-blocked-notify.sh — record which pane (worker or lead) is blocked.
# Hook: Notification
# VERSION: 2.1.0
#
# Why this exists (issue #66): while a permission prompt is pending, the
# MODEL IS FROZEN — it cannot run any tool, SendMessage included. It is
# not declining to report; it has no turn in which to report. So the
# notice has to come from outside the model's turn, which means a hook.
#
# v2.0.0 (T32) — the lead's pane is no longer excluded. v1.0.0's
# comment claimed "the lead's own prompts are in front of whoever is
# already reading this session" — that premise is false when the user
# is not at the keyboard. A guard blocked the lead and the user got
# nothing, which prompted the explicit fix: every pane that can be
# blocked gets a drop-box line. The second column now records the
# origin: a worker name for a worker pane, the literal "lead" for
# the lead's pane.
#
# v2.1.0 (T32 hold) — DROP-BOX ONLY, no transport emit. Claude Code
# already notifies the user on permission prompts via
# `inputNeededNotifEnabled` and `agentPushNotifEnabled` in
# ~/.claude/settings.json. That native notification was previously
# hidden by tmux's allow-passthrough being set to `on`; setting it
# to `all` (today, 2026-08-25) released all the queued notifications
# in one burst. The first transport attempt (osascript display
# notification in v1.0.0 / v2.0.0) and the second (WIP OSC 777 via
# the pane's TTY, never committed) would each have produced a
# SECOND notification on top of the native one — the user has
# explicitly complained about getting notices that don't look real.
# The hook is now a pure triager: every blocked pane writes one
# line to the drop-box; the lead reads it, decides which block is
# a real decision versus a guard defect, and acts on it. Adding
# a notification emit here is a future decision the user has
# reserved for themselves.
#
# Drop-box format: <ts> <origin> <message>
#   - ts: ISO-8601 UTC timestamp
#   - origin: worker name, or "lead" for the lead's pane
#   - message: the prompt message from the harness (or default)
# (3 columns by design: no transport column when there is only one
# transport in use. The schema grows when there is something to
# discriminate, not in advance.)
#
# This hook NEVER answers the prompt and carries no mechanism that
# could. The harness is asking the human in that pane; if the hook
# could approve from anywhere, three permission boundaries would
# collapse into one. All this does is make the wait triable.

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

# Worker or lead? Workers live under .claude/worktrees/<name>; the
# lead's cwd is the main checkout. Both can be blocked; both need
# the lead to know which one.
case "$CWD" in
    */.claude/worktrees/*)
        KIND="worker"
        # .../.claude/worktrees/<name>[/...] -> <name>
        ORIGIN="${CWD##*/.claude/worktrees/}"
        ORIGIN="${ORIGIN%%/*}"
        [[ -n "$ORIGIN" ]] || ORIGIN="unknown"
        ;;
    *)
        KIND="lead"
        ORIGIN="lead"
        ;;
esac

# Drop-box for triage. Three fields by design: a column that always
# has the same value is noise, not data. If a future version adds
# a second transport (e.g. an OSC emit), a column returns then.
DROP_DIR="${HOME}/.ralph/blocked"
mkdir -p "$DROP_DIR" 2>/dev/null || true
if [[ -d "$DROP_DIR" ]]; then
    printf '%s\t%s\t%s\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        "$ORIGIN" \
        "${MESSAGE:-<no message>}" \
        >> "$DROP_DIR/pending.tsv" 2>/dev/null || true
fi

emit_and_exit
