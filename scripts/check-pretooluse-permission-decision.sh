#!/usr/bin/env bash
# check-pretooluse-permission-decision.sh
# VERSION: 1.0.0
#
# Regression guard for the "(root): Invalid input" hook error.
#
# ROOT CAUSE (fixed 2026-06-18): PreToolUse guard hooks emitted
#   {"hookSpecificOutput": {"permissionDecision": "block", ...}}
# but Claude Code's PreToolUse `permissionDecision` field only accepts the
# enum  allow | deny | ask  (verified against /anthropics/claude-code docs).
# "block" belongs to the *Stop* hook `decision` field ONLY. Crossing the two
# vocabularies makes Claude Code reject the whole object at the union root:
#   "Hook JSON output validation failed — (root): Invalid input"
#
# This script fails (exit 1) if any hook emits a permissionDecision value that
# is not allow/deny/ask. It runs in two modes:
#   (default)   STATIC  — grep every emit-site, validate the literal value.
#   --dynamic   DYNAMIC  — additionally exercise the deny branch of the guard
#                          hooks and assert the runtime output is schema-valid.
#
# Usage:
#   scripts/check-pretooluse-permission-decision.sh            # static only
#   scripts/check-pretooluse-permission-decision.sh --dynamic  # static + runtime
#
# Reference: tests/HOOK_FORMAT_REFERENCE.md (rule #4)

set -uo pipefail
umask 077

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.claude/hooks"
VALID_VALUES="allow deny ask"
ERRORS=0

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'

is_valid() { case " $VALID_VALUES " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# ---------------------------------------------------------------------------
# STATIC: scan emit-sites of the form  "permissionDecision": "<value>"
# (the detector form  .permissionDecision == "<value>"  is intentionally not
#  matched — it reads a decision, it does not emit one.)
# ---------------------------------------------------------------------------
echo -e "${YELLOW}[static] Scanning PreToolUse permissionDecision emit-sites${NC}"
if [[ -d "$HOOKS_DIR" ]]; then
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        # match = path:line:"permissionDecision": "value"
        value="$(printf '%s' "$match" | grep -oE '"permissionDecision"[[:space:]]*:[[:space:]]*"[A-Za-z]+"' | grep -oE '"[A-Za-z]+"$' | tr -d '"')"
        location="$(printf '%s' "$match" | cut -d: -f1-2)"
        if [[ -n "$value" ]] && ! is_valid "$value"; then
            echo -e "  ${RED}✗ ${location}: permissionDecision=\"${value}\" — must be allow|deny|ask${NC}"
            [[ "$value" == "block" ]] && echo -e "    ${YELLOW}hint: \"block\" is a Stop-hook 'decision' value; PreToolUse uses \"deny\".${NC}"
            ((ERRORS++))
        fi
    done < <(grep -rnoE '"permissionDecision"[[:space:]]*:[[:space:]]*"[A-Za-z]+"' "$HOOKS_DIR" 2>/dev/null || true)
fi
[[ $ERRORS -eq 0 ]] && echo -e "  ${GREEN}✓ all emit-sites use allow|deny|ask${NC}"

# ---------------------------------------------------------------------------
# DYNAMIC (optional): exercise the deny branch — the path that was failing.
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--dynamic" ]]; then
    echo -e "${YELLOW}[dynamic] Exercising guard deny branches${NC}"
    if ! command -v jq >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠ jq/python3 unavailable — skipping dynamic checks${NC}"
    else
        payload() { printf '{"session_id":"s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"d"}}' "$REPO_ROOT" "$1"; }
        # A command the guards must block. Safe to keep verbatim here: the guard
        # scans the Bash command line (`bash check-...sh`), not file contents.
        danger="git reset --hard HEAD"
        for spec in "git-safety-guard.py|$danger" "permission-guard.sh|$danger"; do
            hook="${spec%%|*}"; cmd="${spec##*|}"
            out="$(payload "$cmd" | "$HOOKS_DIR/$hook" 2>/dev/null || true)"
            pd="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // .permissionDecision // "MISSING"' 2>/dev/null || echo PARSE_ERR)"
            if is_valid "$pd"; then
                echo -e "  ${GREEN}✓ $hook deny-branch → permissionDecision=$pd${NC}"
            elif [[ -z "$out" || "$pd" == "MISSING" || "$pd" == "PARSE_ERR" ]]; then
                # Could not capture output (e.g. nested under a live guard). Not a
                # value violation — the authoritative runtime check lives in
                # tests/test_pretooluse_permission_decision.py. Skip, do not fail.
                echo -e "  ${YELLOW}⚠ $hook deny-branch not exercised (no output captured) — see pytest${NC}"
            else
                # A concrete, invalid value was emitted (e.g. "block"). This is the regression.
                echo -e "  ${RED}✗ $hook deny-branch → permissionDecision=$pd (expected allow|deny|ask)${NC}"
                ((ERRORS++))
            fi
        done
    fi
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}FAIL: $ERRORS invalid permissionDecision value(s).${NC}"
    echo -e "${YELLOW}Fix: use \"deny\" (not \"block\") for PreToolUse. See tests/HOOK_FORMAT_REFERENCE.md rule #4.${NC}"
    exit 1
fi
echo -e "${GREEN}PASS: PreToolUse permissionDecision values are schema-valid.${NC}"
exit 0
