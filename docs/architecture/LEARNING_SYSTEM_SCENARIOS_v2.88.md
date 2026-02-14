# Learning System Skills - Scenario Analysis v2.88.0

**Date**: 2026-02-14
**Version**: 2.88.0
**Status**: ANALYSIS COMPLETE

## Overview

Analysis of the three multi-agent execution scenarios (A, B, C) applied to learning system skills.

## Learning System Skills Inventory

| Skill | Type | Description |
|-------|------|-------------|
| `/curator` | Pipeline | Full discovery → ingest → learn pipeline |
| `/curator-repo-learn` | Learning | Extract patterns from specific repository |
| `/repo-learn` | Learning | Alias for curator-repo-learn |
| Hooks: `orchestrator-auto-learn.sh` | Hook | Detects learning gaps |
| Hooks: `continuous-learning.sh` | Hook | Session-end extraction |
| Hooks: `curator-suggestion.sh` | Hook | User prompt suggestions |

## Scenario Analysis per Skill

### `/curator` - Full Pipeline

**Analysis**:
- **Coordination Need**: HIGH (5+ sequential steps)
- **Specialization Need**: MEDIUM (uses GitHub API, scoring, etc.)
- **Quality Gate Need**: HIGH (must verify each stage)
- **Tool Restriction Need**: LOW (needs web, git, file tools)
- **Scalability**: HIGH (complex multi-repo operations)

**Evaluation Matrix**:

| Criterion | Weight | Score | Rationale |
|-----------|--------|-------|-----------|
| Coordination Need | 25% | 8/10 | Multi-stage pipeline requires orchestration |
| Specialization Need | 25% | 5/10 | General API/git skills sufficient |
| Quality Gate Need | 20% | 9/10 | Each stage needs validation |
| Tool Restriction Need | 15% | 3/10 | Needs broad tool access |
| Scalability | 15% | 8/10 | Can process many repos |
| **Total** | 100% | **6.9/10** | **Scenario C (Integrated)** |

**Recommended Scenario**: **C (Integrated)**

```yaml
# Optimal Workflow for /curator
TeamCreate(team_name="curator-pipeline")
Task(subagent_type="ralph-researcher", prompt="Search GitHub for ${DOMAIN} repos")
Task(subagent_type="ralph-coder", prompt="Clone and analyze ${REPO}")
Task(subagent_type="ralph-reviewer", prompt="Verify pattern quality")
# Quality gate hooks validate each stage
```

---

### `/curator-repo-learn` - Single Repository Learning

**Analysis**:
- **Coordination Need**: LOW (single operation)
- **Specialization Need**: HIGH (pattern extraction expertise)
- **Quality Gate Need**: MEDIUM (pattern verification)
- **Tool Restriction Need**: LOW (needs git, file tools)
- **Scalability**: LOW (one repo at a time)

**Evaluation Matrix**:

| Criterion | Weight | Score | Rationale |
|-----------|--------|-------|-----------|
| Coordination Need | 25% | 2/10 | Independent operation |
| Specialization Need | 25% | 9/10 | Requires pattern recognition |
| Quality Gate Need | 20% | 6/10 | Moderate validation needed |
| Tool Restriction Need | 15% | 3/10 | Standard tools sufficient |
| Scalability | 15% | 2/10 | Single repo focus |
| **Total** | 100% | **5.2/10** | **Scenario B (Custom Subagents)** |

**Recommended Scenario**: **B (Custom Subagents)**

```yaml
# Optimal Workflow for /curator-repo-learn
Task(subagent_type="ralph-researcher", prompt="Analyze ${REPO_URL} and extract patterns")
# Direct spawn, no team overhead
# ralph-researcher handles git clone, analysis, pattern extraction
```

---

### Hooks: `orchestrator-auto-learn.sh`

**Analysis**:
- **Coordination Need**: MEDIUM (triggers other actions)
- **Specialization Need**: MEDIUM (complexity analysis)
- **Quality Gate Need**: HIGH (blocking decisions)
- **Tool Restriction Need**: HIGH (read-only analysis)
- **Scalability**: MEDIUM (per-task analysis)

**Evaluation Matrix**:

| Criterion | Weight | Score | Rationale |
|-----------|--------|-------|-----------|
| Coordination Need | 25% | 5/10 | Triggers learning pipeline |
| Specialization Need | 25% | 6/10 | Requires domain analysis |
| Quality Gate Need | 20% | 9/10 | Critical blocking decisions |
| Tool Restriction Need | 15% | 8/10 | Read-only, limited tools |
| Scalability | 15% | 5/10 | Per-task overhead |
| **Total** | 100% | **6.4/10** | **Scenario A (Pure Agent Teams)** |

**Recommended Scenario**: **A (Pure Agent Teams)** (as hook, runs in main context)

```yaml
# Hook runs in main session context
# No subagent spawn needed - it's a PreToolUse hook
# It injects recommendations into the prompt
# If auto-learn enabled, it triggers /curator pipeline
```

---

### Hooks: `continuous-learning.sh`

**Analysis**:
- **Coordination Need**: LOW (independent extraction)
- **Specialization Need**: MEDIUM (pattern detection)
- **Quality Gate Need**: LOW (advisory only)
- **Tool Restriction Need**: LOW (file operations)
- **Scalability**: MEDIUM (session-end processing)

**Recommended Scenario**: **A (Native Hook)**

```yaml
# SessionEnd hook - runs in main context
# Analyzes session transcript
# Creates pattern files for review
# No agent coordination needed
```

---

### Hooks: `curator-suggestion.sh`

**Analysis**:
- **Coordination Need**: LOW (simple suggestion)
- **Specialization Need**: LOW (keyword matching)
- **Quality Gate Need**: LOW (advisory only)
- **Tool Restriction Need**: LOW (read-only)
- **Scalability**: HIGH (lightweight check)

**Recommended Scenario**: **A (Native Hook)**

```yaml
# UserPromptSubmit hook - runs in main context
# Simple keyword analysis
# Injects suggestion into prompt
# No agent coordination needed
```

## Summary Table

| Skill/Hook | Scenario | Score | Key Rationale |
|------------|----------|-------|---------------|
| `/curator` | **C** | 6.9/10 | Multi-stage pipeline needs coordination |
| `/curator-repo-learn` | **B** | 5.2/10 | Independent pattern extraction |
| `orchestrator-auto-learn.sh` | **A** | 6.4/10 | Hook in main context |
| `continuous-learning.sh` | **A** | N/A | SessionEnd hook |
| `curator-suggestion.sh` | **A** | N/A | UserPromptSubmit hook |

## Implementation Recommendations

### `/curator` - Scenario C Implementation

```yaml
# .claude/skills/curator/SKILL.md
agent_teams_integration:
  optimal_scenario: C
  workflow:
    - TeamCreate(team_name="curator-pipeline")
    - Spawn ralph-researcher for GitHub search
    - Spawn ralph-coder for repo cloning
    - Spawn ralph-reviewer for pattern validation
    - Quality gates at each stage
```

### `/curator-repo-learn` - Scenario B Implementation

```yaml
# .claude/skills/curator-repo-learn/SKILL.md
agent_teams_integration:
  optimal_scenario: B
  workflow:
    - Task(subagent_type="ralph-researcher")
    - Direct spawn for efficiency
    - Single agent handles full extraction
```

## Files to Update

1. `.claude/skills/curator/SKILL.md` - Add Scenario C integration
2. `.claude/skills/curator-repo-learn/SKILL.md` - Add Scenario B integration
3. `docs/architecture/MULTI_AGENT_SCENARIOS_v2.88.md` - Add learning skills to table

## References

- [Multi-Agent Scenarios v2.88](./MULTI_AGENT_SCENARIOS_v2.88.md)
- [Learning System Audit](../audits/LEARNING_SYSTEM_AUDIT_v2.88.md)
- [Unified Architecture v2.88](./UNIFIED_ARCHITECTURE_v2.88.md)
