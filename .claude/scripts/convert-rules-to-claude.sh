#!/bin/bash
# convert-rules-to-claude.sh - Convert procedural rules to Claude Code rules
# VERSION: 2.89.2
#
# Reads ~/.ralph/procedural/rules.json and generates
# ~/.claude/rules/learned/*.md files organized by domain.
#
# Filters: confidence >= 0.7, usage_count >= 3, deduplicated by behavior.
# Uses YAML frontmatter with path scoping per domain.
#
# Can run as:
#   - Manual: ./convert-rules-to-claude.sh
#   - Hook: SessionStart or PreCompact event

set -euo pipefail

RULES_FILE="$HOME/.ralph/procedural/rules.json"
OUTPUT_DIR="$HOME/.claude/rules/learned"
CHECKSUM_FILE="$HOME/.ralph/state/rules-checksum"
LOG_FILE="$HOME/.ralph/logs/rules-conversion.log"

mkdir -p "$OUTPUT_DIR" "$HOME/.ralph/state" "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

if [[ ! -f "$RULES_FILE" ]]; then
    log "No rules file at $RULES_FILE"
    exit 0
fi

# Skip if rules haven't changed
CURRENT_CHECKSUM=$(shasum -a 256 "$RULES_FILE" | cut -d' ' -f1)
if [[ -f "$CHECKSUM_FILE" ]]; then
    PREV_CHECKSUM=$(cat "$CHECKSUM_FILE")
    if [[ "$CURRENT_CHECKSUM" == "$PREV_CHECKSUM" ]]; then
        log "Rules unchanged, skipping"
        if [[ -n "${CLAUDE_HOOK_EVENT:-}" ]]; then
            echo '{"continue": true}'
        fi
        exit 0
    fi
fi

log "Starting conversion from $RULES_FILE"

# Domain -> path mapping (function instead of associative array for Bash 3.2)
get_paths() {
    case "$1" in
        hooks)    echo '.claude/hooks/**/*.sh,.claude/hooks/**/*.py' ;;
        testing)  echo 'tests/**/*,**/*test*,**/*spec*' ;;
        frontend) echo 'src/components/**/*,src/pages/**/*,**/*.tsx,**/*.jsx' ;;
        backend)  echo 'src/services/**/*,src/api/**/*,src/controllers/**/*,**/*.ts' ;;
        database) echo '**/migrations/**/*,**/schema*,**/models/**/*,**/*.sql' ;;
        security) echo '.claude/hooks/**/*security*,**/*auth*,**/*guard*' ;;
        devops)   echo 'Dockerfile*,docker-compose*,.github/**/*,**/deploy*' ;;
        *)        echo '' ;;
    esac
}

# Capitalize first letter (Bash 3.2 compatible)
capitalize() {
    echo "$1" | awk '{print toupper(substr($0,1,1)) substr($0,2)}'
}

# Get unique domains from high-value rules
DOMAINS=$(jq -r '[.rules[] | select(
    (.confidence // 0) >= 0.7 and
    (.usage_count // 0) >= 3 and
    .behavior != null and
    .behavior != ""
)] | [unique_by(.behavior)[]] | [.[] | .domain // "general"] | unique | .[]' "$RULES_FILE" 2>/dev/null)

TOTAL_RULES=0
TOTAL_FILES=0

for domain in $DOMAINS; do
    RULES=$(jq --arg d "$domain" '[.rules[] | select(
        (.domain // "general") == $d and
        (.confidence // 0) >= 0.7 and
        (.usage_count // 0) >= 3 and
        .behavior != null and
        .behavior != ""
    )] | unique_by(.behavior) | sort_by(-.usage_count)' "$RULES_FILE" 2>/dev/null)

    RULE_COUNT=$(echo "$RULES" | jq 'length')

    if [[ "$RULE_COUNT" -eq 0 ]]; then
        continue
    fi

    OUTPUT_FILE="$OUTPUT_DIR/${domain}.md"
    PATHS=$(get_paths "$domain")
    DOMAIN_LABEL=$(capitalize "$domain")

    {
        if [[ -n "$PATHS" ]]; then
            echo "---"
            echo "paths:"
            OLD_IFS="$IFS"
            IFS=','
            set -f
            for p in $PATHS; do
                echo "  - \"$p\""
            done
            set +f
            IFS="$OLD_IFS"
            echo "---"
            echo ""
        fi

        echo "# ${DOMAIN_LABEL} Rules (Auto-learned)"
        echo ""
        echo "Rules from procedural memory. Confidence >= 0.7, usage >= 3."
        echo ""

        # Critical rules first
        HAS_CRITICAL=$(echo "$RULES" | jq '[.[] | select(.severity == "critical")] | length')
        if [[ "$HAS_CRITICAL" -gt 0 ]]; then
            echo "## Critical"
            echo ""
            echo "$RULES" | jq -r '.[] | select(.severity == "critical") | "- " + .behavior' 2>/dev/null
            echo ""
        fi

        echo "## Rules"
        echo ""
        echo "$RULES" | jq -r '.[] | select(.severity != "critical" or .severity == null) | "- " + .behavior' 2>/dev/null
        echo ""

        echo "---"
        echo ""
        echo "*Generated: $(date '+%Y-%m-%d %H:%M'). Source: procedural memory ($RULE_COUNT rules)*"
    } > "$OUTPUT_FILE"

    TOTAL_RULES=$((TOTAL_RULES + RULE_COUNT))
    TOTAL_FILES=$((TOTAL_FILES + 1))
    log "Generated $OUTPUT_FILE ($RULE_COUNT rules)"
done

echo "$CURRENT_CHECKSUM" > "$CHECKSUM_FILE"
log "Done: $TOTAL_RULES rules -> $TOTAL_FILES files in $OUTPUT_DIR"

if [[ -n "${CLAUDE_HOOK_EVENT:-}" ]]; then
    echo '{"continue": true}'
else
    echo "Converted $TOTAL_RULES rules into $TOTAL_FILES domain files at $OUTPUT_DIR"
fi
