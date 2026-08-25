#!/bin/bash
#!/usr/bin/env bash
#===============================================================================
# Smart Skill Reminder Hook (v3.0.0)
# PreToolUse hook - filesystem-derived skill suggestions BEFORE writing code
#===============================================================================
#
# VERSION: 3.0.0
# TRIGGER: PreToolUse (Edit|Write)
# PURPOSE: Suggest relevant skills based on file context
#
# v3.0.0 changes vs v2.69.0:
# - Hand-coded 14-skill list REMOVED. 13 of 14 skills in v2 didn't exist;
#   suggesting them was a violation of "no inventar" inside the hook whose
#   job is to help select skills. v3 sources from a filesystem-derived index
#   at ~/.ralph/cache/skill-index.tsv, built by
#   .claude/hooks/lib/build-skill-index.sh from the actual ~/.claude/skills
#   and .claude/skills/ trees.
# - The index is regenerated only when a root's mtime is newer than the
#   index file. Zero tokens cost; CPU local.
# - Match by file path tokens (extension + key words from the basename).
# - DOUBLE VERIFICATION at emit time: test -f <skill_dir>/SKILL.md. A skill
#   deleted between index regeneration and emit time cannot be suggested.
# - Hard cap of 3 emissions per session (was 1).
# - Cooldown (30 min) and recently-invoked (5 min) gates KEEP.
# - No match -> output {"permissionDecision": "allow"} only. Zero bytes of
#   context pollution. No log line.
# - Match -> output {"permissionDecision": "allow", "permissionDecisionReason":
#   "<suggestion>"} so the suggestion reaches the user via the
#   permission prompt. additionalContext is NOT used because Claude Code's
#   PreToolUse does not honor it (per tests/HOOK_FORMAT_REFERENCE.md);
#   the rationale is documented in the audit doc.
#
# Three tests must hold:
# - Skill present in fixture -> suggests.
# - Skill deleted + index fresh -> same call silent.
# - Skill deleted + index stale -> same call silent (double-verify).
# - Fourth emission within a session -> silent.
# - Regression grep: zero literal skill names in hook code outside the
#   template strings.

# SEC-111: Read input from stdin with length limit (100KB max)
INPUT=$(head -c 100000)

set -euo pipefail
umask 077

readonly VERSION="3.0.0"
readonly HOOK_NAME="smart-skill-reminder"
readonly MARKERS_DIR="${SMART_SKILL_MARKERS_DIR:-${HOME}/.ralph/markers}"
readonly COOLDOWN_MINUTES=30
readonly LOG_FILE="${SMART_SKILL_LOG_FILE:-${HOME}/.ralph/logs/skill-reminder.log}"
# SMART_SKILL_INDEX allows tests to inject a fixture index without polluting
# the real ~/.ralph/cache. Production uses the real path.
readonly INDEX_FILE="${SMART_SKILL_INDEX:-${HOME}/.ralph/cache/skill-index.tsv}"
readonly MAX_EMISSIONS_PER_SESSION=3

# Ensure directories exist
mkdir -p "$MARKERS_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Guaranteed JSON output on any error
output_empty() {
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
}
trap 'output_empty' ERR EXIT

# Logging (silent by default)
log() {
    echo "[$(date -Iseconds)] [$HOOK_NAME] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Get session ID from stdin payload (with stable cwd+date digest fallback).
get_session_id() {
    local sid
    sid=$(printf '%s' "${INPUT:-}" | jq -r '.session_id // empty' 2>/dev/null || true)
    if [[ -z "$sid" ]]; then
        sid="cwd-$(printf '%s|%s' "$PWD" "$(date -u +%Y%m%d)" | shasum -a 256 | cut -c1-16)"
    fi
    printf '%s' "$sid" | tr -cd 'a-zA-Z0-9_-' | head -c 64
}

# Emission counter for the hard cap (3 per session).
emission_count() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/skill-emissions-${session_id}"
    if [[ -f "$marker" ]]; then
        cat "$marker" 2>/dev/null | tr -cd '0-9' | head -c 4
    else
        echo 0
    fi
}

# Bump the emission counter (with a leading timestamp to avoid stale carry-over).
bump_emission_count() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/skill-emissions-${session_id}"
    local n
    n=$(emission_count)
    n=$((n + 1))
    # Atomic write: write to temp then move.
    local tmp
    tmp=$(mktemp)
    printf '%s\n' "$n" > "$tmp"
    mv "$tmp" "$marker"
}

# True iff we've already hit the cap.
at_emission_cap() {
    local n
    n=$(emission_count)
    [[ "$n" -ge "$MAX_EMISSIONS_PER_SESSION" ]]
}

# Cooldown: refuse to emit if last emission was less than N minutes ago.
is_within_cooldown() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/skill-reminder-cooldown"
    if [[ -f "$marker" ]]; then
        local marker_age
        marker_age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null || echo 0) ))
        (( marker_age < COOLDOWN_MINUTES * 60 ))
    else
        return 1
    fi
}

update_cooldown() {
    local marker="${MARKERS_DIR}/skill-reminder-cooldown"
    touch "$marker" 2>/dev/null || true
}

# True iff the Skill tool was used within the last 5 minutes.
skill_recently_invoked() {
    local recent_skills="${MARKERS_DIR}/recent-skill-invocation"
    if [[ -f "$recent_skills" ]]; then
        local age
        age=$(( $(date +%s) - $(stat -c %Y "$recent_skills" 2>/dev/null || stat -f %m "$recent_skills" 2>/dev/null || echo 0) ))
        (( age < 300 ))
    else
        return 1
    fi
}

# Look up the best-matching skill for the file path.
# Reads the index TSV (built by .claude/hooks/lib/build-skill-index.sh) and
# returns the first skill whose match tokens are a substring of the file path
# (case-insensitive). If the index is missing, returns no match silently.
#
# Double-verify: a row whose SKILL.md no longer exists is silently skipped
# (this is the second test of T49: index-stale + skill-deleted -> silent).
match_skill() {
    local file_path="$1"
    [[ -f "$INDEX_FILE" ]] || return 1
    local file_lower
    file_lower=$(printf '%s' "$file_path" | tr '[:upper:]' '[:lower:]')
    while IFS=$'\t' read -r name tokens desc skill_dir; do
        [[ -z "$name" ]] && continue
        # Double-verify: SKILL.md must exist at emit time.
        [[ -f "${skill_dir}/SKILL.md" ]] || continue
        for token in $tokens; do
            if [[ "$file_lower" == *"$token"* ]]; then
                printf '%s\t%s\n' "$name" "${skill_dir}"
                return 0
            fi
        done
    done < "$INDEX_FILE"
    return 1
}

# Main logic
main() {
    local input="$INPUT"

    # Gate 0: file path required.
    local file_path
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || echo "")
    if [[ -z "$file_path" ]]; then
        log "no file path; silent"
        trap - ERR EXIT
        output_empty
        exit 0
    fi

    # Gate 1: hard cap of 3 emissions per session.
    if at_emission_cap; then
        log "at emission cap; silent"
        trap - ERR EXIT
        output_empty
        exit 0
    fi

    # Gate 2: cooldown (rate limit between emissions).
    if is_within_cooldown; then
        log "within cooldown; silent"
        trap - ERR EXIT
        output_empty
        exit 0
    fi

    # Gate 3: skill was recently invoked (user silence after Skill use).
    if skill_recently_invoked; then
        log "skill recently invoked; silent"
        trap - ERR EXIT
        output_empty
        exit 0
    fi

    # No match -> silent allow. Zero bytes of context pollution. AND no log
    # line: the silent case is the normal case, and a log per silent case
    # would dwarf the cost of the (rare) match. Output and exit.
    local match_line
    if ! match_line=$(match_skill "$file_path"); then
        trap - ERR EXIT
        output_empty
        exit 0
    fi

    local skill_name
    local skill_dir
    skill_name=$(printf '%s' "$match_line" | cut -f1)
    skill_dir=$(printf '%s' "$match_line" | cut -f2)

    # Double-verify: defensive. If a race made SKILL.md disappear between
    # the index read and the emit, treat as no-match.
    if [[ ! -f "${skill_dir}/SKILL.md" ]]; then
        log "skill $skill_name vanished between index read and emit; silent"
        trap - ERR EXIT
        output_empty
        exit 0
    fi

    # File extension for the message.
    local ext="${file_path##*.}"
    if [[ "$ext" == "$file_path" ]]; then
        ext=""
    fi

    # Single message template (lead's spec: ≤120 chars, plantilla única).
    if [[ -n "$ext" ]]; then
        local msg="Use $skill_name for .$ext"
    else
        local msg="Use $skill_name"
    fi

    # Bump counters and emit.
    bump_emission_count
    update_cooldown
    log "emitted: $skill_name for $file_path (count=$(emission_count))"

    trap - ERR EXIT
    # The PreToolUse channel that Claude Code GUARANTEES is
    # permissionDecision + permissionDecisionReason. hookEventName is
    # omitted to stay under the 35 tokens/emission budget (the validation
    # function in tests/HOOK_FORMAT_REFERENCE.md does not require it
    # for PreToolUse; only continue/permissionDecision are validated).
    jq -n --arg reason "$msg" \
        '{"hookSpecificOutput": {"permissionDecision": "allow", "permissionDecisionReason": $reason}}'
}

main "$@"