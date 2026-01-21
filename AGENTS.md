# Multi-Agent Ralph Wiggum - Agents Reference v2.58.0

## Overview

Ralph orchestrates **33 specialized agents** across different domains. Each agent has specific expertise and is routed based on task complexity and requirements.

## Core Orchestration Agents (v2.50)

| Agent | Model | Purpose |
|-------|-------|---------|
| `@orchestrator` | opus | Main coordinator - 12-step workflow |
| `@lead-software-architect` | opus | Architecture guardian - LSA verification |
| `@plan-sync` | sonnet | Drift detection & downstream patching |
| `@gap-analyst` | opus | Pre-implementation gap analysis |
| `@quality-auditor` | opus | 6-phase pragmatic code audit |
| `@adversarial-plan-validator` | opus | Dual-model plan validation (Claude + Codex) |
| `@repository-learner` | sonnet | Learn best practices from GitHub repositories |
| `@repo-curator` | sonnet | Curate quality repositories for learning |

## Review & Security Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `@security-auditor` | sonnet→codex | Security vulnerabilities & OWASP compliance |
| `@code-reviewer` | sonnet→codex | Code quality, patterns, best practices |
| `@blockchain-security-auditor` | opus | Smart contract & DeFi security |
| `@ai-output-code-review-super-auditor` | opus | AI-generated code verification |

## Implementation Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `@test-architect` | sonnet | Test generation & coverage |
| `@debugger` | opus | Bug detection & root cause analysis |
| `@refactorer` | sonnet→codex | Code refactoring & modernization |
| `@docs-writer` | sonnet→gemini | Documentation generation |

## Language-Specific Reviewers

| Agent | Model | Purpose |
|-------|-------|---------|
| `@kieran-python-reviewer` | sonnet | Python type hints, patterns, testability |
| `@kieran-typescript-reviewer` | sonnet | TypeScript type safety, modern patterns |
| `@frontend-reviewer` | opus | React/Next.js, UI/UX, accessibility |

## Auxiliary Review Agents (v2.35)

| Agent | Trigger | Purpose |
|-------|---------|---------|
| `@code-simplicity-reviewer` | LOC > 100 | YAGNI enforcement, complexity reduction |
| `@architecture-strategist` | ≥3 modules OR complexity ≥7 | SOLID compliance, architectural review |
| `@pattern-recognition-specialist` | Refactoring tasks | Design patterns, anti-patterns |

## Cost-Effective Agents

| Agent | Model | Cost | Purpose |
|-------|-------|------|---------|
| `@minimax-reviewer` | MiniMax M2.1 | 8% | Second opinion, extended loops |
| `@blender-3d-creator` | opus | Variable | 3D asset creation via Blender MCP |

## Blockchain & DeFi Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `@Hyperliquid-DeFi-Protocol-Specialist` | opus | Hyperliquid protocol integration |
| `@liquid-staking-specialist` | opus | Liquid staking protocols |
| `@defi-protocol-economist` | opus | Token economics & DeFi modeling |
| `@chain-infra-specialist-blockchain` | opus | Chain infrastructure & RPC |

## Memory & Learning Agents (v2.50) - NEW

| Agent | Model | Purpose |
|-------|-------|---------|
| `@repository-learner` | sonnet | Learn best practices from GitHub repositories |

## Memory System Architecture (v2.57.5) - NEW

### Overview

Ralph uses a **3-tier memory architecture** for intelligent context management:

| Tier | Type | Storage | TTL | Purpose |
|------|------|---------|-----|---------|
| **Semantic** | Persistent | `~/.ralph/memory/semantic.json` | Never | Facts, preferences, learned rules |
| **Episodic** | Session | `~/.ralph/episodes/` | 30 days | Experiences, decisions, patterns |
| **Procedural** | Learned | `~/.ralph/procedural/rules.json` | Never | Behaviors, patterns, best practices |

### Memory Components

| Component | Path | Purpose |
|-----------|------|---------|
| **claude-mem MCP** | External | Semantic search & observation storage |
| **Memvid** | `~/.ralph/memory.mv2` | Vector-based semantic search (optional) |
| **Ledgers** | `~/.ralph/ledgers/` | Session continuity & progress tracking |
| **Handoffs** | `~/.ralph/handoffs/` | Agent-to-agent context transfer |
| **Agent Memory** | `~/.ralph/agent-memory/<agent>/` | Per-agent isolated memory buffers |

### Memory Hooks (v2.57)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `smart-memory-search.sh` | PreToolUse (Task) | Parallel memory search before orchestration |
| `memory-write-trigger.sh` | UserPromptSubmit | Detect "remember" phrases, inject context |
| `decision-extractor.sh` | PostToolUse (Edit/Write) | Extract architectural decisions |
| `semantic-realtime-extractor.sh` | PostToolUse (Edit/Write) | Extract semantic facts from changes |
| `procedural-inject.sh` | PreToolUse (Task) | Inject learned procedural rules |
| `agent-memory-auto-init.sh` | PreToolUse (Task) | Auto-initialize agent memory buffers |

### Usage Commands

```bash
# Memory search (parallel - v2.49)
mcp__plugin_claude-mem_mcp-search__search({query: "session goal", limit: 10})

# Agent-scoped memory (v2.51)
ralph agent-memory init security-auditor
ralph agent-memory write security-auditor semantic "Found SQL injection"
ralph agent-memory read security-auditor

# Ledger/Handoff (v2.43)
ralph ledger save    # Save session state
ralph handoff create # Create context transfer

# Memory health (v2.55)
ralph health         # Full memory system check
```

### Memory Integration Points

- **SessionStart**: Auto-loads ledger + handoff context
- **PreCompact**: Auto-saves ledger before context compaction
- **Orchestration**: `smart-memory-search.sh` runs in parallel with task analysis
- **Learning**: `repository-learner` extracts patterns → procedural memory
- **Validation**: Learned rules inform quality gates

---

### @repository-learner (v2.50)

**Purpose**: Extract design patterns and best practices from GitHub repositories to enrich procedural memory.

**Workflow**:
1. **ACQUIRE** → Clone repository or fetch via GitHub API
2. **ANALYZE** → AST-based pattern extraction (Python, TypeScript, Rust, Go)
3. **CLASSIFY** → Categorize patterns by type:
   - `error_handling` - Exception patterns, Result types
   - `async_patterns` - Async/await, Promise patterns
   - `type_safety` - Type guards, generics
   - `architecture` - Design patterns, DI
   - `testing` - Test patterns, fixtures
   - `security` - Auth, validation patterns
4. **GENERATE** → Procedural rules with confidence scores (0.8 threshold)
5. **ENRICH** → Atomic write to `~/.ralph/procedural/rules.json`

**Usage**:
```bash
/repo-learn https://github.com/python/cpython
/repo-learn https://github.com/tiangolo/fastapi --category error_handling
/repo-learn https://github.com/facebook/react --category security --min-confidence 0.9
```

**Output**:
- Procedural rules added to `~/.ralph/procedural/rules.json`
- Rules injected into future Task calls via `procedural-inject.sh`
- Claude considers learned patterns when implementing similar code

**Security**:
- Read-only repository analysis
- Symlink traversal protection
- Atomic writes with backup
- Schema validation before insertion

### @repo-curator (v2.50) - NEW

**Purpose**: Discover, score, and curate high-quality repositories for Ralph's learning system.

**Workflow**:
1. **DISCOVERY** → GitHub API search for candidate repositories (100-500 results)
2. **SCORING** → QualityScore calculation:
   - Stars (normalized)
   - Issues ratio (maintenance activity)
   - Tests presence (test directory, coverage)
   - CI/CD pipelines (GitHub Actions, CircleCI)
   - Documentation (README, docs/)
3. **RANKING** → Sort by QualityScore, max 2 repos per organization
4. **USER REVIEW** → Interactive queue for approve/reject decisions
5. **LEARN** → Trigger `@repository-learner` on approved repos

**Pricing Tiers**:
| Tier | Cost | Features |
|------|------|----------|
| `--tier free` | $0.00 | GitHub API + local scoring heuristics |
| `--tier economic` | ~$0.30 | + OpenSSF Scorecard + MiniMax validation |
| `--tier full` | ~$0.95 | + Claude + Codex adversarial (with fallback) |

**Usage**:
```bash
# Invoke via command
/curator full --type backend --lang typescript

# Via agent
@repo-curator "best backend TypeScript repos with clean architecture"
```

**Output**:
```
=== Ranking Summary ===
Top 10 repositories:
  1. nestjs/nest (score: 9.2, stars: 75000)
  2. prisma/prisma (score: 8.9, stars: 32000)
  ...

Queue Status:
  Pending: 3
  Approved: 5
  Rejected: 2
```

## Agent Routing (v2.46 - 3-Dimension Classification)

The orchestrator routes tasks based on **3 dimensions** (RLM-inspired):

| Dimension | Values | Description |
|-----------|--------|-------------|
| **Complexity** | 1-10 | Scope, risk, ambiguity |
| **Information Density** | CONSTANT / LINEAR / QUADRATIC | How answers scale with input |
| **Context Requirement** | FITS / CHUNKED / RECURSIVE | Decomposition needs |

### Workflow Routing Matrix

| Density | Context | Complexity | Route |
|---------|---------|------------|-------|
| CONSTANT | FITS | 1-3 | **FAST_PATH** (3 steps) |
| CONSTANT | FITS | 4-10 | STANDARD |
| LINEAR | CHUNKED | Any | PARALLEL_CHUNKS |
| QUADRATIC | RECURSIVE | Any | RECURSIVE_DECOMPOSE |

### Additional Routing Criteria

1. **Task Type**: Security → `@security-auditor`, Tests → `@test-architect`
2. **File Type**: `.py` → `@kieran-python-reviewer`, `.ts` → `@kieran-typescript-reviewer`
3. **Domain**: DeFi → Blockchain agents, Frontend → `@frontend-reviewer`

## Hooks Integration (v2.56.2)

### v2.46 RLM-Inspired Hooks (NEW)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `fast-path-check.sh` | PreToolUse (Task) | Detect trivial tasks → FAST_PATH routing |
| `parallel-explore.sh` | PostToolUse (Task) | Launch 5 concurrent exploration tasks |
| `recursive-decompose.sh` | PostToolUse (Task) | Trigger sub-orchestrators for complex tasks |
| `quality-gates-v2.sh` | PostToolUse (Edit/Write) | Quality-first validation (consistency advisory) |

### v2.45 Automation Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `auto-plan-state.sh` | PostToolUse (Write) | Auto-creates `plan-state.json` when `orchestrator-analysis.md` is written |
| `lsa-pre-step.sh` | PreToolUse (Edit/Write) | LSA verification before implementation |
| `plan-sync-post-step.sh` | PostToolUse (Edit/Write) | Drift detection after implementation |
| `plan-state-init.sh` | CLI | Initialize/manage plan-state.json |

### v2.56 Automated Monitoring Hooks (NEW)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `status-auto-check.sh` | PostToolUse (Edit/Write/Bash) | Auto-shows orchestration status every 5 operations |
| `checkpoint-smart-save.sh` | PreToolUse (Edit/Write) | Smart checkpoints on risky edits |
| `statusline-health-monitor.sh` | UserPromptSubmit | Health checks every 5 minutes |

**Smart Checkpoint Triggers**:
- `high_complexity`: Plan complexity ≥ 7
- `high_risk_step`: Step involves auth/security/payment
- `critical_file`: Config, settings, .env, database files
- `security_file`: Files with auth/secret/credential in name

### Logging Hooks

5 priority agents have logging hooks:

```
@security-auditor   → ~/.ralph/logs/security-audit.log
@orchestrator       → ~/.ralph/logs/orchestration.log
@code-reviewer      → ~/.ralph/logs/code-review.log
@test-architect     → ~/.ralph/logs/test-coverage.log
@debugger           → ~/.ralph/logs/debug.log
```

## v2.46 Workflow Routes

### FAST_PATH (Trivial Tasks - 3 Steps)
```
DIRECT_EXECUTE → MICRO_VALIDATE → DONE
```
*5x faster: 5-10 min → 1-2 min*

### STANDARD (Regular Tasks - 12 Steps)
```
EVALUATE → CLARIFY → GAP-ANALYST → CLASSIFY → PLAN → PERSIST →
PLAN-STATE → PLAN MODE → DELEGATE → EXECUTE-WITH-SYNC → VALIDATE → RETROSPECT
```

### RECURSIVE_DECOMPOSE (Complex Tasks)
```
┌─────────────────────────────────────────────────────────────────────┐
│              ROOT ORCHESTRATOR (QUADRATIC density)                  │
├─────────────────────────────────────────────────────────────────────┤
│  1. IDENTIFY CHUNKS (by module/feature/file group)                  │
│  2. CREATE SUB-PLANS (each chunk gets verifiable spec)              │
│  3. SPAWN SUB-ORCHESTRATORS:                                        │
│     ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                │
│     │ SUB-ORCH 1  │ │ SUB-ORCH 2  │ │ SUB-ORCH 3  │                │
│     │ (STANDARD)  │ │ (STANDARD)  │ │ (STANDARD)  │                │
│     └─────────────┘ └─────────────┘ └─────────────┘                │
│  4. AGGREGATE RESULTS (reconcile, merge, verify)                    │
│                                                                     │
│  Max depth: 3 | Max children per level: 5                           │
└─────────────────────────────────────────────────────────────────────┘
```

### Nested Loop (Per-Step)
```
┌─────────────────────────────────────────────────────────────────────┐
│                    EXTERNAL RALPH LOOP (max 25 iter)                │
├─────────────────────────────────────────────────────────────────────┤
│    For EACH step in plan:                                           │
│    ┌─────────────────────────────────────────────────────────┐     │
│    │           INTERNAL PER-STEP LOOP (3-Fix Rule)          │     │
│    │   @lead-software-architect → IMPLEMENT → @plan-sync    │     │
│    │       ↑                                   │             │     │
│    │       └──── retry if MICRO-GATE fails ───┘             │     │
│    └─────────────────────────────────────────────────────────┘     │
│    After ALL steps: @quality-auditor + @adversarial-plan-validator │
└─────────────────────────────────────────────────────────────────────┘
```

## Usage Examples

```bash
# Invoke specific agent
@orchestrator "Implement user authentication"
@security-auditor src/
@debugger "TypeError in auth module"

# Agents are auto-selected by orchestrator based on task
/orchestrator "Fix security vulnerabilities"
# → Routes to @security-auditor

/orchestrator "Add React dashboard"
# → Routes to @frontend-reviewer + @kieran-typescript-reviewer
```

## Adding Custom Agents

Create a new agent in `.claude/agents/`:

```markdown
---
name: my-agent
description: When to use this agent
model: sonnet
allowed-tools: Read,Grep,Glob,Bash,Task
hooks:
  preToolUse: my-hook.sh
---

# My Agent

## Purpose
[What this agent does]

## Workflow
1. Step one
2. Step two
...
```

## Hook Testing (v2.52.0)

All hooks are validated by a **behavioral test suite** that executes hooks with real inputs.

### Test Categories

| Category | Tests | Purpose |
|----------|-------|---------|
| JSON Output | 7 | Hook ALWAYS returns valid `{"decision": "continue"}` |
| Command Injection | 4 | Shell metacharacters blocked |
| Path Traversal | 2 | Symlinks resolved, paths validated |
| Race Conditions | 4 | umask 077, noclobber, chmod 700 |
| Edge Cases | 6 | Unicode, long inputs, null bytes |
| Error Handling | 3 | Exit 0 always, stderr clean |
| Regressions | 5 | Past bugs don't return |
| Performance | 3 | Hooks complete in <5s |

### Running Hook Tests

```bash
# All 38 hook tests
python -m pytest tests/test_hooks_comprehensive.py -v

# Security tests only
python -m pytest tests/test_hooks_comprehensive.py::TestSecurityCommandInjection -v

# Independent review via Codex CLI
codex exec -m gpt-5.2-codex --sandbox read-only \
  --config model_reasoning_effort=high \
  "review ~/.claude/hooks/<hook>.sh --focus security" 2>/dev/null
```

See `tests/HOOK_TESTING_PATTERNS.md` for patterns when adding new hooks.

---

*"Me fail architecture? That's unpossible!"* - Lead Software Architect Agent
