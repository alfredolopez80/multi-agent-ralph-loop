# Multi-Agent-Ralph

![Version](https://img.shields.io/badge/version-2.55.0-blue)
![License](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)

> "Me fail English? That's unpossible!" - Ralph Wiggum

---

## Overview

**Multi-Agent-Ralph** is a sophisticated orchestration system for Claude Code and OpenCode that coordinates multiple AI models to deliver high-quality validated code through iterative refinement cycles.

The system addresses the fundamental challenge of AI-assisted programming: **ensuring quality and consistency in complex tasks**. Instead of relying on a single AI model's output, Ralph orchestrates multiple specialized agents working in parallel, with automatic validation gates and adversarial debates for rigorous requirements.

### What It Does

- **Orchestrates Multiple AI Models**: Coordinates Claude (Opus/Sonnet), OpenAI Codex, Google Gemini, and MiniMax in parallel workflows
- **Iterative Refinement**: Implements the "Ralph Loop" pattern - execute, validate, iterate until quality gates pass
- **Quality Assurance**: Quality gates in 9 languages (TypeScript, Python, Go, Rust, Solidity, Swift, JSON, YAML, JavaScript)
- **Adversarial Specification Refinement**: Adversarial debate to harden specifications before execution
- **Automatic Context Preservation**: 100% automatic ledger/handoff system preserves session state (v2.35)
- **Self-Improvement**: Retrospective analysis after each task to propose workflow improvements
- **Autonomous Learning (v2.55)**: Proactively learns from quality repositories when knowledge gaps detected

### v2.55: Autonomous Self-Improvement

```bash
# Memory system health check
ralph health              # Full report
ralph health --compact    # One-line: 🏥 HEALTH: 7/9 OK, 1 WARN, 1 CRIT

# Auto-triggers when:
# - ZERO relevant rules for a task domain → CRITICAL, learning REQUIRED
# - <3 rules AND complexity ≥7 → HIGH, learning RECOMMENDED
```

**Auto-Learning Hooks**:
| Hook | Trigger | Purpose |
|------|---------|---------|
| `orchestrator-auto-learn.sh` | PreToolUse (Task) | Detects knowledge gaps, recommends `/curator` |
| `agent-memory-auto-init.sh` | PreToolUse (Task) | Auto-initializes agent memory buffers |
| `semantic-auto-extractor.sh` | Stop | Extracts facts from git diff |
| `decision-extractor.sh` | PostToolUse | Detects architectural patterns |

### Why Use It

| Challenge | Ralph Solution |
|-----------|----------------|
| AI output varies in quality | Multi-model debate via adversarial-spec |
| Single step often insufficient | Iterative cycles (15-60 iterations) until VERIFIED_DONE |
| Manual review is bottleneck | Automatic quality gates + human on critical decisions |
| Context limits | MiniMax (1M tokens) + Context7 MCP for documentation |
| Context loss on compaction | Automatic ledger/handoff preservation (85-90% token reduction) |
| High API costs | Optimized routing (WebSearch FREE, MiniMax 8%, strategic Opus) |

---

## Architecture

### General System Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RALPH v2.55.0 COMPLETE ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    SESSION LIFECYCLE                                  │   │
│  │   [SessionStart]                                                     │   │
│  │       │                                                               │   │
│  │       ▼                                                               │   │
│  │   ┌──────────────────────────────────────────────────────────────┐   │   │
│  │   │           SMART MEMORY SEARCH (PARALLEL) v2.47                │   │   │
│  │   │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐    │   │   │
│  │   │  │claude-mem │ │  memvid   │ │ handoffs  │ │  ledgers  │    │   │   │
│  │   │  │  (MCP)    │ │  (HNSW)   │ │ (30 days) │ │CONTINUITY │    │   │   │
│  │   │  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘    │   │   │
│  │   │        │ PARALLEL    │ PARALLEL    │ PARALLEL    │ PARALLEL  │   │   │
│  │   │        └─────────────┴─────────────┴─────────────┘           │   │   │
│  │   │                            │                                    │   │   │
│  │   │                            ▼                                    │   │   │
│  │   │                   ┌─────────────────┐                          │   │   │
│  │   │                   │   MEMORY CONTEXT │                          │   │   │
│  │   │                   └─────────────────┘                          │   │   │
│  │   └──────────────────────────────────────────────────────────────┘   │   │
│  │                                    │                                  │   │
│  │                                    ▼                                  │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │              ORCHESTRATOR WORKFLOW (12 Steps) v2.46             │  │   │
│  │  │                                                               │  │   │
│  │  │  0.EVALUATE ───► 1.CLARIFY ───► 2.CLASSIFY ───► 3.PLAN ───►   │  │   │
│  │  │       │                │               │              │        │  │   │
│  │  │       │                │               │              │        │  │   │
│  │  │       │                │               │              ▼        │  │   │
│  │  │       │                │               │      ┌────────────┐   │  │   │
│  │  │       │                │               │      │   Claude   │   │  │   │
│  │  │       │                │               │      │    Code    │   │  │   │
│  │  │       │                │               │      │  Plan Mode │   │  │   │
│  │  │       │                │               │      └────────────┘   │  │   │
│  │  │       │                │               │              │        │  │   │
│  │  │       ▼                ▼               ▼              ▼        │  │   │
│  │  │  ┌────────────────────────────────────────────────────────────────┐│  │   │
│  │  │  │              EXECUTE-WITH-SYNC (Nested Loop)                   ││  │   │
│  │  │  │  LSA-VERIFY ──► IMPLEMENT ──► PLAN-SYNC ──► MICRO-GATE        ││  │   │
│  │  │  └────────────────────────────────────────────────────────────────┘│  │   │
│  │  │                                    │                               │  │   │
│  │  │                                    ▼                               │  │   │
│  │  │  ┌───────────────────────────────────────────────────────────────┐│  │   │
│  │  │  │              VALIDATE (Multi-Stage)                           ││  │   │
│  │  │  │  CORRECTNESS ──► QUALITY ──► CONSISTENCY ──► ADVERSARIAL     ││  │   │
│  │  │  │       [BLOCKING]      [BLOCKING]     [ADVISORY]   [if >= 7]   ││  │   │
│  │  │  └───────────────────────────────────────────────────────────────┘│  │   │
│  │  │                                    │                               │  │   │
│  │  │                         ┌──────────┴──────────┐                    │  │   │
│  │  │                         │                     │                     │  │   │
│  │  │                         ▼                     ▼                     │  │   │
│  │  │                  ┌─────────────┐      ┌─────────────┐              │  │   │
│  │  │                  │ITERATE LOOP │      │ VERIFIED_   │              │  │   │
│  │  │                  │  (max 25)   │      │    DONE     │              │  │   │
│  │  │                  └─────────────┘      └─────────────┘              │  │   │
│  │  └────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                             │
│  └─────────────────────────────────────────────────────────────────────────────┘
```

> **Complete Diagram**: See `ARCHITECTURE_DIAGRAM_v2.52.0.md` for detailed diagrams (Memory Architecture, Hooks Registry, Tools Matrix, Security Pattern)

### Automatic Feedback Loop (Background Processing)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              AUTOMATIC FEEDBACK LOOP (v2.49) - Background Process          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         ACTIVE SESSION                               │   │
│   │   User ──▶ Task ──▶ Execute ──▶ Validate ──▶ VERIFIED_DONE         │   │
│   │                         │                                            │   │
│   │                         ▼                                            │   │
│   │              ┌─────────────────────────┐                            │   │
│   │              │   Session Transcript    │                            │   │
│   │              │   (Auto-saved)          │                            │   │
│   │              └───────────┬─────────────┘                            │   │
│   └──────────────────────────┼──────────────────────────────────────────┘   │
│                              │                                               │
│                              ▼ (Stop Event)                                  │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                    BACKGROUND PROCESS (Async)                       │   │
│   │                                                                     │   │
│   │   ┌─────────────────────────────────────────────────────────────┐   │   │
│   │   │              reflection-engine.sh (Triggered)               │   │   │
│   │   │                        │                                     │   │   │
│   │   │                        ▼                                     │   │   │
│   │   │              ┌─────────────────────────┐                    │   │   │
│   │   │              │   reflection-executor.py │                    │   │   │
│   │   │              └───────────┬─────────────┘                    │   │   │
│   │   │                          │                                   │   │   │
│   │   │         ┌────────────────┼────────────────┐                  │   │   │
│   │   │         ▼                ▼                ▼                  │   │   │
│   │   │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐         │   │   │
│   │   │  │ Extract      │ │ Detect       │ │ Generate     │         │   │   │
│   │   │  │ Episodes     │ │ Patterns     │ │ Rules        │         │   │   │
│   │   │  │ from Transcript│ │ Across Sessions │ │ (confidence ≥0.8) │    │   │   │
│   │   │  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘         │   │   │
│   │   │         │                │                │                  │   │   │
│   │   │         └────────────────┼────────────────┘                  │   │   │
│   │   │                          │                                   │   │   │
│   │   │                          ▼                                   │   │   │
│   │   │              ┌─────────────────────────────────┐             │   │   │
│   │   │              │    PROCEDURAL MEMORY UPDATE     │             │   │   │
│   │   │              │  ~/.ralph/procedural/rules.json │             │   │   │
│   │   │              └─────────────────────────────────┘             │   │   │
│   │   └─────────────────────────────────────────────────────────────┘   │   │
│   │                              │                                       │
│   │                              ▼ (Next Session)                       │
│   │   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │   │              PROCEDURAL INJECTION (PreToolUse Task)               │   │
│   │   │                                                                     │   │
│   │   │   Task Hook ──▶ Match rule.trigger ──▶ Inject as additionalContext │   │
│   │   │                                                                     │   │
│   │   │   Claude Receives: "Based on past experience: [learned behavior]"  │   │
│   │   └─────────────────────────────────────────────────────────────────────┘   │
│   │                                                                              │
│   └─────────────────────────────────────────────────────────────────────────────┘
```

**Key Components**:
| Component | Trigger | Purpose |
|-----------|---------|---------|
| `reflection-engine.sh` | Stop event | Trigger async reflection |
| `reflection-executor.py` | After session | Extract episodes, detect patterns, generate rules |
| `procedural-inject.sh` | PreToolUse (Task) | Inject learned behaviors into task context |

---

## Main Workflow

### 1. The Ralph Loop Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH LOOP PATTERN                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────┐    ┌──────────────┐    ┌─────────────────┐      │
│   │ EXECUTE  │───▶│   VALIDATE   │───▶│ Quality Passed? │      │
│   │   Task   │    │ (hooks/gates)│    └────────┬────────┘      │
│   └──────────┘    └──────────────┘             │               │
│                                          NO ◀──┴──▶ YES        │
│                                           │         │          │
│                          ┌────────────────┘         │          │
│                          ▼                          ▼          │
│                   ┌─────────────┐          ┌──────────────┐    │
│                   │  ITERATE    │          │ VERIFIED_DONE│    │
│                   │(max 25/50)  │          │   (output)   │    │
│                   └──────┬──────┘          └──────────────┘    │
│                          │                                     │
│                          └──────────▶ Back to EXECUTE          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Complete Orchestration Flow (12 Steps)

```
0. EVALUATE    → Quick classification (trivial?)
1. CLARIFY     → AskUserQuestion (MUST_HAVE/NICE_TO_HAVE)
2. CLASSIFY    → task-classifier (complexity 1-10)
3. PLAN        → Detailed design
4. PLAN MODE   → EnterPlanMode (reads analysis)
5. DELEGATE    → Route to optimal model
6. EXECUTE-WITH-SYNC → Nested loop per step:
   6a. LSA-VERIFY  → Architecture pre-check
   6b. IMPLEMENT   → Execute step
   6c. PLAN-SYNC   → Detect drift
   6d. MICRO-GATE  → Per-step quality (3-fix rule)
7. VALIDATE    → Multi-stage validation:
   7a. QUALITY-AUDITOR → Pragmatic audit
   7b. GATES → Quality gates (9 languages)
   7c. ADVERSARIAL-SPEC → Specification refinement
   7d. ADVERSARIAL-PLAN → Opus+Codex cross-validation
8. RETROSPECT  → Self-improvement
```

---

## Key Features

### Multi-Agent Orchestration

| Feature | Description |
|----------------|-------------|
| **14 Specialized Agents** | 9 core + 5 auxiliary review |
| **12-Step Workflow** | Evaluate → Clarify → Plan → Execute → Validate |
| **Parallel Execution** | Multiple agents work simultaneously |
| **Model Routing** | Automatic selection: Opus (critical), Sonnet (standard), MiniMax (extended) |

**Core Agents (9)**:
`orchestrator`, `security-auditor`, `code-reviewer`, `test-architect`, `debugger`, `refactorer`, `docs-writer`, `frontend-reviewer`, `minimax-reviewer`

### Smart Memory (v2.49)

```
SMART MEMORY SEARCH (PARALLEL)
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│claude-mem│ │ memvid   │ │ handoffs │ │  ledgers │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │ PARALLEL   │ PARALLEL   │ PARALLEL   │ PARALLEL
     └────────────┴────────────┴────────────┘
                    ↓
         .claude/memory-context.json
```

**Three Memory Types**:
| Type | Purpose | Storage |
|------|---------|----------------|
| **Semantic** | Facts, preferences | `~/.ralph/memory/semantic.json` |
| **Episodic** | Experiences (30-day TTL) | `~/.ralph/episodes/` |
| **Procedural** | Learned behaviors | `~/.ralph/procedural/rules.json` |

### Repository Learner (v2.50) - NEW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    REPOSITORY LEARNER (v2.50)                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   /repo-learn https://github.com/{owner}/{repo}                            │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                     5-PHASE WORKFLOW                                 │   │
│   │                                                                     │   │
│   │   1. ACQUIRE → Clone repo or fetch via GitHub API                   │   │
│   │   2. ANALYZE → AST-based pattern extraction (Python, TS, Rust, Go)  │   │
│   │   3. CLASSIFY → Categorize patterns:                                 │   │
│   │      • error_handling     • type_safety      • async_patterns        │   │
│   │      • architecture        • testing          • security             │   │
│   │   4. GENERATE → Procedural rules with confidence scores             │   │
│   │   5. ENRICH → Atomic write to ~/.ralph/procedural/rules.json        │   │
│   │                                                                     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Result: Claude learns best practices from quality repositories            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Usage**:
```bash
# Learn from a repository
/repo-learn https://github.com/python/cpython

# Focus on specific pattern categories
/repo-learn https://github.com/tiangolo/fastapi --category error_handling

# Set minimum confidence threshold
/repo-learn https://github.com/facebook/react --category security --min-confidence 0.9
```

**Output**:
```
Repository: https://github.com/org/repo
Files Analyzed: 150
Patterns Extracted: 45
Rules Generated: 32
Added to Procedural Memory: 28 rules

Claude will now consider learned patterns when:
- Implementing error handling
- Writing async code
- Designing architecture
- Writing tests
```

**Security**: Read-only analysis, atomic writes with backup, validated rules.

### Repo Curator (v2.55)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       REPO CURATOR (v2.55)                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   /curator "best backend TypeScript repos with clean architecture"         │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                     5-PHASE WORKFLOW                                 │   │
│   │                                                                     │   │
│   │   1. DISCOVERY → GitHub API search (100-500 candidates)             │   │
│   │   2. SCORING   → QualityScore + Context Relevance (v2.55)           │   │
│   │   3. RANKING   → Top N (configurable, max per org)                  │   │
│   │   4. REVIEW    → User approves/rejects repos                        │   │
│   │   5. LEARN     → repository-learner extracts patterns               │   │
│   │                                                                     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Pricing Tiers:                                                            │
│   ┌──────────┬─────────┬────────────────────────────────────┐              │
│   │ TIER     │ COST    │ FEATURES                           │              │
│   ├──────────┼─────────┼────────────────────────────────────┤              │
│   │ free     │ $0.00   │ GitHub API + local scoring         │              │
│   │ economic │ ~$0.30  │ + OpenSSF + MiniMax (DEFAULT)      │              │
│   │ full     │ ~$0.95  │ + Claude + Codex (with fallback)   │              │
│   └──────────┴─────────┴────────────────────────────────────┘              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Scripts & Options (v2.55)**:

| Script | Purpose | Key Options |
|--------|---------|-------------|
| `curator-discovery.sh` | GitHub API search | `--type`, `--lang`, `--query`, `--tier`, `--max-results`, `--output` |
| `curator-scoring.sh` | Quality metrics | `--input`, `--output`, `--tier`, `--context` (v2.55), `--verbose` |
| `curator-rank.sh` | Generate rankings | `--input`, `--output`, `--top-n`, `--max-per-org` |
| `curator-ingest.sh` | Clone to corpus | `--repo`, `--output-dir`, `--approve`, `--source`, `--depth` |
| `curator-approve.sh` | Approve repos | `--repo`, `--all` |
| `curator-reject.sh` | Reject repos | `--repo`, `--reason` |
| `curator-learn.sh` | Extract patterns | `--type`, `--lang`, `--repo`, `--all` |
| `curator-queue.sh` | View queue status | `--type`, `--lang` |

**Usage**:
```bash
# Full pipeline (economic tier - default)
/curator full --type backend --lang typescript

# Discovery with custom query and max results
/curator discovery --query "enterprise microservice" --max-results 200 --tier free

# Scoring with context relevance (v2.55 NEW)
/curator scoring --input candidates.json --output scored.json --context "error handling,retry,resilience"

# Ranking with custom limits
/curator rank --input scored.json --output ranking.json --top-n 15 --max-per-org 3

# Show ranking
/curator show --type backend --lang typescript

# Review queue
/curator pending --type backend --lang typescript

# Approve/reject repos
/curator approve nestjs/nest
/curator approve --all
/curator reject some/repo --reason "Low test coverage"

# Ingest with source attribution
/curator ingest --repo prisma/prisma --approve --source "enterprise-db-patterns"

# Execute learning
/curator learn --type backend --lang typescript
/curator learn --repo nestjs/nest
/curator learn --all
```

**Context Relevance Scoring (v2.55 NEW)**:
```bash
# Repos are scored on relevance to your context keywords:
# +3 points if description contains context keywords
# +2 points if repo name contains context keywords
# -1 point if no description or irrelevant description

/curator scoring --context "error handling,retry,circuit breaker"
```

**Full Pipeline Example (Step-by-Step)**:

```bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                    CURATOR FULL PIPELINE EXAMPLE                              ║
# ║                                                                               ║
# ║  Goal: Find best TypeScript backend repos for learning error handling        ║
# ║  patterns in microservices architecture                                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ STEP 1: DISCOVERY - Search GitHub for candidate repositories                │
# │                                                                             │
# │ Parameters:                                                                 │
# │   --type backend      → Filter: backend applications (not frontend/CLI)    │
# │   --lang typescript   → Filter: TypeScript language only                   │
# │   --query "..."       → Custom search: microservices with error handling   │
# │   --tier economic     → Pricing: ~$0.30 (uses MiniMax for validation)      │
# │   --max-results 150   → Limit: fetch up to 150 candidates                  │
# │   --output file.json  → Output: save results to specific file              │
# └─────────────────────────────────────────────────────────────────────────────┘

ralph curator discovery \
  --type backend \
  --lang typescript \
  --query "microservice error handling resilience" \
  --tier economic \
  --max-results 150 \
  --output ~/.ralph/curator/candidates/backend_ts_errors.json

# Output: ~/.ralph/curator/candidates/backend_ts_errors.json (150 repos)

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ STEP 2: SCORING - Calculate quality score for each repository              │
# │                                                                             │
# │ Parameters:                                                                 │
# │   --input file.json   → Input: candidates from discovery step              │
# │   --output file.json  → Output: scored repositories                        │
# │   --tier economic     → Pricing tier for external validations              │
# │   --context "..."     → NEW v2.55: Keywords for relevance scoring          │
# │   --verbose           → Show detailed scoring breakdown                    │
# │                                                                             │
# │ Scoring Formula:                                                            │
# │   QualityScore = stars(30%) + tests(25%) + CI/CD(20%) + docs(15%) + activity(10%)  │
# │   + ContextRelevance: +3 (description match) +2 (name match) -1 (irrelevant)       │
# └─────────────────────────────────────────────────────────────────────────────┘

ralph curator scoring \
  --input ~/.ralph/curator/candidates/backend_ts_errors.json \
  --output ~/.ralph/curator/scored/backend_ts_errors_scored.json \
  --tier economic \
  --context "error handling,retry,circuit breaker,resilience,fault tolerance" \
  --verbose

# Output: Each repo now has QualityScore (0-100) + ContextRelevance bonus

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ STEP 3: RANKING - Select top repositories with diversity constraints       │
# │                                                                             │
# │ Parameters:                                                                 │
# │   --input file.json   → Input: scored repositories                         │
# │   --output file.json  → Output: final ranking                              │
# │   --top-n 10          → Limit: select top 10 repositories                  │
# │   --max-per-org 2     → Diversity: max 2 repos per organization            │
# │                        (prevents nestjs/nest, nestjs/config, nestjs/cli    │
# │                         from dominating the list)                          │
# └─────────────────────────────────────────────────────────────────────────────┘

ralph curator rank \
  --input ~/.ralph/curator/scored/backend_ts_errors_scored.json \
  --output ~/.ralph/curator/rankings/backend_ts_errors_ranking.json \
  --top-n 10 \
  --max-per-org 2

# Output: Top 10 repos, max 2 per organization, sorted by QualityScore

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ STEP 4: REVIEW - Show ranking and manage approval queue                    │
# └─────────────────────────────────────────────────────────────────────────────┘

# View the ranking
ralph curator show --type backend --lang typescript

# View pending repos in queue
ralph curator pending --type backend --lang typescript

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ STEP 5: APPROVE/REJECT - User decides which repos to learn from            │
# │                                                                             │
# │ Approve options:                                                            │
# │   --repo owner/name   → Approve specific repository                        │
# │   --all               → Approve all staged repositories                    │
# │                                                                             │
# │ Reject options:                                                             │
# │   --repo owner/name   → Reject specific repository                         │
# │   --reason "..."      → Document why (for future reference)                │
# └─────────────────────────────────────────────────────────────────────────────┘

# Approve high-quality repos
ralph curator approve --repo nestjs/nest
ralph curator approve --repo prisma/prisma
ralph curator approve --repo trpc/trpc

# Reject with reason (documented for future reference)
ralph curator reject --repo some/low-quality --reason "No tests, outdated dependencies"

# Or approve all at once
ralph curator approve --all

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ STEP 6: INGEST - Clone approved repos to local corpus                      │
# │                                                                             │
# │ Parameters:                                                                 │
# │   --repo owner/name   → Repository to clone                                │
# │   --output-dir path   → Custom output directory                            │
# │   --approve           → Skip staging, go directly to approved              │
# │   --source "label"    → Attribution label for generated rules              │
# │   --depth 1           → Shallow clone (faster, less disk space)            │
# └─────────────────────────────────────────────────────────────────────────────┘

ralph curator ingest \
  --repo nestjs/nest \
  --approve \
  --source "enterprise-typescript-patterns" \
  --depth 1

# Output: Repo cloned to ~/.ralph/curator/corpus/approved/nestjs_nest/

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ STEP 7: LEARN - Extract patterns and update procedural memory              │
# │                                                                             │
# │ Parameters:                                                                 │
# │   --type backend      → Filter by type                                     │
# │   --lang typescript   → Filter by language                                 │
# │   --repo owner/name   → Learn from specific repository                     │
# │   --all               → Learn from ALL approved repositories               │
# │                                                                             │
# │ Output: Rules added to ~/.ralph/procedural/rules.json                      │
# │         Each rule has source_repo attribution for traceability             │
# └─────────────────────────────────────────────────────────────────────────────┘

# Learn from specific repo
ralph curator learn --repo nestjs/nest

# Or learn from all approved repos
ralph curator learn --all

# Or filter by type/language
ralph curator learn --type backend --lang typescript

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                           RESULT                                             ║
# ║                                                                               ║
# ║  Procedural Memory Updated:                                                   ║
# ║  ~/.ralph/procedural/rules.json                                               ║
# ║                                                                               ║
# ║  Example rule generated:                                                      ║
# ║  {                                                                            ║
# ║    "rule_id": "repo-nestjs-1705789234",                                       ║
# ║    "source_repo": "nestjs/nest",                                              ║
# ║    "trigger": "dependency-injection",                                         ║
# ║    "behavior": "Use constructor injection with @Injectable() decorator",      ║
# ║    "confidence": 0.92,                                                        ║
# ║    "category": "architecture"                                                 ║
# ║  }                                                                            ║
# ║                                                                               ║
# ║  Now Ralph will apply these patterns in future implementations!               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
```

### Codex Planner (v2.50) - NEW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       CODEX PLANNER (v2.50)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   /codex-plan "Design a distributed caching system"                        │
│   /orchestrator "Implement microservices" --use-codex                      │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                     3-PHASE WORKFLOW                                 │   │
│   │                                                                     │   │
│   │   1. CLARIFY → AskUser questions (MUST_HAVE + NICE_TO_HAVE)         │   │
│   │   2. EXECUTE → Codex 5.2 with `xhigh` reasoning depth               │   │
│   │   3. SAVE → Plan saved to `http://codex-plan.md`                    │   │
│   │                                                                     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Requirements:                                                             │
│   • Codex CLI: npm install -g @openai/codex                                │
│   • Access to gpt-5.2-codex model                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Usage**:
```bash
# Direct Codex planning
/codex-plan "Design a distributed caching system"

# Orchestrator with Codex for complex planning
/orchestrator "Implement microservices architecture" --use-codex
/orchestrator "Design event-driven system" --codex
```

### Command Synchronization (v2.50) - NEW

Ralph maintains **bidirectional synchronization** between Claude Code and OpenCode:

```
~/.claude/commands/  ←→  ~/.config/opencode/command/
```

**Features**:
- **Automatic Sync**: New commands are automatically synced to both platforms
- **Format Validation**: YAML frontmatter with VERSION headers required
- **20 Unit Tests**: Verify sync integrity, format compliance, and integration

**Scripts**:
- `~/.claude/scripts/sync-commands.sh` - Verification and sync utility
- `~/.claude/scripts/fix-command-format.sh` - Auto-fix format issues

**Test Suite** (`tests/test_command_sync.py`):
```bash
# Run all sync tests
python -m pytest tests/test_command_sync.py -v

# All 20 tests passing
# ✓ Sync verification
# ✓ Version headers
# ✓ Frontmatter format
# ✓ Curator integration
# ✓ Auto-sync integration
```

### Local Observability (v2.52) - NEW

Zero-dependency observability using local files:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      LOCAL OBSERVABILITY (v2.52)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   LAYER 1: StatusLine (Passive)                                            │
│   ──────────────────────────────                                           │
│   ⎇ main* │ 📊 3/7 42% │ [claude-hud metrics]                              │
│                                                                              │
│   LAYER 2: ralph status (On-Demand)                                        │
│   ─────────────────────────────────                                        │
│   $ ralph status --compact                                                 │
│   📊 STANDARD Step 3/7 (42%) - Implementing OAuth2                         │
│                                                                              │
│   $ ralph status --steps                                                   │
│   ┌────────────────────────────────────────┐                               │
│   │ ✅ CLARIFY    ✅ CLASSIFY  ✅ PLAN     │                               │
│   │ 🔄 EXECUTE    ⏳ VALIDATE  ⏳ RETROSPECT│                               │
│   └────────────────────────────────────────┘                               │
│                                                                              │
│   LAYER 3: ralph trace (Historical)                                        │
│   ──────────────────────────────────                                       │
│   $ ralph trace show                  # Recent events                      │
│   $ ralph trace search "checkpoint"   # Search events                      │
│   $ ralph trace timeline              # Visual timeline                    │
│   $ ralph trace export json           # Export for analysis                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Data Sources** (all local, no external dependencies):
- `.claude/plan-state.json` - Current orchestration state
- `~/.ralph/events/event-log.jsonl` - Event bus history
- `~/.ralph/checkpoints/` - Checkpoint snapshots
- `~/.ralph/agent-memory/` - Agent-scoped memory buffers

### Quality-First Validation (v2.46)

```
Stage 1: CORRECTNESS  → Syntax errors (BLOCKING)
Stage 2: QUALITY      → Type errors (BLOCKING)
Stage 2.5: SECURITY   → semgrep + gitleaks (BLOCKING)
Stage 3: CONSISTENCY  → Linting (ADVISORY - not blocking)
```

### 3-Dimension Classification (RLM)

| Dimension | Values |
|-----------|---------|
| **Complexity** | 1-10 |
| **Information Density** | CONSTANT / LINEAR / QUADRATIC |
| **Context Requirement** | FITS / CHUNKED / RECURSIVE |

---

## Quick Installation

```bash
# Clone repository
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Install
chmod +x install.sh
./install.sh
source ~/.zshrc

# Verify
ralph integrations
```

### Requirements

| Tool | Required | Purpose |
|-------------|-----------|-----------|
| Claude CLI | Yes | Base orchestration |
| jq | Yes | JSON processing |
| git | Yes | Version control |
| GitHub CLI | For PRs | PR creation/review |

---

## Essential Commands

```bash
# Orchestration
/orchestrator "Implement OAuth2 with Google"
ralph orch "task"              # Full orchestration
ralph loop "fix errors"        # Loop until VERIFIED_DONE
/clarify                       # Intensive clarification

# Quality
/gates                         # Quality gates
/adversarial                   # Specification refinement

# Memory (v2.49)
ralph memory-search "query"    # Parallel search
ralph fork-suggest "task"      # Suggest sessions

# Repository Learning (v2.50)
/repo-learn https://github.com/python/cpython          # Learn from repo
/repo-learn https://github.com/fastapi/fastapi --category error_handling

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
/codex-plan "Design distributed system"               # Codex planning
/orchestrator "task" --use-codex                      # Orchestrator with Codex

# Security
ralph security src/            # Security audit
ralph security-loop src/       # Iterative audit

# Git Worktree
ralph worktree "feature"       # Create isolated worktree
ralph worktree-pr <branch>     # PR with review

# Context
ralph ledger save              # Save session state
ralph handoff create           # Create handoff
ralph compact                  # Manual save (extensions)

# Local Observability (v2.52)
ralph status                   # Full orchestration status
ralph status --compact         # One-line: 📊 STANDARD Step 3/7 (42%)
ralph status --steps           # Step-by-step breakdown
ralph status --json            # JSON output for scripts

ralph trace show               # Recent events (last 50)
ralph trace search "error"     # Search events
ralph trace timeline           # Visual timeline
ralph trace export json        # Export to JSON/CSV
ralph trace summary            # Event statistics
```

---

## Model Architecture

```
┌────────────────────────────────────────────────────────────┐
│  PRIMARY (Sonnet manages)  │  SECONDARY (8% cost)         │
├────────────────────────────┼───────────────────────────────┤
│  Claude Opus/Sonnet        │  MiniMax M2.1                │
│  Codex GPT-5               │  (Second opinion)            │
│  Gemini 2.5 Pro            │  (Independent validation)    │
├────────────────────────────┼───────────────────────────────┤
│  Implementation            │  Validation                  │
│  Testing                   │  Catch missed issues         │
│  Documentation             │  Opus quality at 8% cost     │
└────────────────────────────┴───────────────────────────────┘
```

### Cost Optimization

| Model | Max Iterations | Cost vs Claude | Use Case |
|--------|-----------------|-----------------|----------|
| Claude Opus | 25 | 100% | Critical review, architecture |
| Claude Sonnet | 25 | 60% | Standard implementation |
| MiniMax M2.1 | 50 | 8% | Extended loops, second opinion |
| MiniMax-lightning | 100 | 4% | Very long tasks |

---

## Hooks (38 Registered)

| Event Type | Purpose |
|-------------|-----------|
| SessionStart | Context preservation at startup |
| PreCompact | Save state before compaction |
| PostToolUse | Quality gates after Edit/Write |
| PreToolUse | Security guards before Bash/Skill |
| UserPromptSubmit | Context warnings, reminders |
| Stop | Session reports |

---

## Additional Documentation

| Document | Purpose |
|-----------|-----------|
| [`CHANGELOG.md`](./CHANGELOG.md) | **Complete version history** (best practices) |
| [`ARCHITECTURE_DIAGRAM_v2.52.0.md`](./ARCHITECTURE_DIAGRAM_v2.52.0.md) | Complete architecture diagrams |
| [`CLAUDE.md`](./CLAUDE.md) | Quick reference (compact) |
| `tests/HOOK_TESTING_PATTERNS.md` | Hook testing patterns |

---

*"Better to fail predictably than succeed unpredictably"* - The Ralph Wiggum Philosophy
