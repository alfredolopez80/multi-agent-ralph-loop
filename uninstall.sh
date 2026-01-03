#!/usr/bin/env bash
# uninstall.sh - Multi-Agent Ralph Wiggum Uninstaller
# Removes ralph CLI and all associated configurations
# v2.24: MiniMax MCP integration (web_search + understand_image), 87% cost savings
# v2.23: AST-grep integration for structural code search (~75% token savings)
# v2.22: Tool validation (startup + on-demand), 9 language quality gates
# v2.21: Self-update, pre-merge validation, integrations health check
# v2.20: WorkTrunk + PR workflow, worktree cleanup

set -euo pipefail

VERSION="2.24.0"

# Installation directories
INSTALL_DIR="${HOME}/.local/bin"
RALPH_DIR="${HOME}/.ralph"
CLAUDE_DIR="${HOME}/.claude"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Ralph agents to remove
RALPH_AGENTS=(
    "orchestrator.md"
    "security-auditor.md"
    "code-reviewer.md"
    "test-architect.md"
    "debugger.md"
    "refactorer.md"
    "docs-writer.md"
    "frontend-reviewer.md"
    "minimax-reviewer.md"
)

# Ralph commands to remove
RALPH_COMMANDS=(
    "orchestrator.md"
    "clarify.md"
    "full-review.md"
    "parallel.md"
    "security.md"
    "bugs.md"
    "unit-tests.md"
    "refactor.md"
    "research.md"
    "minimax.md"
    "gates.md"
    "loop.md"
    "adversarial.md"
    "retrospective.md"
    "improvements.md"
)

# Ralph skills to remove
RALPH_SKILLS=(
    "ask-questions-if-underspecified"
    "task-classifier"
    "retrospective"
)

# ═══════════════════════════════════════════════════════════════════════════════
# REMOVE CLI SCRIPTS
# ═══════════════════════════════════════════════════════════════════════════════
remove_scripts() {
    log_info "Removing CLI scripts..."

    [ -f "$INSTALL_DIR/ralph" ] && rm -f "$INSTALL_DIR/ralph" && log_success "Removed ralph"
    [ -f "$INSTALL_DIR/mmc" ] && rm -f "$INSTALL_DIR/mmc" && log_success "Removed mmc"
}

# ═══════════════════════════════════════════════════════════════════════════════
# REMOVE CLAUDE COMPONENTS
# ═══════════════════════════════════════════════════════════════════════════════
remove_claude_components() {
    log_info "Removing Claude Code components..."

    # Remove agents
    for agent in "${RALPH_AGENTS[@]}"; do
        if [ -f "${CLAUDE_DIR}/agents/${agent}" ]; then
            rm -f "${CLAUDE_DIR}/agents/${agent}"
        fi
    done
    log_success "Removed Ralph agents"

    # Remove commands
    for cmd in "${RALPH_COMMANDS[@]}"; do
        if [ -f "${CLAUDE_DIR}/commands/${cmd}" ]; then
            rm -f "${CLAUDE_DIR}/commands/${cmd}"
        fi
    done
    log_success "Removed Ralph commands"

    # Remove skills
    for skill in "${RALPH_SKILLS[@]}"; do
        if [ -d "${CLAUDE_DIR}/skills/${skill}" ]; then
            rm -rf "${CLAUDE_DIR}/skills/${skill}"
        fi
    done
    log_success "Removed Ralph skills"

    # Remove hooks
    [ -f "${CLAUDE_DIR}/hooks/quality-gates.sh" ] && rm -f "${CLAUDE_DIR}/hooks/quality-gates.sh"
    [ -f "${CLAUDE_DIR}/hooks/git-safety-guard.py" ] && rm -f "${CLAUDE_DIR}/hooks/git-safety-guard.py"
    log_success "Removed Ralph hooks (quality-gates.sh, git-safety-guard.py)"

    # Clean settings.json (remove only Ralph entries, preserve user config)
    clean_settings_json
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLEAN SETTINGS.JSON (Remove only Ralph entries, preserve everything else)
# ═══════════════════════════════════════════════════════════════════════════════
clean_settings_json() {
    local SETTINGS="${CLAUDE_DIR}/settings.json"
    local TEMP_CLEAN="${CLAUDE_DIR}/.settings.clean.tmp"

    if [ ! -f "$SETTINGS" ]; then
        log_info "No settings.json to clean"
        return 0
    fi

    # Validate JSON
    if ! jq empty "$SETTINGS" 2>/dev/null; then
        log_warn "settings.json is invalid JSON - skipping cleanup"
        return 0
    fi

    log_info "Cleaning settings.json (removing only Ralph entries)..."

    # Define Ralph-specific patterns to remove
    # Permissions added by Ralph
    RALPH_PERMISSIONS='["Bash(ralph:*)", "Bash(mmc:*)"]'

    # Hook commands added by Ralph
    RALPH_HOOK_COMMANDS='["${HOME}/.claude/hooks/git-safety-guard.py", "${HOME}/.claude/hooks/quality-gates.sh"]'

    jq --argjson ralph_perms "$RALPH_PERMISSIONS" '
    # Remove Ralph-specific permissions from allow array
    if .permissions.allow then
        .permissions.allow = [.permissions.allow[] | select(. as $p | ($ralph_perms | index($p)) | not)]
    else . end |

    # Remove hooks that reference Ralph hook files
    if .hooks.PreToolUse then
        .hooks.PreToolUse = [
            .hooks.PreToolUse[] |
            .hooks = [.hooks[] | select(.command | test("git-safety-guard|quality-gates") | not)] |
            select(.hooks | length > 0)
        ]
    else . end |

    if .hooks.PostToolUse then
        .hooks.PostToolUse = [
            .hooks.PostToolUse[] |
            .hooks = [.hooks[] | select(.command | test("git-safety-guard|quality-gates") | not)] |
            select(.hooks | length > 0)
        ]
    else . end |

    # Clean up empty arrays
    if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end |
    if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end |
    if .hooks == {} then del(.hooks) else . end |
    if .permissions.allow == [] then del(.permissions.allow) else . end |
    if .permissions == {} then del(.permissions) else . end
    ' "$SETTINGS" > "$TEMP_CLEAN" 2>/dev/null

    if jq empty "$TEMP_CLEAN" 2>/dev/null; then
        # Backup original
        cp "$SETTINGS" "${SETTINGS}.ralph-uninstall-backup"
        mv "$TEMP_CLEAN" "$SETTINGS"
        log_success "Settings cleaned:"
        log_success "  - Ralph permissions: REMOVED"
        log_success "  - Ralph hooks: REMOVED"
        log_success "  - Your other settings: PRESERVED"
        log_success "  - Backup: ${SETTINGS}.ralph-uninstall-backup"
    else
        rm -f "$TEMP_CLEAN"
        log_warn "Could not clean settings.json - manual cleanup may be needed"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# REMOVE RALPH DATA
# ═══════════════════════════════════════════════════════════════════════════════
remove_ralph_data() {
    local KEEP_BACKUPS="${1:-false}"

    if [ "$KEEP_BACKUPS" = "true" ]; then
        log_info "Removing Ralph data (keeping backups)..."
        rm -rf "${RALPH_DIR}/config"
        rm -rf "${RALPH_DIR}/logs"
        rm -rf "${RALPH_DIR}/improvements/pending.md"
        log_success "Ralph data removed (backups preserved in ${RALPH_DIR}/backups)"
    else
        log_info "Removing all Ralph data..."
        rm -rf "$RALPH_DIR"
        log_success "All Ralph data removed"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# REMOVE CODEX CONFIG (Only Ralph section, preserve user config)
# ═══════════════════════════════════════════════════════════════════════════════
remove_codex_config() {
    log_info "Removing Codex CLI config..."

    local CODEX_INSTRUCTIONS="${HOME}/.codex/instructions.md"
    local RALPH_START="# === RALPH WIGGUM CODEX CONFIG ==="
    local RALPH_END="# === END RALPH WIGGUM CODEX CONFIG ==="

    if [ -f "$CODEX_INSTRUCTIONS" ]; then
        if grep -q "$RALPH_START" "$CODEX_INSTRUCTIONS" 2>/dev/null; then
            # Remove only Ralph section
            log_info "Removing Ralph section from Codex instructions..."
            local TEMP_FILE="${CODEX_INSTRUCTIONS}.tmp"
            sed "/$RALPH_START/,/$RALPH_END/d" "$CODEX_INSTRUCTIONS" > "$TEMP_FILE"
            mv "$TEMP_FILE" "$CODEX_INSTRUCTIONS"
            log_success "Codex instructions cleaned (your config preserved)"
        else
            log_info "No Ralph section found in Codex instructions"
        fi
    fi

    # Remove Ralph-specific skills
    local RALPH_SKILLS=("security-review" "bug-hunter" "test-generation" "ask-questions-if-underspecified")
    for skill in "${RALPH_SKILLS[@]}"; do
        [ -d "${HOME}/.codex/skills/${skill}" ] && rm -rf "${HOME}/.codex/skills/${skill}"
    done
    log_success "Ralph Codex skills removed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# REMOVE GEMINI CONFIG (Only Ralph section, preserve user config)
# ═══════════════════════════════════════════════════════════════════════════════
remove_gemini_config() {
    log_info "Removing Gemini CLI config..."

    local GEMINI_CONFIG="${HOME}/.gemini/GEMINI.md"
    local RALPH_START="# === RALPH WIGGUM GEMINI CONFIG ==="
    local RALPH_END="# === END RALPH WIGGUM GEMINI CONFIG ==="

    if [ -f "$GEMINI_CONFIG" ]; then
        if grep -q "$RALPH_START" "$GEMINI_CONFIG" 2>/dev/null; then
            # Remove only Ralph section
            log_info "Removing Ralph section from Gemini config..."
            local TEMP_FILE="${GEMINI_CONFIG}.tmp"
            sed "/$RALPH_START/,/$RALPH_END/d" "$GEMINI_CONFIG" > "$TEMP_FILE"
            mv "$TEMP_FILE" "$GEMINI_CONFIG"
            log_success "Gemini config cleaned (your config preserved)"
        else
            log_info "No Ralph section found in Gemini config"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLEAN SHELL CONFIG (Remove only Ralph section with markers)
# ═══════════════════════════════════════════════════════════════════════════════
clean_shell_config() {
    log_info "Cleaning shell configuration..."

    local SHELL_RC=""
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    if [ -z "$SHELL_RC" ]; then
        log_info "No shell config found"
        return 0
    fi

    local START_MARKER="# >>> RALPH WIGGUM START >>>"
    local END_MARKER="# <<< RALPH WIGGUM END <<<"

    # Try new marker-based removal first
    if grep -q "$START_MARKER" "$SHELL_RC" 2>/dev/null; then
        log_info "Removing Ralph section from shell config..."
        local TEMP_FILE="${SHELL_RC}.ralph.tmp"
        sed "/$START_MARKER/,/$END_MARKER/d" "$SHELL_RC" > "$TEMP_FILE"
        mv "$TEMP_FILE" "$SHELL_RC"
        log_success "Shell config cleaned (markers found)"
        return 0
    fi

    # Fallback: Try old-style markers (for v2.14 and earlier)
    if grep -q "# Ralph Wiggum" "$SHELL_RC" 2>/dev/null; then
        log_info "Found legacy Ralph shell config, attempting removal..."
        cp "$SHELL_RC" "${SHELL_RC}.ralph-backup"

        # Try to remove old-style block
        local TEMP_FILE="${SHELL_RC}.ralph.tmp"
        # Remove from "# ═.*Ralph Wiggum" to "alias mmlight" line (inclusive)
        sed '/# ═.*Ralph Wiggum/,/^alias mmlight/d' "$SHELL_RC" > "$TEMP_FILE" 2>/dev/null && \
            mv "$TEMP_FILE" "$SHELL_RC" && \
            log_success "Legacy shell config removed (backup: ${SHELL_RC}.ralph-backup)" && \
            return 0

        # If that didn't work, try simpler pattern
        sed '/# Ralph Wiggum/,/alias mmlight/d' "$SHELL_RC" > "$TEMP_FILE" 2>/dev/null && \
            mv "$TEMP_FILE" "$SHELL_RC" && \
            log_success "Legacy shell config removed (backup: ${SHELL_RC}.ralph-backup)" && \
            return 0

        rm -f "$TEMP_FILE" 2>/dev/null || true
        log_warn "Could not automatically remove shell aliases - manual cleanup may be needed"
        return 0
    fi

    log_info "No Ralph shell config found to remove"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    local KEEP_BACKUPS=false
    local FULL_UNINSTALL=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keep-backups)
                KEEP_BACKUPS=true
                shift
                ;;
            --full)
                FULL_UNINSTALL=true
                shift
                ;;
            --help|-h)
                echo "Usage: uninstall.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --keep-backups   Keep backup files in ~/.ralph/backups"
                echo "  --full           Also remove Codex and Gemini configs"
                echo "  --help           Show this help"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  🎭 Multi-Agent Ralph Wiggum v${VERSION} - Uninstaller"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  This will remove:"
    echo "    • ralph and mmc CLI from ~/.local/bin/"
    echo "    • Ralph agents from ~/.claude/agents/"
    echo "    • Ralph commands from ~/.claude/commands/"
    echo "    • Ralph skills from ~/.claude/skills/"
    echo "    • Ralph hooks from ~/.claude/hooks/"
    echo "    • Ralph data from ~/.ralph/"
    echo "    • Shell aliases from ~/.zshrc or ~/.bashrc"

    if [ "$FULL_UNINSTALL" = "true" ]; then
        echo "    • Codex config from ~/.codex/"
        echo "    • Gemini config from ~/.gemini/"
    fi

    if [ "$KEEP_BACKUPS" = "true" ]; then
        echo ""
        echo "  ${YELLOW}Backups will be preserved${NC}"
    fi

    echo ""
    read -p "  Continue? [y/N] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "  Aborted."
        exit 0
    fi

    echo ""

    remove_scripts
    remove_claude_components
    remove_ralph_data "$KEEP_BACKUPS"

    if [ "$FULL_UNINSTALL" = "true" ]; then
        remove_codex_config
        remove_gemini_config
    fi

    clean_shell_config

    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  ${GREEN}✅ UNINSTALL COMPLETE${NC}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Don't forget to reload your shell:"
    echo "    source ~/.zshrc  (or ~/.bashrc)"
    echo ""

    if [ "$KEEP_BACKUPS" = "true" ]; then
        echo "  Your backups are preserved in: ${RALPH_DIR}/backups/"
        echo ""
    fi

    echo "═══════════════════════════════════════════════════════════════════════════════"
}

main "$@"
