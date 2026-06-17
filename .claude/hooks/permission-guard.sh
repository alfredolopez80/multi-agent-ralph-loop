#!/usr/bin/env bash
# permission-guard.sh — Unified permission pipeline (v1.0)
# Hook: PreToolUse (Bash|Edit|Write + Agent|Task)
# VERSION: 1.0.0
#
# Consolidates: git-safety-guard.py + repo-boundary-guard.sh
# Strategy: Thin wrapper that dispatches stdin to original guards with
# short-circuit on block. Original guard logic is 100% preserved —
# both scripts remain on disk as internal modules.
#
# git-safety-guard.py (Bash only):
#   - Blocks destructive git commands (reset --hard, push --force, etc.)
#   - Blocks destructive fs commands (rm -rf /, git clean -f)
#   - Blocks command chaining (;, &&, eval, xargs rm)
#
# repo-boundary-guard.sh (Bash + Edit + Write + Agent|Task):
#   - Prevents file operations outside current repository
#   - Allows read-only commands on external repos
#   - Allows ~/.claude/ and /tmp/ paths
#
# SECURITY: SEC-111 (stdin limit), SEC-006 (error trap), umask 077

set -euo pipefail
umask 077

# Fail-open default: if anything goes wrong, allow the operation.
# Matches both original guards' error-trap behavior.
ALLOW='{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
trap 'echo "$ALLOW"' ERR EXIT

# SEC-111: Read input once from stdin (100KB max)
INPUT=$(head -c 100000)

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# --- Phase 1: Git Safety Check (Bash commands only) ---
# git-safety-guard.py blocks destructive git and filesystem commands.
# Only relevant for Bash tool invocations.
if [[ "$TOOL_NAME" == "Bash" ]]; then
    SAFETY_RESULT=$(echo "$INPUT" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>/dev/null || true)
    if echo "$SAFETY_RESULT" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
        trap - ERR EXIT
        echo "$SAFETY_RESULT"
        exit 0
    fi
fi

# --- Phase 2: Repo Boundary Check (all applicable tools) ---
# repo-boundary-guard.sh handles tool-specific path extraction internally
# and works correctly for Bash, Edit, Write, Agent, and Task tools.
BOUNDARY_RESULT=$(echo "$INPUT" | "$HOOKS_DIR/repo-boundary-guard.sh" 2>/dev/null || true)
if echo "$BOUNDARY_RESULT" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
    trap - ERR EXIT
    echo "$BOUNDARY_RESULT"
    exit 0
fi

# All checks passed — allow the operation
trap - ERR EXIT
echo "$ALLOW"
