# Multi-Agent Ralph Wiggum v2.58.0

![Version](https://img.shields.io/badge/version-2.58.0-blue)
![License](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)
![Tests](https://img.shields.io/badge/tests-103%20passed-green)
![Hooks](https://img.shields.io/badge/hooks-53%20registered-orange)
![Skills](https://img.shields.io/badge/skills-25%2B-orange)

> "Me fail English? That's unpossible!" - Ralph Wiggum

---

## Table of Contents

1. [Overview](#overview)
2. [What It Does](#what-it-does)
3. [Tech Stack](#tech-stack)
4. [Prerequisites](#prerequisites)
5. [Getting Started](#getting-started)
6. [Architecture](#architecture)
7. [Key Features](#key-features)
8. [Commands Reference](#commands-reference)
9. [Hooks System](#hooks-system)
10. [Testing](#testing)
11. [Deployment](#deployment)
12. [Troubleshooting](#troubleshooting)
13. [Contributing](#contributing)
14. [License](#license)

---

## Overview

**Multi-Agent Ralph Wiggum** is a sophisticated orchestration system for Claude Code and OpenCode that coordinates multiple AI models to deliver high-quality validated code through iterative refinement cycles.

The system addresses the fundamental challenge of AI-assisted programming: **ensuring quality and consistency in complex tasks**. Instead of relying on a single AI model's output, Ralph orchestrates multiple specialized agents working in parallel, with automatic validation gates and adversarial debates for rigorous requirements.

### What It Does

- **Orchestrates Multiple AI Models**: Coordinates Claude (Opus/Sonnet), OpenAI Codex, Google Gemini, and MiniMax in parallel workflows
- **Iterative Refinement**: Implements the "Ralph Loop" pattern - execute, validate, iterate until quality gates pass
- **Quality Assurance**: Quality gates in 9 languages (TypeScript, Python, Go, Rust, Solidity, Swift, JSON, YAML, JavaScript)
- **Adversarial Specification Refinement**: Adversarial debate to harden specifications before execution
- **Automatic Context Preservation**: 100% automatic ledger/handoff system preserves session state (v2.35)
- **Self-Improvement**: Retrospective analysis after each task to propose workflow improvements
- **Autonomous Learning (v2.55)**: Proactively learns from quality repositories when knowledge gaps detected
- **Automated Monitoring (v2.56)**: Smart checkpoints, status monitoring, and health checks via hooks
- **Memory System Reconstruction (v2.57)**: Fixed 8 critical bugs in memory search, plan-state sync, and context injection
- **Claude Code Skills Ecosystem**: 25+ specialized skills including marketing (23 skills), documentation generation, and React best practices from Vercel

---

## Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Base Platform** | Claude Code CLI | AI orchestration engine |
| **Shell Environment** | Bash 5.x + zsh | Hooks automation |
| **Python** | 3.11+ | Utilities and tooling |
| **Memory System** | claude-mem MCP + SQLite FTS | Semantic/episodic/procedural memory |
| **Model Routing** | Claude Opus/Sonnet + MiniMax M2.1 + Codex | Multi-model coordination |
| **Validation** | semgrep + gitleaks + ast-grep | Security and quality scanning |
| **Package Management** | uv (Python) | Dependency management |
| **Version Control** | Git + GitHub CLI | Code management and PRs |
| **Skills Ecosystem** | Claude Code Skills + Vercel agent-skills | Specialized task skills |

---

## Prerequisites

### Required Tools

| Tool | Minimum Version | Installation |
|------|-----------------|--------------|
| **Claude Code CLI** | Latest | `brew install claude` or `pipx install claude` |
| **jq** | 1.6+ | `brew install jq` |
| **curl** | Any | Pre-installed on macOS |
| **Git** | 2.0+ | Pre-installed on macOS |
| **Bash** | 5.0+ | `brew install bash` (macOS) |

### Optional but Recommended

| Tool | Purpose | Installation |
|------|---------|--------------|
| **GitHub CLI (gh)** | PR workflow | `brew install gh` |
| **Codex CLI** | Advanced planning | `npm install -g @openai/codex` |
| **MiniMax CLI** | Cost-optimized validation | `uvx minimax-coding-plan-mcp` |
| **uv** | Fast Python package manager | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop
```

### 2. Run the Installer

```bash
# Make executable
chmod +x install.sh

# Run installation (requires sudo for some operations)
./install.sh

# Reload shell to pick up new commands
source ~/.zshrc  # or source ~/.bashrc
```

The installer automatically sets up **5 specialized skills**:
- **Marketing skills** (23 skills from coreyhaines31/marketingskills)
- **Documentation skill** (`/readme` for comprehensive project docs)
- **React Best Practices** (Vercel's official patterns)
- Plus 52 hooks, 14 agents, and all CLI commands

### 3. Verify Installation

```bash
# Check integrations
ralph integrations

# Verify all hooks are registered
ralph health

# Show version
ralph --version
```

### 4. Quick Test

```bash
# Run the test suite
cd tests
./run_tests.sh

# Or run individual test modules
python -m pytest test_memory_v2_49.py -v
python -m pytest test_command_sync.py -v
```

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RALPH v2.57.0 COMPLETE ARCHITECTURE                  │
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
│  │  │                  └──────┬──────┘      └─────────────┘              │  │   │
│  │  │                         │                                     │  │   │
│  │  │                         └──────────▶ Back to EXECUTE          │  │   │
│  │  └────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                             │
│  └─────────────────────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
multi-agent-ralph-loop/
├── .claude/                    # Claude Code configuration
│   ├── agents/                # 14 specialized AI agents
│   ├── commands/              # Slash commands
│   ├── hooks/                 # 52 event hooks (v2.57.4)
│   ├── scripts/               # Utility scripts
│   ├── skills/                # Claude Code skills (install script only)
│   └── schemas/               # JSON schemas for validation
├── scripts/                   # Main CLI tools
│   ├── ralph                  # Main CLI (331KB shell script)
│   ├── ralph                  # MiniMax CLI wrapper
│   └── *.sh                   # Utility scripts (20+ files)
├── tests/                     # Test suite (74 test files)
│   ├── test_*.py              # Python tests
│   ├── test_*.sh              # Shell tests
│   └── HOOK_TESTING_PATTERNS.md
├── src/                       # Source code
│   └── applications/          # Python applications
├── docs/                      # Documentation
├── .ralph/                    # Ralph runtime data
│   ├── memory/                # Semantic memory
│   ├── episodes/              # Episodic memory (30-day TTL)
│   ├── procedural/            # Procedural rules
│   ├── events/                # Event bus log
│   ├── checkpoints/           # State snapshots
│   ├── curator/               # Repository curator data
│   └── logs/                  # Hook execution logs
├── install.sh                 # Global installer
├── uninstall.sh               # Cleanup script
├── CLAUDE.md                  # Quick reference guide
├── README.md                  # This file
├── CHANGELOG.md               # Version history
├── AGENTS.md                  # Agent documentation
├── ARCHITECTURE_DIAGRAM_v2.52.0.md  # Detailed diagrams
└── TESTING.md                 # Testing guide
```

### Memory Architecture

```
SMART MEMORY SEARCH (PARALLEL)
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│claude-mem│ │ memvid   │ │ handoffs │ │  ledgers │
│  (MCP)   │ │  (HNSW)  │ │ (30d TTL)│ │CONTINUITY│
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │ PARALLEL   │ PARALLEL   │ PARALLEL   │ PARALLEL
     └────────────┴────────────┴────────────┘
                    ↓
         .claude/memory-context.json
```

**Three Memory Types**:

| Type | Purpose | Storage | TTL |
|------|---------|---------|-----|
| **Semantic** | Facts, preferences, learned patterns | `~/.ralph/memory/semantic.json` | Never |
| **Episodic** | Experiences, session transcripts | `~/.ralph/episodes/` | 30 days |
| **Procedural** | Learned behaviors, best practices | `~/.ralph/procedural/rules.json` | Never |

---

## Key Features

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

### 2. 12-Step Orchestration Workflow

| Step | Name | Description |
|------|------|-------------|
| 0 | EVALUATE | Quick classification (trivial tasks → fast-path) |
| 1 | CLARIFY | AskUserQuestion (MUST_HAVE + NICE_TO_HAVE) |
| 2 | CLASSIFY | task-classifier (complexity 1-10 scale) |
| 3 | PLAN | Detailed design with phases and risks |
| 4 | PLAN MODE | EnterPlanMode (reads analysis) |
| 5 | DELEGATE | Route to optimal model (Opus/Sonnet/MiniMax) |
| 6 | EXECUTE-WITH-SYNC | Nested loop: LSA-VERIFY → IMPLEMENT → PLAN-SYNC → MICRO-GATE |
| 7 | VALIDATE | Multi-stage: CORRECTNESS → QUALITY → CONSISTENCY → ADVERSARIAL |
| 8 | RETROSPECT | Self-improvement analysis |

### 3. 3-Dimension Classification (RLM-Inspired)

| Dimension | Values | Purpose |
|-----------|--------|---------|
| **Complexity** | 1-10 | Scope, risk, ambiguity |
| **Information Density** | CONSTANT / LINEAR / QUADRATIC | How answer scales with input |
| **Context Requirement** | FITS / CHUNKED / RECURSIVE | Whether decomposition needed |

**Workflow Routing**:

| Density | Context | Complexity | Route | Max Iter |
|---------|---------|------------|-------|----------|
| CONSTANT | FITS | 1-3 | **FAST_PATH** | 3 |
| CONSTANT | FITS | 4-10 | STANDARD | 25 |
| LINEAR | CHUNKED | ANY | PARALLEL_CHUNKS | 15/chunk |
| QUADRATIC | ANY | ANY | RECURSIVE_DECOMPOSE | 15/sub |

### 4. 14 Specialized Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `orchestrator` | opus | Coordinator, planning, delegation |
| `security-auditor` | opus | Security vulnerabilities, code review |
| `debugger` | opus | Bug detection, error analysis |
| `code-reviewer` | sonnet | Code quality, pattern analysis |
| `test-architect` | sonnet | Test generation, coverage analysis |
| `refactorer` | sonnet | Refactoring, code improvement |
| `frontend-reviewer` | sonnet | UI/UX, accessibility |
| `docs-writer` | minimax | Documentation, README |
| `minimax-reviewer` | minimax | Validation, second opinion |
| `repository-learner` | sonnet | Pattern extraction, rule generation |
| `repo-curator` | sonnet | Repository discovery, scoring |
| `kieran-python-reviewer` | minimax | Python code quality |
| `kieran-typescript-reviewer` | minimax | TypeScript code quality |
| `codex-planner` | codex | Advanced planning with GPT-5.2 |

### 5. Quality-First Validation (v2.46)

```
Stage 1: CORRECTNESS  → Syntax errors (BLOCKING)
Stage 2: QUALITY      → Type errors (BLOCKING)
Stage 2.5: SECURITY   → semgrep + gitleaks (BLOCKING)
Stage 3: CONSISTENCY  → Linting (ADVISORY - not blocking)
```

### 6. Claude Code Skills Ecosystem (v2.57)

Ralph includes a comprehensive **Claude Code Skills** ecosystem for specialized tasks:

| Skill Category | Count | Purpose |
|----------------|-------|---------|
| **Marketing Skills** | 23 | Copywriting, positioning, pricing, channels, messaging, funnel, CRO, analytics, branding, email, content, SEO, social, paid ads, partnerships, product, launch, retention, community, conversion, strategy, research |
| **Documentation** | 1 | `/readme` - Comprehensive project documentation generation |
| **React Best Practices** | 1 | Vercel's official React patterns and best practices |

#### Marketing Skills Available

```
├── ab-test-setup/              # A/B testing configuration
├── brand-positioning/          # Brand strategy and positioning
├── channel-strategy/           # Distribution channel planning
├── content-marketing/          # Content strategy and creation
├── conversion-optimization/    # CRO and funnel optimization
├── copywriting/                # Persuasive copy writing
├── crm-setup/                  # Customer relationship management
├── email-marketing/            # Email campaign strategy
├── funnel-design/              # Marketing funnel architecture
├── go-to-market/               # Product launch strategy
├── keyword-research/           # SEO keyword analysis
├── landing-page-copy/          # High-converting landing pages
├── market-research/            # Market analysis and research
├── messaging-framework/        # Value proposition crafting
├── partnerships/               # Strategic partnership development
├── pricing-strategy/           # Product pricing models
├── product-marketing/          # Product positioning and messaging
├── paid-advertising/           # Digital ads optimization
├── seo-optimization/           # Search engine optimization
├── social-media/               # Social media strategy
├── strategy-roadmap/           # Marketing strategy planning
├── user-research/              # User persona development
└── analytics-setup/            # Marketing analytics configuration
```

#### Documentation Skill

The `/readme` skill generates comprehensive project documentation:

```bash
# Generate comprehensive README
/readme "Create documentation for my project"

/readme "Update existing README with new features"
```

**Features**:
- Automatic table of contents generation
- Code example formatting
- Architecture diagram integration
- Multi-language support (English/Spanish)
- Badge and metadata inclusion

#### Vercel React Best Practices Skill

Ralph automatically installs **Vercel's official React Best Practices** skill:

```bash
/react-best-practices "How should I structure my React components?"
/react-best-practices "Best patterns for custom hooks"
```

**Covers**:
- Component design (composition, small focused components)
- React hooks (functional updates, useEffect, custom hooks)
- Performance optimization (useMemo, useCallback, lazy loading)
- State management (appropriate strategies, context)
- Error handling (error boundaries)
- TypeScript integration
- Accessibility (semantic HTML, ARIA)
- Server Components for Next.js

---

### 7. Sec-Context Security Hook (v1.0.3)

Ralph includes a **security quality gate hook** that automatically detects critical security vulnerabilities:

| Pattern | Severity | Priority |
|---------|----------|----------|
| Hardcoded Secrets (API keys, passwords) | Critical | 23 |
| SQL Injection (string concatenation) | High | 22 |
| XSS (innerHTML without sanitization) | Critical | 23 |
| Command Injection (os.system, subprocess) | High | 22 |
| JWT None Algorithm | High | 22 |
| Weak Cryptography (MD5, SHA1, ECB) | High | 20 |
| Insecure Random (Math.random) | Medium | 18 |

#### Hook Behavior

```
┌─────────────────────────────────────────────────────────────────┐
│              SEC-CONTEXT VALIDATE HOOK                          │
├─────────────────────────────────────────────────────────────────┤
│  Trigger: PostToolUse (Edit/Write)                             │
│  Timeout: 60 seconds | Max File: 10MB                          │
│                                                                 │
│  Edit/Write → Pattern Scan (7 patterns) → Issues?              │
│                                          NO ──→ Log: OK        │
│                                          YES ──→ Report + Alert│
│  Log: ~/.ralph/logs/sec-context-YYYYMMDD.log                   │
└─────────────────────────────────────────────────────────────────┘
```

#### Installation & Testing

```bash
# Run test suite (16 tests)
bash ~/.claude/hooks/test-sec-context-hook.sh
# Result: 16/16 tests passed
```

#### Sec-Context Depth Skill

AI-powered security analysis:

```bash
/sec-context-depth "Review my authentication module"
```

---

## Commands Reference

### Core Orchestration

```bash
# Full orchestration with classification and planning
/orchestrator "Implement OAuth2 with Google"
ralph orch "task description"

# Loop until VERIFIED_DONE
/loop "fix all type errors"
ralph loop "task"

# Intensive clarification
/clarify

# 3-dimension classification
/classify "Implement OAuth for Google, GitHub, Microsoft"
```

### Quality Validation

```bash
# Quality gates (9 languages)
/gates

# Adversarial specification refinement
/adversarial src/critical/

# Security audit
ralph security src/
ralph security-loop src/
```

### Memory Management

```bash
# Parallel memory search
ralph memory-search "query"

# Fork suggestion (find similar sessions)
ralph fork-suggest "task"

# Health check
ralph health
ralph health --compact
ralph health --json
ralph health --fix
```

### Repository Learning (v2.50)

```bash
# Learn from a repository
/repo-learn https://github.com/python/cpython

# Focused learning
/repo-learn https://github.com/fastapi/fastapi --category error_handling
/repo-learn https://github.com/facebook/react --category security --min-confidence 0.9
```

### Repo Curator (v2.55)

```bash
# Full pipeline (economic tier - DEFAULT)
/curator full --type backend --lang typescript

# Custom discovery
/curator discovery --query "microservice" --max-results 200 --tier free

# Scoring with context relevance
/curator scoring --input candidates.json --context "error handling,retry"

# Custom ranking
/curator rank --input scored.json --top-n 15 --max-per-org 3

# View ranking
/curator show --type backend --lang typescript
/curator pending --type backend

# Approve/reject
/curator approve nestjs/nest
/curator approve --all
/curator reject some/repo --reason "Low test coverage"

# Learn from approved repos
/curator learn --repo nestjs/nest
/curator learn --all
```

### Codex Planning (v2.50)

```bash
# Direct Codex planning
/codex-plan "Design a distributed caching system"

# Orchestrator with Codex
/orchestrator "Implement microservices" --use-codex
/orchestrator "Design event-driven system" --codex
```

### Local Observability (v2.52)

```bash
# Full status
ralph status
ralph status --compact         # One-line: 📊 STANDARD Step 3/7 (42%)
ralph status --steps           # Step-by-step breakdown
ralph status --json            # JSON output

# Trace events
ralph trace show 30            # Recent events
ralph trace search "error"     # Search events
ralph trace timeline           # Visual timeline
ralph trace export json        # Export to JSON/CSV
ralph trace summary            # Session summary
```

### Checkpoint System (v2.51)

```bash
# Save checkpoint
ralph checkpoint save "before-refactor" "Pre-auth module refactoring"

# List checkpoints
ralph checkpoint list

# Restore
ralph checkpoint restore "before-refactor"

# Compare
ralph checkpoint diff "before-refactor"
```

### Handoff API (v2.51)

```bash
# Transfer task between agents
ralph handoff transfer --from orchestrator --to security-auditor \
    --task "Audit authentication module"

# List agents
ralph handoff agents

# Validate agent
ralph handoff validate debugger

# History
ralph handoff history
```

### Event-Driven Engine (v2.51)

```bash
# Emit event
ralph events emit step.complete '{"step_id": "step1"}'

# Check barriers
ralph events barrier check phase-1
ralph events barrier wait phase-1 300

# List barriers
ralph events barrier list

# Event history
ralph events history 20
```

### Git Worktree

```bash
# Create isolated worktree
ralph worktree "feature"

# PR with review
ralph worktree-pr <branch>
```

### Context Preservation

```bash
# Manual save (for extension limitations)
ralph compact

# Ledger management
ralph ledger save
ralph ledger list
ralph ledger load <session-id>

# Handoff
ralph handoff create
ralph handoff load <session-id>
```

### Claude Code Skills

```bash
# Marketing skills (23 skills available)
/ab-test-setup "Design A/B test for pricing page"
/copywriting "Write landing page copy for SaaS product"
/funnel-design "Create marketing funnel for B2B software"
/brand-positioning "Position our AI startup against competitors"

/react-best-practices "Best practices for React component composition"
/readme "Generate comprehensive README for my project"
/readme "Update existing README with new features"
```

---

## Hooks System

### Overview

Ralph uses **53 registered hooks** across 6 event types to automate workflows:

| Event Type | Count | Purpose |
|------------|-------|---------|
| **SessionStart** | 2 | Context preservation at startup |
| **PreCompact** | 1 | Save state before compaction |
| **PostToolUse** | 16 | Quality gates after Edit/Write/Bash |
| **PreToolUse** | 16 | Security guards before Bash/Skill/Task |
| **UserPromptSubmit** | 8 | Context warnings, reminders |
| **Stop** | 10 | Session reports, reflection, learning |

### Key Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `status-auto-check.sh` | PostToolUse | Auto-shows status every 5 operations |
| `sec-context-validate.sh` | PostToolUse (Edit/Write) | **Security quality gate** - detects 7 critical patterns |
| `checkpoint-smart-save.sh` | PreToolUse (Edit/Write) | Smart checkpoints on risky edits |
| `statusline-health-monitor.sh` | UserPromptSubmit | Health checks every 5 minutes |
| `orchestrator-auto-learn.sh` | PreToolUse (Task) | Detects knowledge gaps |
| `reflection-engine.sh` | Stop | Trigger async reflection |
| `procedural-inject.sh` | PreToolUse (Task) | Inject learned behaviors |

### Smart Checkpoint Triggers

| Trigger | Condition |
|---------|-----------|
| `high_complexity` | Plan complexity ≥ 7 |
| `high_risk_step` | Step involves auth/security/payment |
| `critical_file` | Config, settings, .env, database files |
| `security_file` | Files with auth/secret/credential in name |

---

## Testing

### Running Tests

```bash
# Run all tests
cd tests
./run_tests.sh

# Run specific test categories
python -m pytest test_memory_v2_49.py -v           # Memory tests
python -m pytest test_command_sync.py -v           # Command sync tests
python -m pytest test_hooks_comprehensive.py -v    # Hook tests
python -m pytest test_context_engine.py -v         # Context tests

# Run shell tests
bash test_v2.25_search_hierarchy.sh
bash test_v2.27_security_loop.sh
```

### Test Coverage

| Category | Test Count | Status |
|----------|------------|--------|
| Memory Tests | 48+ | ✅ Passing |
| Command Sync Tests | 20 | ✅ Passing |
| Hook Tests | 48+ | ✅ Passing |
| Context Engine Tests | 15+ | ✅ Passing |
| Security Tests | 10+ | ✅ Passing |
| **Total** | **103+** | ✅ Passing |

### Test Structure

```
tests/
├── test_*.py              # Python unit tests
├── test_*.sh              # Shell integration tests
├── conftest.py            # Pytest fixtures
└── HOOK_TESTING_PATTERNS.md  # Hook testing guide
```

---

## Deployment

### Local Development

Ralph is designed for **local development** and **global installation**. The installer sets up:

1. **CLI Commands**: `ralph`, `mmc` in `~/.local/bin/`
2. **Global Configuration**: `~/.claude/` directory with:
   - 14 AI agents
   - 53 event hooks
   - 35+ slash commands
   - **25+ Claude Code skills** (marketing, documentation, React, security)
3. **Runtime Data**: `~/.ralph/` directory with:
   - Memory storage
   - Event logs
   - Checkpoints
   - Agent memory buffers

### Production Use

Ralph is **not deployed as a service**. It's a **development tool** that runs locally alongside Claude Code.

**To update**:

```bash
cd /path/to/multi-agent-ralph-loop
git pull origin main
./install.sh
```

**To uninstall**:

```bash
cd /path/to/multi-agent-ralph-loop
./uninstall.sh
```

---

## Troubleshooting

### Database Connection Issues

**Error**: Memory operations failing

**Solution**:
```bash
# Check claude-mem MCP status
ralph health --json | jq '.memory'

# Verify SQLite FTS
ls ~/.ralph/memory/
```

### Hook Not Firing

**Error**: Expected hook behavior not occurring

**Solution**:
```bash
# Check hook registration
ralph health | grep hooks

# Verify settings.json
cat ~/.claude/settings.json | jq '.hooks'

# Check hook logs
ls ~/.ralph/logs/
cat ~/.ralph/logs/latest.log
```

### Context Loss

**Error**: Session context not preserved

**Solution**:
```bash
# Manual ledger save
ralph ledger save

# Check ledgers
ralph ledger list

# Restore from handoff
ralph handoff history
ralph handoff load <session-id>
```

### Quality Gates Failing

**Error**: Gates blocking valid code

**Solution**:
```bash
# Run gates with verbose output
/gates --verbose

# Check specific language handler
cat ~/.claude/scripts/gates.sh | grep -A5 "typescript"

# Bypass advisory checks
/gates --advisory-only
```

### Installation Failures

**Error**: Installer errors

**Solution**:
```bash
# Check dependencies
brew install jq curl git

# Manual installation
mkdir -p ~/.local/bin
cp scripts/ralph ~/.local/bin/
cp scripts/mmc ~/.local/bin/
chmod +x ~/.local/bin/ralph ~/.local/bin/mmc

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Skills Not Appearing

**Error**: `/readme` or marketing skills not available

**Solution**:
```bash
# Check skills installation
ls ~/.claude/skills/

# Verify skill structure
cat ~/.claude/skills/readme/SKILL.md | head -20

# Re-run installer
cd /path/to/multi-agent-ralph-loop
./install.sh

# Reload Claude Code
# (restart your Claude Code session)
```

### React Best Practices Skill Missing

**Error**: `/react-best-practices` skill not available

**Solution**:
```bash
# Check if skill exists
ls ~/.claude/skills/react-best-practices/

# Manual installation
mkdir -p ~/.claude/skills/react-best-practices
curl -fsSL https://raw.githubusercontent.com/vercel-labs/agent-skills/main/skills/react-best-practices/SKILL.md \
    -o ~/.claude/skills/react-best-practices/SKILL.md

# Verify
cat ~/.claude/skills/react-best-practices/SKILL.md | head -10
```

---

## Contributing

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Run tests: `./run_tests.sh`
5. Submit PR

### Adding New Hooks

1. Create hook file in `~/.claude/hooks/`
2. Add to `~/.claude/settings.json`
3. Document in `CLAUDE.md`
4. Test with `/gates`

### Adding New Agents

1. Create agent file in `~/.claude/agents/`
2. Register in `~/.claude/settings.json`
3. Document in `AGENTS.md`
4. Add to README.md

### Adding New Skills

1. Create skill file in `~/.claude/skills/<skill-name>/SKILL.md`
2. Add YAML frontmatter with name and description:
```yaml
---
name: skill-name
description: When to use this skill
allowed-tools: Bash,Read,Write
---
```
3. Document skill functionality in Markdown
4. Add to install.sh for automatic installation
5. Update README.md with skill description

---

## License

This project is licensed under the **Business Source License 1.1 (BSL 1.1)**.

See [`LICENSE`](./LICENSE) for full terms.

---

## Acknowledgments

- **Claude Code** - Base AI orchestration platform
- **Ralph Wiggum** - Inspiration (The Simpsons)
- **OpenAI Codex** - Advanced planning capabilities
- **MiniMax** - Cost-optimized validation
- **Claude.ai** - Core model capabilities

---

## References

| Document | Purpose |
|----------|---------|
| [`CHANGELOG.md`](./CHANGELOG.md) | Complete version history |
| [`ARCHITECTURE_DIAGRAM_v2.52.0.md`](./ARCHITECTURE_DIAGRAM_v2.52.0.md) | Detailed architecture diagrams |
| [`CLAUDE.md`](./CLAUDE.md) | Quick reference guide |
| [`AGENTS.md`](./AGENTS.md) | Agent documentation |
| [`TESTING.md`](./TESTING.md) | Testing guide |
| [`CONTRIBUTING.md`](./CONTRIBUTING.md) | Contribution guidelines |

---

*"Better to fail predictably than succeed unpredictably"* - The Ralph Wiggum Philosophy
