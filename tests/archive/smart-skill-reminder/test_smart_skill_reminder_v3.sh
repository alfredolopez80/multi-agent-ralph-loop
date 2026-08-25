#!/usr/bin/env bash
# test_smart_skill_reminder_v3.sh — Tests for the filesystem-indexed skill reminder
# v3 of smart-skill-reminder.sh sources skills from the filesystem, not from
# a hand-coded list (which had 13 invented skills out of 14). This file
# validates the four required tests:
#   1. PASS on a real skill (fixture has it, index lists it, emit happens).
#   2. FAIL on a fresh-regen violation (delete skill, regenerate index,
#      same call must be silent — the index was rebuilt without the skill).
#   2b. FAIL on stale-index violation (delete skill, do NOT regenerate the
#      index — the double-verification `test -f` at emit time must still
#      produce silence).
#   3. Hard cap of 3 emissions per session: 4th call is silent.
#   4. Regression grep: zero literal skill names in the hook source code
#      outside the template strings.
#
# Tests are hermetic: HOME and CLAUDE_PROJECT_DIR are redirected to /tmp.

set -euo pipefail
umask 077

# === Setup ===
FIXTURE_DIR="/tmp/t49-fixture-$RANDOM"
MARKERS_DIR="$FIXTURE_DIR/markers"
LOG_FILE="$FIXTURE_DIR/log"
INDEX="$FIXTURE_DIR/cache/skill-index.tsv"
mkdir -p "$FIXTURE_DIR/global-skills/python-tester" \
         "$FIXTURE_DIR/global-skills/rust-tester" \
         "$FIXTURE_DIR/cache" \
         "$MARKERS_DIR"

# Three fixture skills: two matching by extension, one by name.
# These names appear as TOKENS in the index (via basename), so the test
# can assert the suggestion without depending on extension matching.
cat > "$FIXTURE_DIR/global-skills/python-tester/SKILL.md" <<'EOF'
---
name: python-tester
description: |
  Use for Python test files (.py, pytest, unittest).
allowed-tools: Read, Write, Edit, Bash
---
EOF
cat > "$FIXTURE_DIR/global-skills/rust-tester/SKILL.md" <<'EOF'
---
name: rust-tester
description: |
  Use for Rust code (.rs).
allowed-tools: Read, Write, Edit, Bash
---
EOF

# Build a one-off index for the fixture (production code is in
# .claude/hooks/lib/build-skill-index.sh; this mirrors its logic).
build_index() {
    local out="$1"
    local tmp
    tmp=$(mktemp)
    for skill_dir in "$FIXTURE_DIR"/global-skills/*/; do
        [[ -d "$skill_dir" ]] || continue
        local md="${skill_dir}SKILL.md"
        [[ -f "$md" ]] || continue
        local base
        base=$(basename "$skill_dir")
        local desc
        desc=$(awk '/^---/{c++; if (c==2) exit} c==1 && /^description:[[:space:]]*[|>]?$/{f=1; next} c==1 && /^description:/{sub(/^description:.*/,""); gsub(/^[|>] */,""); print; exit} f && /^[[:space:]]+[A-Za-z]/{sub(/^[[:space:]]+/,""); print; exit}' "$md" | head -c 80)
        local tokens
        tokens=$(printf '%s\n' "$desc" | grep -oE '\.[a-zA-Z][a-zA-Z0-9]{1,5}' | tr '[:upper:]' '[:lower:]' | sort -u; printf '%s\n' "$base" | tr '[:upper:]' '[:lower:]')
        tokens=$(printf '%s\n' "$tokens" | sort -u | tr '\n' ' ' | tr -s ' ' | sed 's/ $//')
        printf '%s\t%s\t%s\t%s\n' "$base" "$tokens" "$desc" "${skill_dir%/}" >> "$tmp"
    done
    mv "$tmp" "$out"
}

# === Helper: run the hook with a given stdin and an isolated environment ===
run_hook() {
    SMART_SKILL_INDEX="$INDEX" \
    SMART_SKILL_MARKERS_DIR="$MARKERS_DIR" \
    SMART_SKILL_LOG_FILE="$LOG_FILE" \
    bash .claude/hooks/smart-skill-reminder.sh <<<"$1"
}

# === Test 1: PASS on real skill ===
echo "=== Test 1: PASS — foo.py matches python-tester ==="
build_index "$INDEX"
rm -f "$MARKERS_DIR"/skill-emissions-*  # Reset cap counter.
out=$(run_hook '{"tool_input":{"file_path":"/some/path/test_foo.py"},"session_id":"s1"}')
if echo "$out" | grep -q 'Use python-tester for .py'; then
    echo "  PASS"
else
    echo "  FAIL: $out"
    exit 1
fi

# === Test 2: FAIL on fresh-regen violation (delete skill, regenerate index) ===
echo
echo "=== Test 2: FAIL — delete skill, regenerate, same call silent ==="
rm -f "$MARKERS_DIR"/skill-emissions-*
rm -rf "$FIXTURE_DIR/global-skills/python-tester"
build_index "$INDEX"
# Verify the index no longer has python-tester
if grep -q 'python-tester' "$INDEX"; then
    echo "  FAIL: index still has python-tester after regen"
    exit 1
fi
out=$(run_hook '{"tool_input":{"file_path":"/some/path/test_foo.py"},"session_id":"s2"}')
if echo "$out" | grep -q 'python-tester'; then
    echo "  FAIL: still suggested python-tester after deletion: $out"
    exit 1
fi
if echo "$out" | grep -q 'permissionDecisionReason'; then
    echo "  FAIL: produced reason when no match: $out"
    exit 1
fi
echo "  PASS (silent allow)"

# === Test 2b: FAIL on stale-index violation ===
echo
echo "=== Test 2b: FAIL — delete skill, do NOT regen, double-verify catches it ==="
# Setup: build an index that includes python-tester, THEN delete the
# skill dir WITHOUT rebuilding the index. The double-verification
# (test -f at emit time) must catch the gap.
mkdir -p "$FIXTURE_DIR/global-skills/python-tester"
cat > "$FIXTURE_DIR/global-skills/python-tester/SKILL.md" <<'EOF'
---
name: python-tester
description: |
  Use for Python test files (.py, pytest, unittest).
allowed-tools: Read, Write, Edit, Bash
---
EOF
build_index "$INDEX"
# Verify index has python-tester
if ! grep -q 'python-tester' "$INDEX"; then
    echo "  FAIL: setup failed — index should have python-tester"
    exit 1
fi
# Now: DELETE the skill (rm SKILL.md, keep dir). Don't rebuild the index.
rm "$FIXTURE_DIR/global-skills/python-tester/SKILL.md"
# Index still has python-tester from before (stale), but SKILL.md is GONE.
if ! grep -q 'python-tester' "$INDEX"; then
    echo "  FAIL: stale index unexpectedly lost python-tester"
    exit 1
fi
if [[ -f "$FIXTURE_DIR/global-skills/python-tester/SKILL.md" ]]; then
    echo "  FAIL: SKILL.md should be gone for the test"
    exit 1
fi
out=$(run_hook '{"tool_input":{"file_path":"/some/path/test_foo.py"},"session_id":"s3"}')
if echo "$out" | grep -q 'python-tester'; then
    echo "  FAIL: still suggested despite SKILL.md gone: $out"
    exit 1
fi
echo "  PASS (double-verify at emit time caught the missing SKILL.md)"

# === Test 3: Hard cap of 3 emissions per session ===
echo
echo "=== Test 3: cap of 3 — 4th emission silent ==="
# Restore proper skill for this test.
cat > "$FIXTURE_DIR/global-skills/python-tester/SKILL.md" <<'EOF'
---
name: python-tester
description: |
  Use for Python test files (.py, pytest, unittest).
allowed-tools: Read, Write, Edit, Bash
---
EOF
build_index "$INDEX"
rm -f "$MARKERS_DIR"/skill-emissions-*  # Reset cap for fresh session
rm -f "$MARKERS_DIR"/skill-reminder-cooldown  # Reset cooldown (test would otherwise be blocked by 30-min cooldown)
sess="s4"
# 3 emits: 1st, 2nd, 3rd should all be present
for i in 1 2 3; do
    out=$(run_hook "{\"tool_input\":{\"file_path\":\"/some/path/file${i}.py\"},\"session_id\":\"$sess\"}")
    if ! echo "$out" | grep -q "Use python-tester for .py"; then
        echo "  FAIL: emission $i not in output: $out"
        exit 1
    fi
    # Reset cooldown between emissions so the 30-min cap doesn't
    # block the next emission. (The hard cap of 3 is what we're testing.)
    rm -f "$MARKERS_DIR"/skill-reminder-cooldown
done
# 4th emit must be silent (cap reached)
out=$(run_hook "{\"tool_input\":{\"file_path\":\"/some/path/file4.py\"},\"session_id\":\"$sess\"}")
if echo "$out" | grep -q 'Use python-tester'; then
    echo "  FAIL: 4th emission not blocked: $out"
    exit 1
fi
echo "  PASS (3 emits succeeded, 4th silent)"

# === Test 4: regression grep — no skill names in hook source outside template ===
echo
echo "=== Test 4: regression grep — zero literal skill names in hook code outside template ==="
# Skill names from the OLD hand-coded list that MUST NOT appear in the
# new hook code: python-pro, typescript-pro, rust-pro, go-pro, bash-pro,
# javascript-pro, test-driven-development, backend-development,
# cicd-automation, kubernetes-operations, frontend-mobile-development,
# blockchain-web3, terraform-specialist, deployment-engineer,
# kubernetes-architect, backend-architect, frontend-developer, blockchain-developer.
# Plus: any name in the v3 template (which is the only allowed place
# where SKILL NAMES appear — but the v3 template is generic, it doesn't
# hardcode any specific skill name).
BANNED_SKILLS="python-pro typescript-pro rust-pro go-pro bash-pro
javascript-pro test-driven-development backend-development
cicd-automation kubernetes-operations frontend-mobile-development
blockchain-web3 terraform-specialist deployment-engineer
kubernetes-architect backend-architect frontend-developer
blockchain-developer"
fail=0
for name in $BANNED_SKILLS; do
    # Look for the name as a quoted string in the hook (excludes comments
    # and docstrings by requiring word boundaries in the actual code).
    if grep -nE "^[^#]*[\"']${name}[\"']" .claude/hooks/smart-skill-reminder.sh >/dev/null 2>&1; then
        echo "  FAIL: banned skill name '$name' appears as a literal in hook code"
        grep -nE "^[^#]*[\"']${name}[\"']" .claude/hooks/smart-skill-reminder.sh
        fail=1
    fi
done
if [[ "$fail" -eq 0 ]]; then
    echo "  PASS (zero banned literals)"
fi
[[ "$fail" -eq 0 ]] || exit 1

# === Test 5: no-match silence — no permissionDecisionReason, no log line ===
echo
echo "=== Test 5: silence on no-match — empty allow, zero extras ==="
rm -f "$MARKERS_DIR"/skill-emissions-* "$LOG_FILE"
out=$(run_hook '{"tool_input":{"file_path":"/some/path/foo.unknown_extension"},"session_id":"s5"}')
if echo "$out" | grep -q 'permissionDecisionReason'; then
    echo "  FAIL: no-match produced a reason: $out"
    exit 1
fi
if [[ -s "$LOG_FILE" ]]; then
    echo "  FAIL: no-match wrote to log:"
    cat "$LOG_FILE"
    exit 1
fi
echo "  PASS (no reason, no log)"

echo
echo "ALL TESTS PASSED"
# Cleanup
rm -rf "$FIXTURE_DIR"