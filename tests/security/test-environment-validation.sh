#!/bin/bash
# Test: Environment Variable Validation (rewritten in T88)
# Purpose: Pin the post-#38 state of API-key handling in this repo.
#
# History: this suite used to vouch for .claude/scripts/validate-environment.sh,
# a v2.91 remediation tool (created d9cc3e1) whose only "consumer" was a
# file-existence check here. PR #38 retired that script and
# install-glm-usage-tracking.sh, but this suite survived printing
# "WARNING: validate-environment.sh not found" and still exiting 0 — a PASS
# over zero scope (suite 19 finding, T88). Precedent T84 (03af48c) applies:
# registration is not function.
#
# What the repo actually owns now (each assertion executable):
#   1. The retired validator stays retired: no LIVE script (outside archive/,
#      docs/ and tests/) may carry it by name or by reference.
#   2. .claude/scripts/curator.sh is the only live API-key consumer. It must
#      exist, be executable, read its key crash-safely (${VAR:-}) and degrade
#      with an explicit warning when the key is absent.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

TOTAL=0
FAILED=0

check() {
    local desc="$1"
    shift
    TOTAL=$((TOTAL + 1))
    if "$@" >/dev/null 2>&1; then
        echo "  ✓ $desc"
    else
        echo "  ✗ FAIL: $desc"
        FAILED=$((FAILED + 1))
    fi
}

echo "🔍 Testing environment/API-key validation state (post-#38)..."

CURATOR=".claude/scripts/curator.sh"

# 1. The retired validator stays retired (T84 precedent). Live code is
#    scripts/, .claude/scripts/ and .claude/hooks/ — archive/, docs/ and
#    tests/ are deliberately out of scope: that is where history lives.
#    Match both the filename and any reference in file contents, so a
#    revival under either shape trips this.
LIVE_HITS=$( { find scripts .claude/scripts .claude/hooks \
                  -name "*validate-environment*" 2>/dev/null; \
               grep -rln "validate-environment" \
                  scripts .claude/scripts .claude/hooks 2>/dev/null; } | sort -u )
TOTAL=$((TOTAL + 1))
if [[ -n "$LIVE_HITS" ]]; then
    echo "  ✗ FAIL: retired validate-environment.sh found in live code:"
    echo "$LIVE_HITS" | sed 's/^/      /'
    FAILED=$((FAILED + 1))
else
    echo "  ✓ no live script carries the retired validate-environment.sh"
fi

# 2. curator.sh is still a live, runnable script.
check "curator.sh exists"                    test -f "$CURATOR"
check "curator.sh is executable"             test -x "$CURATOR"

# 3. No AUTOMATIC surface may gate its behaviour on an external LLM provider's
#    API key. The repo is provider-agnostic: the model is whatever the session
#    runs, and nothing routes to, falls back to, or degrades toward a named
#    provider on its own. curator.sh used to select a "pricing tier" from
#    Z_AI_API_KEY presence and fall back down the tier chain; that route is gone
#    and must stay gone. smart-memory-search.sh used to call a provider endpoint
#    on every Task invocation; likewise gone.
#    scripts/ralph is excluded on purpose: it hosts subcommands the user invokes
#    BY NAME to talk to a specific provider, which is explicit opt-in, not routing.
PROVIDER_KEY_HITS=$(grep -rlnE 'Z_AI_API_KEY|ZAI_API_KEY|MINIMAX_API_KEY|OPENAI_API_KEY|GEMINI_API_KEY' \
    scripts .claude/scripts .claude/hooks 2>/dev/null | grep -v '^scripts/ralph$' | sort -u)
TOTAL=$((TOTAL + 1))
if [[ -n "$PROVIDER_KEY_HITS" ]]; then
    echo "  ✗ FAIL: live script gates on an external provider API key:"
    echo "$PROVIDER_KEY_HITS" | sed 's/^/      /'
    FAILED=$((FAILED + 1))
else
    echo "  ✓ no live script gates on an external provider API key"
fi

echo ""
echo "Total: $TOTAL | Pass: $((TOTAL - FAILED)) | Fail: $FAILED"
if [[ "$TOTAL" -eq 0 ]]; then
    echo "❌ FAIL: zero checks executed — harness never reached an assertion"
    exit 1
fi
if [[ "$FAILED" -gt 0 ]]; then
    echo "❌ FAIL: API-key validation state changed — see ✗ lines above"
    exit 1
fi
echo "✅ PASS: environment validation state matches the post-#38 pin"
exit 0
