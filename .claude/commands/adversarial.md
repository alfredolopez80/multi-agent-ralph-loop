---
# VERSION: 2.43.0
name: adversarial
prefix: "@adv"
category: review
color: red
description: "Adversarial spec refinement via adversarial-spec"
argument-hint: "<spec text|file>"
---

# /adversarial - Adversarial Spec Refinement (v2.81.1)

Iteratively refines a PRD or technical spec using multi-agent adversarial validation with swarm mode.

## Overview

The `/adversarial` command spawns a specialized validation team that challenges specifications from multiple perspectives:
1. **Challenge** assumptions and requirements
2. **Identify** edge cases and gaps
3. **Validate** technical feasibility
4. **Strengthen** specification quality

```
┌─────────────────────────────────────────────────────────────────┐
│               ADVERSARIAL SWARM MODE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌────────────┐   ┌─────────────┐   ┌──────────┐   ┌────────┐ │
│   │ CHALLENGE  │──▶│   IDENTIFY  │──▶│ VALIDATE │──▶│REFINE  │ │
│   │ Assumptions│   │  Gaps       │   │Feasibility│  │ Spec   │ │
│   └────────────┘   └─────────────┘   └──────────┘   └────────┘ │
│         │                │               │              │       │
│         └────────────────┴───────────────┴──────────────┘       │
│                            │                                   │
│                            ▼                                   │
│                   ┌─────────────────┐                         │
│                   │ Spec Refiner    │                         │
│                   │  (adv-lead)     │                         │
│                   └─────────────────┘                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## When to Use

Use `/adversarial` when:
- Refining PRDs or technical specifications
- Validating requirements from multiple perspectives
- Identifying gaps and edge cases early
- Strengthening spec quality before implementation
- Complex specifications need adversarial validation

**DO NOT use** for:
- Simple specs with clear requirements
- Code reviews (use /code-reviewer)
- Security audits only (use /security)

## Runtime Detection

- **Claude Code**: command file under `~/.claude/` → models: `claude-4.5-opus`, `claude-4.5-sonnet`, `openai/gpt-5.2-codex`, `minimax/minimax-m2.1`.
- **OpenCode**: command file under `~/.config/opencode/` → models: `openai/gpt-5.2-codex`, `minimax/minimax-m2.1`.

When invoking the CLI, set `RALPH_COMMAND_PATH` to the full path of this command file so runtime detection is accurate.

---

## Swarm Mode Integration (v2.81.1)

`/adversarial` uses swarm mode by default with specialized validation teammates.

### Auto-Spawn Configuration

```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"
  team_name: "adversarial-council"
  name: "adv-lead"
  mode: "delegate"
  run_in_background: true
  prompt: |
    Execute adversarial spec refinement for: $ARGUMENTS

    Adversarial Pattern:
    1. CHALLENGE - Question assumptions and requirements
    2. DISTRIBUTE - Assign validation angles to specialists
    3. IDENTIFY - Find gaps, edge cases, inconsistencies
    4. VALIDATE - Check technical feasibility
    5. REFINE - Strengthen specification
    6. CONVERGE - Merge all feedback into improved spec
```

### Team Composition

| Role | Purpose | Specialization |
|------|---------|----------------|
| **Coordinator** | Adversarial workflow orchestration | Manages validation lifecycle, synthesizes feedback |
| **Teammate 1** | Assumption Challenger specialist | Questions requirements, identifies implicit assumptions |
| **Teammate 2** | Gap Hunter specialist | Finds missing requirements, edge cases |
| **Teammate 3** | Feasibility Validator specialist | Validates technical feasibility, constraints |

### Swarm Mode Workflow

```
User invokes: /adversarial "Design a rate limiter service"

1. Team "adversarial-council" created
2. Coordinator (adv-lead) receives specification
3. 3 Teammates spawned with validation specializations
4. Validation angles distributed:
   - Teammate 1 → Challenge assumptions (scale, performance)
   - Teammate 2 → Hunt gaps (error handling, monitoring)
   - Teammate 3 → Validate feasibility (algorithms, data structures)
5. Teammates work in parallel (background execution)
6. Coordinator monitors progress and gathers findings
7. All feedback consolidated into challenges
8. Specification refined with all considerations
9. Final improved spec returned
```

### Parallel Validation Pattern

Each teammate focuses on their validation angle:

```yaml
# Teammate 1: Assumption Challenger
- Challenge: "1000 RPS" assumption - why not 10k?
- Challenge: "Redis only" - what if Redis fails?
- Challenge: "Sliding window" - is it accurate enough?
- Challenge: "Per-IP limits" - what about NAT/proxies?

# Teammate 2: Gap Hunter
- Missing: Distributed coordination strategy
- Missing: Backpressure handling
- Missing: Metrics and observability
- Missing: Configuration reload mechanism

# Teammate 3: Feasibility Validator
- Feasible: Token bucket algorithm (O(1))
- Concern: Redis memory usage at scale
- Feasible: Distributed locking (RedLock)
- Concern: Clock synchronization issues
```

### Communication Between Teammates

```yaml
# Teammate sends challenge to coordinator
SendMessage:
  type: "message"
  recipient: "adv-lead"
  content: "Challenge: Rate limiter doesn't address distributed deployment"

# Coordinator requests specific analysis
SendMessage:
  type: "message"
  recipient: "teammate-3"
  content: "Validate feasibility of distributed rate limiting without Redis"
```

### Task List Coordination

```bash
# Location: ~/.claude/tasks/adversarial-council/tasks.json

# Example tasks:
[
  {"id": "1", "subject": "Challenge assumptions", "owner": "teammate-1"},
  {"id": "2", "subject": "Hunt for gaps", "owner": "teammate-2"},
  {"id": "3", "subject": "Validate feasibility", "owner": "teammate-3"},
  {"id": "4", "subject": "Consolidate challenges", "owner": "adv-lead"},
  {"id": "5", "subject": "Refine specification", "owner": "adv-lead"}
]
```

## Execution

### Basic Usage

```bash
# Refine specification with swarm mode (default)
/adversarial "Design a rate limiter service"

# Refine from file
/adversarial docs/spec.md

# Specify output format
/adversarial "PRD for user auth" --output markdown
```

### Manual Override

```bash
# Disable swarm mode
/adversarial "Simple spec" --no-swarm

# Increase teammate count for complex specs
/adversarial "Complex distributed system" --teammates 5
```

### CLI Wrapper

```bash
ralph adversarial "Design a rate limiter service"
ralph adversarial docs/spec.md
```

## Output Format

### Console Output

```
╔══════════════════════════════════════════════════════════════╗
║            Adversarial Spec Refinement (Swarm Mode)          ║
╠══════════════════════════════════════════════════════════════╣
║ Spec: Rate Limiter Service Design                            ║
║ Team: adversarial-council                                     ║
╚══════════════════════════════════════════════════════════════╝

[Phase 1: CHALLENGE]
├─ Teammate 1: Assumptions challenged
│  └─ "1000 RPS" → Why not 10k? What's the constraint?
│  └─ "Redis only" → SPOF concern, need fallback?
├─ Teammate 2: Gaps identified
│  └─ Missing: Distributed deployment strategy
│  └─ Missing: Backpressure mechanism
└─ Teammate 3: Feasibility validated
   └─ Token bucket: O(1) ✓
   └─ RedLock: Viable but complex

[Phase 2: REFINE]
├─ Added: Distributed coordination section
├─ Added: Redis cluster + fallback strategy
├─ Added: Circuit breaker for backpressure
└─ Clarified: Scaling constraints (1k-10k RPS range)

╔══════════════════════════════════════════════════════════════╗
║                    Refinement Summary                       ║
╠══════════════════════════════════════════════════════════════╣
║ Challenges Found: 7                                         ║
║ Gaps Identified: 4                                          ║
║ Feasibility Issues: 2                                       ║
║ Sections Added: 3                                           ║
║ Duration: 4m 22s                                            ║
╚══════════════════════════════════════════════════════════════╝
```

## Output Location

```bash
# Refinement reports saved to ~/.ralph/adversarial/
ls ~/.ralph/adversarial/

# View last refinement
cat ~/.ralph/adversarial/latest.md

# Logs saved to ~/.ralph/logs/adversarial-*.log
tail -f ~/.ralph/logs/adversarial-latest.log
```

## Related Commands

### Orchestration Commands
- `/orchestrator` - Full workflow (includes adversarial validation)
- `/loop` - Iterative execution until VERIFIED_DONE
- `/gates` - Quality gate validation

### Analysis Commands
- `/security` - Security-focused audit
- `/codex` - Codex CLI for complex analysis
- `/bug` - Systematic debugging

## Examples

### Example 1: Simple Service

```bash
/adversarial "Design a rate limiter service"
```

**Output**:
- 7 challenges found
- 4 gaps identified
- 3 sections added
- Spec strengthened in 4m 22s

### Example 2: Complex System

```bash
/adversarial "Design a distributed transaction system" --teammates 5
```

**Output**:
- Multiple teammates analyze different aspects:
  - CAP theorem implications
  - Consensus algorithms
  - Failure scenarios
  - Performance characteristics
- Comprehensive refinement in 8m 15s

### Example 3: File-Based Spec

```bash
/adversarial docs/prd-user-auth.md
```

**Output**:
- Existing spec challenged
- Missing flows identified (password reset, 2FA)
- Security gaps found (session hijacking)
- Refined spec with all considerations

## Best Practices

1. **Be specific**: More context = better challenges
2. **Accept challenges**: Adversarial feedback improves quality
3. **Iterate**: Run multiple rounds for complex specs
4. **Document**: Track challenges and decisions
5. **Collaborate**: Use swarm mode for diverse perspectives

---

**Version**: 2.81.1 | **Status**: SWARM MODE ENABLED | **Team Size**: 4 agents
