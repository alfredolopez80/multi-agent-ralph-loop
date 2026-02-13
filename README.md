# Multi-Agent Ralph Loop

Orchestration system for Claude Code with memory-driven planning, multi-agent coordination, and automatic learning.

## Overview

Ralph extends Claude Code with intelligent orchestration capabilities. It classifies tasks, routes to appropriate models, coordinates multiple agents, and maintains persistent memory across sessions.

Key capabilities:
- Task classification and routing
- Parallel memory search across multiple backends
- Multi-agent coordination with swarm mode
- Automatic learning from GitHub repositories
- Quality validation with adversarial review
- Session state management with checkpoints

## Version

Current: v2.84.3

Recent changes:
- Fixed 10 hooks with invalid JSON format
- Eliminated race conditions with atomic file locking
- Added TypeScript compilation caching (80-95% speedup)
- Multilingual support (English/Spanish) for command detection

## Requirements

- Claude Code v2.1.16 or higher
- GLM-4.7 API access (configured in Zai environment)
- Bash 4.0+
- jq 1.6+
- git 2.0+
- curl

Optional:
- GitHub CLI (`gh`) for enhanced API access
- Zai CLI for web search and vision capabilities

## Quick Start

```bash
# Clone repository
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Verify installation
ls -la ~/.ralph/
ralph health --compact

# Run orchestration
/orchestrator "Create a REST API endpoint"

# Complex task with swarm mode
/orchestrator "Implement distributed caching" --launch-swarm --teammate-count 3
```

## Architecture

```
User Request
    |
    v
Claude Code (v2.1.22+)
    |
    v
+-------------------+
| Settings.json     | -- Hook registration
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
| - Model routing (GLM-4.7 primary)         |
| - Swarm mode coordination                 |
| - Quality gates validation                |
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
│   ├── agents/         # 42 agent definitions
│   ├── commands/       # 41 slash commands
│   ├── hooks/          # 83 hook scripts
│   └── skills/         # 84 skill directories
├── docs/               # Architecture and guides
├── scripts/            # Utility scripts
├── tests/              # Test suites
└── .ralph/             # Session data (not in repo)
```

### Agents (42)

| Category | Agents |
|----------|--------|
| Orchestration | orchestrator, debugger, code-reviewer |
| Security | security-auditor, blockchain-security-auditor |
| Quality | test-architect, refactorer, quality-auditor |
| GLM-5 Teammates | glm5-coder, glm5-reviewer, glm5-tester, glm5-orchestrator |
| Specialized | frontend-reviewer, docs-writer, repository-learner |

### Commands (41)

Core commands:
- `/orchestrator` - Full orchestration workflow
- `/loop` - Iterative execution with validation
- `/gates` - Quality gate validation
- `/bug` or `/bugs` - Systematic debugging
- `/security` - Security audit
- `/parallel` - Parallel code review

GLM-5 integration (v2.84.1+):
```bash
/orchestrator "Task" --with-glm5
/loop "Fix errors" --with-glm5
/security src/ --with-glm5
```

### Hooks (83)

Hook events:
- `SessionStart` - Context restoration at startup
- `PreToolUse` - Validation before tool execution
- `PostToolUse` - Quality checks after tool execution
- `UserPromptSubmit` - Command routing and context injection
- `PreCompact` - State save before context compaction
- `Stop` - Session reports

Critical hooks (must be registered):
| Hook | Event | Purpose |
|------|-------|---------|
| `git-safety-guard.py` | PreToolUse (Bash) | Blocks rm -rf, git reset --hard |
| `repo-boundary-guard.sh` | PreToolUse (Bash) | Prevents work outside current repo |
| `learning-gate.sh` | PreToolUse (Task) | Triggers /curator when memory empty |
| `rule-verification.sh` | PostToolUse | Validates learned rules applied |

## Model Support

| Model | Provider | Use Case |
|-------|----------|----------|
| GLM-4.7 | Z.AI | Primary for all tasks |
| GLM-5 | Z.AI | Teammates with thinking mode |
| Codex GPT-5.3 | OpenAI | Security, performance, planning |

GLM-4.7 MCP servers:
- `zai-mcp-server` - Vision tools for screenshots
- `web-search-prime` - Real-time web search
- `web-reader` - Content extraction
- `zread` - Repository knowledge access

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

## Swarm Mode (v2.81.1)

Parallel multi-agent execution for 7 core commands:

| Command | Agents | Speedup |
|---------|--------|---------|
| /orchestrator | 4 | 3x |
| /loop | 4 | 3x |
| /parallel | 7 | 6x |
| /gates | 6 | 3x |

Configuration requirement:
```json
{
  "permissions": {
    "defaultMode": "delegate"
  }
}
```

## Quality Validation

Validation stages:
1. CORRECTNESS - Syntax errors (blocking)
2. QUALITY - Type errors (blocking)
3. SECURITY - semgrep + gitleaks (blocking)
4. CONSISTENCY - Linting (advisory)

3-Fix Rule: Maximum 3 attempts per validation failure before escalation.

## Configuration

Primary settings: `~/.claude-sneakpeek/zai/config/settings.json`

```json
{
  "model": "glm-4.7",
  "defaultMode": "delegate",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Task",
        "hooks": [
          {"command": "/path/to/learning-gate.sh"}
        ]
      }
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
├── quality-parallel/    # Quality gate tests
├── swarm-mode/          # Swarm mode tests
└── unit/                # Unit tests
```

Run tests:
```bash
# Hook validation
./tests/unit/test-hooks-validation.sh

# Swarm mode tests
./tests/swarm-mode/test-swarm-mode-config.sh

# Learning system tests
./tests/learning/run-all-tests.sh
```

Current test status: 100% passing (83/83 hooks validated, 62/62 learning tests)

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

- [claude-sneakpeek](https://github.com/mikekelly/claude-sneakpeek) - Zai variant and swarm mode
- [cc-mirror](https://github.com/numman-ali/cc-mirror) - Documentation patterns
- [Claude Code Docs](https://github.com/ericbuess/claude-code-docs) - Official documentation mirror
