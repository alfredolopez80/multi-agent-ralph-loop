# Multi-Agent Ralph Wiggum v2.62.3

> "Me fail English? That's unpossible!" - Ralph Wiggum

![Version](https://img.shields.io/badge/version-2.62.3-blue)
![License](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)
![Tests](https://img.shields.io/badge/tests-103%20passed-green)
![Hooks](https://img.shields.io/badge/hooks-52%20registered-green)
![Skills](https://img.shields.io/badge/skills-266%2B-orange)
![Error Traps](https://img.shields.io/badge/error%20traps-44%2F52-brightgreen)

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Tech Stack](#tech-stack)
4. [Prerequisites](#prerequisites)
5. [Getting Started](#getting-started)
6. [Architecture](#architecture)
   - [Directory Structure](#directory-structure)
   - [Core Workflow](#core-workflow)
   - [3-Dimension Classification](#3-dimension-classification)
   - [Memory Architecture](#memory-architecture)
   - [Hooks System](#hooks-system)
   - [Agent System](#agent-system)
7. [Commands Reference](#commands-reference)
8. [Ralph Loop Pattern](#ralph-loop-pattern)
9. [Quality-First Validation](#quality-first-validation)
10. [Claude Code Skills Ecosystem](#claude-code-skills-ecosystem)
11. [Testing](#testing)
12. [Deployment](#deployment)
13. [Troubleshooting](#troubleshooting)
14. [Contributing](#contributing)
15. [License](#license)
16. [Resources](#resources)

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
- **Security Hardening (v2.58)**: SEC-034 security hooks, anti-pattern detection, adversarial validation
- **Learning System v2.59**: 319 procedural rules with confidence scoring, feedback loop, and auto-cleanup
- **Hook System Audit (v2.60)**: Reduced hooks from 64 to 52, removed deprecated scripts, adversarial validation
- **Smart Skill Reminder v2.0 (v2.60)**: Context-aware skill suggestions with session gating and rate limiting
- **Adversarial Council v2.61**: LLM-council enhanced multi-model review with Python orchestration, provider-specific extraction, exponential backoff, and security hardening (command allowlist, path traversal prevention)
- **Adversarial Hook Audit (v2.62)**: Comprehensive multi-model audit (Claude Opus, Sonnet, MiniMax, Codex, Gemini) with iterative loop until zero issues
- **Schema v2 Compliance (v2.62.3)**: Plan-state schema updated with `oneOf` for backward compatibility (v1 array + v2 object formats)
- **Error Traps (v2.62.3)**: All 44 registered hooks now have proper error traps guaranteeing valid JSON output
- **Race Condition Fixes (v2.62.3)**: P0/P1 memory system race conditions fixed with `flock` atomic writes
- **Security Audit**: Comprehensive API key leak detection validated by Codex, Gemini, and Claude Opus (9/10 security score)
- **Claude Code Skills Ecosystem**: 266+ specialized skills including marketing (23 skills), documentation generation, and React best practices from Vercel

---

## Key Features

### Core Orchestration

| Feature | Description | Version |
|---------|-------------|---------|
| **Smart Memory Search** | Parallel memory search across semantic, episodic, procedural memories | v2.49 |
| **RLM-Inspired Routing** | 3-dimension classification (Complexity + Density + Context) | v2.46 |
| **Quality-First Validation** | Blocking correctness/quality, advisory consistency | v2.46 |
| **Checkpoint System** | LangGraph-style "time travel" for orchestration state | v2.51 |
| **Handoff API** | OpenAI Agents SDK-style agent-to-agent transfers | v2.51 |
| **Event-Driven Engine** | LangGraph-style event bus with WAIT-ALL barriers | v2.51 |
| **Local Observability** | Query-based status and traceability without external services | v2.52 |

### Memory System

| Memory Type | Purpose | Storage | TTL |
|-------------|---------|---------|-----|
| **Semantic** | Facts, preferences, learned rules | `~/.ralph/memory/semantic.json` | Never |
| **Episodic** | Experiences, decisions, patterns | `~/.ralph/episodes/` | 30 days |
| **Procedural** | Learned behaviors, best practices | `~/.ralph/procedural/rules.json` | Never |
| **Agent-Scoped** | Isolated buffers per agent | `~/.ralph/agent-memory/<agent>/` | Varies |

### Auto-Learning (v2.50-v2.59)

| Component | Purpose | Version |
|-----------|---------|---------|
| **Repository Learner** | Extract patterns from quality repositories via AST | v2.50 |
| **Repo Curator** | Discover, score, and curate quality repos | v2.55 |
| **Auto-Learning Hooks** | Detect knowledge gaps proactively | v2.55 |
| **Learning System v2.59** | 319 rules, confidence scoring, feedback loop | v2.59 |

### Security (v2.58)

| Component | Purpose |
|-----------|---------|
| **SEC-034 Security Hooks** | Comprehensive security validation |
| **sec-context-validate.sh** | Security context validation (BLOCKING) |
| **Anti-Pattern Detection** | 34 security anti-patterns detected |

---

## Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Base Platform** | Claude Code CLI | AI orchestration engine |
| **Shell Environment** | Bash 5.x + zsh | Hooks automation |
| **Scripting** | Python 3.11+ | Utility scripts, memory management |
| **Configuration** | JSON + YAML | Settings, schemas, rules |
| **Memory Storage** | JSON + SQLite FTS | Semantic, episodic, procedural memory |
| **Code Analysis** | AST-grep | Structural code search |
| **MCP Servers** | Context7, Playwright, MiniMax, Blender | Documentation, testing, AI analysis |
| **CLI Tools** | Codex CLI, Gemini CLI, GitHub CLI | Multi-model orchestration |

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
git clone https://github.com/your-org/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Run the global installer
./install.sh

# The installer will:
# 1. Backup existing ~/.claude/ configuration
# 2. Install ralph CLI to ~/.local/bin/
# 3. Copy hooks, agents, commands, skills to ~/.claude/
# 4. Register hooks in ~/.claude/settings.json
# 5. Initialize Ralph memory system in ~/.ralph/

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
# Should output: 52 (after v2.60 cleanup)

# Test quality gates
/gates
# Should show: Quality gates ready
```

### Quick Start Commands

```bash
# 1. Full orchestration with classification
/orchestrator "Implement OAuth2 authentication with JWT tokens"

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
multi-agent-ralph-loop/
├── .claude/                      # Claude Code configuration
│   ├── agents/                   # Specialized agents (11 default)
│   │   ├── orchestrator.sh       # Main orchestration agent
│   │   ├── security-auditor.sh   # Security-focused agent
│   │   ├── debugger.sh           # Bug detection/fix agent
│   │   ├── code-reviewer.sh      # Code review agent
│   │   ├── test-architect.sh     # Testing agent
│   │   ├── refactorer.sh         # Refactoring agent
│   │   ├── frontend-reviewer.sh  # UI/UX agent
│   │   ├── docs-writer.sh        # Documentation agent
│   │   ├── minimax-reviewer.sh   # MiniMax validation
│   │   ├── repository-learner.sh # Learning agent
│   │   └── repo-curator.sh       # Curation agent
│   ├── commands/                 # Slash commands
│   ├── hooks/                    # Hook scripts (52 registered, v2.60)
│   │   ├── quality-gates-v2.sh   # Quality validation (BLOCKING)
│   │   ├── sec-context-validate.sh # Security validation (BLOCKING)
│   │   ├── smart-memory-search.sh # Memory search
│   │   ├── procedural-inject.sh  # Rules injection
│   │   ├── orchestrator-auto-learn.sh # Auto-learning
│   │   ├── smart-skill-reminder.sh # Context-aware skill suggestions (v2.0)
│   │   ├── skill-pre-warm.sh     # Pre-warm skills on session start
│   │   └── ... (45 more hooks)
│   ├── skills/                   # Claude Code skills (266+)
│   │   ├── marketing-ideas/      # 140 marketing strategies
│   │   ├── marketingskills/      # 23 marketing skills
│   │   ├── react-best-practices/ # React optimization
│   │   └── readme/               # Documentation generation
│   ├── settings.json             # Global hooks configuration
│   └── plan-state.json           # Current orchestration state
├── scripts/                      # Utility scripts (40+)
│   ├── ralph*                    # Main CLI commands
│   ├── curator-*                 # Repo curation scripts
│   ├── memory-*                  # Memory management scripts
│   ├── handoff.sh                # Agent transfer script
│   ├── event-bus.sh              # Event-driven engine
│   ├── checkpoint-*.sh           # Checkpoint management
│   ├── install-security-tools.sh # Security tools installer
│   └── validate-hooks.sh         # Hook validation
├── tests/                        # Test suite (74+ tests)
│   ├── test_hooks_*.py           # Hook tests
│   ├── test_memory_*.py          # Memory tests
│   ├── test_v2_*.sh              # Integration tests
│   └── run_tests.sh              # Test runner
├── config/                       # Configuration
├── docs/                         # Documentation
├── install.sh                    # Global installer
├── uninstall.sh                  # Uninstaller
├── CLAUDE.md                     # Project instructions
├── AGENTS.md                     # Agent documentation
├── README.md                     # This file
└── CHANGELOG.md                  # Version history
```

### Core Workflow (12 Steps) - v2.46

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

### 3-Dimension Classification (RLM)

| Dimension | Values | Purpose |
|-----------|--------|---------|
| **Complexity** | 1-10 | Scope, risk, ambiguity |
| **Information Density** | CONSTANT / LINEAR / QUADRATIC | How answer scales with input |
| **Context Requirement** | FITS / CHUNKED / RECURSIVE | Whether decomposition needed |

#### Workflow Routing

| Density | Context | Complexity | Route | Model | Max Iter |
|---------|---------|------------|-------|-------|----------|
| CONSTANT | FITS | 1-3 | **FAST_PATH** | sonnet | 3 |
| CONSTANT | FITS | 4-10 | STANDARD | minimax-m2.1 | 25 |
| LINEAR | CHUNKED | ANY | PARALLEL_CHUNKS | sonnet | 15/chunk |
| QUADRATIC | ANY | ANY | RECURSIVE_DECOMPOSE | opus | 15/sub |

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

**Process**:
1. Acquire repository via git clone or GitHub API
2. Analyze code using AST-based pattern extraction
3. Classify patterns (error_handling, async_patterns, type_safety, architecture, testing, security)
4. Generate procedural rules with confidence scores
5. Enrich `~/.ralph/procedural/rules.json` with deduplication

### Repo Curator (v2.55)

Discovers, scores, and curates quality repositories for learning.

```bash
# Full pipeline (economic tier, default)
/curator full --type backend --lang typescript

# Discovery with options
/curator discovery --query "microservice" --max-results 200 --tier free

# Scoring with context relevance (v2.55)
/curator scoring --context "error handling,retry,resilience"

# Custom ranking
/curator rank --top-n 15 --max-per-org 3

# Approve/reject repos
/curator approve nestjs/nest
/curator approve --all
/curator reject some/repo --reason "Low test coverage"

# Execute learning
/curator learn --type backend --lang typescript
```

#### Pricing Tiers

| Tier | Cost | Features |
|------|------|----------|
| `--tier free` | $0.00 | GitHub API + local scoring |
| `--tier economic` | ~$0.30 | + OpenSSF + MiniMax (DEFAULT) |
| `--tier full` | ~$0.95 | + Claude + Codex adversarial |

### Learning System v2.59

The Learning System automatically extracts and stores behavioral patterns for continuous improvement.

```bash
# Check learning system health
ralph health

# View procedural rules count
ralph memory-index --rules

# Feedback loop
ralph-feedback record --rule-id err-001 --used-in task-123
ralph-feedback complete --rule-id err-001 --success true
ralph-feedback calibrate     # Run confidence calibration

# Auto-cleanup old rules
memory-auto-cleanup.py run

# Convert high-confidence rules to native behavior
convert-high-confidence-rules.py list
convert-high-confidence-rules.py convert --all
```

#### Procedural Rules Structure

```json
{
  "version": "2.59.0",
  "rules": [
    {
      "rule_id": "hook-json-format-sec039",
      "trigger": "Writing or modifying Claude Code hooks",
      "behavior": "CRITICAL: Use correct JSON format per hook type...",
      "confidence": 1.0,
      "source_repo": "claude-code-official-docs",
      "tags": ["security", "hooks", "json-format"],
      "usage_count": 42,
      "success_count": 40,
      "success_rate": 0.95
    }
  ]
}
```

**Statistics (v2.59.0)**:
- Total rules: 319
- High confidence (≥0.9): 47
- Average confidence: 0.78
- Success rate: 95%

### Hook System Audit (v2.60)

Comprehensive audit and cleanup of the hooks system with adversarial validation.

**Results**:
- Scripts before audit: 64
- Registered hooks: 52
- Deleted (deprecated): 8
- Archived (utilities): 5
- Kept (libraries): 3

#### Smart Skill Reminder v2.0

Context-aware skill suggestions that fire **before** writing code (PreToolUse).

```bash
# Replaced skill-reminder.sh (v1.0) with smart-skill-reminder.sh (v2.0)
# Key improvements:
# 1. Fires on PreToolUse (BEFORE code is written, not after)
# 2. Session gating: only reminds once per session
# 3. Context-aware: suggests specific skills based on file type/path
# 4. Rate limiting: respects 30-minute cooldown period
# 5. Skill invocation detection: skips if skill was recently used
```

**Priority Order for Suggestions**:
1. **Test files** (`*test*`, `*spec*`) → `/test-driven-development`
2. **Security files** (`*auth*`, `*token*`, `*payment*`) → `/security-loop`
3. **Language-specific** (`.py`, `.ts`, `.sh`, `.sol`) → Language skill
4. **Architecture files** (`Dockerfile`, `.tf`, `k8s`) → Infrastructure skill
5. **Directory patterns** (`api/`, `components/`) → Domain skill

#### Deleted Scripts (8)

| Script | Reason |
|--------|--------|
| `skill-reminder.sh` | Replaced by `smart-skill-reminder.sh` v2.0 |
| `quality-gates.sh` | Replaced by `quality-gates-v2.sh` |
| `curator-trigger.sh` | Replaced by `curator-suggestion.sh` |
| `test-sec-context-hook.sh` | Test suite, not production |
| `orchestrator-helper.sh` | Obsolete |
| `state-sync.sh` | Obsolete |
| `post-commit-command-verify.sh` | Never configured |
| `pre-commit-command-validation.sh` | Never configured |

#### Archived Scripts (5)

Moved to `~/.claude/hooks-archive/utilities/`:
- `cleanup-secrets-db.js` - Database cleanup utility
- `sanitize-secrets.js` - Secrets sanitization
- `procedural-forget.sh` - Memory cleanup
- `sentry-check-status.sh` - Sentry integration
- `sentry-correlation.sh` - Sentry correlation

#### Library Scripts (3)

Kept as dependencies for other hooks:
- `detect-environment.sh` - Used by context-warning.sh, pre-compact-handoff.sh
- `plan-state-init.sh` - Used by auto-plan-state.sh
- `semantic-write-helper.sh` - Used by semantic-realtime-extractor.sh

#### Skill Pre-Warm (Fixed)

The `skill-pre-warm.sh` hook now correctly finds all skills:

```bash
# Before fix: 9/10 skills pre-warmed (repository-learner failed)
# After fix: 10/10 skills pre-warmed

# Fix applied (GAP-SKILL-002):
mkdir -p ~/.claude/skills/repository-learner
mv ~/.claude/skills/repository-learner.md ~/.claude/skills/repository-learner/SKILL.md
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

### Registered Hooks (52 total) - v2.60

#### PreToolUse Hooks

| Hook | Matcher | Purpose |
|------|---------|---------|
| `git-safety-guard.py` | Bash | Validate git commands before execution |
| `skill-validator.sh` | Skill | Validate skill usage |
| `orchestrator-auto-learn.sh` | Task | Detect knowledge gaps, recommend learning |
| `fast-path-check.sh` | Task | Detect trivial tasks → FAST_PATH |
| `inject-session-context.sh` | Task | Restore session context from ledger |
| `smart-memory-search.sh` | Task | Parallel search across memory sources |
| `procedural-inject.sh` | Task | Inject relevant procedural rules |
| `agent-memory-auto-init.sh` | Task | Auto-initialize agent memory buffers |
| `lsa-pre-step.sh` | Edit/Write | Pre-step LSA verification |
| `checkpoint-smart-save.sh` | Edit/Write | Smart checkpoints on risky edits |
| `smart-skill-reminder.sh` | Edit/Write | Context-aware skill suggestions (v2.0) |

#### PostToolUse Hooks

| Hook | Matcher | Purpose |
|------|---------|---------|
| `quality-gates-v2.sh` | Edit/Write | Quality-first validation (BLOCKING) |
| `sec-context-validate.sh` | Edit/Write | Security context validation (BLOCKING) |
| `checkpoint-auto-save.sh` | Edit/Write | Auto-save checkpoints |
| `plan-sync-post-step.sh` | Edit/Write | Sync plan state after edits |
| `progress-tracker.sh` | Edit/Write | Track progress (every 5 ops) |
| `decision-extractor.sh` | Edit/Write | Extract architectural decisions |
| `status-auto-check.sh` | Edit/Write | Show status every 5 ops |
| `semantic-realtime-extractor.sh` | Edit/Write | Extract semantic facts in real-time |
| `episodic-auto-convert.sh` | Edit/Write | Convert experiences to episodic memory |

### Hook Output Format

#### PreToolUse Output

```json
{
  "continue": true,
  "additionalContext": "Injected context for the tool execution"
}
```

**Blocking**:
```json
{
  "continue": false,
  "reason": "Why the tool is blocked"
}
```

#### PostToolUse Output

```json
{
  "hookSpecificOutput": {
    "additionalContext": "Additional context for Claude"
  }
}
```

---

## Agent System

### Default Agents (11)

| Agent | Model | Purpose |
|-------|-------|---------|
| `@orchestrator` | opus | Coordinator, planning, classification, delegation |
| `@security-auditor` | opus | Security, vulnerability scan, code review |
| `@debugger` | opus | Debugging, error analysis, fix generation |
| `@code-reviewer` | sonnet | Code review, pattern analysis, quality check |
| `@test-architect` | sonnet | Testing, test generation, coverage analysis |
| `@refactorer` | sonnet | Refactoring, pattern application |
| `@frontend-reviewer` | sonnet | Frontend, UI review, accessibility |
| `@docs-writer` | minimax | Documentation, README, API docs |
| `@minimax-reviewer` | minimax | Validation, quick review, second opinion |
| `@repository-learner` | sonnet | Learning, pattern extraction, rule generation |
| `@repo-curator` | sonnet | Curation, scoring, discovery |

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

### Agent-Scoped Memory (v2.51)

LlamaIndex AgentWorkflow-style isolated memory buffers per agent.

```bash
# Initialize memory for an agent
ralph agent-memory init security-auditor

# Write to agent's memory
ralph agent-memory write security-auditor semantic "Found SQL injection in auth.py:42"
ralph agent-memory write security-auditor working "Currently analyzing user input validation"

# Read agent's memory
ralph agent-memory read security-auditor

# Transfer memory during handoff
ralph agent-memory transfer security-auditor code-reviewer relevant
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

# Learning system (v2.59)
ralph-feedback record --rule-id err-001 --used-in task-123
ralph-feedback complete --rule-id err-001 --success true
ralph-feedback calibrate     # Run confidence calibration
```

### Repository Learning Commands

```bash
# Learn from GitHub repo
repo-learn https://github.com/python/cpython
repo-learn https://github.com/fastapi/fastapi --category error_handling

# Curator pipeline
ralph curator full --type backend --lang typescript
ralph curator discovery --query "microservice"
ralph curator scoring --context "error handling,retry"
ralph curator rank --top-n 15
ralph curator show --type backend
ralph curator approve nestjs/nest
ralph curator learn --all
```

### Checkpoint Commands (v2.51)

```bash
# Save state before risky operation
ralph checkpoint save "before-auth-refactor" "Pre-auth changes"

# List all checkpoints
ralph checkpoint list

# Restore if something goes wrong
ralph checkpoint restore "before-auth-refactor"

# Compare checkpoint vs current
ralph checkpoint diff "before-auth-refactor"
```

### Event-Driven Engine Commands (v2.51)

```bash
# Emit an event
ralph events emit step.complete '{"step_id": "step1"}'

# Subscribe to events
ralph events subscribe phase.complete /path/to/handler.sh

# Check barrier status (WAIT-ALL)
ralph events barrier check phase-1
ralph events barrier wait phase-1 300

# Advance to next phase
ralph events advance phase-2

# View event history
ralph events history 20
```

### Observability Commands (v2.52)

```bash
# Full orchestration status
ralph status
ralph status --compact       # One-line summary
ralph status --steps         # Detailed breakdown
ralph status --json          # JSON for scripts

# Traceability
ralph trace show 30          # Recent events
ralph trace search "handoff" # Search events
ralph trace timeline         # Visual timeline
ralph trace export csv ./report.csv
ralph trace summary          # Session summary
```

### Schema Migration Commands (v2.51)

```bash
# Check if migration needed
ralph migrate check

# Execute migration
ralph migrate run

# Preview migration
ralph migrate dry-run
```

### Security Commands

```bash
# Security audit
ralph security src/          # Full audit
ralph security-loop src/     # Iterative audit

# Security tools installation
install-security-tools.sh    # Install semgrep, gitleaks
```

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

### Iteration Limits

| Model | Max Iterations | Use Case |
|-------|----------------|----------|
| Claude (Sonnet/Opus) | **25** | Complex reasoning |
| MiniMax M2.1 | **50** | Standard (2x) |
| MiniMax-lightning | **100** | Extended (4x) |

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

## Claude Code Skills Ecosystem

### Available Skills (266+)

| Skill Category | Count | Purpose |
|----------------|-------|---------|
| Marketing | 140+ | Marketing strategies, content ideas |
| Documentation | 50+ | README generation, API docs |
| React | 40+ | Best practices from Vercel |
| Security | 25+ | Security patterns, validation |
| Testing | 20+ | Test patterns, coverage |
| Architecture | 15+ | Design patterns, clean code |

### Skill Usage

```bash
# Skills are auto-invoked based on task context
# Manual invocation:
Skill: marketing-ideas
Topic: Social media campaign for product launch

# Smart skill reminder (v2.0) suggests relevant skills
# based on file context before writing code:
#
# Example suggestions:
# - test_auth.py → "/test-driven-development for test files"
# - src/auth/login.ts → "/security-loop for security-sensitive code"
# - components/Button.tsx → "/frontend-mobile-development:frontend-developer for UI components"
```

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

# Run individual test
python -m pytest tests/test_learning_system.py -v
bash tests/test_v2_47_smart_memory.py
```

### Test Categories

| Category | Location | Tests | Purpose |
|----------|----------|-------|---------|
| Hook Tests | `tests/test_hooks_*.py` | 15+ | Hook registration, output format |
| Memory Tests | `tests/test_memory_*.py` | 10+ | Memory search, episodic storage |
| Security Tests | `tests/test_security_*.py` | 8+ | Security validation, scanning |
| Integration Tests | `tests/test_v2_*.py` | 20+ | Full workflow integration |
| Quality Tests | `tests/test_quality_*.py` | 12+ | Linting, type checking |
| Learning System | `tests/test_learning_system.py` | 39 | v2.59 learning system |

### Test Coverage

```bash
# Generate coverage report
./tests/run_tests.sh --coverage

# View coverage
cat .coverage/index.html
```

---

## Deployment

### Global Installation

The system is designed for **global installation** via Claude Code:

```bash
# 1. Clone repository
git clone https://github.com/your-org/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# 2. Run installer (one-time)
./install.sh

# 3. Restart Claude Code
# New hooks, agents, and commands are now available
```

### Updating

```bash
# Pull latest changes
git pull origin main

# Re-run installer (preserves settings)
./install.sh

# Or update specific components
ralph sync global  # Sync global configuration
```

### Configuration Locations

| Component | Location |
|-----------|----------|
| Global Settings | `~/.claude/settings.json` |
| Global Hooks | `~/.claude/hooks/*.sh` |
| Global Agents | `~/.claude/agents/*.sh` |
| Global Skills | `~/.claude/skills/*/` |
| Ralph Config | `~/.ralph/` |
| Logs | `~/.ralph/logs/` |

---

## Troubleshooting

### Hooks Not Firing

**Error**: Hooks not executing on expected events

**Solution**:
1. Check hook is registered in `~/.claude/settings.json`
2. Verify matcher pattern matches the tool name
3. Check hook has execute permissions: `chmod +x ~/.claude/hooks/*.sh`
4. Review hook logs: `tail -50 ~/.ralph/logs/*.log`

```bash
# Verify hook registration
cat ~/.claude/settings.json | jq '.hooks.PostToolUse[].hooks[].command'

# Check hook permissions
ls -la ~/.claude/hooks/quality-gates-v2.sh
```

### Quality Gates Failing

**Error**: Quality gates blocking valid code

**Solution**:
1. Check which stage is failing: CORRECTNESS, QUALITY, or CONSISTENCY
2. Review specific error message
3. Some stages are ADVISORY (CONSISTENCY) and don't block

```bash
# Run gates with verbose output
/gates --verbose

# Skip consistency check (not recommended for production)
/gates --no-consistency
```

### Memory Search Not Returning Results

**Error**: Smart memory search returns empty context

**Solution**:
1. Verify claude-mem MCP is configured
2. Check memory files exist
3. Review search logs

```bash
# Check memory files
ls -la ~/.ralph/memory/
ls -la ~/.ralph/episodes/

# Test memory search manually
ralph memory-search "test query"

# Check claude-mem MCP
claude-mem search "test query"
```

### Context Preservation Issues

**Error**: Session context lost after compaction

**Solution**:
1. Verify ledger was created: `ls ~/.ralph/ledgers/`
2. Check SessionStart hook is registered
3. Review ledger content

```bash
# List recent ledgers
ls -la ~/.ralph/ledgers/ | tail -10

# View ledger content
cat ~/.ralph/ledgers/CONTINUITY_RALPH-*.md | head -50
```

### Installation Failures

**Error**: install.sh fails with missing dependencies

**Solution**:
```bash
# Install required dependencies
brew install jq curl git

# Retry installation
./install.sh --dry-run  # Preview first
./install.sh
```

---

## Contributing

### Development Setup

```bash
# Fork the repository
# Clone your fork
git clone https://github.com/YOUR-USER/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Create feature branch
git checkout -b feature/new-hook

# Make changes
# ...

# Test changes
./tests/run_tests.sh

# Commit (use conventional commits)
git commit -m "feat(hooks): add new security hook"

# Push and create PR
git push origin feature/new-hook
```

### Adding New Hooks

1. Create hook script in `~/.claude/hooks/`
2. Add to `~/.claude/settings.json` under appropriate event type
3. Add tests in `tests/test_hooks_*.py`
4. Document in CLAUDE.md and AGENTS.md

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
| Repository | https://github.com/your-org/multi-agent-ralph-loop |
| CLAUDE.md | [Project Instructions](CLAUDE.md) |
| AGENTS.md | [Agent Documentation](AGENTS.md) |
| CHANGELOG.md | [Version History](CHANGELOG.md) |
| Architecture | [ARCHITECTURE_DIAGRAM_v2.52.0.md](ARCHITECTURE_DIAGRAM_v2.52.0.md) |
| Security Audit | [security-audit-v2.45.1.md](security-audit-v2.45.1.md) |

---

**Version**: 2.60.0
**Last Updated**: 2026-01-22
**Next Review**: 2026-02-22
