# Retrospective: Sankalp's Claude Code 2.0 Insights

**Source**: [My Experience with Claude Code 2.0 and How to Get Better at Using Coding Agents](https://sankalp.bearblog.dev/my-experience-with-claude-code-20-and-how-to-get-better-at-using-coding-agents/)

**Date**: 2026-01-13

**Status**: Pending Review

---

## Executive Summary

This document analyzes Sankalp's comprehensive blog post about Claude Code 2.0 usage patterns, extracting actionable improvements for the Multi-Agent Ralph Loop system. The author provides valuable insights from extensive real-world usage, focusing on context engineering, model selection, and workflow optimization.

**Key Insight**: Success with coding agents depends less on raw model capability and more on **context engineering** - strategically configuring what information the model sees, when it sees it, and how that information is structured.

---

## 1. Context Management Improvements

### Current State (Multi-Agent Ralph)
- Context preservation via PreCompact/SessionStart hooks
- Warning thresholds at 80%/85%
- Automatic ledger/handoff creation

### Proposed Improvements

| Improvement | Description | Priority |
|-------------|-------------|----------|
| **Earlier Compaction Threshold** | Compact at 60% instead of 80% for optimal performance | HIGH |
| **Context Quality Monitoring** | Track "context rot" - performance degradation with length | MEDIUM |
| **Effective Context Windows** | Document that models operate at 50-60% of stated maximum | HIGH |

### Implementation Notes

```yaml
# Proposed: Update claude-hud thresholds
context_warnings:
  yellow: 60%   # Was 80%
  red: 75%      # Was 85%
  compact: 60%  # Optimal performance window
```

**Rationale**: Blog confirms "performance drops with length...not task difficulty" - earlier compaction preserves quality.

---

## 2. CLAUDE.md Optimization

### Current State
- Global CLAUDE.md: ~200 lines
- Project CLAUDE.md: ~300 lines
- Skills loaded on-demand

### Proposed Improvements

| Improvement | Description | Priority |
|-------------|-------------|----------|
| **500-Line Limit** | Anthropic-recommended maximum for CLAUDE.md | HIGH |
| **Skill Segmentation** | Move complex instructions to `.claude/skills/` | MEDIUM |
| **Progressive Disclosure** | Only load detailed instructions when relevant | HIGH |

### Implementation

```bash
# Audit current CLAUDE.md sizes
wc -l ~/.claude/CLAUDE.md
wc -l $PROJECT/CLAUDE.md

# If exceeding 500 lines, segment into skills
```

**Rationale**: Bloated CLAUDE.md consumes precious context window before task even begins.

---

## 3. Model Selection Strategy

### Current State (Multi-Agent Ralph)
- Opus for security/critical
- Sonnet for implementation
- MiniMax for validation (8% cost)

### Proposed Improvements

| Improvement | Description | Priority |
|-------------|-------------|----------|
| **GPT-5.2-Codex for Review** | Superior at bug detection per blog | HIGH |
| **Haiku for Straightforward Tasks** | Minimize cost/latency for trivial work | MEDIUM |
| **Multi-Model Validation** | Claude execution + Codex review pattern | HIGH |

### Proposed Routing Matrix

```yaml
task_routing:
  execution:
    primary: "claude-opus-4-5"
    fallback: "claude-sonnet-4-5"
  review:
    primary: "gpt-5.2-codex"      # NEW: Superior bug detection
    secondary: "minimax-m2.1"
  trivial:
    model: "claude-haiku-4-5"     # Cost optimization
```

**Rationale**: Blog author found Codex "superior at finding issues" - use strengths of each model.

---

## 4. Workflow Optimizations

### 4.1 Throw-Away First Draft Pattern

**New Pattern**: Let Claude write end-to-end first, then iterate with sharper prompts informed by first attempt.

```yaml
workflow:
  draft_phase:
    goal: "Explore solution space"
    model: "sonnet"  # Fast iteration
    output: "inform_prompts"

  refinement_phase:
    goal: "Precision implementation"
    model: "opus"    # Quality focus
    input: "learnings_from_draft"
```

### 4.2 Todo List Recitation

**New Pattern**: Maintain objectives in markdown to prevent goal drift.

```yaml
# Add to /orchestrator skill
recitation:
  frequency: "every_5_tool_calls"
  format: |
    Current objectives:
    - [ ] Primary goal: $GOAL
    - [ ] Current step: $STEP
    - [ ] Remaining: $REMAINING
```

### 4.3 Independent Exploration

**Anti-Pattern Identified**: Relying solely on Plan Mode for exploration.

**Recommended**: User explores codebase first, then provides context to agent.

---

## 5. Sub-Agent Patterns

### Current State
- Task() with model: "sonnet"
- run_in_background: true

### Proposed Improvements

| Improvement | Description | Priority |
|-------------|-------------|----------|
| **Explore Sub-Agents** | Read-only Sonnet agents for codebase search | HIGH |
| **Context Inheritance** | General-purpose agents inherit full context | MEDIUM |
| **Verification Sub-Agents** | Dedicated validation tasks | HIGH |

### Implementation

```yaml
# New: Explore sub-agent type
Task:
  subagent_type: "explorer"
  model: "sonnet"  # Speed priority
  capabilities: ["read_only", "search", "analyze"]
  inherit_context: false  # Fresh context

# Existing: Verification pattern
Task:
  subagent_type: "verifier"
  model: "codex"  # Bug detection
  run_in_background: true
  inherit_context: true
```

---

## 6. Tool Description Best Practices

### Key Insight: Negative Guidance

Blog emphasizes importance of **"When NOT to use"** in tool descriptions.

### Proposed Enhancement

```yaml
# Add to all skill frontmatter
---
name: skill-name
description: |
  Use when: [positive triggers]
  Do NOT use when: [negative triggers]  # NEW
allowed-tools: [tools]
---
```

### Example Application

```yaml
---
name: orchestrator
description: |
  Use when: Complex multi-step tasks, feature implementation, critical changes
  Do NOT use when: Single-line fixes, typo corrections, simple questions
---
```

**Rationale**: Clear negative guidance reduces hallucination and improves tool selection accuracy.

---

## 7. Checkpointing Strategy

### Current State
- `/rewind` available but underutilized
- Linear conversation flow

### Proposed Improvements

| Improvement | Description | Priority |
|-------------|-------------|----------|
| **Branch Exploration** | Document `Esc+Esc` checkpointing | MEDIUM |
| **Decision Points** | Create checkpoints before major decisions | HIGH |
| **Rollback Documentation** | Add rollback instructions to handoffs | MEDIUM |

### Implementation

```bash
# Add to handoff creation
ralph handoff create --with-checkpoint

# Handoff includes:
# - Last known good state
# - Rollback instructions
# - Decision tree summary
```

---

## 8. MCP Server Optimization

### Problem Identified

Blog confirms: "MCP servers bloat context by loading tool definitions upfront"

### Proposed Solution

```yaml
# Lazy MCP loading
mcp_strategy:
  load_on_demand: true
  preload_only:
    - "context7"      # Frequent use
    - "playwright"    # Testing
  lazy_load:
    - "blender"       # Specialized
    - "nanobanana"    # Image gen
```

### Implementation

```json
// In opencode.json or settings.json
{
  "mcp": {
    "lazy_loading": true,
    "preload": ["context7", "playwright"]
  }
}
```

---

## 9. Quantitative Metrics to Track

### Blog Benchmarks

| Metric | Value | Notes |
|--------|-------|-------|
| Average tool calls/task | ~50 | Monitor for baseline |
| Effective context | 50-60% of max | Performance threshold |
| Token budget/task | ~6K+ | For complex operations |

### Proposed Tracking

```yaml
# Add to Stop hook metrics
metrics:
  - tool_calls_count
  - context_utilization_percent
  - tokens_used
  - compaction_count
  - subagent_spawns
```

---

## 10. Custom Command Recommendations

### From Blog: Bootstrap Pattern

Author created `/bootstrap-repo` using 10 parallel sub-agents for comprehensive documentation.

### Proposed Commands

| Command | Purpose | Priority |
|---------|---------|----------|
| `/bootstrap` | Initialize new projects with docs | HIGH |
| `/review-codex` | GPT-5.2-Codex code review | HIGH |
| `/explore-fresh` | Fresh-context exploration | MEDIUM |

### Implementation Example

```yaml
---
name: review-codex
description: Submit code for GPT-5.2-Codex review (superior bug detection)
---
# Submit to Codex for severity-rated bug detection
# Leverages Codex's superior issue-finding capabilities
```

---

## Summary of Proposed Changes

### High Priority (Implement Soon)

1. **Lower context warning thresholds** (60%/75% instead of 80%/85%)
2. **Add GPT-5.2-Codex review** to validation pipeline
3. **Document 500-line CLAUDE.md limit** in best practices
4. **Add negative guidance** ("When NOT to use") to all skills
5. **Implement explore sub-agents** for read-only codebase search

### Medium Priority (Plan for v2.43)

1. **Todo list recitation** mechanism
2. **Throw-away first draft** workflow option
3. **Lazy MCP loading** configuration
4. **Checkpointing documentation** improvements
5. **Metric tracking** in Stop hook

### Low Priority (Evaluate Later)

1. Bootstrap command for new projects
2. Branch exploration UI improvements
3. Context inheritance configuration options

---

## Decision Required

**Question for User**: Which improvements should be prioritized for v2.42/v2.43?

Options:
- [ ] Implement all High Priority items
- [ ] Focus on context management only
- [ ] Focus on model selection strategy only
- [ ] Cherry-pick specific items
- [ ] Defer all to future version

---

## References

- **Source Blog**: https://sankalp.bearblog.dev/my-experience-with-claude-code-20-and-how-to-get-better-at-using-coding-agents/
- **Claude Code Official Prompt**: https://x.com/claudecoders/status/2010895731549487409
- **Anthropic Documentation**: https://docs.claude.com

---

*Generated by Multi-Agent Ralph v2.41 Orchestrator*
*Prepared for /retrospective review*
