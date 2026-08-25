#!/usr/bin/env bash
# build-skill-index.sh — Enumerate skills available to the model.
#
# v3.1.0 (T52): refactored out of the smart-skill-reminder hook context.
# Now a standalone enumerator. No dependency on SMART_SKILL_INDEX, no
# hook-specific assumptions.
#
# WHAT IT DOES
#   Walks the two roots where the model can actually invoke a skill:
#     - ~/.claude/skills/*/SKILL.md   (global, may include symlinks to
#       ~/.agents/skills which is the user's actual store)
#     - ${CLAUDE_PROJECT_DIR:-.}/.claude/skills/*/SKILL.md  (project)
#   And writes a TSV that records: (1) basename, (2) match tokens,
#   (3) description (truncated to 80 chars), (4) full path.
#
#   This TSV is the correct "what skills can the model invoke" answer.
#   Any consumer (a hook, a lint check, a CLI command) can use it as
#   the source of truth — it is derived from the filesystem, not from
#   any hand-coded list.
#
# WHY TWO ROOTS, AND NO MORE
#   Per lead's guidance after T49: the index contains "what the model
#   can INVOKE, not what exists in the filesystem". Adding a third root
#   like ~/.agents/skills would surface 106 additional skills that exist
#   in the user's actual store but that Claude Code does not load —
#   suggesting them would be a soft variant of the same violation T49
#   was meant to prevent (inventing a skill the model cannot actually
#   use). The user's choice to symlink or not is theirs; we honour
#   the two roots Claude Code actually loads from.
#
# CAVEAT: MATCHING BY EXTENSION IS NOT A GOOD SIGNAL
#   The match-tokens column extracts file extensions mentioned in each
#   skill's description (e.g. ".py", ".ts", ".go"). For any file with
#   that extension, every skill whose description mentions it is a
#   candidate. With 60+ skills, a single `.py` edit could match
#   multiple skills; the order of the match is the order of the file
#   walk, which is alphabetical on most filesystems. That means the
#   effective "selector" of a substring-extension match is the index
#   order, NOT the skill's relevance. A future selector built on this
#   index must use relevance scoring (or a curated set of tokens per
#   skill) instead of a single substring match.
#
#   Concrete example (measured by zc during T49 review): editing a
#   single `.py` file would surface as candidates every skill whose
#   description mentions `.py`. With 60+ such skills in the index,
#   the "first match" the matcher returns is the first one in file
#   walk order — which on most filesystems is alphabetical. A user
#   editing `model.py` and getting suggested the alphabetically-first
#   `python-tester` (or similar) is NOT relevance; it is noise with a
#   30-minute cooldown. This is the exact failure mode that retired
#   smart-skill-reminder.sh in T49; do not rebuild a selector on this
#   index without addressing it.
#
# TWO ROOTS scanned:
#   - ~/.claude/skills/*/SKILL.md
#   - <project>/.claude/skills/*/SKILL.md
# Dirs starting with `~` are skipped (literal-name marker convention).
#
# REGENERATION: only rebuilds if any root's mtime is newer than the
# index file. Zero tokens cost (CPU local only).
#
# USAGE
#   bash build-skill-index.sh                  # writes to default path
#   SKILL_INDEX_OUT=/path bash build-skill-index.sh   # custom output
#   SKILL_INDEX_OUT=/path touch /path           # external caller triggers

set -euo pipefail
umask 077

# SKILL_INDEX_OUT allows callers (lint, CI) to redirect the output
# without touching the default. Default stays the original cache path so
# the v3.0 hook (now retired) could still read the index it expects.
: "${SKILL_INDEX_OUT:=${HOME}/.ralph/cache/skill-index.tsv}"
readonly INDEX_FILE="${SKILL_INDEX_OUT}"
INDEX_DIR="$(dirname "$INDEX_FILE")"
mkdir -p "$INDEX_DIR" 2>/dev/null || exit 1

GLOBAL_ROOT="${HOME}/.claude/skills"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}/.claude/skills"

# Extract a single-line description from a SKILL.md, max 80 chars.
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

# Extract match tokens from the description ONLY (not whole SKILL.md).
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

# Helper: should we regenerate? Uses `find -L` so symlinked SKILL.md
# (e.g. ~/.claude/skills/foo -> ~/.agents/skills/foo) report the TARGET
# file's mtime, not the symlink's. Without -L, an edit to a symlinked
# skill's actual SKILL.md would not bump the index (the symlink's mtime
# is the symlink creation time, not the target's). The index would
# silently go stale on the symlinked subset, and the symptom would be
# "the suggester rarely suggests symlinked skills" — read as caution,
# not as bug.
#
# Note: macOS BSD find doesn't support -printf, so we use -exec stat
# -f %m per file. The script runs on macOS today (per its umask 077
# + portable-stat pattern used elsewhere in the repo).
should_regenerate() {
    [[ ! -f "$INDEX_FILE" ]] && return 0
    local index_mtime
    index_mtime=$(stat -c %Y "$INDEX_FILE" 2>/dev/null || stat -f %m "$INDEX_FILE" 2>/dev/null || echo 0)
    for root in "$GLOBAL_ROOT" "$PROJECT_ROOT"; do
        [[ -d "$root" ]] || continue
        local root_max
        root_max=$(find -L "$root" -name 'SKILL.md' -type f -exec stat -f %m {} \; 2>/dev/null \
            | sort -n | tail -1)
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

# Output: row count (this script is invoked directly or sourced)
wc -l "$INDEX_FILE" 2>/dev/null || echo "0"