# Multi-Agent Ralph Wiggum

> "Me fail English? That's unpossible!" - Ralph Wiggum

![Version](https://img.shields.io/badge/v2.69-blue) ![Tests](https://img.shields.io/badge/903_tests-passing-brightgreen) ![License](https://img.shields.io/badge/BSL_1.1-orange)

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
7. [Multi-Model Support (v2.69)](#multi-model-support-v269)
8. [Dynamic Contexts System (v2.63)](#dynamic-contexts-system-v263)
9. [Eval-Driven Development (v2.64)](#eval-driven-development-v264)
10. [Plan Lifecycle Management (v2.65)](#plan-lifecycle-management-v265)
11. [Commands Reference](#commands-reference)
12. [Ralph Loop Pattern](#ralph-loop-pattern)
13. [Quality-First Validation](#quality-first-validation)
14. [Claude Code Task Primitive Integration](#claude-code-task-primitive-integration)
15. [Claude Code Skills Ecosystem](#claude-code-skills-ecosystem)
16. [Testing](#testing)
17. [Deployment](#deployment)
18. [Troubleshooting](#troubleshooting)
19. [Contributing](#contributing)
20. [License](#license)
21. [Resources](#resources)

---

## Overview

Ralph coordinates **multiple AI models** (Claude Opus/Sonnet/Haiku, MiniMax M2.1, Codex GPT-5.2, Gemini 2.5 Pro, GLM-4.7) to produce validated code. Rather than trust one model's output, it runs them in parallel with quality gates.

The core idea: **execute → validate → iterate** until the code passes.

### What It Does

- **Multi-model orchestration** — Claude, Codex, Gemini, MiniMax, **GLM-4.7** working together
- **4-Model Adversarial Council** — Codex + Claude + Gemini + **GLM-4.7** for comprehensive review
- **Quality gates** — 9 languages supported (TS, Python, Go, Rust, Solidity, etc.)
- **Memory system** — Semantic, episodic, procedural memory with 30-day TTL
- **67 hooks** (66 bash + 1 python) — Automated validation, checkpoints, context preservation (80 event registrations)
- **8 core skills** — Specialized capabilities for common tasks (39 command shortcuts)
- **Dynamic contexts** — Switch between dev, review, research, debug modes
- **Statusline Ralph** — Real-time context tracking with claude-hud v0.0.6
- **GLM-4.7 Coding API** — Direct access via `/glm-4.7` skill with reasoning model support
- **GLM Web Search** — Real-time web search via `/glm-web-search` skill

See [CHANGELOG.md](CHANGELOG.md) for version history

---

## Key Features

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

### Learning

Ralph learns from repositories you point it at:
- Extracts patterns via AST analysis
- Scores and curates repos by quality
- Stores 300+ procedural rules with confidence scores

### Security

Based on [sec-context](https://github.com/Arcanum-Sec/sec-context):
- 27 anti-patterns checked
- 20+ CWE references
- Blocks on security issues (not advisory)

---

## Tech Stack

- **Claude Code CLI** — Base orchestration
- **Multi-Model AI** — Claude Opus/Sonnet/Haiku, MiniMax M2.1, Codex GPT-5.2, Gemini 2.5 Pro
- **GLM-4.7 MCP Ecosystem** — Vision, image analysis, web search, repository knowledge
- **Bash/zsh** — 66 bash hooks + 1 Python hook for automation
- **Python 3.11+** — Utility scripts
- **JSON** — Configuration, memory storage
- **26 MCP servers** — Context7, Playwright, GLM-4.7 (4 new), and more

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
# Should output: 63 (after v2.68.23 updates)

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
│   ├── hooks/                    # Hook scripts (63 registered, v2.68.23)
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

### Registered Hooks (63 total) - v2.68.23

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
| `task-orchestration-optimizer.sh` | Task | Detect parallelization and context-hiding opportunities |
| `lsa-pre-step.sh` | Edit/Write | Pre-step LSA verification |
| `repo-boundary-guard.sh` | Edit/Write/Bash | Prevent accidental work in external repositories |
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
| `global-task-sync.sh` | TaskUpdate/TaskCreate | Unidirectional sync: plan-state → global storage |
| `verification-subagent.sh` | TaskUpdate | Spawn verification subagent after step completion |

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

## Multi-Model Support (v2.69)

### Overview

Ralph supports **multiple AI models** for optimal cost/performance trade-offs. Each model is selected based on task complexity, cost constraints, and specific capabilities required.

> **v2.69 Update**: GLM-4.7 now integrated as 4th planner in Adversarial Council via Coding API. New standalone skills `/glm-4.7` and `/glm-web-search` for direct model access.

### Supported Models

| Model | Provider | Relative Cost | Use Case | Context |
|-------|----------|---------------|----------|---------|
| **Claude Opus** | Anthropic | 15x | Complex reasoning, security audits, architecture design | 200K tokens |
| **Claude Sonnet** | Anthropic | 5x | Standard tasks, implementation, code review | 200K tokens |
| **Claude Haiku** | Anthropic | 1x | Fast simple tasks, quick iterations | 200K tokens |
| **MiniMax M2.1** | MiniMax | **0.08x** | Validation, second opinion, extended loops | Large |
| **Codex GPT-5.2** | OpenAI | Variable | Code generation, refactoring, deep analysis | Large |
| **Gemini 2.5 Pro** | Google | Variable | Cross-validation, web search grounding, codebase analysis | 1M tokens |
| **GLM-4.7** | Z.AI | **~0.15x** | Reasoning review, web search, Chinese language | Large |

### MiniMax M2.1 - Cost-Effective Validation

**92% cost reduction** compared to Claude Sonnet while maintaining high quality.

**Use Cases**:
- Extended Ralph Loop iterations (up to 100 vs 25 with Claude)
- Validation and quality gates
- Second opinion reviews
- Rapid prototyping and batch operations

**Usage**:
```bash
# Automatic routing for validation
/loop "validate all type errors"  # Uses MiniMax for cost efficiency

# Manual invocation
/minimax-review "review this code for potential issues"
```

### GLM-4.7 - Reasoning & Cost-Effective Review (v2.69)

**Integrated via Coding API** (`/api/coding/paas/v4`) which uses plan quota instead of paas balance.

#### Standalone Skills

| Skill | Purpose | Usage |
|-------|---------|-------|
| `/glm-4.7` | Direct GLM-4.7 queries | Code review, analysis, second opinion |
| `/glm-web-search` | Web search with GLM | Real-time information retrieval |

**Skill Examples**:
```bash
# Direct query
/glm-4.7 "Review this authentication code for security"

# Code file review
~/.claude/skills/glm-4.7/glm-query.sh --code src/auth.ts "Find vulnerabilities"

# Web search
/glm-web-search "TypeScript best practices 2026"

# Custom system prompt
~/.claude/skills/glm-4.7/glm-query.sh --system "You are a security auditor" "Audit this"
```

#### GLM Response Handling

GLM-4.7 is a **reasoning model** - responses may be in:
- `choices[0].message.content` (standard responses)
- `choices[0].message.reasoning_content` (reasoning chain)

Both are automatically extracted by the skills and hooks.

#### MCP Servers (4)

| Server | Tools | Capabilities |
|--------|-------|--------------|
| **zai-mcp-server** | 9 vision tools | UI testing, screenshot debugging, diagram understanding |
| **web-search-prime** | webSearchPrime | Real-time web search |
| **web-reader** | webReader | Web content extraction |
| **zread** | search_doc, read_file | Repository knowledge access |

### Multi-Model Adversarial Validation (4 Planners)

For critical changes (complexity ≥ 7), Ralph runs **four-model validation**:

```
┌─────────────────────────────────────────────────────────────────┐
│            ADVERSARIAL VALIDATION COUNCIL v2.69                  │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │  CODEX   │ │  CLAUDE  │ │  GEMINI  │ │  GLM-4.7 │  ← NEW    │
│  │ GPT-5.2  │ │   Opus   │ │ 2.5 Pro  │ │ Coding   │           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
│       └────────────┴────────────┴────────────┘                  │
│                         ↓                                        │
│                ┌───────────────┐                                 │
│                │     JUDGE     │  (Claude Opus)                  │
│                │  Anonymized   │                                 │
│                └───────┬───────┘                                 │
│                        ↓                                         │
│               CONSENSUS REQUIRED                                 │
│        All planners evaluated, best plan synthesized             │
└─────────────────────────────────────────────────────────────────┘
```

**Planners in adversarial_council.py v2.68.26**:
```python
DEFAULT_PLANNERS = [
    AgentConfig(name="codex", kind="codex", model="gpt-5.2-codex"),
    AgentConfig(name="claude-opus", kind="claude", model="opus"),
    AgentConfig(name="gemini", kind="gemini", model="gemini-2.5-pro"),
    AgentConfig(name="glm-4.7", kind="glm", model="glm-4.7"),  # NEW
]
```

**Exit Criteria**: Judge synthesizes best plan from all four planners.

### Cost Optimization Strategy

| Task Complexity | Primary Model | Secondary | Max Iterations |
|-----------------|---------------|-----------|----------------|
| Simple (1-3) | Haiku | - | 3 |
| Standard (4-6) | MiniMax M2.1 | Sonnet | 50 |
| Complex (7-10) | Opus | Sonnet | 25 |
| Vision/GLM | GLM-4.7 | - | 25 |

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

# Switch to research mode
ralph context research

# Switch to debug mode
ralph context debug

# Show active context
ralph context show

# List all contexts
ralph context list
```

### Context Files

Contexts are defined in `~/.claude/contexts/`:

```
~/.claude/contexts/
├── dev.md       # Development context definition
├── review.md    # Code review context definition
├── research.md  # Research context definition
└── debug.md     # Debugging context definition
```

### Hook Integration

The `context-injector.sh` hook automatically injects the active context at session start.

---

## Eval-Driven Development (v2.64)

### Overview

Eval-Driven Development (EDD) treats AI code quality evals as "unit tests for AI development". Inspired by the concept that evals should be first-class citizens in AI-assisted programming.

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

# Run all evals in a category
edd run-category testing

# Show eval results
edd results

# Create new eval
edd create <eval-name>
```

### Eval Definition Format

Evals are defined in `~/.claude/evals/`:

```yaml
---
name: error-handling-basic
category: error_handling
difficulty: easy
pass_criteria: |
  - Must use try/catch
  - Must log errors
  - Must return meaningful error messages
---

# Error Handling Eval

Given a function that makes an API call, add proper error handling.

## Input
```python
def fetch_user(user_id):
    response = requests.get(f"/api/users/{user_id}")
    return response.json()
```

## Expected Behavior
- Handle network errors
- Handle JSON parsing errors
- Return structured error response
```

### EDD Skill

The `eval-harness.md` skill provides guidance for implementing EDD in your workflow.

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
ralph plan history 5    # Last 5 plans

# Restore from archive
ralph plan restore <archive-id>
ralph plan restore plan-20260123-
```

### Lifecycle Flow

```
┌──────────┐    ┌──────────┐    ┌──────────┐
│  START   │───▶│ EXECUTE  │───▶│ COMPLETE │
│  (new)   │    │(progress)│    │(all done)│
└──────────┘    └──────────┘    └────┬─────┘
                                     │
                                     ▼
                            ┌──────────────┐
                            │   ARCHIVE    │
                            │ (save + tag) │
                            └──────┬───────┘
                                   │
            ┌──────────────────────┼──────────────────┐
            │                      │                  │
            ▼                      ▼                  │
     ┌──────────┐          ┌──────────┐              │
     │  RESET   │          │ RESTORE  │◀─────────────┘
     │(fresh)   │          │(rollback)│
     └──────────┘          └──────────┘
```

### Archive Storage

Plans are archived to `~/.ralph/archive/plans/` with metadata:

```json
{
  "_archive_metadata": {
    "archived_at": "2026-01-23T15:46:20Z",
    "description": "User provided description",
    "source": ".claude/plan-state.json"
  }
}
```

### Task Primitive Sync (v2.65.1)

The `task-primitive-sync.sh` hook automatically syncs Claude's TaskCreate/TaskUpdate/TaskList operations with `plan-state.json`:

- **Auto-detection**: Detects v1 (array) vs v2 (object) format automatically
- **Unidirectional sync**: Claude Tasks → plan-state.json (plan-state is source of truth)
- **Progress tracking**: Enables statusline to show correct progress

```
Claude TaskCreate → Hook → plan-state.json → StatusLine
                                ↑
Claude TaskUpdate → Hook ───────┘
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

## Claude Code Task Primitive Integration

### Overview (v2.62)

Multi-Agent Ralph Loop fully integrates with Claude Code's **Task Primitive** architecture, migrating from the deprecated `TodoWrite` tool to the modern `TaskCreate`, `TaskUpdate`, and `TaskList` tools. This enables:

- **Unidirectional Sync**: Local `plan-state.json` (source of truth) syncs to Claude Code's global task storage
- **Parallelization Detection**: Auto-detect independent tasks that can run concurrently
- **Verification Subagents**: Automatic verification spawning after step completion
- **Context Hiding**: Reduce context pollution with background execution

### Task Primitive Hooks (3)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `global-task-sync.sh` | PostToolUse (TaskUpdate, TaskCreate) | Unidirectional sync: plan-state → `~/.claude/tasks/<session>/` |
| `task-orchestration-optimizer.sh` | PreToolUse (Task) | Detect parallelization and context-hiding opportunities |
| `verification-subagent.sh` | PostToolUse (TaskUpdate) | Spawn verification subagent after step completion |

### Unidirectional Task Sync (v2.66.0+)

The `global-task-sync.sh` hook implements **unidirectional** synchronization where `plan-state.json` is the single source of truth:

```
Local Plan-State                    Global Task Storage
┌────────────────────┐              ┌────────────────────┐
│ .claude/           │   ──────→   │ ~/.claude/tasks/   │
│   plan-state.json  │    SYNC      │   <session>/       │
│  (Source of Truth) │              │     1.json, 2.json │
└────────────────────┘              └────────────────────┘
```

**Features**:
- Session ID detection from `INPUT.session_id` (canonical), `$CLAUDE_SESSION_ID`, plan_id, or fallback
- Atomic writes with `mkdir`-based portable locking (HIGH-002 fix)
- Individual task files (`1.json`, `2.json`) instead of monolithic `tasks.json`
- Status mapping: `completed`/`verified` → `completed`, `in_progress` → `in_progress`, else → `pending`

**Task Format Conversion**:
```json
{
  "session_id": "ralph-20260123-12345",
  "task": "Implement OAuth2 authentication",
  "tasks": [
    {
      "id": "step1",
      "subject": "Setup JWT middleware",
      "status": "completed",
      "agent": "@security-auditor",
      "verification": { "status": "passed" }
    }
  ],
  "source": "ralph-v2.62"
}
```

### Parallelization Detection

The `task-orchestration-optimizer.sh` hook detects opportunities for parallel execution:

**Detection Criteria**:
1. **Parallel Phase**: Current phase has `execution_mode: "parallel"`
2. **Multiple Pending**: 2+ pending tasks in the same phase
3. **No Dependencies**: Tasks are independent

**Optimization Suggestions**:
```
⚡ Parallelization Opportunity Detected
3 independent tasks can run in parallel:
- Setup JWT middleware, Configure OAuth providers, Add refresh tokens

Consider launching multiple Task tools in a single message.
```

**Additional Optimizations**:
- **Context-Hiding**: Suggests `run_in_background: true` for prompts > 2000 chars
- **Model Optimization**: Suggests sonnet for complexity < 5 when opus is used
- **Pending Verifications**: Warns about unverified steps before proceeding

### Verification Subagent Pattern

The `verification-subagent.sh` hook implements Claude Code's verification pattern:

```
Step Completed → Check Verification Required → Spawn Subagent
       ↓                    ↓                        ↓
   TaskUpdate       Complexity ≥ 7?           Task tool with:
   status:           OR explicit              - subagent_type: reviewer
   completed         OR security-related      - run_in_background: true
                                              - model: sonnet
```

**Auto-Verification Triggers**:
| Trigger | Verification Agent |
|---------|-------------------|
| Complexity ≥ 7 | `code-reviewer` |
| Security keywords (auth, token, encrypt) | `security-auditor` |
| Test keywords (test, spec, coverage) | `test-architect` |
| Explicit `verification.required: true` | Configured agent |

**Verification Prompt Template**:
```
Verify the implementation of step '<step-name>'. Check for:
1. Correctness - Does it meet requirements?
2. Quality - Is the code clean and maintainable?
3. Security - Are there any vulnerabilities?
4. Edge cases - Are edge cases handled?

Report findings concisely.
```

### Migration from TodoWrite

The Task Primitive replaces the deprecated `TodoWrite` tool:

| Old (TodoWrite) | New (Task Primitive) | Benefit |
|-----------------|---------------------|---------|
| Single-session scope | Global session storage | Persistence across restarts |
| No sync | Unidirectional sync (plan-state → global) | Multi-agent awareness |
| Manual verification | Auto-verification hooks | Quality assurance |
| Sequential only | Parallel detection | Performance optimization |
| No background | Context-hiding support | Reduced context pollution |

**Usage Example**:

```bash
# Old way (deprecated)
# TodoWrite with internal task list

# New way (Task Primitive)
TaskCreate:
  subject: "Implement authentication"
  description: "Add JWT-based auth with refresh tokens"
  activeForm: "Implementing authentication"

TaskUpdate:
  taskId: "task-123"
  status: "completed"
  # → Triggers verification-subagent.sh automatically
```

### Best Practices

1. **Use TaskCreate for new steps**: Creates proper tracking and enables sync
2. **Update status via TaskUpdate**: Triggers verification hooks
3. **Check TaskList before new work**: See global task state
4. **Enable run_in_background for heavy tasks**: Reduces context pollution
5. **Let hooks handle verification**: Don't manually verify after each step

---

## Claude Code Skills Ecosystem

### Core Skills (8)

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

**Note**: Additional skills may be available in the global skills directory (~/.claude/skills/).

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

**Version**: 2.69
**Last Updated**: 2026-01-25
**Next Review**: 2026-02-25
