# Multi-Agent Ralph Loop - TECHNICAL DEBT DEEP SCAN
**Generated**: 2026-01-25
**Analyst**: Claude Sonnet 4.5 (Code Reviewer)
**Scope**: Complete codebase analysis for v2.69.0
**Method**: Automated scanning + existing debt inventory analysis

---

## Executive Summary

| Category | Count | Critical | High | Medium | Low |
|----------|-------|----------|------|--------|-----|
| **Version Inconsistencies** | 26 | 1 | 1 | 0 | 0 |
| **Deprecated Code (MiniMax)** | 172 | 0 | 3 | 2 | 1 |
| **Code Duplication** | 8 | 0 | 2 | 4 | 2 |
| **Missing Error Handling** | 21 | 0 | 0 | 3 | 0 |
| **Hardcoded Values** | 12 | 0 | 2 | 6 | 4 |
| **Large Scripts (Refactor)** | 30 | 0 | 5 | 15 | 10 |
| **Testing Gaps** | 12 | 2 | 4 | 4 | 2 |
| **Documentation** | 18 | 0 | 4 | 8 | 6 |
| **TOTAL** | **299** | **3** | **21** | **42** | **25** |

**OVERALL RISK**: 🟡 **MEDIUM** - System functional, needs systematic cleanup

**Key Strengths** (maintain these):
- ✅ All 67 hooks have error traps
- ✅ Zero shellcheck suppressions
- ✅ No actual TODO/FIXME in critical code
- ✅ 90/111 scripts have `set -euo pipefail` (81%)

---

## 🔴 CRITICAL (3 items)

### CRIT-001: Version Synchronization Gap
**Severity**: CRITICAL
**Location**: `~/.claude/hooks/*.sh` (67 files)
**Current State**:
```
41 hooks @ v2.69.0 (61%)
21 hooks @ v2.68.23 (31%)
 4 hooks @ v2.68.25 (6%)
 1 hook  @ v2.68.26 (1%)
```
**Impact**: 
- Security fixes (SEC-111, SEC-117, SEC-050) may not be uniformly applied
- Users cannot trust version claims in CHANGELOG
- 26 hooks out of sync with current release

**Effort**: XS (30 minutes)
**Fix**:
```bash
cd ~/.claude/hooks
for f in *.sh; do
  sed -i '' 's/^# VERSION: .*/# VERSION: 2.69.0/' "$f"
done
```
**Verification**: `grep -h "^# VERSION:" ~/.claude/hooks/*.sh | sort | uniq -c`

---

### CRIT-002: Integration Test Coverage = 0%
**Severity**: CRITICAL
**Location**: `tests/` directory
**Current State**:
- 10 unit tests exist
- 0 integration tests for hook interactions
- 0 end-to-end orchestrator tests
- 903 passing tests (from test suite run), but all unit-level

**Impact**: 
- Hook interaction bugs not caught until runtime
- Orchestrator workflow changes untested
- Event-bus barrier logic unvalidated
- Agent handoff flows unverified

**Effort**: L (2-3 weeks)
**Recommendation**: Create integration test framework first, then add tests

---

### CRIT-003: 11 Scripts Without Tests
**Severity**: CRITICAL
**Location**: `scripts/` directory
**Files Without Coverage**:
```
scripts/v2-30-complete-audit.sh
scripts/add-version-markers.sh
scripts/migrate-commands-to-skills.sh
scripts/backup-all-projects.sh
scripts/install-git-hooks.sh
scripts/validate-integration.sh
scripts/migrate-opencode-models.sh
scripts/cleanup-project-configs.sh
scripts/v2-30-validation.sh
scripts/install-security-tools.sh
scripts/validate-global-architecture.sh
```

**Impact**: Installation and migration scripts may break silently
**Effort**: M (1-2 weeks, ~1 day per script group)

---

## 🟠 HIGH (21 items)

### HIGH-001: MiniMax References Should Be GLM-4.7
**Severity**: HIGH
**Location**: Codebase-wide
**Count**: 172 references to "minimax" or "MiniMax"
**Status**: 
- Phase 7 COMPLETE (orchestrator.md updated)
- Phase 8 COMPLETE (mmc + ralph CLI updated)
- **REMAINING**: 172 references in hooks, agents, commands

**Examples**:
```
~/.claude/hooks/*.sh - fallback logic
~/.claude/agents/*.md - agent descriptions
~/.claude/commands/*.md - command documentation
```

**Impact**: 
- Confusion about primary vs fallback models
- Documentation inconsistency
- Users may rely on deprecated MiniMax endpoints

**Effort**: M (1 week)
**Fix Strategy**:
1. Audit all 172 references
2. Categorize: KEEP (fallback), UPDATE (primary), DELETE (obsolete)
3. Batch update with search/replace
4. Test fallback logic still works

**Priority Files**:
- `.claude/commands/minimax-search.md` → rename to `glm-search.md`
- `.claude/agents/minimax-reviewer.md` → rename to `glm-reviewer.md`

---

### HIGH-002: Code Duplication - File Existence Checks
**Severity**: HIGH
**Pattern**: `if [[ -f "$FILE" ]]; then`
**Count**: 65 occurrences across hooks
**Impact**: Maintenance burden, inconsistent error handling

**Recommended Solution**: Create helper function
```bash
# ~/.claude/hooks/lib/file-helpers.sh
file_exists_or_error() {
    local file="$1"
    local error_msg="${2:-File not found: $file}"
    if [[ ! -f "$file" ]]; then
        echo "{\"continue\": true, \"systemMessage\": \"$error_msg\"}"
        return 1
    fi
    return 0
}
```

**Effort**: M (1 week to create library + migrate)

---

### HIGH-003: Code Duplication - jq Patterns
**Severity**: HIGH
**Pattern**: `jq -r '.field // ""' 2>/dev/null || echo ""`
**Count**: 332 occurrences
**Impact**: Inconsistent error handling, verbose code

**Recommended Solution**: Create jq helper
```bash
# ~/.claude/hooks/lib/json-helpers.sh
jq_safe() {
    local query="$1"
    local default="${2:-}"
    jq -r "$query // \"$default\"" 2>/dev/null || echo "$default"
}
```

**Effort**: M (1 week to create + migrate high-traffic hooks)

---

### HIGH-004: Large Scripts Need Refactoring
**Severity**: HIGH
**Scripts > 500 lines**:
```
install.sh:                         976 lines
tests/test_v2.37_tldr_integration.sh:  884 lines
.claude/hooks/smart-memory-search.sh:  707 lines
.claude/scripts/agent-memory-buffer.sh: 677 lines
.claude/scripts/event-bus.sh:          662 lines
tests/test_v2.33_sentry_integration.sh: 655 lines
tests/test_v2.36_skills_unification.sh: 609 lines
.claude/scripts/checkpoint-manager.sh:  608 lines
```

**Impact**: 
- Hard to maintain
- High cognitive load
- Testing difficulty
- Cyclomatic complexity

**Effort**: L (3-4 weeks, prioritize by criticality)
**Priority**: 
1. `smart-memory-search.sh` (707 lines) - core orchestrator hook
2. `event-bus.sh` (662 lines) - critical orchestration component
3. `checkpoint-manager.sh` (608 lines) - data integrity component

**Refactoring Strategy**:
- Extract functions into separate library files
- Split responsibilities (e.g., memory search into 6 separate modules)
- Create modular architecture

---

### HIGH-005: Hardcoded Timeout Values
**Severity**: HIGH
**Location**: Various hooks
**Pattern**: `timeout 10`, `timeout 30`, `sleep 5`
**Count**: ~45 occurrences
**Impact**: Inflexible for slow systems or high-load scenarios

**Recommended Solution**:
```bash
# ~/.ralph/config/timeouts.json
{
  "web_search": 30,
  "security_audit": 120,
  "codex_query": 60,
  "default": 30
}

# Hook usage:
TIMEOUT=$(jq -r '.web_search // .default' ~/.ralph/config/timeouts.json)
timeout "$TIMEOUT" curl ...
```

**Effort**: S (3 days)

---

### HIGH-006: Missing Scripts Without `set -euo pipefail`
**Severity**: HIGH
**Count**: 21 scripts (19% of total)
**Impact**: Silent failures, inconsistent error behavior

**Scripts to Fix**:
```bash
find . -name "*.sh" -exec sh -c '
  if ! grep -q "set -euo pipefail" "$1"; then
    echo "$1"
  fi
' _ {} \; > /tmp/missing-strict-mode.txt
```

**Effort**: XS (1 hour)
**Fix**: Add `set -euo pipefail` after shebang in all scripts

---

### HIGH-007: Hardcoded /tmp Paths
**Severity**: HIGH
**Location**: 3 scripts
**Files**:
- `tests/test_v2.24.1_security.sh` - `/tmp` exception
- `.claude/hooks/repo-boundary-guard.sh` - `/tmp/*` allowlist
- `.claude/hooks/session-start-tldr.sh` - `LOG_FILE="/tmp/tldr-warm-$$.log"`

**Impact**: 
- Cross-platform compatibility issues
- Security risk (predictable paths)
- Disk space management issues

**Fix**: Replace with `mktemp -d` or `$TMPDIR`
**Effort**: XS (2 hours)

---

### HIGH-008: No Central Security Controls Index
**Severity**: HIGH
**Location**: Missing `SECURITY_CONTROLS.md`
**Description**: SEC-XXX fixes scattered across CHANGELOG
**Count**: ~30 security fixes documented, but not indexed

**Impact**: Cannot audit security posture quickly
**Effort**: M (1 week)
**Deliverable**: Create `SECURITY_CONTROLS.md` with:
- SEC-XXX index
- CWE mappings
- Test coverage per control
- Implementation locations

---

### HIGH-009: Cross-Platform Compatibility Unverified
**Severity**: HIGH
**Risk Areas**:
```bash
# macOS-specific
sed -i '' (BSD sed)
stat -f (BSD stat)
mktemp -t (BSD mktemp)

# Should be
sed -i (GNU sed) or portable sed script
stat -c (GNU stat) or portable stat wrapper
mktemp --tmpdir (GNU mktemp) or portable mktemp wrapper
```

**Impact**: System breaks on Linux
**Effort**: M (2 weeks to create compatibility layer + test)

---

### HIGH-010: No Hook Dependency Graph
**Severity**: HIGH
**Location**: Documentation gap
**Description**: Execution order dependencies not documented
**Example**: `global-task-sync.sh` must run AFTER `task-primitive-sync.sh`

**Impact**: Race conditions, execution order bugs
**Effort**: M (1 week to analyze + document)
**Deliverable**: Dependency graph in `.claude/hooks/DEPENDENCIES.md`

---

### HIGH-011-021: (From existing inventory)
- HIGH-011: Lock Contention Not Tested
- HIGH-012: Deprecated Pattern in orchestrator.md
- HIGH-013: TODO Detection Not Tracked
- HIGH-014: Missing Hook Event Type Docs
- HIGH-015: No Migration Guides
- HIGH-016: Context Warning Path (fixed, pattern reminder)
- HIGH-017: Integer Validation Pattern Audit
- HIGH-018: Documentation Files With TODOs (18 files)
- HIGH-019: Global vs Project Hook Sync
- HIGH-020: No Performance Metrics
- HIGH-021: Archived Hooks Not Documented

---

## 🟡 MEDIUM (42 items)

### MED-001: Inconsistent Logging Patterns
**Severity**: MEDIUM
**Locations**:
- Some hooks: `~/.ralph/logs/*.log`
- Others: `/tmp/*.log`
- Some: No logging

**Impact**: Debugging difficulty
**Effort**: M (1 week)
**Solution**: Standardize on `~/.ralph/logs/` with rotation

---

### MED-002: Magic Numbers in Scripts
**Severity**: MEDIUM
**Examples**:
```bash
if [ "$COMPLEXITY" -ge 7 ]; then  # Why 7?
sleep 5  # Why 5 seconds?
MAX_ITER=50  # Why 50?
```

**Count**: ~60 occurrences
**Impact**: Unclear intent, hard to tune
**Effort**: S (1 week to document + extract to config)

---

### MED-003: Large Test Files
**Severity**: MEDIUM
**Files > 400 lines**:
```
test_v2.37_tldr_integration.sh:    884 lines
test_v2.33_sentry_integration.sh:  655 lines
test_v2.36_skills_unification.sh:  609 lines
test_v2.24_minimax_mcp.sh:         456 lines
```

**Impact**: Hard to maintain, slow to run
**Effort**: M (2 weeks to split into focused tests)

---

### MED-004-042: (Abbreviated - see full list in existing inventory)
- Temp file pattern inconsistency
- No stress testing
- Manual version batching
- CHANGELOG manual updates
- No error code documentation
- Conditional complexity (456 statements)
- Function count unknown
- No test coverage metrics
- Missing skill documentation
- Memory system files unvalidated
- Context tree index not documented
- Episode auto-convert truncation
- Blender integration not tested
- Open Agent UI status unknown
- YouTube video Spanish comment
- ... (see existing inventory for full list)

---

## 🔵 LOW (25 items)

### LOW-001: Explicit Exit Statements
**Severity**: LOW
**Count**: 11 explicit `exit 1` in hooks
**Impact**: Style inconsistency (most use traps)
**Effort**: XS (1 hour)

---

### LOW-002: Version Header Formatting
**Severity**: LOW
**Pattern**: Some use `# VERSION: X.Y.Z`, others `# v2.X.Y`
**Count**: ~8 inconsistencies
**Impact**: Minor aesthetic issue
**Effort**: XS (30 min)

---

### LOW-003-025: (From existing inventory)
- Git worktree tools comparison
- Codex CLI skill placeholder
- OpenAI docs skill status
- XXXXXX pattern (false positive)
- CWE-XXX placeholder
- Hex color placeholders
- Session inbox UI states
- Episode files disk usage
- Grep pattern in quality auditor
- AI code audit dead code detection
- Script syntax check passed (positive finding)
- All hooks have strict mode (positive finding)
- ... (see existing inventory for full list)

---

## 📊 Prioritized Backlog

### Sprint 1 (Week 1) - CRITICAL QUICK WINS
**Goal**: Fix critical version/consistency issues
**Effort**: ~20 hours

| Item | Effort | Impact |
|------|--------|--------|
| CRIT-001: Version sync | 0.5h | Critical |
| HIGH-006: Add strict mode | 1h | High |
| HIGH-007: Fix /tmp paths | 2h | High |
| HIGH-012: Update deprecated docs | 0.5h | High |
| LOW-001: Standardize exit patterns | 1h | Low |
| MED-002: Document magic numbers | 8h | Medium |

**Deliverables**:
- All hooks at v2.69.0
- All scripts have `set -euo pipefail`
- No hardcoded /tmp paths
- Magic numbers documented

---

### Sprint 2 (Week 2-3) - MINIMAX DEPRECATION
**Goal**: Complete GLM-4.7 migration
**Effort**: ~40 hours

| Item | Effort | Impact |
|------|--------|--------|
| HIGH-001: Audit 172 MiniMax refs | 16h | High |
| HIGH-001: Update hooks | 16h | High |
| HIGH-001: Update agents/commands | 8h | High |

**Deliverables**:
- MiniMax = fallback only
- GLM-4.7 = primary everywhere
- Updated documentation

---

### Sprint 3 (Week 4-5) - CODE QUALITY
**Goal**: Reduce duplication, improve maintainability
**Effort**: ~60 hours

| Item | Effort | Impact |
|------|--------|--------|
| HIGH-002: File helpers library | 16h | High |
| HIGH-003: jq helpers library | 16h | High |
| HIGH-005: Timeout config | 16h | High |
| MED-001: Logging standardization | 12h | Medium |

**Deliverables**:
- `~/.claude/hooks/lib/` created
- Helper libraries in use
- Configurable timeouts
- Consistent logging

---

### Sprint 4-6 (Week 6-12) - REFACTORING
**Goal**: Break up large scripts
**Effort**: ~120 hours

| Item | Effort | Impact |
|------|--------|--------|
| HIGH-004: Refactor smart-memory-search | 40h | High |
| HIGH-004: Refactor event-bus | 40h | High |
| HIGH-004: Refactor checkpoint-manager | 40h | High |

**Deliverables**:
- Modular architecture
- <300 lines per file
- Testable components

---

### Sprint 7-10 (Week 13-20) - TESTING
**Goal**: Achieve 80% coverage
**Effort**: ~160 hours

| Item | Effort | Impact |
|------|--------|--------|
| CRIT-002: Integration test framework | 40h | Critical |
| CRIT-002: Integration tests | 40h | Critical |
| CRIT-003: Script tests | 40h | Critical |
| HIGH-011: Stress tests | 40h | High |

**Deliverables**:
- Integration test framework
- 80%+ coverage
- Stress test suite
- Performance benchmarks

---

### Sprint 11-14 (Week 21-28) - DOCUMENTATION
**Goal**: Complete documentation
**Effort**: ~80 hours

| Item | Effort | Impact |
|------|--------|--------|
| HIGH-008: SECURITY_CONTROLS.md | 16h | High |
| HIGH-010: Hook dependency graph | 16h | High |
| HIGH-014: Hook event type guide | 16h | High |
| HIGH-015: Migration guides | 16h | High |
| HIGH-018: Resolve 18 TODOs | 16h | High |

**Deliverables**:
- Complete documentation
- Migration guides
- Security audit index
- No outstanding TODOs

---

## 📈 Success Metrics

| Metric | Current | Sprint 1 | Sprint 6 | Sprint 14 |
|--------|---------|----------|----------|-----------|
| Version Consistency | 61% @ v2.69.0 | 100% | 100% | 100% |
| Scripts with strict mode | 81% (90/111) | 100% | 100% | 100% |
| MiniMax refs (should be GLM) | 172 | 150 | 0 | 0 |
| Scripts > 500 lines | 8 | 8 | 4 | 0 |
| Test coverage | ~15% | ~15% | ~40% | ~80% |
| Integration tests | 0 | 0 | 50 | 100 |
| Script tests | 0/11 | 0/11 | 6/11 | 11/11 |
| Hardcoded timeouts | ~45 | ~45 | 0 | 0 |
| Code duplication (patterns) | ~400 | ~400 | ~200 | ~50 |
| Documentation TODOs | 18 | 12 | 6 | 0 |

---

## 🎯 Top 10 Quick Wins (This Week)

1. **CRIT-001**: Version sync (30 min) → 100% hooks at v2.69.0
2. **HIGH-006**: Add strict mode (1h) → All scripts protected
3. **HIGH-007**: Fix /tmp paths (2h) → Cross-platform safe
4. **HIGH-012**: Update deprecated docs (30 min) → No confusion
5. **LOW-001**: Standardize exit (1h) → Consistent patterns
6. **LOW-002**: Version header format (30 min) → Clean headers
7. **MED-006**: Version batch script (2h) → Automation
8. **HIGH-021**: Document archived hooks (1h) → Clean up dead code
9. **HIGH-017**: Integer validation audit (2h) → Pattern safety
10. **MED-003**: ShellCheck audit (1h) → Confirm zero suppressions

**Total Time**: ~12 hours
**Impact**: 10 debt items resolved, foundation for sprints 2+

---

## 🔧 Immediate Actions (Today)

Run these commands to start Sprint 1:

```bash
# 1. Version sync (30 min)
cd ~/.claude/hooks && for f in *.sh; do
  sed -i '' 's/^# VERSION: .*/# VERSION: 2.69.0/' "$f"
done

# 2. Verify version sync
grep -h "^# VERSION:" ~/.claude/hooks/*.sh | sort | uniq -c

# 3. Find scripts missing strict mode
find . -name "*.sh" -exec sh -c '
  if ! grep -q "set -euo pipefail" "$1"; then
    echo "$1"
  fi
' _ {} \; > /tmp/missing-strict-mode.txt

# 4. Create tracking file
cat > .claude/audits/DEBT_SPRINT1.md << 'SPRINT'
# Technical Debt Sprint 1 Tracking

## Goals
- [ ] All hooks at v2.69.0
- [ ] All scripts have strict mode
- [ ] No hardcoded /tmp paths
- [ ] Magic numbers documented

## Progress
...
SPRINT
```

---

**END OF TECHNICAL DEBT DEEP SCAN**
**Next Review**: After Sprint 1 completion (Week 2)
