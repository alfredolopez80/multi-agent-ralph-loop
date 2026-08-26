#!/usr/bin/env bash
# test_wakeup_broad_recall_retired.sh - Regression test for T74 (#47 C2).
#
# T74: wake-up-layer-stack.sh ran a broad 14-term recall_v2 query on every
#     SessionStart. A startup has no task to direct a query at — any startup
#     query is broad by definition, which is exactly what #47 C2 prohibits.
#     Measured before removal: ~160 tokens + ~110ms per session per subagent,
#     and the block's whole top-10 was already delivered by persistent layers
#     (L1 Essential in the same hook, global proven rules, project
#     auto-memory) — 10/10 covered, zero information added.
#
# Contract under test (v1.1.0): the Top Procedural Rules section is absent
# by default; RALPH_WAKEUP_BROAD_RECALL=true in features.json (annotated
# escape hatch) restores the legacy block. L0 identity and L1 essential
# rules are untouched.
#
# Sandbox-safe: the runner exports HOME to an empty sandbox, so this suite
# provisions its own layers, memory tree (one node, project_id derived by
# the engine's own context_for), and features file. Nothing reads the real
# ~/.ralph — the first version of this test did and failed only under the
# runner, which is how the sandbox was discovered.
#
# Usage: bash tests/hooks/test_wakeup_broad_recall_retired.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1
HOOK=".claude/hooks/wake-up-layer-stack.sh"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d /tmp/t74-wakeup.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# Self-owned sandbox: never touch the real home, run standalone OR under the
# runner's sandbox alike. The hook resolves L0/L1/logs from $HOME.
export HOME="$TMP/home"
mkdir -p "$HOME/.ralph/layers"

# --- Provision: layers, one-node memory tree, features --------------------

printf '# T74 identity marker\nL0MARKER-T74\n' > "$HOME/.ralph/layers/L0_identity.md"
printf '# T74 essential marker\nL1MARKER-T74\n' > "$HOME/.ralph/layers/L1_essential.md"

RALPH_HOME="$TMP/ralph-home" python3 - <<'PY' || { echo "seeding failed"; exit 1; }
import os, sys
from pathlib import Path
sys.path.insert(0, "scripts/memory")
from recall_v2 import context_for
from tree_store import TreeStore

# Same project_id the hook's recall invocation will derive for this repo.
ctx = context_for(Path("."), "", "", "")
store = TreeStore(Path(os.environ["RALPH_HOME"]))
store.create_node({
    "project_id": ctx.project_id,
    "node_id": "rule_t74-broad-recall-marker",
    "workspace_instance_id": "ws-t74",
    "repo_remote_hash": "t74hash",
    "branch": "worktree-zc-2",
    "summary": "hook rule pattern marker for the t74 broad recall suite",
    "sensitivity": "GREEN",
    "authority": "non_authoritative",
    "memory_type": "procedural_rule",
    "source_description": "t74 fixture",
    "quality": {"confidence": 0.9},
    "session_id": "t74-fixture",
    "commit": "t74-fixture",
})
PY

run_hook() {
    # $1 = RALPH_FEATURES_FILE value; output -> stdout
    echo '{"session_id":"t74-test"}' \
        | RALPH_HOME="$TMP/ralph-home" \
          RALPH_FEATURES_FILE="$1" \
          bash "$REPO_ROOT/$HOOK" 2>/dev/null
}

# --- Tests ------------------------------------------------------------------

# 1. Default: broad recall retired — section absent, rest of payload intact.
test_default_has_no_broad_recall() {
    local out
    out=$(run_hook "$TMP/features-absent.json")   # never created: default path
    if grep -q "Top Procedural Rules" <<< "$out"; then
        fail "broad recall block present by default" "section should be retired unless the hatch is set"
    else
        pass "no Top Procedural Rules section by default"
    fi
    if grep -q "L1MARKER-T74" <<< "$out"; then
        pass "L1 essential rules still injected"
    else
        fail "L1 essential rules missing" "the retirement must not touch the curated layer"
    fi
}

# 2. Escape hatch: RALPH_WAKEUP_BROAD_RECALL=true restores the legacy block
#    with the provisioned node in it.
test_hatch_restores_legacy_block() {
    printf '{"RALPH_WAKEUP_BROAD_RECALL": true}' > "$TMP/features-on.json"
    local out
    out=$(run_hook "$TMP/features-on.json")
    # The hook renders "- (score X) <summary> — src: ...", never the node_id,
    # so assert on the section heading plus the fixture's summary marker.
    if grep -q "Top Procedural Rules" <<< "$out" \
       && grep -q "hook rule pattern marker" <<< "$out"; then
        pass "escape hatch restores the broad recall block (node visible)"
    else
        fail "hatch did not restore the block" "features.json true should re-enable the startup query"
    fi
}

# 3. Hatch with the flag explicitly false behaves as default (annotated
#    silence must require a positive true, not just a present key).
test_explicit_false_stays_retired() {
    printf '{"RALPH_WAKEUP_BROAD_RECALL": false}' > "$TMP/features-off.json"
    local out
    out=$(run_hook "$TMP/features-off.json")
    if grep -q "Top Procedural Rules" <<< "$out"; then
        fail "explicit false still shows the block" "only literal true may re-enable"
    else
        pass "explicit false stays retired"
    fi
}

test_default_has_no_broad_recall
test_hatch_restores_legacy_block
test_explicit_false_stays_retired

echo
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
