#!/usr/bin/env bash
# vault-graduation.sh — Promotes high-confidence vault learnings to .claude/learned-src/learned/
# Event: SessionStart (*)
# VERSION: 3.0.0
#
# Scans vault wiki articles for learnings with confidence >= 0.7 and >= 3 session confirmations.
# Promotes them to .claude/learned-src/learned/{category}.md (the T40 source tree).
# .claude/rules/** is auto-loaded per session: nothing may write there (T62 #73).
# The user sees changes in git diff at commit time.

set -euo pipefail
umask 077

# T81 — Daily gate (ralph periodic maintenance). If the graduation scan
# already ran today, exit early with a breadcrumb instead of forking a
# background scan that would just confirm what we already know.
source "$(dirname "${BASH_SOURCE[0]}")/lib/daily-gate.sh"
if ! daily_gate_check "vault-graduation"; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"vault-graduation: skipped (already ran today)"}}'
    exit 0
fi

# PERF v3.1.1: SessionStart maintenance — run detached so startup never blocks.
# The full-vault scan cost ~2s synchronously; now the hook returns in ~5ms and the
# scan/graduation runs in the background. Status JSON is dropped in background mode.
if [[ "${RALPH_HOOK_BG:-0}" != "1" ]]; then
    mkdir -p "${HOME}/.ralph/logs" 2>/dev/null || true
    RALPH_HOOK_BG=1 nohup bash "$0" </dev/null >>"${HOME}/.ralph/logs/vault-graduation.bg.log" 2>&1 &
    disown 2>/dev/null || true
    # Breadcrumb (codex review): keep a SessionStart context line even though the real
    # graduation status now goes to the bg log instead of being injected synchronously.
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"vault-graduation: maintenance running in background"}}'
    exit 0
fi

# Safety: always output valid JSON for SessionStart
trap 'echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": \"vault-graduation: error\"}}"' ERR INT TERM

VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
# T62 (#73): graduated learnings go to the SOURCE tree (.claude/learned-src/),
# NOT .claude/rules/learned — T40 moved that tree out of the auto-load
# path precisely so it stops being paid per-session; writing here again
# was silently undoing the ~9.7k-token saving on every graduation
# (observed live: hooks.md and security.md repopulated 12 minutes after
# the T40 merge).
RULES_DIR="${REPO_ROOT}/.claude/learned-src/learned"

# Skip if vault doesn't exist
if [[ ! -d "$VAULT_DIR/global/wiki" ]]; then
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "vault-graduation: no vault found, skipping"}}'
    exit 0
fi

GRADUATED=0

# FIX: Use process substitution instead of pipe to avoid subshell variable scoping bug.
# With `find | while`, the while loop runs in a subshell and GRADUATED increments are lost.
# With `while ... done < <(find ...)`, the loop runs in the current shell.
while IFS= read -r article; do
    # Extract frontmatter — sanitize to prevent injection via crafted YAML values
    confidence=$(sed -n 's/^confidence: *//p' "$article" 2>/dev/null | head -1 | tr -cd '0-9.')
    sessions=$(sed -n 's/^sessions_confirmed: *//p' "$article" 2>/dev/null | head -1 | tr -cd '0-9')
    category=$(sed -n 's/^category: *//p' "$article" 2>/dev/null | head -1 | tr -cd 'a-zA-Z0-9_-')

    # Validate extracted values are non-empty and sane
    [[ -z "$confidence" || -z "$sessions" || -z "$category" ]] && continue
    [[ ${#category} -gt 64 ]] && continue

    # Use awk for float comparison
    eligible=$(awk "BEGIN {print ($confidence >= 0.7 && $sessions >= 3) ? 1 : 0}" 2>/dev/null)

    if [[ "$eligible" == "1" ]]; then
        RULES_FILE="$REPO_ROOT/$RULES_DIR/$category.md"

        # Extract rule title (strip markdown heading)
        title=$(grep "^# " "$article" 2>/dev/null | head -1 | sed 's/^# //')
        [[ -z "$title" ]] && continue

        # Dedup by SOURCE (vault article path), not by title. T40-extra:
        # the previous check used $title, which was too lenient when two
        # articles shared a title (canonical case: learned/hooks.md had
        # the same bullet twice because re-graduation passed the title
        # check). Each vault article has a unique path; matching on
        # $article catches re-graduations while letting two distinct
        # articles with similar titles through.
        if [[ -f "$RULES_FILE" ]] && grep -qF "$article" "$RULES_FILE" 2>/dev/null; then
            continue
        fi

        # Ensure rules directory exists
        mkdir -p "$RULES_DIR" 2>/dev/null || true

        # Append to category rules file
        {
            echo ""
            echo "- $title (confidence: $confidence, sessions: $sessions, source: $article)"
        } >> "$RULES_FILE" 2>/dev/null || true

        GRADUATED=$((GRADUATED + 1))
    fi
done < <(find "$VAULT_DIR/global/wiki" -name "*.md" -type f 2>/dev/null)

# Also scan project-specific wiki articles for cross-project graduation
if [[ -d "$VAULT_DIR/projects" ]]; then
    while IFS= read -r article; do
        confidence=$(sed -n 's/^confidence: *//p' "$article" 2>/dev/null | head -1 | tr -cd '0-9.')
        sessions=$(sed -n 's/^sessions_confirmed: *//p' "$article" 2>/dev/null | head -1 | tr -cd '0-9')
        category=$(sed -n 's/^category: *//p' "$article" 2>/dev/null | head -1 | tr -cd 'a-zA-Z0-9_-')
        classification=$(sed -n 's/^classification: *//p' "$article" 2>/dev/null | head -1 | tr -cd 'A-Z')

        [[ -z "$confidence" || -z "$sessions" || -z "$category" ]] && continue
        [[ ${#category} -gt 64 ]] && continue

        # Only graduate GREEN (universal) project learnings, not YELLOW (project-specific)
        [[ "$classification" != "GREEN" ]] && continue

        eligible=$(awk "BEGIN {print ($confidence >= 0.7 && $sessions >= 3) ? 1 : 0}" 2>/dev/null)

        if [[ "$eligible" == "1" ]]; then
            RULES_FILE="$REPO_ROOT/$RULES_DIR/$category.md"
            title=$(grep "^# " "$article" 2>/dev/null | head -1 | sed 's/^# //')
            [[ -z "$title" ]] && continue

            # Dedup by SOURCE — see comment in the global/wiki loop above.
            if [[ -f "$RULES_FILE" ]] && grep -qF "$article" "$RULES_FILE" 2>/dev/null; then
                continue
            fi

            mkdir -p "$RULES_DIR" 2>/dev/null || true
            {
                echo ""
                echo "- $title (confidence: $confidence, sessions: $sessions, source: $article)"
            } >> "$RULES_FILE" 2>/dev/null || true

            GRADUATED=$((GRADUATED + 1))
        fi
    done < <(find "$VAULT_DIR/projects" -path "*/wiki/*.md" -type f 2>/dev/null)
fi

if [[ "$GRADUATED" -gt 0 ]]; then
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": \"vault-graduation: promoted $GRADUATED learnings to rules\"}}"
else
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "vault-graduation: no learnings ready for graduation"}}'
fi
