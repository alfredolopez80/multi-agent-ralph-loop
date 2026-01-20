#!/bin/bash
# install-git-hooks.sh - Install git hooks for multi-agent-ralph-loop
# VERSION: 2.57.3
#
# Usage:
#   ./scripts/install-git-hooks.sh
#
# This installs the pre-commit hook that validates Claude Code hook JSON formats

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_DIR/.git/hooks"

echo "Installing git hooks for multi-agent-ralph-loop..."

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'HOOK_EOF'
#!/bin/bash
# pre-commit hook for multi-agent-ralph-loop
# VERSION: 2.57.3
# Purpose: Validate hook JSON formats before commit
#
# CRITICAL FORMAT RULES (per official Claude Code docs):
# - PostToolUse/PreToolUse/UserPromptSubmit: {"continue": true/false}
# - Stop hooks ONLY: {"decision": "approve"/"block"}
# - The string "continue" is NEVER valid for the "decision" field

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

STAGED_HOOKS=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.claude/hooks/.*\.(sh|py)$' || true)

if [[ -z "$STAGED_HOOKS" ]]; then
    exit 0
fi

echo -e "${YELLOW}Pre-commit: Validating Claude Code hook JSON formats${NC}"

ERRORS=0

for hook_file in $STAGED_HOOKS; do
    [[ ! -f "$hook_file" ]] && continue

    hook_name=$(basename "$hook_file")

    # CRITICAL: "decision": "continue" is NEVER valid
    if grep -qE '"decision":\s*"continue"' "$hook_file"; then
        echo -e "${RED}✗ $hook_name: Uses invalid {\"decision\": \"continue\"}${NC}"
        ((ERRORS++))
        continue
    fi

    echo -e "${GREEN}✓ $hook_name${NC}"
done

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}COMMIT BLOCKED: $ERRORS hook(s) have invalid JSON format${NC}"
    echo "Reference: tests/HOOK_FORMAT_REFERENCE.md"
    exit 1
fi

exit 0
HOOK_EOF

chmod +x "$HOOKS_DIR/pre-commit"

echo "✓ pre-commit hook installed"
echo ""
echo "Git hooks installed successfully!"
echo ""
echo "The pre-commit hook will validate Claude Code hook JSON formats"
echo "before each commit to prevent format errors."
echo ""
echo "Reference: tests/HOOK_FORMAT_REFERENCE.md"
