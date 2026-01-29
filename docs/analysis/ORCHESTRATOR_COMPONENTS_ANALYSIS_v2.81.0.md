# Orchestrator Components Analysis - v2.81.0

**Date**: 2026-01-29
**Version**: v2.81.0
**Status**: ANALYSIS COMPLETE

## Executive Summary

This analysis examines the state of three key orchestrator components:
1. **Repo Curator** - Repository discovery and curation system
2. **Repository Learner** - Pattern extraction and learning system
3. **Plan State** - Orchestration state management and persistence

**Key Finding**: All three components are IMPLEMENTED and FUNCTIONAL, but documentation in README.md is incomplete and outdated.

## Component Status Matrix

| Component | Status | Implementation | Documentation | Scripts Location |
|-----------|--------|----------------|---------------|------------------|
| **Repo Curator** | ✅ ACTIVE | Complete | Partial | `~/.ralph/curator/` + `.claude/scripts/` |
| **Repository Learner** | ✅ ACTIVE | Complete | Partial | `~/.ralph/scripts/repo-learn.sh` |
| **Plan State** | ✅ ACTIVE | Complete | Partial | `.claude/hooks/` + `~/.ralph/scripts/plan.sh` |

---

## 1. Repo Curator System

### Implementation Status: ✅ COMPLETE

**Location**: `~/.ralph/curator/`

**Directory Structure**:
```
~/.ralph/curator/
├── curator.sh                    # Main orchestrator
├── config.yml                    # Configuration
├── approved.json                 # Approved repos list
├── scripts/
│   ├── curator-discovery.sh      # GitHub API search
│   ├── curator-scoring.sh        # Quality scoring
│   ├── curator-rank.sh           # Ranking with max-per-org
│   ├── curator-show.sh           # Display ranking
│   ├── curator-pending.sh        # Show pending queue
│   ├── curator-approve.sh        # Approve repo
│   ├── curator-reject.sh         # Reject repo
│   └── curator-learn.sh          # Extract patterns
├── candidates/                   # Discovery results
├── rankings/                     # Ranked results
├── repos/                        # Cloned repositories
└── corpus/                       # Approved corpus
```

**Hooks Integration**:
- `.claude/hooks/curator-suggestion.sh` - UserPromptSubmit hook
- `.claude/hooks/orchestrator-auto-learn.sh` - PreToolUse (Task) hook

**Command**: `.claude/commands/curator.md`

**Agent**: `.claude/agents/repo-curator.md`

### Documentation Gaps

**README.md Status**:
- ✅ Mentions `/curator` command
- ✅ Shows basic usage examples
- ❌ Missing comprehensive workflow documentation
- ❌ Missing pricing tier details (free/economic/full)
- ❌ Missing integration with orchestrator
- ❌ Missing context relevance scoring (v2.55 feature)

**Missing Documentation**:
1. Full pipeline workflow (Discovery → Scoring → Ranking → Review → Learn)
2. Context relevance scoring (v2.55.0)
3. Integration with plan-state
4. Auto-learning triggers

### Git History

| Commit | Date | Description |
|--------|------|-------------|
| `e66b3e2` | 2026-01-19 | feat(v2.50.0): Add Repo Curator |
| `ddc3400` | 2026-01-20 | feat(v2.55.0): Autonomous Self-Improvement |
| `4308968` | 2026-01-20 | docs: Update Repo Curator to v2.55 |
| `d529e64` | 2026-01-22 | fix(v2.68.2): CRIT-010 curator-suggestion.sh |

---

## 2. Repository Learner

### Implementation Status: ✅ COMPLETE

**Location**: `~/.ralph/scripts/repo-learn.sh`

**Version**: 1.4.0 (v2.68.23)

**Key Features**:
1. **AST-based Pattern Extraction**
   - Python, TypeScript, Rust, Go support
   - Categories: error_handling, async_patterns, type_safety, architecture, testing, security

2. **Domain Classification** (v1.3.0)
   - Uses `~/.ralph/lib/domain-classifier.sh` library
   - Domains: database, security, backend, frontend, testing

3. **Procedural Rules Generation**
   - Confidence scores (0.0-1.0)
   - Source attribution (source_repo, source_url)
   - Atomic writes to `~/.ralph/procedural/rules.json`

**Security Fixes**:
- SEC-106: Path traversal validation (RALPH_TMPDIR)
- DUP-001: Shared domain-classifier library

### Documentation Gaps

**README.md Status**:
- ✅ Basic usage shown
- ❌ Missing version history
- ❌ Missing security fixes documentation
- ❌ Missing domain classification details
- ❌ Missing integration with curator

**Command**: `.claude/commands/repo-learn.md`

**Agent**: `.claude/agents/repository-learner.md`

### Git History

| Commit | Date | Description |
|--------|------|-------------|
| `3ee50fd` | 2026-01-19 | feat(v2.50.0): Add Repository Learner |
| `e66b3e2` | 2026-01-19 | feat(v2.50.0): Add Repo Curator integration |

---

## 3. Plan State System

### Implementation Status: ✅ COMPLETE

**Schema Version**: v2.62.0

**Location**: `.claude/schemas/plan-state-v2.schema.json`

**Key Components**:

**Scripts**:
- `~/.ralph/scripts/plan.sh` - Plan lifecycle CLI
- `~/.ralph/scripts/migrate.sh` - Schema migration

**Hooks** (5 hooks):
1. `auto-migrate-plan-state.sh` - SessionStart
2. `auto-plan-state.sh` - PreToolUse (Task)
3. `plan-state-init.sh` - Initialize plan-state.json
4. `plan-state-lifecycle.sh` - Manage phases, steps, barriers
5. `plan-state-adaptive.sh` - Adaptive compaction

**Schema Features**:
1. **Phases + Barriers** (v2.51.0)
   - WAIT-ALL consistency
   - Sequential/parallel execution modes

2. **Plan Lifecycle** (v2.65.2)
   - `ralph plan show` - Show current plan
   - `ralph plan archive` - Archive completed plan
   - `ralph plan reset` - Reset to empty
   - `ralph plan history` - Show archived plans

3. **Context Preservation**
   - PreCompact hook saves state before compaction
   - Survives context window compaction

### Documentation Gaps

**README.md Status**:
- ✅ Mentions plan-state.json
- ✅ Shows lifecycle commands
- ❌ Missing schema v2 details
- ❌ Missing phase/barrier architecture
- ❌ Missing integration with Task primitive (v2.62.0)
- ❌ Missing verification subagent integration

**Missing Documentation**:
1. Phase and barrier system (WAIT-ALL pattern)
2. Step execution modes (sequential/parallel)
3. Context compaction survival
4. Integration with Claude Code Task primitive
5. Verification subagent spawning

### Git History

| Commit | Date | Description |
|--------|------|-------------|
| `770de22` | 2026-01-15 | feat(v2.45.1): Auto plan-state |
| `4568e9f` | 2026-01-17 | feat(v2.54.0): Unified State Machine |
| `ae31820` | 2026-01-18 | fix(schema): Update plan-state-v2.json |
| `e9e74ac` | 2026-01-24 | feat(v2.65.2): Plan Lifecycle CLI |
| `efa3786` | 2026-01-24 | feat(v2.62.0): Task Primitive integration |
| `affdea5` | 2026-01-28 | fix: jq error in plan-state-adaptive |

---

## Critical Issues Found

### 1. Documentation Inconsistency

**Issue**: README.md documents v2.50.0 features but doesn't reflect:
- v2.55.0: Context relevance scoring in curator
- v2.62.0: Task primitive integration
- v2.65.2: Plan lifecycle CLI
- v2.68.23: Security fixes

**Impact**: Users don't know about:
- Context relevance scoring: `--context "error handling,retry"`
- Plan lifecycle: `ralph plan archive`, `ralph plan history`
- Security fixes: SEC-106, DUP-001

### 2. Hook Registration Gaps

**Missing Hooks**:
- No hook for continuous learning during development
- No hook for plan-state verification during execution
- No hook for auto-curator based on project type

**Existing Hooks Not Documented**:
- `continuous-learning.sh` - Exists but not in README
- `orchestrator-auto-learn.sh` - Partially documented

### 3. Integration Disconnect

**Issue**: The three systems work independently but lack orchestration:

**Current State**:
```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Curator    │     │  Repo-Learn  │     │ Plan-State   │
│              │     │              │     │              │
│  Manual use  │     │  Manual use  │     │  Auto on /o  │
└──────────────┘     └──────────────┘     └──────────────┘
```

**Desired State**:
```
┌─────────────────────────────────────────────────────────────┐
│                    Orchestrator Integration                 │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│   1. Orchestrator detects project type (backend, frontend)  │
│                   ↓                                          │
│   2. Auto-suggest curator for that type                      │
│                   ↓                                          │
│   3. Learn from approved repos                               │
│                   ↓                                          │
│   4. Apply learned patterns during implementation            │
│                   ↓                                          │
│   5. Update plan-state with learned patterns                 │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### 4. Plan-State Context Survival

**Issue**: Documentation doesn't explain how plan-state survives context compaction.

**Reality** (from code analysis):
1. PreCompact hook saves state
2. State written to `.claude/plan-state.json`
3. Post-compact reads from file
4. Continues execution

**Missing**: Clear documentation of this lifecycle.

---

## Recommendations

### Phase 1: Documentation Update (Priority: HIGH)

1. **Update README.md** with:
   - Complete curator workflow (all 5 phases)
   - Context relevance scoring (v2.55)
   - Plan lifecycle commands (v2.65.2)
   - Task primitive integration (v2.62.0)
   - Security fixes summary

2. **Create Integration Guide**:
   - How curator + repo-learn + plan-state work together
   - Auto-learning triggers
   - Continuous improvement workflow

3. **Add Examples**:
   - Full curator pipeline execution
   - Learning from approved repos
   - Plan-state during complex orchestration

### Phase 2: Hook Integration (Priority: MEDIUM)

1. **Create orchestrator-learning-bridge.sh**:
   - Detect project type from files
   - Suggest curator for that type
   - Trigger auto-learning from approved repos
   - Apply patterns to plan-state

2. **Create plan-state-verification.sh**:
   - Verify plan-state consistency
   - Detect drift during execution
   - Trigger plan-sync when needed

3. **Create continuous-learning-daemon.sh**:
   - Monitor git commits
   - Extract new patterns
   - Update procedural rules
   - Suggest curator runs

### Phase 3: Enhanced Integration (Priority: LOW)

1. **Auto-Curator Trigger**:
   - Detect new project type
   - Auto-suggest: `/curator full --type <detected> --lang <detected>`

2. **Pattern Application**:
   - During implementation, apply learned patterns
   - Show: "Using pattern from nestjs/nest: error handling"

3. **Retrospective Integration**:
   - After task completion, suggest learning
   - Extract successful patterns
   - Update procedural rules

---

## Test Coverage

### Existing Tests

| Test | Status | Coverage |
|------|--------|----------|
| `test_command_sync.py` | ✅ Passing | 20 tests |
| Swarm mode tests | ✅ Passing | 44 tests |
| Quality parallel tests | ✅ Passing | 945 tests |

### Missing Tests

1. **Curator Pipeline**:
   - Discovery → Scoring → Ranking → Learn
   - Context relevance scoring
   - Max-per-org constraints

2. **Plan State Lifecycle**:
   - Archive → Reset → Restore
   - Context compaction survival
   - Phase/barrier consistency

3. **Integration**:
   - Curator → Repo-learn → Plan-state
   - Auto-learning triggers
   - Pattern application

---

## Version History Summary

| Version | Date | Features |
|---------|------|----------|
| v2.50.0 | 2026-01-19 | Initial curator + repo-learn |
| v2.51.0 | 2026-01-17 | Phases + barriers in plan-state |
| v2.54.0 | 2026-01-17 | Unified state machine |
| v2.55.0 | 2026-01-20 | Autonomous self-improvement |
| v2.62.0 | 2026-01-24 | Task primitive integration |
| v2.65.2 | 2026-01-24 | Plan lifecycle CLI |
| v2.68.23 | 2026-01-27 | Security fixes (SEC-106, DUP-001) |
| v2.81.0 | 2026-01-29 | Swarm mode integration |

---

## Next Steps

1. ✅ **Analysis Complete** - This document
2. ⏳ **Documentation Update** - Update README.md
3. ⏳ **Integration Hook** - Create learning bridge
4. ⏳ **Test Suite** - Add integration tests
5. ⏳ **Validation** - End-to-end testing

---

## References

- [README.md](../../README.md) - Main documentation (needs update)
- [CLAUDE.md](../../CLAUDE.md) - Project instructions
- [AGENTS.md](../../AGENTS.md) - Agent documentation
- [CHANGELOG.md](../../CHANGELOG.md) - Version history
- [Schema v2.62.0](../.claude/schemas/plan-state-v2.schema.json) - Plan state schema
- [Curator Scripts](../.claude/scripts/curator-*.sh) - Curator implementation
- [Hooks](../.claude/hooks/) - Hook system
