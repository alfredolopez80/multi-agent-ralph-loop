#!/usr/bin/env bats
# test-security-hardening-v2.89.bats - Security Hardening Validation Suite
# VERSION: 2.89.1
# Tests all 14 security findings from /security-loop audit (2026-02-15)

REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
SETTINGS="$HOME/.claude/settings.json"
LOCAL_SETTINGS="$REPO_ROOT/.claude/settings.local.json"
HOOKS_DIR="$REPO_ROOT/.claude/hooks"

# ============================================================================
# CRIT-001: skipDangerousModePermissionPrompt must be false
# ============================================================================

@test "CRIT-001: skipDangerousModePermissionPrompt is false" {
  result=$(python3 -c "import json; d=json.load(open('$SETTINGS')); print(d.get('skipDangerousModePermissionPrompt', 'NOT_SET'))")
  [ "$result" = "False" ] || [ "$result" = "NOT_SET" ]
}

# ============================================================================
# HIGH-001: defaultMode delegation risk documented
# ============================================================================

@test "HIGH-001: defaultMode delegation risk is documented" {
  grep -q '_defaultMode_WARNING' "$SETTINGS"
}

# ============================================================================
# HIGH-002: gordon.run_command restricted
# ============================================================================

@test "HIGH-002: mcp__gordon__run_command not in allow list" {
  ! grep -q '"mcp__gordon__run_command"' "$LOCAL_SETTINGS" 2>/dev/null || \
  ! grep -q 'mcp__gordon__run_command' "$LOCAL_SETTINGS" 2>/dev/null
}

# ============================================================================
# HIGH-004: ralph-subagent-start.sh fixes
# ============================================================================

@test "HIGH-004a: ralph-subagent-start.sh uses dynamic REPO_ROOT" {
  grep -q 'git rev-parse --show-toplevel' "$HOOKS_DIR/ralph-subagent-start.sh"
}

@test "HIGH-004b: ralph-subagent-start.sh uses SEC-111 stdin limit" {
  grep -q 'head -c 100000' "$HOOKS_DIR/ralph-subagent-start.sh"
}

@test "HIGH-004c: ralph-subagent-start.sh has no hardcoded path for REPO_ROOT" {
  ! grep -q 'REPO_ROOT="/Users/' "$HOOKS_DIR/ralph-subagent-start.sh"
}

# ============================================================================
# MED-001/MED-006: Deny list completeness
# ============================================================================

@test "MED-001: Write to settings.json is denied" {
  grep -q 'Write(\*\*/.claude/settings.json)' "$SETTINGS"
}

@test "MED-001: Edit of settings.json is denied" {
  grep -q 'Edit(\*\*/.claude/settings.json)' "$SETTINGS"
}

@test "MED-006a: .env read is denied" {
  grep -q 'Read(\*\*/.env)' "$SETTINGS"
}

@test "MED-006b: .env.* read is denied" {
  grep -q 'Read(\*\*/.env\.\*)' "$SETTINGS"
}

@test "MED-006c: .netrc read is denied" {
  grep -q 'Read(\*\*/.netrc)' "$SETTINGS"
}

@test "MED-006d: id_rsa read is denied" {
  grep -q 'Read(\*\*/id_rsa)' "$SETTINGS"
}

@test "MED-006e: id_ed25519 read is denied" {
  grep -q 'Read(\*\*/id_ed25519)' "$SETTINGS"
}

@test "MED-006f: plugin cache read is denied" {
  grep -q 'Read(\*\*/.claude/plugins/cache/\*\*)' "$SETTINGS"
}

# ============================================================================
# MED-003: git-safety-guard command chaining detection
# ============================================================================

@test "MED-003a: git-safety-guard.py has split_chained_commands function" {
  grep -q 'split_chained_commands\|split.*chain' "$HOOKS_DIR/git-safety-guard.py"
}

@test "MED-003b: git-safety-guard blocks chained rm -rf" {
  input='{"tool_name":"Bash","tool_input":{"command":"echo safe && rm -rf /home"}}'
  result=$(echo "$input" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>/dev/null) || true
  echo "$result" | grep -q '"block"'
}

@test "MED-003c: git-safety-guard blocks chained git reset --hard" {
  input='{"tool_name":"Bash","tool_input":{"command":"ls ; git reset --hard"}}'
  result=$(echo "$input" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>/dev/null) || true
  echo "$result" | grep -q '"block"'
}

@test "MED-003d: git-safety-guard allows safe chained commands" {
  input='{"tool_name":"Bash","tool_input":{"command":"git add . && git commit -m test"}}'
  result=$(echo "$input" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>/dev/null)
  # Should NOT contain block
  ! echo "$result" | grep -q '"block"'
}

# ============================================================================
# HIGH-003: Handoff integrity checksums
# ============================================================================

@test "HIGH-003a: handoff-integrity.sh library exists" {
  [ -f "$HOOKS_DIR/handoff-integrity.sh" ]
}

@test "HIGH-003b: handoff-integrity.sh is executable" {
  [ -x "$HOOKS_DIR/handoff-integrity.sh" ]
}

@test "HIGH-003c: post-compact-restore.sh sources integrity library" {
  grep -q 'handoff-integrity' "$HOOKS_DIR/post-compact-restore.sh"
}

@test "HIGH-003d: session-end-handoff.sh creates checksums" {
  grep -q 'checksum\|sha256\|integrity' "$HOOKS_DIR/session-end-handoff.sh"
}

# ============================================================================
# MED-005: flock/locking for plan-state.json
# ============================================================================

@test "MED-005: plan-state hooks use file locking" {
  # Check that plan-state-adaptive.sh or plan-state-init.sh uses locking
  grep -q 'lock\|flock\|mkdir.*lock' "$HOOKS_DIR/plan-state-adaptive.sh" || \
  grep -q 'lock\|flock\|mkdir.*lock' "$HOOKS_DIR/plan-state-init.sh" || \
  grep -q 'lock\|flock\|mkdir.*lock' "$HOOKS_DIR/orchestrator-init.sh"
}

# ============================================================================
# MED-002: auto-sync-global whitelist
# ============================================================================

@test "MED-002: auto-sync-global.sh has whitelist" {
  grep -q 'APPROVED_HOOKS\|whitelist\|WHITELIST' "$HOOKS_DIR/auto-sync-global.sh"
}

# ============================================================================
# MED-004: No realistic credentials in test files
# ============================================================================

@test "MED-004a: no sk-live patterns in tests" {
  ! grep -r 'sk-live-[0-9a-f]' tests/ 2>/dev/null
}

@test "MED-004b: test credentials use FAKE/TESTONLY markers" {
  # Check for realistic API key patterns (sk-live-*, sk- followed by 16+ hex chars)
  # Exclude false positives like task-*, ask-*, disk-*, etc.
  found=$(grep -rE '\bsk-(live|prod|[0-9a-f]{16,})' tests/ 2>/dev/null | grep -v 'FAKE\|TESTONLY\|\.bats:' | wc -l | tr -d ' ') || found=0
  [ "$found" -eq 0 ]
}

# ============================================================================
# LOW-003/SEC-111: stdin limiting compliance
# ============================================================================

@test "SEC-111: command-router.sh uses head -c for stdin" {
  grep -q 'head -c' "$HOOKS_DIR/command-router.sh"
}

@test "SEC-111: glm5-subagent-stop.sh uses head -c for stdin" {
  grep -q 'head -c' "$HOOKS_DIR/glm5-subagent-stop.sh"
}

# ============================================================================
# LOW-001: No double shebangs
# ============================================================================

@test "LOW-001a: security-full-audit.sh has single shebang" {
  shebang_count=$(head -3 "$HOOKS_DIR/security-full-audit.sh" | grep -c '^#!')
  [ "$shebang_count" -eq 1 ]
}

@test "LOW-001b: repo-boundary-guard.sh has single shebang" {
  shebang_count=$(head -3 "$HOOKS_DIR/repo-boundary-guard.sh" | grep -c '^#!')
  [ "$shebang_count" -eq 1 ]
}

# ============================================================================
# LOW-002: .gitignore blocks backup files
# ============================================================================

@test "LOW-002a: .gitignore blocks .bak files" {
  grep -q '\.bak' "$REPO_ROOT/.gitignore"
}

@test "LOW-002b: .gitignore blocks .backup.* files" {
  grep -q '\.backup\.' "$REPO_ROOT/.gitignore"
}

@test "LOW-002c: no .bak files tracked by git" {
  count=$(cd "$REPO_ROOT" && git ls-files '*.bak' '*.backup.*' 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -eq 0 ]
}

# ============================================================================
# STRUCTURAL: All hook files valid
# ============================================================================

@test "STRUCT-001: settings.json is valid JSON" {
  python3 -c "import json; json.load(open('$SETTINGS'))"
}

@test "STRUCT-002: all modified hooks pass syntax check" {
  for hook in ralph-subagent-start.sh command-router.sh security-full-audit.sh repo-boundary-guard.sh post-compact-restore.sh session-end-handoff.sh auto-sync-global.sh handoff-integrity.sh; do
    [ ! -f "$HOOKS_DIR/$hook" ] || bash -n "$HOOKS_DIR/$hook"
  done
}

@test "STRUCT-003: git-safety-guard.py passes compile check" {
  python3 -m py_compile "$HOOKS_DIR/git-safety-guard.py"
}

@test "STRUCT-004: all modified hooks are executable" {
  for hook in ralph-subagent-start.sh command-router.sh security-full-audit.sh repo-boundary-guard.sh post-compact-restore.sh session-end-handoff.sh auto-sync-global.sh handoff-integrity.sh git-safety-guard.py; do
    [ ! -f "$HOOKS_DIR/$hook" ] || [ -x "$HOOKS_DIR/$hook" ]
  done
}
