#!/usr/bin/env bash
# install.sh - Multi-Agent Ralph Wiggum v2.21 Global Installer
# Installs ralph CLI globally and integrates with Claude Code
# v2.21: Self-update, pre-merge validation, integrations health check
# v2.20: Git worktree + PR workflow with multi-agent review (Claude + Codex)
# v2.19: Security hardening (VULN-001 to VULN-008 fixes), improved file permissions

set -euo pipefail

# SECURITY: Ensure all created files are user-only by default (VULN-008)
umask 077

VERSION="2.21.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation directories
INSTALL_DIR="${HOME}/.local/bin"
RALPH_DIR="${HOME}/.ralph"
CLAUDE_DIR="${HOME}/.claude"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECK
# ═══════════════════════════════════════════════════════════════════════════════
check_dependencies() {
    echo ""
    log_info "Checking dependencies..."

    local MISSING=()
    local OPTIONAL_MISSING=()

    # Required
    command -v jq &>/dev/null || MISSING+=("jq")
    command -v curl &>/dev/null || MISSING+=("curl")

    # Optional but recommended
    command -v claude &>/dev/null || OPTIONAL_MISSING+=("claude (Claude Code CLI)")
    command -v codex &>/dev/null || OPTIONAL_MISSING+=("codex (Codex CLI)")
    command -v gemini &>/dev/null || OPTIONAL_MISSING+=("gemini (Gemini CLI)")
    command -v wt &>/dev/null || OPTIONAL_MISSING+=("wt (WorkTrunk - for git worktree workflow)")
    command -v gh &>/dev/null || OPTIONAL_MISSING+=("gh (GitHub CLI - for PR workflow)")

    # Language-specific (optional)
    command -v npx &>/dev/null || OPTIONAL_MISSING+=("npx (Node.js - for TypeScript/ESLint)")
    command -v pyright &>/dev/null || OPTIONAL_MISSING+=("pyright (Python type checker)")
    command -v ruff &>/dev/null || OPTIONAL_MISSING+=("ruff (Python linter)")

    if [ ${#MISSING[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${MISSING[*]}"
        echo ""
        echo "  Install them with:"
        echo "    brew install ${MISSING[*]}"
        echo ""
        exit 1
    fi

    log_success "Required dependencies OK"

    if [ ${#OPTIONAL_MISSING[@]} -gt 0 ]; then
        log_warn "Optional dependencies not found:"
        for dep in "${OPTIONAL_MISSING[@]}"; do
            echo "    - $dep"
        done
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# BACKUP EXISTING CONFIG
# ═══════════════════════════════════════════════════════════════════════════════
backup_existing() {
    local BACKUP_DIR="${RALPH_DIR}/backups/$(date +%Y%m%d_%H%M%S)"

    if [ -d "${CLAUDE_DIR}/agents" ] || [ -d "${CLAUDE_DIR}/commands" ] || [ -f "${CLAUDE_DIR}/settings.json" ]; then
        log_info "Backing up existing Claude Code config..."
        mkdir -p "$BACKUP_DIR"

        [ -d "${CLAUDE_DIR}/agents" ] && cp -r "${CLAUDE_DIR}/agents" "$BACKUP_DIR/" 2>/dev/null || true
        [ -d "${CLAUDE_DIR}/commands" ] && cp -r "${CLAUDE_DIR}/commands" "$BACKUP_DIR/" 2>/dev/null || true
        [ -d "${CLAUDE_DIR}/skills" ] && cp -r "${CLAUDE_DIR}/skills" "$BACKUP_DIR/" 2>/dev/null || true
        [ -d "${CLAUDE_DIR}/hooks" ] && cp -r "${CLAUDE_DIR}/hooks" "$BACKUP_DIR/" 2>/dev/null || true
        [ -f "${CLAUDE_DIR}/settings.json" ] && cp "${CLAUDE_DIR}/settings.json" "$BACKUP_DIR/" 2>/dev/null || true

        log_success "Backup saved to: $BACKUP_DIR"
        # Store backup dir for potential restore
        LAST_BACKUP_DIR="$BACKUP_DIR"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MERGE SETTINGS (CRITICAL: Never overwrite, always merge)
# ═══════════════════════════════════════════════════════════════════════════════
merge_settings() {
    local RALPH_SETTINGS="${SCRIPT_DIR}/.claude/settings.json"
    local USER_SETTINGS="${CLAUDE_DIR}/settings.json"
    local TEMP_MERGED="${CLAUDE_DIR}/.settings.merged.tmp"

    # If no existing user settings, just copy ours
    if [ ! -f "$USER_SETTINGS" ]; then
        cp "$RALPH_SETTINGS" "$USER_SETTINGS"
        log_success "Settings installed (new file)"
        return 0
    fi

    log_info "Merging settings (preserving your existing configuration)..."

    # Validate both files are valid JSON
    if ! jq empty "$USER_SETTINGS" 2>/dev/null; then
        log_warn "Existing settings.json is invalid JSON - backing up and replacing"
        cp "$USER_SETTINGS" "${USER_SETTINGS}.invalid.bak"
        cp "$RALPH_SETTINGS" "$USER_SETTINGS"
        return 0
    fi

    # Deep merge using jq:
    # 1. Preserve ALL user settings
    # 2. Add our permissions (array union, no duplicates)
    # 3. Add our hooks (merge hook arrays, no duplicates)
    # 4. Preserve $schema from our file for validation

    jq -s '
    # Helper to merge hook arrays by matcher (no duplicates)
    def merge_hooks(a; b):
        if (a | type) == "array" and (b | type) == "array" then
            # Both are arrays - combine and deduplicate by matcher
            (a + b) | group_by(.matcher) | map(
                .[0] + {
                    hooks: ([.[].hooks] | add | unique_by(.command))
                }
            )
        elif (a | type) == "array" then a
        elif (b | type) == "array" then b
        else [] end;

    # $user is .[0], $ralph is .[1]
    .[0] as $user | .[1] as $ralph |

    # Start with user settings as base
    $user |

    # Add schema from ralph if user does not have one
    (if .["$schema"] then . else . + {"$schema": $ralph["$schema"]} end) |

    # Merge permissions.allow arrays (union, no duplicates)
    .permissions.allow = (
        (($user.permissions.allow // []) + ($ralph.permissions.allow // [])) | unique
    ) |

    # Merge permissions.deny arrays if they exist (union, no duplicates)
    (if ($user.permissions.deny // $ralph.permissions.deny) then
        .permissions.deny = ((($user.permissions.deny // []) + ($ralph.permissions.deny // [])) | unique)
    else . end) |

    # Merge hooks.PreToolUse
    .hooks.PreToolUse = merge_hooks($user.hooks.PreToolUse; $ralph.hooks.PreToolUse) |

    # Merge hooks.PostToolUse
    .hooks.PostToolUse = merge_hooks($user.hooks.PostToolUse; $ralph.hooks.PostToolUse) |

    # Ensure we dont have null values
    del(..|nulls)
    ' "$USER_SETTINGS" "$RALPH_SETTINGS" > "$TEMP_MERGED" 2>/dev/null

    # Validate merged result
    if jq empty "$TEMP_MERGED" 2>/dev/null; then
        mv "$TEMP_MERGED" "$USER_SETTINGS"
        log_success "Settings merged successfully:"
        log_success "  - Your existing settings: PRESERVED"
        log_success "  - Ralph permissions: ADDED"
        log_success "  - Ralph hooks: ADDED"
    else
        rm -f "$TEMP_MERGED"
        log_error "Failed to merge settings. Your settings are unchanged."
        log_warn "You may need to manually add Ralph hooks to your settings.json"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CREATE DIRECTORIES
# ═══════════════════════════════════════════════════════════════════════════════
create_directories() {
    log_info "Creating directories..."

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$RALPH_DIR"/{config,improvements/backups,logs}
    mkdir -p "$CLAUDE_DIR"/{agents,commands,skills,hooks}

    log_success "Directories created"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL CLI SCRIPTS
# ═══════════════════════════════════════════════════════════════════════════════
install_scripts() {
    log_info "Installing CLI scripts..."

    # Copy ralph and mmc
    cp "${SCRIPT_DIR}/scripts/ralph" "$INSTALL_DIR/ralph"
    cp "${SCRIPT_DIR}/scripts/mmc" "$INSTALL_DIR/mmc"

    # Make executable
    chmod +x "$INSTALL_DIR/ralph"
    chmod +x "$INSTALL_DIR/mmc"

    log_success "CLI scripts installed to $INSTALL_DIR"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL CLAUDE CODE COMPONENTS
# ═══════════════════════════════════════════════════════════════════════════════
install_claude_components() {
    log_info "Installing Claude Code components..."

    # Agents
    if [ -d "${SCRIPT_DIR}/.claude/agents" ]; then
        cp -r "${SCRIPT_DIR}/.claude/agents/"* "${CLAUDE_DIR}/agents/" 2>/dev/null || true
        log_success "Agents installed ($(ls -1 "${CLAUDE_DIR}/agents/" 2>/dev/null | wc -l | tr -d ' ') files)"
    fi

    # Commands
    if [ -d "${SCRIPT_DIR}/.claude/commands" ]; then
        cp -r "${SCRIPT_DIR}/.claude/commands/"* "${CLAUDE_DIR}/commands/" 2>/dev/null || true
        log_success "Commands installed ($(ls -1 "${CLAUDE_DIR}/commands/" 2>/dev/null | wc -l | tr -d ' ') files)"
    fi

    # Skills
    if [ -d "${SCRIPT_DIR}/.claude/skills" ]; then
        cp -r "${SCRIPT_DIR}/.claude/skills/"* "${CLAUDE_DIR}/skills/" 2>/dev/null || true
        log_success "Skills installed"
    fi

    # Hooks (with proper permissions)
    if [ -d "${SCRIPT_DIR}/.claude/hooks" ]; then
        cp -r "${SCRIPT_DIR}/.claude/hooks/"* "${CLAUDE_DIR}/hooks/" 2>/dev/null || true
        # Make all hook scripts executable (both .sh and .py)
        chmod +x "${CLAUDE_DIR}/hooks/"*.sh 2>/dev/null || true
        chmod +x "${CLAUDE_DIR}/hooks/"*.py 2>/dev/null || true
        log_success "Hooks installed:"
        log_success "  - git-safety-guard.py (blocks destructive git commands)"
        log_success "  - quality-gates.sh (9-language validation)"
    fi

    # Merge settings.json (CRITICAL: preserve user's existing settings)
    if [ -f "${SCRIPT_DIR}/.claude/settings.json" ]; then
        merge_settings
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL CODEX CONFIG (Safe merge)
# ═══════════════════════════════════════════════════════════════════════════════
install_codex_config() {
    if [ ! -d "${SCRIPT_DIR}/.codex" ]; then
        return 0
    fi

    log_info "Installing Codex CLI config..."
    mkdir -p "${HOME}/.codex/skills"

    local CODEX_INSTRUCTIONS="${HOME}/.codex/instructions.md"
    local RALPH_CODEX_INSTRUCTIONS="${SCRIPT_DIR}/.codex/instructions.md"
    local RALPH_MARKER="# === RALPH WIGGUM CODEX CONFIG ==="

    # Handle instructions.md
    if [ -f "$RALPH_CODEX_INSTRUCTIONS" ]; then
        if [ -f "$CODEX_INSTRUCTIONS" ]; then
            # Check if Ralph section already exists
            if grep -q "$RALPH_MARKER" "$CODEX_INSTRUCTIONS" 2>/dev/null; then
                log_info "Codex instructions already contain Ralph config"
            else
                # Append Ralph config to existing
                log_info "Appending Ralph config to existing Codex instructions..."
                {
                    echo ""
                    echo "$RALPH_MARKER"
                    echo "# Added by Ralph Wiggum v${VERSION}"
                    echo "# Do not edit between markers - will be updated on reinstall"
                    echo ""
                    cat "$RALPH_CODEX_INSTRUCTIONS"
                    echo ""
                    echo "# === END RALPH WIGGUM CODEX CONFIG ==="
                } >> "$CODEX_INSTRUCTIONS"
                log_success "Codex instructions merged (your existing config preserved)"
            fi
        else
            # No existing instructions, just copy
            cp "$RALPH_CODEX_INSTRUCTIONS" "$CODEX_INSTRUCTIONS"
            log_success "Codex instructions installed (new file)"
        fi
    fi

    # Copy skills (these are safe to overwrite as they're Ralph-specific)
    if [ -d "${SCRIPT_DIR}/.codex/skills" ]; then
        cp -r "${SCRIPT_DIR}/.codex/skills/"* "${HOME}/.codex/skills/" 2>/dev/null || true
        log_success "Codex skills installed"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL GEMINI CONFIG (Safe merge)
# ═══════════════════════════════════════════════════════════════════════════════
install_gemini_config() {
    if [ ! -d "${SCRIPT_DIR}/.gemini" ]; then
        return 0
    fi

    log_info "Installing Gemini CLI config..."
    mkdir -p "${HOME}/.gemini"

    local GEMINI_CONFIG="${HOME}/.gemini/GEMINI.md"
    local RALPH_GEMINI_CONFIG="${SCRIPT_DIR}/.gemini/GEMINI.md"
    local RALPH_MARKER="# === RALPH WIGGUM GEMINI CONFIG ==="

    # Handle GEMINI.md
    if [ -f "$RALPH_GEMINI_CONFIG" ]; then
        if [ -f "$GEMINI_CONFIG" ]; then
            # Check if Ralph section already exists
            if grep -q "$RALPH_MARKER" "$GEMINI_CONFIG" 2>/dev/null; then
                log_info "Gemini config already contains Ralph config"
            else
                # Append Ralph config to existing
                log_info "Appending Ralph config to existing Gemini config..."
                {
                    echo ""
                    echo "$RALPH_MARKER"
                    echo "# Added by Ralph Wiggum v${VERSION}"
                    echo "# Do not edit between markers - will be updated on reinstall"
                    echo ""
                    cat "$RALPH_GEMINI_CONFIG"
                    echo ""
                    echo "# === END RALPH WIGGUM GEMINI CONFIG ==="
                } >> "$GEMINI_CONFIG"
                log_success "Gemini config merged (your existing config preserved)"
            fi
        else
            # No existing config, just copy
            cp "$RALPH_GEMINI_CONFIG" "$GEMINI_CONFIG"
            log_success "Gemini config installed (new file)"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL CONFIG FILES
# ═══════════════════════════════════════════════════════════════════════════════
install_config() {
    log_info "Installing configuration..."

    # Copy models.json
    cp "${SCRIPT_DIR}/config/models.json" "${RALPH_DIR}/config/"

    log_success "Configuration installed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURE SHELL (Safe update with markers)
# ═══════════════════════════════════════════════════════════════════════════════
configure_shell() {
    log_info "Configuring shell..."

    local SHELL_RC=""
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    if [ -z "$SHELL_RC" ]; then
        log_warn "No .zshrc or .bashrc found - add PATH manually"
        return 0
    fi

    local START_MARKER="# >>> RALPH WIGGUM START >>>"
    local END_MARKER="# <<< RALPH WIGGUM END <<<"

    # Check if Ralph section already exists
    if grep -q "$START_MARKER" "$SHELL_RC" 2>/dev/null; then
        # Remove old Ralph section and replace with new
        log_info "Updating existing Ralph shell config..."
        # Create temp file without Ralph section
        local TEMP_RC="${SHELL_RC}.ralph.tmp"
        sed "/$START_MARKER/,/$END_MARKER/d" "$SHELL_RC" > "$TEMP_RC"
        mv "$TEMP_RC" "$SHELL_RC"
    fi

    # Append new Ralph section
    cat >> "$SHELL_RC" << RCEOF

$START_MARKER
# Ralph Wiggum v${VERSION} - Multi-Agent Orchestration
# This section is managed by Ralph - do not edit manually
# To update: reinstall Ralph or edit and remove markers

export PATH="\$HOME/.local/bin:\$PATH"

# Ralph aliases
alias rh='ralph'
alias rho='ralph orch'
alias rhr='ralph review'
alias rhp='ralph parallel'
alias rhs='ralph security'
alias rhb='ralph bugs'
alias rhu='ralph unit-tests'
alias rhf='ralph refactor'
alias rhres='ralph research'
alias rhm='ralph minimax'
alias rhg='ralph gates'
alias rha='ralph adversarial'
alias rhl='ralph loop'
alias rhc='ralph clarify'
alias rhret='ralph retrospective'
alias rhi='ralph improvements'

# MiniMax aliases
alias mm='mmc'
alias mml='mmc --loop 30'
alias mmlight='mmc --lightning'
$END_MARKER
RCEOF
    log_success "Shell aliases configured in $SHELL_RC"
}

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFY INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════
verify_installation() {
    log_info "Verifying installation..."

    local ERRORS=0

    [ -x "$INSTALL_DIR/ralph" ] && log_success "ralph CLI installed" || { log_error "ralph not found"; ((ERRORS++)); }
    [ -x "$INSTALL_DIR/mmc" ] && log_success "mmc CLI installed" || { log_error "mmc not found"; ((ERRORS++)); }
    [ -d "${CLAUDE_DIR}/agents" ] && log_success "Agents directory OK" || { log_error "Agents missing"; ((ERRORS++)); }
    [ -d "${CLAUDE_DIR}/commands" ] && log_success "Commands directory OK" || { log_error "Commands missing"; ((ERRORS++)); }
    [ -x "${CLAUDE_DIR}/hooks/git-safety-guard.py" ] && log_success "Git Safety Guard installed (ACTIVE)" || log_warn "Git Safety Guard may need chmod +x"
    [ -x "${CLAUDE_DIR}/hooks/quality-gates.sh" ] && log_success "Quality Gates installed" || log_warn "Quality Gates may need chmod +x"
    [ -f "${CLAUDE_DIR}/settings.json" ] && log_success "Settings with hooks configured" || log_warn "Settings.json missing"
    [ -d "${RALPH_DIR}/logs" ] && log_success "Hybrid logging directory ready" || log_warn "Logs directory missing"

    return $ERRORS
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  🎭 Multi-Agent Ralph Wiggum v${VERSION} - Global Installer"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  This will install:"
    echo "    • ralph CLI to ~/.local/bin/"
    echo "    • mmc (MiniMax wrapper) to ~/.local/bin/"
    echo "    • 9 agents to ~/.claude/agents/"
    echo "    • 15 commands to ~/.claude/commands/"
    echo "    • 4 skills to ~/.claude/skills/"
    echo "    • Git Safety Guard (blocks destructive commands) - ALWAYS ACTIVE"
    echo "    • Quality Gates (9-language validation) - Manual via 'ralph gates'"
    echo "    • Git Worktree + PR Workflow (v2.20) - 'ralph worktree'"
    echo "    • Hybrid usage logging (global + per-project)"
    echo "    • Security hardening (VULN-001 to VULN-008 fixes) - v2.19"
    echo "    • Shell aliases to ~/.zshrc or ~/.bashrc"
    echo ""

    read -p "  Continue? [Y/n] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]?$ ]]; then
        echo "  Aborted."
        exit 0
    fi

    echo ""

    check_dependencies
    backup_existing
    create_directories
    install_scripts
    install_claude_components
    install_codex_config
    install_gemini_config
    install_config
    configure_shell

    echo ""

    if verify_installation; then
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "  ${GREEN}✅ INSTALLATION COMPLETE${NC}"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "  Next steps:"
        echo ""
        echo "  1. Reload your shell:"
        echo "     ${CYAN}source ~/.zshrc${NC}  (or ~/.bashrc)"
        echo ""
        echo "  2. (Optional) Configure MiniMax for 2-4x iterations:"
        echo "     ${CYAN}mmc --setup${NC}"
        echo ""
        echo "  3. Start using Ralph:"
        echo "     ${CYAN}ralph help${NC}"
        echo "     ${CYAN}ralph orch \"Your task here\"${NC}"
        echo ""
        echo "  4. Run quality gates manually when needed:"
        echo "     ${CYAN}ralph gates${NC}"
        echo ""
        echo "  5. View usage statistics (hybrid logging):"
        echo "     ${CYAN}mmc --stats all${NC}      # Global + project"
        echo "     ${CYAN}mmc --stats project${NC}  # This repo only"
        echo ""
        echo "  6. (v2.20) Install WorkTrunk for git worktree workflow:"
        echo "     ${CYAN}brew install max-sixty/worktrunk/wt${NC}"
        echo "     ${CYAN}wt config shell install${NC}"
        echo "     ${CYAN}ralph worktree \"your feature\"${NC}"
        echo ""
        echo "  To uninstall:"
        echo "     ${CYAN}ralph --uninstall${NC}  or  ${CYAN}./uninstall.sh${NC}"
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
    else
        echo ""
        log_error "Installation completed with errors. Check messages above."
        exit 1
    fi
}

main "$@"
