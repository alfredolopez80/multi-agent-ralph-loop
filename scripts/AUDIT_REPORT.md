# Multi-Agent Ralph Loop Scripts Audit Report
**Date**: 2026-01-25
**Current Version**: v2.69.0
**Scripts Audited**: 11

## Executive Summary

- **Syntax**: All 11 scripts pass `bash -n` validation
- **Critical Issues**: 3 scripts
- **High Severity**: 2 scripts (completely obsolete)
- **Medium Severity**: 4 scripts
- **Low Severity**: 2 scripts

**Recommendation**: Archive or remove 5 obsolete scripts (v2.30-v2.40), update 3 scripts for v2.69.0 compatibility.

---

## Critical Issues

### 1. add-version-markers.sh
**Script**: `add-version-markers.sh`
**Problem**: Hardcoded user-specific path
**Line**: 21
```bash
PROJECT_DIR="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
```
**Severity**: CRITICAL
**Impact**: Script will fail for any user other than `alfredolopez`
**Fix**: Use dynamic path resolution:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
```

### 2. migrate-opencode-models.sh
**Script**: `migrate-opencode-models.sh`
**Problem**: Maps to deprecated MiniMax models
**Lines**: 6-8, 113-119
**Severity**: CRITICAL
**Impact**: Script migrates to MiniMax which is DEPRECATED in v2.69 (GLM-4.7 is PRIMARY)
**Fix**: Update model mapping:
```bash
# OLD (WRONG):
# opus   → gpt-5.2-codex
# sonnet → minimax-m2.1
# haiku  → minimax-m2.1-lightning

# NEW (CORRECT for v2.69):
# opus   → gpt-5.2-codex
# sonnet → sonnet  (keep as-is)
# haiku  → sonnet  (upgrade, don't use haiku)
# complexity 1-4 → GLM-4.7
```

### 3. migrate-opencode-models.sh
**Script**: `migrate-opencode-models.sh`
**Problem**: Missing `-e` flag in strict mode
**Line**: 11
```bash
set -uo pipefail  # Missing -e
```
**Severity**: MEDIUM
**Fix**: `set -euo pipefail`

---

## High Severity (Obsolete)

### 4. v2-30-validation.sh
**Script**: `v2-30-validation.sh`
**Problem**: Validates v2.30 features (we're at v2.69)
**Severity**: HIGH
**Impact**: Script checks for files/directories that no longer exist in current architecture
**References**:
- `checkpoint-manager` skill (removed)
- `fresh-context-explorer` skill (removed)
- `cc-codex-workflow` skill (removed)
**Recommendation**: **ARCHIVE** - no longer relevant

### 5. v2-30-complete-audit.sh
**Script**: `v2-30-complete-audit.sh`
**Problem**: Audits v2.30 implementation (obsolete)
**Severity**: HIGH
**Impact**: Checks 10 skills and 3 hooks that may not exist
**Missing**: `set -euo pipefail`
**Recommendation**: **ARCHIVE** - no longer relevant

---

## Medium Severity

### 6. validate-global-architecture.sh
**Script**: `validate-global-architecture.sh`
**Version Referenced**: v2.35
**Problems**:
1. Missing `-e` flag (line 5)
2. macOS-specific `stat -f %m` (line 117) - won't work on Linux
3. References v2.35 auxiliary agents that may have changed
**Severity**: MEDIUM
**Fix**:
```bash
# Line 5:
set -euo pipefail

# Line 117 (cross-platform stat):
AGE=$(( ($(date +%s) - $(stat -c %Y "$RECENT_LEDGER" 2>/dev/null || stat -f %m "$RECENT_LEDGER" 2>/dev/null)) / 3600 ))
```

### 7. validate-integration.sh
**Script**: `validate-integration.sh`
**Version Referenced**: v2.40
**Problems**:
1. Missing `-e` flag (line 14)
2. Checks for MiniMax models (line 350-357) which are DEPRECATED
3. References `llm-tldr` integration (may be outdated)
**Severity**: MEDIUM
**Fix**: Update validation to check for GLM-4.7 instead of MiniMax

### 8. backup-all-projects.sh
**Script**: `backup-all-projects.sh`
**Version Referenced**: v2.40
**Problems**:
1. Hardcoded `${HOME}/Documents/GitHub` (line 21)
2. Hardcoded project list (lines 24-46) - 21 projects
**Severity**: MEDIUM
**Fix**: Make GITHUB_DIR configurable:
```bash
GITHUB_DIR="${GITHUB_DIR:-${HOME}/Documents/GitHub}"
```

### 9. cleanup-project-configs.sh
**Script**: `cleanup-project-configs.sh`
**Version Referenced**: v2.43.0
**Problems**:
1. Hardcoded `${HOME}/Documents/GitHub` (line 24)
2. Version is v2.43.0 (should be v2.69.0 or removed)
**Severity**: MEDIUM
**Fix**: Make path configurable, update version marker

---

## Low Severity (Functional)

### 10. migrate-commands-to-skills.sh
**Script**: `migrate-commands-to-skills.sh`
**Version Referenced**: v2.36
**Problem**: Migration may already be complete
**Severity**: LOW
**Recommendation**: Run once, then archive

### 11. install-security-tools.sh
**Script**: `install-security-tools.sh`
**Version**: v2.48.0
**Status**: ✓ Functional, no issues found
**Severity**: LOW

### 12. install-git-hooks.sh
**Script**: `install-git-hooks.sh`
**Version**: v2.57.3
**Status**: ✓ Functional, no issues found
**Severity**: LOW

---

## Summary by Script

| # | Script | Version | Severity | Status | Recommendation |
|---|--------|---------|----------|--------|----------------|
| 1 | v2-30-validation.sh | v2.30 | HIGH | Obsolete | ARCHIVE |
| 2 | v2-30-complete-audit.sh | v2.30 | HIGH | Obsolete | ARCHIVE |
| 3 | validate-global-architecture.sh | v2.35 | MEDIUM | Outdated | UPDATE |
| 4 | migrate-commands-to-skills.sh | v2.36 | LOW | One-time | ARCHIVE after run |
| 5 | backup-all-projects.sh | v2.40 | MEDIUM | Limited | UPDATE paths |
| 6 | migrate-opencode-models.sh | - | CRITICAL | Wrong models | UPDATE for v2.69 |
| 7 | validate-integration.sh | v2.40 | MEDIUM | Outdated | UPDATE |
| 8 | cleanup-project-configs.sh | v2.43 | MEDIUM | Limited | UPDATE paths |
| 9 | add-version-markers.sh | v2.43 | CRITICAL | Hardcoded path | FIX IMMEDIATELY |
| 10 | install-security-tools.sh | v2.48 | LOW | Functional | OK |
| 11 | install-git-hooks.sh | v2.57 | LOW | Functional | OK |

---

## Detailed Findings

### Strict Mode Compliance

| Script | `set -e` | `set -u` | `set -o pipefail` | Status |
|--------|----------|----------|-------------------|--------|
| v2-30-validation.sh | ✗ | ✗ | ✗ | MISSING |
| v2-30-complete-audit.sh | ✗ | ✗ | ✗ | MISSING |
| validate-global-architecture.sh | ✗ | ✓ | ✓ | PARTIAL |
| migrate-commands-to-skills.sh | ✓ | ✓ | ✓ | FULL |
| backup-all-projects.sh | ✓ | ✓ | ✓ | FULL |
| migrate-opencode-models.sh | ✗ | ✓ | ✓ | PARTIAL |
| validate-integration.sh | ✗ | ✓ | ✓ | PARTIAL |
| cleanup-project-configs.sh | ✓ | ✓ | ✓ | FULL |
| add-version-markers.sh | ✓ | ✓ | ✓ | FULL |
| install-security-tools.sh | ✓ | ✓ | ✓ | FULL |
| install-git-hooks.sh | ✓ | ✓ | ✓ | FULL |

### Hardcoded Paths

| Script | Path | Line | Issue |
|--------|------|------|-------|
| add-version-markers.sh | `/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop` | 21 | User-specific |
| backup-all-projects.sh | `${HOME}/Documents/GitHub` | 21 | Assumes location |
| cleanup-project-configs.sh | `${HOME}/Documents/GitHub` | 24 | Assumes location |
| validate-global-architecture.sh | - | - | OK (uses HOME) |

### Platform-Specific Code

| Script | Issue | Line |
|--------|-------|------|
| validate-global-architecture.sh | `stat -f %m` (macOS only) | 117 |
| add-version-markers.sh | `sed -i ''` (macOS syntax) | 55, 61, etc. |

---

## Recommendations

### Immediate Actions (Critical)

1. **FIX** `add-version-markers.sh`:
   - Replace hardcoded path with dynamic resolution
   - Test on non-macOS systems (sed -i syntax)

2. **UPDATE** `migrate-opencode-models.sh`:
   - Remove MiniMax mappings (deprecated)
   - Add GLM-4.7 as PRIMARY for complexity 1-4
   - Add `set -e` flag

### Short-term Actions (High Priority)

3. **ARCHIVE** obsolete scripts to `scripts/archive/`:
   - `v2-30-validation.sh`
   - `v2-30-complete-audit.sh`

### Medium-term Actions

4. **UPDATE** validation scripts for v2.69:
   - `validate-global-architecture.sh` (v2.35 → v2.69)
   - `validate-integration.sh` (v2.40 → v2.69, check GLM-4.7)

5. **GENERALIZE** path handling:
   - `backup-all-projects.sh` (make GITHUB_DIR configurable)
   - `cleanup-project-configs.sh` (make GITHUB_DIR configurable)

6. **RUN ONCE** and archive:
   - `migrate-commands-to-skills.sh` (if migration not complete)

### Documentation

7. **ADD** to scripts/README.md:
   - Purpose of each script
   - Which scripts are one-time vs. recurring
   - Dependencies for each script

---

## Testing Checklist

Before any script execution:
- [ ] Verify all paths are absolute or properly resolved
- [ ] Check that referenced files/directories exist
- [ ] Test on both macOS and Linux (if applicable)
- [ ] Verify version numbers match current architecture
- [ ] Ensure all dependencies are installed

---

**Audit Performed By**: Claude Sonnet 4.5
**Audit Date**: 2026-01-25
**Project Version**: v2.69.0
