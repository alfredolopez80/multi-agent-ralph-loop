#!/usr/bin/env bash
# quick-install.sh - One-line installer for Multi-Agent Ralph
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/alfredolopez80/multi-agent-ralph-loop/main/scripts/quick-install.sh | bash
#   curl -fsSL ... | bash -s -- --all
#   curl -fsSL ... | bash -s -- --minimal
#   curl -fsSL ... | bash -s -- --skills-only
#
# Flags:
#   --all          Install everything (CLI + skills + agents + LSP + security tools)
#   --minimal      CLI + skills only (default)
#   --skills-only  Only symlink skills (for updating)
#   --uninstall    Remove Ralph installation
#   --force        Overwrite existing symlinks even if they point elsewhere
#   --dry-run      Show what would be done without making changes
#
# This script is idempotent — safe to run multiple times.
# It merges with existing ~/.claude/ configuration instead of overwriting.

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
RALPH_HOME="${RALPH_HOME:-${HOME}/.ralph}"
RALPH_REPO="${RALPH_HOME}/repo"
RALPH_REPO_URL="${RALPH_REPO_URL:-https://github.com/alfredolopez80/multi-agent-ralph-loop.git}"
CLAUDE_DIR="${HOME}/.claude"
INSTALL_DIR="${HOME}/.local/bin"

# Defaults
MODE="minimal"
FORCE=false
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "\n${CYAN}═══ $1 ═══${NC}"; }
run()         { if $DRY_RUN; then echo "  [dry-run] $*"; else "$@"; fi; }

# ═══════════════════════════════════════════════════════════════════════════════
# PARSE ARGUMENTS
# ═══════════════════════════════════════════════════════════════════════════════
for arg in "$@"; do
    case "$arg" in
        --all)          MODE="all" ;;
        --minimal)      MODE="minimal" ;;
        --skills-only)  MODE="skills-only" ;;
        --uninstall)    MODE="uninstall" ;;
        --force)        FORCE=true ;;
        --dry-run|-n)   DRY_RUN=true ;;
        --help|-h)
            sed -n '2,/^$/s/^# \?//p' "$0" 2>/dev/null || echo "Usage: quick-install.sh [--all|--minimal|--skills-only] [--force] [--dry-run]"
            exit 0
            ;;
        *) log_error "Unknown flag: $arg"; exit 1 ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# UNINSTALL
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$MODE" = "uninstall" ]; then
    log_step "Uninstalling Ralph"
    [ -f "${INSTALL_DIR}/ralph" ] && run rm -f "${INSTALL_DIR}/ralph" && log_success "Removed ralph CLI"

    # Remove only Ralph-owned symlinks from ~/.claude/skills/
    if [ -d "${CLAUDE_DIR}/skills" ]; then
        for link in "${CLAUDE_DIR}/skills/"*; do
            [ -L "$link" ] || continue
            target=$(readlink "$link")
            if [[ "$target" == *"multi-agent-ralph-loop"* ]]; then
                run rm -f "$link"
            fi
        done
        log_success "Removed Ralph skill symlinks (preserved external skills)"
    fi

    log_info "Ralph repo preserved at ${RALPH_REPO} — delete manually if desired"
    log_success "Uninstall complete"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PREFLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════════════════════
log_step "Preflight Checks"

MISSING=()
command -v git  &>/dev/null || MISSING+=("git")
command -v jq   &>/dev/null || MISSING+=("jq")
command -v curl &>/dev/null || MISSING+=("curl")

if [ ${#MISSING[@]} -gt 0 ]; then
    log_error "Missing required tools: ${MISSING[*]}"
    echo "  Install with: brew install ${MISSING[*]}"
    exit 1
fi
log_success "Required tools: git, jq, curl"

# Check optional tools
OPTIONAL_MISSING=()
command -v claude &>/dev/null || OPTIONAL_MISSING+=("claude (Claude Code CLI)")
command -v gh    &>/dev/null || OPTIONAL_MISSING+=("gh (GitHub CLI)")
if [ ${#OPTIONAL_MISSING[@]} -gt 0 ]; then
    log_warn "Optional: ${OPTIONAL_MISSING[*]}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: CLONE OR UPDATE REPO
# ═══════════════════════════════════════════════════════════════════════════════
log_step "Step 1: Repository"

run mkdir -p "${RALPH_HOME}"

if [ -d "${RALPH_REPO}/.git" ]; then
    log_info "Repo exists at ${RALPH_REPO}, pulling latest..."
    if ! $DRY_RUN; then
        git -C "${RALPH_REPO}" fetch origin main --quiet 2>/dev/null || true
        git -C "${RALPH_REPO}" reset --hard origin/main --quiet 2>/dev/null || true
    fi
    log_success "Updated to latest"
else
    log_info "Cloning to ${RALPH_REPO}..."
    run git clone --depth 1 "${RALPH_REPO_URL}" "${RALPH_REPO}"
    log_success "Cloned"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: CREATE DIRECTORIES (idempotent)
# ═══════════════════════════════════════════════════════════════════════════════
log_step "Step 2: Directories"

for dir in \
    "${INSTALL_DIR}" \
    "${RALPH_HOME}/config" \
    "${RALPH_HOME}/logs" \
    "${RALPH_HOME}/memory" \
    "${RALPH_HOME}/episodes" \
    "${RALPH_HOME}/procedural" \
    "${RALPH_HOME}/improvements/backups" \
    "${CLAUDE_DIR}/agents" \
    "${CLAUDE_DIR}/skills" \
    "${CLAUDE_DIR}/hooks"; do
    run mkdir -p "$dir"
done
log_success "All directories exist"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: INSTALL RALPH CLI
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$MODE" != "skills-only" ]; then
    log_step "Step 3: Ralph CLI"

    if ! $DRY_RUN; then
        cp "${RALPH_REPO}/scripts/ralph" "${INSTALL_DIR}/ralph"
        chmod +x "${INSTALL_DIR}/ralph"
    fi
    log_success "ralph CLI → ${INSTALL_DIR}/ralph"

    # Verify PATH
    if ! echo "$PATH" | tr ':' '\n' | grep -q "${INSTALL_DIR}"; then
        log_warn "${INSTALL_DIR} is not in PATH. Add to your shell profile:"
        echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: SYMLINK SKILLS (merge with existing)
# ═══════════════════════════════════════════════════════════════════════════════
log_step "Step 4: Skills"

CREATED=0
SKIPPED=0
REPLACED=0

for skill_dir in "${RALPH_REPO}/.claude/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")

    # Skip if no SKILL.md
    [ -f "${skill_dir}/SKILL.md" ] || [ -f "${skill_dir}/skill.md" ] || continue
    # Skip hidden/temp dirs
    [[ "$skill_name" == .* ]] && continue

    target="${CLAUDE_DIR}/skills/${skill_name}"

    if [ -L "$target" ]; then
        current=$(readlink "$target")
        if [ "$current" = "$skill_dir" ]; then
            ((SKIPPED++))
            continue
        fi
        if $FORCE; then
            run rm -f "$target"
            run ln -sfn "$skill_dir" "$target"
            ((REPLACED++))
        else
            ((SKIPPED++))
        fi
    elif [ -e "$target" ]; then
        # Real directory exists (not a symlink) — don't clobber
        log_warn "Skipping $skill_name (real dir exists, use --force to replace)"
        ((SKIPPED++))
    else
        run ln -sfn "$skill_dir" "$target"
        ((CREATED++))
    fi
done

log_success "Skills: ${CREATED} created, ${REPLACED} replaced, ${SKIPPED} unchanged"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: AGENTS (copy, don't overwrite existing)
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$MODE" != "skills-only" ]; then
    log_step "Step 5: Agents"

    AGENT_ADDED=0
    AGENT_SKIPPED=0
    for agent_file in "${RALPH_REPO}/.claude/agents/"*.md; do
        [ -f "$agent_file" ] || continue
        agent_name=$(basename "$agent_file")
        target="${CLAUDE_DIR}/agents/${agent_name}"

        # Skip old/backup files
        [[ "$agent_name" == *.old ]] && continue

        if [ -f "$target" ] && ! $FORCE; then
            ((AGENT_SKIPPED++))
        else
            if ! $DRY_RUN; then
                cp "$agent_file" "$target"
            fi
            ((AGENT_ADDED++))
        fi
    done

    log_success "Agents: ${AGENT_ADDED} installed, ${AGENT_SKIPPED} preserved"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: OPTIONAL — LSP + SECURITY TOOLS
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$MODE" = "all" ]; then
    log_step "Step 6: Language Servers"
    if [ -x "${RALPH_REPO}/scripts/install-language-servers.sh" ]; then
        run bash "${RALPH_REPO}/scripts/install-language-servers.sh" --essential
    else
        log_warn "LSP installer not found, skipping"
    fi

    log_step "Step 6b: Security Tools"
    if [ -x "${RALPH_REPO}/scripts/install-security-tools.sh" ]; then
        run bash "${RALPH_REPO}/scripts/install-security-tools.sh"
    else
        log_warn "Security tools installer not found, skipping"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: VERIFY
# ═══════════════════════════════════════════════════════════════════════════════
log_step "Verification"

ERRORS=0
[ -x "${INSTALL_DIR}/ralph" ] && log_success "ralph CLI installed" || { log_error "ralph CLI missing"; ((ERRORS++)); }
[ -d "${CLAUDE_DIR}/skills" ] && log_success "Skills directory exists" || { log_error "Skills dir missing"; ((ERRORS++)); }

SKILL_COUNT=$(find "${CLAUDE_DIR}/skills" -maxdepth 1 -type l -exec readlink {} \; 2>/dev/null | grep -c "multi-agent-ralph-loop" || true)
log_info "Ralph skills linked: ${SKILL_COUNT}"

AGENT_COUNT=$(find "${CLAUDE_DIR}/agents" -name "*.md" -not -name "*.old" 2>/dev/null | wc -l | tr -d ' ')
log_info "Agents available: ${AGENT_COUNT}"

if [ "$ERRORS" -eq 0 ]; then
    echo ""
    log_success "Installation complete!"
    echo ""
    echo -e "  Next steps:"
    echo -e "    1. ${CYAN}ralph help${NC}              — see available commands"
    echo -e "    2. ${CYAN}ralph health --compact${NC}  — check system status"
    echo -e "    3. ${CYAN}/orchestrator \"task\"${NC}    — run orchestration in Claude Code"
    echo ""
    echo -e "  To update:  re-run this script"
    echo -e "  To remove:  re-run with ${CYAN}--uninstall${NC}"
    echo ""
else
    log_error "Installation completed with ${ERRORS} error(s)"
    exit 1
fi
