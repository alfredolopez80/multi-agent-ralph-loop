#!/bin/bash
# ==============================================================================
# validate-integration.sh - Multi-Agent Ralph v2.40 Integration Validator
# ==============================================================================
# Quick bash-based validation of all v2.40 components:
# - Skills discovery and frontmatter
# - llm-tldr integration
# - ultrathink skill presence
# - Hooks configuration
# - Configuration hierarchy
# - OpenCode synchronization
# ==============================================================================

set -uo pipefail
# Note: -e disabled to allow ((counter++)) when counter is 0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Paths
CLAUDE_GLOBAL="${HOME}/.claude"
OPENCODE_DIR="${HOME}/.config/opencode"
RALPH_DIR="${HOME}/.ralph"
GITHUB_DIR="${HOME}/Documents/GitHub"

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Multi-Agent Ralph v2.40 Integration Validator${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${YELLOW}[$1/7] $2${NC}"
    echo "────────────────────────────────────────────────"
}

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

check_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

check_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

# ==============================================================================
# Section 1: Skills Discovery
# ==============================================================================
check_skills() {
    print_section 1 "Skills Discovery"

    local skills_dir="${CLAUDE_GLOBAL}/skills"

    # Check directory exists
    if [ -d "$skills_dir" ]; then
        check_pass "Skills directory exists: $skills_dir"
    else
        check_fail "Skills directory NOT found: $skills_dir"
        return
    fi

    # Count skills
    local skill_count
    skill_count=$(find "$skills_dir" -maxdepth 1 -type d | wc -l | tr -d ' ')
    skill_count=$((skill_count - 1)) # Subtract parent directory

    if [ "$skill_count" -ge 100 ]; then
        check_pass "Skills count: $skill_count (minimum 100)"
    else
        check_fail "Skills count: $skill_count (expected >= 100)"
    fi

    # Check critical skills
    local critical_skills=("orchestrator" "clarify" "gates" "adversarial" "ultrathink" "retrospective" "loop" "parallel")
    local missing=0

    for skill in "${critical_skills[@]}"; do
        if [ -d "${skills_dir}/${skill}" ] || [ -f "${skills_dir}/${skill}.md" ]; then
            : # exists
        else
            check_fail "Critical skill missing: $skill"
            missing=$((missing + 1))
        fi
    done

    if [ "$missing" -eq 0 ]; then
        check_pass "All ${#critical_skills[@]} critical skills present"
    fi
}

# ==============================================================================
# Section 2: Skill Frontmatter
# ==============================================================================
check_frontmatter() {
    print_section 2 "Skill Frontmatter Validation"

    local ultrathink="${CLAUDE_GLOBAL}/skills/ultrathink/SKILL.md"
    local orchestrator="${CLAUDE_GLOBAL}/skills/orchestrator/SKILL.md"

    # Check ultrathink
    if [ -f "$ultrathink" ]; then
        if grep -q "^---" "$ultrathink" && grep -q "model: opus" "$ultrathink"; then
            check_pass "ultrathink has valid frontmatter with model: opus"
        else
            check_fail "ultrathink missing frontmatter or model: opus"
        fi

        if grep -q "user-invocable: true" "$ultrathink"; then
            check_pass "ultrathink is user-invocable"
        else
            check_warn "ultrathink should be user-invocable"
        fi
    else
        check_fail "ultrathink SKILL.md not found"
    fi

    # Check orchestrator
    if [ -f "$orchestrator" ]; then
        if grep -q "^---" "$orchestrator" && grep -q "description:" "$orchestrator"; then
            check_pass "orchestrator has valid frontmatter"
        else
            check_fail "orchestrator missing frontmatter"
        fi
    else
        check_fail "orchestrator SKILL.md not found"
    fi
}

# ==============================================================================
# Section 3: llm-tldr Integration
# ==============================================================================
check_tldr() {
    print_section 3 "llm-tldr Integration"

    # Check if installed
    if command -v tldr &>/dev/null; then
        local version
        version=$(tldr --version 2>&1 | head -1 || echo "unknown")
        check_pass "llm-tldr installed: $version"
    else
        check_fail "llm-tldr NOT installed (run: pip install llm-tldr)"
        return
    fi

    # Check hook exists
    local hook_path="${CLAUDE_GLOBAL}/hooks/session-start-tldr.sh"
    if [ -f "$hook_path" ]; then
        check_pass "SessionStart hook exists: session-start-tldr.sh"

        if [ -x "$hook_path" ]; then
            check_pass "Hook is executable"
        else
            check_fail "Hook NOT executable"
        fi
    else
        check_fail "SessionStart hook NOT found: $hook_path"
    fi

    # Check hook registered
    local settings="${CLAUDE_GLOBAL}/settings.json"
    if [ -f "$settings" ]; then
        if grep -q "session-start-tldr" "$settings"; then
            check_pass "Hook registered in settings.json"
        else
            check_fail "Hook NOT registered in settings.json"
        fi
    else
        check_fail "settings.json NOT found"
    fi

    # Check tldr skills
    local tldr_skills=("tldr" "tldr-context" "tldr-impact" "tldr-semantic")
    local found=0
    for skill in "${tldr_skills[@]}"; do
        if [ -d "${CLAUDE_GLOBAL}/skills/${skill}" ]; then
            found=$((found + 1))
        fi
    done

    if [ "$found" -ge 2 ]; then
        check_pass "TLDR skills found: $found of ${#tldr_skills[@]}"
    else
        check_warn "Only $found TLDR skills found (expected >= 2)"
    fi
}

# ==============================================================================
# Section 4: Hooks Configuration
# ==============================================================================
check_hooks() {
    print_section 4 "Hooks Configuration"

    local hooks_dir="${CLAUDE_GLOBAL}/hooks"
    local settings="${CLAUDE_GLOBAL}/settings.json"

    # Check hooks directory
    if [ -d "$hooks_dir" ]; then
        local hook_count
        hook_count=$(find "$hooks_dir" -maxdepth 1 -type f \( -name "*.sh" -o -name "*.py" \) | wc -l | tr -d ' ')
        check_pass "Hooks directory exists with $hook_count hooks"
    else
        check_fail "Hooks directory NOT found"
        return
    fi

    # Check critical hooks
    local critical_hooks=(
        "session-start-ledger.sh"
        "session-start-tldr.sh"
        "pre-compact-handoff.sh"
        "quality-gates.sh"
        "git-safety-guard.py"
        "auto-sync-global.sh"
    )

    local missing=0
    for hook in "${critical_hooks[@]}"; do
        if [ -f "${hooks_dir}/${hook}" ]; then
            if [ -x "${hooks_dir}/${hook}" ]; then
                : # exists and executable
            else
                check_warn "Hook not executable: $hook"
            fi
        else
            check_fail "Critical hook missing: $hook"
            missing=$((missing + 1))
        fi
    done

    if [ "$missing" -eq 0 ]; then
        check_pass "All ${#critical_hooks[@]} critical hooks present"
    fi

    # Check hook types in settings.json
    if [ -f "$settings" ]; then
        local hook_types=("PostToolUse" "PreToolUse" "SessionStart" "PreCompact")
        local configured=0

        for type in "${hook_types[@]}"; do
            if grep -q "\"$type\"" "$settings"; then
                configured=$((configured + 1))
            fi
        done

        if [ "$configured" -eq ${#hook_types[@]} ]; then
            check_pass "All ${#hook_types[@]} hook types configured in settings.json"
        else
            check_warn "Only $configured of ${#hook_types[@]} hook types configured"
        fi
    fi
}

# ==============================================================================
# Section 5: Configuration Hierarchy
# ==============================================================================
check_config() {
    print_section 5 "Configuration Hierarchy"

    # Check global directory
    if [ -d "$CLAUDE_GLOBAL" ]; then
        check_pass "Global Claude directory exists: ~/.claude/"
    else
        check_fail "Global Claude directory NOT found"
        return
    fi

    # Check global settings.json
    if [ -f "${CLAUDE_GLOBAL}/settings.json" ]; then
        if python3 -c "import json; json.load(open('${CLAUDE_GLOBAL}/settings.json'))" 2>/dev/null; then
            check_pass "Global settings.json is valid JSON"
        else
            check_fail "Global settings.json is INVALID JSON"
        fi
    else
        check_fail "Global settings.json NOT found"
    fi

    # Check subdirectories
    local dirs=("skills" "agents" "hooks" "commands")
    for dir in "${dirs[@]}"; do
        if [ -d "${CLAUDE_GLOBAL}/${dir}" ]; then
            local count
            count=$(find "${CLAUDE_GLOBAL}/${dir}" -maxdepth 1 -type d -o -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
            check_info "$dir: $count items"
        fi
    done
}

# ==============================================================================
# Section 6: OpenCode Synchronization
# ==============================================================================
check_opencode() {
    print_section 6 "OpenCode Synchronization"

    if [ ! -d "$OPENCODE_DIR" ]; then
        check_warn "OpenCode not installed: $OPENCODE_DIR"
        return
    fi

    check_pass "OpenCode directory exists: $OPENCODE_DIR"

    # Check for skills (singular in OpenCode)
    local skill_dir="${OPENCODE_DIR}/skill"
    local skills_dir="${OPENCODE_DIR}/skills"

    if [ -d "$skill_dir" ] || [ -d "$skills_dir" ]; then
        local skill_count=0
        [ -d "$skill_dir" ] && skill_count=$(find "$skill_dir" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        [ -d "$skills_dir" ] && skill_count=$((skill_count + $(find "$skills_dir" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')))
        check_pass "OpenCode skills present: ~$skill_count"
    else
        check_warn "OpenCode skills directory not found"
    fi

    # Check for agents
    local agent_dir="${OPENCODE_DIR}/agent"
    local agents_dir="${OPENCODE_DIR}/agents"

    if [ -d "$agent_dir" ] || [ -d "$agents_dir" ]; then
        check_pass "OpenCode agents directory present"
    else
        check_warn "OpenCode agents directory not found"
    fi

    # Check for Claude model references (should be ZERO for OpenCode compatibility)
    local claude_refs
    claude_refs=$(grep -r "model:.*opus\|model:.*sonnet\|model:.*haiku" "$OPENCODE_DIR" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$claude_refs" -eq 0 ]; then
        check_pass "No Claude model references in OpenCode (compatible)"
    else
        check_fail "Found $claude_refs Claude model references in OpenCode"
        check_info "Run: ./scripts/migrate-opencode-models.sh to fix"
    fi

    # Verify opencode.json uses MiniMax/OpenAI models
    local config_file="${OPENCODE_DIR}/opencode.json"
    if [ -f "$config_file" ]; then
        if grep -q "minimax\|openai\|gpt-5" "$config_file"; then
            check_pass "opencode.json uses compatible models"
        else
            check_warn "opencode.json may use unsupported models"
        fi
    fi
}

# ==============================================================================
# Section 7: Ralph Data & Backups
# ==============================================================================
check_ralph() {
    print_section 7 "Ralph Data & Backups"

    if [ ! -d "$RALPH_DIR" ]; then
        check_warn "Ralph data directory not found: $RALPH_DIR"
        return
    fi

    check_pass "Ralph data directory exists: ~/.ralph/"

    # Check ledgers
    local ledger_dir="${RALPH_DIR}/ledgers"
    if [ -d "$ledger_dir" ]; then
        local ledger_count
        ledger_count=$(find "$ledger_dir" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        check_pass "Ledgers directory: $ledger_count saved"
    else
        check_info "No ledgers directory (will be created on first save)"
    fi

    # Check handoffs
    local handoff_dir="${RALPH_DIR}/handoffs"
    if [ -d "$handoff_dir" ]; then
        local handoff_count
        handoff_count=$(find "$handoff_dir" -maxdepth 2 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        check_pass "Handoffs directory: $handoff_count saved"
    else
        check_info "No handoffs directory (will be created on first save)"
    fi

    # Check backups
    local backup_dir="${RALPH_DIR}/backups"
    if [ -d "$backup_dir" ]; then
        local backup_count
        backup_count=$(find "$backup_dir" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        backup_count=$((backup_count - 1))
        check_pass "Backups directory: $backup_count backup sets"
    else
        check_info "No backups directory (run ralph backup-all-projects)"
    fi
}

# ==============================================================================
# Summary
# ==============================================================================
print_summary() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Summary${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}✓ PASSED:${NC}   $PASSED"
    echo -e "  ${RED}✗ FAILED:${NC}   $FAILED"
    echo -e "  ${YELLOW}⚠ WARNINGS:${NC} $WARNINGS"
    echo ""

    if [ "$FAILED" -eq 0 ]; then
        echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  ✓ Integration VALID - All critical components available${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
        exit 0
    else
        echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}  ✗ Integration INCOMPLETE - $FAILED checks failed${NC}"
        echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
        exit 1
    fi
}

# ==============================================================================
# Main
# ==============================================================================
main() {
    print_header

    check_skills
    check_frontmatter
    check_tldr
    check_hooks
    check_config
    check_opencode
    check_ralph

    print_summary
}

main "$@"
