# Multi-Agent Ralph Wiggum

![Version](https://img.shields.io/badge/version-2.45.1-blue)
![License](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen)](CONTRIBUTING.md)

> "Me fail English? That's unpossible!" - Ralph Wiggum

---

## Overview

**Multi-Agent Ralph Wiggum** is a sophisticated orchestration system for Claude Code and OpenCode that coordinates multiple AI models to deliver high-quality, validated code through iterative refinement loops.

The system addresses the fundamental challenge of AI-assisted coding: **ensuring quality and consistency across complex tasks**. Rather than relying on a single AI model's output, Ralph orchestrates multiple specialized agents working in parallel, with automatic validation gates and adversarial spec debates for rigorous requirements.

## About

Ralph is a dual-runtime orchestrator that adapts model routing based on whether it is invoked from Claude Code or OpenCode. It standardizes workflows (clarify → plan → execute → validate) while letting each environment use the best available models.

**v2.45.1 Highlights**:
- **Lead Software Architect (LSA)**: Architecture guardian verifies each step against ARCHITECTURE.md
- **Plan-Sync Pattern**: Catches drift when implementation diverges from spec, patches downstream specs
- **Auto Plan-State Hook**: `auto-plan-state.sh` automatically creates `plan-state.json` when `orchestrator-analysis.md` is written
- **5 New Agents**: `@lead-software-architect`, `@plan-sync`, `@gap-analyst`, `@quality-auditor`, `@adversarial-plan-validator`
- **plan-state.json**: Structured spec vs actual tracking (context as queryable variable)
- **12-Step Workflow**: Nested loop with LSA-VERIFY → IMPLEMENT → PLAN-SYNC → MICRO-GATE
- **69+ Integration Tests**: Comprehensive pytest suite validates v2.45.1 hooks, agents, and workflows
- **Security Fixes**: Atomic temp file handling (race conditions), path traversal prevention, command injection fix

**v2.44 Highlights**:
- **Plan Mode Integration**: Orchestrator analysis now feeds INTO Claude Code's native Plan Mode (one unified plan)
- **Step 3b: PERSIST**: Writes `.claude/orchestrator-analysis.md` before EnterPlanMode
- **Global Rule**: `~/.claude/rules/plan-mode-orchestrator.md` instructs Plan Mode to read analysis file
- **Auto-Cleanup Hook**: `plan-analysis-cleanup.sh` backs up and removes analysis after ExitPlanMode
- **10-Step Workflow**: Expanded from 8 steps to include PERSIST and PLAN MODE steps
- **Extension Workaround**: `/compact` skill for manual context save in VSCode/Cursor

**v2.43 Highlights**:
- **Claude-Mem Integration**: Semantic memory with 3-layer workflow (search → timeline → get_observations)
- **PreToolUse additionalContext**: Session context injection for Task subagents
- **LSP-Explore Skill**: Token-free code navigation (go-to-definition, find-references, hover)
- **MCP auto:10 Optimization**: Deferred tool loading until 10% context usage
- **StatusLine Git Enhancement**: Shows current branch/worktree with change indicators (⎇ main*)
- **VERSION Markers**: All config files now have `# VERSION: 2.44.0` for tracking
- **Config Cleanup**: `ralph cleanup-project-configs` removes old local configs for global inheritance
- **Auto-Sync CLI**: `ralph sync-global` now auto-updates `~/.local/bin/ralph` (7-step sync)
- **Modernized Skills**: YAML allowed-tools, agent field, hooks in frontmatter

**v2.42 Highlights**:
- **Stop Hook Verification**: Validates completion before session end (TODOs, git status, lint, tests)
- **2-Action Rule (Auto-Save)**: Auto-saves context every 5 operations to prevent mid-task loss
- **Two-Stage Review**: `/adversarial` separates Spec Compliance → Code Quality
- **3-Fix Rule Enforcement**: Mandatory escalation after 3 failed fix attempts
- **Socratic Design**: `/clarify` presents 2-3 alternatives with trade-offs

**v2.41 Highlights**:
- **Context Engineering Optimization**: `context: fork` for all Task()-using skills, progress.md tracking, PIN/Lookup tables

**v2.40 Highlights**:
- **Full OpenCode Compatibility**: Automatic model migration from Claude (opus/sonnet/haiku) to OpenCode-compatible models (gpt-5.2-codex/minimax-m2.1)
- **Integration Test Suite**: 26 pytest tests validate skills, hooks, llm-tldr, and configuration hierarchy
- **Dual-Sync Architecture**: `ralph sync-to-opencode` maintains parallel Claude Code and OpenCode configurations

### What It Does

- **Orchestrates Multiple AI Models**: Coordinates Claude (Opus/Sonnet), OpenAI Codex, Google Gemini, and MiniMax in parallel workflows
- **Iterative Refinement**: Implements the "Ralph Loop" pattern - execute, validate, iterate until quality gates pass
- **Quality Assurance**: 9-language quality gates (TypeScript, Python, Go, Rust, Solidity, Swift, JSON, YAML, JavaScript)
- **Adversarial Spec Refinement**: adversarial-spec debate to harden specs before execution
- **Automatic Context Preservation**: 100% automatic ledger/handoff system preserves session state across compactions (v2.35)
- **Self-Improvement**: Retrospective analysis after every task to propose workflow improvements
- **Ultrathink Doctrine**: Domain-specific craftsmanship principles guide every agent's workflow (v2.39)

### Why Use It

| Challenge | Ralph's Solution |
|-----------|------------------|
| AI outputs vary in quality | Multi-model spec debate via adversarial-spec |
| Single-pass often insufficient | Iterative loops (15-60 iterations) until VERIFIED_DONE |
| Manual review bottleneck | Automated quality gates + human-in-the-loop for critical decisions |
| Context limits | MiniMax (1M tokens) + Context7 MCP for documentation |
| Context loss on compaction | Automatic ledger/handoff preservation (85-90% token reduction) |
| High API costs | Cost-optimized routing (WebSearch FREE, MiniMax 8%, strategic Opus usage) |

---

## Key Features

### Multi-Agent Orchestration

| Feature | Description |
|---------|-------------|
| **14 Specialized Agents** | 9 core + 5 auxiliary review agents |
| **12-Step Workflow (v2.45)** | Evaluate → Clarify → Gap-Analyze → Classify → Worktree → Plan → Persist → Plan-State → Plan Mode → Execute-with-Sync → Validate → Retrospect |
| **Plan Mode Integration** | Orchestrator analysis feeds INTO Claude Code's Plan Mode (unified plan) |
| **Parallel Execution** | Multiple agents work simultaneously on independent subtasks |
| **Model Routing** | Automatic selection: Opus (critical), Sonnet (standard), MiniMax (extended) |

**Core Agents (9):**
`orchestrator`, `security-auditor`, `code-reviewer`, `test-architect`, `debugger`, `refactorer`, `docs-writer`, `frontend-reviewer`, `minimax-reviewer`

**Auxiliary Review Agents (5 - v2.35):**

| Agent | Trigger | Purpose |
|-------|---------|---------|
| `code-simplicity-reviewer` | LOC > 100 after implementation | YAGNI enforcement, complexity reduction |
| `architecture-strategist` | Changes span ≥3 modules OR complexity ≥7 | SOLID compliance, architectural review |
| `kieran-python-reviewer` | Any .py file modified | Type hints, Pythonic patterns, testability |
| `kieran-typescript-reviewer` | Any .ts/.tsx/.js/.jsx file modified | Type safety, modern patterns |
| `pattern-recognition-specialist` | Refactoring tasks planned | Design patterns, anti-patterns, duplication |

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

### YAML-based Skills System (v2.32)

| Feature | Description |
|---------|-------------|
| **H70-Inspired Architecture** | Lightweight YAML skills achieving +36.7pts improvement (94.5% vs 57.8% baseline) |
| **4-File Structure** | skill.yaml, sharp-edges.yaml, validations.yaml, collaboration.yaml |
| **Regex-based Validation** | Automated pattern detection and quality checks |
| **Inter-skill Collaboration** | Delegation rules and workflow orchestration |
| **Extended Iterations** | Claude: 25 (+10), MiniMax: 50 (+20), Lightning: 100 (+40) |
| **Hook Registration Fix** | v2.30 hooks now properly registered (context-warning, periodic-reminder, checkpoint-auto-save) |

```bash
ralph skill create api-security    # Create new skill from template
ralph skill validate security-hardening  # Validate YAML structure
ralph skill list                   # List all available skills
```

### PRD Generation System (v2.32)

| Feature | Description |
|---------|-------------|
| **Structured Requirements** | Product Requirements Document system with INVEST-compliant user stories |
| **Template-based** | Comprehensive PRD template with all standard sections (Overview, Goals, Stories, Tech Requirements, Success Criteria) |
| **Story Conversion** | Automated conversion from PRD markdown to executable JSON user stories |
| **Status Tracking** | Progress monitoring across all PRDs and stories |
| **Orchestrator Integration** | Auto-recommended for complexity >= 7 (reduces LLM error margin via small, precise subtasks) |
| **Error Reduction** | Breaks complex features into focused user stories with clear acceptance criteria and multiple verification points |

```bash
ralph prd create "OAuth2 authentication"  # Create PRD from template
ralph prd convert tasks/prd-oauth2.md     # Convert to user stories (JSON)
ralph prd status                          # Show PRD progress
ralph loop --prd tasks/prd-oauth2.json    # Execute stories iteratively
```

### Sentry Observability Integration (v2.33)

| Feature | Description |
|---------|-------------|
| **Skills-First Approach** | 80% of value WITHOUT requiring Sentry MCP configuration |
| **Orchestrator Enhancements** | Optional Sentry steps (2c, 6b, 7b) with 100% backward compatibility |
| **Context Isolation** | All Sentry skills use `context: fork` for clean execution |
| **PR Workflow Integration** | Sentry bot priority in iterate-pr, auto-fix via sentry-code-review |
| **Production Correlation** | find-bugs correlates local issues with live Sentry data |
| **Anti-Pattern Detection** | deslop removes Sentry over-instrumentation |
| **Graceful Degradation** | All Sentry features optional, no breaking changes |

```bash
# Phase 1: Setup (No MCP required)
ralph sentry-init              # Auto-detect project type and configure SDK
ralph sentry-init --tracing    # Setup tracing only
ralph sentry-init --all        # Full observability stack

# Phase 2: Validation & PR Review (No MCP required)
ralph sentry-validate          # Check configuration
ralph code-review-sentry <branch>  # Wait for Sentry bot + auto-fix
ralph iterate <pr>             # Enhanced with Sentry priority
```

**Sentry Integration Components:**

| Component | Uses MCP? | When to Use |
|-----------|-----------|-------------|
| sentry-setup-* skills | ❌ NO | Auto-configure SDK (tracing, logging, metrics, AI) |
| sentry-code-review | ❌ NO | Fix Sentry bot PR comments |
| iterate-pr (enhanced) | ❌ NO | Prioritize Sentry checks in PR workflow |
| find-bugs (enhanced) | ❌ NO | Correlate with production issues (optional) |
| deslop (enhanced) | ❌ NO | Remove Sentry over-instrumentation |
| issue-summarizer | ✅ YES | Deep issue analysis (optional Phase 3) |
| /seer, /getIssues | ✅ YES | Natural language queries (optional Phase 3) |

### Codex CLI v0.79.0 Security Hardening (v2.34)

| Feature | Description |
|---------|-------------|
| **Zero --yolo Usage** | 10/11 invocations (91%) eliminated → 0/11 (0%) ✅ Complete removal of insecure auto-approval |
| **100% Sandbox Isolation** | All Codex invocations use proper sandboxing (0% → 100%) |
| **Configuration Profiles** | 5 specialized profiles (security-audit, bug-hunting, code-review, unit-tests, ci-cd) |
| **Secure by Default** | Global config: `approval_policy=on-request` + `sandbox_mode=workspace-write` |
| **Output Schemas** | JSON validation eliminates ~20% parsing failures (100% reliable) |
| **Convenience Flags** | `--full-auto` for balanced automation (workspace-write + on-request) |
| **Native Review** | `codex review` for Git-aware PR reviews |
| **Auto-initialization** | `init_codex_schemas()` creates schemas on startup |

**Security Impact:**
- **VULN-009 (HIGH)** - Eliminated: All `--yolo` flags removed from 11 Codex invocations
- **Sandbox Security** - Upgraded: read-only for audits, workspace-write for development
- **Approval Control** - Enhanced: Fine-grained policies (untrusted, on-failure, on-request, never)

```bash
# Security audit (read-only sandbox, o3 model for max reasoning)
ralph security src/

# Bug hunting (workspace-write, interactive approval)
ralph bugs src/

# Unit test generation (workspace-write)
ralph unit-tests src/

# Code review (Git-aware native review)
ralph review main..feature-branch

# Security loop (iterative audit + fix until 0 vulnerabilities)
ralph security-loop src/ --max-rounds 10
```

**Configuration Profiles (v2.34):**

| Profile | Model | Sandbox | Approval | Use Case |
|---------|-------|---------|----------|----------|
| security-audit | o3 | read-only | on-failure | Security audits - no file mods |
| bug-hunting | gpt-5.2-codex | workspace-write | on-request | Bug detection + fixes |
| code-review | gpt-5.2-codex | workspace-write | on-request | PR reviews, refactoring |
| unit-tests | gpt-5.2-codex | workspace-write | on-request | Test generation |
| ci-cd | gpt-5.2-codex | danger-full-access | never | ⚠️ CI/CD ONLY |

**Migration (v2.33 → v2.34):**
- All 11 Codex invocations updated automatically
- Backward compatible - existing commands work with safer defaults
- Use `--profile ci-cd` to match old `--yolo` behavior (CI/CD only)

### LLM-TLDR Token Optimization (v2.37)

| Feature | Description |
|---------|-------------|
| **95% Token Savings** | Reduce 21,000 tokens to 175 for function context |
| **155x Faster Queries** | Daemon mode with 100ms latency vs 30s CLI |
| **5-Layer Analysis** | AST → Call Graph → CFG → DFG → PDG |
| **16 Languages** | Python, TypeScript, JavaScript, Go, Rust, Java, C, C++, Ruby, PHP, C#, Kotlin, Scala, Swift, Lua, Elixir |
| **Semantic Search** | 1024-dim embeddings via bge-large-en-v1.5 |
| **MCP Integration** | Built-in `tldr-mcp` for Claude Code/Desktop |

**Orchestrator Integration:**
- **Step 1 (CLARIFY)**: `tldr semantic` finds existing functionality
- **Step 3 (PLAN)**: `tldr impact` shows change blast radius
- **Step 5 (EXECUTE)**: `tldr context` prepares minimal context for subagents

```bash
ralph tldr warm .              # Build semantic index
ralph tldr semantic "auth" .   # Search by behavior
ralph tldr context login .     # LLM-optimized context
ralph tldr impact handler .    # Find all callers
ralph tldr structure src/      # Codebase structure
ralph tldr dead .              # Find dead code
```

**Skills (4):**
- `/tldr` - Main command interface
- `/tldr-semantic` - Behavior-based code search
- `/tldr-impact` - Change impact analysis
- `/tldr-context` - Optimized context for orchestrator

**Installation**: `pip install llm-tldr`

### OpenCode Model Migration & Integration Testing (v2.40)

| Feature | Description |
|---------|-------------|
| **OpenCode Model Migration** | Automatic conversion from Claude models to OpenCode-compatible alternatives |
| **26 Integration Tests** | Comprehensive pytest suite validates all v2.40 components |
| **Dual-Sync Architecture** | Parallel configurations for Claude Code (`~/.claude/`) and OpenCode (`~/.config/opencode/`) |
| **Model Compatibility Validation** | Automatic check for Claude model references in OpenCode config |
| **Backup System** | Automatic backups before model migration |

**Model Mapping (OpenCode Compatibility)**:

| Claude Model | OpenCode Model | Use Case |
|--------------|----------------|----------|
| `opus` | `gpt-5.2-codex` | Complex reasoning, architecture |
| `sonnet` | `minimax-m2.1` | Standard tasks, subagents |
| `haiku` | `minimax-m2.1-lightning` | Fast tasks, quick validation |

**Commands**:
```bash
# Sync Claude Code config to OpenCode (preserves structure)
ralph sync-to-opencode

# Migrate Claude models to OpenCode-compatible alternatives
./scripts/migrate-opencode-models.sh
./scripts/migrate-opencode-models.sh --dry-run  # Preview changes

# Validate integration (25 checks)
./scripts/validate-integration.sh
ralph validate-integration

# Run pytest suites
pytest tests/test_v2_40_integration.py -v    # v2.40 integration
pytest tests/test_v2_45_integration.py -v    # v2.45.1 features
pytest tests/test_hooks_registration.py -v   # Hook registry validation
pytest tests/ -v                             # All tests (69+)
```

**Test Coverage (v2.45.1)**:

| Test Class | Tests | Purpose |
|------------|-------|---------|
| `TestSkillsDiscovery` | 3 | Global skills directory and critical skills |
| `TestSkillFrontmatter` | 2 | YAML frontmatter validation |
| `TestTldrIntegration` | 6 | llm-tldr installation and hooks |
| `TestUltrathinkIntegration` | 3 | ultrathink skill with model: opus |
| `TestHooksConfiguration` | 4 | Critical hooks and settings.json |
| `TestConfigurationHierarchy` | 3 | Global vs local configuration |
| `TestProjectInheritance` | 2 | Multi-project inheritance |
| `TestOpenCodeSync` | 2 | OpenCode directory sync |
| `TestRalphBackups` | 2 | Backup functionality |
| `TestCmdOrchV2451` | 5 | cmd_orch 12-step workflow validation |
| `TestAutoPlanStateHook` | 7 | auto-plan-state.sh hook functionality |
| `TestV2451Hooks` | 6 | v2.45.1 hook registration and features |
| `TestV245Agents` | 5 | 5 new v2.45 agents validation |
| `TestPlanStateSchema` | 3 | plan-state.json schema validation |

**v2.45.1 Tests Total: 69** (test_v2_45_integration.py + test_hooks_registration.py)

**Full Test Suite: 474+ tests** (all versions combined)

### OpenAI Documentation Access (v2.37)

| Feature | Description |
|---------|-------------|
| **Context7 MCP Integration** | Access 10,000+ OpenAI documentation snippets |
| **Codex CLI Docs** | 614 snippets for Codex CLI configuration and usage |
| **OpenAI API Docs** | 9,418 snippets for API integration |
| **SDK Documentation** | Python (429), Node.js (437) SDK snippets |
| **Claude-Codex Bridge** | Enhanced skill for seamless collaboration |

**Available Documentation Libraries:**

| Library ID | Content | Snippets |
|------------|---------|----------|
| `/websites/developers_openai_codex` | Codex CLI documentation | 614 |
| `/websites/platform_openai` | OpenAI API documentation | 9,418 |
| `/openai/openai-python` | Python SDK | 429 |
| `/openai/openai-node` | Node.js SDK | 437 |

**Skills (2):**
- `/openai-docs` - Query OpenAI documentation via Context7 MCP
- `/codex-cli` - Enhanced Codex CLI orchestration with documentation lookup

```bash
# Query Codex CLI documentation before execution
# Use Context7 MCP with libraryId="/websites/developers_openai_codex"

# Query OpenAI API documentation
# Use Context7 MCP with libraryId="/websites/platform_openai"
```

### Commands → Skills Unification (v2.36)

| Feature | Description |
|---------|-------------|
| **Claude Code v2.1.3 Aligned** | Unified commands/skills following Anthropic's merged mental model |
| **185 Global Skills** | All commands migrated to `~/.claude/skills/` with proper frontmatter |
| **Progressive Disclosure** | Metadata (~100 tokens) always loaded, body (<5k tokens) on activation |
| **`context: fork`** | Context isolation for quality gates, adversarial, parallel skills |
| **Agent Hooks** | 5 priority agents with PreToolUse/PostToolUse/Stop hooks for logging |
| **PostCompact Recovery** | Automatic context restoration via SessionStart:compact event |
| **Threshold Update** | Context warning 60%→80%, critical 75%→85% (aligned with Claude Code v2.1.0) |

**Skills Architecture (Anthropic skill-creator pattern):**

```
~/.claude/skills/
├── orchestrator/SKILL.md      # 8-step workflow (most critical)
├── clarify/SKILL.md           # AskUserQuestion workflow
├── gates/SKILL.md             # 9-language quality gates (context: fork)
├── adversarial/SKILL.md       # adversarial-spec debate (context: fork)
├── loop/SKILL.md              # Ralph Loop pattern
├── parallel/SKILL.md          # Concurrent execution (context: fork)
├── retrospective/SKILL.md     # Post-task analysis
└── ... 178 more skills
```

**Agent Hooks (v2.36):**

| Agent | Hooks | Purpose |
|-------|-------|---------|
| `security-auditor` | PreToolUse, PostToolUse, Stop | Security audit logging |
| `orchestrator` | PreToolUse, PostToolUse, Stop | Orchestration tracking |
| `code-reviewer` | PreToolUse, PostToolUse | Review metrics |
| `test-architect` | PreToolUse, PostToolUse | Test coverage tracking |
| `debugger` | PreToolUse, PostToolUse, Stop | Debug session logging |

```bash
# Logs stored in ~/.ralph/logs/
# - security-audit.log
# - orchestration.log
# - code-review.log
# - test-coverage.log
# - debug.log
```

### Automatic Context Preservation (v2.35)

| Feature | Description |
|---------|-------------|
| **100% Automatic** | No user intervention required after one-time `ralph setup-context-engine` |
| **Ledger System** | CONTINUITY_RALPH-<session>.md files preserve session state (~500 tokens) |
| **Handoff System** | handoff-<timestamp>.md documents for context transfer (~300 tokens) |
| **SessionStart Hook** | Auto-loads ledger + handoff at session start (startup/resume/compact) |
| **PreCompact Hook** | Auto-saves state BEFORE context compaction (prevents information loss) |
| **Memvid Integration** | Hybrid storage with HNSW + BM25 semantic search for handoff queries |
| **85-90% Context Reduction** | Optimized token injection vs full context reload |
| **Feature Flags** | Enable/disable via `~/.ralph/config/features.json` |

**Context Engine Architecture:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH v2.35 CONTEXT ENGINE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [SessionStart Hook] - Auto-load at session start               │
│  ├── Auto-load CONTINUITY_RALPH.md (~500 tokens)               │
│  ├── Auto-load last handoff.md (~300 tokens)                   │
│  └── Inject via hookSpecificOutput.additionalContext           │
│                                                                 │
│  [PreCompact Hook] - Auto-save before compaction                │
│  ├── Auto-save ledger to ~/.ralph/ledgers/                     │
│  ├── Auto-create handoff to ~/.ralph/handoffs/                 │
│  └── Index to Memvid for semantic search                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Automation Matrix (Zero User Intervention):**

| Event | Trigger | Automatic Action |
|-------|---------|------------------|
| Session start | SessionStart hook | Loads ledger + handoff |
| Context 70%+ | claude-hud | Yellow warning displayed |
| Context 85%+ | claude-hud | Red warning displayed |
| Pre-compaction | PreCompact hook | Saves ledger + handoff + Memvid |
| Post-compaction | SessionStart hook | Reloads fresh context |

```bash
# One-time setup (REQUIRED ONCE)
ralph setup-context-engine  # Creates dirs, registers hooks, validates

# Manual commands (OPTIONAL - usually automatic)
ralph ledger save [id] [goal]   # Save session state
ralph ledger list               # List available ledgers
ralph handoff create [id]       # Create manual handoff
ralph handoff search "query"    # Search handoffs (Memvid)
```

**Migration (v2.34 → v2.35):**
- Run `ralph setup-context-engine` once to enable
- 100% backward compatible - disable features via flags
- All existing functionality preserved

### Global Configuration Sync (v2.35)

| Feature | Description |
|---------|-------------|
| **Global Directory** | `~/.claude/` stores agents, commands, skills, hooks available in ALL projects |
| **sync-global Command** | Propagates configurations from ralph repo to global directory |
| **Settings.json Merge** | Automatically merges hook configurations across projects |
| **42 Validation Tests** | Comprehensive test suite ensures sync consistency |

**Configuration Hierarchy:**

```
┌─────────────────────────────────────────────────────────────────┐
│              CONFIGURATION HIERARCHY                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [GLOBAL - ~/.claude/]                                         │
│  ├── agents/    (27 agents - always available)                 │
│  ├── commands/  (33 slash commands - always available)         │
│  ├── skills/    (169 skills - always available)                │
│  ├── hooks/     (17 hook scripts)                              │
│  └── settings.json (6 hook event types)                        │
│                                                                 │
│  [PROJECT-LOCAL - .claude/]                                    │
│  └── Can extend/override global configurations                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

```bash
# Sync all configurations to global (run after updating ralph repo)
ralph sync-global           # Full sync
ralph sync-global --dry-run # Preview changes
ralph sync-global --force   # Overwrite all files

# Syncs: agents, commands, skills, hooks, settings.json
```

### Quality & Validation

| Feature | Description |
|---------|-------------|
| **9-Language Quality Gates** | TypeScript, JavaScript, Python, Go, Rust, Solidity, Swift, JSON, YAML |
| **Adversarial Spec Refinement** | adversarial-spec debate for requirements before build |
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
| **CLI Commands** | 30+ | `ralph orch`, `ralph security-loop`, `ralph ledger`, `ralph handoff` |
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
│                   │(max 25/50)  │          │   (output)   │    │
│                   └──────┬──────┘          └──────────────┘    │
│                          │                                     │
│                          └──────────▶ Back to EXECUTE          │
│                                                                 │
│   Iteration Limits (v2.32):                                     │
│   • Claude (Sonnet/Opus): 25 iterations (+10 from v2.31)       │
│   • MiniMax M2.1: 50 iterations (+20 from v2.31)               │
│   • MiniMax-lightning: 100 iterations (+40 from v2.31)         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Full Orchestration Flow (12 Steps) - v2.45.1

Complete workflow from task request to verified completion:

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR (Opus) v2.45.1                  │
│                                                                 │
│  0. EVALUATE    → Quick complexity assessment (trivial?)       │
│  1. CLARIFY     → AskUserQuestion (MUST_HAVE/NICE_TO_HAVE)     │
│  1b. GAP-ANALYST→ Pre-implementation gap analysis (v2.45)      │
│  2. CLASSIFY    → task-classifier (complexity 1-10)            │
│  2b. WORKTREE   → Ask user: "Requires isolated worktree?"      │
│  3. PLAN        → Design detailed plan (orchestrator analysis) │
│  3b. PERSIST    → Write to .claude/orchestrator-analysis.md    │
│  3c. PLAN-STATE → auto-plan-state.sh creates plan-state.json   │  ← NEW v2.45.1
│  4. PLAN MODE   → EnterPlanMode (reads analysis as foundation) │
│  5. DELEGATE    → Route to optimal model                       │
│  6. EXECUTE-WITH-SYNC → Nested loop per step (v2.45):          │  ← ENHANCED
│     6a. LSA-VERIFY  → Architecture pre-check                   │
│     6b. IMPLEMENT   → Execute step                             │
│     6c. PLAN-SYNC   → Detect drift, patch downstream           │
│     6d. MICRO-GATE  → Per-step quality (3-Fix Rule)            │
│  7. VALIDATE    → Multi-stage validation (v2.45):              │  ← ENHANCED
│     7a. QUALITY-AUDITOR → 6-phase pragmatic audit              │
│     7b. GATES       → 9-language quality gates                 │
│     7c. ADVERSARIAL-SPEC → Spec refinement (if complexity ≥7)  │
│     7d. ADVERSARIAL-PLAN → Opus + Codex cross-validation       │
│  8. RETROSPECT  → Self-improvement proposals                   │
│  8b. PR REVIEW  → If worktree: Claude + Codex review → merge   │
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

### 4. Adversarial Spec Refinement (Two-Stage Review v2.42)

Multi-model debate with two-stage validation:

```
┌─────────────────────────────────────────────────────────────────┐
│              ADVERSARIAL TWO-STAGE REVIEW (v2.42)               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  STAGE 1: SPEC COMPLIANCE (Exit before Stage 2 if fails)       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [ ] Meets all stated requirements                        │  │
│  │ [ ] Covers all use cases                                 │  │
│  │ [ ] Respects constraints                                 │  │
│  │ [ ] Handles edge cases                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                         │                                       │
│                         ▼ PASS                                  │
│  STAGE 2: CODE QUALITY                                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [ ] Follows codebase patterns                            │  │
│  │ [ ] Performance OK                                       │  │
│  │ [ ] Security applied                                     │  │
│  │ [ ] Tests adequate                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Output: finalized PRD/tech spec + quality validation           │
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
| adversarial-spec (Claude) | Optional | Spec refinement (/adversarial) | `claude plugin install adversarial-spec` |
| adversarial-spec (OpenCode) | Optional | Spec refinement (/adversarial) | `opencode plugin install adversarial-spec` |
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

# Adversarial spec refinement
ralph adversarial "Design a rate limiter service"

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
ralph adversarial <input>      # adversarial-spec debate
ralph pre-merge                # Pre-PR validation

# Maintenance
ralph self-update              # Sync scripts from repo
ralph integrations             # Show tool status

# OpenCode Sync (v2.40)
ralph sync-to-opencode         # Sync to ~/.config/opencode/
ralph validate-integration     # Run 25-check validation
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
| | /adversarial | @adv | adversarial-spec debate |
| **Research** | /research | @research | Web research |
| | /library-docs | @lib | Library documentation |
| | /lsp-explore | @lsp | Token-free code navigation (v2.43) |
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
│   ├── ralph                       # Main CLI (v2.40)
│   ├── mmc                         # MiniMax wrapper
│   ├── validate-integration.sh     # v2.40 integration validator
│   └── migrate-opencode-models.sh  # Claude→OpenCode model migration
├── tests/
│   ├── conftest.py                 # Pytest fixtures (v2.40)
│   └── test_v2_40_integration.py   # 26 integration tests
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
- [LLM-TLDR](https://github.com/syedazharmbnr1/llm-tldr) - @syedazharmbnr1 - 5-layer code analysis with 95% token savings (v2.37)
- [Claude-Mem MCP](https://github.com/anthropics/claude-code-plugins) - Semantic memory with 3-layer workflow: search → timeline → get_observations
- [Context7 MCP](https://github.com/upstash/context7) - Library documentation including OpenAI/Codex docs (10,000+ snippets)
- [MiniMax MCP](https://blog.devgenius.io/claude-code-but-cheaper-and-snappy-minimax-m2-1-with-a-tiny-wrapper-7d910db93383) - @jpcaparas - 8% cost web search
- [ast-grep](https://ast-grep.github.io/) - Structural code search (~75% token savings)
- [dev-browser](https://github.com/anthropics/claude-code-plugins) - Browser automation (17% faster, 39% cheaper)
- [OpenAI Codex CLI](https://github.com/openai/codex) - Adversarial validation agent with `/codex-cli` skill integration
- [Gemini CLI](https://github.com/google/gemini-cli) - Long-context research agent

### Community
- [WorkTrunk](https://github.com/max-sixty/worktrunk) - Git worktree management

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

### Latest: v2.45.1 (2026-01-17)

- **Lead Software Architect (LSA)**: Architecture guardian verifies each step against ARCHITECTURE.md
- **Plan-Sync Pattern**: Catches drift when implementation diverges from spec, patches downstream
- **Auto Plan-State Hook**: `auto-plan-state.sh` automatically creates `plan-state.json` when `orchestrator-analysis.md` is written (PostToolUse Write trigger)
- **Gap-Analyst Agent**: Pre-implementation gap analysis for missing requirements
- **Quality-Auditor Agent**: 6-phase pragmatic code audit
- **Adversarial-Plan-Validator**: Cross-validation between Claude Opus and Codex GPT-5.2
- **plan-state.json**: Structured tracking of spec vs actual implementation (context as queryable variable)
- **12-Step Workflow**: Expanded from 10 steps with nested LSA-VERIFY → IMPLEMENT → PLAN-SYNC loop
- **69+ Integration Tests**: Comprehensive pytest suite validates hooks, agents, workflows (test_v2_45_integration.py, test_hooks_registration.py)
- **Security Fixes (v2.45.1)**: Atomic temp file handling (mktemp), path traversal prevention, command injection fix

### v2.44.0 (2026-01-16)

- **Plan Mode Integration**: Orchestrator analysis now feeds INTO Claude Code's native Plan Mode
- **Step 3b: PERSIST**: New step writes `.claude/orchestrator-analysis.md` before EnterPlanMode
- **Global Rule**: `~/.claude/rules/plan-mode-orchestrator.md` instructs Plan Mode to read analysis
- **Auto-Cleanup Hook**: `plan-analysis-cleanup.sh` backs up to `~/.ralph/analysis/` and removes after ExitPlanMode
- **10-Step Workflow**: Expanded from 8 steps to include EVALUATE, PERSIST, and PLAN MODE steps
- **Unified Plan**: ONE plan instead of conflicting orchestrator + Claude Code plans
- **Extension Workaround**: `/compact` skill for manual context save in VSCode/Cursor

### v2.43.0 (2026-01-16)

- **Claude-Mem Integration**: Semantic memory with 3-layer workflow (search → timeline → get_observations)
- **PreToolUse additionalContext**: Session context injection for Task subagents via hook output
- **LSP-Explore Skill**: Token-free code navigation (go-to-definition, find-references, hover)
- **MCP auto:10 Optimization**: Deferred tool loading until 10% context usage
- **Modernized Skills**: YAML allowed-tools, agent field, hooks in skill frontmatter
- **Codex CLI Security**: Replaced --yolo with --full-auto across all Codex invocations
- **Worktree Dashboard**: New `ralph worktree-dashboard` command for worktree visibility

### v2.42.0 (2026-01-13)

- **Two-Stage Review**: `/adversarial` separates Spec Compliance (Stage 1) → Code Quality (Stage 2)
- **Socratic Design**: `/clarify` presents 2-3 design alternatives with trade-offs for architectural decisions
- **3-Fix Rule Enforcement**: Mandatory escalation after 3 failed fix attempts (`/systematic-debugging`)
- **Stop Hook Verification**: Validates completion checklist before session end (TODOs, git, lint, tests)
- **Auto-Save Context (2-Action Rule)**: Auto-saves context every 5 operations to prevent mid-task loss
- **Orchestrator Integration**: All v2.42 features integrated into 8-step workflow

### v2.40.0 (2026-01-13)

- **OpenCode Model Migration**: Automatic conversion from Claude models to OpenCode-compatible alternatives
- **Integration Test Suite**: 26 pytest tests validate skills, hooks, llm-tldr, ultrathink
- **Dual-Sync Architecture**: `ralph sync-to-opencode` synchronizes Claude Code config to OpenCode

### v2.39.0 (2026-01-12)

- **Ultrathink Doctrine**: Added ultrathink guidance across all agents and skills
- **Domain-Specific Steps**: Each agent/skill now defines its workflow steps
- **Version Alignment**: Updated orchestrator and CLAUDE.md to v2.39

### v2.36.0 (2026-01-10)

- **Commands → Skills Unification**: Aligned with Claude Code v2.1.3 merged mental model
- **185 Global Skills**: All commands migrated to `~/.claude/skills/` with Progressive Disclosure
- **Agent Hooks**: 5 priority agents with PreToolUse/PostToolUse/Stop logging hooks
- **PostCompact Recovery**: Automatic context restoration via SessionStart:compact
- **Threshold Update**: Context warning 60%→80%, critical 75%→85% (Claude Code v2.1.0)
- **Zero Configuration**: Multi-Agent Ralph automatically available in ALL projects via global inheritance

### v2.35.0 (2026-01-09)

- **100% Automatic Context Preservation**: SessionStart + PreCompact hooks
- **Global Hooks Inheritance**: Projects inherit from `~/.claude/settings.json`
- **Global Architecture Validator**: `ralph validate-arch` for 48-component validation
- **Token Optimization**: CLAUDE.md slimmed from 45KB to 5KB (89% reduction)

### v2.31.0 (2026-01-07)

- **Smart Execution**: Background tasks by default, explicit quality criteria per agent
- **Auto Discovery**: Explorer/Plan invoked automatically for complex tasks (complexity >= 7)
- **Tool Selection Matrix**: Intelligent routing to ast-grep, Context7, WebSearch, MiniMax MCP
- **9 Agents Updated**: orchestrator, security-auditor, debugger, code-reviewer, test-architect, refactorer, frontend-reviewer, docs-writer, minimax-reviewer
- **New Skill**: auto-intelligence for automatic context exploration and planning

### v2.27.0 (2026-01-04)

---

*"Better to fail predictably than succeed unpredictably"* - The Ralph Wiggum Philosophy
