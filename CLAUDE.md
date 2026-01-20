# Multi-Agent Ralph v2.57.0

> "Me fail English? That's unpossible!" - Ralph Wiggum

**Smart Memory-Driven Orchestration** with parallel memory search, RLM-inspired routing, quality-first validation, checkpoints, agent handoffs, local observability, and **autonomous self-improvement**.

---

## Language Policy (Política de Idioma)

> **IMPORTANT**: This repository follows English-only documentation standards.

| Content Type | Language | Notes |
|--------------|----------|-------|
| **Code** | English | Variables, functions, classes, comments |
| **Documentation** | English | README.md, CLAUDE.md, AGENTS.md, CHANGELOG.md |
| **Commit Messages** | English | Conventional commits format |
| **Code Comments** | English | Inline documentation |
| **Pull Requests** | English | Titles, descriptions, reviews |

### Exception for Spanish-Speaking Users

- **Prompt/Chat Responses**: Claude may respond in Spanish when the user writes in Spanish
- **README.es.md**: Spanish translation available for initial understanding
- **Technical discussions**: Should remain in English for consistency

### Why English-Only?

1. **Global Collaboration**: English is the universal language for software development
2. **Searchability**: English documentation is easier to find and index
3. **Tooling Compatibility**: Linters, formatters, and AI tools work best with English
4. **Onboarding**: New contributors can understand the codebase immediately

---

## Quick Start

```bash
# Full orchestration
/orchestrator "Implement OAuth2 authentication"
ralph orch "Migrate database from MySQL to PostgreSQL"

# Quality validation
/gates          # Quality gates
/adversarial    # Spec refinement

# Loop until VERIFIED_DONE
/loop "fix all type errors"

# v2.51: Checkpoints (Time Travel)
ralph checkpoint save "before-refactor" "Pre-auth module refactoring"
ralph checkpoint restore "before-refactor"

# v2.51: Handoffs (Agent-to-Agent)
ralph handoff transfer --from orchestrator --to security-auditor --task "Audit auth module"
ralph handoff agents   # List available agents
```

---

## Core Workflow (12 Steps) - v2.46

```
0. EVALUATE     → 3-dimension classification (FAST_PATH vs STANDARD)
1. CLARIFY      → AskUserQuestion (MUST_HAVE + NICE_TO_HAVE)
2. CLASSIFY     → Complexity 1-10 + Info Density + Context Req
3. PLAN         → orchestrator-analysis.md → Plan Mode
4. PLAN MODE    → EnterPlanMode (reads analysis)
5. DELEGATE     → Route to optimal model
6. EXECUTE-WITH-SYNC → LSA-VERIFY → IMPLEMENT → PLAN-SYNC → MICRO-GATE
7. VALIDATE     → CORRECTNESS (block) + QUALITY (block) + CONSISTENCY (advisory)
8. RETROSPECT   → Analyze and improve
```

**Fast-Path** (complexity ≤ 3): DIRECT_EXECUTE → MICRO_VALIDATE → DONE (3 steps)

---

## 3-Dimension Classification (RLM)

| Dimension | Values |
|-----------|--------|
| **Complexity** | 1-10 |
| **Information Density** | CONSTANT / LINEAR / QUADRATIC |
| **Context Requirement** | FITS / CHUNKED / RECURSIVE |

### Workflow Routing

| Density | Context | Complexity | Route |
|---------|---------|------------|-------|
| CONSTANT | FITS | 1-3 | **FAST_PATH** |
| CONSTANT | FITS | 4-10 | STANDARD |
| LINEAR | CHUNKED | ANY | PARALLEL_CHUNKS |
| QUADRATIC | ANY | ANY | RECURSIVE_DECOMPOSE |

---

## Memory Architecture (v2.49)

```
SMART MEMORY SEARCH (PARALLEL)
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│claude-mem│ │ memvid   │ │ handoffs │ │ ledgers  │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │ PARALLEL   │ PARALLEL   │ PARALLEL   │ PARALLEL
     └────────────┴────────────┴────────────┘
                    ↓
         .claude/memory-context.json
```

**Three Memory Types**:
| Type | Purpose | Storage |
|------|---------|---------|
| **Semantic** | Facts, preferences | `~/.ralph/memory/semantic.json` |
| **Episodic** | Experiences (30-day TTL) | `~/.ralph/episodes/` |
| **Procedural** | Learned behaviors | `~/.ralph/procedural/rules.json` |

### Repository Learner (v2.50) - NEW

```
/repo-learn https://github.com/{owner}/{repo}
```

**What it does**:
1. Acquire repository via git clone or GitHub API
2. Analyze code using AST-based pattern extraction
3. Classify patterns into categories (error_handling, async_patterns, type_safety, architecture, testing, security)
4. Generate procedural rules with confidence scores
5. Enrich `~/.ralph/procedural/rules.json` with deduplication

**Result**: Claude learns best practices from quality repositories and applies them in future implementations.

### Repo Curator (v2.55)

```
/curator "best backend TypeScript repos with clean architecture"
```

**What it does**:
1. **DISCOVERY** → GitHub API search for candidate repositories
2. **SCORING** → Quality metrics + Context Relevance (v2.55)
3. **RANKING** → Top N repos (configurable, max per org)
4. **USER REVIEW** → Interactive queue for approve/reject
5. **LEARN** → Extract patterns from approved repos via repository-learner

**Pricing Tiers**:
| Tier | Cost | Features |
|------|------|----------|
| `--tier free` | $0.00 | GitHub API + local scoring |
| `--tier economic` | ~$0.30 | + OpenSSF + MiniMax (DEFAULT) |
| `--tier full` | ~$0.95 | + Claude + Codex adversarial (with fallback) |

**All Scripts (v2.55)**:
| Script | Key Options |
|--------|-------------|
| `curator-discovery.sh` | `--type`, `--lang`, `--query`, `--tier`, `--max-results`, `--output` |
| `curator-scoring.sh` | `--input`, `--output`, `--tier`, `--context` (NEW), `--verbose` |
| `curator-rank.sh` | `--input`, `--output`, `--top-n`, `--max-per-org` |
| `curator-ingest.sh` | `--repo`, `--output-dir`, `--approve`, `--source`, `--depth` |
| `curator-approve.sh` | `--repo`, `--all` |
| `curator-reject.sh` | `--repo`, `--reason` |
| `curator-learn.sh` | `--type`, `--lang`, `--repo`, `--all` |
| `curator-queue.sh` | `--type`, `--lang` |

**Usage**:
```bash
# Full pipeline (economic tier, default)
/curator full --type backend --lang typescript

# Discovery with options
/curator discovery --query "microservice" --max-results 200 --tier free

# Scoring with context relevance (v2.55 NEW)
/curator scoring --context "error handling,retry,resilience"

# Custom ranking
/curator rank --top-n 15 --max-per-org 3

# Show ranking / queue
/curator show --type backend --lang typescript
/curator pending --type backend

# Approve/reject repos
/curator approve nestjs/nest
/curator approve --all
/curator reject some/repo --reason "Low test coverage"

# Execute learning
/curator learn --type backend --lang typescript
/curator learn --repo nestjs/nest
/curator learn --all
```

### Codex Planner (v2.50) - NEW

```
/codex-plan "Design a distributed caching system"
/orchestrator "Implement microservices" --use-codex
```

**What it does**:
1. **CLARIFY** → AskUser questions (MUST_HAVE + NICE_TO_HAVE)
2. **EXECUTE** → Codex 5.2 with `xhigh` reasoning
3. **SAVE** → Plan saved to `http://codex-plan.md`

**Integration with Orchestrator**:
Use `--use-codex` or `--codex` flag to invoke Codex planning:
```bash
/orchestrator "Implement distributed system" --use-codex
/orchestrator "Design microservices architecture" --codex
```

**Requirements**:
- Codex CLI: `npm install -g @openai/codex`
- Access to `gpt-5.2-codex` model

### Checkpoint System (v2.51) - NEW

LangGraph-style "time travel" for orchestration state.

```bash
# Save state before risky operation
ralph checkpoint save "before-auth-refactor" "Pre-authentication module changes"

# List all checkpoints
ralph checkpoint list

# Restore if something goes wrong
ralph checkpoint restore "before-auth-refactor"

# Compare checkpoint vs current state
ralph checkpoint diff "before-auth-refactor"
```

**What it saves**:
| File | Purpose |
|------|---------|
| `plan-state.json` | Current orchestration state |
| `orchestrator-analysis.md` | Planning analysis |
| `git-status.txt` | Uncommitted changes |
| `git-diff.patch` | Unstaged changes as patch |
| `metadata.json` | Checkpoint metadata |

**Storage**: `~/.ralph/checkpoints/<name>/`

### Handoff API (v2.51) - NEW

OpenAI Agents SDK-style explicit agent-to-agent transfers.

```bash
# Transfer task from orchestrator to security-auditor
ralph handoff transfer --from orchestrator --to security-auditor \
    --task "Audit authentication module" \
    --context '{"files": ["src/auth/"]}'

# List available agents
ralph handoff agents

# Validate agent exists
ralph handoff validate debugger

# View handoff history
ralph handoff history
```

**Default Agents (11)**:
| Agent | Model | Capabilities |
|-------|-------|--------------|
| `orchestrator` | opus | planning, classification, delegation, validation |
| `security-auditor` | opus | security, vulnerability-scan, code-review |
| `debugger` | opus | debugging, error-analysis, fix-generation |
| `code-reviewer` | sonnet | code-review, pattern-analysis, quality-check |
| `test-architect` | sonnet | testing, test-generation, coverage-analysis |
| `refactorer` | sonnet | refactoring, pattern-application, code-improvement |
| `frontend-reviewer` | sonnet | frontend, ui-review, accessibility |
| `docs-writer` | minimax | documentation, readme, api-docs |
| `minimax-reviewer` | minimax | validation, quick-review, second-opinion |
| `repository-learner` | sonnet | learning, pattern-extraction, rule-generation |
| `repo-curator` | sonnet | curation, scoring, discovery |

**Agent Registry**: `~/.ralph/config/agents.json` (optional override)

### Plan State v2 Schema (v2.51) - NEW

Phases + barriers for strict WAIT-ALL consistency.

```json
{
  "version": "2.51.0",
  "phases": [
    {"phase_id": "clarify", "step_ids": ["1"], "execution_mode": "sequential"},
    {"phase_id": "implement", "step_ids": ["6a", "6b"], "execution_mode": "parallel"}
  ],
  "barriers": {
    "clarify_complete": false,
    "implement_complete": false
  }
}
```

**Automatic Migration**: Run `ralph migrate check` or it auto-migrates at session start.

### Agent-Scoped Memory (v2.51) - NEW

LlamaIndex AgentWorkflow-style isolated memory buffers per agent.

```bash
# Initialize memory for an agent
ralph agent-memory init security-auditor

# Write to agent's memory
ralph agent-memory write security-auditor semantic "Found SQL injection in auth.py:42"
ralph agent-memory write security-auditor working "Currently analyzing user input validation"

# Read agent's memory
ralph agent-memory read security-auditor          # All types
ralph agent-memory read security-auditor semantic # Only semantic

# Transfer memory during handoff (default: relevant)
ralph agent-memory transfer security-auditor code-reviewer relevant

# List all agents with memory buffers
ralph agent-memory list

# Garbage collect expired episodic entries
ralph agent-memory gc
```

**Memory Types**:
| Type | Purpose | TTL |
|------|---------|-----|
| `semantic` | Persistent facts and knowledge | Never expires |
| `episodic` | Experiences and observations | 24 hours |
| `working` | Current task context | Session-based |

**Transfer Filters**:
- `all`: Transfer all memory
- `relevant`: Semantic + recent working (default for handoffs)
- `working`: Only working memory

**Storage**: `~/.ralph/agent-memory/<agent_id>/`

### Event-Driven Engine (v2.51) - NEW

LangGraph-style event bus with WAIT-ALL phase barriers.

```bash
# Emit an event
ralph events emit step.complete '{"step_id": "step1"}' orchestrator

# Subscribe to events
ralph events subscribe phase.complete /path/to/handler.sh

# Check barrier status (WAIT-ALL)
ralph events barrier check phase-1

# Wait for barrier (blocks until all steps complete)
ralph events barrier wait phase-1 300  # 300s timeout

# List all barriers and status
ralph events barrier list

# Determine next phase based on state
ralph events route

# Advance to next phase
ralph events advance phase-2

# Show event bus status
ralph events status

# View event history
ralph events history 20
```

**Event Types**:
| Event | Trigger |
|-------|---------|
| `barrier.complete` | Phase barrier satisfied (all steps done) |
| `phase.start` | Phase started |
| `phase.complete` | Phase completed |
| `step.complete` | Individual step completed |
| `handoff.transfer` | Agent-to-agent transfer |

**WAIT-ALL Pattern**:
Phase N+1 **never** starts until ALL sub-steps of Phase N complete. This ensures strict consistency in multi-agent orchestration.

**Storage**: `~/.ralph/events/event-log.jsonl`

### Local Observability (v2.52) - NEW

Query-based status and traceability without external services.

```bash
# Full orchestration status
ralph status

# Compact one-liner
ralph status --compact
# Output: 🔄 STANDARD Step 3/7 (42%) - in_progress

# Detailed step breakdown
ralph status --steps

# JSON for scripts
ralph status --json | jq '.plan.status'
```

**StatusLine Integration**:
Progress is shown in the statusline automatically:
```
⎇ main* │ 📊 3/7 42% │ [claude-hud metrics]
```

| Icon | Meaning |
|------|---------|
| `📊` | Active plan |
| `🔄` | Executing |
| `⚡` | Fast-path |
| `✅` | Completed |

**Traceability**:
```bash
# Show recent events
ralph trace show 30

# Search for specific events
ralph trace search "handoff"

# Visual timeline
ralph trace timeline

# Export for analysis
ralph trace export csv ./trace-report.csv

# Session summary
ralph trace summary
```

**Event Log**: `~/.ralph/events/event-log.jsonl` (shared with event-bus)

### Autonomous Self-Improvement (v2.55) - NEW

Proactive learning and memory population for higher code quality.

```bash
# Memory system health check
ralph health                    # Full health report
ralph health --compact          # One-line summary
ralph health --json             # JSON output for scripts
ralph health --fix              # Auto-fix critical issues
```

**Health Checks**: Semantic, Procedural, Episodic, Agent-Memory, Curator, Events, Ledgers, Handoffs, Checkpoints

**Auto-Learning Triggers**:
| Condition | Severity | Action |
|-----------|----------|--------|
| ZERO relevant rules (any complexity) | CRITICAL | Learning REQUIRED before implementation |
| <3 rules AND complexity ≥7 | HIGH | Learning RECOMMENDED for better quality |

**New Hooks (v2.55)**:
| Hook | Trigger | Purpose |
|------|---------|---------|
| `orchestrator-auto-learn.sh` | PreToolUse (Task) | Detects knowledge gaps, recommends `/curator` |
| `agent-memory-auto-init.sh` | PreToolUse (Task) | Auto-initializes agent memory buffers |
| `semantic-auto-extractor.sh` | Stop | Extracts facts from git diff (functions, classes) |
| `decision-extractor.sh` | PostToolUse | Detects architectural patterns and decisions |
| `curator-suggestion.sh` | UserPromptSubmit | Suggests `/curator` when memory is empty |

**Automatic Extraction**:
- **Semantic**: New functions, classes, dependencies from git diff
- **Decisions**: Design patterns (Singleton, Repository, Factory...), architectural choices (async/await, caching, logging)
- **Source tracking**: `"source": "auto-extract"` with deduplication

### Automated Monitoring (v2.56) - NEW

100% automatic monitoring via hooks - no manual commands needed.

**Automation Hooks (v2.56)**:
| Hook | Trigger | Purpose |
|------|---------|---------|
| `status-auto-check.sh` | PostToolUse (Edit/Write/Bash) | Auto-shows status every 5 operations |
| `checkpoint-smart-save.sh` | PreToolUse (Edit/Write) | Smart checkpoints on risky edits |
| `statusline-health-monitor.sh` | UserPromptSubmit | Health checks every 5 minutes |

**Smart Checkpoint Triggers**:
| Trigger | Condition |
|---------|-----------|
| `high_complexity` | Plan complexity ≥ 7 |
| `high_risk_step` | Step involves auth/security/payment |
| `critical_file` | Config, settings, .env, database files |
| `security_file` | Files with auth/secret/credential in name |

**Health Checks**:
- Script existence and permissions
- Plan-state JSON validity
- Stuck detection (in_progress > 30 min)
- StatusLine sync verification

---

## Quality-First Validation (v2.46)

```
Stage 1: CORRECTNESS → Syntax errors (BLOCKING)
Stage 2: QUALITY     → Type errors (BLOCKING)
Stage 2.5: SECURITY  → semgrep + gitleaks (BLOCKING)
Stage 3: CONSISTENCY → Linting (ADVISORY - not blocking)
```

---

## Model Routing

| Route | Primary | Secondary | Max Iter |
|-------|---------|-----------|----------|
| FAST_PATH | sonnet | - | 3 |
| STANDARD (1-4) | minimax-m2.1 | sonnet | 25 |
| STANDARD (5-6) | sonnet | opus | 25 |
| STANDARD (7-10) | opus | sonnet | 25 |

---

## Commands Reference

```bash
# Core
ralph orch "task"         # Full orchestration
ralph gates               # Quality gates
ralph loop "task"         # Loop (25 iter)
ralph compact             # Manual context save
ralph health              # Memory system health check (v2.55)
ralph health --compact    # One-line health summary
ralph health --fix        # Auto-fix critical issues

# Memory (v2.49)
ralph memory-search "query"  # Parallel search
ralph fork-suggest "task"    # Find sessions to fork

# Repository Learning (v2.50)
repo-learn https://github.com/python/cpython          # Learn from repo
repo-learn https://github.com/fastapi/fastapi --category error_handling  # Focused

# Repo Curator (v2.55)
ralph curator full --type backend --lang typescript   # Full pipeline
ralph curator discovery --query "microservice" --max-results 200  # Custom search
ralph curator scoring --context "error handling,retry"  # Context relevance (v2.55)
ralph curator rank --top-n 15 --max-per-org 3         # Custom ranking
ralph curator show --type backend --lang typescript   # View ranking
ralph curator pending --type backend                  # View queue
ralph curator approve nestjs/nest                     # Approve single
ralph curator approve --all                           # Approve all staged
ralph curator reject some/repo --reason "Low quality" # Reject with reason
ralph curator ingest --repo x/y --approve --source "patterns"  # Direct ingest
ralph curator learn --repo nestjs/nest                # Learn specific
ralph curator learn --all                             # Learn all approved

# Codex Planning (v2.50)
codex-plan "Design distributed system"                # Codex planning
/orchestrator "task" --use-codex                      # Orchestrator with Codex

# Checkpoint System (v2.51)
ralph checkpoint save "name" "description"            # Save state
ralph checkpoint restore "name"                       # Restore from checkpoint
ralph checkpoint list                                 # List all checkpoints
ralph checkpoint show "name"                          # Show checkpoint details
ralph checkpoint diff "n1" "n2"                       # Compare checkpoints

# Handoff API (v2.51)
ralph handoff transfer --from X --to Y --task "desc"  # Agent handoff
ralph handoff agents                                  # List available agents
ralph handoff validate <agent>                        # Validate agent exists
ralph handoff history                                 # View handoff history

# Schema Migration (v2.51)
ralph migrate check                                   # Check if migration needed
ralph migrate run                                     # Execute migration
ralph migrate dry-run                                 # Preview migration

# Agent-Scoped Memory (v2.51)
ralph agent-memory init <agent>                       # Initialize memory buffer
ralph agent-memory write <agent> <type> <content>     # Write to memory
ralph agent-memory read <agent> [type]                # Read from memory
ralph agent-memory transfer <from> <to> [filter]      # Transfer during handoff
ralph agent-memory list                               # List all agents
ralph agent-memory gc                                 # Garbage collect expired

# Event-Driven Engine (v2.51)
ralph events emit <type> [payload]                    # Emit event
ralph events subscribe <type> <handler>               # Subscribe to events
ralph events barrier check <phase>                    # Check WAIT-ALL barrier
ralph events barrier wait <phase> [timeout]           # Wait for barrier
ralph events barrier list                             # List all barriers
ralph events route                                    # Determine next phase
ralph events advance [phase]                          # Advance to next phase
ralph events status                                   # Event bus status
ralph events history [count]                          # Event history

# Observability (v2.52)
ralph status                                          # Full orchestration status
ralph status --compact                                # One-line summary
ralph status --steps                                  # Detailed step breakdown
ralph status --json                                   # JSON output
ralph trace show [count]                              # Recent events
ralph trace search <query>                            # Search events
ralph trace timeline                                  # Visual timeline
ralph trace export [format]                           # Export to JSON/CSV
ralph trace summary                                   # Session summary

# Security
ralph security src/       # Security audit
ralph security-loop src/  # Iterative audit

# Worktree
ralph worktree "task"     # Create worktree
ralph worktree-pr <branch> # PR + review

# Context
ralph ledger save         # Save session state
ralph handoff create      # Create handoff
```

---

## Agents (11+)

| Agent | Model | Purpose |
|-------|-------|---------|
| `@orchestrator` | opus | Coordinator |
| `@security-auditor` | opus | Security |
| `@debugger` | opus | Bug detection |
| `@code-reviewer` | sonnet | Reviews |
| `@test-architect` | sonnet | Tests |
| `@refactorer` | sonnet | Refactoring |
| `@frontend-reviewer` | sonnet | UI/UX |
| `@docs-writer` | minimax | Docs |
| `@minimax-reviewer` | minimax | Second opinion |
| `@repository-learner` | sonnet | Learn best practices from repos |
| `@repo-curator` | sonnet | Curate quality repos for learning |

---

## Hooks (30 registered)

| Event Type | Purpose |
|------------|---------|
| SessionStart | Context preservation at startup, **auto-migrate plan-state** (v2.51) |
| PreCompact | Save state before compaction |
| PostToolUse | Quality gates after Edit/Write |
| PreToolUse | Safety guards before Bash/Skill |
| UserPromptSubmit | Context warnings, reminders |
| Stop | Session reports |

---

## Ralph Loop Pattern

```
EXECUTE → VALIDATE → Quality Passed?
                          ↓ NO
                      ITERATE (max 25)
                          ↓
                    Back to EXECUTE
```

`VERIFIED_DONE` = plan approved + MUST_HAVE answered + classified + implemented + gates passed + retrospective done

---

## Completion Criteria

| Requirement | Status |
|-------------|--------|
| Smart Memory Search complete | Required |
| Task classified (3 dimensions) | Required |
| MUST_HAVE questions answered | Required |
| Plan approved | Required |
| CORRECTNESS passed (blocking) | Required |
| QUALITY passed (blocking) | Required |
| Retrospective done | Required |

---

## References

| Topic | Documentation |
|-------|---------------|
| Complete Architecture | `ARCHITECTURE_DIAGRAM_v2.52.0.md` |
| Version History | `CHANGELOG.md` |
| Hook Testing | `tests/HOOK_TESTING_PATTERNS.md` |
| Full README | `README.md` |
| Installation | `install.sh` |
| Plan State v2 Schema | `.claude/schemas/plan-state-v2.schema.json` |
| v2.51 Improvements | `.claude/v2.51-improvements-analysis.md` |
| v2.55 Auto-Learning | `~/.claude/hooks/orchestrator-auto-learn.sh` |

---

## Aliases

```bash
rh=ralph rho=orch rhs=security rhb=bugs rhg=gates
mm=mmc mml="mmc --loop 30"
```

---

*Full documentation: See README.md and ARCHITECTURE_DIAGRAM_v2.52.0.md*
