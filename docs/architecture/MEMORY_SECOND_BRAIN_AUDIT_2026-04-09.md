# Memory & Second Brain Audit — 2026-04-09

**Auditor**: Ralph (GLM-5)  
**Scope**: Memory architecture, Karpathy LLM Wiki alignment, "Second Brain" reality check  
**Status**: HONEST ASSESSMENT

---

## Executive Summary

**Do we have a real "Second Brain"? NO.**  
We have the *infrastructure skeleton* for one, but the actual knowledge circulation is broken. The system has 5 memory subsystems, but only 2 are alive (L0+L1). The vault is under-populated (8 global wiki articles). Agent diaries are empty. L2 and L3 are dead code. There is no query→writeback loop, no automatic lint, and no ingest pipeline.

**What we DO have**: An excellent session wake-up system (616 tokens) and a working graduation pipeline (vault → rules). This is a **"read-only index"**, not a living knowledge base.

---

## 1. Current Memory Map — What's ACTUALLY Working

### Memory Types (Cognitive Science Framework)

| Type | Purpose | Ralph Implementation | Status | Population |
|------|---------|---------------------|--------|------------|
| **Semantic** | General knowledge, rules, patterns | L1_essential.md + rules/learned/ + rules/proven/ | ✅ LIVE | 9 rules (L1) + 14 files (learned) + 6 files (proven) |
| **Procedural** | How to do things (skills, workflows) | .claude/skills/ + hooks/ | ✅ LIVE | 60+ skills, 67+ hooks |
| **Episodic** | Session history, what happened when | .ralph/ledgers/ + handoffs/ | ⚠️ PASSIVE | 456 ledgers (written, rarely read) |
| **Identity** | Who am I, what are my principles | L0_identity.md | ✅ LIVE | 239 tokens |
| **Project Context** | Current project state, decisions | Auto-memory (informal L2) | ⚠️ INFORMAL | 20 memory files |

### Layer Stack Reality Check

| Layer | Design Purpose | Actual Status | Token Cost | Population |
|-------|---------------|---------------|------------|------------|
| **L0** (Identity) | Agent identity + principles | ✅ **ALIVE** — loaded every session | ~133 tokens | Static, human-maintained |
| **L1** (Essential) | Top 9 rules from 2028 | ✅ **ALIVE** — loaded every session | ~482 tokens | Auto-generated from rules.json |
| **L2** (Project Wings) | Per-project context on-demand | ❌ **DEAD CODE** — exists in layers.py, zero callers | 0 tokens | Directory EMPTY |
| **L3** (Vault Queries) | Obsidian vault grep | ❌ **DEAD CODE** — grepper exists, never invoked | 0 tokens | 54 MD files in vault but unreachable via L3 |

### What Replaces L2/L3 (Informal Mechanisms)

| Mechanism | Location | Status | Problem |
|-----------|----------|--------|---------|
| Auto-memory | `~/.claude/projects/*/memory/` | ✅ Works | Not integrated with vault; Claude-managed, not vault-managed |
| Learned rules | `.claude/rules/learned/` | ✅ Works | Taxonomy exists (halls/rooms/wings) but sparse |
| Proven rules | `.claude/rules/proven/` | ✅ Works | Only 6 rules graduated; threshold very high |
| CLAUDE.md rules | Loaded as project instructions | ✅ Works | Static, not auto-updated |
| Vault grep | Manual (Claude reads vault files) | ⚠️ Ad-hoc | No automated retrieval; L3 grepper unused |

---

## 2. Karpathy LLM Wiki — Architecture

### Core Model (3 Layers)

```
┌─────────────────────────────────────────┐
│  SCHEMA (CLAUDE.md / AGENTS.md)         │  ← Human+LLM co-evolved
│  Structure, conventions, workflows       │
├─────────────────────────────────────────┤
│  WIKI (LLM-generated markdown)          │  ← LLM OWNS this entirely
│  Summaries, entities, concepts, index    │
├─────────────────────────────────────────┤
│  RAW SOURCES (immutable)                │  ← Human curates
│  PDFs, articles, images, data            │
└─────────────────────────────────────────┘
```

### Core Operations Cycle

```
INGEST ──→ QUERY ──→ LINT ──→ (repeat)
  │           │          │
  │           │          └─ Auto-detect: contradictions, orphans, stale claims
  │           └─ Good answers get FILED BACK as new wiki pages (compounding!)
  └─ Drop source → LLM processes → updates 10-15 wiki pages + index
```

### Key Principles

| # | Principle | Description |
|---|-----------|-------------|
| P1 | **Compilation over Retrieval** | Don't re-derive from raw sources every time. Compile once, maintain incrementally. |
| P2 | **LLM is Writer/Maintainer** | "You rarely write or edit the wiki manually; it's the domain of the LLM." |
| P3 | **Knowledge Compounds** | Every query, answer, chart gets filed back. Sessions accumulate, not evaporate. |
| P4 | **Markdown as Universal Format** | .md files are LLM-native, human-readable, git-versionable, future-proof. |
| P5 | **File-over-App** | No SaaS lock-in. User owns the data. AI "visits" files to work. |
| P6 | **Incremental Compilation** | New data integrates into existing structure, not reprocessed from scratch. |
| P7 | **No Vector DB at Personal Scale** | index.md + LLM context sufficient at ~100 sources / 400K words. |

### Navigation: index.md as the "Front Door"

- LLM reads index.md first (one-line summary per page)
- Identifies relevant pages, drills into specifics
- Progressive disclosure: metadata (~300 tokens/entry) → full content on demand
- At ~100 articles, works "surprisingly well" without embeddings

---

## 3. Gap Analysis — Ralph vs. Karpathy

### Critical Gaps

| Gap | Karpathy Has | Ralph Status | Impact |
|-----|-------------|-------------|--------|
| **G1: No Ingest Pipeline** | Drop source → auto-process → wiki update | Manual vault population only | Knowledge doesn't flow IN automatically |
| **G2: No Query→Writeback Loop** | Good queries filed back as new pages | Queries are one-shot; answers evaporate | No compounding |
| **G3: No Lint/Maintenance** | Auto-detect contradictions, orphans, stale | No lint capability | Wiki degrades over time |
| **G4: L2/L3 Dead Code** | On-demand retrieval via index.md | L2 empty, L3 grepper unused | Can't access vault knowledge in-session |
| **G5: Sparse Wiki** | 100+ articles, 400K words | 8 global wiki articles | Not enough knowledge to be useful |
| **G6: Empty Agent Diaries** | Agent activity logged | Diaries exist but are EMPTY | No episodic memory from agents |
| **G7: Unidirectional Graduation** | Wiki is read AND written by LLM | Vault → rules only; no write-back | Half-pipeline, not a cycle |
| **G8: No index.md Navigation** | LLM uses index as front door | Vault has _index.md but L3 dead; never read in-session | Can't find relevant knowledge |

### What Ralph Gets RIGHT (vs. Karpathy)

| Aspect | Ralph Advantage |
|--------|----------------|
| **Session wake-up** | L0+L1 at 616 tokens — more structured than Karpathy's generic CLAUDE.md |
| **Rule graduation** | 2028 → 9 rules pipeline — Karpathy has no equivalent |
| **Security hooks** | 37 security tests, git-safety-guard — Karpathy mentions none |
| **Multi-agent** | 6 specialized teammates — Karpathy is single-agent |
| **Token discipline** | Measured with tiktoken, budgets enforced — Karpathy relies on index.md navigation |
| **Memory taxonomy** | Halls/rooms/wings = structured ontology — Karpathy uses flat wiki |

---

## 4. Memory Type Audit — Where Each Type Lives

### Episodic Memory (What happened)

| Store | Contents | Write Path | Read Path | Status |
|-------|----------|------------|-----------|--------|
| `.ralph/ledgers/` | Session summaries | session-end hook | Manual only | ⚠️ Passive |
| `.ralph/handoffs/` | Session handoffs | session-end hook | Subagent spawn | ⚠️ Conditional |
| Agent diaries | Per-agent activity | **EMPTY** | **EMPTY** | ❌ Dead |
| Obsidian facts/ | Project facts by date | vault-graduation hook | L3 dead; manual grep | ⚠️ Unreachable |
| Log (Karpathy) | Append-only chronological log | **MISSING** | **MISSING** | ❌ Missing |

**Assessment**: Episodic memory is written but never READ for decision-making. No Karpathy-style log.md exists. Agents don't record their work.

### Procedural Memory (How to do things)

| Store | Contents | Write Path | Read Path | Status |
|-------|----------|------------|-----------|--------|
| `.claude/skills/` | 60+ skills | Manual | Skill tool | ✅ Live |
| `.claude/hooks/` | 67+ hooks | Manual | Claude Code runtime | ✅ Live |
| `rules/learned/` | Taxonomized rules | Vault graduation | Loaded by domain | ✅ Live |
| `rules/proven/` | Top-confidence rules | Auto-graduation | Always loaded | ✅ Live |

**Assessment**: Procedural memory is the strongest part of the system. Skills and hooks are well-organized and actively used.

### Semantic Memory (General knowledge)

| Store | Contents | Write Path | Read Path | Status |
|-------|----------|------------|-----------|--------|
| Obsidian vault wiki/ | 8 articles | Manual/AI-assisted | L3 dead; manual only | ⚠️ Sparse |
| L1_essential.md | 9 rules | Auto-generated from rules.json | SessionStart hook | ✅ Live |
| Obsidian vault decisions/ | 247 JSON decisions | Session hooks | Manual only | ⚠️ Passive |
| CLAUDE.md | Project instructions | Manual | Always loaded | ✅ Live |

**Assessment**: Semantic memory is thin. The vault has only 8 wiki articles — this is the biggest gap. 247 decisions exist as JSON but are never queried in-session.

---

## 5. The "Second Brain" Verdict

### Current State: "Read-Only Index" (Level 2/5)

| Level | Name | Description | Ralph? |
|-------|------|-------------|--------|
| 1 | **None** | No persistent memory | — |
| 2 | **Read-Only Index** | Static knowledge, no feedback loop | ← **HERE** |
| 3 | **One-Way Pipeline** | Knowledge flows in, gets curated, but doesn't cycle | Close on graduation |
| 4 | **Living Wiki** | Auto-ingest, query-writeback, lint, compounding | Karpathy's target |
| 5 | **Fine-tuned Intelligence** | Knowledge in model weights | Future (Karpathy's long-term vision) |

### Why Level 2, Not Higher

1. **No INGEST**: Can't drop a source and have it auto-processed
2. **No WRITEBACK**: Good queries don't get filed back into the wiki
3. **No LINT**: No auto-detection of contradictions, orphans, or stale claims
4. **No RETRIEVAL**: L3 is dead; can't access vault knowledge in-session via automated means
5. **No COMPOUNDING**: Each session starts fresh (except L0+L1 rules)
6. **No LOG**: No chronological record of what was explored/learned

### What's Working Well (Keep These!)

1. L0+L1 wake-up at 616 tokens — excellent token discipline
2. Graduation pipeline (vault → learned → proven → L1) — unique, Karpathy doesn't have this
3. Token measurement with tiktoken — data-driven, not guessed
4. Halls/rooms/wings taxonomy — structured ontology, better than flat wiki
5. Security layer — 37 tests, git safety, no Karpathy equivalent
6. Multi-agent coordination — 6 specialized teammates

---

## 6. Recommendations — Path to "Level 4: Living Wiki"

### Phase 1: Fix the Broken Cycle (Highest Impact)

**R1: Revive L3 as Vault Query Engine**
- Replace dead L3 grepper with Karpathy-style index.md navigation
- Implement: SessionStart reads vault `_index.md`, caches page summaries
- On query: grep vault for relevant terms, return top-N snippets
- Token cost: ~500 tokens for index + ~200 per drill-down

**R2: Add Query→Writeback Hook**
- New PostToolUse hook: when Claude generates a good analysis/answer, offer to file it back to vault
- Implementation: `query-writeback.sh` triggered on significant findings
- Target: `~/Documents/Obsidian/MiVault/projects/{project}/wiki/` or `global/wiki/`

**R3: Implement log.md (Karpathy Pattern)**
- Append-only chronological log at `~/Documents/Obsidian/MiVault/log.md`
- Entries: `[YYYY-MM-DD HH:MM] ingest|query|lint | summary`
- Parseable: `grep "^## \[" log.md | tail -5`

### Phase 2: Populate the Wiki (Medium Impact)

**R4: Auto-Ingest Pipeline**
- Watch `~/Documents/Obsidian/MiVault/global/raw/` for new sources
- On new file: LLM reads, extracts key points, writes summary to wiki/
- Updates 10-15 relevant existing wiki pages with cross-references
- Updates index.md

**R5: Populate Agent Diaries**
- Each ralph-* agent should write to `~/Documents/Obsidian/MiVault/agents/{name}/diary/`
- Hook: TeammateIdle → append diary entry with task summary
- Creates episodic memory from agent work

**R6: Backfill Decisions as Wiki Pages**
- 247 JSON decisions in vault → convert to proper wiki articles
- Each decision gets a markdown page with context, rationale, date
- Cross-referenced in index.md

### Phase 3: Add Lint (Lower Priority)

**R7: Vault Lint Hook**
- Periodic (daily/weekly): scan vault for contradictions between pages
- Flag orphan pages with no inbound links
- Detect stale claims (>30 days since last update)
- Suggest new questions to investigate

**R8: Knowledge Decay**
- Implement confidence decay: older learnings gradually lose confidence
- Re-verification: prompt user to confirm still-valid knowledge
- Thinking-MCP pattern: "values persist but fleeting ideas fade"

### Phase 4: Deep Integration (Future)

**R9: Remove L2/L3 Dead Code**
- Delete Layer2 and Layer3 classes from layers.py
- Replace with Karpathy-style index.md navigation (R1)
- Document the ACTUAL memory mechanisms (not aspirational ones)

**R10: Fine-tuning Pipeline**
- As wiki grows and stabilizes, use it as synthetic training data
- Fine-tune smaller model on vault content
- Per Karpathy: "the wiki becomes the training set"

---

## 7. Integration with Karpathy Model — Target Architecture

```
                    KARPATHY MODEL           RALPH CURRENT         RALPH TARGET
                    ─────────────           ─────────────         ─────────────
RAW SOURCES         raw/ (immutable)         global/raw/ EMPTY     ✅ Same path
                    LLM reads only           Nothing reads         LLM reads on ingest

WIKI                LLM-generated .md        8 articles (sparse)   Auto-generated
                    Summaries, entities      Manual + AI-assisted   LLM writes/maintains
                    index.md navigation      _index.md exists       index.md as front door
                    log.md chronological     MISSING                log.md append-only

SCHEMA              CLAUDE.md conventions    L0+L1 (616 tokens)    ✅ Already excellent
                    Structure, workflows     Rules taxonomy         ✅ halls/rooms/wings

OPERATIONS
  INGEST            Auto-process sources     Manual only            Auto from raw/
  QUERY             NL → search → answer     Ad-hoc grep            L3 revived with index
  WRITEBACK         Good answers → wiki      Answers evaporate      PostToolUse hook
  LINT              Auto-detect issues       No lint                Vault lint hook
  COMPOUND          Every session adds       L0+L1 only             Full cycle

MEMORY TYPES
  Episodic          log.md                   Ledgers (passive)      log.md + agent diaries
  Procedural        Skills (manual)          60+ skills ✅          Same (already good)
  Semantic          Wiki pages               8 articles             Auto-populated wiki
```

---

## 8. Sources

- Karpathy's Gist: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
- VentureBeat analysis: https://venturebeat.com/data/karpathy-shares-llm-knowledge-base-architecture-that-bypasses-rag-with-an/
- DAIR.AI Academy: https://academy.dair.ai/blog/llm-knowledge-bases-karpathy
- MindStudio guide: https://www.mindstudio.ai/blog/andrej-karpathy-llm-wiki-knowledge-base-claude-code/
- SwarmVault, Sage-Wiki, Thinking-MCP implementations referenced in analysis

---

*Audit completed 2026-04-09. Next step: Phase 1 recommendations for a planning session.*
