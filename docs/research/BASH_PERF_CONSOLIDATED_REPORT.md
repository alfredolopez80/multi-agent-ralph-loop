# Bash/Edit Performance Investigation — Consolidated Report

**Date**: 2026-04-09
**Branch**: feat/bash-edit-perf-investigation
**Team**: bash-perf-research (4 agents)
**Status**: Analysis complete, no changes applied

---

## Executive Summary

Claude Code Bash and Edit operations are slow because **67 hooks execute on every operation**, with **21 PostToolUse hooks** firing after each Edit/Write/Bash call. The permission model is already optimized — the bottleneck is **hook cascade overhead** at 2-5 seconds per operation.

### Root Cause

```
User Request → LLM generates command (~2s LLM time)
            → Permission check (~instant, already optimized)
            → 3 PreToolUse hooks (~200-500ms)
            → Bash/Edit executes (~instant)
            → 21 PostToolUse hooks (~2-5s)  ← BOTTLENECK
            → Result returns to LLM (~2s LLM time)
            ──────────────────────────────────
            TOTAL: ~6-10s per operation (user perception)
```

The user-perceived slowness is the combination of:
1. LLM inference time (~4s total, before + after)
2. Hook execution overhead (~2-5s)
3. Hook cascading (sequential, not parallel)

---

## Detailed Findings

### 1. Hook Inventory (67 Total)

| Event | Hook Count | Frequency | Impact |
|-------|-----------|-----------|--------|
| **PostToolUse** | **21** | Every Edit/Write/Bash | CRITICAL |
| **PreToolUse** | **10** | Every tool call | HIGH |
| **SessionStart** | **11** | Once per session | MEDIUM |
| **UserPromptSubmit** | **7** | Every user message | MEDIUM |
| **Stop** | **6** | Session end | LOW |
| **SessionEnd** | **4** | Session end | LOW |
| **TeammateIdle** | **2** | Agent idle | MEDIUM |
| **PreCompact** | **1** | Before compaction | LOW |
| **TaskCreated** | **1** | Task creation | LOW |
| **TaskCompleted** | **1** | Task completion | LOW |
| **SubagentStart** | **1** | Subagent spawn | LOW |
| **SubagentStop** | **2** | Subagent stop | LOW |

### 2. Top 5 Bottleneck Hooks

| # | Hook | Event | Timeout | Est. Latency | Issue |
|---|------|-------|---------|-------------|-------|
| 1 | `quality-parallel-async.sh` | PostToolUse | **60s** | 100-1000ms | Spawns 4 duplicate checks; duplicates sec-context + quality-gates work |
| 2 | `quality-gates-v2.sh` | PostToolUse | N/A | 100-500ms | Runs tsc on every TS Edit; sequential security scans |
| 3 | `security-full-audit.sh` | PostToolUse | N/A | 100-300ms | Duplicate of sec-context-validate.sh |
| 4 | `audit-secrets.js` | PostToolUse | **30s** | 50-100ms | Runs on ALL tools (should be Edit/Write only) |
| 5 | `sec-context-validate.sh` | PostToolUse | N/A | 50-100ms | ~50% overlap with other security hooks |

**Combined overhead**: ~400-2000ms per operation (hooks alone)

### 3. Redundancy Analysis

#### Duplicate Security Hooks (4 → should be 2)

| Hook | Patterns Checked | Overlap |
|------|-----------------|---------|
| `audit-secrets.js` | 20+ secret patterns | Base |
| `sec-context-validate.sh` | 10+ patterns | ~60% overlap with audit-secrets |
| `security-full-audit.sh` | 15+ patterns | ~80% overlap with sec-context |
| `security-real-audit.sh` | 12+ patterns | ~70% overlap |

**Recommendation**: Keep `audit-secrets.js` + `sec-context-validate.sh`, remove other 2.

#### Duplicate Plan-State Hooks (7 → should be 1)

| Hook | Purpose |
|------|---------|
| `auto-plan-state.sh` | Auto-sync plan state |
| `plan-state-adaptive.sh` | Adaptive plan state |
| `plan-state-lifecycle.sh` | Lifecycle management |
| `plan-sync-post-step.sh` | Post-step sync |
| `todo-plan-sync.sh` | Todo→Plan sync |
| `task-plan-sync.sh` | Task→Plan sync |
| `auto-migrate-plan-state.sh` | Migration |

**Recommendation**: Consolidate into single `plan-state-manager.sh`.

#### Duplicate TypeScript Checking (2 → should be 1)

| Hook | What it does |
|------|-------------|
| `typescript-quick-check.sh` | Quick tsc check |
| `quality-gates-v2.sh` | Includes tsc check |

**Recommendation**: Remove `typescript-quick-check.sh`, keep in quality-gates.

### 4. Plugin Overhead

38 plugins are enabled, many unused:

| Plugin | Status | Startup Impact |
|--------|--------|---------------|
| atlassian | Auth required (unused) | ~200ms |
| supabase | Auth required (unused) | ~200ms |
| firebase | Auth required (unused) | ~150ms |
| stripe | Auth required (unused) | ~150ms |
| sentry | Auth required (unused) | ~150ms |
| Notion | Auth required (unused) | ~150ms |

**Recommendation**: Disable unused auth-required plugins → save ~1s startup.

### 5. Permission Model Analysis

The permission model is **already optimized**:
- `skipDangerousModePermissionPrompt: true` is set
- `permissions.allow` includes common patterns (git, ralph, etc.)

**Additional optimization available** (low impact since permissions aren't the bottleneck):
```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)", "Bash(ralph:*)",
      "Bash(ls:*)", "Bash(cat:*)", "Bash(grep:*)",
      "Bash(head:*)", "Bash(tail:*)", "Bash(wc:*)",
      "Bash(mkdir:*)", "Bash(mv:*)", "Bash(cp:*)"
    ]
  }
}
```

Estimated savings: ~0.5-1s per approved command (not significant vs hook overhead).

---

## Options Analysis

### Option A: Quick Wins (~30 min, -2-4s/operation)

| Action | Savings | Risk |
|--------|---------|------|
| Disable `quality-parallel-async.sh` | ~1s | Low (redundant) |
| Disable `security-full-audit.sh` | ~0.3s | Low (duplicate) |
| Disable `security-real-audit.sh` | ~0.3s | Low (duplicate) |
| Limit `audit-secrets.js` to Edit/Write | ~0.1s | Low |
| Expand `permissions.allow` | ~0.5-1s | Low |

**Net effect**: 67 → ~62 hooks, ~2-4s saved per operation

### Option B: Aggressive Consolidation (~2 hours, -4-8s/operation)

| Action | Savings | Risk |
|--------|---------|------|
| All Quick Wins | ~2-4s | Low |
| Consolidate security hooks (4→2) | ~0.3s | Low |
| Consolidate plan-state hooks (7→1) | ~0.2s | Low |
| Consolidate SessionStart hooks (11→3) | ~0.5s startup | Medium |
| Make quality-gates async | ~1s | Medium |
| Disable unused plugins | ~1s startup | Low |
| Add timeouts to all hooks | Prevents hangs | Low |

**Net effect**: 67 → ~25 hooks, ~4-8s saved per operation

### Option C: Full Restructure (~1 day, -6-9s/operation)

| Action | Savings | Risk |
|--------|---------|------|
| All Aggressive items | ~4-8s | Medium |
| Hook priority system | ~1s | High |
| Hook result caching | ~1-2s | High |
| Hook performance monitoring | Observability | Medium |
| Smart batching for Edit operations | ~2s | High |
| Async-first architecture for all hooks | ~1-3s | High |

**Net effect**: 67 → ~15 hooks, overhead reduced to <500ms

### Option D: Alternative Execution Strategies

| Strategy | Speed Gain | Tradeoff | Verdict |
|----------|-----------|----------|---------|
| **Bash batching** (`&&` chains) | **3x faster** (39 hooks vs 117 for 3 calls) | Harder to debug | VIABLE |
| `bypassPermissions` mode | 10x faster | **THREAT-004** Privilege Escalation | NEVER |
| **MCP filesystem tools** | Similar speed | Read-only, not execution replacement | LIMITED |
| **ast-grep MCP** vs grep | 30x SLOWER (~2-3s vs ~0.08s) | Structural precision | ONLY for complex queries |
| **async:true on hooks** | 50-80% reduction | Need idempotent hooks | VIABLE |
| ~~ctx_execute~~ | Does NOT exist | N/A | INVALID |

### Critical Finding from alt-strategies Agent

**Batch commands with `&&`** is the most practical immediate win:
```bash
# SLOW: 3 separate calls = 117 hooks
Bash("ls -la")
Bash("cat file.txt")
Bash("grep pattern file.txt")

# FAST: 1 batched call = 39 hooks
Bash("ls -la && cat file.txt && grep pattern file.txt")
```

**async:true** on idempotent PostToolUse hooks could reduce overhead 50-80%:
- `audit-secrets.js` (30s timeout)
- `universal-step-tracker.sh`
- `decision-extractor.sh`
- `semantic-realtime-extractor.sh`
- `console-log-detector.sh`
- `ai-code-audit.sh`

---

## Recommendation Matrix

| Priority | Action | Impact | Effort | Risk |
|----------|--------|--------|--------|------|
| **P0** | Disable `quality-parallel-async.sh` | HIGH (1s) | 1 min | Low |
| **P0** | Remove duplicate security hooks (2 of 4) | HIGH (0.6s) | 5 min | Low |
| **P0** | Add timeouts to all hooks | Prevents hangs | 10 min | Low |
| **P1** | Consolidate plan-state (7→1) | MEDIUM (0.2s) | 30 min | Low |
| **P1** | Make quality-gates async | MEDIUM (1s) | 15 min | Medium |
| **P1** | Disable unused plugins | MEDIUM (1s startup) | 5 min | Low |
| **P2** | Expand permissions.allow | LOW (0.5s) | 5 min | Low |
| **P2** | SessionStart consolidation | LOW (0.5s startup) | 30 min | Medium |
| **P3** | Hook caching system | HIGH (1-2s) | 4 hours | High |
| **P3** | Hook priority system | MEDIUM (1s) | 4 hours | High |

---

## Appendix: Agent Reports

- `docs/research/bash-perf-hooks-analysis.md` — Hook-level profiling (hook-analyzer)
- `docs/research/bash-perf-permission-model.md` — Permission model deep dive (permission-researcher)
- `docs/research/bash-perf-settings-audit.md` — Settings.json audit (settings-auditor)
- `docs/research/bash-perf-alternatives.md` — Alternative strategies (alt-strategies, pending)

---

*Report generated by bash-perf-research team on 2026-04-09*
*No changes were applied to the system.*
