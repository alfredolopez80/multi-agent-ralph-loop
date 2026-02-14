#!/bin/bash
# test_skills_centralization.sh - Tests for proper skills centralization
# VERSION: 2.86.0
#
# Validates that skills from all sources are available in ~/.claude/skills

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TESTS_PASSED=0
TESTS_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; ((TESTS_PASSED++)); }
fail() { echo -e "${RED}✗${NC} $1"; ((TESTS_FAILED++)); }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
section() { echo ""; echo "=== $1 ==="; }

count_skills() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        find "$dir" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

section "Skills Centralization Audit"

# Count skills in each location
echo "Skills count by location:"
echo ""

# Old Claude Code
old_claude="/Users/alfredolopez/.claude-code-old/.claude-old/skills"
count=$(count_skills "$old_claude")
count=$((count - 1))
echo "  old_claude: $count skills"

# Old Zai
old_zai="/Users/alfredolopez/.claude-sneakpeek-old/zai/skills"
count=$(count_skills "$old_zai")
count=$((count - 1))
echo "  old_zai: $count skills"

# Kimi shared
kimi="/Users/alfredolopez/.config/agents/skills"
count=$(count_skills "$kimi")
count=$((count - 1))
echo "  kimi_shared: $count skills"

# Current
current="$HOME/.claude/skills"
count=$(count_skills "$current")
count=$((count - 1))
echo "  current: $count skills"

# Check current ~/.claude/skills
section "Current Configuration"

if [[ -L "$current" ]]; then
    target=$(readlink "$current")
    warn "~/.claude/skills is a symlink to: $target"
    warn "This means only repo skills are available (~40)"
    warn "Skills from other locations (~1800+) are NOT accessible"
    fail "Skills not centralized - symlink points to single repo"
elif [[ -d "$current" ]]; then
    if [[ $count -gt 100 ]]; then
        pass "~/.claude/skills has $count skills (centralized)"
    else
        warn "~/.claude/skills has only $count skills"
        fail "Skills not fully centralized"
    fi
else
    fail "~/.claude/skills does not exist"
fi

# Check ralph-* agents availability
section "Custom Agents Availability"

agents_to_check=("ralph-coder" "ralph-reviewer" "ralph-tester" "ralph-researcher")

for agent in "${agents_to_check[@]}"; do
    if [[ -f "$HOME/.claude/agents/${agent}.md" ]]; then
        pass "Agent available globally: $agent"
    else
        if [[ -f "$REPO_ROOT/.claude/agents/${agent}.md" ]]; then
            fail "Agent exists in repo but NOT in global: $agent"
        else
            fail "Agent missing entirely: $agent"
        fi
    fi
done

# Summary
section "Summary"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "ISSUES FOUND:"
    echo "1. Skills are not centralized - many skills from old locations are inaccessible"
    echo "2. Custom agents (ralph-*) exist in repo but not globally"
    echo ""
    echo "RECOMMENDED FIX:"
    echo "  Run: /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/scripts/centralize-skills.sh"
    exit 1
else
    echo "All skills and agents properly centralized!"
    exit 0
fi
