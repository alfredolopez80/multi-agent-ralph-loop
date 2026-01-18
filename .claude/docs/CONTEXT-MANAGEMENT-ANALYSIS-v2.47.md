# Context Management Analysis - v2.47 Proposal

> **Author**: Claude Opus 4.5 (Orchestrator)
> **Date**: 2026-01-18
> **Status**: Analysis Complete - Awaiting User Approval
> **Based On**:
>   - Software Engineering Agents Survey (arXiv:2511.18538v5) - Sections 5, 6, 7
>   - Claude Code Cowork Mode Prompt (affaanmustafa tweet)
>   - llm-tldr Integration
>   - Current Ralph v2.46.1 Implementation

---

## 1. Problem Statement

### 1.1 Observed Issue

El usuario reporta una inconsistencia critica:
- **StatusLine (claude-hud)**: Muestra 50% de contexto usado
- **Sistema**: Constantemente emite warnings de contexto al 100% o necesidad de compactar

### 1.2 Root Cause Analysis

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONTEXT MONITORING INCONSISTENCY                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  StatusLine (claude-hud)          context-warning.sh                        │
│  ├── Uses claude --print          ├── Uses fallback estimation              │
│  │   "/context"                   │   when CLI unavailable                  │
│  ├── Accurate in CLI mode         ├── operation_counter / 4                 │
│  └── May not update in            │   + message_count * 2                   │
│      real-time                    └── Can diverge significantly             │
│                                                                              │
│  Current counter values:                                                    │
│  - operation_counter: 2321        → 2321/4 = 580 (clamped to 100%)         │
│  - message_count: 78              → 78*2 = 156 (clamped to 100%)           │
│                                                                              │
│  Problem: Counters NEVER RESET between sessions!                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Contributing Factors

1. **Counter Accumulation**: `operation-counter` y `message_count` nunca se resetean al iniciar nueva sesion
2. **Fallback Estimation Drift**: La estimacion por operaciones diverge de la realidad
3. **Environment Detection Gaps**: El sistema no siempre detecta correctamente CLI vs Extension
4. **No Auto-Compaction Trigger**: Claude Code auto-compacta al 80%, pero los hooks pueden no dispararse

---

## 2. Current Architecture Review

### 2.1 Context Preservation Flow (v2.46.1)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CURRENT CONTEXT FLOW (v2.46.1)                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SessionStart                                                               │
│  ├── session-start-welcome.sh     (timeout: 5s)                            │
│  ├── session-start-ledger.sh      (timeout: 5s)  → Load ledger             │
│  ├── auto-sync-global.sh          (timeout: 10s)                           │
│  └── session-start-tldr.sh        (timeout: 30s) → llm-tldr warm           │
│                                                                              │
│  UserPromptSubmit                                                           │
│  ├── context-warning.sh           (timeout: 5s)  → WARNING: Uses counters  │
│  ├── periodic-reminder.sh         (timeout: 5s)                            │
│  └── prompt-analyzer.sh           (timeout: 5s)                            │
│                                                                              │
│  PostToolUse (Edit|Write)                                                   │
│  ├── quality-gates-v2.sh          (timeout: 300s)                          │
│  ├── checkpoint-auto-save.sh      (timeout: 60s)                           │
│  ├── plan-sync-post-step.sh       (timeout: 30s)                           │
│  ├── progress-tracker.sh          (timeout: 10s)                           │
│  └── auto-save-context.sh         (timeout: 5s)  → Increments counter      │
│                                                                              │
│  PreCompact (when triggered)                                                │
│  └── pre-compact-handoff.sh       (timeout: ??)  → Save ledger + handoff   │
│                                                                              │
│  SessionStart:compact                                                       │
│  ├── post-compact-restore.sh      (timeout: 10s)                           │
│  └── session-start-ledger.sh      (timeout: 5s)  → Reload ledger           │
│                                                                              │
│  MISSING:                                                                   │
│  ├── Counter reset on SessionStart                                         │
│  ├── Accurate context % detection                                          │
│  └── Proactive context optimization                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Components Analysis

| Component | Status | Issue |
|-----------|--------|-------|
| `session-start-ledger.sh` | OK | Loads ledger correctly |
| `context-warning.sh` | BROKEN | Counter-based estimation drifts |
| `auto-save-context.sh` | PARTIAL | Saves but doesn't optimize |
| `pre-compact-handoff.sh` | OK | Works when triggered |
| `post-compact-restore.sh` | OK | Restores correctly |
| `detect-environment.sh` | OK | Detects CLI vs Extension |
| `ledger-manager.py` | OK | CRUD works |
| `context-extractor.py` | OK | Rich extraction works |

---

## 3. Research Findings

### 3.1 From Software Engineering Agents Survey (Sections 5, 6, 7)

#### Section 5: SWE Agents - Key Insights

1. **Hierarchical Architecture** (Issue Resolving):
   - Layer 1: Foundation Interface (ACI)
   - Layer 2: Multi-Agent Collaboration
   - Layer 3: Knowledge Layer (Code Knowledge Graphs)
   - Layer 4: Semantic Layer (Intent & Consistency)
   - Layer 5: Intelligence Layer (Self-Evolution)

   **Aplicacion**: El orchestrator deberia operar en Layer 4-5, delegando contexto a layers inferiores.

2. **Feedback-based Optimization**:
   - Tests, SAST, execution feedback transforman generacion en busqueda guiada
   - **Aplicacion**: Usar feedback de context-warning para triggerar compaction proactivamente

3. **Knowledge Graphs for Code**:
   - CODEXGRAPH, CGM integran LLM + graph database
   - **Aplicacion**: llm-tldr ya provee esto - profundizar integracion

#### Section 6: Code as... - Key Insights

1. **Memory With Code** (6.2.3):
   - Codigo como mecanismo de memoria
   - Persistencia de estado
   - Recuperacion de contexto
   - **Aplicacion**: Structured summary sections (Anchored Iterative Summarization)

2. **Model Context Protocol (MCP)** (6.1.2):
   - Protocolo estandar para comunicacion
   - Gestion de estado
   - **Aplicacion**: claude-mem MCP ya integrado - optimizar queries

#### Section 7: Safety - Key Insights

1. **Defense-in-Depth Architecture**:
   - Layer 1: Secure Execution Environments
   - Layer 2: Proactive Pre-Execution Validation
   - Layer 3: Runtime Oversight

   **Aplicacion al Context**:
   - Layer 1: Context isolation (worktrees)
   - Layer 2: Pre-compaction validation
   - Layer 3: Runtime context monitoring

### 3.2 From Claude Code Cowork Mode Prompt

Key discoveries from the official prompt:

1. **AskUserQuestion Tool**: "ALWAYS use this tool before starting any real work"
   - Even simple requests are often **underspecified**
   - Asking upfront prevents wasted effort

2. **TodoList Tool**: "Claude MUST use TodoWrite for virtually ALL tasks"
   - Nicely rendered as widget
   - Provides structure and tracking

3. **Task Tool for Subagents**:
   - **Parallelization**: Independent items with multiple steps
   - **Context-hiding**: High-token-cost subtasks without distraction

4. **Knowledge Cutoff**: End of May 2025
   - Model versions: claude-opus-4-5-20251101, claude-sonnet-4-5-20250929, claude-haiku-4-5-20251001

5. **Formatting**: Minimal formatting by default
   - Prose and paragraphs, not lists unless essential

### 3.3 From Context Engineering Skills

#### context-compression (skill)

**Anchored Iterative Summarization**:
```markdown
## Session Intent
[What the user is trying to accomplish]

## Files Modified
- auth.controller.ts: Fixed JWT token generation
- config/redis.ts: Updated connection pooling

## Decisions Made
- Using Redis connection pool instead of per-request

## Current State
- 14 tests passing, 2 failing

## Next Steps
1. Fix remaining test failures
```

**Key Insight**: Structure forces preservation. Dedicated sections act as checklists.

#### context-degradation (skill)

**Degradation Patterns**:
1. **Lost-in-Middle**: U-shaped attention (beginning/end favored)
2. **Context Poisoning**: Errors compound through repeated reference
3. **Context Distraction**: Irrelevant info overwhelms relevant
4. **Context Confusion**: Cannot determine which context applies
5. **Context Clash**: Accumulated info directly conflicts

**Thresholds**:
| Model | Degradation Onset | Severe Degradation |
|-------|-------------------|-------------------|
| Claude Opus 4.5 | ~100K tokens | ~180K tokens |
| Claude Sonnet 4.5 | ~80K tokens | ~150K tokens |

**Optimization Target**: tokens-per-task, NOT tokens-per-request

---

## 4. Proposed Solution: v2.47 Context Engineering Overhaul

### 4.1 Core Changes

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    v2.47 CONTEXT MANAGEMENT ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ Layer 5: PROACTIVE CONTEXT OPTIMIZATION                             │    │
│  │ ├── Automatic counter reset on SessionStart                         │    │
│  │ ├── Threshold-based proactive compaction (70% trigger)              │    │
│  │ ├── Anchored Iterative Summarization                                │    │
│  │ └── tokens-per-task optimization                                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                           │                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ Layer 4: ACCURATE CONTEXT MONITORING                                │    │
│  │ ├── claude-hud native integration                                   │    │
│  │ ├── StatusLine context_window.used_percentage                       │    │
│  │ ├── Fallback estimation (calibrated)                                │    │
│  │ └── Periodic validation (every 10 operations)                       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                           │                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ Layer 3: STRUCTURED CONTEXT PRESERVATION                            │    │
│  │ ├── session-ledger.md (Anchored format)                             │    │
│  │ ├── claude-mem MCP for semantic search                              │    │
│  │ ├── llm-tldr for code context                                       │    │
│  │ └── progress.md for task tracking                                   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                           │                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ Layer 2: CONTEXT INJECTION                                          │    │
│  │ ├── SessionStart: Load ledger (beginning of context)                │    │
│  │ ├── PostCompact: Restore summary (end of context)                   │    │
│  │ └── Position-aware (avoid lost-in-middle)                           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                           │                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ Layer 1: COUNTER MANAGEMENT                                         │    │
│  │ ├── Reset counters on SessionStart                                  │    │
│  │ ├── Calibrated estimation (0.1% per tool call, 1.5% per message)   │    │
│  │ └── Sync with claude-hud StatusLine                                 │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Specific Fixes

#### Fix 1: Counter Reset on SessionStart

```bash
# In session-start-ledger.sh - ADD at beginning:

# Reset counters for fresh session
COUNTER_DIR="${HOME}/.ralph/state"
echo "0" > "${COUNTER_DIR}/operation-counter"
echo "0" > "${COUNTER_DIR}/message-count"

# Also reset on clear/compact
```

#### Fix 2: Calibrated Context Estimation

```bash
# In context-warning.sh - REPLACE estimation logic:

# Calibrated estimation based on empirical data:
# - Each tool call: ~0.1% of context
# - Each message: ~1.5% of context
# - Base overhead: 5% (system prompt, CLAUDE.md)

local ops=$(cat "${RALPH_DIR}/state/operation-counter" 2>/dev/null || echo "0")
local msgs=$(cat "${RALPH_DIR}/message_count" 2>/dev/null || echo "0")

# Calibrated formula
local estimated=$(echo "scale=0; 5 + ($ops / 10) + ($msgs * 15 / 10)" | bc)
[[ $estimated -gt 100 ]] && estimated=100
```

#### Fix 3: Proactive Compaction at 70%

```bash
# NEW hook: proactive-compact.sh (UserPromptSubmit)

# Trigger proactive compaction at 70%
if [[ "$context_pct" -ge 70 ]] && [[ "$context_pct" -lt 80 ]]; then
    log "INFO" "Proactive compaction recommended at ${context_pct}%"

    # Generate Anchored Summary
    generate_anchored_summary

    # Suggest compaction
    echo "📊 Context at ${context_pct}% - Consider /compact for optimal performance"
fi
```

#### Fix 4: Anchored Iterative Summarization

```bash
# NEW script: anchored-summary.py

"""
Generates structured summary with explicit sections:
- Session Intent
- Files Modified
- Decisions Made
- Current State
- Next Steps

Forces preservation through structure.
"""
```

#### Fix 5: Position-Aware Context Injection

```bash
# In session-start-ledger.sh - Position critical info at START

CONTEXT="## SESSION CONTEXT (Auto-loaded)\n\n"
CONTEXT+="### Current Goal\n$GOAL\n\n"        # CRITICAL - at start
CONTEXT+="### Next Steps\n$NEXT_STEPS\n\n"    # CRITICAL - at start
CONTEXT+="$LEDGER_DETAILS\n"                  # Less critical - middle

# In post-compact-restore.sh - Position summary at END

CONTEXT+="### Session Summary\n$SUMMARY"       # At end - attention favored
```

### 4.3 Integration with Orchestrator Steps 5, 6, 7

Based on SWE Agents Survey recommendations:

#### Step 5: DELEGATE - Context-Aware Delegation

```yaml
# v2.47 Enhancement: Context budget per subagent
Task:
  subagent_type: "code-reviewer"
  model: "sonnet"
  run_in_background: true
  context_budget: 10000  # Max tokens for this subtask
  prompt: |
    CONTEXT_INJECTION:
      goal: $ANCHORED_GOAL
      files: $RELEVANT_FILES_ONLY
      constraint: "Focus on authentication module only"
```

#### Step 6: EXECUTE-WITH-SYNC - Context Checkpointing

```yaml
# v2.47 Enhancement: Checkpoint every N steps
for step in plan.steps:
    # ... existing logic ...

    # NEW: Context checkpoint every 5 steps
    if step.index % 5 == 0:
        checkpoint_context()
        prune_irrelevant_context()
```

#### Step 7: VALIDATE - Context-Optimized Validation

```yaml
# v2.47 Enhancement: Fresh context for validation
7. VALIDATE (Quality-First + Context-Fresh)
   7a. CHECKPOINT → Save current context
   7b. SPAWN_FRESH → Fresh context validator (avoids bias)
   7c. CORRECTNESS → Meets requirements? (BLOCKING)
   7d. QUALITY → Security, performance? (BLOCKING)
   7e. RESTORE → Restore checkpointed context
```

### 4.4 New CLI Commands

```bash
# Context monitoring
ralph context status          # Show actual vs estimated context
ralph context reset           # Reset counters manually
ralph context optimize        # Run proactive optimization

# Anchored summaries
ralph summary generate        # Generate Anchored summary
ralph summary inject          # Inject summary into context

# Integration
ralph compact --anchored      # Compact with Anchored summary
ralph ledger save --anchored  # Save with structure
```

### 4.5 New Hooks (v2.47)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `context-reset.sh` | SessionStart | Reset counters to 0 |
| `proactive-compact.sh` | UserPromptSubmit (70%+) | Suggest early compaction |
| `anchored-summary.sh` | PreCompact | Generate structured summary |
| `context-sync.sh` | PostToolUse (every 10) | Validate estimation accuracy |

---

## 5. Implementation Plan

### Phase 1: Fix Immediate Issues (1 hour)

1. Add counter reset to `session-start-ledger.sh`
2. Calibrate estimation formula in `context-warning.sh`
3. Test fix with manual counter reset

### Phase 2: Proactive Optimization (2 hours)

1. Create `proactive-compact.sh` hook
2. Create `anchored-summary.py` script
3. Update `pre-compact-handoff.sh` to use anchored format
4. Test proactive compaction flow

### Phase 3: Orchestrator Integration (2 hours)

1. Update `/orchestrator` skill for context-aware delegation
2. Add context checkpointing to Step 6
3. Implement fresh-context validation in Step 7
4. Test full orchestration flow

### Phase 4: Testing & Documentation (1 hour)

1. Integration tests for context management
2. Update CLAUDE.md with v2.47 changes
3. Update CHANGELOG.md
4. User documentation

---

## 6. Expected Results

### 6.1 Metrics

| Metric | v2.46.1 | v2.47 Target |
|--------|---------|--------------|
| Context estimation accuracy | ~50% | **90%+** |
| Unnecessary compaction warnings | High | **Minimal** |
| Context loss on compaction | ~20% | **<5%** |
| Session continuity | 80% | **95%** |
| Tokens-per-task | 100% | **70%** |

### 6.2 User Experience

- No more false 100% context warnings
- Proactive suggestions at 70% (not forced compaction)
- Seamless session continuity after compaction
- Structured summaries preserve critical information
- Fresh context validation improves quality

---

## 7. Questions for User

Before implementing, please confirm:

1. **Counter Reset Strategy**: Reset on every SessionStart, or only on "startup" (not resume)?
2. **Proactive Threshold**: 70% suggested - adjust up/down?
3. **Anchored Summary Sections**: Current proposal includes Intent/Files/Decisions/State/Next - add others?
4. **Fresh Context Validation**: Worth the extra compute for Step 7?
5. **Implementation Priority**: All phases, or specific phase first?

---

## 8. References

- arXiv:2511.18538v5 - Software Engineering Agents Survey
- Claude Code Cowork Mode Prompt (affaanmustafa tweet)
- Factory Research: Evaluating Context Compression for AI Agents (Dec 2025)
- Netflix Engineering: "The Infinite Software Crisis" - Three-phase workflow
- GitHub #15021 - Claude Code extension hook limitations

---

*Document generated by Claude Opus 4.5 - Multi-Agent Ralph Orchestrator v2.46.1*
