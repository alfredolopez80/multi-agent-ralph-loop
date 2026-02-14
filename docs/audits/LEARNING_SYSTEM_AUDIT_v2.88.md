# Learning System Comprehensive Audit v2.88.0

**Date**: 2026-02-14
**Version**: 2.88.0
**Status**: AUDIT COMPLETE - FIXES REQUIRED
**Auditor**: Claude Opus 4.6

## Executive Summary

The curator and auto-learning system has **excellent architectural design** but **incomplete implementation**. While gap detection and triggers work, the actual **pattern extraction** and **categorization** components are either broken or not implemented.

### Critical Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Total Rules | 1003 | N/A | - |
| Rules with source_repo | 0 | > 50% | CRITICAL |
| Domain-Categorized Rules | 148 (14.7%) | > 80% | CRITICAL |
| Undefined Domain Rules | 855 (85.3%) | < 20% | CRITICAL |
| Security Domain Rules | 3 | > 50 | CRITICAL |
| DevOps Domain Rules | 1 | > 30 | CRITICAL |
| Approved Repos with Patterns | 0/3 | 100% | CRITICAL |

---

## 1. System Architecture

### 1.1 Learning Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RALPH LEARNING SYSTEM v2.88                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  DETECTION           CURATION           LEARNING          INJECTION │
│  ──────────          ─────────          ─────────          ─────────│
│                                                                      │
│  Task Prompt   →     Discovery    →    Scoring     →     Ranking    │
│  (complexity)        (GitHub API)       (quality)         (top N)   │
│                                                                      │
│       ↓               ↓                  ↓                  ↓        │
│                                                                      │
│  orchestrator-       curator-          curator-          procedural│
│  auto-learn.sh       discovery.sh      scoring.sh         inject.sh │
│                                                                      │
│       ↓               ↓                  ↓                  ↓        │
│                                                                      │
│  GAP detected    repos found       repos scored       repos approved│
│  → recommend     → candidates      → quality_metrics   → corpus     │
│                                                                      │
│                      ↓                                               │
│                                                                      │
│               curator-ingest.sh  →  curator-learn.sh               │
│               (clone repos)          (extract patterns)              │
│                                                                      │
│                                            ↓                         │
│                                                                      │
│                                    procedural/rules.json            │
│                                    (1003 rules currently)            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Inventory

| Component | File | Purpose | Status |
|-----------|------|---------|--------|
| orchestrator-auto-learn.sh | `.claude/hooks/` | Detects learning gaps | ✅ Working |
| continuous-learning.sh | `.claude/hooks/` | Session-end extraction | ✅ Working |
| curator-suggestion.sh | `.claude/hooks/` | User prompt suggestions | ✅ Working |
| curator.sh | `.claude/scripts/` | Main orchestrator | ✅ Working |
| curator-discovery.sh | `.claude/scripts/` | GitHub API search | ✅ Working |
| curator-scoring.sh | `.claude/scripts/` | Quality scoring | ✅ Working |
| curator-rank.sh | `.claude/scripts/` | Ranking logic | ✅ Working |
| curator-ingest.sh | `.claude/scripts/` | Clone repos | ✅ Working |
| curator-approve.sh | `.claude/scripts/` | Approve repos | ✅ Working |
| curator-learn.sh | `.claude/scripts/` | Extract patterns | ❌ BROKEN |
| procedural-inject.sh | `.claude/hooks/` | Inject rules | ⚠️ Partial |

---

## 2. Critical Issues (BLOCKING)

### GAP-C01: Empty Manifest Files

**Issue**: Approved repos have empty `files: []` arrays in manifests.

**Impact**: No pattern traceability, cannot verify what was learned.

**Evidence**:
```json
// ~/.ralph/curator/corpus/approved/*/manifest.json
{
  "repo_url": "https://github.com/example/repo",
  "files": [],  // <-- EMPTY
  "patterns_extracted": 0
}
```

**Root Cause**: `curator-learn.sh` doesn't update manifest after processing.

### GAP-C02: Uncategorized Rules

**Issue**: 855 out of 1003 rules (85%) have `category: "all"` or undefined domain.

**Impact**: Domain detection fails, learning recommendations trigger incorrectly.

**Evidence**:
```json
{
  "id": "rule-1737392172-12345",
  "name": "Pattern from ...",
  "category": "all",  // <-- Should be detected domain
  "domain": undefined
}
```

**Root Cause**: `curator-learn.sh` and `repo-learn.sh` use generic "all" category.

### GAP-C03: Learning Gate Not Enforced

**Issue**: `learning_state: "CRITICAL"` doesn't block execution.

**Impact**: Tasks proceed without required domain knowledge.

**Evidence**:
```
[2026-02-14T18:10:12+01:00] Learning state: CRITICAL
[2026-02-14T18:10:12+01:00] Proceeding with implementation anyway...
```

**Root Cause**: `orchestrator-auto-learn.sh` only recommends, doesn't block.

---

## 3. High Priority Issues

### GAP-H01: Lock Contention

**Issue**: 33% of procedural-inject.sh runs skip due to lock timeouts.

**Impact**: Feedback loop broken, no usage tracking.

**Evidence**:
```
[2026-01-22T16:03:19+01:00] SKIPPED feedback loop - lock not acquired
[2026-01-22T16:04:16+01:00] SKIPPED feedback loop - lock not acquired
```

### GAP-H02: No Rule Verification

**Issue**: No check if injected rules are actually used by the model.

**Impact**: Cannot measure rule effectiveness.

### GAP-H03: Basic Metrics

**Issue**: Reports show counts but no actionable insights.

**Impact**: Cannot identify which rules help or hurt.

---

## 4. Domain Distribution Analysis

| Domain | Count | Percentage | Target | Gap |
|--------|-------|------------|--------|-----|
| undefined | 855 | 85.3% | < 20% | CRITICAL |
| database | 43 | 4.3% | 15% | HIGH |
| hooks | 33 | 3.3% | 10% | MEDIUM |
| frontend | 27 | 2.7% | 15% | HIGH |
| backend | 18 | 1.8% | 20% | CRITICAL |
| general | 14 | 1.4% | 5% | OK |
| testing | 9 | 0.9% | 10% | HIGH |
| security | 3 | 0.3% | 15% | CRITICAL |
| devops | 1 | 0.1% | 10% | CRITICAL |

---

## 5. Test Coverage

| Test Suite | Location | Tests | Status |
|------------|----------|-------|--------|
| Unit | `tests/unit/test-unit-learning-hooks-v1.sh` | 13 | ✅ |
| Integration | `tests/integration/test-learning-integration-v1.sh` | 13 | ✅ |
| Functional | `tests/functional/test-functional-learning-v1.sh` | 4 | ✅ |
| E2E | `tests/end-to-end/test-e2e-learning-complete-v1.sh` | 32 | ✅ |
| **Total** | `tests/run-all-learning-tests.sh` | **62** | ✅ |

---

## 6. What Works

### 6.1 Gap Detection ✅
- Correctly identifies when domain has < 3 rules
- Logs complexity and domain analysis
- Recommends learning when appropriate

### 6.2 Discovery Pipeline ✅
- GitHub API search with rate limiting
- Star/topic/language filtering
- Quality scoring with context relevance
- Organization diversity limits

### 6.3 Continuous Learning Hook ✅
- Analyzes session transcripts
- Detects learning opportunities
- Creates pattern files for review

### 6.4 Curator Suggestion Hook ✅
- Analyzes user prompts
- Suggests `/curator` when memory empty
- Context-aware recommendations

---

## 7. What Doesn't Work

### 7.1 Pattern Extraction ❌
- `curator-learn.sh` generates placeholder rules
- No actual code pattern extraction
- Rules have no `source_repo` file references

### 7.2 Domain Categorization ❌
- Rules default to `category: "all"`
- No domain detection from rule content
- Backfill mechanism missing

### 7.3 Learning Gate ⚠️
- Only recommends, doesn't enforce
- No blocking on CRITICAL state
- No retry mechanism

### 7.4 Feedback Loop ⚠️
- 33% skip rate from lock contention
- No `applied_count` tracking
- No effectiveness measurement

---

## 8. Implementation Plan

### Phase 1: Critical Fixes (P0)

| Task | File | Effort |
|------|------|--------|
| Fix pattern extraction | curator-learn.sh | 4-6h |
| Implement domain detection | curator-learn.sh | 2-3h |
| Backfill existing rules | backfill-domains.sh | 2-3h |
| Enforce learning gate | orchestrator-auto-learn.sh | 3-4h |

### Phase 2: High Priority (P1)

| Task | File | Effort |
|------|------|--------|
| Fix lock contention | procedural-inject.sh | 2-3h |
| Add rule verification | procedural-inject.sh | 4-6h |
| Enhance metrics | curator-report.sh | 2-3h |

### Phase 3: Test Integration (P2)

| Task | File | Effort |
|------|------|--------|
| Learning validation tests | tests/learning/ | 4-6h |
| Pre-commit integration | .git/hooks/pre-commit | 1-2h |
| Regression tests | tests/regression/ | 3-4h |

---

## 9. Files Referenced

| File | Path | Status |
|------|------|--------|
| orchestrator-auto-learn.sh | `.claude/hooks/` | Needs Fix |
| continuous-learning.sh | `.claude/hooks/` | Working |
| curator-suggestion.sh | `.claude/hooks/` | Working |
| curator.sh | `.claude/scripts/` | Working |
| curator-learn.sh | `.claude/scripts/` | BROKEN |
| curator-discovery.sh | `.claude/scripts/` | Working |
| curator-scoring.sh | `.claude/scripts/` | Working |
| curator-rank.sh | `.claude/scripts/` | Working |
| curator-ingest.sh | `.claude/scripts/` | Working |
| curator-approve.sh | `.claude/scripts/` | Working |
| procedural-inject.sh | `.claude/hooks/` | Partial |
| rules.json | `~/.ralph/procedural/` | Needs Backfill |

---

## 10. Conclusion

The learning system architecture is sound, but implementation gaps prevent autonomous operation. The fixes are well-defined and estimated at 15-25 hours total effort.

**Next Steps**:
1. Implement critical fixes (Phase 1)
2. Add comprehensive tests (Phase 3)
3. Integrate with pre-commit
4. Document resolved issues
