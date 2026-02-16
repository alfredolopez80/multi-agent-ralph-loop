# Multi-Agent Ralph Loop

Orchestration system for Claude Code with memory-driven planning, multi-agent coordination, Agent Teams integration, and automatic learning.

## Overview

Ralph extends Claude Code with intelligent orchestration capabilities. It classifies tasks, routes to appropriate models, coordinates multiple agents, and maintains persistent memory across sessions.

Key capabilities:
- **Agent Teams Integration** - Multiple Claude Code instances working in parallel
- Task classification and routing
- Parallel memory search across multiple backends
- Multi-agent coordination with swarm mode
- Automatic learning from GitHub repositories
- Quality validation with adversarial review
- Session state management with checkpoints

## Version

Current: **v2.93.0**

### What's New in v2.93.0

- **Memory System Optimization** — Smart memory search re-enabled + cleanup policies implemented
  - Re-enabled `smart-memory-search.sh` hook (700+ lines of parallel memory search)
  - Implemented episodic memory cleanup: 30-day TTL (previously: NO cleanup)
  - Removed redundant storage: memvid.json (175KB) and semantic.json (62KB)
  - Streamlined to primary memory storage: claude-mem + episodic + handoffs + ledgers
  - Removed memvid integration from `ralph` CLI (tool definition + validation)

### What's New in v2.92.0

- **Removed Obsolete Dependencies** — Cleaned up llm-tldr and claude-sneakpeek references
  - Removed `llm-tldr` integration (hook, tests, CLI command)
  - Removed `claude-sneakpeek` historical references
  - Updated context tree to use ast-grep backend instead of llm-tldr
  - Simplified architecture without deprecated tooling

### What's New in v2.90.2

- **MCP Servers Integration** — Structural code search and Zai vision capabilities
  - **ast-grep MCP**: AST-based code search (13 MCP servers total)
    - Tool selection guide: ast-grep vs Grep vs Glob based on benchmark results
    - 4 cases where only ast-grep works: containment, blocks, negation, scope-aware
    - Complete rule reference (atomic, relational, composite, metavariables)
  - **Zai MCP Servers**: 4 servers with 13 tools
    - `zai-mcp-server`: 8 vision tools (ui_to_artifact, extract_text, diagnose_error, etc.)
    - `web-search-prime`: Web search with rich results
    - `web-reader`: Full webpage content extraction
    - `zread`: GitHub repository documentation (search_doc, read_file, get_repo_structure)

### Previous Releases

- **v2.89.2** - Hooks alignment with official Claude Code hooks guide, 15 additional security fixes
- **v2.89.1** - 14 security vulnerability fixes (command chaining, SHA-256 checksums, deny list expansion, settings self-protection, file locking, SEC-111 compliance), 37 security tests, threat model documentation
- **v2.88.2** - LSP Integration, Batch Task Execution, 950+ BATS tests passing
- **v2.88.0** - Agent Teams, Multi-Agent Scenarios, `/task-batch` and `/create-task-batch` skills
- **v2.86.0** - Session Lifecycle Hooks, Agent Teams hooks
- **v2.84.1** - GLM-5 integration, model-agnostic architecture

## Requirements

- Claude Code v2.1.42 or higher (for Agent Teams + SessionEnd support)
- GLM-5 API access (configured via Z.AI)
- Bash 4.0+
- jq 1.6+
- git 2.0+
- curl

Optional:
- GitHub CLI (`gh`) for enhanced API access
- Zai CLI (`@z_ai/coding-helper`) for MCP server management
- `uv` package manager for ast-grep MCP server
- `ast-grep` binary for structural code search

## Quick Start

```bash
# Clone repository
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Run setup script (creates symlinks)
./.claude/scripts/centralize-all.sh

# Verify installation
ralph health --compact

# Run orchestration (uses configured default model)
/orchestrator "Create a REST API endpoint"

# Complex task with swarm mode
/orchestrator "Implement distributed caching" --launch-swarm --teammate-count 3
```

## Installation Guide

### Prerequisites

Ensure you have the following installed:

| Tool | Version | Purpose |
|------|---------|---------|
| **Claude Code** | v2.1.42+ | Main CLI tool |
| **Bash** | 3.2+ | Shell scripts |
| **jq** | 1.6+ | JSON processing |
| **git** | 2.0+ | Version control |
| **curl** | Any | HTTP requests |
| **python3** | 3.8+ | Python tooling |

### Step-by-Step Installation

#### 1. Clone Repository

```bash
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop
```

#### 2. Run Centralization Script

This script creates symlinks from your global `~/.claude/` directory to the repository:

```bash
./.claude/scripts/centralize-all.sh
```

**What it does:**
- Creates backup of existing configuration
- Symlinks skills from repository to `~/.claude/skills/`
- Symlinks agents from repository to `~/.claude/agents/`
- Consolidates plugins from multiple sources

#### 3. Install Language Servers (LSP)

LSP provides intelligent code navigation for skills like `/gates`, `/security`, and `/code-reviewer`:

```bash
# Install essential language servers (TypeScript, Python, C/C++, Swift)
./scripts/install-language-servers.sh --essential

# Or install all servers including optional ones
./scripts/install-language-servers.sh --all

# Check what's installed
./scripts/install-language-servers.sh --check
```

**Essential Language Servers:**

| Server | Language | Install Command |
|--------|----------|-----------------|
| `typescript-language-server` | TypeScript/JavaScript | `npm install -g typescript-language-server typescript` |
| `pyright` | Python | `npm install -g pyright` |
| `clangd` | C/C++ | `brew install llvm` (macOS) or system package |
| `sourcekit-lsp` | Swift | Included with Xcode (macOS) |

**Optional Language Servers:**
- `bash-language-server` - Shell scripts
- `dockerfile-language-server` - Dockerfiles
- `yaml-language-server` - YAML files
- `json-language-server` - JSON files
- `html-language-server` - HTML
- `css-language-server` - CSS

#### 4. Install Security Tools (Optional but Recommended)

```bash
./scripts/install-security-tools.sh
```

This installs:
- `semgrep` - Static analysis for security
- `gitleaks` - Secret detection

#### 5. Validate Installation

Run the comprehensive validation script:

```bash
# Full validation
./scripts/validate-installation.sh

# Quick check (critical only)
./scripts/validate-installation.sh --quick

# Verbose output
./scripts/validate-installation.sh --verbose

# JSON output for CI/CD
./scripts/validate-installation.sh --format json
```

**Validation checks:**
1. System Requirements - Required tools and versions
2. Shell Environment - PATH, aliases, environment
3. Directory Structure - Required directories and permissions
4. Hooks Registration - All hooks registered and executable
5. Skills Registration - All skills properly installed
6. Agents Registration - All agents properly defined
7. LSP Servers - Language servers availability

#### 6. Verify System Health

```bash
ralph health --compact
```

Expected output:
```
✓ System healthy
✓ Memory system operational
✓ LSP servers available: typescript-language-server, pyright, clangd
✓ Hooks registered: 89
✓ Skills available: 30+
✓ Agents available: 46
```

### Running Tests

The project includes comprehensive test suites to verify everything works:

```bash
# Run all installer tests
bats tests/installer/

# Run specific test suites
bats tests/installer/test-complete-installation.bats   # 55 tests
bats tests/installer/test-lsp-usage-validation.bats    # 36 tests

# Run all integration tests
./tests/test_all_integration.sh
```

### Troubleshooting

#### LSP Servers Not Found

If language servers are not detected:

```bash
# Check if servers are in PATH
which typescript-language-server
which pyright
which clangd

# Verify npm global packages
npm list -g --depth=0 | grep -E 'typescript-language-server|pyright'

# Reinstall language servers
./scripts/install-language-servers.sh --essential --force
```

#### Hooks Not Executing

If hooks are not running:

```bash
# Validate hook registration
./scripts/validate-all-hooks.sh

# Check hook permissions
chmod +x .claude/hooks/*.sh
chmod +x .claude/hooks/*.py
```

#### Skills Not Available

If skills are not showing up:

```bash
# Re-run centralization
./.claude/scripts/centralize-all.sh

# Verify symlinks
ls -la ~/.claude/skills/ | head -20
```

#### Agent Teams Not Working

If Agent Teams features aren't working:

```bash
# Check Claude Code version
claude --version  # Should be v2.1.39+

# Verify Agent Teams is enabled
grep -A5 '"env"' ~/.claude/settings.json | grep AGENT_TEAMS
```

## Architecture

```
User Request
    |
    v
Claude Code (v2.1.39+)
    |
    v
+-------------------+
| ~/.claude/        |
| settings.json     | -- Hook registration & Agent Teams config
+-------------------+
    |
    v
+-------------------+     +------------------+
| Memory Systems    |     | Learning System  |
| - claude-mem MCP  |     | - Repo curation  |
| - Local JSON      |     | - Pattern extract|
| - Ledgers         |     | - Rule validation|
+-------------------+     +------------------+
    |                           |
    v                           v
+-------------------------------------------+
|            Orchestration Layer            |
| - Task classification (1-10 complexity)   |
| - Model routing (GLM-5 primary)           |
| - Agent Teams coordination                |
| - Quality gates validation                |
+-------------------------------------------+
    |
    v
+-------------------------------------------+
|            Agent Teams (v2.86)            |
| - ralph-coder (implementation)            |
| - ralph-reviewer (code review)            |
| - ralph-tester (testing & QA)             |
| - ralph-researcher (research)             |
+-------------------------------------------+
    |
    v
Implementation / Analysis / Review
```

## Components

### Directory Structure

```
multi-agent-ralph-loop/
├── .claude/
│   ├── agents/         # 46 agent definitions (4 ralph-* + 42 specialized)
│   ├── commands/       # 41 slash commands
│   ├── hooks/          # 89 hook scripts
│   ├── skills/         # Ralph-specific skills
│   └── scripts/        # Utility scripts
├── docs/               # Architecture and guides
│   └── agent-teams/    # Agent Teams documentation
├── scripts/            # CLI utilities
├── tests/              # Test suites
│   ├── session-lifecycle/  # Session lifecycle tests
│   └── agent-teams/        # Agent Teams tests
└── .ralph/             # Session data (not in repo)
```

### Agent Teams (v2.88.0)

Custom subagents for parallel execution:

| Agent | Role | Tools | Max Turns |
|-------|------|-------|-----------|
| `ralph-coder` | Code implementation | Read, Edit, Write, Bash | 50 |
| `ralph-reviewer` | Code review | Read, Grep, Glob | 25 |
| `ralph-tester` | Testing & QA | Read, Edit, Write, Bash(test) | 30 |
| `ralph-researcher` | Research | Read, Grep, Glob, WebSearch, WebFetch | 20 |

All subagents use the configured default model from `~/.claude/settings.json`.

**Model Configuration** (in `~/.claude/settings.json`):
```json
{
  "env": {
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-5",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

The system is **model-agnostic** - change the model in settings and all skills/agents automatically use it.

```bash
# Spawn teammates (uses configured default model)
Task(subagent_type="ralph-coder", team_name="my-project")
Task(subagent_type="ralph-reviewer", team_name="my-project")
```

### Multi-Agent Execution Scenarios (v2.88.0)

The Ralph system supports three distinct execution scenarios for multi-agent coordination. Each skill is configured with its optimal scenario based on task requirements.

#### Scenario Overview

| Scenario | Description | Best For |
|----------|-------------|----------|
| **A: Pure Agent Teams** | Native Claude Code teams with built-in coordination | Simple coordination, low specialization |
| **B: Custom Subagents** | Direct spawn of ralph-* agents without team overhead | Specialized tasks, independent execution |
| **C: Integrated** | TeamCreate + ralph-* subagents + quality hooks | Complex workflows, production-grade |

#### Scenario A: Pure Agent Teams

Uses native Claude Code team coordination with `TeamCreate`, `TaskCreate`, `TaskUpdate`, and `SendMessage` tools. Best for tasks requiring simple coordination without specialized agent behavior.

**Characteristics**:
- Native Claude Code integration
- Automatic task coordination via shared task list
- Built-in quality gates via hooks
- No custom agent specialization

**Skills using Scenario A**:
- `clarify` - Sequential question flow
- `retrospective` - Single-threaded analysis
- `glm5-parallel` - Same-type parallel execution

#### Scenario B: Pure Custom Subagents

Direct spawn of specialized `ralph-*` agents via the `Task` tool. Best for independent specialized tasks where coordination overhead is unnecessary.

**Characteristics**:
- Full customization of agent behavior
- Tool restrictions per agent type
- Simpler setup without team overhead
- Manual coordination when needed

**Skills using Scenario B**:
- `bugs` - Bug scanning (independent)
- `code-reviewer` - Code review (single-purpose)

#### Scenario C: Integrated (Recommended for Complex Tasks)

Combines `TeamCreate` coordination with `ralph-*` specialized subagents and quality validation hooks (`TeammateIdle`, `TaskCompleted`). This is the most powerful scenario.

**Characteristics**:
- Native task coordination from Agent Teams
- Custom agent specialization from ralph-* subagents
- Quality gates via hooks for VERIFIED_DONE guarantee
- Tool restrictions per agent type

**Skills using Scenario C**:
- `orchestrator` - Multi-phase workflow coordination
- `parallel` - Parallel execution with results aggregation
- `loop` - Iterative execution with quality validation
- `security` - Security analysis with specialized patterns
- `gates` - Quality validation (meta-validation)
- `quality-gates-parallel` - Parallel quality checks
- `adversarial` - Multi-agent attack coordination

#### Implementation Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MULTI-AGENT SCENARIO DECISION TREE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Does the task require tight coordination between agents?                   │
│                    │                                                         │
│         ┌──────────┴──────────┐                                              │
│         ▼                     ▼                                              │
│       YES                    NO ──► SCENARIO B (Custom Subagents)            │
│         │                                                                     │
│   Does it need specialized agents (coder, tester, reviewer)?                 │
│         │                                                                     │
│    ┌────┴────┐                                                               │
│    ▼         ▼                                                               │
│   YES       NO ──► SCENARIO A (Pure Agent Teams)                             │
│    │                                                                          │
│    ▼                                                                          │
│ SCENARIO C (Integrated)                                                       │
│ - TeamCreate for coordination                                                 │
│ - ralph-* for specialization                                                  │
│ - Hooks for quality gates                                                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Agents (46)

| Category | Agents |
|----------|--------|
| **Agent Teams** | ralph-coder, ralph-reviewer, ralph-tester, ralph-researcher |
| Orchestration | orchestrator, debugger, code-reviewer |
| Security | security-auditor, blockchain-security-auditor |
| Quality | test-architect, refactorer, quality-auditor |
| GLM-5 Teammates | glm5-coder, glm5-reviewer, glm5-tester, glm5-orchestrator |
| Specialized | frontend-reviewer, docs-writer, repository-learner |

### Commands (41)

Core commands:
- `/orchestrator` - Full orchestration workflow
- `/loop` - Iterative execution with validation
- `/task-batch` - Autonomous batch task execution (v2.88)
- `/create-task-batch` - Interactive PRD/task list creator (v2.88)
- `/gates` - Quality gate validation
- `/bug` or `/bugs` - Systematic debugging
- `/security` - Security audit
- `/parallel` - Parallel code review

Model-agnostic (v2.88+):
```bash
# All commands use the configured default model automatically
/orchestrator "Task"
/loop "Fix errors"
/security src/

# For specific GLM-5 evaluations, use dedicated skills
/glm5 "Task"           # GLM-5 specific evaluation
/glm5-parallel "Task"  # GLM-5 parallel execution
```

## Session Lifecycle Hooks (v2.86)

| Event | Hook | Purpose |
|-------|------|---------|
| `PreCompact` | pre-compact-handoff.sh | Save state BEFORE compaction |
| `SessionStart(compact)` | post-compact-restore.sh | Restore context AFTER compaction |
| `SessionEnd` | session-end-handoff.sh | Save state when session terminates |
| `Stop` | summarize, reports | Session reports and cleanup |

> **Note**: `PostCompact` does not exist in Claude Code. Use `SessionStart(matcher="compact")` instead. `SessionEnd` and `Stop` are separate events — use `SessionEnd` for state persistence, `Stop` for reports.

## Agent Teams Hooks (v2.86)

| Event | Purpose | Exit 2 Behavior |
|-------|---------|-----------------|
| `TeammateIdle` | Quality gate when teammate goes idle | Keep working + feedback |
| `TaskCompleted` | Quality gate before task completion | Prevent completion + feedback |
| `SubagentStart` | Load Ralph context into subagents | - |
| `SubagentStop` | Quality gates when subagent stops | - |

### Hooks (89)

Hook events:
- `SessionStart` - Context restoration at startup
- `PreToolUse` - Validation before tool execution
- `PostToolUse` - Quality checks after tool execution
- `UserPromptSubmit` - Command routing and context injection
- `PreCompact` - State save before context compaction
- `TeammateIdle` - Quality gates for Agent Teams
- `TaskCompleted` - Task completion validation
- `SubagentStart/Stop` - Subagent lifecycle
- `Stop` - Session reports

Critical hooks (must be registered):
| Hook | Event | Purpose |
|------|-------|---------|
| `git-safety-guard.py` | PreToolUse (Bash) | Blocks rm -rf, git reset --hard |
| `repo-boundary-guard.sh` | PreToolUse (Bash) | Prevents work outside current repo |
| `learning-gate.sh` | PreToolUse (Task) | Triggers /curator when memory empty |
| `teammate-idle-quality-gate.sh` | TeammateIdle | Quality checks before idle |
| `task-completed-quality-gate.sh` | TaskCompleted | Validation before completion |

## Model Support

**Model-Agnostic Architecture (v2.88)**: The system works with any model configured in Claude Code settings.

| Model | Provider | Configuration |
|-------|----------|---------------|
| GLM-5 | Z.AI | `ANTHROPIC_DEFAULT_*_MODEL: "glm-5"` |
| Claude Sonnet/Opus | Anthropic | `ANTHROPIC_DEFAULT_*_MODEL: "claude-sonnet-4"` |
| Minimax M2.5 | Minimax | `ANTHROPIC_DEFAULT_*_MODEL: "minimax-m2.5"` |

To change the default model, update `~/.claude/settings.json`:
```json
{
  "env": {
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "your-model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "your-model",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "your-model",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

All skills, agents, and subagents automatically use the configured model. No flags required.

## Memory System

Three-tier architecture:

| Tier | Type | Storage | Purpose |
|------|------|---------|---------|
| Semantic | Persistent | `~/.ralph/memory/semantic.json` | Facts, preferences |
| Episodic | Session | `~/.ralph/episodes/` | Experiences (30-day TTL) |
| Procedural | Learned | `~/.ralph/procedural/rules.json` | Patterns, best practices |

Memory commands:
```bash
ralph memory-search "query"
ralph agent-memory init <agent>
ralph agent-memory write <agent> semantic "fact"
ralph health
```

## Learning System (v2.81.2)

Automatic learning pipeline:

1. **Discovery** - GitHub API search for quality repositories
2. **Scoring** - Quality metrics + context relevance
3. **Ranking** - Top N with max-per-org limits
4. **Learning** - Pattern extraction from approved repos

Commands:
```bash
/curator full --type backend --lang typescript
/curator discovery --query "microservice" --max-results 200
/curator learn --repo nestjs/nest
/curator learn --all
```

Current statistics:
- Total rules: 1003+
- Auto-learning: Enabled
- System status: Production

## Quality Validation

Validation stages:
1. CORRECTNESS - Syntax errors (blocking)
2. QUALITY - Type errors (blocking)
3. SECURITY - semgrep + gitleaks (blocking)
4. CONSISTENCY - Linting (advisory)

3-Fix Rule: Maximum 3 attempts per validation failure before escalation.

### Quality Gates for Teammates

| Gate | Type | Detection |
|------|------|-----------|
| Gate 1 | Blocking | `console.log|debug` |
| Gate 2 | Blocking | `debugger|breakpoint` |
| Gate 3 | Blocking | `TODO:|FIXME:|XXX:|HACK:` |
| Gate 4 | Blocking | Placeholder code |
| Gate 5 | Advisory | Empty function bodies |

## Configuration

**Primary settings**: `~/.claude/settings.json`

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "hooks": {
    "TeammateIdle": [{"matcher": "*", "hooks": [...]}],
    "TaskCompleted": [{"matcher": "*", "hooks": [...]}],
    "SubagentStart": [{"matcher": "ralph-*", "hooks": [...]}],
    "SubagentStop": [
      {"matcher": "ralph-*", "hooks": [...]},
      {"matcher": "glm5-*", "hooks": [...]}
    ]
  }
}
```

Memory configuration: `~/.ralph/config/memory-config.json`

Learning configuration: `~/.ralph/curator/config.json`

## Testing

Test structure:
```
tests/
├── session-lifecycle/    # Session lifecycle tests
│   └── test_session_lifecycle_hooks.sh
├── agent-teams/          # Agent Teams tests
│   └── test_agent_teams_integration.sh
├── skills/               # Skill tests (v2.88)
│   ├── test-task-batch.sh
│   ├── test-create-task-batch.sh
│   └── test-batch-skills-integration.sh
├── quality-parallel/     # Quality gate tests
├── swarm-mode/           # Swarm mode tests
└── unit/                 # Unit tests
```

Run tests:
```bash
# All integration tests
./tests/test_all_integration.sh

# Session lifecycle tests
./tests/session-lifecycle/test_session_lifecycle_hooks.sh

# Agent Teams tests
./tests/agent-teams/test_agent_teams_integration.sh

# Hook validation
./tests/unit/test-hooks-validation.sh
```

Current test status: **100% passing** (102 hooks validated, 37 security tests, 950+ BATS tests)

## CLI Reference

```bash
# Orchestration
ralph orch "task"              # Full orchestration
ralph loop "task"              # Iterative execution
ralph gates                    # Quality gates

# Context
ralph context dev              # Development mode
ralph context review           # Review mode
ralph context debug            # Debug mode

# Memory
ralph memory-search "query"    # Search memory
ralph health                   # System health check

# Checkpoints
ralph checkpoint save "name"   # Save state
ralph checkpoint restore "name" # Restore state
ralph checkpoint list          # List checkpoints

# Learning
ralph curator full --type backend --lang typescript
ralph curator learn --repo owner/repo

# Events
ralph events status            # Event bus status
ralph trace show 30            # Recent events
```

## Documentation

| Topic | Location |
|-------|----------|
| Architecture | `docs/architecture/` |
| Agent Teams | `docs/agent-teams/` |
| Batch Execution | `docs/batch-execution/BATCH_SKILLS_v2.88.0.md` |
| Swarm Mode | `docs/swarm-mode/` |
| Learning System | `docs/guides/LEARNING_SYSTEM_INTEGRATION_GUIDE.md` |
| Hooks Reference | `docs/hooks/` |
| Security | `docs/security/` |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following existing patterns
4. Run tests: `./tests/run-all.sh`
5. Submit pull request

Code standards:
- All code in English
- Documentation in English
- Conventional commits format
- Tests required for new features

## License

MIT License - see LICENSE file for details.

## References

- [Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Subagents Docs](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [cc-mirror](https://github.com/numman-ali/cc-mirror) - Documentation patterns
