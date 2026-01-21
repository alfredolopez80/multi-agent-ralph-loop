# Multi-Agent Ralph Wiggum v2.58.0

> "Me fail English? That's unpossible!" - Ralph Wiggum

![Version](https://img.shields.io/badge/version-2.58.0-blue)
![License](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)
![Tests](https://img.shields.io/badge/tests-103%20passed-green)
![Hooks](https://img.shields.io/badge/hooks-52%20registered-orange)
![Skills](https://img.shields.io/badge/skills-266%2B-orange)

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

### Auto-Learning

| Component | Purpose | Version |
|-----------|---------|---------|
| **Repository Learner** | Extract patterns from quality repositories | v2.50 |
| **Repo Curator** | Discover, score, and curate quality repos | v2.55 |
| **Auto-Learning Hooks** | Detect knowledge gaps proactively | v2.55 |

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
| **3D Modeling** | Blender MCP | 3D asset creation via Blender |

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
| **uv** | Fast Python package manager | `curl -LsSf https://astral.sh/uv/install.sh | sh` |
| **Blender** | 3D asset creation | `brew install --cask blender` |
| **Docker** | Containerized deployment | `brew install --cask docker` |

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop
```

### 2. Run the Installer

The installer sets up the global CLI and integrates with Claude Code:

```bash
# Make executable
chmod +x install.sh

# Run installer (requires jq, curl)
./install.sh

# Verify installation
ralph --version
ralph status
```

### 3. Verify Global Installation

After installation, these paths should exist:

```bash
# CLI tool
which ralph
# Expected: ~/.local/bin/ralph

# Configuration
ls -la ~/.ralph/
# Expected: directories for memory, logs, config, etc.

# Global hooks
ls -la ~/.claude/hooks/
# Expected: 52+ .sh hook files

# Global skills
ls -la ~/.claude/skills/
# Expected: 266+ skill directories
```

### 4. Quick Validation

Run a quick validation to ensure everything works:

```bash
# Check Ralph status
ralph status

# Check memory health
ralph health

# Check hooks registration
ralph hooks check
```

---

## Architecture

### Directory Structure

```
multi-agent-ralph-loop/
├── .claude/                    # Claude Code configuration
│   ├── agents/                 # 30+ specialized agent definitions
│   ├── commands/               # Slash command implementations
│   ├── hooks/                  # 52+ hook scripts (in settings.json)
│   ├── skills/                 # Local project skills
│   ├── rules/                  # Global rules (Plan Mode, etc.)
│   ├── settings.local.json     # Project permissions
│   └── schemas/                # JSON schemas
├── scripts/                    # Utility scripts
│   ├── validate-integration.sh
│   ├── validate-global-architecture.sh
│   └── ...
├── src/                        # Source code (minimal)
├── tests/                      # Test suite
├── docs/                       # Documentation
├── install.sh                  # Global installer
├── README.md                   # This file
├── CLAUDE.md                   # Project instructions
├── AGENTS.md                   # Agent reference
└── CHANGELOG.md                # Version history

~/.ralph/                       # Global Ralph data (after installation)
├── memory/
│   ├── semantic.json           # Semantic memory
│   ├── memvid.json             # Memvid checkpoints
│   └── episodes/               # Episodic memory (30-day TTL)
├── procedural/
│   └── rules.json              # Learned procedural rules
├── agent-memory/               # Per-agent isolated memory
├── checkpoints/                # LangGraph-style checkpoints
├── ledgers/                    # Session continuity
├── handoffs/                   # Agent-to-agent context transfer
├── events/                     # Event bus log
├── logs/                       # Hook and system logs
├── curator/                    # Repo curation data
└── config/                     # Agent registry, etc.

~/.claude/                      # Global Claude Code config (after installation)
├── settings.json               # 52 hooks registered
├── hooks/                      # 58 hook scripts total
│   ├── fast-path-check.sh
│   ├── parallel-explore.sh
│   ├── recursive-decompose.sh
│   ├── quality-gates-v2.sh
│   ├── sec-context-validate.sh
│   └── ... (52 more)
├── agents/                     # Global agent definitions
├── commands/                   # Global slash commands
├── skills/                     # 266+ global skills
│   ├── orchestrator/           # Orchestration skill
│   ├── marketing-skills/       # 23 marketing skills
│   ├── readme/                 # README generation skill
│   └── vercel-react-best-practices/
└── rules/                      # Global behavior rules
```

### Core Workflow

The orchestration follows a 12-step workflow (v2.46):

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

**Fast-Path** (complexity ≤ 3): `DIRECT_EXECUTE → MICRO_VALIDATE → DONE` (3 steps)

### 3-Dimension Classification

The system uses RLM-inspired routing based on three dimensions:

| Dimension | Values | Description |
|-----------|--------|-------------|
| **Complexity** | 1-10 | Scope, risk, ambiguity |
| **Information Density** | CONSTANT / LINEAR / QUADRATIC | How answer scales with input |
| **Context Requirement** | FITS / CHUNKED / RECURSIVE | Whether decomposition needed |

#### Workflow Routing Matrix

| Density | Context | Complexity | Route |
|---------|---------|------------|-------|
| CONSTANT | FITS | 1-3 | **FAST_PATH** |
| CONSTANT | FITS | 4-10 | STANDARD |
| LINEAR | CHUNKED | ANY | PARALLEL_CHUNKS |
| QUADRATIC | ANY | ANY | RECURSIVE_DECOMPOSE |

#### Model Routing by Route

| Route | Primary | Secondary | Max Iter |
|-------|---------|-----------|----------|
| FAST_PATH | sonnet | - | 3 |
| STANDARD (1-4) | minimax-m2.1 | sonnet | 25 |
| STANDARD (5-6) | sonnet | opus | 25 |
| STANDARD (7-10) | opus | sonnet | 25 |
| PARALLEL_CHUNKS | sonnet (chunks) | opus (aggregate) | 15/chunk |
| RECURSIVE | opus (root) | sonnet (sub) | 15/sub |

### Memory Architecture

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

#### Memory Types

| Type | Purpose | Storage | TTL |
|------|---------|---------|-----|
| **Semantic** | Facts, preferences | `~/.ralph/memory/semantic.json` | Never |
| **Episodic** | Experiences (30-day TTL) | `~/.ralph/episodes/` | 30 days |
| **Procedural** | Learned behaviors | `~/.ralph/procedural/rules.json` | Never |

#### Memory Commands

```bash
# Memory search (parallel - v2.49)
ralph memory-search "session goal"

# Fork suggest (find similar sessions)
ralph fork-suggest "implement OAuth"

# Checkpoint system (v2.51)
ralph checkpoint save "before-refactor" "Pre-auth changes"
ralph checkpoint restore "before-refactor"
ralph checkpoint list
ralph checkpoint diff "checkpoint1" "checkpoint2"

# Handoff API (v2.51)
ralph handoff transfer --from orchestrator --to security-auditor \
    --task "Audit auth module"
ralph handoff agents
ralph handoff history

# Agent-Scoped Memory (v2.51)
ralph agent-memory init security-auditor
ralph agent-memory write security-auditor semantic "Found SQL injection"
ralph agent-memory read security-auditor
```

### Hooks System

Ralph uses a comprehensive hooks system with 52 registered hooks across 6 event types.

#### Hook Event Types

| Event Type | Purpose | Number of Hooks |
|------------|---------|-----------------|
| **SessionStart** | Context preservation at startup | 8 |
| **PreCompact** | Save state before compaction | 2 |
| **PostToolUse** | Quality gates after operations | 25 |
| **PreToolUse** | Safety guards before operations | 12 |
| **UserPromptSubmit** | Context warnings, reminders | 3 |
| **Stop** | Session reports | 2 |

#### Key Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `fast-path-check.sh` | PreToolUse (Task) | Detect trivial tasks → FAST_PATH routing |
| `parallel-explore.sh` | PostToolUse (Task) | Launch 5 concurrent exploration tasks |
| `recursive-decompose.sh` | PostToolUse (Task) | Trigger sub-orchestrators for complex tasks |
| `quality-gates-v2.sh` | PostToolUse (Edit/Write) | Quality-first validation (consistency advisory) |
| `sec-context-validate.sh` | PostToolUse (Edit/Write) | Security context validation |
| `semantic-realtime-extractor.sh` | PostToolUse (Edit/Write) | Real-time semantic extraction |
| `agent-memory-auto-init.sh` | PreToolUse (Task) | Auto-initialize agent memory buffers |
| `status-auto-check.sh` | PostToolUse (Edit/Write/Bash) | Auto-show status every 5 operations |
| `checkpoint-smart-save.sh` | PreToolUse (Edit/Write) | Smart checkpoints on risky edits |

#### Hook Registration

Hooks are registered in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "name": "quality-gates-v2",
        "script": "quality-gates-v2.sh",
        "matchers": [
          {"type": "Edit"},
          {"type": "Write"}
        ]
      }
    ]
  }
}
```

### Agent System

Ralph orchestrates 30+ specialized agents across different domains.

#### Core Orchestration Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `@orchestrator` | opus | Main coordinator - 12-step workflow |
| `@lead-software-architect` | opus | Architecture guardian - LSA verification |
| `@plan-sync` | sonnet | Drift detection & downstream patching |
| `@gap-analyst` | opus | Pre-implementation gap analysis |
| `@quality-auditor` | opus | 6-phase pragmatic code audit |
| `@adversarial-plan-validator` | opus | Dual-model plan validation (Claude + Codex) |

#### Review & Security Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `@security-auditor` | sonnet→codex | Security vulnerabilities & OWASP compliance |
| `@code-reviewer` | sonnet→codex | Code quality, patterns, best practices |
| `@blockchain-security-auditor` | opus | Smart contract & DeFi security |
| `@ai-output-code-review-super-auditor` | opus | AI-generated code verification |

#### Implementation Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `@test-architect` | sonnet | Test generation & coverage |
| `@debugger` | opus | Bug detection & root cause analysis |
| `@refactorer` | sonnet→codex | Code refactoring & modernization |
| `@docs-writer` | sonnet→gemini | Documentation generation |

#### Language-Specific Reviewers

| Agent | Model | Purpose |
|-------|-------|---------|
| `@kieran-python-reviewer` | sonnet | Python type hints, patterns, testability |
| `@kieran-typescript-reviewer` | sonnet | TypeScript type safety, modern patterns |
| `@frontend-reviewer` | opus | React/Next.js, UI/UX, accessibility |

#### Blockchain & DeFi Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `@Hyperliquid-DeFi-Protocol-Specialist` | opus | Hyperliquid protocol integration |
| `@liquid-staking-specialist` | opus | Liquid staking protocols |
| `@defi-protocol-economist` | opus | Token economics & DeFi modeling |
| `@chain-infra-specialist-blockchain` | opus | Chain infrastructure & RPC |

---

## Commands Reference

### Core Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `ralph orch "task"` | `rho` | Full orchestration with fast-path |
| `ralph loop "task"` | - | Execute until VERIFIED_DONE |
| `ralph gates` | `rhg` | Quality-first validation |
| `ralph adversarial "path"` | `rha` | Adversarial spec refinement |
| `ralph compact` | - | Manual context save |
| `ralph health` | - | Memory system health check |
| `ralph status` | - | Full orchestration status |

### Memory Commands (v2.49+)

| Command | Description |
|---------|-------------|
| `ralph memory-search "query"` | Parallel search across memory types |
| `ralph fork-suggest "task"` | Find sessions to fork |
| `ralph checkpoint save "name" "desc"` | Save state checkpoint |
| `ralph checkpoint restore "name"` | Restore from checkpoint |
| `ralph checkpoint list` | List all checkpoints |
| `ralph handoff transfer --from X --to Y --task "desc"` | Agent handoff |
| `ralph handoff agents` | List available agents |

### Repository Learning Commands (v2.50+)

| Command | Description |
|---------|-------------|
| `repo-learn https://github.com/org/repo` | Learn patterns from repository |
| `repo-learn https://github.com/org/repo --category error_handling` | Focused category learning |

### Repo Curator Commands (v2.55+)

| Command | Description |
|---------|-------------|
| `ralph curator full --type backend --lang typescript` | Full curation pipeline |
| `ralph curator discovery --query "microservice"` | Custom discovery |
| `ralph curator show --type backend` | View ranking |
| `ralph curator approve nestjs/nest` | Approve single repo |
| `ralph curator learn --repo nestjs/nest` | Learn from approved repo |

### Checkpoint Commands (v2.51+)

| Command | Description |
|---------|-------------|
| `ralph checkpoint save "name" "description"` | Save state |
| `ralph checkpoint restore "name"` | Restore from checkpoint |
| `ralph checkpoint list` | List all checkpoints |
| `ralph checkpoint diff "n1" "n2"` | Compare checkpoints |

### Event-Driven Engine Commands (v2.51+)

| Command | Description |
|---------|-------------|
| `ralph events emit <type> [payload]` | Emit event |
| `ralph events barrier check <phase>` | Check WAIT-ALL barrier |
| `ralph events barrier wait <phase> [timeout]` | Wait for barrier |
| `ralph events status` | Event bus status |
| `ralph events history [count]` | Event history |

### Observability Commands (v2.52+)

| Command | Description |
|---------|-------------|
| `ralph status` | Full orchestration status |
| `ralph status --compact` | One-line summary |
| `ralph status --steps` | Detailed step breakdown |
| `ralph status --json` | JSON output |
| `ralph trace show [count]` | Recent events |
| `ralph trace search <query>` | Search events |
| `ralph trace summary` | Session summary |

### Security Commands

| Command | Description |
|---------|-------------|
| `ralph security src/` | Security audit |
| `ralph security-loop src/` | Iterative security audit |

### Context Commands

| Command | Description |
|---------|-------------|
| `ralph ledger save` | Save session state |
| `ralph handoff create` | Create handoff |

---

## Ralph Loop Pattern

The core iteration pattern:

```
EXECUTE → VALIDATE → Quality Passed?
                      ↓ NO
                  ITERATE (max 25)
                      ↓
                Back to EXECUTE
```

`VERIFIED_DONE` = plan approved + MUST_HAVE answered + classified + implemented + gates passed + retrospective done

### Model Iteration Limits

| Model | Max Iter | Use Case |
|-------|----------|----------|
| Claude | **25** | Complex reasoning |
| MiniMax M2.1 | **50** | Standard (2x) |
| MiniMax-lightning | **100** | Extended (4x) |

---

## Quality-First Validation

Ralph implements a 3-stage validation pipeline (v2.46):

```
Stage 1: CORRECTNESS → Syntax errors (BLOCKING)
Stage 2: QUALITY     → Type errors (BLOCKING)
Stage 2.5: SECURITY  → semgrep + gitleaks (BLOCKING)
Stage 3: CONSISTENCY → Linting (ADVISORY - not blocking)
```

### Quality Gates by Language

| Language | Linter | Type Checker | Security Scanner |
|----------|--------|--------------|------------------|
| TypeScript | ESLint | tsc | semgrep |
| Python | ruff | pyright | semgrep |
| Go | gofmt/golint | go build | semgrep |
| Rust | rustfmt | cargo check | semgrep |
| Solidity | solhint | solc | slither |
| Java | prettier | - | semgrep |
| JSON | jq (validate) | - | - |
| YAML | yamllint | - | - |

---

## Claude Code Skills Ecosystem

Ralph includes 266+ specialized skills for domain-specific tasks.

### Skills Categories

| Category | Count | Examples |
|----------|-------|----------|
| **Marketing** | 23 | A/B testing, copywriting, funnel design, brand positioning |
| **Documentation** | 1 | README generation |
| **React** | 1 | Vercel React Best Practices |
| **Orchestration** | 1 | Orchestrator skill |
| **Total** | 266+ | Multiple categories |

### Installing Additional Skills

```bash
# Skills are installed to ~/.claude/skills/
# Global skills are available in all projects

# Install from GitHub
git clone https://github.com/user/skill-name ~/.claude/skills/skill-name

# Verify installation
ralph skills list
```

### Skill Structure

```
~/.claude/skills/
├── skill-name/
│   ├── SKILL.md          # Skill definition and usage
│   ├── AGENTS.md         # Agent definitions (optional)
│   ├── README.md         # Documentation (optional)
│   ├── metadata.json     # Skill metadata (optional)
│   └── rules/            # Additional rules (optional)
```

---

## Testing

### Running Tests

```bash
# Run all tests
python -m pytest tests/ -v

# Run specific test category
python -m pytest tests/test_hooks_comprehensive.py -v

# Run hook security tests
python -m pytest tests/test_hooks_comprehensive.py::TestSecurityCommandInjection -v

# Run with coverage
python -m pytest tests/ --cov=. --cov-report=html
```

### Test Structure

```
tests/
├── test_hooks_comprehensive.py  # 38 hook tests (7 categories)
├── test_memory_system.py        # Memory system tests
├── test_quality_gates.py        # Quality validation tests
└── ...
```

### Test Categories

| Category | Tests | Purpose |
|----------|-------|---------|
| JSON Output | 7 | Hook ALWAYS returns valid JSON |
| Command Injection | 4 | Shell metacharacters blocked |
| Path Traversal | 2 | Symlinks resolved, paths validated |
| Race Conditions | 4 | umask 077, noclobber, chmod 700 |
| Edge Cases | 6 | Unicode, long inputs, null bytes |
| Error Handling | 3 | Exit 0 always, stderr clean |
| Regressions | 5 | Past bugs don't return |
| Performance | 3 | Hooks complete in <5s |

### Codex CLI Validation

```bash
# Run adversarial validation
codex exec -m gpt-5.2-codex --sandbox read-only \
  --config model_reasoning_effort=high \
  "review ~/.claude/hooks/<hook>.sh --focus security"
```

---

## Deployment

### Local Development

Ralph is designed for local development with Claude Code. No server deployment required.

```bash
# Update Ralph to latest version
cd multi-agent-ralph-loop
git pull origin main
./install.sh
```

### Global Installation

The installer sets up:

1. **CLI Tool**: `~/.local/bin/ralph`
2. **Configuration**: `~/.ralph/` (memory, logs, config)
3. **Global Hooks**: `~/.claude/hooks/`
4. **Global Skills**: `~/.claude/skills/`
5. **Global Agents**: `~/.claude/agents/`

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_HOME` | Ralph configuration directory | `~/.ralph` |
| `RALPH_LOG_LEVEL` | Logging verbosity | `info` |
| `RALPH_HOOKS_DIR` | Hooks directory | `~/.claude/hooks` |

### Docker (Optional)

```bash
# Build development image
docker build -t ralph-dev .

# Run tests
docker run -it --rm -v ~/.claude:/root/.claude ralph-dev \
  python -m pytest tests/ -v
```

---

## Troubleshooting

### Installation Issues

**Error**: `jq not found`

**Solution**:
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

**Error**: `jq: error during parse (...)` during hook execution

**Solution**:
```bash
# Check jq version (requires 1.6+)
jq --version

# Reinstall newer version
brew upgrade jq
```

### Memory Issues

**Error**: `Could not acquire lock` in semantic-write.log

**Solution**:
```bash
# Check for stuck processes
ps aux | grep ralph

# Clear lock file (if stale)
rm -f ~/.ralph/logs/semantic-write.lock

# Restart Claude Code session
```

**Error**: `Unknown command: memvid`

**Solution**:
```bash
# Verify memvid is installed
python3 -c "import memvid"

# Re-run installer to register memvid commands
cd multi-agent-ralph-loop
./install.sh

# Verify commands
ralph memvid status
```

### Hook Issues

**Error**: Hook not triggering

**Solution**:
```bash
# Check hook registration
ralph hooks list

# Verify settings.json contains hook
grep "hook-name" ~/.claude/settings.json

# Test hook manually
bash ~/.claude/hooks/hook-name.sh
```

**Error**: Stop hook JSON format error

**Solution**:
```bash
# Check orchestrator-report.sh output format
bash ~/.claude/hooks/orchestrator-report.sh

# Expected: {"decision": "approve"} (not "continue")
```

### Memory Health Issues

**Error**: `ralph health` reports failures

**Solution**:
```bash
# Run health check with fix
ralph health --fix

# Manual repair
mkdir -p ~/.ralph/memory
mkdir -p ~/.ralph/logs
mkdir -p ~/.ralph/procedural
```

### Context Issues

**Error**: Context not preserved between sessions

**Solution**:
```bash
# Check ledger status
ralph ledger list

# Restore from ledger
ralph ledger load <session-id>

# Check handoff
ralph handoff history
```

---

## Contributing

### Adding New Hooks

1. Create hook script in `~/.claude/hooks/`
2. Register in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "name": "my-hook",
        "script": "my-hook.sh",
        "matchers": [
          {"type": "Edit"},
          {"type": "Write"}
        ]
      }
    ]
  }
}
```

3. Test hook with `python -m pytest tests/test_hooks_comprehensive.py::TestJSONOutput -v`

### Adding New Agents

1. Create agent definition in `.claude/agents/<agent-name>.md`
2. Register in agent registry (optional)

### Adding New Skills

1. Create skill in `~/.claude/skills/<skill-name>/`
2. Include `SKILL.md` with YAML frontmatter
3. Document usage in README.md

### Submitting Changes

```bash
# Fork repository
git fork https://github.com/alfredolopez80/multi-agent-ralph-loop.git

# Create feature branch
git checkout -b feature/new-hook

# Make changes
# ...

# Run tests
python -m pytest tests/ -v

# Commit with conventional format
git commit -m "feat: Add new hook for X"

# Submit PR
gh pr create
```

---

## License

This project is licensed under the **Business Source License 1.1** (BSL 1.1).

See [LICENSE](LICENSE) for full terms.

### What This Means

- **Free to use**: Anyone can use Ralph for development
- **Source available**: Full source code is available
- **Production use**: May require license for production deployments
- **Contributions**: Subject to contribution agreement

---

## Resources

| Resource | Description |
|----------|-------------|
| [README.es.md](README.es.md) | Spanish translation |
| [CLAUDE.md](CLAUDE.md) | Project instructions for Claude |
| [AGENTS.md](AGENTS.md) | Agent reference documentation |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [TESTING.md](TESTING.md) | Testing guide |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines |
| [docs/](docs/) | Additional documentation |
| [.claude/](.claude/) | Configuration and agent definitions |

---

*Generated with the README Skill - "Absurdly thorough documentation"*

*Version: 2.58.0 | Last Updated: 2026-01-21*
