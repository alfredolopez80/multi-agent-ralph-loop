#!/usr/bin/env bats
# test-bug-fixes-v2.90.bats - Validation for 12 bug fixes from v2.90.1 audit
# VERSION: 2.90.1
# DATE: 2026-02-16
# Tests BUG-001 through BUG-012 fixes

# BATS_TEST_DIRNAME is the .bats file's own directory: bats-core runs each test
# from a generated script under $TMPDIR, so BASH_SOURCE[0] points at that temp
# file, not at this suite (that is why this path was once hardcoded to the
# author's machine). The :-fallback keeps direct `bash` sourcing working.
REPO_ROOT="$(cd "${BATS_TEST_DIRNAME:-$(dirname "${BASH_SOURCE[0]}")}/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.claude/hooks"
SCRIPTS_DIR="$REPO_ROOT/scripts"
LIB_DIR="$REPO_ROOT/.claude/lib"
# NOTE (issue #50 audit): assertions against promptify-auto-detect.sh (BUG-001c),
# sanitize-secrets.js and cleanup-secrets-db.js were removed with the files they
# tested. Verdicts and evidence: docs/testing/ORPHAN_TEST_AUDIT.md.

# ============================================================================
# BUG-001: SEC-111 stdin limit enforcement (5 hooks)
# ============================================================================

# BUG-001a/b (ralph-subagent-stop, ralph-stop-quality-gate) retired: hooks
# removed by #69 Phase 3 Slice C. See docs/testing/ORPHAN_TEST_AUDIT.md.

# BUG-001c (promptify-auto-detect.sh) retired: the hook was deleted in 498556f
# (Unified Herding Blanket v3.0); its live successor is run_promptify_auto_detect()
# in .claude/hooks/command-router.sh. See docs/testing/ORPHAN_TEST_AUDIT.md.

@test "BUG-001d: session-start-restore-context.sh uses head -c 100000" {
  grep -q 'head -c 100000' "$HOOKS_DIR/session-start-restore-context.sh"
}

@test "BUG-001e: todo-plan-sync.sh uses head -c 100000" {
  grep -q 'head -c 100000' "$HOOKS_DIR/todo-plan-sync.sh"
}

@test "BUG-001f: no remaining INPUT=\$(cat) in fixed hooks" {
  for hook in session-start-restore-context.sh todo-plan-sync.sh; do
    ! grep -q 'INPUT=$(cat)' "$HOOKS_DIR/$hook"
  done
}

# ============================================================================
# BUG-007: git-safety-guard.py detects command substitution
# ============================================================================

@test "BUG-007a: git-safety-guard.py checks for \$() patterns" {
  grep -q 'command substitution' "$HOOKS_DIR/git-safety-guard.py"
}

# BUG-007b/c/d assert on the CURRENT PreToolUse output format
# (hookSpecificOutput.permissionDecision: deny/allow). The original assertions
# grepped for '"block"', a value that format never had — verified against the
# live guard output while repairing this suite (issue #50 audit).
@test "BUG-007b: git-safety-guard blocks \$(rm -rf) command substitution" {
  input='{"tool_name":"Bash","tool_input":{"command":"echo $(rm -rf /home)"}}'
  result=$(echo "$input" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>/dev/null) || true
  echo "$result" | grep -q '"permissionDecision": "deny"'
}

@test "BUG-007c: git-safety-guard blocks backtick command substitution" {
  input='{"tool_name":"Bash","tool_input":{"command":"echo `git reset --hard`"}}'
  result=$(echo "$input" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>/dev/null) || true
  echo "$result" | grep -q '"permissionDecision": "deny"'
}

@test "BUG-007d: git-safety-guard allows safe \$() usage" {
  input='{"tool_name":"Bash","tool_input":{"command":"echo $(date)"}}'
  result=$(echo "$input" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>/dev/null)
  echo "$result" | grep -q '"permissionDecision": "allow"'
}

# ============================================================================
# BUG-008: audit-secrets.js (renamed from sanitize-secrets.js in 5ac3547)
# pattern ordering (specific before generic)
# ============================================================================

@test "BUG-008a: sk-proj- pattern comes before generic sk- pattern" {
  proj_line=$(grep -n 'sk-proj-' "$HOOKS_DIR/audit-secrets.js" | head -1 | cut -d: -f1)
  generic_line=$(grep -n 'sk-\[a-zA-Z0-9\]' "$HOOKS_DIR/audit-secrets.js" | head -1 | cut -d: -f1)
  [ -n "$proj_line" ]
  [ -n "$generic_line" ]
  [ "$proj_line" -lt "$generic_line" ]
}

@test "BUG-008b: audit-secrets.js correctly classifies sk-proj keys" {
  input='{"content":"my key is sk-proj-abc123def456ghi789jkl012mno345pqr678stu901vwx"}'
  # The human-readable classification ("OpenAI Project Key") goes to stderr;
  # stdout carries only the hook JSON. Capture both or the assertion is grepping
  # the stream it just threw away.
  result=$(echo "$input" | node "$HOOKS_DIR/audit-secrets.js" 2>&1)
  echo "$result" | grep -q 'OpenAI Project Key'
}

# ============================================================================
# BUG-009: handoff-integrity.sh checksum sidecar permissions
# (moved from .claude/hooks/ to .claude/lib/ in 498556f; umask 077 and
# chmod 600 survived the move — this suite followed the new path)
# ============================================================================

@test "BUG-009a: handoff-integrity.sh uses umask 077 for checksum files" {
  grep -q 'umask 077' "$LIB_DIR/handoff-integrity.sh"
}

@test "BUG-009b: handoff-integrity.sh sets chmod 600 on checksum files" {
  grep -q 'chmod 600' "$LIB_DIR/handoff-integrity.sh"
}

@test "BUG-009c: checksum sidecar has restrictive permissions" {
  # Create a temp file and test the function
  tmpfile=$(mktemp)
  echo "test content" > "$tmpfile"
  source "$LIB_DIR/handoff-integrity.sh"
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
# BUG-011 (cleanup-secrets-db.js SQL injection note) retired: the script was
# deleted in e580a8b (MemPalace v3.0, claude-mem forensic removal); only an
# archived copy remains under .claude/archive/. See
# docs/testing/ORPHAN_TEST_AUDIT.md.
# ============================================================================

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
  for hook in session-start-restore-context.sh todo-plan-sync.sh \
              repo-boundary-guard.sh; do
    bash -n "$HOOKS_DIR/$hook"
  done
  # handoff-integrity.sh moved to lib/; sourced (and thus parsed) by BUG-009c
  bash -n "$LIB_DIR/handoff-integrity.sh"
}

@test "STRUCT: git-safety-guard.py passes compile check" {
  python3 -m py_compile "$HOOKS_DIR/git-safety-guard.py"
}

@test "STRUCT: audit-secrets.js passes syntax check" {
  node --check "$HOOKS_DIR/audit-secrets.js"
}

@test "STRUCT: all fixed hooks are executable" {
  for hook in session-start-restore-context.sh todo-plan-sync.sh \
              repo-boundary-guard.sh \
              audit-secrets.js git-safety-guard.py; do
    [ -x "$HOOKS_DIR/$hook" ]
  done
  [ -x "$LIB_DIR/handoff-integrity.sh" ]
}
