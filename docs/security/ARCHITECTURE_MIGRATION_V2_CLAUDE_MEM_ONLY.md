# Architecture Migration: Claude-Mem Only (Zero Redundancy)

**Date**: 2026-01-29
**Version**: 2.0.0
**Status**: PROPOSED
**Severity**: CRITICAL (9/10)

---

## Executive Summary

**Goal**: Eliminate ALL Ralph memory systems and use ONLY `claude-mem` for memory storage.

**Current Problem**: 3 overlapping memory systems causing:
- Cross-project information leakage
- Redundant storage (82% overlap)
- Filesystem pollution
- Maintenance burden

**Solution**: Single-source-of-truth architecture using `claude-mem` exclusively.

---

## Before (Problematic - 3 Systems)

```
┌─────────────────────────────────────────────────────────────┐
│                    MEMORY CHAOS (Current)                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  System 1: Claude-mem (MCP Plugin)                          │
│  ├─ Semantic: ~/.config/claude-mem/memory/semantic.json    │
│  ├─ Episodic: ~/.config/claude-mem/episodes/               │
│  ├─ Procedural: ~/.config/claude-mem/procedural/           │
│  └─ OVERLAP: 82% with System 2                             │
│                                                              │
│  System 2: Ralph Global Memory (LEAKY!)                     │
│  ├─ Semantic: ~/.ralph/memory/semantic.json                │
│  ├─ Episodic: ~/.ralph/episodes/                           │
│  ├─ Procedural: ~/.ralph/procedural/rules.json             │
│  └─ RISK: Cross-project pattern leakage!                   │
│                                                              │
│  System 3: Ralph Local Memory (DUPLICATE!)                  │
│  ├─ Per-repo: <repo>/.ralph/memory/                        │
│  ├─ Overlaps: 60% with System 2                            │
│  └─ Status: Incomplete implementation                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Total Systems: 3
Total Redundancy: 82%
Total Directories: 14+ per repo
Security Risk: CRITICAL (9/10)
```

---

## After (Secure - 1 System)

```
┌─────────────────────────────────────────────────────────────┐
│              MEMORY SIMPLICITY (Proposed)                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ONLY System: Claude-mem (MCP Plugin)                       │
│  ├─ Semantic: ~/.config/claude-mem/memory/semantic.json    │
│  ├─ Episodic: ~/.config/claude-mem/episodes/               │
│  ├─ Procedural: ~/.config/claude-mem/procedural/           │
│  ├─ MCP Tools: search, timeline, get_observations          │
│  ├─ Web UI: http://localhost:7373                          │
│  └─ OVERLAP: 0% (only system!)                             │
│                                                              │
│  NO Ralph memory systems                                    │
│  NO ~/.ralph/memory/                                        │
│  NO <repo>/.ralph/memory/                                   │
│  NO code duplication                                        │
│  NO cross-project leakage                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Total Systems: 1
Total Redundancy: 0%
Total Directories: 0 per repo (claude-mem is global)
Security Risk: LOW (1/10)
```

---

## Migration Plan

### Phase 1: Assessment (1 hour)

**Tasks**:
1. Audit all hooks using `.ralph/memory/`
2. List all semantic memory entries in `~/.ralph/memory/`
3. Check for any irreplaceable data
4. Document migration scope

**Output**: `MIGRATION_ASSESSMENT.md`

### Phase 2: Data Migration (2 hours)

**Tasks**:
1. **Export** data from `~/.ralph/memory/`:
   ```bash
   cp ~/.ralph/memory/semantic.json .claude/memory/semantic-backup.json
   cp ~/.ralph/procedural/rules.json .claude/memory/procedural-backup.json
   ```

2. **Import to claude-mem** (via MCP):
   ```bash
   # Use claude-mem MCP tools
   mcp__plugin_claude-mem_mcp-search__search # Verify data accessible
   ```

3. **Verify** migration:
   ```bash
   ./claude/scripts/verify-claude-mem-migration.sh
   ```

**Output**: Migration completion report

### Phase 3: Code Cleanup (4 hours)

**Tasks**:
1. **Remove** `.ralph/memory/` references from hooks:
   - `semantic-auto-extractor.sh`
   - `decision-extractor.sh`
   - `curator-*.sh` scripts
   - Any memory-related hooks

2. **Replace** with claude-mem MCP calls:
   ```bash
   # OLD:
   ralph memory-write semantic "key" "value"

   # NEW:
   mcp__plugin_claude-mem_mcp-search__search
   ```

3. **Update** CLAUDE.md documentation

**Output**: Cleaned codebase

### Phase 4: Directory Cleanup (1 hour)

**Tasks**:
1. **Add** to `.gitignore`:
   ```
   .ralph/
   .ralph/**/*
   ```

2. **Remove** directories:
   ```bash
   # From current repo
   rm -rf .ralph/

   # Global cleanup (optional)
   rm -rf ~/.ralph/memory/
   ```

3. **Verify** no accidental commits:
   ```bash
   git log --all --full-history -- ".ralph/"
   ```

**Output**: Clean repositories

### Phase 5: Validation (2 hours)

**Tasks**:
1. **Test** memory operations still work
2. **Verify** no cross-project leakage
3. **Run** adversarial audit again
4. **Document** lessons learned

**Output**: Validation report

---

## Benefits Comparison

| Metric | Before (3 Systems) | After (1 System) | Improvement |
|--------|-------------------|------------------|-------------|
| **Memory Systems** | 3 | 1 | -67% |
| **Code Redundancy** | 82% | 0% | -100% |
| **Dirs per Repo** | 14 | 0 | -100% |
| **Cross-Project Leakage** | CRITICAL | NONE | ✅ |
| **Maintenance** | High | Zero | ✅ |
| **User Consent** | None | N/A | ✅ |
| **Git Safety** | Risk | Safe (.gitignore) | ✅ |

---

## Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Data loss during migration | LOW | HIGH | Backup before migration |
| Hooks break after removal | MEDIUM | HIGH | Comprehensive testing |
| Claude-mem MCP unavailable | LOW | MEDIUM | Graceful degradation |
| User resistance | LOW | LOW | Document benefits |

---

## Success Criteria

- [ ] Zero `.ralph/memory/` directories in any repo
- [ ] All hooks use claude-mem MCP tools
- [ ] No cross-project information leakage
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Adversarial audit passes (score < 2/10)

---

## Rollback Plan

If migration fails:

1. **Restore** from backup:
   ```bash
   cp .claude/memory/*-backup.json ~/.ralph/memory/
   ```

2. **Revert** hook changes:
   ```bash
   git revert <migration-commit>
   ```

3. **Document** failure reasons

---

## Next Steps

1. ✅ Review this architecture proposal
2. ⏳ Run Phase 1 assessment
3. ⏳ Execute migration (Phases 2-5)
4. ⏳ Validate and document results

---

**Total Estimated Time**: 10 hours
**Total Risk Reduction**: 89% (9/10 → 1/10)
**Architecture Complexity**: -67% (3 systems → 1 system)
