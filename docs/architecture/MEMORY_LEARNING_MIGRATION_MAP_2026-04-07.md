# Memory/Learning Implementation Map → MemPalace Migration

**Date**: 2026-04-07 | **Status**: PLANNING | **Scope**: Curator → Procedural → Vault → Rules ecosystem

---

## 1. CURATOR PIPELINE

### Input
- **Source**: GitHub repositories via curator-discovery.sh → curator-ingest.sh
- **Storage during pipeline**: `~/.ralph/curator/corpus/approved/` (cloned repos)
- **Trigger**: PreToolUse hook (`orchestrator-auto-learn.sh`) or manual `/curator` skill

### Processing
1. **Discovery**: Find candidate repos (GitHub API)
2. **Scoring**: Rate quality via curator-scoring.sh (README, docs, tests)
3. **Ranking**: curator-rank.sh selects top N (default 3) with --diversity flag
4. **Ingestion**: curator-ingest.sh clones with --clone-depth 1
5. **Approval**: curator-approve.sh validates before learning
6. **Learning**: curator-learn.sh extracts patterns (regex-based + LLM inference)

### Pattern Extraction Logic
- Searches file patterns: `tests/**/*`, `src/**/*`, `migrations/**/*`, etc.
- Detects domain via keyword scan (GAP-C02 fix):
  - "React", "Vue" → frontend
  - "async/await", "services" → backend
  - "SQL", "migrations" → database
- Extracts rules WITHOUT external Python (inline bash functions)
- Populates manifest with `files[]` array (GAP-C01 fix)

### Output
- **Primary**: `~/.ralph/procedural/rules.json` (1.1MB, ~5000+ rules)
  ```json
  {
    "rules": [
      {
        "rule_id": "backend-001",
        "name": "API Handler Pattern",
        "domain": "backend",
        "category": "backend",
        "confidence": 0.9
      }
    ]
  }
  ```
- **Secondary**: `~/.ralph/test-learning-[TIMESTAMP]/procedural/rules.json` (test instances)
- **Tertiary**: Vault sync → `~/Documents/Obsidian/MiVault/global/wiki/[domain]/`

### Integration Hooks
| Hook Path | Trigger | Purpose |
|-----------|---------|---------|
| `orchestrator-auto-learn.sh` | PreToolUse (Task) | Detect learning gaps, auto-suggest curator |
| `continuous-learning.sh` | SessionEnd | Extract learnings → vault |
| `vault-index-updater.sh` | SessionEnd | Update vault indices |
| *(removed)* `curator-suggestion.sh` | UserPromptSubmit | Deleted in v3.0 |

**Hook Locations**: `.claude/hooks/` (integrated via settings.json events)

---

## 2. LEARNED RULES FORMAT

### File Locations & Count
- **Directory**: `~/.claude/rules/learned/`
- **Count**: 9 files (auto-categorized by domain)

### Current Schema (Exact Format)

**agent-engineering.md**
```markdown
- Kaizen 4 Pillars for AI Agent Development (confidence: 0.85, sessions: 5, source: /Users/alfredolopez/Documents/Obsidian/MiVault/global/wiki/agent-engineering/kaizen-4-pillars.md)

- Anti-Rationalization Tables for AI Agents (confidence: 0.8, sessions: 3, source: /Users/alfredolopez/Documents/Obsidian/MiVault/global/wiki/agent-engineering/anti-rationalization.md)
```

**architecture.md**
```markdown
- Procedural Rules: Only 27 of 1003 are High-Value (confidence: 0.8, sessions: 4, source: /Users/alfredolopez/Documents/Obsidian/MiVault/global/wiki/architecture/procedural-rules-filtering.md)
```

**backend.md**
```markdown
---
paths:
  - "src/services/**/*"
  - "src/api/**/*"
  - "src/controllers/**/*"
  - "**/*.ts"
---

# Backend Rules (Auto-learned)

Rules from procedural memory. Confidence >= 0.7, usage >= 3.

## Rules

- Uses async/await for asynchronous operations
- Implements metrics/observability
- Implements error handling. Implements structured logging
- Implements caching strategy. Uses schema validation
```

### Format Patterns
1. **Narrative Rules** (agent-engineering, architecture, security): Bullet-list with `confidence:` + `sessions:` + `source:`
2. **Technical Rules** (backend, frontend, database): YAML frontmatter with `paths:` + Markdown heading + bullet list

### All 9 Domains
1. `agent-engineering.md` - Narrative
2. `architecture.md` - Narrative
3. `backend.md` - Technical (paths)
4. `database.md` - Technical
5. `frontend.md` - Technical
6. `general.md` - Mixed
7. `hooks.md` - Technical
8. `security.md` - Technical
9. `testing.md` - Technical

---

## 3. PROCEDURAL MEMORY

### Schema (Current)
**File**: `~/.ralph/procedural/rules.json` (1.1MB)

```json
{
  "rules": [
    {
      "rule_id": "string (e.g., 'backend-001')",
      "name": "string",
      "domain": "string | null (backend, frontend, database, security, testing, hooks, architecture, agent-engineering, general, all)",
      "category": "string | null (mirrors domain)",
      "confidence": "float (0.0-1.0, threshold 0.7 for graduation)"
    }
  ]
}
```

### Sample Entry
```json
{
  "rule_id": "backend-001",
  "name": "API Handler",
  "domain": "backend",
  "category": "backend",
  "confidence": 0.9
}
```

### Current State
- **Size**: 1.1MB
- **Rule Count**: ~5000+ entries
- **Graduation Threshold**: confidence >= 0.7, usage >= 3 sessions, confirmed in >= 3 sessions
- **No timestamp field** in current schema (⚠️ migration opportunity)

### Test Instances (Non-Production)
- `~/.ralph/test-learning-81969/procedural/rules.json` (592B, test data)
- `~/.ralph/test-learning-82443/procedural/rules.json` (592B, test data)
- `~/.ralph/test-learning-82947/procedural/rules.json` (592B, test data)

---

## 4. CLAUDE-MEM & MEMVID INTEGRATION

### Current Status: **MIGRATION COMPLETE, LEGACY CLEANUP IN PROGRESS**

### Removed Components
- **memvid.json**: Deleted from `~/.ralph/memory/` (175KB, purpose unclear)
- **semantic.json**: Deleted (62KB, deprecated after claude-mem)
- **memvid tool**: Removed from `scripts/ralph` (tool definition + validation function)

### Remaining Claude-mem References
**Active MCP Integration**:
- **Location**: `~/.claude-mem/claude-mem.db` (active MCP server)
- **Data**: 21,129+ observations stored locally
- **Integration**: `smart-memory-search.sh` queries this as primary source

**Auto-generated CLAUDE.md sections** (non-breaking):
- `.config/opencode/CLAUDE.md` - `<claude-mem-context>` tags
- `.gemini/CLAUDE.md` - `<claude-mem-context>` tags
- `frontend/src/pages/CLAUDE.md` - `<claude-mem-context>` tags
- README.es.md - References in architecture diagram

### Legacy Memvid Hook Fallbacks (Graceful Degradation)
| Hook | Behavior | Impact |
|------|----------|--------|
| `pre-compact-handoff.sh` | Fails gracefully if memvid missing | Non-blocking |
| `session-start-repo-summary.sh` | Creates empty memvid.json if needed | Non-blocking |
| `smart-memory-search.sh` | Skips memvid layer (works without) | Reduced search depth (4→5 sources) |

### Safe to Remove
- All memvid references (already non-blocking)
- `<claude-mem-context>` auto-gen tags (docstring only)
- Memvid vector search fallback (smart-memory-search.sh Line N)

### Cannot Break
- `~/.claude-mem/claude-mem.db` (active observations, 21KB+)
- MCP server integration in settings.json
- Vault → rules graduation pipeline (depends on claude-mem for sourcing)

---

## 5. VAULT SYSTEM

### Architecture
**Root**: `~/Documents/Obsidian/MiVault/` (Obsidian vault, 6 subdirs)

```
global/
  ├─ raw/
  │   ├─ articles/
  │   ├─ papers/
  │   └─ images/
  ├─ wiki/
  │   ├─ _index.md (master index)
  │   ├─ agent-engineering/ (kaizen, anti-rationalization)
  │   ├─ architecture/ (procedural-rules-filtering, diagrams)
  │   ├─ hooks/ (hook patterns, integration)
  │   ├─ security/ (auth, encryption, compliance)
  │   ├─ testing/ (test strategies, frameworks)
  │   ├─ react/ (component patterns)
  │   └─ typescript/ (type safety rules)
  ├─ output/ (compiled wiki articles)
  └─ decisions/ (ADRs, learning decisions)
projects/ (per-project vaults, isolated)
_templates/ (Obsidian templates)
```

### Current State
- **Graduation Rules**: confidence >= 0.7, sessions >= 3, confirmed >= 3 times
- **Source Tracking**: All rules include `source: /path/to/wiki/file.md`
- **Classification**: GREEN (safe to graduate), YELLOW (experimental), RED (secrets, never store)
- **Integration**: Vault articles are SOURCE for learned rules, not vice versa

### Data Flow: Raw → Wiki → Rules
1. `session-accumulator.sh` (PostToolUse hook) → captures learnings → `raw/`
2. LLM compilation → `wiki/[domain]/` articles
3. `vault-graduation.sh` (SessionStart hook) → promotes high-confidence → `~/.claude/rules/learned/`
4. Update backlinks between wiki articles
5. Update `_index.md` and `_project-index.md`

### Integration Points
| Component | Hook | Purpose |
|-----------|------|---------|
| `session-accumulator.sh` | PostToolUse | Capture learnings during session |
| `vault-graduation.sh` | SessionStart | Promote high-confidence to rules |
| `/exit-review` | SessionStop | Classify as GREEN/YELLOW/RED |
| `smart-memory-search.sh` | Tool queries | Add vault as 5th search source |
| `pre-compact-handoff.sh` | SessionEnd | Save vault context before compaction |

---

## 6. ~/.RALPH DIRECTORY STRUCTURE

### Confirmed Existence
```
~/.ralph/
├─ episodes/ (3384 dirs, ~237KB) ✓ EXISTS
├─ procedural/ (rules.json 1.1MB) ✓ EXISTS
└─ 40+ other directories (552MB total)
```

### Key Directories for Learning
| Dir | Purpose | Size | Status |
|-----|---------|------|--------|
| `episodes/` | Session recordings/transcripts | 237KB | ✓ Active, 3384 subdirs |
| `procedural/` | `rules.json` (authoritative) | 1.1MB | ✓ Active |
| `curator/` | Curator corpus + manifests | <1MB | ✓ Active |
| `learning/` | Learning session logs | TBD | ✓ Exists |
| `sessions/` | Session state/metadata | TBD | ✓ Exists |
| `memory/` | *(deprecated, memvid removed)* | 0B | ✗ Empty |
| `cache/` | Ephemeral cache | TBD | ✓ Auto-purged |
| `checkpoints/` | Checkpoint snapshots | TBD | 7588 items, auto-managed |

### CLAUDE.md Claims vs Reality
- **Claimed**: episodes/ and procedural/ exist ✓ CONFIRMED
- **Claimed**: 21,129 observations in claude-mem ✓ CONFIRMED (via CHANGELOG)
- **Claimed**: memvid.json deleted ✓ CONFIRMED (CHANGELOG entry)

---

## MIGRATION READINESS ASSESSMENT

### Safe to Migrate
- ✓ Curator pipeline (self-contained, modular)
- ✓ Procedural rules.json (no external dependencies)
- ✓ Vault structure (already semi-independent via MCP)
- ✓ Learned rules format (just markdown lists)
- ✓ Remove all memvid references (already non-blocking)

### Requires Careful Planning
- ⚠️ Procedural schema lacks timestamps (add before migration)
- ⚠️ Vault graduation logic embedded in bash hooks (refactor to Python AAAK)
- ⚠️ Rules.json domains are hardcoded strings (add schema validation)
- ⚠️ Claude-mem MCP still active (ensure MemPalace can query it during transition)

### Dependencies to Preserve
1. **Claude-mem DB**: Keep active until MemPalace fully replaces search paths
2. **Vault articles**: Source of truth for rule graduation
3. **Learned rules .md files**: Referenced by system prompts
4. **Curator corpus**: Training data for pattern extraction

---

## RECOMMENDED MIGRATION SEQUENCE

1. **Phase 1**: Add metadata to procedural schema (timestamps, extraction_date, confidence_trend)
2. **Phase 2**: Implement AAAK layer for procedural rules (Python wrapper around rules.json)
3. **Phase 3**: Build MemPalace Librarian (AAAK subtype) to replace vault-graduation.sh
4. **Phase 4**: Redirect curator-learn.sh output to MemPalace instead of rules.json
5. **Phase 5**: Implement fallback queries (claude-mem → MemPalace → hybrid search)
6. **Phase 6**: Migrate vault articles → MemPalace "House of Learning"
7. **Phase 7**: Decommission legacy memvid/semantic hooks (non-blocking)
8. **Phase 8**: Archive procedural/rules.json (read-only backup)

---

## FILE REFERENCES FOR IMPLEMENTATION

### Core Curator Files
- `.claude/scripts/curator-learn.sh` - Pattern extraction engine
- `.claude/skills/curator/SKILL.md` - Pipeline orchestration docs
- `.claude/scripts/curator-discovery.sh` - Repo discovery
- `.claude/scripts/curator-ingest.sh` - Corpus cloning

### Procedural Memory
- `~/.ralph/procedural/rules.json` - Authoritative rules store (1.1MB)
- `~/.claude/rules/learned/*.md` - 9 domain-specific rule files

### Vault Integration
- `~/.claude/skills/vault/SKILL.md` - Vault system architecture
- `~/Documents/Obsidian/MiVault/global/wiki/` - Graduation source
- `.claude/hooks/vault-graduation.sh` - Graduation logic

### Hooks (Integration Points)
- `.claude/hooks/orchestrator-auto-learn.sh` - PreToolUse trigger
- `.claude/hooks/continuous-learning.sh` - SessionEnd extraction
- `.claude/hooks/vault-index-updater.sh` - Index updates
- `.claude/hooks/smart-memory-search.sh` - Multi-source search

### Config
- `settings.json` - Hook registrations + claude-mem MCP config
- `~/.claude/rules/learned/` - Generated from vault via graduation

---

**Next Step**: Review this map with user → Approve architecture → Begin Phase 1 implementation
