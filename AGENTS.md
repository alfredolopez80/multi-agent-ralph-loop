# Multi-Agent Ralph Wiggum - Agents Reference v2.84.1

## Overview

Ralph orchestrates **14 specialized agents** across different domains with **simplified multi-model support**: GLM-4.7 (PRIMARY for all tasks) + GLM-5 (TEAMMATES with thinking mode) + Codex GPT-5.3 (SPECIALIZED for security/performance).

> **🆕 v2.84.1 - GLM-5 Agent Teams Complete Integration**: 7 commands with `--with-glm5` flag (`/orchestrator`, `/loop`, `/adversarial`, `/bugs`, `/parallel`, `/gates`, `/security`). 4 GLM-5 teammate agents with thinking mode. SubagentStop native hook (not TeammateIdle/TaskCompleted which don't exist). Codex upgraded to `gpt-5.3-codex`. 42/42 tests passing.

> **v2.83.1 - Hook System 5-Phase Audit Complete**: 100% validation achieved (18/18 tests passing). Eliminated 4 race conditions with atomic file locking, fixed 3 JSON malformations, added TypeScript caching (80-95% speedup), multilingual support (EN/ES), and 5 new critical hooks.

## Model Support (v2.84.1) - SIMPLIFIED

Ralph now uses a **simplified 3-model architecture** for maximum cost efficiency:

| Model | Provider | Cost | Use Case | Status |
|-------|----------|------|----------|--------|
| **GLM-4.7** | Z.AI | **~0.15x** | All tasks (PRIMARY) | **PRIMARY** |
| **GLM-5** | Z.AI | **~0.20x** | Teammates with thinking mode | **TEAMMATES** |
| **Codex GPT-5.3** | OpenAI | Variable | Security, performance, planning | **SPECIALIZED** |

### GLM-5 - TEAMMATES Model (v2.84.1) ✅ NEW

**Purpose**: Teammate agents with native thinking mode for parallel execution.

**Features**:
- Native `thinking` mode with `reasoning_content` capture
- 4 specialized teammates: `glm5-coder`, `glm5-reviewer`, `glm5-tester`, `glm5-orchestrator`
- Project-scoped storage in `.ralph/`
- Integrated with 7 commands via `--with-glm5` flag

**Usage**:
```bash
# Spawn single teammate
/glm5 coder "Implement authentication"

# Parallel execution
/glm5-parallel "Complex task" --teammates coder,reviewer,tester

# With orchestrator
/orchestrator "Implement feature" --with-glm5

# With loop for iterative fixing
/loop "Fix all errors" --with-glm5
```

**Output Files**:
- `.ralph/teammates/{task_id}/status.json` - Task status
- `.ralph/reasoning/{task_id}.txt` - Thinking process

### Codex GPT-5.3 - SPECIALIZED Model (v2.84.1) ✅ UPGRADED

**Purpose**: SPECIALIZED model for security audits, planning, and code analysis.

**Upgraded from GPT-5.2 to GPT-5.3** with adaptive reasoning:
- `--complexity low` → reasoning "medium" (faster)
- `--complexity medium` → reasoning "high" (balanced)
- `--complexity high` → reasoning "xhigh" (deepest)

**Usage**:
```bash
# Planning with Codex
/codex-plan "Design microservice architecture" --complexity high
|-----|-----|
| `mmc --query` | `mmc --query` (auto-routes to GLM) |
| `@minimax-reviewer` | `@glm-reviewer` |
| `/minimax-review` | `/glm-4.7` |

### GLM-4.7 MCP Servers (4)

| Server | Tools | Use Case |
|--------|-------|----------|
| **zai-mcp-server** | 9 vision tools | Screenshot debugging, diagram understanding |
| **web-search-prime** | webSearchPrime | Real-time web search |
| **web-reader** | webReader | Web content extraction |
| **zread** | search_doc, read_file | Repository knowledge access |

### Multi-Model Adversarial Validation

**v2.69**: Four-model validation for critical changes:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      ADVERSARIAL VALIDATION COUNCIL                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐                │
│  │  CODEX    │  │  CLAUDE   │  │  GEMINI   │  │  GLM-4.7  │                │
│  │ GPT-5.2   │  │   Opus    │  │  2.5 Pro  │  │  Reasoning│                │
│  │           │  │           │  │           │  │  + Web    │                │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘                │
│        └──────────────┼──────────────┼──────────────┘                       │
│                       ▼              ▼                                       │
│                   ┌──────────────────────┐                                   │
│                   │        JUDGE         │  (Claude Opus)                   │
│                   │  Anonymized Review   │                                   │
│                   └──────────┬───────────┘                                   │
│                              ▼                                               │
│                    CONSENSUS REQUIRED                                        │
│                    (All 4 must agree)                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Exit Criteria**: All four models must agree "NO ISSUES FOUND" before validation passes.

**GLM-4.7 Advantages in Council**:
- **~15% cost** vs Claude Opus (most economical planner)
- **Reasoning model**: Deep analysis via `reasoning_content`
- **Web search**: Can verify against current documentation
- **Independent perspective**: Chinese LLM provides diverse viewpoint

## Core Orchestration Agents (v2.84.1)

| Agent | Model | Purpose | Priority |
|-------|-------|---------|----------|
| `@orchestrator` | glm-4.7 | Main orchestration workflow | PRIMARY |
| `@security-auditor` | codex | Security-focused review | SPECIALIZED |
| `@debugger` | glm-4.7 | Bug detection and fixes | PRIMARY |
| `@code-reviewer` | glm-4.7 → codex | Code quality, patterns, best practices | PRIMARY → SECONDARY |
| `@performance-reviewer` | codex | Performance optimization | SPECIALIZED |

## GLM-5 Teammate Agents (v2.84.1) ✅ NEW

| Agent | Model | Purpose | Thinking Mode |
|-------|-------|---------|---------------|
| `glm5-coder` | glm-5 | Implementation, refactoring, bug fixes | ✅ Enabled |
| `glm5-reviewer` | glm-5 | Code review, security analysis | ✅ Enabled |
| `glm5-tester` | glm-5 | Test generation, coverage analysis | ✅ Enabled |
| `glm5-orchestrator` | glm-5 | Team coordination, task delegation | ✅ Enabled |

**Features**:
- All agents have `thinking: true` for transparent reasoning
- Reasoning captured to `.ralph/reasoning/{task_id}.txt`
- Status tracked in `.ralph/teammates/{task_id}/status.json`
- Spawned via `/glm5` command or `--with-glm5` flag

**Usage**:
```bash
# Single teammate
/glm5 coder "Implement factorial function"

# With commands
/orchestrator "Task" --with-glm5
/loop "Fix bugs" --with-glm5
/parallel src/ --with-glm5
```

| Agent | Model | Purpose |
|-------|-------|---------|

| Agent | Model | Purpose |
|-------|-------|---------|
| `@test-architect` | glm-4.7 | Test generation & coverage |
| `@debugger (GLM-4.7) PRIMARY | Bug detection & root cause analysis |
| `@refactorer` | glm-4.7 | Code refactoring & modernization |
| `@docs-writer` | glm-4.7 | Documentation generation |


| Agent | Trigger | Purpose |
|-------|---------|---------|
| `@code-simplicity-reviewer` | LOC > 100 | YAGNI enforcement, complexity reduction |
| `@architecture-strategist` | ≥3 modules OR complexity ≥7 | SOLID compliance, architectural review |
| `@pattern-recognition-specialist` | Refactoring tasks | Design patterns, anti-patterns |

## Cost-Effective Agents

| Agent | Model | Cost | Purpose |
|-------|-------|------|---------|
| `@glm-reviewer` | GLM-4.7 | 15% | Second opinion, web search, vision (PRIMARY) |
| `@minimax-reviewer (DEPRECATED - Use GLM-4.7) - fallback only |
| `@blender-3d-creator | glm-4.7 | 15% | 3D asset creation via Blender MCP |


| Agent | Model | Purpose |
|-------|-------|---------|
| `@repository-learner | glm-4.7 | Learn best practices from GitHub repositories |

## Swarm Mode Commands (v2.81.1) ✅ COMPLETE

**Overview**: 7 core commands with full swarm mode integration for parallel multi-agent execution.

### Commands with Team Composition

| Command | Team Size | Lead | Teammates | Speedup | Status |
|---------|-----------|------|-----------|---------|--------|
| `/orchestrator` | 4 | Workflow coordinator | Requirements analyst, Implementation specialist, Quality validation | 3x | ✅ |
| `/loop` | 4 | Loop coordinator | Execute specialist, Validate specialist, Quality check specialist | 3x | ✅ |
| `/edd` | 4 | EDD coordinator | Capability check specialist, Behavior check specialist, Non-functional check specialist | 3x | ✅ |
| `/bug` | 4 | Bug analysis lead | Error Analysis specialist, Root Cause specialist, Fix Validation specialist | 3x | ✅ |
| `/adversarial` | 4 | Adversarial lead | Assumption Challenger, Gap Hunter, Feasibility Validator | 3x | ✅ |
| `/parallel` | 7 | Parallel coordinator | Code, Security, Test, Performance, Documentation, Architecture reviewers | 6x | ✅ |
| `/gates` | 6 | Gates coordinator | TypeScript/JS, Python, Compiled, Smart Contracts, Config validators | 3x | ✅ |

### Validation Results

**Integration Tests**: 27/27 tests passing (100%)

**External Audits**:
| Audit | Model | Result | Score |
|-------|-------|--------|-------|
| **/adversarial** | ZeroLeaks-inspired | ✅ PASS | Strong defense |
| **/codex-cli** | gpt-5.2-codex | ✅ PASS | 9.3/10 Excellent |
| **/gemini-cli** | Gemini 3 Pro | ✅ PASS | 9.8/10 Outstanding |

### Configuration

Swarm mode requires **ONE configuration**:

```json
{
  "permissions": {
    "defaultMode": "delegate"
  }
}
```

**Note**: Environment variables (`CLAUDE_CODE_AGENT_*`) are set **dynamically** by Claude Code when spawning teammates.

### Usage

```bash
# Swarm mode is enabled by default
/orchestrator "Implement distributed system"    # 4 agents, 3x faster
/loop "fix all type errors"                   # 4 agents, 3x faster
/edd "Define feature requirements"            # 4 agents, 3x faster
/bug "Authentication fails"                   # 4 agents, 3x faster
/adversarial "Design rate limiter"            # 4 agents, 3x faster
/parallel "src/auth/"                         # 7 agents, 6x faster
/gates                                        # 6 agents, 3x faster
```

### Documentation

- **Usage Guide**: `docs/swarm-mode/SWARM_MODE_USAGE_GUIDE.md`
- **Integration Plan**: `docs/architecture/SWARM_MODE_INTEGRATION_PLAN_v2.81.1.md`
- **Consolidated Audits**: `docs/swarm-mode/CONSOLIDATED_AUDITS_v2.81.1.md`
- **Progress Report**: `docs/swarm-mode/INTEGRATION_PROGRESS_REPORT_v2.81.1.md`

---

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
| `--tier economic` | ~$0.30 | + OpenSSF Scorecard + GLM-4.7 validation |
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

## Hooks Integration (v2.83.1) - 100% VALIDATED

> **🆕 v2.83.1 - 5-Phase Hook System Audit Complete**: 100% validation achieved (target was 95%). All 83 hooks production-ready with race-condition-free operations, TypeScript caching (80-95% speedup), multilingual support (EN/ES), and 5 new critical hooks.

> **⚠️ CRITICAL v2.81.2**: PreToolUse hooks now use correct JSON schema with `hookSpecificOutput` wrapper. Fixed validation errors on Edit/Write/Bash operations. See [docs/bugs/PRETOOLUSE_JSON_SCHEMA_FIX_v2.81.2.md](docs/bugs/PRETOOLUSE_JSON_SCHEMA_FIX_v2.81.2.md).

> **⚠️ CRITICAL v2.81.1**: `PostCompact` does NOT exist in Claude Code. Compaction hooks have been fixed. See [docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md](docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md).

### v2.83.1 5-Phase Audit Results

```
╔══════════════════════════════════════════════════════════════════════════╗
║                    v2.83.1 HOOK SYSTEM AUDIT                             ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  Phase 1: Critical Fixes              ✅ 6/6 items     (100%)            ║
║  ├── Race conditions eliminated       ✅ 4/4 fixed     (100%)            ║
║  ├── JSON malformations fixed         ✅ 3/3 fixed     (100%)            ║
║  ├── Timeouts added                   ✅ 38 hooks      (100%)            ║
║  └── Invalid hooks archived           ✅ 1 archived    (100%)            ║
║                                                                          ║
║  Phase 2: Robustness                  ✅ 6/6 items     (100%)            ║
║  ├── TypeScript cache                 ✅ 80-95% faster                   ║
║  ├── Multilingual support             ✅ EN/ES (20+ ext)                 ║
║  ├── File locking                     ✅ 2 critical hooks                ║
║  └── Security hardening               ✅ umask 077 (38 hooks)            ║
║                                                                          ║
║  Phase 3: Documentation               ✅ 4/4 items     (100%)            ║
║  ├── New hooks created                ✅ 2 hooks                         ║
║  ├── Hooks documented                 ✅ +24 hooks                       ║
║  └── Settings.json example            ✅ 41 hooks                        ║
║                                                                          ║
║  Phase 4: Optimization                ✅ 5/5 items     (100%)            ║
║  ├── File extensions                  ✅ 8 new (20 total)                ║
║  ├── Rate limiting                    ✅ GLM-4.7 API                     ║
║  └── Structured logging               ✅ JSON format                     ║
║                                                                          ║
║  Phase 5: Testing                     ✅ 6/6 items     (100%)            ║
║  ├── Syntax validation                ✅ 83/83 hooks   (100%)            ║
║  ├── JSON parseability                ✅ 83/83 hooks   (100%)            ║
║  ├── Integration tests                ✅ 18/18 tests   (100%)            ║
║  └── Overall validation               ✅ 100% (target: 95%)              ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### New v2.83.1 Critical Hooks

| Hook | Event | Matcher | Purpose | Status |
|------|-------|---------|---------|--------|
| `orchestrator-auto-learn.sh` | PreToolUse | Task | Detects knowledge gaps, auto-triggers curator learning | ✅ Production |
| `promptify-security.sh` | PreToolUse | Task | Security validation for prompts with pattern detection | ✅ Production |
| `parallel-explore.sh` | PostToolUse | Task | Launches 5 concurrent exploration tasks | ✅ Production |
| `recursive-decompose.sh` | PostToolUse | Task | Triggers sub-orchestrators for complex tasks | ✅ Production |
| `todo-plan-sync.sh` | PostToolUse | TodoWrite | Syncs todos with plan-state.json progress | ✅ Production |

**Key Changes**:
- ✅ Fixed `auto-sync-global.sh` glob pattern bug (caused SessionStart failures)
- ✅ Added `session-start-restore-context.sh` for post-compaction restoration
- ✅ Clarified that `PostCompact` is NOT a valid event (only `PreCompact` exists)
- ✅ Both `pre-compact-handoff.sh` and `post-compact-restore.sh` run in `PreCompact` event
- ✅ Atomic file locking with `mkdir` pattern for race-condition-free operations
- ✅ TypeScript caching reduces compile times by 80-95%
- ✅ Multilingual support (EN/ES) for 20+ file extensions

**Correct Compaction Pattern**:
```
PreCompact Event → pre-compact-handoff.sh saves state
    ↓
Compaction Happens → Old messages removed
    ↓
SessionStart Event → session-start-restore-context.sh restores state ✅
```

### v2.46 RLM-Inspired Hooks (NEW)

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

### v2.82 Comprehensive Hooks Reference

| Evento | Cantidad | Hooks Principales |
|--------|----------|-------------------|
| UserPromptSubmit | 8 | command-router, context-warning, prompt-analyzer, skill-pre-warm, statusline-health-monitor |
| PreToolUse | 25+ | smart-memory-search, agent-memory-auto-init, lsa-pre-step, checkpoint-smart-save, fast-path-check, skill-validator, inject-session-context |
| PostToolUse | 35+ | plan-sync-post-step, decision-extractor, semantic-realtime-extractor, status-auto-check, todo-plan-sync, quality-gates-v2, checkpoint-auto-save |
| PreCompact | 3 | pre-compact-handoff, post-compact-restore |
| SessionStart | 8 | session-start-ledger, session-start-restore-context, session-start-tldr, session-start-welcome |
| Stop | 5 | sentry-report, reflection-engine, stop-verification, semantic-auto-extractor |
| Interval | 4 | periodic-reminder, state-sync, sentry-check-status |

> **🆕 v2.82.0 - Intelligent Command Router Hook**: New UserPromptSubmit hook that analyzes prompts and suggests optimal commands (`/bug`, `/edd`, `/orchestrator`, `/loop`, `/adversarial`, `/gates`, `/security`, `/parallel`, `/audit`). Multilingual support (English + Spanish). Confidence-based filtering (≥ 80%).

**Hook Count Summary (v2.83.1):**
- Total scripts: 83 (validated)
- Registered in settings.json: 39 (34 + 5 new)
- Utility scripts (sourced): 6
- Backup/archived: 1 (post-compact-restore.sh)

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
model: glm-4.7
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
