#!/usr/bin/env bash
# test-secrets-write-guard.sh — PR3-C1 (#69 §1B, gap secrets-ordinary-work).
#
# Matrix for .claude/hooks/secrets-write-guard.py (deterministic write-time gate):
#   - each of the 6 closed patterns denies a synthetic secret (Write/Edit/MultiEdit)
#   - normal code allows (type hints, env lookups, short placeholders)
#   - allowlisted paths allow WITH a documented reason
#   - fail-closed: unparseable stdin, writes without path/content
#   - non-write tools are not scanned
#
# ESCAPE HATCH (documented): a false positive is fixed by (a) a versioned
# ALLOWLIST_GLOBS entry in the hook, or (b) fixing the pattern if it is wrong.
# Never by weakening the gate ad hoc — pattern or allowlist changes are code
# review, and this suite pins both.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
HOOK="$REPO_ROOT/.claude/hooks/secrets-write-guard.py"

PASS=0
FAIL=0

# expect <label> <want_decision> <want_exit> <payload-json> [<stdin-raw-instead>]
expect() {
  local label="$1" want_decision="$2" want_exit="$3" payload="$4"
  local out rc decision
  out="$(printf '%s' "$payload" | python3 "$HOOK" 2>/dev/null)"
  rc=$?
  decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "NO_DECISION"' 2>/dev/null)"
  if [[ "$decision" == "$want_decision" && "$rc" == "$want_exit" ]]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    echo "  FAIL: $label (decision=$decision want=$want_decision, rc=$rc want=$want_exit)"
    printf '%s\n' "$out" | head -2 | sed 's/^/    /'
  fi
}

# --- positive matrix: one synthetic secret per closed pattern -> deny/1 -------
expect "PEM private key (Write)"            deny 1 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/app.py","content":"cert = \"\"\"-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA0Z3VS5JJcds3xfn/aGfFz\n-----END RSA PRIVATE KEY-----\"\"\""}}'
expect "OpenAI-style key (Write)"           deny 1 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/app.py","content":"key = \"sk-proj-abcdefghij0123456789ABCDEFGHIJ\""}}'
expect "GitHub PAT (Edit)"                  deny 1 '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/svc/app.py","new_string":"token = \"ghp_abcdefghijklmnopqrstuvwx0123456789ABCD\""}}'
expect "GitHub fine-grained (Write)"        deny 1 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/app.py","content":"t = \"github_pat_11AAAAAAA0abcdefghijklmnopqrstuv\""}}'
expect "AWS access key id (Write)"          deny 1 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/app.py","content":"aws_id = \"AKIAABCDEFGHIJKLMNOP\""}}'
expect "basic-auth URL (Write)"             deny 1 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/app.py","content":"dsn = \"postgres://admin:s3cr3t-p4ssw0rd@db.internal:5432/prod\""}}'
expect "credential assignment (Write)"      deny 1 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/app.py","content":"API_KEY = \"abcdefghijklmnop1234\""}}'
expect "secret in MultiEdit second edit"    deny 1 '{"tool_name":"MultiEdit","tool_input":{"file_path":"/tmp/svc/app.py","edits":[{"new_string":"x = 1"},{"new_string":"password = \"abcdefghijklmnop1234\""}]}}'

# --- negatives: normal code must allow --------------------------------------
expect "type annotation is not a secret"    allow 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/auth.py","content":"def login(password: str) -> bool:\n    return verify(password)\n"}}'
expect "env lookup is not a secret"         allow 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/auth.py","content":"key = os.environ[\"API_KEY\"]\nsecret = config.get(\"secret\")\n"}}'
expect "short placeholder allows"           allow 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/docs.md","content":"API_KEY=your-key-here\n"}}'
expect "plain URL without credentials"      allow 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/db.py","content":"url = \"postgres://db.internal:5432/prod\"\n"}}'
expect "non-write tool is not scanned"      allow 0 '{"tool_name":"Bash","tool_input":{"command":"echo ghp_abcdefghijklmnopqrstuvwx0123456789ABCD"}}'
expect "empty write allows"                 allow 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/empty.py","content":""}}'

# --- prose must allow regardless of which content field carries it -----------
# (RETURN PR3-C1-r2: harmless prose was denied when carried in new_string on a
#  Write — field-name strictness, now fixed by scanning every known field)
expect "pure prose in content allows"       allow 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/probe.py","content":"The sky is blue today."}}'
expect "lead repro: prose in new_string on Write allows" allow 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/probe.py","new_string":"The sky is blue today."}}'
expect "pure prose in Edit allows"          allow 0 '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/probe.py","new_string":"The sky is blue today."}}'

# --- C2 RED classes (owner decisions 2026-08-31) -----------------------------
# R1: mnemonic SEQUENCE denies (N in {12,15,18,21,24} wordlist words on a line).
# Checksum is verified and reported but does NOT gate the deny: a typo'd seed is
# still the target. Scattered list words inside prose must allow.
SEED12="liquid prosper home oyster dance film shift cradle unlock apart arrest swap"
SEED24="olive blind worry turn day predict wrap embrace skirt party erode ghost summer wealth liar stand cute climb distance rough episode elbow indoor cradle"
FIRST12="abandon ability able about above absent absorb abstract absurd abuse access accident"
BADCHK="abandon ability able about above absent absorb abstract absurd abuse access across"
expect "R1 valid 12-word mnemonic denies"     deny 1 "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/tmp/svc/wallet.md\",\"content\":\"backup: $SEED12\"}}"
expect "R1 valid 24-word mnemonic denies"     deny 1 "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/tmp/svc/wallet.md\",\"content\":\"$SEED24\"}}"
expect "R1 canonical BIP-39 vector denies"    deny 1 "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/tmp/svc/wallet.md\",\"content\":\"$FIRST12\"}}"
expect "R1 all-list words with broken checksum denies" deny 1 "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/tmp/svc/wallet.md\",\"content\":\"$BADCHK\"}}"
expect "R1 scattered list words in prose allow" allow 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/probe.py","content":"The abstract about the accident was above suspicion, and the ability to absorb it felt absurd."}}'

# R2: EVM 0x+64hex outside test paths asks (owner accepts web3 friction);
# inside test paths it allows (hash constants are ordinary test data).
expect "R2 EVM hex outside tests asks"        ask 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/web3.py","content":"pk = \"0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318\""}}'
expect "R2 EVM hex inside test path allows"   allow 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/proj/tests/test_web3.py","content":"TX = \"0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318\""}}'

# R3: PII DENSITY asks at threshold (default 10); isolated emails allow.
expect "R3 twelve-email dump asks"            ask 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/export.sql","content":"u1@example.com u2@example.com u3@example.com u4@example.com u5@example.com u6@example.com u7@example.com u8@example.com u9@example.com u10@example.com u11@example.com u12@example.com"}}'
expect "R3 two isolated emails allow"         allow 0 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/config.py","content":"support = \"support@example.com\"\nadmin = \"admin@example.org\"\n"}}'

# R1 instrument integrity: the vendored wordlist must be the real standard list.
WL="$REPO_ROOT/.claude/hooks/secrets-write-guard.bip39-wordlist"
wl_n=$(wc -l < "$WL" | tr -d ' ')
if [[ "$wl_n" == "2048" ]] && LC_ALL=C sort -c "$WL" 2>/dev/null \
   && [[ "$(LC_ALL=C sort "$WL" | uniq -d | wc -l | tr -d ' ')" == "0" ]] \
   && [[ "$(grep -cvE '^[a-z]+$' "$WL")" == "0" ]]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); echo "  FAIL: BIP-39 wordlist integrity (2048/sorted/unique/lowercase)"
fi

# --- allowlist: documented allow ---------------------------------------------
out="$(printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"/tmp/proj/tests/fixtures/leaked.pem","content":"-----BEGIN PRIVATE KEY-----\nMIIEowIBAAKCAQEA0Z3VS5JJcds3xfn/aGfFz\n-----END PRIVATE KEY-----"}}' | python3 "$HOOK" 2>/dev/null)"
rc=$?
decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)"
reason="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason' 2>/dev/null)"
if [[ "$decision" == "allow" && "$rc" == "0" && "$reason" == *allowlist* ]]; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); echo "  FAIL: allowlist path must allow with documented reason (got $decision rc=$rc reason=$reason)"
fi

# --- fail-closed paths --------------------------------------------------------
out="$(printf 'this is not json at all' | python3 "$HOOK" 2>/dev/null)"; rc=$?
decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "NO_DECISION"' 2>/dev/null)"
if [[ "$decision" == "deny" && "$rc" == "1" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "  FAIL: unparseable stdin must deny/1 (got $decision rc=$rc)"; fi

expect "Write without content fails closed"  deny 1 '{"tool_name":"Write","tool_input":{"file_path":"/tmp/svc/app.py"}}'
expect "Write without file_path fails closed" deny 1 '{"tool_name":"Write","tool_input":{"content":"hello"}}'

echo "Results: $PASS passed, $FAIL failed (secrets-write-guard matrix)"
if [[ "$FAIL" -ne 0 || "$PASS" -eq 0 ]]; then
  echo "FAIL(secrets-write-guard): $FAIL failing / $PASS passing assertions" >&2
  exit 1
fi
exit 0
