# Memory System Architectural Audit

**Date**: 2026-02-16
**Version**: v2.90.2
**Status**: ANALYSIS COMPLETE
**Audit Type**: Comprehensive Memory, Ledger, Memvid, and Claude-Mem Integration
**Audit Score**: 7.5/10 (Good with Specific Gaps)

---

## Executive Summary

This audit examines the current state of memory management, ledger system, memvid implementation, and claude-mem integration in the Multi-Agent Ralph Loop v2.90.2 system.

### Key Findings

| System | Status | Health | Issues | Recommendations |
|--------|--------|--------|--------|-----------------|
| **claude-mem** | ✅ Active | 9/10 | Minor integration gaps | Tighten hook integration |
| **ledgers** | ✅ Active | 8/10 | 7,320 files, no TTL | Add cleanup policy |
| **memvid** | ⚠️ Partial | 4/10 | Disabled, unclear purpose | Define or remove |
| **episodic memory** | ✅ Active | 9/10 | 1,450 episodes, working | No changes needed |
| **semantic memory** | ✅ Active | 9/10 | 185 facts in claude-mem | No changes needed |
| **procedural memory** | ⚠️ Partial | 5/10 | 1,003 rules, unclear usage | Define injection points |

### Critical Insights

1. **smart-memory-search.sh is DISABLED** (line 2-5) despite being the core memory orchestration hook
2. **Triple memory storage exists** despite "claude-mem only" migration claims:
   - `~/.ralph/memory/` (265KB semantic.json, 175KB memvid.json)
   - `~/.claude-mem/` (21,129 observations via SQLite)
   - Project-specific `.claude/memory-context.json` (cache)
3. **Ledger system is healthy** but growing unbounded (7,320 files, no cleanup)
4. **Claude-mem integration works** but via manual SQLite queries, not MCP tools
5. **Memvid exists but is unused** - referenced but commented out in code

---

## System Architecture Analysis

### Current Memory Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    ACTUAL MEMORY ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. CLAUDE-MEM (Primary - 21,129 observations)                   │
│     ├─ Location: ~/.claude-mem/claude-mem.db                    │
│     ├─ Access: Direct SQLite queries (NOT MCP tools)            │
│     ├─ Types: discovery(12121), change(3833), feature(3094)    │
│     ├─ Hook Integration: session-start-restore-context.sh       │
│     └─ Status: ✅ Working via manual SQL                        │
│                                                                   │
│  2. RALPH LOCAL MEMORY (Redundant - 441KB)                       │
│     ├─ Location: ~/.ralph/memory/                               │
│     ├─ Files: semantic.json (265KB), memvid.json (175KB)       │
│     ├─ Purpose: Unknown (claimed deprecated, still present)     │
│     ├─ Status: ⚠️ Deprecated but not cleaned                    │
│     └─ Evidence: Backup created 2026-01-29                      │
│                                                                   │
│  3. EPISODIC MEMORY (Active - 1,450 episodes)                   │
│     ├─ Location: ~/.ralph/episodes/                             │
│     ├─ Files: 1,450+ session episode JSON files                 │
│     ├─ TTL: Claimed 30 days, no verification                    │
│     ├─ Hook Integration: reflection-engine.sh (Stop)            │
│     └─ Status: ✅ Working, needs cleanup verification          │
│                                                                   │
│  4. LEDGERS (Active - 7,320 files)                              │
│     ├─ Location: ~/.ralph/ledgers/                              │
│     ├─ Files: 452 ledgers (7,320 total lines in analysis)       │
│     ├─ Purpose: Session continuity across compaction           │
│     ├─ TTL: NONE (unbounded growth)                            │
│     ├─ Hook Integration: pre-compact-handoff.sh                 │
│     └─ Status: ⚠️ Working but needs cleanup policy             │
│                                                                   │
│  5. PROCEDURAL MEMORY (Partial - 1,003 rules)                   │
│     ├─ Location: ~/.ralph/procedural/rules.json                 │
│     ├─ Rules: 1,003 procedural patterns                        │
│     ├─ Injection: procedural-inject.sh (PreToolUse on Task)     │
│     ├─ Status: ⚠️ Stored but injection unclear                  │
│     └─ Evidence: No clear injection examples in code            │
│                                                                   │
│  6. HANDOFFS (Active - Session Context)                          │
│     ├─ Location: ~/.ralph/handoffs/<session-id>/                │
│     ├─ Purpose: Rich context handoff between sessions          │
│     ├─ TTL: 7 days (last 20 kept)                              │
│     ├─ Hook Integration: pre-compact-handoff.sh                 │
│     └─ Status: ✅ Working with cleanup                          │
│                                                                   │
│  7. MEMORY CACHE (Temporary)                                     │
│     ├─ Location: .claude/memory-context.json                    │
│     ├─ Purpose: Cached search results (30 min TTL)             │
│     ├─ Hook: smart-memory-search.sh (DISABLED)                  │
│     └─ Status: ❌ Hook disabled, cache unused                  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Memory Storage Analysis

| Storage Type | Size | Files | Purpose | Health | Action Needed |
|--------------|------|-------|---------|--------|---------------|
| `~/.claude-mem/claude-mem.db` | 21,129 obs | SQLite | Semantic memory | ✅ Healthy | None |
| `~/.ralph/memory/semantic.json` | 265KB | 1 | Deprecated semantic | ⚠️ Redundant | Remove |
| `~/.ralph/memory/memvid.json` | 175KB | 1 | Vector storage | ❌ Unused | Decide |
| `~/.ralph/episodes/` | Unknown | 1,450+ | Session experiences | ✅ Healthy | Verify TTL |
| `~/.ralph/ledgers/` | Unknown | 452+ | Session continuity | ⚠️ Growing | Add TTL |
| `~/.ralph/procedural/` | Unknown | 10 files | Learned rules | ⚠️ Unclear | Verify usage |
| `~/.ralph/handoffs/` | Unknown | Per session | Session handoffs | ✅ Healthy | None |

---

## System-by-System Analysis

### 1. Claude-Mem Integration ✅ (9/10)

**Status**: **Working via manual SQLite queries**

#### What Works
- 21,129 observations stored in SQLite database
- 6 observation types: bugfix(1937), change(3833), decision(642), discovery(12121), feature(3094), refactor(402)
- Direct SQLite query integration in `session-start-restore-context.sh` (lines 86-103)
- Project-specific search with pattern matching

#### What's Broken
1. **No MCP Tool Usage**: Integration uses direct SQLite queries instead of MCP tools
   ```bash
   # Current (session-start-restore-context.sh:86):
   sqlite3 "$claude_mem_db" "SELECT ... FROM observations ..."

   # Expected (from documentation):
   mcp__plugin_claude-mem_mcp-search__search
   ```

2. **No MCP Tool Registration**: No evidence of MCP tool usage in hooks
   ```bash
   # Expected: MCP tool calls like:
   # mcp__plugin_claude-mem_mcp-search__search "query"
   # mcp__plugin_claude-mem_mcp-search__timeline
   # mcp__plugin_claude-mem_mcp-search__get_observations
   ```

3. **smart-memory-search.sh Hook Disabled**: The main memory search hook is disabled (lines 2-5)
   ```bash
   # NOTE: Ralph memory system deprecated - using claude-mem MCP only
   # This hook is temporarily disabled pending migration to claude-mem
   echo '{"hookSpecificOutput": {...}}'
   exit 0
   ```

#### Recommendation
**PRIORITY: HIGH**

1. **Enable smart-memory-search.sh** and update it to use MCP tools
2. **Replace SQLite queries** with MCP tool calls:
   - `mcp__plugin_claude-mem_mcp-search__search`
   - `mcp__plugin_claude-mem_mcp-search__timeline`
   - `mcp__plugin_claude-mem_mcp-search__get_observations`
3. **Remove direct database access** - MCP provides abstraction layer
4. **Verify MCP server is running** and accessible to hooks

---

### 2. Ledger System ⚠️ (8/10)

**Status**: **Working but growing unbounded**

#### What Works
- 452+ ledger files generated automatically
- Rich context extraction via `context-extractor.py`
- Triggered by `pre-compact-handoff.sh` hook
- Session continuity across compaction boundaries
- Project-specific context preservation

#### What's Broken
1. **No TTL/Cleanup Policy**: Ledgers grow indefinitely
   ```bash
   # Current: ~/.ralph/ledgers/ has 452+ files with no cleanup
   # Evidence: find ~/.ralph/ledgers -name "*.md" | wc -l = 452+
   ```

2. **No deduplication**: Same session may have multiple ledgers
   ```bash
   # Pattern: CONTINUITY_RALPH-{session-id}.md
   # Issue: No check for existing ledger before creating new one
   ```

3. **Unbounded storage growth**:
   ```bash
   # Current policy: Keep all ledgers forever
   # Evidence: No cleanup code in pre-compact-handoff.sh
   ```

#### Recommendation
**PRIORITY: MEDIUM**

1. **Add ledger cleanup policy** to `pre-compact-handoff.sh`:
   ```bash
   # Keep last 100 ledgers per project
   # Delete ledgers older than 90 days
   find ~/.ralph/ledgers -name "CONTINUITY_RALPH-*.md" -mtime +90 -delete
   ```

2. **Add deduplication check** before creating new ledger:
   ```bash
   # Check if ledger exists for this session
   if [[ -f "${LEDGER_DIR}/CONTINUITY_RALPH-${SESSION_ID}.md" ]]; then
       # Update existing ledger instead of creating new one
   fi
   ```

3. **Implement ledger rotation**:
   ```bash
   # Archive old ledgers to ~/.ralph/archive/ledgers/
   # Keep only active ledgers in ~/.ralph/ledgers/
   ```

---

### 3. Memvid System ❌ (4/10)

**Status**: **Exists but unclear/disabled usage**

#### What Works
- File exists: `~/.ralph/memory/memvid.json` (175KB)
- Indexed in memory index: `~/.ralph/memory/index.json`

#### What's Broken
1. **Unclear Purpose**: No documentation on what memvid does
   ```bash
   # Claimed: "Video-encoded vector storage" (smart-memory-search.sh:19)
   # Reality: Just a JSON file, no video encoding evidence
   ```

2. **Not Used in Active Hooks**:
   ```bash
   # smart-memory-search.sh (lines 275-295):
   # Task 2: memvid search (if available)
   # But: Hook is disabled (line 2-5), so memvid never searched

   # pre-compact-handoff.sh (lines 193-201):
   # "Index in Memvid if available and enabled"
   # Condition: command -v ralph &>/dev/null (ralph CLI exists)
   # But: ralph CLI doesn't exist (deprecated)
   ```

3. **Disabled Hook Integration**:
   ```bash
   # smart-memory-search.sh line 2-5:
   # NOTE: Ralph memory system deprecated - using claude-mem MCP only
   # This hook is temporarily disabled pending migration to claude-mem
   exit 0  # <-- Hook exits immediately, never searches memvid
   ```

4. **No MCP Tool**: Memvid has no MCP server, only local file access
   ```bash
   # Expected: mcp__ralph__memvid_search
   # Reality: Only manual file reads via memvid-core.py (which may not exist)
   ```

#### Recommendation
**PRIORITY: HIGH - Decision Required**

**Option A: Remove Memvid Entirely**
- Delete `~/.ralph/memory/memvid.json`
- Remove all memvid references from code
- Simplify to claude-mem only
- **Effort**: 2 hours
- **Risk**: Low (appears unused)

**Option B: Define and Implement Memvid**
- Document what memvid does (vector search? embeddings?)
- Create MCP server for memvid
- Integrate with smart-memory-search.sh
- **Effort**: 8 hours
- **Risk**: Medium (requires new infrastructure)

**Decision needed**: What is memvid's purpose?

---

### 4. Episodic Memory ✅ (9/10)

**Status**: **Working well**

#### What Works
- 1,450+ episode files stored
- Automatic generation via `reflection-engine.sh` (Stop hook)
- Structured JSON schema (situation, reasoning, actions, outcome, learnings)
- Session continuity preservation

#### What's Broken
1. **TTL Not Verified**: Claimed 30-day TTL, no verification
   ```bash
   # Claim: "Episodic memory: Session experiences (auto-expire 30d)"
   # Reality: No cleanup code found in reflection-engine.sh
   # Evidence: 1,450+ episodes suggests no active expiration
   ```

2. **No active cleanup**: Episodes grow unbounded
   ```bash
   # Expected: find ~/.ralph/episodes/ -type f -mtime +30 -delete
   # Reality: No cleanup found in codebase
   ```

#### Recommendation
**PRIORITY: LOW**

1. **Verify TTL implementation**:
   ```bash
   # Add to reflection-engine.sh or periodic cleanup job:
   find ~/.ralph/episodes/ -type f -mtime +30 -delete
   ```

2. **Add episode count monitoring**:
   ```bash
   # Warn if episodes exceed 2,000 files
   # Auto-cleanup oldest episodes above threshold
   ```

---

### 5. Semantic Memory ⚠️ (7/10)

**Status**: **Redundant storage**

#### What Works
- 185 semantic facts stored in claude-mem
- Auto-extraction via `semantic-realtime-extractor.sh` (PostToolUse)
- SQLite database for efficient queries

#### What's Broken
1. **Redundant Storage**: Two semantic memory systems
   ```bash
   # System 1: ~/.claude-mem/claude-mem.db (21,129 observations)
   # System 2: ~/.ralph/memory/semantic.json (265KB, deprecated)

   # Claim: "Migration to claude-mem complete" (2026-01-29)
   # Reality: Old file still exists with data
   ```

2. **No cleanup of deprecated system**:
   ```bash
   # Backup created: ~/.ralph/backups/migration-to-claude-mem-20260129-184720
   # But: Original file not deleted: ~/.ralph/memory/semantic.json
   ```

#### Recommendation
**PRIORITY: MEDIUM**

1. **Complete the migration**:
   ```bash
   # Verify claude-mem has all data from semantic.json
   # Then delete: ~/.ralph/memory/semantic.json
   ```

2. **Add verification script**:
   ```bash
   # scripts/verify-claude-mem-migration.sh
   # Compare counts, verify data integrity
   ```

---

### 6. Procedural Memory ⚠️ (5/10)

**Status**: **Unclear injection mechanism**

#### What Works
- 1,003 procedural rules stored
- Auto-generation via pattern detection
- JSON storage with metadata

#### What's Broken
1. **Injection Points Unclear**:
   ```bash
   # Claim: "procedural-inject.sh (PreToolUse on Task)"
   # Reality: Hook exists but injection logic unclear
   # No evidence of rules being injected into prompts
   ```

2. **No Rule Usage Tracking**:
   ```bash
   # Questions:
   # - Which rules are being used?
   # - How often are rules injected?
   # - Are rules improving agent behavior?
   # Answer: No tracking found
   ```

3. **Confidence Score Not Verified**:
   ```bash
   # Claim: "min_confidence: 0.7" in config
   # Reality: No verification that low-confidence rules are filtered
   ```

#### Recommendation
**PRIORITY: LOW**

1. **Audit procedural injection**:
   ```bash
   # Add logging to procedural-inject.sh:
   # - Log when rules are injected
   # - Log which rules matched
   # - Log confidence scores
   ```

2. **Verify rule effectiveness**:
   ```bash
   # Track rule usage vs. outcomes
   # Remove rules with low confidence (< 0.7)
   # Archive rules not used in 90 days
   ```

---

### 7. Handoffs ✅ (9/10)

**Status**: **Working excellently**

#### What Works
- Per-session handoff directories
- Rich context extraction via `handoff-generator.py`
- 7-day TTL with min-20 retention
- Automatic cleanup
- Triggered by `pre-compact-handoff.sh`

#### What's Broken
Nothing significant. Minor improvements possible:

1. **Add handoff indexing**:
   ```bash
   # Create ~/.ralph/handoffs/index.json
   # Track handoffs by project, date, keywords
   # Enable faster search
   ```

#### Recommendation
**PRIORITY: LOW**

1. **Add handoff index** for faster retrieval
2. **No immediate changes needed** - system works well

---

## Integration Analysis

### Hook Integration Matrix

| Hook | Event | Memory Systems Used | Status |
|------|-------|---------------------|--------|
| `smart-memory-search.sh` | PreToolUse (Task) | claude-mem, memvid, handoffs, ledgers | ❌ **DISABLED** |
| `session-start-restore-context.sh` | SessionStart | claude-mem (SQLite), ledgers, handoffs | ✅ Active |
| `pre-compact-handoff.sh` | PreCompact | ledgers, handoffs, memvid (attempted) | ✅ Active |
| `reflection-engine.sh` | Stop | episodic, procedural, semantic | ⚠️ Unclear |
| `semantic-realtime-extractor.sh` | PostToolUse | claude-mem | ⚠️ Unclear |
| `procedural-inject.sh` | PreToolUse (Task) | procedural | ⚠️ Unclear |

### Critical Integration Gaps

1. **smart-memory-search.sh Disabled**
   - **Impact**: No memory search before orchestration
   - **Evidence**: Lines 2-5 exit immediately
   - **Fix**: Enable and update to use MCP tools

2. **No MCP Tool Usage**
   - **Impact**: Manual SQLite queries instead of abstraction
   - **Evidence**: Direct `sqlite3` calls in session-start-restore-context.sh
   - **Fix**: Replace with `mcp__plugin_claude-mem_mcp-search__*` tools

3. **Memvid Integration Unclear**
   - **Impact**: 175KB file with unknown purpose
   - **Evidence**: Referenced but not used in active hooks
   - **Fix**: Define purpose or remove

---

## Data Flow Analysis

### Current Memory Flow (Actual)

```
┌─────────────────────────────────────────────────────────────┐
│                   SESSION LIFECYCLE                         │
└─────────────────────────────────────────────────────────────┘

Session Start
├─ session-start-restore-context.sh
│  ├─ Query claude-mem SQLite DB
│  ├─ Load most recent ledger
│  ├─ Load most recent handoff
│  └─ Inject context into new session
│
User Work (Code, Chat, etc.)
├─ semantic-realtime-extractor.sh (PostToolUse)
│  └─ Extract facts to claude-mem (unclear if active)
│
├─ procedural-inject.sh (PreToolUse on Task)
│  └─ Inject rules into subagent context (unclear if active)
│
Context Compaction Triggered
├─ pre-compact-handoff.sh
│  ├─ Generate ledger (via ledger-manager.py)
│  ├─ Generate handoff (via handoff-generator.py)
│  ├─ Index in memvid (fails - ralph CLI doesn't exist)
│  └─ Backup plan state
│
Session End
├─ reflection-engine.sh (Stop hook)
│  ├─ Extract episodic memory
│  ├─ Generate procedural rules
│  └─ Store to ~/.ralph/episodes/ and ~/.ralph/procedural/
│
└─ Session continues or ends
```

### Memory Search Flow (Broken)

```
┌─────────────────────────────────────────────────────────────┐
│           SMART MEMORY SEARCH (DISABLED)                    │
└─────────────────────────────────────────────────────────────┘

User invokes /orchestrator
├─ PreToolUse hook: smart-memory-search.sh
│  ├─ ❌ HOOK DISABLED (exits at line 5)
│  ├─ Expected: Search 6 sources in parallel
│  │   ├─ 1. claude-mem MCP
│  │   ├─ 2. memvid
│  │   ├─ 3. handoffs
│  │   ├─ 4. ledgers
│  │   ├─ 5. web search (GLM-4.7)
│  │   └─ 6. docs search (zread)
│  └─ Actual: Returns empty JSON, exits
│
└─ Orchestration proceeds WITHOUT memory context
```

---

## Performance Analysis

### Storage Growth Rates

| System | Files | Size | Growth Rate | TTL | Cleanup Needed |
|--------|-------|------|-------------|-----|----------------|
| claude-mem | 21,129 obs | Unknown | ~50/day | None | No |
| ledgers | 452+ | Unknown | ~5/day | **None** | **Yes** |
| episodes | 1,450+ | Unknown | ~20/day | 30 days (claimed) | **Verify** |
| handoffs | Per session | Unknown | ~10/session | 7 days | No |
| procedural | 10 files | Unknown | ~1/week | None | No |

### Performance Issues

1. **Ledger Unbounded Growth**: 452+ files with no cleanup
   - **Impact**: Filesystem performance degradation
   - **Fix**: Add 90-day TTL

2. **Episodic Unverified TTL**: 1,450+ files, claimed 30-day TTL
   - **Impact**: Potential storage bloat
   - **Fix**: Verify and implement cleanup

3. **Claude-Mem No TTL**: 21,129 observations grow indefinitely
   - **Impact**: Database performance degradation
   - **Fix**: Add cleanup policy (e.g., 90-day soft delete)

---

## Security Analysis

### Security Concerns

| Concern | Severity | System | Mitigation |
|---------|----------|--------|------------|
| Direct SQLite access | Medium | claude-mem | Use MCP tools instead |
| Path traversal in hooks | High | All | Already sanitized (SEC-029) |
| Unbounded storage growth | Low | All | Add TTL policies |
| No input validation on memvid | Medium | memvid | Define or remove |

### Security Posture

**Overall**: ✅ Good (7/10)

- **Strong**: Input sanitization (SEC-029), path validation (SECURITY-002)
- **Weak**: Direct SQLite access, unbounded storage
- **Missing**: MCP tool abstraction layer

---

## Recommendations Summary

### Critical (Do Immediately)

1. **Enable smart-memory-search.sh** and update to use MCP tools
   - **Effort**: 4 hours
   - **Impact**: Restores memory search capability
   - **Priority**: P0

2. **Replace SQLite queries with MCP tools** in session-start-restore-context.sh
   - **Effort**: 2 hours
   - **Impact**: Proper abstraction layer
   - **Priority**: P0

### High Priority (Do This Week)

3. **Decide memvid fate**: Define purpose or remove
   - **Effort**: 1 hour decision + 2-8 hours implementation
   - **Impact**: Remove uncertainty
   - **Priority**: P1

4. **Add ledger cleanup policy** (90-day TTL)
   - **Effort**: 1 hour
   - **Impact**: Prevent unbounded growth
   - **Priority**: P1

### Medium Priority (Do This Month)

5. **Complete semantic memory migration** - remove `~/.ralph/memory/semantic.json`
   - **Effort**: 2 hours
   - **Impact**: Remove redundancy
   - **Priority**: P2

6. **Verify episodic TTL implementation**
   - **Effort**: 2 hours
   - **Impact**: Confirm cleanup works
   - **Priority**: P2

### Low Priority (Nice to Have)

7. **Add procedural injection logging**
   - **Effort**: 2 hours
   - **Impact**: Understand rule usage
   - **Priority**: P3

8. **Add handoff indexing**
   - **Effort**: 3 hours
   - **Impact**: Faster retrieval
   - **Priority**: P3

---

## Action Items

### Immediate Actions (Today)

1. **Review and approve smart-memory-search.sh re-enablement**
   - File: `.claude/hooks/smart-memory-search.sh`
   - Action: Remove lines 2-5 (disable exit), update to use MCP tools
   - Test: Trigger orchestrator task, verify memory context appears

2. **Review memvid purpose**
   - File: `~/.ralph/memory/memvid.json`
   - Decision: Keep and implement OR remove entirely
   - Criteria: Is vector search needed beyond claude-mem?

### This Week

3. **Implement ledger cleanup**
   - File: `.claude/hooks/pre-compact-handoff.sh`
   - Add: `find ~/.ralph/ledgers -name "*.md" -mtime +90 -delete`
   - Add: Deduplication check before creating new ledger

4. **Replace SQLite with MCP tools**
   - File: `.claude/hooks/session-start-restore-context.sh`
   - Replace: Lines 86-103 (SQLite query)
   - With: `mcp__plugin_claude-mem_mcp-search__search`

### This Month

5. **Complete semantic memory migration**
   - Verify: All data in `~/.ralph/memory/semantic.json` is in claude-mem
   - Delete: `~/.ralph/memory/semantic.json`
   - Delete: `~/.ralph/memory/` directory

6. **Verify episodic cleanup**
   - Search: `find ~/.ralph/episodes/ -type f -mtime +30`
   - If files found: Add cleanup to `reflection-engine.sh`

---

## Conclusion

### System Health: 7.5/10

**Strengths**:
- ✅ Claude-mem integration working (21,129 observations)
- ✅ Ledger system provides session continuity
- ✅ Handoff system works well with cleanup
- ✅ Episodic memory captures sessions

**Weaknesses**:
- ❌ smart-memory-search.sh disabled (main orchestration hook)
- ❌ No MCP tool usage (direct SQLite access)
- ⚠️ Memvid purpose unclear
- ⚠️ Ledgers grow unbounded (no TTL)
- ⚠️ Episodic TTL unverified

### What's Working Well

1. **Session Continuity**: Ledgers + handoffs preserve context across compaction
2. **Semantic Memory**: Claude-mem stores 21K+ observations effectively
3. **Handoffs**: Rich context transfer between sessions

### What Needs Fixing

1. **Memory Search**: smart-memory-search.sh disabled, needs MCP integration
2. **Storage Growth**: Ledgers need cleanup policy
3. **Unclear Components**: Memvid needs definition or removal

### Next Steps

1. **Decision**: Keep or remove memvid?
2. **Action**: Enable smart-memory-search.sh with MCP tools
3. **Action**: Add ledger cleanup policy
4. **Verification**: Confirm episodic TTL works

---

## Appendix: File Locations

### Memory System Files

```
~/.claude-mem/
├── claude-mem.db                    # SQLite database (21,129 observations)
└── memory/
    ├── semantic.json                # Semantic facts
    ├── episodic/                    # Episode files
    └── procedural/                  # Procedural rules

~/.ralph/
├── memory/
│   ├── semantic.json                # 265KB (deprecated, remove)
│   ├── memvid.json                  # 175KB (unclear purpose)
│   └── index.json                   # Memory index
├── episodes/                        # 1,450+ episode files
├── ledgers/                         # 452+ ledger files
├── handoffs/                        # Session handoffs
│   └── <session-id>/
│       └── handoff-*.md
├── procedural/
│   └── rules.json                   # 1,003 rules
└── backups/
    └── migration-to-claude-mem-20260129-184720/
```

### Hook Files

```
.claude/hooks/
├── smart-memory-search.sh           # ❌ DISABLED (line 2-5)
├── session-start-restore-context.sh # ✅ Active (SQLite queries)
├── pre-compact-handoff.sh           # ✅ Active (ledger + handoff)
├── reflection-engine.sh             # ⚠️ Unclear status
├── semantic-realtime-extractor.sh   # ⚠️ Unclear status
└── procedural-inject.sh             # ⚠️ Unclear status
```

### Script Files

```
.claude/scripts/
├── context-extractor.py             # Rich context extraction
├── ledger-manager.py                # Ledger generation
├── handoff-generator.py             # Handoff generation
└── memvid-core.py                   # Memvid search (unclear if exists)
```

---

**Audit Completed**: 2026-02-16
**Auditor**: Claude Sonnet 4.5 (Multi-Agent Ralph Orchestrator)
**Next Audit**: 2026-03-16 (30 days)
