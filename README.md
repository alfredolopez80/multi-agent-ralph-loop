# 🎭 Multi-Agent Ralph Wiggum v2.17

![Version](https://img.shields.io/badge/version-2.17.0-blue)
![License](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen)](CONTRIBUTING.md)

> "Me fail English? That's unpossible!" - Ralph Wiggum

A sophisticated multi-agent orchestration system for Claude Code that coordinates multiple AI models (Claude, Codex CLI, Gemini CLI, MiniMax) with **automatic planning**, **intensive clarification**, adversarial validation, self-improvement capabilities, and comprehensive quality gates.

## 🌟 What's New in v2.17

- **Security Hardening**: All user inputs validated and shell-escaped before execution
- **Enhanced validate_path()**: Blocks control characters, path traversal attacks, and shell metacharacters
- **New validate_text_input()**: Validates free-form text inputs (tasks, queries) with length limits
- **Safe JSON Construction**: Uses `jq` for all JSON building to prevent injection attacks
- **escape_for_shell()**: Now actively applied to all user inputs passed to external commands

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
│  0. AUTO-PLAN  → EnterPlanMode (automatic)                     │
│  1. CLARIFY    → AskUserQuestion (MUST_HAVE/NICE_TO_HAVE)      │
│  2. CLASSIFY   → task-classifier (complexity 1-10)             │
│  3. PLAN       → Write detailed plan, get approval             │
│  4. DELEGATE   → Route to optimal model                        │
│  5. EXECUTE    → Parallel subagents                            │
│  6. VALIDATE   → Quality gates + Adversarial validation        │
│  7. RETROSPECT → Self-improvement proposals                    │
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
unzip multi-agent-ralph-v2.15.zip
cd ralph-v2.15
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
ralph-v2.15/
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
│   │   └── quality-gates.sh        # Stop hook (9 languages)
│   └── skills/
│       ├── ask-questions-if-underspecified/
│       ├── task-classifier/
│       └── retrospective/
├── .codex/                         # Codex CLI configuration
│   ├── instructions.md
│   └── skills/
│       ├── security-review.md
│       ├── bug-hunter.md
│       ├── test-generation.md
│       └── ask-questions-if-underspecified.md  # NEW
├── .gemini/                        # Gemini CLI configuration
│   └── GEMINI.md
├── scripts/
│   ├── ralph                       # Main CLI
│   └── mmc                         # MiniMax wrapper
├── config/
│   └── models.json
├── CLAUDE.md                       # Quick reference
├── README.md
└── install.sh
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

## 📋 All Commands

### CLI Commands

```bash
# Orchestration
ralph orch "task"           # Full 6-step orchestration
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
