# Multi-Agent Ralph Wiggum

![Version](https://img.shields.io/badge/version-2.31-blue)
![License](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen)](CONTRIBUTING.md)

> "Me fail English? That's unpossible!" - Ralph Wiggum

---

## Overview

**Multi-Agent Ralph Wiggum** is a sophisticated orchestration system for Claude Code that coordinates multiple AI models to deliver high-quality, validated code through iterative refinement loops.

The system addresses the fundamental challenge of AI-assisted coding: **ensuring quality and consistency across complex tasks**. Rather than relying on a single AI model's output, Ralph orchestrates multiple specialized agents (Claude, Codex, Gemini, MiniMax) working in parallel, with automatic validation gates and adversarial consensus checks.

### What It Does

- **Orchestrates Multiple AI Models**: Coordinates Claude (Opus/Sonnet), OpenAI Codex, Google Gemini, and MiniMax in parallel workflows
- **Iterative Refinement**: Implements the "Ralph Loop" pattern - execute, validate, iterate until quality gates pass
- **Quality Assurance**: 9-language quality gates (TypeScript, Python, Go, Rust, Solidity, Swift, JSON, YAML, JavaScript)
- **Adversarial Validation**: 2/3 consensus requirement for critical code (auth, payments, data)
- **Self-Improvement**: Retrospective analysis after every task to propose workflow improvements

### Why Use It

| Challenge | Ralph's Solution |
|-----------|------------------|
| AI outputs vary in quality | Multi-model validation with 2/3 consensus |
| Single-pass often insufficient | Iterative loops (15-60 iterations) until VERIFIED_DONE |
| Manual review bottleneck | Automated quality gates + human-in-the-loop for critical decisions |
| Context limits | MiniMax (1M tokens) + Context7 MCP for documentation |
| High API costs | Cost-optimized routing (WebSearch FREE, MiniMax 8%, strategic Opus usage) |

---

## Key Features

### Multi-Agent Orchestration

| Feature | Description |
|---------|-------------|
| **9 Specialized Agents** | orchestrator, security-auditor, code-reviewer, test-architect, debugger, refactorer, docs-writer, frontend-reviewer, minimax-reviewer |
| **8-Step Workflow** | Auto-plan → Clarify → Classify → Worktree → Plan → Execute → Validate → Retrospect |
| **Parallel Execution** | Multiple agents work simultaneously on independent subtasks |
| **Model Routing** | Automatic selection: Opus (critical), Sonnet (standard), MiniMax (extended) |

### Smart Execution (v2.29)

| Feature | Description |
|---------|-------------|
| **Background Tasks** | All agents use `run_in_background: true` by default |
| **Quality Criteria** | Explicit stop conditions defined per agent/task type |
| **Auto Discovery** | Explorer/Plan invoked automatically for complex tasks (complexity >= 7) |
| **Tool Selection Matrix** | Intelligent routing: ast-grep → Context7 → WebSearch → MiniMax MCP |

### Context Engineering (v2.30)

| Feature | Description |
|---------|-------------|
| **Context Monitoring** | @context-monitor alerts at 60% context threshold to prevent degradation |
| **Auto-Checkpointing** | /checkpoint save/restore/list/clear for session state preservation |
| **System Reminders** | Periodic goal reminders (Manus pattern) to prevent "lost in middle" |
| **Fresh Context Explorer** | @fresh-explorer for independent analysis without context contamination |
| **CC + Codex Workflow** | Claude Code implements → Codex reviews → iterate until VERIFIED_DONE |
| **CLAUDE.md Modularization** | Core content split into 10 on-demand skills (58% size reduction) |

### Memvid Semantic Memory (v2.31)

| Feature | Description |
|---------|-------------|
| **HNSW + BM25 Hybrid Search** | Sub-5ms semantic search with high recall |
| **Time-travel Queries** | Query across session history with semantic matching |
| **Single-file Storage** | Portable `.mv2` file (no database required) |
| **100% Offline** | Apache 2.0 license, no cloud dependencies |
| **@memvid Skill** | Quick access to memory operations |

```bash
ralph memvid init          # Initialize memory system
ralph memvid save "context"  # Save current context
ralph memvid search "query"  # Semantic search
```

### Quality & Validation

| Feature | Description |
|---------|-------------|
| **9-Language Quality Gates** | TypeScript, JavaScript, Python, Go, Rust, Solidity, Swift, JSON, YAML |
| **Adversarial Validation** | 2/3 consensus (Claude + Codex + Gemini) for critical code |
| **Git Safety Guard** | Pre-execution hook blocks destructive commands (force push, reset --hard, etc.) |
| **Multi-Level Security Loop** | Iterative audit → fix → re-audit until 0 vulnerabilities (v2.27) |

### Development Workflow

| Feature | Description |
|---------|-------------|
| **Auto Planning** | Automatic `EnterPlanMode` for non-trivial tasks |
| **Intensive Clarification** | AskUserQuestion with MUST_HAVE/NICE_TO_HAVE classification |
| **Git Worktree Isolation** | Feature isolation via `ralph worktree` with multi-agent PR review |
| **Self-Improvement** | Retrospective analysis proposes workflow improvements |

### Search & Research

| Tool | Cost | Use Case |
|------|------|----------|
| **WebSearch** | FREE | Default web research (Claude Max subscription) |
| **Context7 MCP** | Optimized | Library/framework documentation |
| **MiniMax MCP** | ~8% | Fallback search + image analysis |
| **ast-grep MCP** | ~25% | Structural code search (~75% token savings) |

### Browser & Media

| Tool | Performance | Use Case |
|------|-------------|----------|
| **dev-browser** | 17% faster, 39% cheaper | Primary browser automation |
| **Playwright MCP** | Baseline | Complex automation fallback |
| **Nano Banana MCP** | Variable | Image/asset generation |

### CLI & Commands

| Type | Count | Example |
|------|-------|---------|
| **CLI Commands** | 25+ | `ralph orch`, `ralph security-loop`, `ralph worktree-pr` |
| **Slash Commands** | 23 | `/orchestrator`, `/security`, `/library-docs` |
| **Prefix Shortcuts** | 23 | `@orch`, `@sec`, `@lib` (v2.26) |

---

## Core Workflows

### 1. The Ralph Loop Pattern

The fundamental iteration pattern ensuring quality through validation:

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
│                   │ (max 15/30) │          │   (output)   │    │
│                   └──────┬──────┘          └──────────────┘    │
│                          │                                     │
│                          └──────────▶ Back to EXECUTE          │
│                                                                 │
│   Iteration Limits:                                             │
│   • Claude (Sonnet/Opus): 15 iterations                        │
│   • MiniMax M2.1: 30 iterations                                │
│   • MiniMax-lightning: 60 iterations                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Full Orchestration Flow (8 Steps)

Complete workflow from task request to verified completion:

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR (Opus)                          │
│                                                                 │
│  0. AUTO-PLAN   → EnterPlanMode (automatic for non-trivial)    │
│  1. CLARIFY     → AskUserQuestion (MUST_HAVE/NICE_TO_HAVE)     │
│  2. CLASSIFY    → task-classifier (complexity 1-10)            │
│  2b. WORKTREE   → Ask user: "Requires isolated worktree?"      │
│  3. PLAN        → Write detailed plan, get approval            │
│  4. DELEGATE    → Route to optimal model                       │
│  5. EXECUTE     → Parallel subagents (in worktree if selected) │
│  6. VALIDATE    → Quality gates + Adversarial validation       │
│  7. RETROSPECT  → Self-improvement proposals                   │
│  7b. PR REVIEW  → If worktree: Claude + Codex review → merge   │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                 SONNET SUBAGENTS (9)                            │
├─────────────────────────────────────────────────────────────────┤
│  @security-auditor  │  @code-reviewer    │  @test-architect    │
│  @debugger          │  @refactorer       │  @docs-writer       │
│  @frontend-reviewer │  @minimax-reviewer │                     │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│                   EXTERNAL CLIs (Parallel)                      │
├─────────────────────────────────────────────────────────────────┤
│  Codex CLI          │  Gemini CLI         │  MiniMax (mmc)     │
│  • Security review  │  • Short tasks only │  • Second opinion  │
│  • Bug hunting      │  • Integration tests│  • Extended loops  │
│  • Unit tests       │                     │  • Fallback        │
└─────────────────────────────────────────────────────────────────┘
```

### 3. Multi-Level Security Loop (v2.27)

Iterative security auditing until zero vulnerabilities:

```
┌─────────────────────────────────────────────────────────────────┐
│                 MULTI-LEVEL SECURITY LOOP                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Round 1                                                       │
│   ┌──────────┐    ┌──────────────┐    ┌─────────────────┐      │
│   │  AUDIT   │───▶│   FINDINGS   │───▶│ Issues Found?   │      │
│   │  (Codex) │    │   (Parse)    │    └────────┬────────┘      │
│   └──────────┘    └──────────────┘             │               │
│                                          NO ◀──┴──▶ YES        │
│                                           │         │          │
│                                           ▼         ▼          │
│                                   ┌───────────┐  ┌──────────┐  │
│                                   │  DONE     │  │   FIX    │  │
│                                   │  0 issues │  │ (Hybrid) │  │
│                                   └───────────┘  └────┬─────┘  │
│                                                       │        │
│   Round 2+                                            ▼        │
│   ┌──────────┐    ┌──────────────┐    ┌─────────────────┐      │
│   │ RE-AUDIT │◀───│   VALIDATE   │◀───│ Fixes Applied   │      │
│   │  (Codex) │    │   (Check)    │    └─────────────────┘      │
│   └──────────┘    └──────────────┘                             │
│        │                                                        │
│        └─────────────────▶ Loop until 0 issues or max rounds   │
│                                                                 │
│   Config:                                                       │
│   • Max Rounds: 10 (configurable)                              │
│   • Fix Agent: Codex GPT-5                                     │
│   • Approval: Hybrid (auto LOW/MEDIUM, ask CRITICAL/HIGH)      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4. Adversarial Validation

2/3 consensus for critical code (auth, payments, data):

```
┌─────────────────────────────────────────────────────────────────┐
│                 ADVERSARIAL VALIDATION                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Claude Review ──┐                                              │
│                  │                                              │
│  Codex Review  ──┼──▶  CONSENSUS CHECK  ──▶  2/3 REQUIRED      │
│                  │                                              │
│  Gemini Review ──┘     (tie-breaker)                           │
│                                                                 │
│  PASS: 2+ models approve                                        │
│  FAIL: exit 2 → Ralph Loop until fixed                         │
└─────────────────────────────────────────────────────────────────┘
```

### 5. Git Worktree + PR Workflow

Isolated feature development with multi-agent review:

```
┌─────────────────────────────────────────────────────────────────┐
│  1. ralph worktree "feature"                                    │
│     → Creates .worktrees/ai-ralph-YYYYMMDD-feature/             │
│     → Launches Claude in isolated worktree                      │
├─────────────────────────────────────────────────────────────────┤
│  2. Develop feature (all subagents work in same worktree)       │
│     → @backend-dev, @frontend-dev, @test-architect, etc.        │
├─────────────────────────────────────────────────────────────────┤
│  3. ralph worktree-pr <branch>                                  │
│     → Creates PR with multi-agent review                        │
│     → Claude Opus: Logic, architecture, edge cases              │
│     → Codex GPT-5: Security, performance, best practices        │
├─────────────────────────────────────────────────────────────────┤
│  4. Review Decision:                                            │
│     → PASS: ralph worktree-merge <pr>                          │
│     → FAIL: ralph worktree-fix <pr>                            │
│     → ABORT: ralph worktree-close <pr>                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Installation

```bash
# 1. Clone repository
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# 2. Install
chmod +x install.sh
./install.sh
source ~/.zshrc  # or ~/.bashrc

# 3. Configure MiniMax (recommended for extended loops)
mmc --setup

# 4. Verify installation
ralph integrations
```

### Requirements

| Tool | Required | Purpose | Install |
|------|----------|---------|---------|
| Claude CLI | Yes | Base orchestration | `npm i -g @anthropic-ai/claude-code` |
| jq | Yes | JSON processing | `brew install jq` |
| git | Yes | Version control | `brew install git` |
| WorkTrunk | For worktrees | Git worktree management | `brew install max-sixty/worktrunk/wt` |
| GitHub CLI | For PRs | PR creation/review | `brew install gh` |

### Basic Usage

```bash
# Full orchestration (8 steps)
ralph orch "Implement OAuth2 with Google"

# Security audit
ralph security src/

# Multi-level security loop (v2.27)
ralph security-loop src/ --max-rounds 10

# Adversarial validation
ralph adversarial src/auth/

# Git worktree workflow
ralph worktree "implement feature X"
ralph worktree-pr ai/ralph/20260104-feature
ralph worktree-merge 42
```

### Slash Commands (Claude Code)

```bash
# Full orchestration
@orch "Implement OAuth2"          # or /orchestrator

# Security
@sec src/                         # or /security
@secloop src/                     # or /security-loop (v2.27)

# Research
@lib "React 19 hooks"             # or /library-docs
@research "TypeScript 5.4"        # or /research

# All commands
@cmds                             # or /commands
```

---

## Model Architecture

### Primary + Secondary Pattern

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
│  Documentation             │  Opus quality @ 8% cost      │
└────────────────────────────┴───────────────────────────────┘
```

### Cost Optimization

| Model | Max Iterations | Cost vs Claude | Use Case |
|-------|----------------|----------------|----------|
| Claude Opus | 15 | 100% | Critical reviews, architecture |
| Claude Sonnet | 15 | 60% | Standard implementation |
| MiniMax M2.1 | 30 | 8% | Extended loops, second opinion |
| MiniMax-lightning | 60 | 4% | Very long tasks |

### Search Hierarchy

```
┌────────────────────────────────────────┐
│ Is it about a library/framework?       │
├────────────────────────────────────────┤
│ YES → Context7 MCP → MiniMax fallback  │
│ NO  → WebSearch → MiniMax fallback     │
└────────────────────────────────────────┘
Gemini: ONLY for short, punctual tasks
```

---

## Commands Reference

### CLI Commands

```bash
# Orchestration
ralph orch "task"              # Full 8-step orchestration
ralph loop "task"              # Ralph loop (15 iterations)
ralph loop --mmc "task"        # With MiniMax (30 iterations)
ralph clarify "task"           # Generate clarification questions

# Security (v2.27)
ralph security <path>          # Single-pass security audit
ralph security-loop <path>     # Multi-level iterative audit
ralph secloop <path>           # Alias for security-loop

# Search & Research
ralph research "query"         # WebSearch → MiniMax fallback
ralph library "React 19"       # Context7 MCP documentation
ralph browse URL               # dev-browser automation
ralph ast '<pattern>' path     # Structural code search

# Code Analysis
ralph bugs <path>              # Bug hunting
ralph review <path>            # Multi-model review
ralph parallel <path>          # All subagents async

# Git Worktree
ralph worktree "task"          # Create isolated worktree
ralph worktree-pr <branch>     # Create PR with review
ralph worktree-merge <pr>      # Merge approved PR
ralph worktree-fix <pr>        # Apply review fixes
ralph worktree-close <pr>      # Close and cleanup
ralph worktree-status          # Show worktrees
ralph worktree-cleanup         # Clean merged

# Validation & Quality
ralph gates                    # Quality gates (9 languages)
ralph adversarial <path>       # 2/3 consensus validation
ralph pre-merge                # Pre-PR validation

# Maintenance
ralph self-update              # Sync scripts from repo
ralph integrations             # Show tool status
```

### Slash Commands with Prefixes (v2.26)

| Category | Command | Prefix | Description |
|----------|---------|--------|-------------|
| **Orchestration** | /orchestrator | @orch | Full 8-step workflow |
| | /clarify | @clarify | Clarification questions |
| | /loop | @loop | Ralph loop iteration |
| **Review** | /security | @sec | Security audit |
| | /security-loop | @secloop | Multi-level security (v2.27) |
| | /bugs | @bugs | Bug hunting |
| | /unit-tests | @tests | Unit test generation |
| | /refactor | @ref | Code refactoring |
| | /full-review | @review | 6-agent review |
| | /parallel | @par | Parallel subagents |
| | /adversarial | @adv | 2/3 consensus |
| **Research** | /research | @research | Web research |
| | /library-docs | @lib | Library documentation |
| | /minimax-search | @mmsearch | MiniMax search |
| | /ast-search | @ast | Structural code search |
| | /browse | @browse | Browser automation |
| | /image-analyze | @img | Image analysis |
| **Tools** | /gates | @gates | Quality gates |
| | /minimax | @mm | MiniMax query |
| | /improvements | @imp | Manage improvements |
| | /usage-audit | @audit | Usage report |
| | /retrospective | @retro | Self-improvement |
| | /commands | @cmds | List all commands |
| | /diagram | @diagram | Mermaid diagrams |

---

## Project Structure

```
multi-agent-ralph-loop/
├── .claude/
│   ├── agents/                     # 9 specialized agents
│   │   ├── orchestrator.md         # Main coordinator (Opus)
│   │   ├── security-auditor.md     # Security (Sonnet → Codex)
│   │   ├── code-reviewer.md        # Review (Sonnet → Codex)
│   │   ├── test-architect.md       # Tests (Sonnet → Codex/Gemini)
│   │   ├── debugger.md             # Debug (Opus)
│   │   ├── refactorer.md           # Refactor (Sonnet → Codex)
│   │   ├── docs-writer.md          # Docs (Sonnet → Gemini)
│   │   ├── frontend-reviewer.md    # Frontend (Opus)
│   │   └── minimax-reviewer.md     # Fallback (MiniMax)
│   ├── commands/                   # 23 slash commands
│   ├── hooks/
│   │   ├── git-safety-guard.py     # Pre-bash safety hook
│   │   └── quality-gates.sh        # Post-edit validation
│   └── skills/
│       ├── task-visualizer/        # Task dependency graphs
│       └── worktree-pr/            # Git worktree workflow
├── .ralph/
│   ├── tasks.json                  # Persistent task tracking
│   └── tasks-schema.json           # Task validation schema
├── scripts/
│   ├── ralph                       # Main CLI (v2.28.0)
│   └── mmc                         # MiniMax wrapper
├── tests/                          # 476+ tests
├── docs/
│   └── git-worktree/               # Worktree documentation
├── CLAUDE.md                       # Quick reference
├── CHANGELOG.md                    # Version history
├── README.md                       # This file
└── install.sh                      # Installation script
```

---

## Security Features

### Git Safety Guard

Pre-execution hook blocks destructive commands:

| Blocked | Reason |
|---------|--------|
| `git reset --hard` | Destroys uncommitted changes |
| `git push --force` | Rewrites remote history |
| `git clean -f` | Removes untracked files |
| `git branch -D` | Force-deletes without check |
| `rm -rf` (non-temp) | Recursive deletion |

### Security Hardening (v2.24.x)

| Fix | CWE | Description |
|-----|-----|-------------|
| Command Substitution Block | CWE-78 | Block `$()` before expansion |
| Canonical Path Validation | CWE-59 | Validate after symlink resolution |
| Decompression Bomb Protection | CWE-400 | Size + dimension validation |
| Structured Security Logging | CWE-778 | JSON audit trail |
| Input Validation | CWE-20 | All inputs validated/escaped |

---

## Testing

```bash
# Run all tests (244+)
./tests/run_tests.sh

# Run specific test suites
./tests/run_tests.sh python     # git-safety-guard.py (71 tests)
./tests/run_tests.sh bash       # All .bats files
./tests/run_tests.sh security   # Security-specific tests
```

| Component | Tests | Coverage |
|-----------|-------|----------|
| git-safety-guard.py | 71 | 99% |
| install.sh | 30 | Full |
| uninstall.sh | 28 | Full |
| ralph CLI | 33 | Full |
| mmc CLI | 21 | Full |
| quality-gates.sh | 23 | Full |
| v2.24.x security | 27 | Full |

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- Report bugs via [Issues](https://github.com/alfredolopez80/multi-agent-ralph-loop/issues)
- Propose agents using [Agent Proposal template](.github/ISSUE_TEMPLATE/new_agent.md)
- Submit pull requests for improvements

---

## License

**Business Source License 1.1 (BSL 1.1)**

- **Free for**: Non-commercial, educational, personal, internal business use
- **Restricted**: Commercial offerings competing with this project
- **Change Date**: January 1, 2030 - converts to Apache 2.0

See [LICENSE](LICENSE) for details.

---

## Credits

### Architecture Inspiration
- [Gas Town](https://github.com/atx-ai/gas-town) - Multi-agent orchestrator with persistent work tracking, Mayor/Polecats architecture
- [The Trading Floor](https://github.com/CloudAI-X/the-trading-floor) - Multi-agent architecture patterns
- [Luke Parker](https://lukeparker.dev/stop-chatting-with-ai-start-loops-ralph-driven-development) - Ralph-Driven Development philosophy
- [@nummanali](https://x.com/nummanali) - [CC Mirror](https://github.com/numman-ali/cc-mirror) and multi-agent orchestration insights

### Claude Code Ecosystem
- [Anthropic Claude Code Plugins](https://github.com/anthropics/claude-code-plugins) - Official plugins and MCP servers
- [Awesome Claude Code Setup](https://github.com/cassler/awesome-claude-code-setup) - Community configurations
- [Claude Code Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) - Quality gates implementation

### Tools & MCP Integrations
- [MiniMax MCP](https://blog.devgenius.io/claude-code-but-cheaper-and-snappy-minimax-m2-1-with-a-tiny-wrapper-7d910db93383) - @jpcaparas - 8% cost web search
- [Context7](https://github.com/upstash/context7) - Library documentation MCP server
- [ast-grep](https://ast-grep.github.io/) - Structural code search (~75% token savings)
- [dev-browser](https://github.com/anthropics/claude-code-plugins) - Browser automation (17% faster, 39% cheaper)
- [OpenAI Codex CLI](https://github.com/openai/codex) - Adversarial validation agent
- [Gemini CLI](https://github.com/google/gemini-cli) - Long-context research agent

### Community
- [WorkTrunk](https://github.com/max-sixty/worktrunk) - Git worktree management
- [Greptile](https://greptile.com) - Code review automation (optional)

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

### Latest: v2.29.0 (2026-01-07)

- **Smart Execution**: Background tasks by default, explicit quality criteria per agent
- **Auto Discovery**: Explorer/Plan invoked automatically for complex tasks (complexity >= 7)
- **Tool Selection Matrix**: Intelligent routing to ast-grep, Context7, WebSearch, MiniMax MCP
- **9 Agents Updated**: orchestrator, security-auditor, debugger, code-reviewer, test-architect, refactorer, frontend-reviewer, docs-writer, minimax-reviewer
- **New Skill**: auto-intelligence for automatic context exploration and planning

### v2.27.0 (2026-01-04)

- **Multi-Level Security Loop**: `ralph security-loop` - iterative audit until 0 vulnerabilities
- **Hybrid Approval Mode**: Auto-fix LOW/MEDIUM, manual approval for CRITICAL/HIGH
- **README Restructured**: Professional documentation with Overview, Features, Workflows

---

*"Better to fail predictably than succeed unpredictably"* - The Ralph Wiggum Philosophy
