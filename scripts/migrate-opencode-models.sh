#!/bin/bash
# ==============================================================================
# migrate-opencode-models.sh - Migrate Claude models to OpenCode-compatible models
# ==============================================================================
# ⚠️  DEPRECATED v2.69.0: MiniMax is now optional fallback only.
#     GLM-4.7 is PRIMARY for complexity 1-4 tasks.
#     Consider using GLM-4.7 MCP tools instead.
# ==============================================================================
# Replaces Claude model references with OpenAI/GLM equivalents:
#   - model: opus      → model: "gpt-5.2-codex"  (complex/deep reasoning)
#   - model: sonnet    → model: "glm-4.7"        (standard tasks - v2.69.0 PRIMARY)
#   - model: haiku     → model: "glm-4.7"        (fast tasks)
# ==============================================================================

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
OPENCODE_DIR="${HOME}/.config/opencode"
DRY_RUN=false
BACKUP=true
VERBOSE=false

# Counters
TOTAL_FILES=0
TOTAL_REPLACEMENTS=0

# Usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run, -n     Preview changes without modifying files"
    echo "  --no-backup       Don't create backups before modification"
    echo "  --verbose, -v     Show detailed output"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Model Mapping (v2.69.0):"
    echo "  opus   → gpt-5.2-codex (complex/deep reasoning)"
    echo "  sonnet → glm-4.7 (standard tasks - PRIMARY)"
    echo "  haiku  → glm-4.7 (fast tasks)"
    echo ""
    echo "NOTE: MiniMax is DEPRECATED. GLM-4.7 is now PRIMARY for complexity 1-4."
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n) DRY_RUN=true; shift ;;
        --no-backup) BACKUP=false; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) shift ;;
    esac
done

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Header
echo ""
echo "==============================================================="
echo "  OpenCode Model Migration Script"
echo "==============================================================="
echo ""
log_info "Target: $OPENCODE_DIR/"
[ "$DRY_RUN" = true ] && log_warn "DRY RUN MODE - No changes will be made"
echo ""

# Check OpenCode directory exists
if [ ! -d "$OPENCODE_DIR" ]; then
    log_error "OpenCode directory not found: $OPENCODE_DIR"
    exit 1
fi

# Create backup
if [ "$BACKUP" = true ] && [ "$DRY_RUN" = false ]; then
    BACKUP_DIR="${HOME}/.ralph/backups/opencode-models-$(date +%Y%m%d_%H%M%S)"
    log_info "Creating backup at: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    cp -r "$OPENCODE_DIR/agent" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "$OPENCODE_DIR/skill" "$BACKUP_DIR/" 2>/dev/null || true
    log_success "Backup created"
    echo ""
fi

# Process a single file
process_file() {
    local file="$1"
    local changes=0

    # Skip if not a markdown file
    [[ ! "$file" =~ \.(md|MD)$ ]] && return 0

    # Read file content
    local content
    content=$(cat "$file")
    local original="$content"

    # Count occurrences before replacement
    local opus_count sonnet_count haiku_count
    opus_count=$(echo "$content" | grep -c 'model:.*opus' || true)
    sonnet_count=$(echo "$content" | grep -c 'model:.*sonnet' || true)
    haiku_count=$(echo "$content" | grep -c 'model:.*haiku' || true)

    # Apply all replacements using sed (handles both quoted and unquoted)
    # Patterns cover: model: opus, model: "opus", model: 'opus' with any leading whitespace

    # Replace opus → gpt-5.2-codex
    content=$(echo "$content" | sed -E 's/(model:[[:space:]]*)("?)opus("?)/\1"gpt-5.2-codex"/g')

    # Replace sonnet → glm-4.7
    content=$(echo "$content" | sed -E 's/(model:[[:space:]]*)("?)sonnet("?)/\1"glm-4.7"/g')

    # Replace haiku → glm-4.7
    content=$(echo "$content" | sed -E 's/(model:[[:space:]]*)("?)haiku("?)/\1"glm-4.7"/g')

    # Calculate total changes
    changes=$((opus_count + sonnet_count + haiku_count))

    # If changes were made
    if [ "$content" != "$original" ]; then
        TOTAL_FILES=$((TOTAL_FILES + 1))
        TOTAL_REPLACEMENTS=$((TOTAL_REPLACEMENTS + changes))

        local relative_path="${file#$OPENCODE_DIR/}"

        if [ "$DRY_RUN" = true ]; then
            echo "  Would modify: $relative_path ($changes replacements)"
            if [ "$VERBOSE" = true ]; then
                echo "    Changes:"
                diff <(echo "$original") <(echo "$content") | grep "^[<>]" | head -10
            fi
        else
            echo "$content" > "$file"
            log_success "Modified: $relative_path ($changes replacements)"
        fi
    fi
}

# Process agents
log_info "Processing agents..."
if [ -d "$OPENCODE_DIR/agent" ]; then
    for file in "$OPENCODE_DIR/agent"/*.md; do
        [ -f "$file" ] && process_file "$file"
    done
fi

# Process skills
log_info "Processing skills..."
if [ -d "$OPENCODE_DIR/skill" ]; then
    find "$OPENCODE_DIR/skill" -name "*.md" -type f | while read -r file; do
        process_file "$file"
    done
fi

# Update documentation references
log_info "Updating documentation references..."

# Create sed commands for text references
if [ "$DRY_RUN" = false ]; then
    # Update text mentions of Claude models
    find "$OPENCODE_DIR" -name "*.md" -type f -exec sed -i '' \
        -e 's/Claude Sonnet/GLM-4.7/g' \
        -e 's/Claude Opus/GPT-5.2-Codex/g' \
        -e 's/Claude Haiku/GLM-4.7/g' \
        -e 's/Sonnet 4\.5/GLM-4.7/g' \
        -e 's/Opus 4\.5/GPT-5.2-Codex/g' \
        {} \; 2>/dev/null || true
fi

# Summary
echo ""
echo "==============================================================="
echo "  Migration Summary"
echo "==============================================================="

if [ "$DRY_RUN" = true ]; then
    log_info "Would modify: $TOTAL_FILES files"
    log_info "Would make: $TOTAL_REPLACEMENTS model replacements"
    echo ""
    log_warn "Run without --dry-run to apply changes"
else
    log_success "Modified: $TOTAL_FILES files"
    log_success "Made: $TOTAL_REPLACEMENTS model replacements"
    echo ""
    log_info "Model mapping applied:"
    echo "  opus   → gpt-5.2-codex"
    echo "  sonnet → glm-4.7"
    echo "  haiku  → glm-4.7"
    [ "$BACKUP" = true ] && log_info "Backup saved to: $BACKUP_DIR"
fi

# Verification
echo ""
log_info "Verification - Remaining Claude model references:"
REMAINING=$(grep -r "model:.*opus\|model:.*sonnet\|model:.*haiku" "$OPENCODE_DIR" --include="*.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" -eq 0 ]; then
    log_success "No Claude model references remaining!"
else
    log_warn "$REMAINING references still found (may need manual review)"
    grep -r "model:.*opus\|model:.*sonnet\|model:.*haiku" "$OPENCODE_DIR" --include="*.md" 2>/dev/null | head -5
fi

echo ""
