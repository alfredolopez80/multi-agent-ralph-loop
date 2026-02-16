#!/usr/bin/env bats
# test-bug-fixes-v2.90.bats - Validation for 12 bug fixes from v2.90.1 audit
# VERSION: 2.90.1
# DATE: 2026-02-16
# Tests BUG-001 through BUG-012 fixes

REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
HOOKS_DIR="$REPO_ROOT/.claude/hooks"
SCRIPTS_DIR="$REPO_ROOT/scripts"

# ============================================================================
# BUG-001: SEC-111 stdin limit enforcement (5 hooks)
# ============================================================================

@test "BUG-001a: ralph-subagent-stop.sh uses head -c 100000" {
  grep -q 'head -c 100000' "$HOOKS_DIR/ralph-subagent-stop.sh"
}

@test "BUG-001b: ralph-stop-quality-gate.sh uses head -c 100000" {
  grep -q 'head -c 100000' "$HOOKS_DIR/ralph-stop-quality-gate.sh"
}

@test "BUG-001c: promptify-auto-detect.sh uses head -c 100000" {
  grep -q 'head -c 100000' "$HOOKS_DIR/promptify-auto-detect.sh"
}

@test "BUG-001d: session-start-restore-context.sh uses head -c 100000" {
  grep -q 'head -c 100000' "$HOOKS_DIR/session-start-restore-context.sh"
}

@test "BUG-001e: todo-plan-sync.sh uses head -c 100000" {
  grep -q 'head -c 100000' "$HOOKS_DIR/todo-plan-sync.sh"
}

@test "BUG-001f: no remaining INPUT=\$(cat) in fixed hooks" {
  for hook in ralph-subagent-stop.sh ralph-stop-quality-gate.sh promptify-auto-detect.sh session-start-restore-context.sh todo-plan-sync.sh; do
    ! grep -q 'INPUT=$(cat)' "$HOOKS_DIR/$hook"
  done
}

# ============================================================================
# BUG-002: SESSION_ID sanitization in ralph-stop-quality-gate.sh
# ============================================================================

@test "BUG-002a: ralph-stop-quality-gate.sh sanitizes SESSION_ID" {
  grep -q "tr -cd 'a-zA-Z0-9_-'" "$HOOKS_DIR/ralph-stop-quality-gate.sh"
}

@test "BUG-002b: ralph-stop-quality-gate.sh limits SESSION_ID length" {
  grep -q 'head -c 64' "$HOOKS_DIR/ralph-stop-quality-gate.sh"
}

@test "BUG-002c: ralph-stop-quality-gate.sh defaults empty SESSION_ID" {
  grep -q 'SESSION_ID="unknown"' "$HOOKS_DIR/ralph-stop-quality-gate.sh"
}

# ============================================================================
# BUG-003: No hardcoded REPO_ROOT in ralph-stop-quality-gate.sh
# ============================================================================

@test "BUG-003a: ralph-stop-quality-gate.sh uses dynamic REPO_ROOT" {
  grep -q 'git rev-parse --show-toplevel' "$HOOKS_DIR/ralph-stop-quality-gate.sh"
}

@test "BUG-003b: ralph-stop-quality-gate.sh has no hardcoded user path for REPO_ROOT" {
  ! grep -q 'REPO_ROOT="/Users/' "$HOOKS_DIR/ralph-stop-quality-gate.sh"
}

# ============================================================================
# BUG-004: Removed duplicate division-by-zero guard in post-compact-restore.sh
# ============================================================================

@test "BUG-004: post-compact-restore.sh has no nested duplicate TOTAL_STEPS check" {
  # Count occurrences of the TOTAL_STEPS check pattern in the progress section
  # There should be exactly ONE check, not a nested duplicate
  count=$(grep -c 'if \[\[ "$TOTAL_STEPS" -gt 0 \]\]' "$HOOKS_DIR/post-compact-restore.sh")
  [ "$count" -eq 1 ]
}

# ============================================================================
# BUG-005: PLAN_STATUS initialized before conditional
# ============================================================================

@test "BUG-005: post-compact-restore.sh initializes PLAN_STATUS before use" {
  # PLAN_STATUS should be set to "unknown" before the conditional that may set it
  line_init=$(grep -n 'PLAN_STATUS="unknown"' "$HOOKS_DIR/post-compact-restore.sh" | head -1 | cut -d: -f1)
  line_use=$(grep -n 'PLAN_STATUS=.*jq' "$HOOKS_DIR/post-compact-restore.sh" | head -1 | cut -d: -f1)
  [ -n "$line_init" ]
  [ "$line_init" -lt "$line_use" ]
}

# ============================================================================
# BUG-006: pre-compact-handoff.sh ERR-only trap (no double JSON)
# ============================================================================

@test "BUG-006a: pre-compact-handoff.sh does not use ERR EXIT trap" {
  ! grep -q "trap.*ERR EXIT" "$HOOKS_DIR/pre-compact-handoff.sh"
}

@test "BUG-006b: pre-compact-handoff.sh uses ERR-only trap" {
  grep -q "trap.*ERR$" "$HOOKS_DIR/pre-compact-handoff.sh" || \
  grep -q "trap.*' ERR$" "$HOOKS_DIR/pre-compact-handoff.sh"
}

@test "BUG-006c: pre-compact-handoff.sh clears trap with ERR only" {
  grep -q 'trap - ERR$' "$HOOKS_DIR/pre-compact-handoff.sh"
}

# ============================================================================
# BUG-007: git-safety-guard.py detects command substitution
# ============================================================================

@test "BUG-007a: git-safety-guard.py checks for \$() patterns" {
  grep -q 'command substitution' "$HOOKS_DIR/git-safety-guard.py"
}

@test "BUG-007b: git-safety-guard blocks \$(rm -rf) command substitution" {
  input='{"tool_name":"Bash","tool_input":{"command":"echo $(rm -rf /home)"}}'
  result=$(echo "$input" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>/dev/null) || true
  echo "$result" | grep -q '"block"'
}

@test "BUG-007c: git-safety-guard blocks backtick command substitution" {
  input='{"tool_name":"Bash","tool_input":{"command":"echo `git reset --hard`"}}'
  result=$(echo "$input" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>/dev/null) || true
  echo "$result" | grep -q '"block"'
}

@test "BUG-007d: git-safety-guard allows safe \$() usage" {
  input='{"tool_name":"Bash","tool_input":{"command":"echo $(date)"}}'
  result=$(echo "$input" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>/dev/null)
  ! echo "$result" | grep -q '"block"'
}

# ============================================================================
# BUG-008: sanitize-secrets.js pattern ordering (specific before generic)
# ============================================================================

@test "BUG-008a: sk-proj- pattern comes before generic sk- pattern" {
  proj_line=$(grep -n 'sk-proj-' "$HOOKS_DIR/sanitize-secrets.js" | head -1 | cut -d: -f1)
  generic_line=$(grep -n 'sk-\[a-zA-Z0-9\]' "$HOOKS_DIR/sanitize-secrets.js" | head -1 | cut -d: -f1)
  [ -n "$proj_line" ]
  [ -n "$generic_line" ]
  [ "$proj_line" -lt "$generic_line" ]
}

@test "BUG-008b: sanitize-secrets.js correctly classifies sk-proj keys" {
  input='{"content":"my key is sk-proj-abc123def456ghi789jkl012mno345pqr678stu901vwx"}'
  result=$(echo "$input" | node "$HOOKS_DIR/sanitize-secrets.js" 2>/dev/null)
  echo "$result" | grep -q 'OPENAI_PROJECT_KEY'
}

# ============================================================================
# BUG-009: handoff-integrity.sh checksum sidecar permissions
# ============================================================================

@test "BUG-009a: handoff-integrity.sh uses umask 077 for checksum files" {
  grep -q 'umask 077' "$HOOKS_DIR/handoff-integrity.sh"
}

@test "BUG-009b: handoff-integrity.sh sets chmod 600 on checksum files" {
  grep -q 'chmod 600' "$HOOKS_DIR/handoff-integrity.sh"
}

@test "BUG-009c: checksum sidecar has restrictive permissions" {
  # Create a temp file and test the function
  tmpfile=$(mktemp)
  echo "test content" > "$tmpfile"
  source "$HOOKS_DIR/handoff-integrity.sh"
  handoff_create_checksum "$tmpfile"
  # Check permissions (should be 600 = -rw-------)
  perms=$(stat -f '%Lp' "${tmpfile}.sha256" 2>/dev/null || stat -c '%a' "${tmpfile}.sha256" 2>/dev/null)
  rm -f "$tmpfile" "${tmpfile}.sha256"
  [ "$perms" = "600" ]
}

# ============================================================================
# BUG-010: repo-boundary-guard.sh pipeline inspection
# ============================================================================

@test "BUG-010a: repo-boundary-guard.sh checks pipeline segments" {
  grep -q 'pipe\|pipeline' "$HOOKS_DIR/repo-boundary-guard.sh"
}

@test "BUG-010b: repo-boundary-guard.sh splits on pipe character" {
  grep -q "tr '|'" "$HOOKS_DIR/repo-boundary-guard.sh"
}

# ============================================================================
# BUG-011: cleanup-secrets-db.js SQL injection note
# ============================================================================

@test "BUG-011: cleanup-secrets-db.js has SQL injection safety note" {
  grep -q 'NEVER derived from user input' "$HOOKS_DIR/cleanup-secrets-db.js"
}

# ============================================================================
# BUG-012: git-guard.py architecture documented
# ============================================================================

@test "BUG-012a: scripts/git-guard.py documents it is standalone CLI" {
  grep -q 'Standalone CLI\|STANDALONE CLI' "$SCRIPTS_DIR/git-guard.py"
}

@test "BUG-012b: scripts/git-guard.py references hook version" {
  grep -q 'git-safety-guard.py' "$SCRIPTS_DIR/git-guard.py"
}

# ============================================================================
# STRUCTURAL: All fixed hooks pass validation
# ============================================================================

@test "STRUCT: all fixed bash hooks pass syntax check" {
  for hook in ralph-subagent-stop.sh ralph-stop-quality-gate.sh promptify-auto-detect.sh \
              session-start-restore-context.sh todo-plan-sync.sh post-compact-restore.sh \
              pre-compact-handoff.sh handoff-integrity.sh repo-boundary-guard.sh; do
    bash -n "$HOOKS_DIR/$hook"
  done
}

@test "STRUCT: git-safety-guard.py passes compile check" {
  python3 -m py_compile "$HOOKS_DIR/git-safety-guard.py"
}

@test "STRUCT: sanitize-secrets.js passes syntax check" {
  node --check "$HOOKS_DIR/sanitize-secrets.js"
}

@test "STRUCT: cleanup-secrets-db.js passes syntax check" {
  node --check "$HOOKS_DIR/cleanup-secrets-db.js"
}

@test "STRUCT: all fixed hooks are executable" {
  for hook in ralph-subagent-stop.sh ralph-stop-quality-gate.sh promptify-auto-detect.sh \
              session-start-restore-context.sh todo-plan-sync.sh post-compact-restore.sh \
              pre-compact-handoff.sh handoff-integrity.sh repo-boundary-guard.sh \
              sanitize-secrets.js cleanup-secrets-db.js git-safety-guard.py; do
    [ -x "$HOOKS_DIR/$hook" ]
  done
}
