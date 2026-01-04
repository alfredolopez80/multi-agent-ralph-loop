# 🎭 Multi-Agent Ralph Wiggum v2.26

![Version](https://img.shields.io/badge/version-2.26-blue)
![License](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen)](CONTRIBUTING.md)

> "Me fail English? That's unpossible!" - Ralph Wiggum

A sophisticated multi-agent orchestration system for Claude Code that coordinates multiple AI models (Claude, Codex CLI, MiniMax MCP) with **automatic planning**, **intensive clarification**, **git worktree isolation**, adversarial validation, self-improvement capabilities, and comprehensive quality gates.

---

## 🌟 What's New in v2.26

**Prefix-Based Slash Commands + Anthropic Best Practices** - Quick command invocation with `@` prefixes and official Claude 4 directives:

| Change | Before | After | Benefit |
|--------|--------|-------|---------|
| Command Invocation | `/orchestrator` | `@orch` | **Faster typing** |
| Command Discovery | None | `/commands` | **Easy reference** |
| Diagram Generation | Manual | `@diagram` | **Auto Mermaid** |
| Task Persistence | Session-only | `.ralph/tasks.json` | **Survives restarts** |
| Anti-Hallucination | Implicit | Explicit directive | **Anthropic official** |

### Prefix System (v2.26)

All 23 slash commands now support short `@prefix` invocation:

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH v2.26 COMMANDS                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🟣 ORCHESTRATION        🔴 REVIEW           🔵 RESEARCH       │
│  ───────────────         ─────────           ──────────        │
│  @orch  Full flow        @sec   Security     @research Web     │
│  @clarify Questions      @bugs  Bug hunt     @lib     Docs     │
│  @loop  Iterate          @tests Unit tests   @mmsearch MM      │
│                          @ref   Refactor     @ast     Code     │
│                          @review 6 agents    @browse  Browser  │
│                          @par   Parallel     @img     Image    │
│                          @adv   Consensus                      │
│                                                                 │
│  🟢 TOOLS                                                       │
│  ─────────                                                      │
│  @gates Quality gates    @mm   MiniMax       @imp  Improve     │
│  @audit Usage report     @retro Retrospect   @cmds Commands    │
│  @diagram Mermaid                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Usage Examples (v2.26)

```bash
# Prefix invocation (NEW - faster)
@orch "Implement OAuth2"       # Full orchestration
@sec src/                      # Security audit
@lib "React 19 hooks"          # Library documentation
@diagram "architecture"        # Generate Mermaid diagram
@cmds                          # List all commands

# Traditional invocation (still works)
/orchestrator "Implement OAuth2"
/security src/
/library-docs "React 19 hooks"
```

### Anthropic Best Practices (v2.26)

Official Claude 4 directives now integrated into CLAUDE.md:

| Directive | Purpose |
|-----------|---------|
| `<investigate_before_answering>` | Never speculate about unread code |
| `<use_parallel_tool_calls>` | Maximize parallel tool execution |
| `<default_to_action>` | Implement rather than just suggest |
| `<avoid_overengineering>` | Keep solutions simple and focused |
| `<code_exploration>` | Read files before proposing edits |

### Task Persistence (v2.26)

Tasks now survive session restarts via `.ralph/tasks.json`:

```
Task #1 Design    ─────────► COMPLETED
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
Task #2 Structure          Task #3 Models
   COMPLETED                   COMPLETED
          │                       │
          └───────────┬───────────┘
                      ▼
            Task #4 Endpoints
              ⚠ blocked by #2, #3 (resolved)
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
     Task #5 Tests         Task #6 Docs
       PENDING               PENDING
       (parallelizable)
```

---

## 📋 Features Overview

### Core Capabilities

| Feature | Description | Since |
|---------|-------------|-------|
| **Multi-Agent Orchestration** | Coordinate Claude, Codex, MiniMax in parallel | v2.14 |
| **Auto Planning** | Automatic `EnterPlanMode` for non-trivial tasks | v2.16 |
| **Intensive Clarification** | AskUserQuestion with MUST_HAVE/NICE_TO_HAVE | v2.16 |
| **Git Worktree Isolation** | Feature isolation via `ralph worktree` | v2.20 |
| **Adversarial Validation** | 2/3 consensus (Claude + Codex + Gemini) | v2.14 |
| **Self-Improvement** | Retrospective analysis after tasks | v2.14 |
| **9-Language Quality Gates** | TS, JS, Python, Go, Rust, Solidity, Swift, JSON, YAML | v2.14 |

### Installed Tools & MCPs

| Tool | Type | Purpose | Cost |
|------|------|---------|------|
| **WebSearch** | Native | Web research | FREE |
| **Context7 MCP** | Plugin | Library/framework documentation | Optimized |
| **MiniMax MCP** | Plugin | Web search + image analysis | ~8% |
| **ast-grep MCP** | Plugin | Structural code search | ~25% |
| **dev-browser** | Skill | Browser automation (17% faster) | -39% |
| **Nano Banana MCP** | Plugin | Image/asset generation | Variable |
| **Playwright MCP** | Plugin | Complex browser automation | Baseline |

### Search Hierarchy (v2.25)

```
┌────────────────────────────────────────────────────────────┐
│              SEARCH DECISION TREE (v2.25)                  │
├────────────────────────────────────────────────────────────┤
│                                                            │
│   ┌─────────────────────────────────────┐                  │
│   │ Is it about a library/framework?    │                  │
│   └─────────────────┬───────────────────┘                  │
│                     │                                      │
│           YES ◀─────┴─────▶ NO                             │
│            │                 │                             │
│            ▼                 ▼                             │
│   ┌─────────────┐   ┌──────────────────┐                   │
│   │ Context7    │   │ WebSearch        │                   │
│   │ MCP         │   │ (native, FREE)   │                   │
│   └──────┬──────┘   └────────┬─────────┘                   │
│          │                   │                             │
│          └─────────┬─────────┘                             │
│                    │                                       │
│                    ▼                                       │
│           ┌────────────────┐                               │
│           │ MiniMax MCP    │                               │
│           │ (8% fallback)  │                               │
│           └────────────────┘                               │
│                                                            │
│   Gemini CLI: ONLY for short, punctual tasks               │
└────────────────────────────────────────────────────────────┘
```

### CLI Commands Overview

```bash
# Orchestration
ralph orch "task"           # Full 8-step orchestration
ralph loop "task"           # Ralph loop (15 iterations)
ralph clarify "task"        # Generate clarification questions

# Search & Research (v2.25)
ralph research "query"      # WebSearch → MiniMax fallback
ralph library "React 19"    # Context7 MCP documentation
ralph browse URL            # dev-browser automation

# Code Analysis
ralph ast 'pattern' path    # Structural search (ast-grep)
ralph security path         # Security audit
ralph bugs path             # Bug hunting

# Git Worktree
ralph worktree "task"       # Create isolated worktree
ralph worktree-pr branch    # Create PR with multi-agent review

# Quality & Validation
ralph gates                 # Quality gates (9 languages)
ralph adversarial path      # 2/3 consensus validation
ralph pre-merge             # Pre-PR validation
```

---

## 🌟 What's New in v2.25

**Search Hierarchy + Context7 + dev-browser Integration** - Cost-optimized search strategy with MCP integrations:

| Change | Before | After | Savings |
|--------|--------|-------|---------|
| Web Research | Gemini CLI (60%) | WebSearch (FREE) | **60%** |
| Library Docs | MiniMax (8%) | Context7 (optimized) | **~50% tokens** |
| Browser Automation | Playwright (baseline) | dev-browser | **39% cost, 17% faster** |
| Long-Context | Gemini CLI (60%) | MiniMax (8%) | **52%** |

### New Commands (v2.25)

```bash
# Library documentation (Context7 MCP)
ralph library "React 19 useTransition"
ralph lib "Next.js 15 app router"
ralph docs "TypeScript generics"

# Browser automation (dev-browser)
ralph browse https://example.com --snapshot
ralph browse localhost:3000 --screenshot
```

### New Slash Commands (v2.25)

```bash
/library-docs React hooks      # Context7 MCP
/browse https://example.com    # dev-browser skill
```

### Updated Commands

| Command | Before | After |
|---------|--------|-------|
| `ralph research` | Gemini CLI | WebSearch → MiniMax |
| `/research` | Gemini CLI | WebSearch → MiniMax |

---

## 🌟 What's New in v2.24.2

**Complete Security Hardening** - All HIGH and MEDIUM findings from multi-agent security audit addressed:

| Fix | CWE | Severity | Description |
|-----|-----|----------|-------------|
| Command Substitution Block | CWE-78 | HIGH | Block `$()` and backticks before path expansion |
| Canonical Path Validation | CWE-59 | HIGH | Validate resolved path after symlink resolution |
| Decompression Bomb Protection | CWE-400 | HIGH | Post-download size check + pixel dimension validation |
| Structured Security Logging | CWE-778 | MEDIUM | JSON audit trail in `~/.ralph/security-audit.log` |
| Tmpdir Permission Verification | CWE-362 | MEDIUM | TOCTOU race condition mitigation |

### Security Features (v2.24.2)

- **Command Substitution Blocking**: Pre-validation blocks `$()` and backticks before any shell expansion
- **Symlink-Aware Path Validation**: Allowlist checks canonical path AFTER symlink resolution
- **Decompression Bomb Protection**: Post-download size check + optional ImageMagick dimension check (max 10000x10000)
- **Structured Security Logging**: JSON audit trail at `~/.ralph/security-audit.log` with auto-rotation
- **Tmpdir Permission Verification**: Validates 700 permissions immediately after creation

## 🌟 What's New in v2.24.1

**Security Hardening Release** - All findings from v2.24 security review addressed:

| Fix | CWE | Description |
|-----|-----|-------------|
| URL Validation | CWE-20 | 20MB size limit + MIME type check for URL images |
| Path Allowlist | CWE-22 | Interactive confirmation for files outside project |
| Prompt Injection | CWE-94 | Heredoc blocks with SECURITY INSTRUCTION markers |
| Doc Guardrails | CWE-1325 | Prompt injection warnings in slash commands |

## 🌟 What's New in v2.24

- **MiniMax MCP Web Search**: 8% cost web research via MCP protocol (87% savings vs Gemini)
- **MiniMax MCP Image Analysis**: New image analysis capability (screenshots, UI, diagrams)
- **Gemini Deprecation**: Research queries migrate to MiniMax for cost savings
- **New CLI Commands**: `ralph websearch`, `ralph image`
- **New Slash Commands**: `/minimax-search`, `/image-analyze`

### Research Tools (v2.24)

| Tool | Type | Cost | Use Case |
|------|------|------|----------|
| MiniMax MCP | Web + Image | ~8% | Default research |
| ast-grep MCP | Code | ~25% | Pattern search (v2.23) |
| Gemini CLI | Long-form | ~60% | >100k context |

### Quick Research Commands

```bash
# Web search (MiniMax MCP)
ralph websearch "React 19 features 2025"
ralph websearch "TypeScript satisfies operator examples"

# Image analysis (MiniMax MCP)
ralph image "Describe error" /tmp/screenshot.png
ralph image "Review UI" ./mockup.png

# Slash commands
/minimax-search "query"
/image-analyze "prompt" /path/to/image
```

## 🌟 What's New in v2.23

- **AST-Grep Integration**: Structural code search via MCP (~75% less tokens)
- **Hybrid Search**: Combines ast-grep (patterns) + Explore agent (semantic)
- **Search Strategy**: Intelligent tool selection via `/ast-search` command
- **Token Optimization**: AST-based search reduces token usage significantly

### Search Tools (v2.23)

| Query Type | Tool | Example | Token Savings |
|------------|------|---------|---------------|
| Exact pattern | ast-grep MCP | `console.log($MSG)` | ~75% less |
| Code structure | ast-grep MCP | `async function $NAME` | ~75% less |
| Semantic/context | Explore agent | "authentication functions" | Variable |
| Hybrid | /ast-search | Combines both | Optimized |

### Quick Search Commands

```bash
# CLI (structural search)
ralph ast 'console.log($MSG)' src/
ralph ast 'async function $NAME' .
ralph ast 'try { $BODY } catch ($E) {}' src/

# Slash command (hybrid - AST + semantic)
/ast-search "async authentication functions"
```

### Pattern Syntax

| Pattern | Meaning | Example |
|---------|---------|---------|
| `$VAR` | Single AST node | `console.log($MSG)` |
| `$$$` | Multiple nodes | `function($$$)` |
| `$$VAR` | Optional nodes | `async $$AWAIT function` |

## 🌟 What's New in v2.22

- **Startup Validation**: Fast check at every command warns about missing tools
- **On-Demand Validation**: Blocking error with installation instructions when tool needed
- **Tool Categories**: Critical (always), Feature (when needed), Quality Gates (9 languages)
- **Clear Error Messages**: ASCII box with exact installation command

### Validation Behavior

| Tool Category | Startup | On-Demand | Blocking |
|--------------|---------|-----------|----------|
| Critical (claude, jq, git) | Warning | Error + Exit | Yes |
| Feature (wt, gh, mmc, codex, gemini, sg) | Info | Error + Exit | When needed |
| Quality Gates (9 languages) | Count | Warning | No (graceful) |

### Quality Gate Tools (9 Languages)

| Language | Tools | Install |
|----------|-------|---------|
| TypeScript/JavaScript | npx, tsc, eslint | `brew install node` |
| Python | pyright, ruff | `npm i -g pyright && pip install ruff` |
| Go | go vet, staticcheck | `brew install go` |
| Rust | cargo clippy | `brew install rust` |
| Solidity | forge, solhint | `foundryup && npm i -g solhint` |
| Swift | swiftlint | `brew install swiftlint` |
| JSON | jq | `brew install jq` |
| YAML | yamllint | `pip install yamllint` |

### Ralph Loop Pattern

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
│                          └──────────▶ Back to EXECUTE          │
└─────────────────────────────────────────────────────────────────┘
```

### Model Architecture

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

## 🌟 What's New in v2.21

- **Self-Update**: `ralph self-update` syncs scripts from repo to ~/.local/bin/
- **Pre-Merge Validation**: `ralph pre-merge` validates shellcheck + versions + tests before PR
- **Integrations Check**: `ralph integrations` shows status of all tools (Greptile always **OPTIONAL**)
- **Commit Prefix**: Per-agent commit prefixes for consistent messages (security:, test:, ui:, docs:)
- **Auto Version Sync**: Prevents version mismatch issues between installed and repo scripts

### v2.20 Features (included)

- **Git Worktree Workflow**: Isolated feature development via `ralph worktree "task"`
- **Human-in-the-Loop**: Orchestrator asks user about worktree isolation (Step 2b)
- **Multi-Agent PR Review**: Claude Opus + Codex GPT-5 review before merge
- **One Worktree Per Feature**: Multiple subagents share same worktree
- **WorkTrunk Integration**: Required for worktree management (`brew install max-sixty/worktrunk/wt`)
- **8-Step Flow**: Updated orchestration with worktree decision and PR review phases

See [docs/git-worktree/](docs/git-worktree/) for comprehensive documentation.

### v2.19 Features (included)

- **VULN-001 FIX**: `escape_for_shell()` now uses `printf %q` to prevent command injection attacks
- **VULN-003 FIX**: Improved rm -rf regex patterns in git-safety-guard.py
- **VULN-004 FIX**: `validate_path()` uses `realpath -e` to resolve symlinks
- **VULN-005 FIX**: Log files now set to `chmod 600` (user-only read/write)
- **VULN-008 FIX**: All scripts start with `umask 077` for secure file creation

### v2.17 Features (included)

- **Security Hardening**: All user inputs validated and shell-escaped before execution
- **Enhanced validate_path()**: Blocks control characters, path traversal attacks, and shell metacharacters
- **New validate_text_input()**: Validates free-form text inputs (tasks, queries) with length limits
- **Safe JSON Construction**: Uses `jq` for all JSON building to prevent injection attacks

### v2.16 Features (included)

- **Auto Plan Mode**: Automatically enters `EnterPlanMode` for non-trivial tasks
- **AskUserQuestion Integration**: Uses Claude's native tool for interactive MUST_HAVE/NICE_TO_HAVE questions
- **Deep Clarification Skill**: New skill with comprehensive questioning patterns by domain
- **7-Step Flow**: Updated orchestration from 6 to 7 steps with dedicated planning phase

### v2.15 Features (included)
- **Safe Settings Merge**: Installation preserves your existing settings.json
- **Non-Destructive Install/Uninstall**: Only Ralph-specific entries are added/removed

### v2.14 Features (included)
- **Adversarial Validation**: 2/3 consensus required (Claude + Codex + Gemini)
- **15 Slash Commands**: Full command suite for orchestration
- **Self-Improvement**: Retrospective analysis after every task
- **9 Language LSP**: TS, JS, Python, Go, Rust, Solidity, Swift, JSON, YAML

## 📊 Model Distribution & Iteration Limits

| Model | Max Iterations | Cost vs Claude | Use Case |
|-------|----------------|----------------|----------|
| Claude (Sonnet/Opus) | **15** | baseline | Complex reasoning |
| MiniMax M2.1 | **30** | ~8% | Standard tasks (2x iterations) |
| MiniMax-lightning | **60** | ~4% | Extended loops (4x iterations) |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR (Opus)                          │
│                                                                 │
│  0. AUTO-PLAN   → EnterPlanMode (automatic)                    │
│  1. CLARIFY     → AskUserQuestion (MUST_HAVE/NICE_TO_HAVE)     │
│  2. CLASSIFY    → task-classifier (complexity 1-10)            │
│  2b. WORKTREE   → Ask user: "¿Requiere worktree aislado?"      │
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
│  • Security review  │  • Integration tests│  • Second opinion  │
│  • Bug hunting      │  • Research         │  • Extended loops  │
│  • Unit tests       │  • Documentation    │  • Fallback        │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

```bash
# 1. Install
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop
chmod +x install.sh
./install.sh
source ~/.zshrc  # or ~/.bashrc

# 2. Configure MiniMax (recommended for 2-4x more iterations)
mmc --setup

# 3. Use
ralph orch "Implement OAuth2 with Google"
ralph adversarial src/auth/
ralph --mmc loop "Extended task"
```

## 📁 Structure

```
multi-agent-ralph-loop/
├── .claude/
│   ├── agents/                     # 9 specialized agents
│   │   ├── orchestrator.md         # Main coordinator (Opus)
│   │   ├── security-auditor.md     # Sonnet → Codex + MiniMax
│   │   ├── code-reviewer.md        # Sonnet → Codex + MiniMax
│   │   ├── test-architect.md       # Sonnet → Codex + Gemini
│   │   ├── debugger.md             # Opus
│   │   ├── refactorer.md           # Sonnet → Codex
│   │   ├── docs-writer.md          # Sonnet → Gemini
│   │   ├── frontend-reviewer.md    # Opus
│   │   └── minimax-reviewer.md     # Universal fallback
│   ├── commands/                   # 15 slash commands
│   │   ├── orchestrator.md
│   │   ├── clarify.md
│   │   ├── full-review.md
│   │   ├── parallel.md
│   │   ├── security.md
│   │   ├── bugs.md
│   │   ├── unit-tests.md
│   │   ├── refactor.md
│   │   ├── research.md
│   │   ├── minimax.md
│   │   ├── gates.md
│   │   ├── loop.md
│   │   ├── adversarial.md
│   │   ├── retrospective.md
│   │   └── improvements.md
│   ├── hooks/
│   │   ├── git-safety-guard.py     # PreToolUse hook (blocks destructive commands)
│   │   └── quality-gates.sh        # Stop hook (9 languages)
│   └── skills/
│       ├── ask-questions-if-underspecified/
│       ├── task-classifier/
│       ├── retrospective/
│       └── worktree-pr/              # Git worktree + PR workflow (v2.20)
├── .codex/                         # Codex CLI configuration
│   ├── instructions.md
│   └── skills/
│       ├── security-review.md
│       ├── bug-hunter.md
│       ├── test-generation.md
│       └── ask-questions-if-underspecified.md
├── .gemini/                        # Gemini CLI configuration
│   └── GEMINI.md
├── docs/
│   └── git-worktree/               # Git worktree workflow documentation (v2.20)
│       ├── README.md               # Overview and quick start
│       ├── SECURITY.md             # Security considerations
│       ├── TOOLS-COMPARISON.md     # WorkTrunk vs alternatives
│       ├── INTEGRATION-GUIDE.md    # Claude Code integration
│       └── IMPLEMENTATION-PLAN.md  # Technical implementation details
├── scripts/
│   ├── ralph                       # Main CLI orchestrator
│   └── mmc                         # MiniMax wrapper with usage tracking
├── tests/                          # Comprehensive test suite (211 tests)
│   ├── run_tests.sh                # Test runner (all/python/bash/security/v218)
│   ├── test_git_safety_guard.py    # Python tests (65 tests)
│   ├── test_install_security.bats  # Install script tests (30 tests)
│   ├── test_uninstall_security.bats # Uninstall script tests (28 tests)
│   ├── test_ralph_security.bats    # Ralph CLI tests (33 tests)
│   ├── test_mmc_security.bats      # MiniMax wrapper tests (21 tests)
│   ├── test_quality_gates.bats     # Quality gates tests (23 tests)
│   └── test_settings_merge.bats    # Settings merge tests (11 tests)
├── config/
│   └── models.json
├── CLAUDE.md                       # Quick reference
├── README.md
├── TESTING.md                      # Test documentation
├── CONTRIBUTING.md                 # Contribution guidelines
├── LICENSE                         # BSL 1.1 License
├── install.sh                      # Installation script
└── uninstall.sh                    # Uninstallation script
```

## 🔐 Adversarial Validation

For critical code (auth, payments, data), require 2/3 consensus:

```bash
ralph adversarial src/auth/
```

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

## 🌲 Git Worktree + PR Workflow (v2.20)

Isolated feature development with multi-agent code review before merge.

### Why Worktrees?

- **Isolation**: Each feature develops in its own directory
- **Parallel Work**: Multiple features can progress simultaneously
- **Safe Rollback**: Easy cleanup if something goes wrong
- **PR-Based Merge**: All changes go through multi-agent review

### Workflow

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

### Requirements

```bash
# WorkTrunk (required)
brew install max-sixty/worktrunk/wt

# GitHub CLI (required for PR)
brew install gh
gh auth login
```

### Quick Example

```bash
# Create isolated worktree for new feature
ralph worktree "implement OAuth2 authentication"

# After development, create PR with review
ralph worktree-pr ai/ralph/20260103-oauth

# If review passes, merge
ralph worktree-merge 42

# Clean up all merged worktrees
ralph worktree-cleanup
```

See [docs/git-worktree/](docs/git-worktree/) for comprehensive documentation.

## 📋 All Commands

### CLI Commands

```bash
# Orchestration
ralph orch "task"           # Full 8-step orchestration
ralph loop "task"           # Loop until VERIFIED_DONE (15 iter)
ralph loop --mmc "task"     # With MiniMax (30 iter)
ralph loop --lightning "t"  # With Lightning (60 iter)
ralph clarify "task"        # Generate clarification questions

# Review (6 parallel subagents)
ralph review <path>         # Multi-model review
ralph parallel <path>       # All subagents async
ralph full-review <path>    # Alias

# Specialized
ralph security <path>       # Codex + MiniMax
ralph bugs <path>           # Codex bug hunter
ralph unit-tests <path>     # Codex (90% coverage)
ralph integration <path>    # Gemini
ralph refactor <path>       # Codex
ralph research "query"      # Gemini
ralph minimax "query"       # MiniMax (~8% cost)

# Git Worktree + PR Workflow (v2.20)
ralph worktree "task"       # Create worktree + launch Claude
ralph worktree-pr <branch>  # Create PR + multi-agent review
ralph worktree-merge <pr>   # Approve and merge PR
ralph worktree-fix <pr>     # Apply fixes from review
ralph worktree-close <pr>   # Close PR and cleanup
ralph worktree-status       # Show all worktrees
ralph worktree-cleanup      # Clean merged worktrees

# Validation
ralph gates                 # Quality gates (9 languages)
ralph adversarial <path>    # 2/3 consensus

# Self-improvement
ralph retrospective         # Analyze & propose improvements
ralph improvements          # List pending
ralph improvements apply    # Apply improvements
```

### Slash Commands (Claude Code)

```bash
/orchestrator task          # Full orchestration
/clarify task               # Clarification questions
/full-review src/           # 6 subagents
/parallel src/              # Async subagents
/security src/              # Security audit
/bugs src/                  # Bug hunting
/unit-tests src/            # Unit tests
/refactor src/              # Refactoring
/research "query"           # Web research
/minimax "query"            # Second opinion
/gates                      # Quality gates
/loop task                  # Ralph loop
/adversarial src/           # 2/3 consensus
/retrospective              # Self-improvement
/improvements               # Manage improvements
```

### Agents (@mentions)

```bash
@orchestrator task          # Main coordinator (Opus)
@security-auditor src/      # Security (Sonnet → Codex)
@code-reviewer src/         # Review (Sonnet → Codex)
@test-architect src/        # Tests (Sonnet → Codex/Gemini)
@debugger error             # Debug (Opus)
@refactorer src/            # Refactor (Sonnet → Codex)
@docs-writer module         # Docs (Sonnet → Gemini)
@frontend-reviewer src/     # Frontend (Opus)
@minimax-reviewer query     # Fallback (MiniMax)
```

## 🔧 Shell Aliases

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# Ralph
alias rh='ralph'
alias rho='ralph orch'
alias rhr='ralph review'
alias rhp='ralph parallel'
alias rhs='ralph security'
alias rhb='ralph bugs'
alias rhu='ralph unit-tests'
alias rhf='ralph refactor'
alias rhres='ralph research'
alias rhm='ralph minimax'
alias rhg='ralph gates'
alias rha='ralph adversarial'
alias rhl='ralph loop'
alias rhc='ralph clarify'
alias rhret='ralph retrospective'
alias rhi='ralph improvements'

# MiniMax
alias mm='mmc'
alias mml='mmc --loop 30'
alias mmlight='mmc --lightning'
```

## 💰 Cost Optimization

With MiniMax backend (~8% of Claude's cost):

| Metric | Claude Only | With MiniMax |
|--------|-------------|--------------|
| Cost/task | ~$0.50 | ~$0.04 |
| Max iterations | 15 | 30-60 |
| Extended loops | ❌ | ✅ |
| Second opinion | Expensive | Cheap |

## 🛡️ Git Safety Guard (PreToolUse Hook)

A critical safety hook that **automatically blocks destructive git commands** before execution. This hook is **ALWAYS ACTIVE** at the user level, protecting all your projects.

### Why This Matters

AI coding assistants can accidentally execute destructive commands that cause irreversible data loss:
- `git reset --hard` destroys all uncommitted changes
- `git push --force` rewrites remote history
- `rm -rf` outside temp directories can delete important files

### Blocked Commands

| Command | Reason |
|---------|--------|
| `git checkout -- <files>` | Discards uncommitted changes permanently |
| `git restore <files>` | Overwrites working tree without stash |
| `git reset --hard` | Destroys all uncommitted changes |
| `git reset --merge` | Can lose uncommitted changes |
| `git clean -f` | Removes untracked files permanently |
| `git push --force` / `-f` | Destroys remote history |
| `git push origin +branch` | Force push variant |
| `git branch -D` | Force-deletes without merge check |
| `git stash drop` | Permanently deletes stashed changes |
| `git stash clear` | Deletes ALL stashes |
| `rm -rf` (non-temp) | Recursive deletion outside /tmp |
| `git rebase main/master` | Rebasing shared branches |

### Safe Patterns (Allowed)

| Command | Why Safe |
|---------|----------|
| `git checkout -b <branch>` | Creates new branch |
| `git checkout --orphan` | Creates orphan branch |
| `git restore --staged` | Only unstages, doesn't discard |
| `git clean -n` / `--dry-run` | Preview mode only |
| `rm -rf /tmp/...` | Ephemeral directories |

### Configuration

The hook is configured in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${HOME}/.claude/hooks/git-safety-guard.py",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### When Blocked

If Claude tries to execute a blocked command, it receives:

```
BLOCKED by git-safety-guard: [reason]. Command: [command].
If truly needed, ask the user to run it manually.
```

### Manual Override

If you truly need to run a blocked command:
1. Claude will inform you the command was blocked
2. Copy the command and run it manually in your terminal
3. This ensures human oversight for destructive operations

## 🔍 Quality Gates (9 Languages)

| Language | Validators |
|----------|------------|
| TypeScript | `tsc --noEmit` |
| JavaScript | ESLint |
| Python | Pyright, Ruff |
| Go | go vet, staticcheck |
| Rust | Clippy |
| Solidity | solhint, forge/hardhat |
| Swift | SwiftLint |
| JSON | jq validation |
| YAML | yamllint |

## 🧪 Testing

Comprehensive test suite with **244 tests** covering all components:

```bash
# Run all tests
./tests/run_tests.sh

# Run Python tests only (git-safety-guard.py)
./tests/run_tests.sh python

# Run Bash tests only (all .bats files)
./tests/run_tests.sh bash

# Run security tests only
./tests/run_tests.sh security

# Run v2.19 security fix tests only
./tests/run_tests.sh v218
```

### Test Coverage

| Component | Tests | Coverage |
|-----------|-------|----------|
| `git-safety-guard.py` | 71 | Command normalization, safe/blocked patterns, bypass prevention (99%) |
| `install.sh` | 30 | Permissions, backup, dependencies, shell config |
| `uninstall.sh` | 28 | Safe removal, settings preservation, markers |
| `ralph` CLI | 33 | Security functions, CLI commands, iteration limits |
| `mmc` CLI | 21 | API handling, JSON escaping, log permissions |
| `quality-gates.sh` | 23 | Language detection, JSON validation, blocking modes |
| `settings merge` | 11 | User config preservation, schema handling |
| `v2.24.1 security` | 27 | URL validation, path allowlist, prompt injection, doc guardrails |

### Requirements

```bash
# Install test dependencies
pip install pytest pytest-cov
brew install bats-core
```

See [TESTING.md](TESTING.md) for detailed test documentation.

## 📚 Inspiration & Credits

This project was inspired by and builds upon the work of these amazing contributors:

### Multi-Agent Orchestration
- **The Trading Floor** - Multi-agent trading system architecture
  [CloudAI-X/the-trading-floor](https://github.com/CloudAI-X/the-trading-floor)

### Ralph-Driven Development
- **Luke Parker** - "Stop Chatting with AI, Start Loops: Ralph-Driven Development"
  [lukeparker.dev](https://lukeparker.dev/stop-chatting-with-ai-start-loops-ralph-driven-development)

### Claude Code Setup & Hooks
- **Awesome Claude Code Setup** - Comprehensive Claude Code configurations
  [cassler/awesome-claude-code-setup](https://github.com/cassler/awesome-claude-code-setup)
- **Destructive Git Command Hooks** - Safe git operations with Claude
  [Dicklesworthstone/misc_coding_agent_tips_and_scripts](https://github.com/Dicklesworthstone/misc_coding_agent_tips_and_scripts/blob/main/DESTRUCTIVE_GIT_COMMAND_CLAUDE_HOOKS_SETUP.md)

### Community Ideas & Discussions
- [Multi-agent orchestration patterns](https://x.com/i/status/2006110425373347882)
- [Agent coordination strategies](https://x.com/i/status/2006138974834716993)
- [Quality validation approaches](https://x.com/i/status/2006132522468454681)
- [Extended loop techniques](https://x.com/i/status/2006624792531923266)

### Tools & Wrappers
- **MiniMax Wrapper**: [@jpcaparas](https://twitter.com/jpcaparas) - [DevGenius Article](https://blog.devgenius.io/claude-code-but-cheaper-and-snappy-minimax-m2-1-with-a-tiny-wrapper-7d910db93383)
- **Anthropic Official Plugins**: [anthropics/claude-code-plugins](https://github.com/anthropics/claude-code-plugins)

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Ways to contribute:**
- Report bugs and suggest features via [Issues](https://github.com/alfredolopez/multi-agent-ralph-loop/issues)
- Propose new agents using the [Agent Proposal template](.github/ISSUE_TEMPLATE/new_agent.md)
- Submit pull requests for improvements
- Share your use cases and feedback

## 📄 License

**Business Source License 1.1 (BSL 1.1)**

- **Free for**: Non-commercial use, educational use, personal use, internal business use
- **Restricted**: Commercial offerings that compete with this project
- **Change Date**: January 1, 2030 - converts to Apache 2.0

See [LICENSE](LICENSE) file for full details.

---

*"Better to fail predictably than succeed unpredictably"* - The Ralph Wiggum Philosophy
