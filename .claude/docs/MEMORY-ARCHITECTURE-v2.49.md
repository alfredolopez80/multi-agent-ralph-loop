# Memory Architecture v2.49 - Design Document

**Status**: DRAFT
**Author**: Ralph Orchestrator
**Date**: 2026-01-19
**Based on**: @rohit4verse "Stop building Goldfish AI" + LangMem Framework

---

## Executive Summary

Current v2.47 Smart Memory-Driven Orchestration is **read-only** and **synchronous**.
This proposal upgrades to a **read-write**, **dual-path** memory system inspired by LangMem.

### Key Changes

| v2.47 (Current) | v2.49 (Proposed) |
|-----------------|------------------|
| Search-only memory | Read-Write memory |
| Single synchronous path | Hot Path + Cold Path |
| Unstructured handoffs | Structured Episodic Memory |
| No behavior learning | Procedural Memory → Prompts |
| claude-mem only | claude-mem + local stores |

---

## Problem Statement

> "Most RAG systems have zero memory. They retrieve, answer, and immediately forget everything. They are Stateless. To build true Agents in 2026, we must move beyond simple retrieval."
> — @rohit4verse

### Current Limitations

1. **No Real-Time Writing**: We search memory but never write during conversation
2. **No Reflection**: No background processing to extract patterns
3. **Unstructured Episodes**: Handoffs are text blobs, not structured experiences
4. **No Behavior Evolution**: System prompts are static, don't learn from interactions
5. **No Forgetting**: Memory grows indefinitely without cleanup

---

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    RALPH MEMORY SYSTEM v2.49                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ╔═══════════════════════╗        ╔═══════════════════════╗            │
│   ║     HOT PATH          ║        ║     COLD PATH         ║            │
│   ║   (Synchronous)       ║        ║   (Asynchronous)      ║            │
│   ╠═══════════════════════╣        ╠═══════════════════════╣            │
│   ║                       ║        ║                       ║            │
│   ║  ┌─────────────────┐  ║        ║  ┌─────────────────┐  ║            │
│   ║  │ memory_write    │  ║        ║  │ReflectionEngine │  ║            │
│   ║  │ memory_search   │  ║        ║  │ (Stop hook)     │  ║            │
│   ║  │ memory_update   │  ║        ║  └────────┬────────┘  ║            │
│   ║  └────────┬────────┘  ║        ║           │           ║            │
│   ║           │           ║        ║  ┌────────▼────────┐  ║            │
│   ║  Triggers:            ║        ║  │ Pattern Extract │  ║            │
│   ║  • User says "remember"║       ║  │ Conflict Resolve│  ║            │
│   ║  • Important decision  ║       ║  │ Memory Cleanup  │  ║            │
│   ║  • Error encountered   ║       ║  └────────┬────────┘  ║            │
│   ║           │           ║        ║           │           ║            │
│   ╚═══════════╪═══════════╝        ╚═══════════╪═══════════╝            │
│               │                                │                         │
│               └──────────────┬─────────────────┘                         │
│                              ▼                                           │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                      UNIFIED MEMORY STORE                         │  │
│   ├──────────────────┬──────────────────┬────────────────────────────┤  │
│   │    SEMANTIC      │     EPISODIC     │        PROCEDURAL          │  │
│   │    (Facts)       │   (Experiences)  │       (Behaviors)          │  │
│   ├──────────────────┼──────────────────┼────────────────────────────┤  │
│   │                  │                  │                            │  │
│   │ • User prefs     │ • Situation      │ • Communication tone       │  │
│   │ • Project facts  │ • Reasoning      │ • Error handling rules     │  │
│   │ • Tech decisions │ • Actions taken  │ • Escalation patterns      │  │
│   │ • Team knowledge │ • Outcomes       │ • Tool preferences         │  │
│   │                  │ • Learnings      │                            │  │
│   │                  │                  │                            │  │
│   │ Storage:         │ Storage:         │ Storage:                   │  │
│   │ claude-mem MCP   │ ~/.ralph/        │ ~/.ralph/                  │  │
│   │ + local JSON     │ episodes/        │ procedural.json            │  │
│   │                  │                  │ → Injected to prompts      │  │
│   └──────────────────┴──────────────────┴────────────────────────────┘  │
│                                                                          │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                    MEMORY LIFECYCLE MANAGER                       │  │
│   │  • TTL-based expiration (configurable per type)                  │  │
│   │  • Conflict resolution (latest wins / merge / ask user)          │  │
│   │  • Importance scoring (access frequency + recency)               │  │
│   │  • Automatic deduplication                                        │  │
│   └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Component Design

### 1. Hot Path: Real-Time Memory Operations

#### 1.1 Skill: `/memory`

```yaml
---
name: memory
description: Real-time memory operations during conversation
allowed-tools: Read,Write,Bash,mcp__plugin_claude-mem_*
---
# Memory Management Skill

## Commands
- `/memory write <type> <content>` - Store immediately
- `/memory search <query>` - Search all memory types
- `/memory update <id> <content>` - Update existing
- `/memory forget <id>` - Mark for deletion

## Auto-Triggers (via hook)
- User says "remember this", "don't forget", "note that"
- Error occurs (auto-store as episodic)
- Decision made (auto-store reasoning)
```

#### 1.2 Hook: `memory-write-trigger.sh`

```bash
# Trigger: UserPromptSubmit
# Detects phrases indicating memory intent

TRIGGERS=(
  "remember"
  "don't forget"
  "note that"
  "keep in mind"
  "for future reference"
)

# If trigger detected, inject memory tool availability
```

#### 1.3 Tool: `memory_write`

```python
# ~/.claude/scripts/memory-write.py

def write_memory(
    memory_type: Literal["semantic", "episodic", "procedural"],
    content: dict,
    importance: int = 5,  # 1-10
    ttl_days: Optional[int] = None
) -> str:
    """
    Write to appropriate memory store.

    Args:
        memory_type: Which memory system
        content: Structured content (schema varies by type)
        importance: Priority for retention
        ttl_days: Auto-expire after N days

    Returns:
        memory_id: Reference for updates/deletion
    """
```

### 2. Cold Path: Background Reflection

#### 2.1 Hook: `reflection-engine.sh`

```bash
# Trigger: Stop (session end)
# Also: PostCompact (context limit)

# 1. Collect session transcript
# 2. Extract patterns via LLM analysis
# 3. Store to appropriate memory types
# 4. Update procedural rules if behavior patterns detected
```

#### 2.2 Reflection Tasks

| Task | Frequency | Output |
|------|-----------|--------|
| Extract Facts | Every session | Semantic entries |
| Summarize Episodes | Every session | Episodic entries |
| Detect Patterns | Every 5 sessions | Procedural updates |
| Conflict Resolution | On detection | Merged entries |
| Memory Cleanup | Weekly | Pruned entries |

#### 2.3 Script: `reflection-executor.py`

```python
# ~/.claude/scripts/reflection-executor.py

class ReflectionExecutor:
    """
    Background processing of session transcripts.
    Runs asynchronously after session ends.
    """

    def extract_semantic_facts(self, transcript: str) -> List[SemanticFact]:
        """Extract stable facts from conversation."""

    def create_episode(self, transcript: str) -> Episode:
        """Create structured episode from session."""

    def detect_behavior_patterns(self,
                                  recent_episodes: List[Episode]
                                  ) -> List[ProceduralRule]:
        """Identify recurring patterns → procedural rules."""

    def resolve_conflicts(self,
                          new_facts: List[SemanticFact]
                          ) -> List[SemanticFact]:
        """Handle contradicting information."""
```

### 3. Structured Episodic Memory

#### 3.1 Episode Schema

```json
{
  "episode_id": "ep-2026-01-19-abc123",
  "timestamp": "2026-01-19T01:30:00Z",
  "session_id": "session-xyz",
  "project": "multi-agent-ralph-loop",

  "situation": {
    "task": "Implement security scanning for quality gates",
    "context": "User requested semgrep + gitleaks integration",
    "constraints": ["No GitHub Actions", "Local execution only"]
  },

  "reasoning": {
    "approach": "Integrate into existing quality-gates-v2.sh hook",
    "alternatives_considered": [
      "Separate hook (rejected: two hooks per file)",
      "Manual skill (rejected: not automatic)"
    ],
    "decision_factors": ["Efficiency", "Single pass", "Maintainability"]
  },

  "actions": [
    {
      "type": "create",
      "target": "scripts/install-security-tools.sh",
      "description": "Installation script for semgrep + gitleaks"
    },
    {
      "type": "modify",
      "target": "~/.claude/hooks/quality-gates-v2.sh",
      "description": "Added Stage 2.5 SECURITY"
    }
  ],

  "outcome": {
    "success": true,
    "tests_passed": 20,
    "user_satisfaction": "confirmed",
    "artifacts_created": [
      "scripts/install-security-tools.sh",
      "tests/test_security_scan.py"
    ]
  },

  "learnings": [
    "Security tools can run locally without CI/CD",
    "Graceful degradation is key for optional dependencies",
    "One-time installation hints reduce friction"
  ],

  "tags": ["security", "hooks", "quality-gates", "v2.48"],
  "importance": 8
}
```

#### 3.2 Episode Storage

```
~/.ralph/
├── episodes/
│   ├── index.json              # Quick lookup by tags/date
│   ├── 2026-01/
│   │   ├── ep-2026-01-19-abc123.json
│   │   ├── ep-2026-01-19-def456.json
│   │   └── ...
│   └── embeddings/             # Vector embeddings for search
│       └── episodes.mv2        # Memvid format
```

### 4. Procedural Memory → System Prompts

#### 4.1 Procedural Rules Schema

```json
{
  "procedural_id": "proc-code-review-001",
  "created": "2026-01-15",
  "last_updated": "2026-01-19",
  "confidence": 0.92,
  "source_episodes": ["ep-xxx", "ep-yyy", "ep-zzz"],

  "rule": {
    "trigger": "User requests code review",
    "behavior": "Always check for security issues first, then functionality",
    "rationale": "Detected pattern: user prefers security-first reviews"
  },

  "injection_point": "PreToolUse",
  "prompt_template": "When reviewing code, prioritize security analysis before functionality checks. This aligns with user preferences."
}
```

#### 4.2 Procedural Injection Hook

```bash
# Hook: PreToolUse (Task)
# Injects relevant procedural rules into subagent context

# 1. Load ~/.ralph/procedural.json
# 2. Match rules to current task context
# 3. Inject via additionalContext
```

---

## Implementation Plan

### Phase 1: Foundation (v2.49.0)

| Task | Priority | Effort |
|------|----------|--------|
| Episode schema definition | HIGH | LOW |
| Episode storage structure | HIGH | LOW |
| Basic `memory_write` tool | HIGH | MEDIUM |
| Reflection hook (Stop) | HIGH | MEDIUM |

### Phase 2: Hot Path (v2.49.1)

| Task | Priority | Effort |
|------|----------|--------|
| `/memory` skill | HIGH | LOW |
| Write trigger detection | MEDIUM | LOW |
| Real-time semantic storage | HIGH | MEDIUM |
| Integration with claude-mem | HIGH | MEDIUM |

### Phase 3: Cold Path (v2.49.2)

| Task | Priority | Effort |
|------|----------|--------|
| ReflectionExecutor script | HIGH | HIGH |
| Pattern detection (LLM-based) | MEDIUM | HIGH |
| Procedural rule generation | MEDIUM | HIGH |
| Memory lifecycle manager | MEDIUM | MEDIUM |

### Phase 4: Integration (v2.49.3)

| Task | Priority | Effort |
|------|----------|--------|
| Procedural → prompt injection | HIGH | MEDIUM |
| Episode search in orchestrator | HIGH | MEDIUM |
| Conflict resolution system | MEDIUM | MEDIUM |
| Dashboard for memory inspection | LOW | MEDIUM |

---

## Configuration

```json
// ~/.ralph/config/memory-config.json
{
  "version": "2.49.0",

  "hot_path": {
    "enabled": true,
    "auto_triggers": ["remember", "note", "don't forget"],
    "max_writes_per_session": 20
  },

  "cold_path": {
    "enabled": true,
    "reflection_on_stop": true,
    "reflection_on_compact": true,
    "pattern_detection_threshold": 3  // episodes before pattern detection
  },

  "semantic": {
    "storage": "claude-mem",  // or "local"
    "ttl_days": null,  // never expire
    "max_entries": 10000
  },

  "episodic": {
    "storage": "local",
    "ttl_days": 90,
    "max_entries": 1000,
    "embeddings": true
  },

  "procedural": {
    "storage": "local",
    "min_confidence": 0.7,
    "max_rules": 50,
    "inject_to_prompts": true
  },

  "lifecycle": {
    "cleanup_interval_days": 7,
    "importance_decay": 0.1,  // per week
    "min_importance_to_keep": 3
  }
}
```

---

## Migration Path

### From v2.47 to v2.49

1. **Existing claude-mem data**: Migrated as Semantic Memory
2. **Existing handoffs**: Converted to Episodes (one-time script)
3. **Existing ledgers**: Kept as-is (different purpose)
4. **New structures**: Created on first run

```bash
# Migration command
ralph migrate-memory --from v2.47 --to v2.49 --dry-run
ralph migrate-memory --from v2.47 --to v2.49 --execute
```

---

## Success Metrics

| Metric | Current (v2.47) | Target (v2.49) |
|--------|-----------------|----------------|
| Memory writes per session | 0 | 5-10 |
| Episodes with full structure | 0% | 90%+ |
| Procedural rules active | 0 | 10-20 |
| Memory-informed decisions | ~20% | 70%+ |
| Context reuse across sessions | Low | High |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Storage bloat | Medium | TTL + importance decay |
| Slow reflection | Low | Async execution |
| Stale procedural rules | Medium | Confidence decay + user override |
| Privacy concerns | High | Local-first storage, opt-in cloud |

---

## References

1. @rohit4verse "Stop building Goldfish AI" - https://twitter-thread.com/t/2000967807333491131
2. LangMem Framework - github.com/langchain-ai/langmem
3. Rohit Sharma LinkedIn Article - "Building Truly Adaptive AI Agents"
4. Ralph v2.47 Smart Memory Search - Current implementation

---

## Approval

- [ ] Architecture review
- [ ] Security review (local storage)
- [ ] Performance review (reflection overhead)
- [ ] User approval to proceed

**Next Step**: Review this document and approve implementation phases.
