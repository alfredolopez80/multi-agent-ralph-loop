# Multi-Agent-Ralph

![Version](https://img.shields.io/badge/version-2.49.1-blue)
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
│                         RALPH v2.49.1 COMPLETE ARCHITECTURE                  │
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

> **Complete Diagram**: See `ARCHITECTURE_DIAGRAM_v2.49.1.md` for detailed diagrams (Memory Architecture, Hooks Registry, Tools Matrix, Security Pattern)

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

## Hooks (29 Registered)

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
| [`ARCHITECTURE_DIAGRAM_v2.49.1.md`](./ARCHITECTURE_DIAGRAM_v2.49.1.md) | Complete architecture diagrams |
| [`CLAUDE.md`](./CLAUDE.md) | Quick reference (compact) |
| `tests/HOOK_TESTING_PATTERNS.md` | Hook testing patterns |

---

*"Better to fail predictably than succeed unpredictably"* - The Ralph Wiggum Philosophy
