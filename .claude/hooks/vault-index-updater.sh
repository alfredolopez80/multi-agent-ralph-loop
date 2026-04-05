#!/usr/bin/env bash
# vault-index-updater.sh — Auto-regenerates vault index files after each session
# Event: SessionEnd (*)
# VERSION: 3.0.0
#
# Scans the Obsidian vault and updates:
#   - _vault-index.md (root statistics)
#   - global/wiki/_index.md (global wiki article list)
#   - projects/_project-index.md (per-project statistics)
# Prevents stale indices that misrepresent vault contents.

set -euo pipefail
umask 077

# Safety: always output valid JSON for SessionEnd
trap 'echo "{\"decision\": \"approve\"}"' ERR INT TERM

VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"

# Skip if vault doesn't exist
if [[ ! -d "$VAULT_DIR" ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

NOW=$(date +"%Y-%m-%d %H:%M")

# ─────────────────────────────────────────────
# 1. Count global wiki articles by category
# ─────────────────────────────────────────────
GLOBAL_WIKI_DIR="$VAULT_DIR/global/wiki"
GLOBAL_INDEX="$GLOBAL_WIKI_DIR/_index.md"

if [[ -d "$GLOBAL_WIKI_DIR" ]]; then
    {
        echo "# Global Wiki Index"
        echo ""
        echo "Auto-updated: $NOW"
        echo ""

        # Iterate categories (subdirectories)
        while IFS= read -r cat_dir; do
            cat_name=$(basename "$cat_dir")
            [[ "$cat_name" == "_index.md" ]] && continue

            # Count .md files in category
            count=$(find "$cat_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

            if [[ "$count" -gt 0 ]]; then
                echo "## $cat_name ($count articles)"
                while IFS= read -r article; do
                    article_name=$(basename "$article" .md)
                    echo "- [[$cat_name/$article_name]]"
                done < <(find "$cat_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort)
                echo ""
            fi
        done < <(find "$GLOBAL_WIKI_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    } > "$GLOBAL_INDEX" 2>/dev/null || true
fi

# ─────────────────────────────────────────────
# 2. Count per-project stats
# ─────────────────────────────────────────────
PROJECTS_DIR="$VAULT_DIR/projects"
PROJECT_INDEX="$PROJECTS_DIR/_project-index.md"

if [[ -d "$PROJECTS_DIR" ]]; then
    {
        echo "# Project Index"
        echo ""
        echo "Auto-updated: $NOW"
        echo ""

        while IFS= read -r proj_dir; do
            proj_name=$(basename "$proj_dir")
            [[ "$proj_name" == "_project-index.md" ]] && continue

            lessons=0
            wiki_articles=0

            # Count lesson files
            if [[ -d "$proj_dir/lessons" ]]; then
                lessons=$(find "$proj_dir/lessons" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
            fi

            # Count wiki articles
            if [[ -d "$proj_dir/wiki" ]]; then
                wiki_articles=$(find "$proj_dir/wiki" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
            fi

            echo "## $proj_name"
            echo "- Lessons: $lessons"
            echo "- Wiki articles: $wiki_articles"
            echo ""
        done < <(find "$PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    } > "$PROJECT_INDEX" 2>/dev/null || true
fi

# ─────────────────────────────────────────────
# 3. Root vault index with totals
# ─────────────────────────────────────────────
VAULT_INDEX="$VAULT_DIR/_vault-index.md"

total_lessons=$(find "$PROJECTS_DIR" -path "*/lessons/*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
total_wiki_global=$(find "$GLOBAL_WIKI_DIR" -name "*.md" -not -name "_index.md" -type f 2>/dev/null | wc -l | tr -d ' ')
total_wiki_project=$(find "$PROJECTS_DIR" -path "*/wiki/*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
total_projects=$(find "$PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
total_decisions=$(find "$VAULT_DIR/global/decisions" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

{
    echo "# Vault Index"
    echo ""
    echo "Auto-updated: $NOW"
    echo ""
    echo "## Statistics"
    echo "- Total lessons: $total_lessons"
    echo "- Global wiki articles: $total_wiki_global"
    echo "- Project wiki articles: $total_wiki_project"
    echo "- Projects tracked: $total_projects"
    echo "- Decisions: $total_decisions"
    echo ""
    echo "## Global Knowledge"
    echo "- [Global Wiki](global/wiki/_index.md)"
    echo "- [Raw Sources](global/raw/)"
    echo "- [Decisions](global/decisions/)"
    echo ""
    echo "## Projects"
    echo "- [Project Index](projects/_project-index.md)"
} > "$VAULT_INDEX" 2>/dev/null || true

echo '{"decision": "approve"}'
