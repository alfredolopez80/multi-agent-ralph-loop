#!/usr/bin/env bash
# W0.5 — global-uninstall-validation
# Verifies claude-mem is FULLY removed from all known surfaces.
# Reference: .ralph/plans/cheeky-dazzling-catmull.md (Wave 0.5)
#
# Exit codes:
#   0 — all checks passed
#   1 — any check failed (claude-mem residue detected)
#
# Run: bash tests/security/test-claude-mem-removed.sh

set -uo pipefail

PASS=0
FAIL=0
RESULTS=()

check() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        RESULTS+=("FAIL  $name")
        FAIL=$((FAIL + 1))
    else
        RESULTS+=("PASS  $name")
        PASS=$((PASS + 1))
    fi
}

# Inverse check: passes when the condition is TRUE (file/dir absent, etc.)
check_absent() {
    local name="$1"
    local path="$2"
    if [[ ! -e "$path" ]]; then
        RESULTS+=("PASS  $name")
        PASS=$((PASS + 1))
    else
        RESULTS+=("FAIL  $name (still exists: $path)")
        FAIL=$((FAIL + 1))
    fi
}

count_eq_zero() {
    local name="$1"
    local cmd="$2"
    local count
    count=$(eval "$cmd" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" == "0" ]]; then
        RESULTS+=("PASS  $name (count=0)")
        PASS=$((PASS + 1))
    else
        RESULTS+=("FAIL  $name (count=$count)")
        FAIL=$((FAIL + 1))
    fi
}

echo "=== W0.5 Global Uninstall Validation ==="
echo ""

# 1. No running processes
count_eq_zero "no claude-mem processes"   "pgrep -f 'claude-mem' 2>/dev/null"
count_eq_zero "no mcp-server.cjs processes" "pgrep -f 'mcp-server\\.cjs' 2>/dev/null"
count_eq_zero "no worker-service.cjs processes" "pgrep -f 'worker-service\\.cjs' 2>/dev/null"

# 2. No port 37777 listening
count_eq_zero "port 37777 not listening" "lsof -i :37777 2>/dev/null | grep LISTEN"

# 3. No primary data directories
check_absent "~/.claude-mem data dir absent"           "$HOME/.claude-mem"
check_absent "plugin cache (thedotmack) absent"        "$HOME/.claude/plugins/cache/thedotmack/claude-mem"

# 4. No secondary cache locations
check_absent "~/.cache/claude-mem absent"              "$HOME/.cache/claude-mem"
check_absent "~/.local/share/claude-mem absent"        "$HOME/.local/share/claude-mem"
if [[ "$OSTYPE" == "darwin"* ]]; then
    check_absent "macOS Caches/claude-mem absent"      "$HOME/Library/Caches/claude-mem"
    check_absent "macOS App Support/claude-mem absent" "$HOME/Library/Application Support/claude-mem"
fi

# 5. No entries in active settings.json files
for cfg in "$HOME/.claude/settings.json" "$HOME/.cc-mirror/minimax/config/settings.json" "$HOME/.cc-mirror/zai/config/settings.json"; do
    if [[ -f "$cfg" ]]; then
        count_eq_zero "no claude-mem in $(basename "$(dirname "$cfg")")/settings.json" "grep claude-mem '$cfg'"
    fi
done

# 6. No ACTIVE code references in hooks (excluding documentation comments and retrocompat string tags).
# Allowed (after Wave 0):
#   - Paths to ~/Documents/Obsidian/MiVault/migrated-from-claude-mem/  (post-migration data)
#   - .bak / .ARCHIVED files (historical)
#   - Comments explaining the removal: "claude-mem removed", "claude-mem was removed",
#     "pending migration to claude-mem" (stale TODO), "TODO(W4..."
#   - Retrocompat string tag in episodic-auto-convert.sh "supported_sources"
count_eq_zero "no active claude-mem code refs in hooks" \
    "find .claude/hooks -type f ! -name '*.bak' ! -name '*.ARCHIVED' -exec grep -Hn 'claude-mem' {} \\; 2>/dev/null \
        | grep -v 'migrated-from-claude-mem' \
        | grep -v 'pre-claude-mem-removal' \
        | grep -v '# .* claude-mem' \
        | grep -v 'claude-mem removed' \
        | grep -v 'claude-mem was removed' \
        | grep -v '\"claude-mem\",'"

# 7. No mcp__plugin_claude-mem_* in skills/agents
count_eq_zero "no mcp__plugin_claude-mem_ in skills" "grep -rn 'mcp__plugin_claude-mem_' .claude/skills/ 2>/dev/null"
count_eq_zero "no mcp__plugin_claude-mem_ in agents" "grep -rn 'mcp__plugin_claude-mem_' .claude/agents/ 2>/dev/null"

# 8. No <claude-mem-context> XML blocks remaining
count_eq_zero "no <claude-mem-context> blocks in repo" "grep -rln 'claude-mem-context' .claude/ 2>/dev/null"

# 9. Security archive backup exists (W0.1 evidence)
if [[ -d "$HOME/.security-archive" ]] && ls "$HOME/.security-archive"/claude-mem-data-*.tar.gz >/dev/null 2>&1; then
    RESULTS+=("PASS  W0.1 backup exists in ~/.security-archive/")
    PASS=$((PASS + 1))
else
    RESULTS+=("FAIL  W0.1 backup MISSING from ~/.security-archive/")
    FAIL=$((FAIL + 1))
fi

# 10. Obsidian migration data exists (W0.2 evidence)
if [[ -d "$HOME/Documents/Obsidian/MiVault/migrated-from-claude-mem" ]]; then
    RESULTS+=("PASS  W0.2 migration data in Obsidian vault")
    PASS=$((PASS + 1))
else
    RESULTS+=("FAIL  W0.2 migration data MISSING from Obsidian vault")
    FAIL=$((FAIL + 1))
fi

# Print results
echo ""
for r in "${RESULTS[@]}"; do
    echo "  $r"
done
echo ""
echo "=== Summary: $PASS passed / $FAIL failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    echo "❌ Wave 0 NOT complete. Fix failures above before proceeding."
    exit 1
fi
echo "✅ Wave 0 validation PASSED."
exit 0
