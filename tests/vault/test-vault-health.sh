#!/usr/bin/env bash
# test-vault-health.sh — Validates the entire auto-learning vault pipeline
# VERSION: 3.0.0
#
# Tests:
# 1. Vault directory structure exists
# 2-5. (graduation / index-updater / accumulator / registration checks
#       removed by #69 Slice D along with the hooks they asserted on)
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
echo "▸ 2-5. removed by #69 Slice D — graduation / index-updater / accumulator / registration"
# ─────────────────────────────────────────────
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
