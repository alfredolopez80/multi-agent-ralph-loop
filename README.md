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

Current: **v2.86.0**

Recent changes:
- **Agent Teams Integration** - TeammateIdle, TaskCompleted, SubagentStart, SubagentStop hooks
- **Custom Subagents** - ralph-coder, ralph-reviewer, ralph-tester, ralph-researcher
- **Session Lifecycle** - PreCompact → SessionStart(compact) → SessionEnd flow
- **Centralized Skills** - 1,856 skills consolidated from multiple sources
- Quality gates for teammates (console.log, debugger, TODO detection)

## Requirements

- Claude Code v2.1.39 or higher (for Agent Teams support)
- GLM-5 API access (configured via Z.AI)
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

# Run setup script (creates symlinks)
./.claude/scripts/centralize-all.sh

# Verify installation
ralph health --compact

# Run orchestration
/orchestrator "Create a REST API endpoint"

# With GLM-5 teammates for faster execution
/orchestrator "Implement feature X" --with-glm5

# Complex task with swarm mode
/orchestrator "Implement distributed caching" --launch-swarm --teammate-count 3
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

### Agent Teams (v2.86.0)

Custom subagents for parallel execution:

| Agent | Role | Tools | Max Turns |
|-------|------|-------|-----------|
| `ralph-coder` | Code implementation | Read, Edit, Write, Bash | 50 |
| `ralph-reviewer` | Code review | Read, Grep, Glob | 25 |
| `ralph-tester` | Testing & QA | Read, Edit, Write, Bash(test) | 30 |
| `ralph-researcher` | Research | Read, Grep, Glob, WebSearch, WebFetch | 20 |

All configured with `model: glm-5` for optimal performance.

```bash
# Spawn teammates
Task(subagent_type="ralph-coder", team_name="my-project")
Task(subagent_type="ralph-reviewer", team_name="my-project")
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

## Session Lifecycle Hooks (v2.86)

| Event | Hook | Purpose |
|-------|------|---------|
| `PreCompact` | pre-compact-handoff.sh | Save state BEFORE compaction |
| `SessionStart(compact)` | post-compact-restore.sh | Restore context AFTER compaction |
| `SessionEnd` | session-end-handoff.sh | Save state when session TERMINATES |

> **Critical**: `PostCompact` event does NOT exist in Claude Code. Use `SessionStart(matcher="compact")` instead.

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

| Model | Provider | Use Case |
|-------|----------|----------|
| GLM-5 | Z.AI | Primary for all tasks + Agent Teams |
| GLM-4.7 | Z.AI | Web search, vision tasks |
| Codex GPT-5.3 | OpenAI | Security, performance, planning |

GLM-5 configuration (in `~/.claude/settings.json`):
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

Current test status: **100% passing** (89 hooks validated, 30+ integration tests)

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
- [claude-sneakpeek](https://github.com/mikekelly/claude-sneakpeek) - Zai variant and swarm mode
- [cc-mirror](https://github.com/numman-ali/cc-mirror) - Documentation patterns
