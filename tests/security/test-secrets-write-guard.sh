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
