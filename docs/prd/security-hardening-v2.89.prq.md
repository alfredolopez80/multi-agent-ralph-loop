# Feature: Security Hardening - Complete Remediation v2.89

**Created**: 2026-02-15
**Version**: 2.89.1
**Timeframe**: Multi-session (prioritized execution)
**Status**: PENDING EXECUTION

## Priority: CRITICAL

## Overview

Complete security hardening of multi-agent-ralph-loop based on comprehensive security audit findings. Remediates 14 security vulnerabilities across 4 severity levels (1 CRITICAL, 4 HIGH, 6 MEDIUM, 3 LOW) affecting Claude Code configuration, hooks, and infrastructure.

**Audit Source**: `/security-loop` comprehensive audit of last 50 commits + configuration
**Focus**: Platform security, configuration hardening, hook integrity, no third-party API security

## Scope Analysis

### Security Findings Summary

| Severity | Count | Impact Area |
|----------|-------|-------------|
| CRITICAL | 1 | Permission bypass, autonomous execution |
| HIGH | 4 | Privilege escalation, integrity validation, command injection |
| MEDIUM | 6 | Path restrictions, race conditions, credential leakage |
| LOW | 3 | Code quality, cleanup |

### Files Affected

| Category | File Count | Key Files |
|----------|------------|-----------|
| Settings | 2 | `~/.claude/settings.json`, `.claude/settings.local.json` |
| Hooks | 8 | `git-safety-guard.py`, `post-compact-restore.sh`, `ralph-subagent-start.sh`, etc. |
| Tests | 10+ | Test files with realistic credentials |
| Infrastructure | 5+ | Hooks with TOCTOU issues, state management |

---

## Tasks

### Phase 1: CRITICAL & HIGH Priority (Immediate - Today)

- [ ] **SEC-1.1**: [P0-CRITICAL] Disable skipDangerousModePermissionPrompt
  - Files: `~/.claude/settings.json` (line 398)
  - Finding: CRIT-001
  - Action: Change `"skipDangerousModePermissionPrompt": true` to `false`
  - Criteria: User confirmation required for dangerous operations
  - Verification: JSON valid, key is `false` or removed, manual test with dangerous command shows prompt
  - **MANDATORY**: Must verify prompt appears when attempting `dangerouslyDisableSandbox` operation

- [ ] **SEC-1.2**: [P1-HIGH] Restrict defaultMode to suggest for production safety
  - Files: `~/.claude/settings.json` (line 41)
  - Finding: HIGH-001
  - Action: Add comment documenting risk, create backup setting for Agent Teams sessions
  - Criteria: Document delegation risk, provide toggle mechanism
  - Verification: Comment exists explaining risk + delegation trade-off
  - **MANDATORY**: Documentation must warn about autonomous execution risk

- [ ] **SEC-1.3**: [P1-HIGH] Add Write/Edit restrictions to deny list
  - Files: `~/.claude/settings.json` (deny section)
  - Finding: MED-001, MED-006
  - Action: Add to deny list:
    ```json
    "Write(**/.claude/settings.json)",
    "Edit(**/.claude/settings.json)",
    "Read(**/.env)",
    "Read(**/.env.*)",
    "Read(**/.netrc)",
    "Read(**/id_rsa)",
    "Read(**/id_ed25519)",
    "Read(**/.claude/plugins/cache/**)"
    ```
  - Criteria: All 8 patterns added to deny list, JSON valid
  - Verification: Settings file valid, deny list contains all patterns, test read of .env fails
  - **MANDATORY**: Must verify .env read is blocked with test file

- [ ] **SEC-1.4**: [P1-HIGH] Restrict mcp__gordon__run_command to safe patterns
  - Files: `.claude/settings.local.json` (line 4)
  - Finding: HIGH-002
  - Action: Change from `"mcp__gordon__run_command"` to specific patterns:
    ```json
    "mcp__gordon__run_command(docker build:*)",
    "mcp__gordon__run_command(docker inspect:*)",
    "mcp__gordon__run_command(docker logs:*)"
    ```
  - Criteria: Only allow safe Docker operations (build, inspect, logs)
  - Verification: JSON valid, patterns restricted, dangerous commands blocked
  - **MANDATORY**: Test that `docker run --privileged` is blocked

- [ ] **SEC-1.5**: [P1-HIGH] Fix ralph-subagent-start.sh hardcoded path and stdin limit
  - Files: `.claude/hooks/ralph-subagent-start.sh` (lines 29, 36)
  - Finding: HIGH-004
  - Action:
    1. Replace `REPO_ROOT="/Users/alfredolopez/..."` with `REPO_ROOT="$(git rev-parse --show-toplevel)"`
    2. Replace `stdin_data=$(cat)` with `stdin_data=$(head -c 100000)`
  - Criteria: Dynamic path resolution, SEC-111 stdin limiting
  - Verification: Hook executable, syntax valid, grep confirms changes, test with large input
  - **MANDATORY**: Test hook works in different directory location

- [ ] **SEC-1.6**: [P1-HIGH] Implement git-safety-guard.py command chaining detection
  - Files: `.claude/hooks/git-safety-guard.py`
  - Finding: MED-003
  - Action: Split command by `&&`, `||`, `;`, `|` and validate each subcommand
  - Criteria: Detect chained dangerous commands
  - Verification: Test cases pass for `echo safe && rm -rf /`, `git add . ; git reset --hard`
  - **MANDATORY**: Must block: `echo safe && git reset --hard`, `ls ; rm -rf /tmp/test`

### Phase 2: MEDIUM Priority (Short Term - This Week)

- [ ] **SEC-2.1**: [P2-MEDIUM] Implement checksum validation for restored handoffs/ledgers
  - Files: `.claude/hooks/post-compact-restore.sh`, new `handoff-integrity.sh` library
  - Finding: HIGH-003
  - Action:
    1. Create integrity library with SHA-256 checksum functions
    2. Modify handoff creation to generate `.sha256` files
    3. Modify restore to verify checksums before injection
    4. Sanitize injected content (filter control chars, prompt injection patterns)
  - Criteria: All handoffs/ledgers have checksums, verification works, content sanitized
  - Verification: Create handoff → `.sha256` exists, modify handoff → restore fails, test sanitization
  - **MANDATORY**: Must reject tampered handoff files

- [ ] **SEC-2.2**: [P2-MEDIUM] Implement flock for plan-state.json race conditions
  - Files: `.claude/hooks/lsa-pre-step.sh`, `.claude/hooks/auto-plan-state.sh`, all hooks writing plan-state
  - Finding: MED-005 (TOCTOU)
  - Action: Wrap all plan-state.json read-modify-write in flock:
    ```bash
    (
        flock -x 200
        # read, modify, write plan-state.json
    ) 200>"${PLAN_STATE_FILE}.lock"
    ```
  - Criteria: All plan-state writers use flock, parallel test succeeds
  - Verification: Grep all hooks for plan-state writes, verify flock present, parallel execution test
  - **MANDATORY**: Test with 3 parallel hooks writing plan-state - no corruption

- [ ] **SEC-2.3**: [P2-MEDIUM] Add whitelist validation to auto-sync-global.sh
  - Files: `.claude/hooks/auto-sync-global.sh`
  - Finding: MED-002
  - Action:
    1. Create whitelist array of approved hook names
    2. Verify checksums before copying (optional but recommended)
    3. Skip hooks not in whitelist
    4. Log skipped hooks
  - Criteria: Only whitelisted hooks copied, others logged
  - Verification: Add fake hook to ~/.claude/hooks/, run sync, verify not copied
  - **MANDATORY**: Fake malicious hook must NOT be copied to project

- [ ] **SEC-2.4**: [P2-MEDIUM] Replace realistic credentials in test files
  - Files: All test files with `sk-live-*`, `sk-*` patterns
  - Finding: MED-004
  - Action: Replace with clearly fake patterns:
    - `sk-live-*` → `sk-test-FAKE_000000000000`
    - `sk-*` → `sk-TESTONLY_000000000000`
    - Add comment: `# FAKE CREDENTIAL FOR TESTING ONLY`
  - Criteria: No realistic-looking credentials in any test file
  - Verification: Grep for `sk-live`, `sk-[0-9a-f]{20}` returns 0 matches in tests/
  - **MANDATORY**: Semgrep/gitleaks scan must not flag test files

- [ ] **SEC-2.5**: [P2-MEDIUM] Fix command-router.sh stdin limit
  - Files: `.claude/hooks/command-router.sh` (line 41)
  - Finding: LOW-003
  - Action: Replace `INPUT=$(cat)` with `INPUT=$(head -c 100000)`
  - Criteria: SEC-111 compliance
  - Verification: Hook syntax valid, grep confirms change, test with large input
  - **MANDATORY**: Large input (>100KB) must be truncated

- [ ] **SEC-2.6**: [P2-MEDIUM] Add .gitignore entries for backup files
  - Files: `.gitignore`
  - Finding: LOW-002
  - Action: Add patterns: `*.bak`, `*.backup.*`, `.claude/hooks/*.backup.*`
  - Criteria: Backup files excluded from git
  - Verification: Git status shows no .bak files, create test.bak → not shown in status
  - **MANDATORY**: Existing .bak files must be removed from git history (git rm)

### Phase 3: LOW Priority & Cleanup (Medium Term - Next 2 Weeks)

- [ ] **SEC-3.1**: [P3-LOW] Fix double shebang in security-full-audit.sh
  - Files: `.claude/hooks/security-full-audit.sh` (lines 1-2)
  - Finding: LOW-001
  - Action: Remove duplicate shebang, keep only `#!/usr/bin/env bash`
  - Criteria: Single shebang line
  - Verification: Head -2 shows only one shebang, syntax valid
  - **MANDATORY**: bash -n validates, no errors

- [ ] **SEC-3.2**: [P3-CLEANUP] Remove backup files from repository
  - Files: `*.bak`, `*.backup.*` in `.claude/hooks/`
  - Finding: LOW-002
  - Action: `git rm .claude/hooks/*.bak .claude/hooks/*.backup.*`
  - Criteria: No backup files in git
  - Verification: Git ls-files shows no .bak or .backup.* files
  - **MANDATORY**: Git history cleaned (consider git filter-repo if sensitive)

- [ ] **SEC-3.3**: [P3-VALIDATION] Create security validation test suite
  - Files: New `tests/security/test-security-hardening-v2.89.bats`
  - Action: Create BATS test suite validating all 14 fixes:
    - Test skipDangerousModePermissionPrompt prompt appears
    - Test .env read blocked
    - Test docker --privileged blocked
    - Test ralph-subagent-start.sh works outside repo dir
    - Test git-safety-guard blocks chained commands
    - Test handoff checksum validation
    - Test flock prevents plan-state race
    - Test auto-sync-global whitelist works
    - Test no realistic credentials in tests
    - Test stdin limits work
  - Criteria: All tests pass, 100% fix coverage
  - Verification: bats tests/security/test-security-hardening-v2.89.bats passes
  - **MANDATORY**: All 14 security fixes have at least 1 automated test

- [ ] **SEC-3.4**: [P3-DOCUMENTATION] Document security model and threat model
  - Files: New `docs/security/SECURITY_MODEL_v2.89.md`
  - Action: Create comprehensive security documentation:
    - Threat model (what we protect against)
    - Security controls (hooks, deny lists, permissions)
    - Attack surfaces and mitigations
    - Audit history and fixes
    - Security best practices for users
  - Criteria: Complete security model documented
  - Verification: Document exists, covers all major attack surfaces, references all fixes
  - **MANDATORY**: Document must include section on Agent Teams security implications

### Phase 4: VALIDATION & ROLLOUT

- [ ] **SEC-4.1**: [P0-VALIDATION] Run complete security validation suite
  - Files: All modified files, all test suites
  - Action:
    1. Run `bats tests/security/` - all tests pass
    2. Run `bats tests/` - no regressions
    3. Manual validation of each CRITICAL/HIGH fix
    4. Verify settings.json valid and parseable
  - Criteria: All tests pass, no regressions, manual validation complete
  - Verification: 0 test failures, all hooks executable and valid syntax
  - **MANDATORY**: Must test in isolated environment first (backup settings.json)

- [ ] **SEC-4.2**: [P1-ROLLOUT] Create rollback plan and backup
  - Files: `~/.claude/settings.json.pre-hardening-backup`, documentation
  - Action:
    1. Backup current settings.json with timestamp
    2. Document rollback steps
    3. Create validation checklist
    4. Plan staged rollout (test env → production)
  - Criteria: Backup exists, rollback documented, checklist complete
  - Verification: Backup file exists, rollback instructions tested
  - **MANDATORY**: Must be able to rollback in <5 minutes if issues found

- [ ] **SEC-4.3**: [P1-COMMIT] Commit all security fixes with detailed message
  - Files: All modified files
  - Action: Create comprehensive commit message:
    ```
    security: Complete hardening v2.89.1 - Fix 14 vulnerabilities

    CRITICAL FIXES:
    - CRIT-001: Disable skipDangerousModePermissionPrompt

    HIGH PRIORITY FIXES:
    - HIGH-001: Document defaultMode delegation risk
    - HIGH-002: Restrict gordon.run_command to safe patterns
    - HIGH-003: Implement handoff checksum validation
    - HIGH-004: Fix ralph-subagent-start.sh hardcoded path + stdin
    - MED-003: Add command chaining detection to git-safety-guard

    MEDIUM PRIORITY FIXES:
    - MED-001/MED-006: Add Write/Edit/Read deny patterns
    - MED-002: Add whitelist to auto-sync-global.sh
    - MED-004: Replace realistic credentials in tests
    - MED-005: Implement flock for plan-state race conditions
    - LOW-003: Fix command-router stdin limit

    LOW PRIORITY FIXES:
    - LOW-001: Fix double shebang
    - LOW-002: Remove backup files, update .gitignore

    VALIDATION:
    - Created test-security-hardening-v2.89.bats
    - All 14 fixes have automated tests
    - No regressions in existing 950+ BATS tests
    - Manual validation of all CRITICAL/HIGH fixes

    Audit: /security-loop comprehensive audit
    Fixes: 1 CRITICAL, 4 HIGH, 6 MEDIUM, 3 LOW

    Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
    ```
  - Criteria: All fixes committed, message complete, tests pass
  - Verification: Git log shows commit, all files staged, message complete
  - **MANDATORY**: Commit message must reference all 14 finding IDs

---

## Completion Criteria (MANDATORY)

### Success Criteria

All tasks must meet these criteria to be marked VERIFIED_DONE:

1. **CRITICAL Fixes (SEC-1.1)**:
   - ✅ `skipDangerousModePermissionPrompt` is `false` or removed
   - ✅ Manual test confirms prompt appears for dangerous operations
   - ✅ settings.json valid JSON

2. **HIGH Fixes (SEC-1.2 - SEC-1.6)**:
   - ✅ All deny list patterns added (8 patterns)
   - ✅ Test confirms .env read blocked
   - ✅ gordon.run_command restricted to safe patterns
   - ✅ Test confirms docker --privileged blocked
   - ✅ ralph-subagent-start uses dynamic path + SEC-111 stdin
   - ✅ Test confirms hook works outside original directory
   - ✅ git-safety-guard blocks command chaining
   - ✅ Test confirms `echo safe && rm -rf /` blocked

3. **MEDIUM Fixes (SEC-2.1 - SEC-2.6)**:
   - ✅ Handoff/ledger checksums implemented and verified
   - ✅ Test confirms tampered handoff rejected
   - ✅ All plan-state writers use flock
   - ✅ Test confirms no corruption with 3 parallel writers
   - ✅ auto-sync-global has whitelist
   - ✅ Test confirms malicious hook not synced
   - ✅ No realistic credentials in test files
   - ✅ Semgrep/gitleaks scan clean
   - ✅ All stdin readers use `head -c 100000`
   - ✅ .gitignore updated, backup files removed

4. **Validation (SEC-3.3, SEC-4.1)**:
   - ✅ test-security-hardening-v2.89.bats exists and passes
   - ✅ All 14 fixes have automated tests
   - ✅ 0 regressions in existing BATS tests
   - ✅ Manual validation checklist complete

5. **Documentation (SEC-3.4)**:
   - ✅ SECURITY_MODEL_v2.89.md created
   - ✅ All attack surfaces documented
   - ✅ Agent Teams security implications covered

6. **Rollout (SEC-4.2, SEC-4.3)**:
   - ✅ Backup created with timestamp
   - ✅ Rollback tested and documented
   - ✅ All changes committed with comprehensive message
   - ✅ All finding IDs referenced in commit

### Verification Commands

```bash
# Verify settings.json valid
python3 -c "import json; json.load(open('~/.claude/settings.json'.replace('~', '$HOME')))"

# Verify deny list complete
grep -c '\.env\|\.netrc\|id_rsa\|id_ed25519\|settings\.json\|plugins/cache' ~/.claude/settings.json

# Verify no realistic credentials in tests
! grep -r 'sk-live-[0-9a-f]' tests/
! grep -r 'sk-[0-9a-f]{20}' tests/

# Verify all hooks use SEC-111 stdin limiting
grep -L 'head -c 100000' .claude/hooks/*.sh | grep 'INPUT\|stdin_data' || echo "All hooks compliant"

# Run security test suite
bats tests/security/test-security-hardening-v2.89.bats

# Run full test suite (no regressions)
bats tests/
```

---

## Notes

### Security Impact

This remediation addresses attack vectors including:
- **Privilege escalation**: Via settings.json modification
- **Arbitrary code execution**: Via malicious hook injection
- **Data exfiltration**: Via unrestricted Docker commands
- **Integrity violation**: Via handoff/ledger tampering
- **Race conditions**: Via concurrent plan-state modification
- **Credential leakage**: Via test file scanning

### Agent Teams Considerations

Several fixes specifically address Agent Teams security:
- `defaultMode: delegate` allows autonomous multi-agent execution
- `skipDangerousModePermissionPrompt` bypasses safety in subagents
- `ralph-subagent-start.sh` context injection must be integrity-verified
- Concurrent plan-state access requires flock in multi-agent scenarios

### Rollback Plan

If any fix causes issues:
1. `cp ~/.claude/settings.json.pre-hardening-backup ~/.claude/settings.json`
2. `git revert <commit-hash>` if code changes needed
3. Restart Claude Code
4. Verify system functional with `ralph health`

### Testing Strategy

- **Unit tests**: Each fix has isolated test in BATS suite
- **Integration tests**: Full workflow with all fixes applied
- **Manual tests**: CRITICAL/HIGH fixes require manual validation
- **Regression tests**: Run existing 950+ BATS tests

---

## References

- Security Audit: `/security-loop` output (2026-02-15)
- CWE References: CWE-269, CWE-345, CWE-367, CWE-78, CWE-426
- Related PRDs: ralph-validation-audit-v2.89.prq.md
- Architecture: docs/architecture/UNIFIED_ARCHITECTURE_v2.88.md
- Security Docs: docs/security/

---

**END OF PRD**
