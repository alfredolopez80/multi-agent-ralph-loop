#!/usr/bin/env bash
# test_cc_mirror_sync.sh - Validate cc-mirror variant synchronization
# Date: 2026-02-15
# Version: v2.90.0

set -euo pipefail

PASS=0
FAIL=0
PRIMARY="$HOME/.claude/settings.json"
ZAI="$HOME/.cc-mirror/zai/config/settings.json"
MINIMAX="$HOME/.cc-mirror/minimax/config/settings.json"

pass() { echo "  PASS: $1"; ((PASS++)) || true; }
fail() { echo "  FAIL: $1"; ((FAIL++)) || true; }

echo "=== CC-Mirror Variant Synchronization Validation ==="
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# 1. JSON Validity
echo "--- JSON Validity ---"
python3 -c "import json; json.load(open('$PRIMARY'))" 2>/dev/null && pass "primary JSON valid" || fail "primary JSON invalid"
python3 -c "import json; json.load(open('$ZAI'))" 2>/dev/null && pass "zai JSON valid" || fail "zai JSON invalid"
python3 -c "import json; json.load(open('$MINIMAX'))" 2>/dev/null && pass "minimax JSON valid" || fail "minimax JSON invalid"

# 2. Field Comparison (using Python with env vars)
echo ""
echo "--- Non-env Field Comparison ---"
export PRIMARY ZAI MINIMAX
python3 -c "
import json, sys, os

primary_path = os.environ['PRIMARY']
zai_path = os.environ['ZAI']
minimax_path = os.environ['MINIMAX']

with open(primary_path) as f:
    primary = json.load(f)
with open(zai_path) as f:
    zai = json.load(f)
with open(minimax_path) as f:
    minimax = json.load(f)

fields = ['hooks', 'enabledPlugins', 'statusLine', 'outputStyle', 'language',
          'alwaysThinkingEnabled', 'plansDirectory', 'skipDangerousModePermissionPrompt', 'mcpToolSearchMode']

errors = 0
for field in fields:
    if field not in primary:
        continue
    for name, variant in [('zai', zai), ('minimax', minimax)]:
        if field not in variant:
            print(f'  FAIL: {name} missing field \"{field}\"')
            errors += 1
        elif field in ['hooks', 'enabledPlugins', 'statusLine']:
            if json.dumps(primary[field], sort_keys=True) == json.dumps(variant[field], sort_keys=True):
                print(f'  PASS: {name} \"{field}\" matches primary')
            else:
                print(f'  FAIL: {name} \"{field}\" differs from primary')
                errors += 1
        elif primary[field] == variant[field]:
            print(f'  PASS: {name} \"{field}\" matches primary')
        else:
            print(f'  FAIL: {name} \"{field}\" = {variant[field]} (expected {primary[field]})')
            errors += 1

# Check variant-specific deny entries preserved
zai_deny = set(zai.get('permissions', {}).get('deny', []))
minimax_deny = set(minimax.get('permissions', {}).get('deny', []))

if 'WebSearch' in zai_deny and 'WebFetch' in zai_deny:
    print('  PASS: zai deny entries preserved (WebSearch, WebFetch)')
else:
    print('  FAIL: zai missing variant-specific deny entries')
    errors += 1

if 'WebSearch' in minimax_deny:
    print('  PASS: minimax deny entries preserved (WebSearch)')
else:
    print('  FAIL: minimax missing variant-specific deny entries')
    errors += 1

sys.exit(1 if errors > 0 else 0)
"

# 3. Skills Symlinks
echo ""
echo "--- Skills Symlinks ---"
if [ -L "$HOME/.cc-mirror/zai/config/skills" ]; then
    target=$(readlink "$HOME/.cc-mirror/zai/config/skills")
    if [ "$target" = "$HOME/.claude/skills" ]; then
        pass "zai skills symlink -> ~/.claude/skills"
    else
        fail "zai skills symlink points to $target"
    fi
else
    fail "zai skills is not a symlink"
fi

if [ -L "$HOME/.cc-mirror/minimax/config/skills" ]; then
    target=$(readlink "$HOME/.cc-mirror/minimax/config/skills")
    if [ "$target" = "$HOME/.claude/skills" ]; then
        pass "minimax skills symlink -> ~/.claude/skills"
    else
        fail "minimax skills symlink points to $target"
    fi
else
    fail "minimax skills is not a symlink"
fi

# 4. Plugin Cache Symlinks
echo ""
echo "--- Plugin Cache Symlinks ---"
if [ -L "$HOME/.cc-mirror/zai/config/plugins/cache" ]; then
    pass "zai plugin cache is symlink"
else
    fail "zai plugin cache is not a symlink"
fi

if [ -L "$HOME/.cc-mirror/minimax/config/plugins/cache" ]; then
    pass "minimax plugin cache is symlink"
else
    fail "minimax plugin cache is not a symlink"
fi

if [ -d "$HOME/.cc-mirror/zai/config/plugins/cache/thedotmack/claude-mem/10.0.6" ]; then
    pass "zai can access claude-mem 10.0.6"
else
    fail "zai cannot access claude-mem plugin"
fi

if [ -d "$HOME/.cc-mirror/minimax/config/plugins/cache/thedotmack/claude-mem/10.0.6" ]; then
    pass "minimax can access claude-mem 10.0.6"
else
    fail "minimax cannot access claude-mem plugin"
fi

# 5. Skill accessibility test
echo ""
echo "--- Skill Accessibility ---"
if [ -f "$HOME/.cc-mirror/zai/config/skills/adversarial/SKILL.md" ]; then
    pass "zai: /adversarial skill accessible"
else
    fail "zai: /adversarial skill NOT accessible"
fi

if [ -f "$HOME/.cc-mirror/minimax/config/skills/adversarial/SKILL.md" ]; then
    pass "minimax: /adversarial skill accessible"
else
    fail "minimax: /adversarial skill NOT accessible"
fi

# 6. CLAUDE.md symlinks
echo ""
echo "--- CLAUDE.md ---"
if [ -L "$HOME/.cc-mirror/zai/config/CLAUDE.md" ]; then
    pass "zai CLAUDE.md symlink exists"
else
    fail "zai CLAUDE.md missing"
fi

if [ -L "$HOME/.cc-mirror/minimax/config/CLAUDE.md" ]; then
    pass "minimax CLAUDE.md symlink exists"
else
    fail "minimax CLAUDE.md missing"
fi

echo ""
echo "=== RESULTS ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "ALL CHECKS PASSED"
    exit 0
else
    echo "SOME CHECKS FAILED"
    exit 1
fi
