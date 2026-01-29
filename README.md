# Multi-Agent Ralph Wiggum

> "Me fail English? That's unpossible!" - Ralph Wiggum

![Version](https://img.shields.io/badge/v2.81.0-blue) ![Tests](https://img.shields.io/badge/945_tests-passing-brightgreen) ![License](https://img.shields.io/badge/BSL_1.1-orange) ![GLM-4.7](https://img.shields.io/badge/GLM--4.7-PRIMARY-green) ![Swarm](https://img.shields.io/badge/Swarm_Mode-Enabled-success)

---

## 🚀 Latest Release: v2.81.0 - Native Swarm Mode

**New**: Multi-Agent Ralph Loop now supports **native swarm mode** with multi-agent coordination using Claude Code's built-in TeammateTool.

### What's New in v2.81.0

- **Swarm Mode**: Native multi-agent orchestration with TeammateTool
- **Teammate Spawning**: Automatic spawning of specialized teammates
- **Inter-Agent Messaging**: Direct communication between agents
- **Shared Task List**: Collaborative task management
- **Plan Approval**: Leader can approve/reject teammate plans
- **GLM-4.7 PRIMARY**: Economic model for all tasks

### Quick Start with Swarm Mode

```bash
# Full orchestration with automatic teammate spawning
/orchestrator "Implement OAuth2 authentication with JWT tokens"
# → Spawns 3 teammates: code-reviewer, test-architect, security-auditor

# Manual teammate spawning
Task:
  subagent_type: "orchestrator"
  team_name: "my-team"
  name: "team-lead"
  mode: "delegate"

ExitPlanMode:
  launchSwarm: true
  teammateCount: 3
```

**Documentation**: [Swarm Mode Guide](tests/swarm-mode/COMO_USAR_SWARM_MODE_CLAUDE_ZAI.md) | [Architecture](docs/architecture/SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md)

---

## 🐛 Recent Bug Fixes (v2.70.0 - v2.81.0)

### Swarm Mode Integration (v2.81.0) ✅ NEW

**Overview**: Complete integration of Claude Code's native swarm mode with multi-agent coordination.

#### Key Features

1. **TeammateTool Integration**
   - spawnTeam: Create teams and spawn teammates
   - approveJoin: Approve teammate join requests
   - requestJoin: Request to join a team
   - cleanup: Clean up team resources

2. **Agent Environment Variables**
   - CLAUDE_CODE_AGENT_ID: Unique agent identifier
   - CLAUDE_CODE_AGENT_NAME: Human-readable agent name
   - CLAUDE_CODE_TEAM_NAME: Team coordination
   - CLAUDE_CODE_PLAN_MODE_REQUIRED: Plan approval mode

3. **Multi-Agent Commands**
   - `/orchestrator` - Full orchestration with swarm (v2.81.0)
   - `/loop` - Iterative execution with team (v2.81.0)

4. **Configuration**
   - Automated setup script
   - 44 unit tests for validation
   - Environment-specific configurations

#### Swarm Mode Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    SWARM MODE EXECUTION FLOW                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. User Request → /orchestrator "Implement feature X"          │
│         ↓                                                         │
│  2. Orchestrator creates team "multi-agent-ralph-loop"          │
│         ↓                                                         │
│  3. ExitPlanMode with launchSwarm: true                         │
│         ↓                                                         │
│  4. Spawns 3 teammates:                                         │
│     - code-reviewer                                              │
│     - test-architect                                             │
│     - security-auditor                                           │
│         ↓                                                         │
│  5. Teammates coordinate via shared task list                    │
│         ↓                                                         │
│  6. Inter-agent messaging for collaboration                     │
│         ↓                                                         │
│  7. Quality gates validate all changes                          │
│         ↓                                                         │
│  8. Plan approval/rejection by leader                           │
│         ↓                                                         │
│  9. Cleanup team resources                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Verification

```bash
# Verify swarm mode is enabled
bash tests/swarm-mode/test-swarm-mode-config.sh
# Expected: ALL TESTS PASSED (44/44)

# Check settings
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '{
  agent_id: .env.CLAUDE_CODE_AGENT_ID,
  agent_name: .env.CLADE_CODE_AGENT_NAME,
  team_name: .env.CLADE_CODE_TEAM_NAME,
  default_mode: .permissions.defaultMode
}'
```

#### Documentation

| Document | Purpose |
|----------|---------|
| [COMO_USAR_SWARM_MODE_CLAUDE_ZAI.md](tests/swarm-mode/COMO_USAR_SWARM_MODE_CLAUDE_ZAI.md) | Spanish guide for using swarm mode |
| [SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md](docs/architecture/SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md) | Technical analysis |
| [SWARM_MODE_VALIDATION_v2.81.0.md](docs/architecture/SWARM_MODE_VALIDATION_v2.81.0.md) | Validation report |
| [SETTINGS_CONFIGURATION_GUIDE.md](tests/swarm-mode/SETTINGS_CONFIGURATION_GUIDE.md) | Configuration guide |
| [REPRODUCTION_GUIDE.md](tests/swarm-mode/REPRODUCTION_GUIDE.md) | Reproduction steps |

---

## 🐛 Recent Bug Fixes (v2.70.0 - v2.80.9)

### GLM Usage Cache Optimization (v2.80.9)

**Overview**: Optimized GLM usage tracking with single-pass JSON parsing and improved performance.

#### Changes

| Metric | Before | After |
|--------|--------|-------|
| **jq calls** | 4 separate reads | 1 single pass |
| **Disk I/O** | 4 file reads | 1 file read |
| **Execution time** | ~15ms | ~5ms |

#### Key Improvements

1. **Single jq call**: Read all cache data in one pass using pipe-delimited output
2. **Simplified color logic**: Short-circuit evaluation for color thresholds
3. **Better performance**: 3x faster statusline rendering

#### Statusline Format

```
⎇ main* │ ⏱️ 11% (~5h) │ 🔧 4% MCP (182/4000)
          └─ Token Quota ─┘ └──── MCP Usage ──────┘
```

#### GLM Usage Metrics

| Metric | Display | Color Thresholds |
|--------|---------|------------------|
| **Tokens (5h)** | `⏱️ 11% (~5h)` | 🟢<75%, 🟡≥75%, 🔴≥85% |
| **MCP (monthly)** | `🔧 4% MCP (182/4000)` | 🔵<75%, 🟡≥75% |

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Tech Stack](#tech-stack)
4. [Prerequisites](#prerequisites)
5. [Getting Started](#getting-started)
6. [Architecture](#architecture)
7. [Memory Architecture](#memory-architecture)
8. [Hooks System](#hooks-system)
9. [Agent System](#agent-system)
10. [Swarm Mode (v2.81.0)](#swarm-mode--v2810)
11. [Multi-Model Support (v2.69)](#multi-model-support--v2-69)
12. [Dynamic Contexts System (v2.63)](#dynamic-contexts-system--v2-63)
13. [Eval-Driven Development (v2.64)](#eval-driven-development--v2-64)
14. [Input](#input)
15. [Expected Behavior](#expected-behavior)
16. [Plan Lifecycle Management (v2.65)](#plan-lifecycle-management--v2-65)
17. [Commands Reference](#commands-reference)
18. [Ralph Loop Pattern](#ralph-loop-pattern)
19. [Quality-First Validation](#quality-first-validation)
20. [Claude Code Task Primitive Integration](#claude-code-task-primitive-integration)
21. [Claude Code Skills Ecosystem](#claude-code-skills-ecosystem)
22. [Testing](#testing)
23. [Deployment](#deployment)
24. [Troubleshooting](#troubleshooting)
25. [Contributing](#contributing)
26. [License](#license)

---

## Overview

Ralph coordinates **multiple AI models** and **multiple AI agents** to produce validated code. Rather than trust one model's output, it runs them in parallel with quality gates and swarm coordination.

```
┌─────────────────────────────────────────────────────────────────┐
│                  MULTI-AGENT SWARM MODE v2.81.0                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ORCHESTRATOR (LEAD)                                           │
│   ┌─────────────┐                                              │
│   │  GLM-4.7    │                                              │
│   │  PRIMARY    │                                              │
│   │  Coordinator│                                              │
│   └──────┬──────┘                                              │
│          │                                                     │
│          ├─────────────┬─────────────┬─────────────┐            │
│          ↓             ↓             ↓             ↓            │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│   │code-     │  │test-     │  │security- │  │debugger  │       │
│   │reviewer  │  │architect │  │auditor   │  │          │       │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
│                                                                 │
│   INTER-AGENT MESSAGING + SHARED TASK LIST                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

The core idea: **spawn → coordinate → validate → iterate** until the code passes.

### What It Does

- **Swarm orchestration** — Native multi-agent coordination with TeammateTool
- **Multi-model routing** — GLM-4.7 (PRIMARY) + Codex (SPECIALIZED)
- **3-Model Adversarial Council** — Codex + GLM-4.7 + Gemini for review
- **Quality gates** — 9 languages supported (TS, Python, Go, Rust, Solidity, etc.)
- **Memory system** — Semantic, episodic, procedural memory with 30-day TTL
- **74 hooks** (73 bash + 1 python) — 80 event registrations
- **40 core skills** — Command shortcuts
- **Dynamic contexts** — dev, review, research, debug modes
- **Statusline Ralph** — Real-time tracking with claude-hud v0.0.6
- **GLM Web Search** — Real-time search via `/glm-web-search`

See [CHANGELOG.md](CHANGELOG.md) for version history

---

## Key Features

### Swarm Mode (v2.81.0) 🆕

- **Native multi-agent coordination** — Built-in TeammateTool for spawning and managing teammates
- **Inter-agent messaging** — Direct communication between agents
- **Shared task list** — All teammates see and work on the same tasks
- **Plan approval workflow** — Leader can approve/reject teammate plans
- **Automated spawning** — Automatic teammate creation with ExitPlanMode
- **Team cleanup** — Automatic resource cleanup after completion

### Orchestration

- **Smart routing** — Classifies tasks by complexity, density, and context requirements
- **Checkpoints** — Save and restore orchestration state (time travel)
- **Handoffs** — Transfer work between specialized agents
- **Plan lifecycle** — Archive, reset, restore plans via CLI
- **Multi-model adversarial validation** — Three-model consensus for critical changes

### Memory

| Type | What it stores | TTL |
|------|----------------|-----|
| Semantic | Facts, preferences | Forever |
| Episodic | Decisions, patterns | 30 days |
| Procedural | Best practices, rules | Forever |

### Learning (v2.81.2) 🎓

**Automatic Learning System** - Ralph learns quality patterns from GitHub repositories and applies them during development.

#### Components

1. **Repo Curator** (v2.0.0)
   - **Discovery**: GitHub API search for quality repositories
   - **Scoring**: Quality metrics + context relevance scoring
   - **Ranking**: Top N repos with max-per-org limits
   - **15 critical bugs fixed** in v2.0.0

2. **Repository Learner**
   - Extracts patterns via AST analysis
   - Classifies by domain (backend, frontend, security, etc.)
   - Generates procedural rules with confidence scores
   - Stores 1003+ learned rules

3. **Auto-Learning Integration** (v2.81.2) 🆕
   - **learning-gate.sh**: Auto-executes /curator when memory is empty
   - **rule-verification.sh**: Validates rules were applied in code
   - **Automatic execution**: No manual intervention needed
   - **Quality metrics**: Utilization rate tracking

#### Usage

```bash
# Full learning pipeline
/curator full --type backend --lang typescript

# Discover repositories
/curator discovery --query "microservice" --max-results 50

# Score with context relevance
/curator scoring --context "error handling,retry,resilience"

# Rank results
/curator rank --top-n 20 --max-per-org 3

# Learn from approved repos
/curator learn --all
```

#### Pricing Tiers

| Tier | Cost | Features |
|------|------|----------|
| `free` | $0.00 | GitHub API + local scoring |
| `economic` | ~$0.30 | + OpenSSF + GLM-4.7 (DEFAULT) |
| `full` | ~$0.95 | + Claude + Codex adversarial |

#### Current Statistics

- **Total Rules**: 1003
- **With Domain**: 148 (14.7%)
- **Applied Count**: Tracking active
- **Utilization Rate**: Measured automatically

**Documentation**: [Learning System Guide](docs/implementation/FASE_2_COMPLETADA_v2.81.2.md) | [Curator Fixes](docs/implementation/FASE_1_COMPLETADA_v2.81.1.md)

### Security

Based on [sec-context](https://github.com/Arcanum-Sec/sec-context):
- 27 anti-patterns checked
- 20+ CWE references
- Blocks on security issues (not advisory)

---

## Tech Stack

- **Claude Code CLI** — Base orchestration
- **Swarm Mode** — Native multi-agent coordination (v2.81.0)
- **GLM-4.7 PRIMARY** — Economic model for all tasks
- **Multi-Model AI** — Claude Opus/Sonnet, Codex GPT-5.2, Gemini 2.5 Pro
- **Bash/zsh** — 74 hooks (73 bash + 1 python)
- **Python 3.11+** — Utility scripts
- **JSON** — Configuration, memory storage
- **26 MCP servers** — GLM-4.7, Context7, Playwright, etc.

---

## Prerequisites

### Required

```bash
# Core dependencies
command -v jq    # JSON processing (REQUIRED)
command -v curl  # HTTP requests (REQUIRED)
command -v git   # Version control (REQUIRED)
command -v bash  # Shell scripts (REQUIRED, version 5.0+)
```

### Optional (Recommended)

```bash
# AI Orchestration
command -v claude  # Claude Code CLI (primary)
command -v codex   # OpenAI Codex CLI (adversarial review)
command -v gemini  # Google Gemini CLI (analysis)

# Development Tools
command -v gh      # GitHub CLI (PR workflow)
command -v npx     # Node.js (TypeScript, ESLint)
command -v ruff    # Python linter
command -v pyright # Python type checker

# Security Tools
command -v semgrep  # Security scanning
command -v gitleaks # Secrets detection
```

### Installation

```bash
# macOS
brew install jq curl git gh npx ruff

# Verify versions
jq --version   # >= 1.6
curl --version # Any recent version
git --version  # Any recent version
```

---

## Getting Started

### Installation

```bash
# Clone the repository
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Run the global installer
./install.sh

# The installer will:
# 1. Backup existing ~/.claude/ configuration
# 2. Install ralph CLI to ~/.local/bin/
# 3. Copy hooks, agents, commands, skills to ~/.claude/
# 4. Register hooks in ~/.claude/settings.json
# 5. Initialize Ralph memory system in ~/.ralph/

# Configure Swarm Mode (v2.81.0)
bash tests/swarm-mode/configure-swarm-mode.sh

# Verify Swarm Mode
bash tests/swarm-mode/test-swarm-mode-config.sh

# Restart Claude Code to load new configuration
```

### Verification

```bash
# Check Ralph health
ralph health

# Should output something like:
# === Memory System Health ===
# Semantic: OK (1452 facts)
# Procedural: OK (319 rules)
# Episodic: OK (234 episodes)
# Total: OK

# Check hooks registration
ls ~/.claude/hooks/*.sh | wc -l
# Should output: 74 (v2.81.0 - 74 files, 80 registrations)

# Test quality gates
/gates
# Should show: Quality gates ready

# Verify Swarm Mode
bash tests/swarm-mode/test-swarm-mode-config.sh
# Should output: ALL TESTS PASSED (44/44)
```

### Quick Start Commands

```bash
# 1. Full orchestration with swarm mode
/orchestrator "Implement OAuth2 authentication with JWT tokens"
# → Spawns 3 teammates automatically

# 2. Quality validation
/gates          # Quality gates
/adversarial    # Spec refinement with dual-model

# 3. Iterative loop (until VERIFIED_DONE)
/loop "fix all type errors in src/"

# 4. Checkpoint (v2.51)
ralph checkpoint save "before-refactor" "Pre-auth module changes"
ralph checkpoint restore "before-refactor"

# 5. Agent handoff (v2.51)
ralph handoff transfer --from orchestrator --to security-auditor \
    --task "Audit authentication module"

# 6. Learn from repository (v2.50)
/repo-learn https://github.com/fastapi/fastapi

# 7. Curate quality repos (v2.55)
/curator full --type backend --lang python
```

---

## Architecture

### Directory Structure

```
multi-agent-ralph-loop/           # Repository root
├── .claude/                      # Project-level Claude Code config
│   ├── agents/                   # Specialized agents (35 files)
│   │   ├── orchestrator.md       # Main orchestration agent
│   │   ├── security-auditor.md   # Security-focused agent
│   │   ├── debugger.md           # Bug detection/fix agent
│   │   ├── code-reviewer.md      # Code review agent
│   │   ├── glm-reviewer.md       # GLM-4.7 validation
│   │   ├── repository-learner.md # AST pattern extraction
│   │   ├── repo-curator.md       # Repository curation
│   │   └── ... (28 more agents)
│   ├── commands/                 # Slash commands (40 files)
│   │   ├── orchestrator.md       # v2.81.0 with swarm parameters
│   │   └── loop.md               # v2.81.0 with swarm parameters
│   ├── hooks/                    # Project hooks (synced from global)
│   ├── scripts/                  # Utility scripts (35+ files)
│   ├── skills/                   # Project skills (26 directories)
│   └── plan-state.json           # Current orchestration state
├── tests/
│   └── swarm-mode/               # Swarm mode test suite (v2.81.0)
│       ├── test-swarm-mode-config.sh      # 44 unit tests
│       ├── configure-swarm-mode.sh        # Automated setup
│       ├── SETTINGS_CONFIGURATION_GUIDE.md # Settings guide
│       ├── REPRODUCTION_GUIDE.md          # Reproduction steps
│       ├── COMO_USAR_SWARM_MODE_CLAUDE_ZAI.md # Spanish guide
│       └── README.md                        # Test suite docs
├── docs/                         # Documentation
│   ├── architecture/             # Architecture diagrams
│   │   ├── SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md
│   │   └── SWARM_MODE_VALIDATION_v2.81.0.md
│   └── security/                 # Security documentation
├── scripts/                      # Main CLI scripts
│   ├── ralph                     # Main CLI (v2.81.0)
│   └── mmc                       # Multi-Model CLI
├── config/                       # Configuration files
│   ├── models.json               # Model routing config
│   └── ralph_rules.json          # Procedural rules
├── install.sh                    # Global installer
├── uninstall.sh                  # Uninstaller
├── CLAUDE.md                     # Project instructions
├── AGENTS.md                     # Agent documentation
├── README.md                     # This file
├── CHANGELOG.md                  # Version history
└── LICENSE                       # BSL 1.1 License

~/.claude-sneakpeek/zai/config/   # Zai variant configuration
└── settings.json                 # Swarm mode configuration

~/.claude/                        # Global Claude Code config
├── hooks/                        # Global hooks (74 files, 80 registrations)
├── agents/                       # Global agents (35 files)
├── commands/                     # Global commands
├── skills/                       # Global skills ecosystem
├── contexts/                     # Dynamic contexts (dev, review, research, debug)
└── settings.json                 # Hook registrations

~/.ralph/                         # Ralph runtime data
├── memory/                       # Semantic memory
├── episodes/                     # Episodic memory (30-day TTL)
├── procedural/                   # Procedural rules
├── agent-memory/                 # Per-agent memory buffers
├── checkpoints/                  # Time-travel checkpoints
├── ledgers/                      # Session ledgers
├── handoffs/                     # Agent handoff records
├── logs/                         # Hook and system logs
└── tasks/                        # Swarm mode task lists
```

### Core Workflow (12 Steps) - v2.81.0

```
  0. EVALUATE     -> 3-dimension classification
  1. CLARIFY      -> AskUserQuestion (MUST_HAVE + NICE_TO_HAVE)
  1b. GAP-ANALYST -> Pre-implementation gap analysis
  1c. PARALLEL_EXPLORE -> 5 concurrent searches
  2. CLASSIFY     -> Complexity 1-10 + Info Density + Context Req
  2b. WORKTREE    -> Isolated worktree option
  3. PLAN         -> orchestrator-analysis.md -> Plan Mode
  3b. PERSIST     -> Write analysis file
  3c. PLAN-STATE  -> Initialize plan-state.json
  3d. RECURSIVE_DECOMPOSE -> Sub-orchestrators if needed
  4. PLAN MODE    -> EnterPlanMode (reads analysis)
  5. DELEGATE     -> Route to GLM-4.7 (PRIMARY)
  6. SPAWN TEAM   -> Create team + spawn teammates (SWARM MODE)
  6a. LSA-VERIFY  -> Lead Software Architect pre-check
  6b. IMPLEMENT   -> Execute (parallel if independent)
  6c. PLAN-SYNC   -> Detect drift, patch downstream
  6d. MICRO-GATE  -> Per-step quality (3-Fix Rule)
  7. VALIDATE     -> CORRECTNESS + QUALITY + CONSISTENCY + ADVERSARIAL
  8. RETROSPECT   -> Analyze and improve
  9. CHECKPOINT   -> Optional state save
  10. HANDOFF     -> Optional agent transfer
  11. CLEANUP     -> Clean up team resources (SWARM MODE)
```

**Fast-Path** (complexity ≤ 3): DIRECT_EXECUTE → MICRO_VALIDATE → DONE (3 steps)

---

## Memory Architecture

### Three Memory Types

```
SMART MEMORY SEARCH (PARALLEL)
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│claude-mem│ │ memvid   │ │ handoffs │ │ ledgers  │
│  MCP     │ │          │ │          │ │          │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │ PARALLEL   │ PARALLEL   │ PARALLEL   │ PARALLEL
     └────────────┴────────────┴────────────┘
                    ↓
         .claude/memory-context.json
                    ↓
              Subagent Context
```

| Type | Purpose | Storage | TTL |
|-------------|---------|---------|-----|
| **Semantic** | Facts, preferences, learned rules | `~/.ralph/memory/semantic.json` | Never |
| **Episodic** | Experiences, decisions, patterns | `~/.ralph/episodes/` | 30 days |
| **Procedural** | Learned behaviors, best practices | `~/.ralph/procedural/rules.json` | Dynamic |
| **Agent-Scoped** | Isolated buffers per agent | `~/.ralph/agent-memory/<agent>/` | Varies |

### Repository Learner (v2.50)

Extracts best practices from GitHub repositories using AST-based pattern analysis.

```bash
# Learn from a specific repository
/repo-learn https://github.com/python/cpython

# Learn focused on specific patterns
/repo-learn https://github.com/fastapi/fastapi --category error_handling
```

---

## Hooks System

### Hook Types and Events

Claude Code hooks execute at specific lifecycle events:

| Event Type | Trigger | Common Use Cases |
|------------|---------|------------------|
| **SessionStart** | New session begins | Context restoration, ledger loading |
| **PreToolUse** | Before tool execution | Validation, context injection, permission checks |
| **PostToolUse** | After tool completion | Quality gates, formatting, extraction |
| **UserPromptSubmit** | User sends message | Context warnings, reminders |
| **PreCompact** | Before context compaction | State saving, ledger creation |
| **Stop** | Response completes | Session reports, cleanup |

### Registered Hooks (74 files, 80 registrations) - v2.81.0

See [CLAUDE.md](CLAUDE.md) for complete hook documentation.

---

## Agent System

### Default Agents (11) - v2.81.0

| Agent | Model | Purpose | Status |
|-------|-------|---------|--------|
| `@orchestrator` | **glm-4.7** | Coordinator, planning, classification, delegation, swarm lead | PRIMARY |
| `@security-auditor` | **codex** | Security, vulnerability scan (high-level) | SPECIALIZED |
| `@debugger` | **glm-4.7** | Debugging, error analysis, fix generation | PRIMARY |
| `@code-reviewer` | **glm-4.7** | Code review, pattern analysis | PRIMARY → Codex SECONDARY |
| `@performance-reviewer` | **codex** | Performance analysis, optimization | SPECIALIZED |
| `@test-architect` | **glm-4.7** | Testing, test generation, coverage analysis | PRIMARY |
| `@refactorer` | **glm-4.7** | Refactoring, pattern application | PRIMARY |
| `@frontend-reviewer` | **glm-4.7** | Frontend, UI review, accessibility | PRIMARY |
| `@docs-writer` | **glm-4.7** | Documentation, README, API docs | PRIMARY |
| `@repository-learner` | **glm-4.7** | Learning, pattern extraction, rule generation | PRIMARY |
| `@repo-curator` | **glm-4.7** | Curation, scoring, discovery | PRIMARY |

**Complete Agent Documentation**: See [AGENTS.md](AGENTS.md)

### Agent Handoffs (v2.51)

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

---

## Swarm Mode (v2.81.0)

### Overview

Swarm Mode enables **native multi-agent coordination** using Claude Code's built-in TeammateTool. It allows spawning specialized teammates that collaborate through a shared task list and inter-agent messaging.

### Key Components

1. **TeammateTool** - Native tool for multi-agent coordination
2. **Agent Environment Variables** - Identity and team configuration
3. **ExitPlanMode Parameters** - Swarm spawning control
4. **Inter-Agent Messaging** - Direct communication
5. **Shared Task List** - Collaborative task management

### Configuration

```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "claude-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "multi-agent-ralph-loop",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"
  },
  "permissions": {
    "defaultMode": "delegate"
  },
  "model": "glm-4.7"
}
```

### Usage

```bash
# Method 1: /orchestrator command (Recommended)
/orchestrator "Implement OAuth2 authentication"
# → Spawns 3 teammates automatically

# Method 2: /loop command
/loop "Fix all type errors"
# → Can spawn teammates if needed

# Method 3: Manual Task tool
Task:
  subagent_type: "orchestrator"
  team_name: "my-team"
  name: "team-lead"
  mode: "delegate"

ExitPlanMode:
  launchSwarm: true
  teammateCount: 3
```

### Verification

```bash
# Run automated tests
bash tests/swarm-mode/test-swarm-mode-config.sh

# Expected output:
# ✓ ALL TESTS PASSED (44/44)
# Swarm mode v2.81.0 is properly configured
```

### Documentation

| Document | Language | Purpose |
|----------|----------|---------|
| [COMO_USAR_SWARM_MODE_CLAUDE_ZAI.md](tests/swarm-mode/COMO_USAR_SWARM_MODE_CLAUDE_ZAI.md) | Spanish | Complete usage guide |
| [SETTINGS_CONFIGURATION_GUIDE.md](tests/swarm-mode/SETTINGS_CONFIGURATION_GUIDE.md) | English | Configuration details |
| [REPRODUCTION_GUIDE.md](tests/swarm-mode/REPRODUCTION_GUIDE.md) | English | Reproduction steps |
| [SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md](docs/architecture/SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md) | English | Technical analysis |
| [SWARM_MODE_VALIDATION_v2.81.0.md](docs/architecture/SWARM_MODE_VALIDATION_v2.81.0.md) | English | Validation report |

---

## Multi-Model Support (v2.69)

### Overview

Ralph supports **multiple AI models** for optimal cost/performance trade-offs. Each model is selected based on task complexity, cost constraints, and specific capabilities required.

### Supported Models

| Model | Provider | Relative Cost | Use Case | Status |
|-------|----------|---------------|----------|--------|
| **GLM-4.7** | Z.AI | **~0.15x** | All tasks (PRIMARY model) | **PRIMARY** |
| **Codex GPT-5.2** | OpenAI | Variable | Security, performance, high-level review (SPECIALIZED) | SECONDARY |
| **Gemini 2.5 Pro** | Google | Variable | Cross-validation, 1M context | OPTIONAL |

### GLM-4.7 - PRIMARY Economic Model (v2.69.0)

```
┌─────────────────────────────────────────────────────────────┐
│                    GLM-4.7 CAPABILITIES                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  VISION (8 tools)           SEARCH (2 tools)                │
│  ├─ ui_to_artifact          ├─ webSearchPrime               │
│  ├─ extract_text_from_ss    └─ webReader                    │
│  ├─ diagnose_error_ss                                       │
│  ├─ understand_diagram      DOCS (3 tools)                  │
│  ├─ analyze_data_viz        ├─ search_doc                   │
│  ├─ ui_diff_check           ├─ read_file                    │
│  ├─ analyze_image           └─ get_repo_structure           │
│  └─ analyze_video                                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Use Cases**:
- All tasks (PRIMARY model)
- Adversarial Council (4th planner)
- Web search validation
- Vision/OCR analysis
- Extended loops (50 iterations)

**Usage**:
```bash
# Direct query
/glm-4.7 "Review this authentication code"

# Web search
/glm-web-search "TypeScript best practices 2026"

# Via mmc CLI
mmc --query "Analyze this code"
mmc --web-search "Latest security patterns"
```

### Multi-Model Adversarial Validation (4 Planners)

For critical changes (complexity ≥ 7), Ralph runs **four-model validation**:

```
┌─────────────────────────────────────────────────────────────────┐
│            ADVERSARIAL VALIDATION COUNCIL v2.81.0                │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                           │
│  │  CODEX   │ │  GLM-4.7 │ │  GEMINI  │                           │
│  │ GPT-5.2  │ │  Coding   │ │ 2.5 Pro  │                           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘                           │
│       └────────────┴────────────┘                              │
│                         ↓                                      │
│                ┌───────────────┐                               │
│                │     JUDGE     │  (GLM-4.7 Coding)              │
│                │  Anonymized   │  + Web Search Validation       │
│                └───────┬───────┘                               │
│                        ↓                                       │
│               CONSENSUS REQUIRED                               │
│        All planners evaluated, best plan synthesized           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Dynamic Contexts System (v2.63)

### Overview

The Dynamic Contexts System allows switching between operational modes that change Claude's behavior, priorities, and focus.

### Available Contexts

| Context | Focus | Behavior |
|---------|-------|----------|
| `dev` | Development | Code first, explain after. Prioritizes working code over documentation. |
| `review` | Code Review | Thorough analysis, pattern detection, quality suggestions. |
| `research` | Research | Deep exploration, comprehensive documentation, alternatives comparison. |
| `debug` | Debugging | Systematic diagnosis, hypothesis testing, minimal changes. |

### Usage

```bash
# Switch to development mode
ralph context dev

# Switch to review mode
ralph context review

# Show active context
ralph context show
```

---

## Eval-Driven Development (v2.64)

### Overview

Eval-Driven Development (EDD) treats AI code quality evals as "unit tests for AI development".

### Key Metrics

| Metric | Description | Formula |
|--------|-------------|---------|
| `pass@1` | Success rate on first attempt | correct_first / total |
| `pass@3` | Success rate within 3 attempts | correct_within_3 / total |
| `pass^k` | Geometric mean across difficulties | (pass@easy × pass@med × pass@hard)^(1/3) |

### Usage

```bash
# List all evals
edd list

# Run a specific eval
edd run <eval-name>

# Show eval results
edd results
```

---

## Plan Lifecycle Management (v2.65)

### Overview

Plan Lifecycle Management provides CLI commands for managing `plan-state.json` throughout its lifecycle: creation, execution, completion, archiving, and restoration.

### Commands

```bash
# Show current plan status
ralph plan show

# Archive current plan and start fresh
ralph plan archive "Completed OAuth implementation"

# Reset plan to empty state
ralph plan reset

# Show archived plans history
ralph plan history

# Restore from archive
ralph plan restore <archive-id>
```

---

## Commands Reference

### Core Commands

```bash
# Orchestration
ralph orch "task"           # Full orchestration
/orchestrator "task"        # Claude Code slash command

# Quality validation
/gates                       # Quality gates (CORRECTNESS + QUALITY + CONSISTENCY)
/adversarial                 # Dual-model spec refinement

# Loop pattern
/loop "task"                 # Execute until VERIFIED_DONE
ralph loop "task"            # CLI alternative

# Manual context save
/compact                     # Manual context compaction
```

### Memory Commands

```bash
# Search memory in parallel
ralph memory-search "query"  # Search claude-mem, memvid, handoffs

# Suggest sessions to fork
ralph fork-suggest "task"    # Find similar past sessions

# Memory system health
ralph health                 # Full health report
ralph health --compact       # One-line summary
ralph health --json          # JSON output
ralph health --fix           # Auto-fix critical issues
```

### Repository Learning Commands

```bash
# Learn from GitHub repo
repo-learn https://github.com/python/cpython

# Curator pipeline
ralph curator full --type backend --lang typescript
ralph curator discovery --query "microservice"
ralph curator scoring --context "error handling,retry"
ralph curator rank --top-n 15
ralph curator show --type backend
ralph curator approve nestjs/nest
ralph curator learn --all
```

### Swarm Mode Commands (v2.81.0)

```bash
# Configure swarm mode
bash tests/swarm-mode/configure-swarm-mode.sh

# Verify swarm mode
bash tests/swarm-mode/test-swarm-mode-config.sh

# Use swarm mode
/orchestrator "task"  # Spawns teammates automatically
/loop "task"          # Can spawn teammates if needed
```

---

## Ralph Loop Pattern

```
EXECUTE → VALIDATE → Quality Passed?
                          ↓ NO
                      ITERATE (max 50)
                          ↓
                    Back to EXECUTE
```

`VERIFIED_DONE` = plan approved + MUST_HAVE answered + classified + implemented + gates passed + retrospective done

### Iteration Limits (v2.81.0)

| Model | Max Iterations | Use Case | Status |
|-------|----------------|----------|--------|
| **GLM-4.7** | **50** | All tasks (PRIMARY) | **PRIMARY** |
| Codex GPT-5.2 | **25** | Security, performance | SPECIALIZED |
| Gemini 2.5 Pro | **25** | Cross-validation | OPTIONAL |

---

## Quality-First Validation

```
Stage 1: CORRECTNESS → Syntax errors (BLOCKING)
Stage 2: QUALITY     → Type errors (BLOCKING)
Stage 2.5: SECURITY  → semgrep + gitleaks (BLOCKING)
Stage 3: CONSISTENCY → Linting (ADVISORY - not blocking)
```

### Quality Gates (v2.46)

| Language | Syntax | Types | Linting |
|----------|--------|-------|---------|
| TypeScript | ✓ | ✓ | ✓ (eslint) |
| Python | ✓ | ✓ (pyright) | ✓ (ruff) |
| Go | ✓ | ✓ (gotype) | ✓ (gofmt) |
| Rust | ✓ | ✓ (rustc) | ✓ (rustfmt) |
| Solidity | ✓ | - | ✓ (solhint) |
| Swift | ✓ | ✓ (swiftc) | ✓ (swiftformat) |
| JavaScript | ✓ | ✓ | ✓ (eslint) |
| JSON/YAML | ✓ | - | ✓ |

---

## Claude Code Task Primitive Integration

### Overview (v2.62)

Multi-Agent Ralph Loop fully integrates with Claude Code's **Task Primitive** architecture, enabling:

- **Unidirectional Sync**: Local `plan-state.json` syncs to Claude Code's global task storage
- **Parallelization Detection**: Auto-detect independent tasks that can run concurrently
- **Verification Subagents**: Automatic verification spawning after step completion
- **Context Hiding**: Reduce context pollution with background execution

### Task Primitive Hooks (3)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `global-task-sync.sh` | PostToolUse (TaskUpdate, TaskCreate) | Unidirectional sync: plan-state → global storage |
| `task-orchestration-optimizer.sh` | PreToolUse (Task) | Detect parallelization and context-hiding opportunities |
| `verification-subagent.sh` | PostToolUse (TaskUpdate) | Spawn verification subagent after step completion |

---

## Claude Code Skills Ecosystem

### Core Skills (9)

| Skill | Purpose |
|-------|---------|
| ask-questions-if-underspecified | Clarification and requirements gathering |
| codex-cli | OpenAI Codex integration for planning |
| openai-docs | Access OpenAI documentation |
| retrospective | Post-task analysis and improvements |
| task-classifier | 3-dimension task classification |
| compact | Manual context preservation |
| orchestrator | Full workflow orchestration |
| smart-fork | Session forking recommendations |
| crafting-effective-readmes | README writing with templates |

**Note**: Additional skills may be available in the global skills directory (~/.claude/skills/).

---

## Testing

### Running Tests

```bash
# Run all tests
./tests/run_tests.sh

# Run specific test category
./tests/run_tests.sh hooks          # Hook tests
./tests/run_tests.sh memory         # Memory tests
./tests/run_tests.sh security       # Security tests
./tests/run_tests.sh quality        # Quality gate tests

# Run swarm mode tests (v2.81.0)
bash tests/swarm-mode/test-swarm-mode-config.sh

# Run skills validation (v2.81.0)
bash .claude/scripts/validate-global-skills.sh
bash .claude/scripts/validate-all-orchestrator-skills.sh
```

### Test Categories

| Category | Location | Tests | Purpose |
|----------|----------|-------|---------|
| Hook Tests | `tests/test_hooks_*.py` | 15+ | Hook registration, output format |
| Memory Tests | `tests/test_memory_*.py` | 10+ | Memory search, episodic storage |
| Security Tests | `tests/test_security_*.py` | 8+ | Security validation, scanning |
| Integration Tests | `tests/test_v2_*.py` | 20+ | Full workflow integration |
| Quality Tests | `tests/test_quality_*.py` | 12+ | Linting, type checking |
| Swarm Mode Tests | `tests/swarm-mode/` | 44 | v2.81.0 swarm mode validation |
| Skills Validation | `.claude/scripts/validate-*.sh` | 33+ | v2.81.0 skills validation |
| Learning System | `tests/test_learning_system.py` | 39 | v2.59 learning system |

### Skills Validation System (v2.81.0) ✅ NEW

Multi-Agent Ralph Loop includes a comprehensive validation system for all 33 project skills, ensuring they work correctly across different repositories.

#### Skills Validation Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SKILLS VALIDATION SYSTEM                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Repository (.claude/skills/)                                    │
│  ├─ adversarial/                                                 │
│  ├─ codex-cli/                                                   │
│  ├─ gemini-cli/                                                  │
│  ├─ orchestrator/                                                │
│  ├─ loop/                                                        │
│  └─ ... (29 more skills)                                         │
│         ↓                                                         │
│  Symlink Synchronization                                         │
│  ~/.claude-sneakpeek/zai/config/skills/{skill} → repo           │
│         ↓                                                         │
│  Validation Scripts                                             │
│  ├─ validate-global-skills.sh (3 core skills)                   │
│  └─ validate-all-orchestrator-skills.sh (all 33 skills)         │
│         ↓                                                         │
│  Test Coverage                                                   │
│  ✓ Versioned in repository (33/33)                              │
│  ✓ Available globally (33/33)                                   │
│  ✓ Accessible from any directory (33/33)                        │
│  ✓ Following naming conventions (33/33)                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Skills Validation Tests

**Test 1: Repository Versioning**
- Validates all skills are versioned in `.claude/skills/`
- Checks for `skill.md` files
- Ensures no broken symlinks in repo

**Test 2: Global Installation**
- Verifies symlinks in `~/.claude-sneakpeek/zai/config/skills/`
- Validates symlink targets point to repository
- Checks for accessibility

**Test 3: Core Orchestrator Skills**
- Tests 10 core skills used by `/orchestrator`
- Ensures proper configuration
- Validates documentation exists

**Test 4: Cross-Repository Accessibility**
- Creates temporary directory
- Tests skills are accessible from outside repo
- Simulates usage in different projects

**Test 5: Configuration Inconsistencies**
- Detects skills versioned but not globally available
- Finds skills globally available but not versioned
- Reports synchronization issues

**Test 6: Naming Conventions**
- Validates `skill.md` naming (not `SKILL.md` or `skill.yaml`)
- Ensures consistency across all skills

#### Running Skills Validation

```bash
# Quick validation (3 core skills: adversarial, codex-cli, gemini-cli)
bash .claude/scripts/validate-global-skills.sh

# Complete validation (all 33 skills)
bash .claude/scripts/validate-all-orchestrator-skills.sh
```

#### Expected Output

```
=========================================
🔍 Multi-Agent Ralph Loop Skills Validator
=========================================

📊 Repository Skills: 33 total
🎯 Core Orchestrator Skills: 10

=========================================
📋 Test 1: Skills Versioned in Repository
=========================================

  ✓ adversarial (versioned)
  ✓ codex-cli (versioned)
  ✓ gemini-cli (versioned)
  ✓ orchestrator (versioned)
  ... (29 more)

Summary: 33/33 skills properly versioned

=========================================
📋 Test 2: Skills Installed Globally
=========================================

  ✓ adversarial (symlink → repo)
  ✓ codex-cli (symlink → repo)
  ✓ gemini-cli (symlink → repo)
  ... (30 more)

Summary: 33/33 skills available globally

=========================================
📊 Final Summary
=========================================

Repository:
  Total skills: 33
  Versioned: 33
  With skill.md: 33

Global Installation:
  Available globally: 33
  Symlinked to repo: 33

Core Orchestrator Skills:
  Total: 10
  Configured: 10
  Issues: 0

✅ ALL TESTS PASSED!
```

#### Validated Skills

**Core Orchestrator Skills (10/33)**
- ✅ `orchestrator` - Main orchestration workflow
- ✅ `task-classifier` - 3-dimension task classification
- ✅ `adversarial` - Multi-agent adversarial analysis
- ✅ `codex-cli` - OpenAI Codex CLI integration
- ✅ `gemini-cli` - Google Gemini CLI integration
- ✅ `loop` - Iterative execution until VERIFIED_DONE
- ✅ `parallel` - Parallel task execution
- ✅ `gates` - Quality gates validation
- ✅ `clarify` - Intensive AskUserQuestion workflow
- ✅ `retrospective` - Post-task analysis

**Additional Skills (23/33)**
- ✅ `ask-questions-if-underspecified`
- ✅ `attack-mutator`
- ✅ `audit`
- ✅ `bugs`
- ✅ `code-reviewer`
- ✅ `compact`
- ✅ `context7-usage`
- ✅ `crafting-effective-readmes`
- ✅ `defense-profiler`
- ✅ `edd`
- ✅ `glm-mcp`
- ✅ `kaizen`
- ✅ `minimax`
- ✅ `minimax-mcp-usage`
- ✅ `openai-docs`
- ✅ `quality-gates-parallel`
- ✅ `security`
- ✅ `smart-fork`
- ✅ `tap-explorer`
- ✅ `task-visualizer`
- ✅ `testing-anti-patterns`
- ✅ `vercel-react-best-practices`
- ✅ `worktree-pr`

#### Skills Pattern

All skills follow this synchronization pattern:

```
┌──────────────────────────────────────────────┐
│  Repository (.claude/skills/{skill}/)        │
│  ├─ skill.md (documentation)                │
│  ├─ references/ (optional docs)              │
│  └─ *.sh (optional scripts)                  │
└──────────────────┬───────────────────────────┘
                   │ Symlink
                   ▼
┌──────────────────────────────────────────────┐
│  Global (~/.claude-sneakpeek/.../skills/)    │
│  └─ {skill} → repository                    │
└──────────────────────────────────────────────┘
```

**Benefits**:
- Skills work in **any repository**
- Changes in repo automatically reflected globally
- Version controlled documentation
- Consistent across all projects

#### Testing Skills in Other Repositories

After validation, test skills in a different repository:

```bash
cd ~/GitHub/other-project

# All skills should work:
/adversarial src/
/codex-cli "Review this code"
/gemini-cli "Search latest docs"
/orchestrator "Implement feature X"
```

#### Troubleshooting Skills

**Skill not found in other repo:**

```bash
# Check global symlink
ls -la ~/.claude-sneakpeek/zai/config/skills/{skill}

# Verify target exists
readlink ~/.claude-sneakpeek/zai/config/skills/{skill}

# Re-run validation
bash .claude/scripts/validate-all-orchestrator-skills.sh
```

**Skill documentation missing:**

```bash
# Check skill.md exists
cat .claude/skills/{skill}/skill.md

# If missing, create from template
cp .claude/skills/adversarial/skill.md .claude/skills/{skill}/
```

#### CI/CD Integration

Add skills validation to your CI/CD pipeline:

```yaml
# .github/workflows/skills-validation.yml
name: Skills Validation

on: [push, pull_request]

jobs:
  validate-skills:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate All Skills
        run: |
          bash .claude/scripts/validate-all-orchestrator-skills.sh
```

#### Documentation

- [Skills CLAUDE.md](.claude/skills/CLAUDE.md) - Skills directory documentation
- [Validation Script](.claude/scripts/validate-all-orchestrator-skills.sh) - Complete validator
- [Skills Pattern](CLAUDE.md#repository-structure-v2810) - Architecture documentation

---

## Deployment

### Global Installation

```bash
# 1. Clone repository
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# 2. Run installer
./install.sh

# 3. Configure Swarm Mode (v2.81.0)
bash tests/swarm-mode/configure-swarm-mode.sh

# 4. Verify Swarm Mode
bash tests/swarm-mode/test-swarm-mode-config.sh

# 5. Restart Claude Code
```

### Configuration Locations

| Component | Location |
|-----------|----------|
| Global Settings | `~/.claude/settings.json` |
| Zai Settings | `~/.claude-sneakpeek/zai/config/settings.json` |
| Global Hooks | `~/.claude/hooks/*.sh` (74 files) |
| Global Agents | `~/.claude/agents/*.md` (35 files) |
| Global Skills | `~/.claude/skills/*/` |
| Ralph Config | `~/.ralph/` |
| Logs | `~/.ralph/logs/` |

---

## Troubleshooting

### Swarm Mode Not Working

**Error**: Teammates not spawning

**Solution**:
```bash
# Verify configuration
bash tests/swarm-mode/test-swarm-mode-config.sh

# Check agent environment variables
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.env'

# Reconfigure if needed
bash tests/swarm-mode/configure-swarm-mode.sh
```

### Hooks Not Firing

**Error**: Hooks not executing on expected events

**Solution**:
```bash
# Verify hook registration
cat ~/.claude/settings.json | jq '.hooks.PostToolUse[].hooks[].command'

# Check hook permissions
ls -la ~/.claude/hooks/quality-gates-v2.sh

# Review hook logs
tail -50 ~/.ralph/logs/*.log
```

### Quality Gates Failing

**Error**: Quality gates blocking valid code

**Solution**:
```bash
# Run gates with verbose output
/gates --verbose

# Skip consistency check (not recommended)
/gates --no-consistency
```

---

## Contributing

### Development Setup

```bash
# Fork the repository
git clone https://github.com/YOUR-USER/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Create feature branch
git checkout -b feature/swarm-mode-improvement

# Make changes
# ...

# Test changes
./tests/run_tests.sh
bash tests/swarm-mode/test-swarm-mode-config.sh

# Commit (use conventional commits)
git commit -m "feat(swarm): add new swarm coordination feature"

# Push and create PR
git push origin feature/swarm-mode-improvement
```

### Code Style

- **Shell scripts**: Follow Google Shell Style Guide
- **Python scripts**: Follow PEP 8, use ruff for linting
- **JSON**: Valid JSON with 2-space indentation
- **Documentation**: English only, clear and concise

---

## License

This project is licensed under the BSL 1.1 License.

---

## Resources

| Resource | Link |
|----------|------|
| Repository | https://github.com/alfredolopez80/multi-agent-ralph-loop |
| CLAUDE.md | [Project Instructions](CLAUDE.md) |
| AGENTS.md | [Agent Documentation](AGENTS.md) |
| CHANGELOG.md | [Version History](CHANGELOG.md) |
| Swarm Mode Guide | [Spanish Guide](tests/swarm-mode/COMO_USAR_SWARM_MODE_CLAUDE_ZAI.md) |
| Architecture | [docs/architecture/](docs/architecture/) |
| Security | [docs/security/](docs/security/) |

---

**Version**: 2.81.0
**Last Updated**: 2026-01-29
**Next Review**: 2026-02-29
