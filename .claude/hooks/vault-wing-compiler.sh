#!/bin/bash
# vault-wing-compiler.sh — SessionEnd Hook (Wave 2.1)
# ====================================================
#
# Event: SessionEnd (also fired by the session wake-up path)
# Wave:  W2.1 (project-wings)
#
# Compiles project facts into L2 wing context (Layer2.write).
# Reads today's facts file, deduplicates against existing wing,
# and writes the updated wing.
#
# Input (JSON via stdin): session_id
# Output: none — allow is a silent exit 0 (SessionEnd)
#
# VERSION: 1.1.0
# T54 (#69) fixed THREE independent defects found in the produced wing
# (43 bullets, 9 distinct, 79% filler — paid in tokens at every wake-up):
#   1. DOUBLED PREFIX: the extractor's fact lines already carry
#      "- [category] "; the compiler prepended a second one, so every line
#      shipped "- [cat] - [cat] ..." (43/43). Now the source prefix is
#      stripped before adding exactly one.
#   2. RACE + WEAK DEDUP: the lock covered only the final echo, so N
#      concurrent sessions (a pane's SessionStart plus its subagents fire
#      within seconds) all read the SAME pre-write wing and each appended
#      the same facts — the x3/x6 multiplicities were literally the number
#      of simultaneous sessions per wave. And the dedup key was
#      `cut -c1-60`, which left the file path — the only part that
#      distinguishes two facts — outside the key (the doubled prefix alone
#      ate ~40 chars), silently dropping new facts that shared a prefix
#      with a stored one. Now: the whole read-modify-write runs under the
#      lock, the key is the WHOLE line, and the batch is deduplicated
#      against itself (K copies of one fact in a single facts file used to
#      enter together).
#   3. RETRO-REPAIR: on load, the historical wing is normalized — doubled
#      prefixes collapsed, first occurrence of each line kept — so the
#      accumulated 79% filler disappears on the first post-fix run, without
#      touching artifacts by hand.
# Also fixed: the PROJECT="unknown" fallback was dead (basename of an empty
# string succeeds), so a failed rev-parse silently compiled into
# projects//facts/.

set -euo pipefail
umask 077

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VAULT_DIR="${HOME}/Documents/Obsidian/MiVault"
L2_DIR="${HOME}/.ralph/layers/L2_wings"
LOG_FILE="${HOME}/.ralph/logs/vault-wing-compiler.log"
MAX_WING_ENTRIES=50
VALID_CATEGORIES="code_structure dependencies design_patterns api_patterns"

mkdir -p "${HOME}/.ralph/logs" "${L2_DIR}"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] vault-wing-compiler: $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Read stdin (SEC-111)
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

# ---------------------------------------------------------------------------
# Detect project name
# ---------------------------------------------------------------------------
PROJECT="unknown"
if command -v git &>/dev/null; then
    REPO_ROOT="${HOME}/Documents/GitHub/multi-agent-ralph-loop"
    PROJECT=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "")" 2>/dev/null || echo "unknown")
fi
# T54: the "unknown" fallback above was dead — basename of an empty string
# succeeds with rc 0, so a failed rev-parse produced PROJECT="" and the wing
# silently compiled into projects//facts/. Restore the fallback explicitly.
[[ -z "$PROJECT" ]] && PROJECT="unknown"
: # allow: this hook signals allow with a silent exit 0 (no stdout)

SAFE_PROJECT=$(echo "$PROJECT" | tr -cd 'a-zA-Z0-9_-' | head -c 64)

# ---------------------------------------------------------------------------
# Check for today's facts file
# ---------------------------------------------------------------------------
TODAY=$(date +"%Y%m%d")
FACTS_FILE="${VAULT_DIR}/projects/${PROJECT}/facts/facts-${TODAY}.md"

if [[ ! -f "$FACTS_FILE" ]]; then
    log "INFO no facts file for today: ${FACTS_FILE}"
    : # allow: this hook signals allow with a silent exit 0 (no stdout)
    exit 0
fi

# ---------------------------------------------------------------------------
# Extract categorized facts (filter to valid categories only)
# T54 (#69): the source line ALREADY carries its "- [category] " prefix —
# strip it before adding exactly one, or every line ships a doubled prefix.
# ---------------------------------------------------------------------------
NEW_FACTS=""
while IFS= read -r line; do
    CATEGORY=$(echo "$line" | grep -oE '\[[a-z_]+\]' | tr -d '[]' | head -1)
    if [[ -n "$CATEGORY" ]] && echo " $VALID_CATEGORIES " | grep -q " $CATEGORY "; then
        SAFE_LINE=$(echo "$line" | sed "s|${HOME}/|~/|g" | sed -E 's/^-?[[:space:]]*\[[a-z_]+\][[:space:]]*//' | tr -cd ' a-zA-Z0-9_.:/-()[]{}' | head -c 200)
        NEW_FACTS="${NEW_FACTS}- [${CATEGORY}] ${SAFE_LINE}
"
    fi
done < "$FACTS_FILE"

if [[ -z "$NEW_FACTS" ]]; then
    log "INFO no valid categorized facts found"
    : # allow: this hook signals allow with a silent exit 0 (no stdout)
    exit 0
fi

# ---------------------------------------------------------------------------
# Lock the WHOLE read-modify-write (T54, #69)
# ---------------------------------------------------------------------------
# The lock used to cover only the final echo: N concurrent sessions (a pane's
# SessionStart plus its subagents fire within seconds) all read the SAME
# pre-write wing and each appended the same facts. Everything from the wing
# read to the write now happens under the lock.
WING_DIR="${L2_DIR}/${SAFE_PROJECT}"
WING_FILE="${WING_DIR}/context.md"
mkdir -p "$WING_DIR"

LOCK_DIR="${L2_DIR}/.wing-lock"
LOCK_TRIES=0
LOCK_MAX=50
while [[ -d "$LOCK_DIR" && $LOCK_TRIES -lt $LOCK_MAX ]]; do
    sleep 0.2
    LOCK_TRIES=$((LOCK_TRIES + 1))
done
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "WARN could not acquire lock for wing write — skipping this run"
    : # allow: this hook signals allow with a silent exit 0 (no stdout)
    exit 0
fi
release_lock() { rmdir "$LOCK_DIR" 2>/dev/null || true; }

# ---------------------------------------------------------------------------
# Load existing wing (normalized) and deduplicate — under the lock
# ---------------------------------------------------------------------------
# T54 (#69): normalize the historical wing on load. Two repairs:
#   1. collapse doubled category prefixes the old bug wrote
#      ("- [cat] - [cat] …" -> "- [cat] …") — 43/43 lines had them;
#   2. keep the FIRST occurrence of each line (drops the x3/x6
#      multiplicities accumulated by the read-modify-write race).
# Both apply retroactively on the first post-fix run.
EXISTING=""
if [[ -f "$WING_FILE" ]]; then
    # BSD-sed note: a crossed backreference (\[\1\]) does not match here;
    # capturing the whole first tag and reusing it directly does.
    EXISTING=$(sed -E 's/^(- \[[a-z_]+\]) - \[[a-z_]+\] /\1 /' "$WING_FILE" 2>/dev/null | awk '!seen[$0]++' || echo "")
fi

# Dedup key is the WHOLE line (T54, #69): the path is the identity. The
# `--` guards the pattern: every fact line starts with "- ", which grep
# would otherwise parse as an option (this exact bug made the first fix
# attempt a no-op — every comparison errored, everything looked new).
# Intra-batch dedup: K copies of one fact inside a single facts file
# enter once.
DEDUPED_FACTS=""
while IFS= read -r fact_line; do
    [[ -z "$fact_line" ]] && continue
    if [[ -n "$EXISTING" ]] && grep -qxF -- "$fact_line" <<<"$EXISTING"; then
        continue  # already in the wing
    fi
    if [[ -n "$DEDUPED_FACTS" ]] && grep -qxF -- "$fact_line" <<<"$DEDUPED_FACTS"; then
        continue  # duplicate inside this same batch
    fi
    DEDUPED_FACTS="${DEDUPED_FACTS}${fact_line}
"
done <<< "$NEW_FACTS"

if [[ -z "$DEDUPED_FACTS" ]]; then
    log "INFO all facts already in wing, nothing new"
    release_lock
    : # allow: this hook signals allow with a silent exit 0 (no stdout)
    exit 0
fi

# ---------------------------------------------------------------------------
# Compile new wing content
# ---------------------------------------------------------------------------
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ -z "$EXISTING" ]]; then
    WING_CONTENT="# Wing: ${PROJECT}

**Project**: ${PROJECT}
**Compiled**: ${NOW}
**Source**: vault-wing-compiler.sh (auto-generated)

## Facts

${DEDUPED_FACTS}
"
else
    WING_CONTENT="${EXISTING}

${DEDUPED_FACTS}"
fi

# ---------------------------------------------------------------------------
# FIFO trim: keep only last MAX_WING_ENTRIES lines of facts
# ---------------------------------------------------------------------------
TOTAL_LINES=$(echo "$WING_CONTENT" | wc -l | tr -d ' ')
if [[ $TOTAL_LINES -gt $((MAX_WING_ENTRIES + 10)) ]]; then
    HEADER=$(echo "$WING_CONTENT" | head -6)
    BODY=$(echo "$WING_CONTENT" | tail -n "$MAX_WING_ENTRIES")
    WING_CONTENT="${HEADER}

${BODY}"
    log "INFO trimmed wing from ${TOTAL_LINES} to ~$((MAX_WING_ENTRIES + 6)) lines"
fi

# ---------------------------------------------------------------------------
# Write wing (lock held since before the read)
# ---------------------------------------------------------------------------
echo "$WING_CONTENT" > "$WING_FILE"
release_lock
FACT_COUNT=$(echo "$DEDUPED_FACTS" | grep -c "^-" || echo "0")
log "INFO wing compiled project=${PROJECT} new_facts=${FACT_COUNT}"

: # allow: this hook signals allow with a silent exit 0 (no stdout)
exit 0
