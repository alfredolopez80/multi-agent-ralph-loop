#!/usr/bin/env bash
# test-vault-health.sh — Validates the entire auto-learning vault pipeline
# VERSION: 3.0.0
#
# Tests:
# 1. Vault directory structure exists
# 2. vault-graduation.sh executes without errors and counter works
# 3. vault-index-updater.sh regenerates indices correctly
# 4. session-accumulator.sh writes to correct project buffer
# 5. Hooks are registered globally in all settings.json
# 6. Wikilinks in articles resolve to existing files
# 7. Frontmatter YAML is well-formed in wiki articles

set -euo pipefail

VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
HOOKS_DIR="$REPO_ROOT/.claude/hooks"
PASS=0
FAIL=0
WARN=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN + 1)); }

echo "╔══════════════════════════════════════════════╗"
echo "║  Vault Auto-Learning Health Check v3.0.0     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────
echo "▸ 1. Vault directory structure"
# ─────────────────────────────────────────────
[[ -d "$VAULT_DIR" ]] && pass "Vault root exists: $VAULT_DIR" || fail "Vault root missing: $VAULT_DIR"
[[ -d "$VAULT_DIR/global/wiki" ]] && pass "Global wiki exists" || fail "Global wiki missing"
[[ -d "$VAULT_DIR/projects" ]] && pass "Projects dir exists" || fail "Projects dir missing"
[[ -f "$VAULT_DIR/_vault-index.md" ]] && pass "Root index exists" || fail "Root index missing"
[[ -f "$VAULT_DIR/_templates/vault-entry.md" ]] && pass "Template exists" || fail "Template missing"
echo ""

# ─────────────────────────────────────────────
echo "▸ 2. vault-graduation.sh — subshell fix validation"
# ─────────────────────────────────────────────
GRAD_HOOK="$HOOKS_DIR/vault-graduation.sh"
if [[ -f "$GRAD_HOOK" ]]; then
    pass "vault-graduation.sh exists"

    # Check it uses process substitution, not pipe
    if grep -q 'done < <(find' "$GRAD_HOOK"; then
        pass "Uses process substitution (no subshell bug)"
    else
        fail "Still uses pipe pattern (subshell bug present)"
    fi

    # Check umask
    if grep -q 'umask 077' "$GRAD_HOOK"; then
        pass "Has umask 077"
    else
        fail "Missing umask 077"
    fi

    # Check input sanitization
    if grep -q "tr -cd" "$GRAD_HOOK"; then
        pass "Has input sanitization (tr -cd)"
    else
        warn "Missing input sanitization"
    fi

    # Execute and check output
    output=$(cd "$REPO_ROOT" && bash "$GRAD_HOOK" 2>&1)
    if echo "$output" | grep -q '"hookEventName"'; then
        pass "Executes and returns valid JSON"
    else
        fail "Execution failed or invalid JSON: $output"
    fi
else
    fail "vault-graduation.sh not found"
fi
echo ""

# ─────────────────────────────────────────────
echo "▸ 3. vault-index-updater.sh — index freshness"
# ─────────────────────────────────────────────
IDX_HOOK="$HOOKS_DIR/vault-index-updater.sh"
if [[ -f "$IDX_HOOK" ]]; then
    pass "vault-index-updater.sh exists"

    # Execute
    output=$(bash "$IDX_HOOK" 2>&1)
    if echo "$output" | grep -q '"decision"'; then
        pass "Executes and returns valid JSON"
    else
        fail "Execution failed: $output"
    fi

    # Verify indices were updated (check timestamp contains today's date)
    TODAY=$(date +"%Y-%m-%d")
    if grep -q "$TODAY" "$VAULT_DIR/_vault-index.md" 2>/dev/null; then
        pass "Root index updated today ($TODAY)"
    else
        fail "Root index is stale"
    fi

    if grep -q "$TODAY" "$VAULT_DIR/global/wiki/_index.md" 2>/dev/null; then
        pass "Global wiki index updated today"
    else
        fail "Global wiki index is stale"
    fi

    # Verify counts are non-zero
    total_articles=$(grep "Global wiki articles:" "$VAULT_DIR/_vault-index.md" | grep -oE '[0-9]+')
    if [[ -n "$total_articles" && "$total_articles" -gt 0 ]]; then
        pass "Global wiki articles count: $total_articles"
    else
        fail "Global wiki articles count is 0 or missing"
    fi
else
    fail "vault-index-updater.sh not found"
fi
echo ""

# ─────────────────────────────────────────────
echo "▸ 4. session-accumulator.sh — multi-project capture"
# ─────────────────────────────────────────────
ACC_HOOK="$HOOKS_DIR/session-accumulator.sh"
if [[ -f "$ACC_HOOK" ]]; then
    pass "session-accumulator.sh exists"

    # Check it detects project name dynamically
    if grep -q 'git rev-parse --show-toplevel' "$ACC_HOOK"; then
        pass "Uses git root for project detection (works for any repo)"
    else
        fail "Hardcoded project name (won't work globally)"
    fi

    # Check it handles non-git directories
    if grep -q "|| echo" "$ACC_HOOK"; then
        pass "Handles non-git directories gracefully"
    else
        warn "May fail in non-git directories"
    fi

    # Count projects with lesson data
    project_count=$(find "$VAULT_DIR/projects" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$project_count" -gt 1 ]]; then
        pass "Capturing data from $project_count projects (multi-repo working)"
    else
        warn "Only $project_count project(s) detected"
    fi
else
    fail "session-accumulator.sh not found"
fi
echo ""

# ─────────────────────────────────────────────
echo "▸ 5. Global hook registration"
# ─────────────────────────────────────────────
SETTINGS_FILES=(
    "$HOME/.claude/settings.json"
    "$HOME/.cc-mirror/minimax/config/settings.json"
)

for sf in "${SETTINGS_FILES[@]}"; do
    sf_name=$(basename "$(dirname "$(dirname "$sf")")")/$(basename "$sf")
    if [[ ! -f "$sf" ]]; then
        fail "$sf_name not found"
        continue
    fi

    # Check each critical hook
    for hook in "vault-graduation.sh" "session-accumulator.sh" "vault-index-updater.sh"; do
        if grep -q "$hook" "$sf" 2>/dev/null; then
            pass "$hook registered in $sf_name"
        else
            fail "$hook NOT registered in $sf_name"
        fi
    done
done
echo ""

# ─────────────────────────────────────────────
echo "▸ 6. Wikilink integrity"
# ─────────────────────────────────────────────
broken_links=0
while IFS= read -r article; do
    # Extract wikilinks [[target]]
    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        # Try to resolve the wikilink
        found=0
        while IFS= read -r candidate; do
            found=1
            break
        done < <(find "$VAULT_DIR" -name "${link}.md" -type f 2>/dev/null)
        if [[ "$found" -eq 0 ]]; then
            warn "Broken wikilink [[$link]] in $(basename "$article")"
            broken_links=$((broken_links + 1))
        fi
    done < <(grep -oP '\[\[\K[^\]]+' "$article" 2>/dev/null)
done < <(find "$VAULT_DIR" -name "*.md" -path "*/wiki/*" -type f 2>/dev/null)

if [[ "$broken_links" -eq 0 ]]; then
    pass "All wikilinks resolve correctly"
else
    warn "$broken_links broken wikilinks found"
fi
echo ""

# ─────────────────────────────────────────────
echo "▸ 7. Frontmatter YAML validation"
# ─────────────────────────────────────────────
bad_frontmatter=0
while IFS= read -r article; do
    # Check article has frontmatter delimiters
    first_line=$(head -1 "$article" 2>/dev/null)
    if [[ "$first_line" != "---" ]]; then
        warn "Missing frontmatter in $(basename "$article")"
        bad_frontmatter=$((bad_frontmatter + 1))
        continue
    fi

    # Check required fields
    for field in "type" "confidence" "category"; do
        if ! grep -q "^${field}:" "$article" 2>/dev/null; then
            warn "Missing '$field' in frontmatter of $(basename "$article")"
            bad_frontmatter=$((bad_frontmatter + 1))
        fi
    done
done < <(find "$VAULT_DIR" -name "*.md" -path "*/wiki/*" -type f 2>/dev/null)

if [[ "$bad_frontmatter" -eq 0 ]]; then
    pass "All wiki articles have valid frontmatter"
else
    warn "$bad_frontmatter frontmatter issues found"
fi
echo ""

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo "╔══════════════════════════════════════════════╗"
echo "║  Results: ✅ $PASS passed  ❌ $FAIL failed  ⚠️  $WARN warnings  ║"
echo "╚══════════════════════════════════════════════╝"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
else
    exit 0
fi
