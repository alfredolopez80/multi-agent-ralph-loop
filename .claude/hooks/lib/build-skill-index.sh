#!/usr/bin/env bash
# build-skill-index.sh — Build a filesystem-derived TSV of all available skills.
#
# v3.0.0: Replaces the hand-coded 14-skill list in smart-skill-reminder.sh
# (13 of which were invented, never existed). The index is built from the
# actual filesystem: each row is one skill that has a SKILL.md file.
#
# Output: ~/.ralph/cache/skill-index.tsv with columns:
#   1. basename (NEVER the YAML `name` field — 15 skills have name != basename)
#   2. match tokens (file extensions + key terms, space-separated, lowercase)
#   3. description (truncated to 80 chars)
#   4. full path to the skill dir (used for double-verification at emit time)
#
# Regeneration policy: only rebuild if any root's mtime is newer than the
# index file. Zero tokens cost (CPU local only).
#
# Two roots are scanned:
#   - ~/.claude/skills/*/SKILL.md  (global)
#   - <repo>/.claude/skills/*/SKILL.md  (project)
# Dirs starting with `~` are skipped (literal-name marker convention).

set -euo pipefail
umask 077

readonly INDEX_FILE="${HOME}/.ralph/cache/skill-index.tsv"
INDEX_DIR="$(dirname "$INDEX_FILE")"
mkdir -p "$INDEX_DIR" 2>/dev/null || exit 1

GLOBAL_ROOT="${HOME}/.claude/skills"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}/.claude/skills"

# Helper: extract match tokens from the description ONLY (not whole SKILL.md).
# Otherwise code examples inflate the index with random .xxx tokens.
extract_tokens() {
    local skill_md="$1"
    local dir_name="$2"
    local desc
    desc=$(extract_description "$skill_md")
    # File extensions in the description: .py, .ts, .go, .rs, .sol, .yaml, etc.
    printf '%s\n' "$desc" | grep -oE '\.[a-zA-Z][a-zA-Z0-9]{1,5}' 2>/dev/null \
        | tr '[:upper:]' '[:lower:]' | sort -u
    # Plus the basename as a token (so skill name == dir name can match)
    printf '%s\n' "$dir_name" | tr '[:upper:]' '[:lower:]'
}

# Helper: extract a single-line description, max 80 chars
extract_description() {
    local skill_md="$1"
    awk '
        /^---$/ {c++; if (c==2) exit; next}
        c==1 && /^description:[[:space:]]*[|>]?$/ {flag=1; next}
        c==1 && /^description:[[:space:]]*/ {
            sub(/^description:[[:space:]]*/, "")
            gsub(/^[|>][[:space:]]*/, "")
            print
            exit
        }
        # Indented continuation line under `description: |`. Match by leading
        # whitespace followed by alpha (NOT anchored to ^, since the line
        # starts with spaces).
        flag && /^[[:space:]]+[A-Za-z]/ {sub(/^[[:space:]]+/, ""); print; exit}
    ' "$skill_md" 2>/dev/null | head -c 80 | tr '\n' ' ' | tr -s ' '
}

# Helper: should we regenerate? If index is newer than all roots, skip.
should_regenerate() {
    [[ ! -f "$INDEX_FILE" ]] && return 0
    local index_mtime
    index_mtime=$(stat -c %Y "$INDEX_FILE" 2>/dev/null || stat -f %m "$INDEX_FILE" 2>/dev/null || echo 0)
    for root in "$GLOBAL_ROOT" "$PROJECT_ROOT"; do
        [[ -d "$root" ]] || continue
        local root_max
        root_max=$(find "$root" -name 'SKILL.md' -type f -printf '%T@\n' 2>/dev/null \
            | sort -n | tail -1 | cut -d. -f1)
        [[ -z "$root_max" ]] && continue
        if [[ "$root_max" -gt "$index_mtime" ]]; then
            return 0
        fi
    done
    return 1
}

# Build the index
build_index() {
    tmp=$(mktemp)
    for root in "$GLOBAL_ROOT" "$PROJECT_ROOT"; do
        [[ -d "$root" ]] || continue
        for skill_dir in "$root"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_md="${skill_dir}SKILL.md"
            [[ -f "$skill_md" ]] || continue
            local dir_name
            dir_name=$(basename "$skill_dir")
            # Skip dirs starting with `~` (literal-name marker convention)
            [[ "$dir_name" == ~* ]] && continue
            local desc tokens
            desc=$(extract_description "$skill_md")
            tokens=$(extract_tokens "$skill_md" "$dir_name" | tr '\n' ' ' | tr -s ' ' | sed 's/ $//')
            printf '%s\t%s\t%s\t%s\n' "$dir_name" "$tokens" "$desc" "${skill_dir%/}"
        done
    done > "$tmp"
    mv "$tmp" "$INDEX_FILE"
}

if should_regenerate; then
    build_index
fi

# Output: report (this script is run by the hook or invoked directly)
wc -l "$INDEX_FILE" 2>/dev/null || echo "0"