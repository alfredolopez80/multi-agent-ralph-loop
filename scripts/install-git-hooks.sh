#!/bin/bash
# install-git-hooks.sh - Install git hooks for multi-agent-ralph-loop
# VERSION: 3.2.0
#
# Installs the pre-commit hook from the SINGLE versioned source of truth
# (scripts/pre-commit-template.sh) into the active hooks directory resolved from
# `git config core.hooksPath`.
#
# This repo uses core.hooksPath=.git-hooks, which is .gitignored — the active
# hook copy is LOCAL ONLY and is never committed. That is deliberate: it keeps
# hook contents out of the PUBLIC repo (no risk of leaking machine-specific or
# sensitive data). The committed source of truth is the template; run this
# script after cloning to (re)generate the active hook locally.
#
# Replaces the previous embedded-heredoc approach (which had drifted to an old
# version and missed Phase 1b). One source of truth now: the template.
#
# Usage:
#   ./scripts/install-git-hooks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$SCRIPT_DIR/pre-commit-template.sh"

echo "Installing git hooks for multi-agent-ralph-loop..."

if [[ ! -f "$TEMPLATE" ]]; then
    echo "ERROR: missing template: $TEMPLATE" >&2
    exit 1
fi

# Resolve the active hooks path. Honor an existing core.hooksPath; otherwise
# adopt the repo convention (.git-hooks) and set it so git actually uses it.
HOOKS_PATH="$(git -C "$PROJECT_DIR" config --get core.hooksPath 2>/dev/null || true)"
if [[ -z "$HOOKS_PATH" ]]; then
    HOOKS_PATH=".git-hooks"
    git -C "$PROJECT_DIR" config core.hooksPath "$HOOKS_PATH"
    echo "  core.hooksPath set to $HOOKS_PATH"
fi

# Resolve to an absolute directory (core.hooksPath may be relative to repo root).
case "$HOOKS_PATH" in
    /*) HOOKS_DIR="$HOOKS_PATH" ;;
    *)  HOOKS_DIR="$PROJECT_DIR/$HOOKS_PATH" ;;
esac

mkdir -p "$HOOKS_DIR"

# Install from the single source of truth. The template already includes
# Phase 1b (PreToolUse permissionDecision guard: allow|deny|ask, never "block").
install -m 0755 "$TEMPLATE" "$HOOKS_DIR/pre-commit"

echo "✓ pre-commit installed → $HOOKS_DIR/pre-commit"
echo "  source: scripts/pre-commit-template.sh"
echo "  active core.hooksPath: $(git -C "$PROJECT_DIR" config --get core.hooksPath)"
echo ""
echo "Git hooks installed successfully!"
echo "The pre-commit hook validates Claude Code hook JSON formats (incl. the"
echo "PreToolUse permissionDecision enum) before each commit."
echo ""
echo "Reference: tests/HOOK_FORMAT_REFERENCE.md"
