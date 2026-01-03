# Git Worktree Tools Comparison

> **Last Updated**: January 2026
> **Purpose**: Detailed comparison of tools for parallel Claude Code development with git worktrees

## Quick Recommendation

| Use Case | Recommended Tool |
|----------|------------------|
| **Production team** | WorkTrunk |
| **Quick experiments** | claude-wt |
| **Enterprise/Complex** | ccswarm |
| **Custom integration** | DIY /worktree command |
| **No file isolation needed** | Built-in subagents |

---

## Tool #1: WorkTrunk

### Overview

| Attribute | Value |
|-----------|-------|
| **URL** | [worktrunk.dev/claude-code](https://worktrunk.dev/claude-code/) |
| **GitHub** | [max-sixty/worktrunk](https://github.com/max-sixty/worktrunk) |
| **Language** | Rust (99.2%) |
| **License** | MIT |
| **Version** | 0.9.1 (Jan 2026) |
| **Platforms** | macOS, Linux |

### Installation

```bash
# Homebrew (recommended)
brew install max-sixty/worktrunk/wt && wt config shell install

# Cargo
cargo install worktrunk && wt config shell install
```

### Core Commands

| Command | Description |
|---------|-------------|
| `wt switch feat` | Navigate to worktree |
| `wt switch -c feat` | Create new worktree + branch |
| `wt switch -c -x claude feat` | Create + launch Claude |
| `wt remove` | Clean up worktree |
| `wt list` | Show all worktrees with status |
| `wt merge` | Squash + rebase + merge + cleanup |
| `wt config state marker set "🔧"` | Set custom status marker |

### Claude Code Integration

**Status Tracking**:
- 🤖 = Claude actively working
- 💬 = Claude awaiting input

**Statusline Integration**:
```json
// ~/.claude/settings.json
{
  "statusLine": {
    "type": "command",
    "command": "wt list statusline --claude-code"
  }
}
```

**Example Output**:
```
~/w/myproject.feature-auth !🤖 @+42 -8 ↑3
```

### Hook System

```bash
# Create hook
wt config hooks create pre-merge "npm test"
wt config hooks create post-merge "git push"

# Hook execution order
1. pre-merge: Run before merge
2. post-merge: Run after successful merge
```

### Pros & Cons

| Pros | Cons |
|------|------|
| Native Claude status tracking | macOS/Linux only |
| Built-in hook system | Requires shell integration |
| LLM commit messages | Learning curve |
| Active development | Rust compilation if from source |
| Battle-tested | |

---

## Tool #2: claude-wt

### Overview

| Attribute | Value |
|-----------|-------|
| **GitHub** | [jlowin/claude-wt](https://github.com/jlowin/claude-wt) |
| **Language** | Python (100%) |
| **License** | MIT |
| **Version** | 0.2.0 (Jul 2025) |
| **Platforms** | macOS, Linux |

### Installation

```bash
# No installation required (uvx)
uvx claude-wt new "task"

# Global installation
uv tool install claude-wt

# From source
git clone https://github.com/jlowin/claude-wt.git
cd claude-wt && uv install -e .
```

### Core Commands

| Command | Description |
|---------|-------------|
| `uvx claude-wt new "task"` | Create isolated session |
| `uvx claude-wt new "task" --name feat-x` | With custom name |
| `uvx claude-wt new "task" --branch main` | From specific branch |
| `uvx claude-wt resume <id>` | Resume session |
| `uvx claude-wt list` | Show active sessions |
| `uvx claude-wt clean <id>` | Remove session |
| `uvx claude-wt clean --all` | Remove all sessions |

### Session Management

Sessions stored in `.claude-wt/worktrees/` with format:
```
.claude-wt/
└── worktrees/
    ├── claude-wt-20241201-143022/
    ├── claude-wt-20241202-091530/
    └── feat-x/  (custom named)
```

### Pros & Cons

| Pros | Cons |
|------|------|
| Zero-install via uvx | No Claude status tracking |
| Simple mental model | No hook system |
| Python extensibility | Python dependency risks |
| Great for experiments | Less mature |

---

## Tool #3: ccswarm

### Overview

| Attribute | Value |
|-----------|-------|
| **GitHub** | [nwiizo/ccswarm](https://github.com/nwiizo/ccswarm) |
| **Language** | Rust |
| **License** | Open Source |
| **Architecture** | Multi-agent orchestration |

### Key Features

- **Specialized Agents**: Frontend, Backend, DevOps, QA, Search
- **Claude ACP**: WebSocket-based communication (ws://localhost:9100)
- **Task Queue**: Priority-based delegation
- **TUI**: Real-time monitoring interface
- **Observability**: OpenTelemetry + Langfuse

### Installation

```bash
git clone https://github.com/nwiizo/ccswarm.git
cd ccswarm && cargo build --release
./target/release/ccswarm --help
```

### Core Commands

```bash
# System
ccswarm start              # Launch orchestrator
ccswarm tui                # Monitoring interface
ccswarm status --detailed  # Health check

# Tasks
ccswarm task "description" --priority high --type feature
ccswarm delegate task "task" --agent backend

# Templates
ccswarm template list
ccswarm template apply rust-cli --output ./my-cli

# Auto-creation
ccswarm auto-create "TODO app" --output ./todo
```

### Pros & Cons

| Pros | Cons |
|------|------|
| Full orchestration | Complex setup |
| Specialized agents | High learning curve |
| Built-in monitoring | Requires ACP server |
| Enterprise features | Overkill for small teams |

---

## Tool #4: Custom /worktree Command

### Implementation

Based on [motlin.com/blog/claude-code-worktree](https://motlin.com/blog/claude-code-worktree):

```markdown
<!-- .claude/commands/worktree.md -->
# /worktree

Create isolated worktree for parallel development.

## Steps

1. Mark todo item: `- [ ] Task` → `- [>] Task <!-- worktree: id -->`
2. Create worktree: `git worktree add ../project-{id} -b task/{id} HEAD`
3. Copy environment: `cp .envrc ../project-{id}/ && direnv allow`
4. Create focused todo: Write single task to `.llm/todo.md`
5. Launch terminal: Open new tab with `claude /todo`
```

### Integration with /todo and /commit

```bash
# Workflow
/todo           # View and select task
/worktree       # Create isolated environment
/commit         # Commit when done
/compact        # Manage context
```

### Pros & Cons

| Pros | Cons |
|------|------|
| Full customization | Manual maintenance |
| No dependencies | No monitoring |
| Integrates with existing | No status tracking |

---

## Tool #5: Built-in Subagents

### Usage

```python
# Within Claude Code session
Task(
  subagent_type="general-purpose",
  description="Backend implementation",
  prompt="Implement API endpoints for...",
  run_in_background=True
)
```

### Characteristics

| Aspect | Detail |
|--------|--------|
| **Isolation** | Context only (no file isolation) |
| **Best for** | Research, analysis, code review |
| **Not for** | Parallel file editing |
| **Monitoring** | TaskOutput tool |

### When to Use

- Quick parallel research
- Multiple perspectives on same code
- Analysis that doesn't modify files
- Within single session context

---

## Feature Comparison Matrix

| Feature | WorkTrunk | claude-wt | ccswarm | Custom | Subagents |
|---------|:---------:|:---------:|:-------:|:------:|:---------:|
| **Installation** | Homebrew | uvx | Cargo | None | Built-in |
| **File Isolation** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Claude Status** | 🤖💬 | ❌ | ✅ | ❌ | N/A |
| **Hook System** | ✅ | ❌ | ✅ | Manual | N/A |
| **Monitoring** | CLI | CLI | TUI | Manual | Task |
| **Auto Merge** | ✅ | ❌ | ✅ | ❌ | N/A |
| **Agent Types** | External | External | Built-in | External | Internal |
| **Windows** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Learning Curve** | Medium | Low | High | Medium | Low |
| **Maturity** | High | Medium | Medium | N/A | High |
| **Cost** | Free | Free | Free | Free | API |

---

## Performance Characteristics

| Tool | Startup Time | Memory per Session | Concurrent Limit |
|------|--------------|-------------------|------------------|
| WorkTrunk | ~100ms | ~50MB (wt) | 10+ practical |
| claude-wt | ~500ms | ~30MB (Python) | 10+ practical |
| ccswarm | ~2s | ~100MB (orchestrator) | 50+ (designed for) |
| Custom | ~50ms | ~10MB | 10+ practical |
| Subagents | ~0ms | Shared context | 3-5 recommended |

---

## Integration Examples

### WorkTrunk with Multi-Agent Ralph

```bash
# Add to scripts/ralph
ralph_parallel() {
  local tasks=("$@")
  for task in "${tasks[@]}"; do
    local branch="ai/ralph/$(date +%Y%m%d)-${task// /-}"
    wt switch -c -x claude "$branch" &
  done
  wait
  wt list
}

# Usage
ralph_parallel "implement auth" "add tests" "update docs"
```

### claude-wt with Orchestrator

```bash
# In orchestrator agent
spawn_parallel_sessions() {
  uvx claude-wt new "backend: implement API" --name backend &
  uvx claude-wt new "frontend: create UI" --name frontend &
  uvx claude-wt new "tests: write test suite" --name tests &
  wait
  uvx claude-wt list
}
```

### ccswarm with Full Orchestration

```bash
# Initialize project
ccswarm init --name "my-project" --agents frontend,backend,devops,qa

# Delegate tasks
ccswarm delegate task "Implement user auth" --agent backend --priority high
ccswarm delegate task "Create login UI" --agent frontend --priority high
ccswarm delegate task "Write auth tests" --agent qa --priority medium

# Monitor
ccswarm tui
```

---

## Migration Paths

### From Manual Worktrees to WorkTrunk

```bash
# Current manual approach
git worktree add ../project-feat -b feat
cd ../project-feat && claude

# With WorkTrunk
wt switch -c -x claude feat
```

### From claude-wt to WorkTrunk

```bash
# claude-wt
uvx claude-wt new "task" --name feat

# WorkTrunk equivalent
wt switch -c feat
cd ../repo.feat && claude
```

### From Single Session to Parallel

```bash
# Before: Sequential
claude  # Work on task 1, then task 2, then task 3

# After: Parallel with WorkTrunk
wt switch -c -x claude task1
wt switch -c -x claude task2
wt switch -c -x claude task3
wt list  # Monitor all
```

---

## Recommendations by Team Size

| Team Size | Recommended | Rationale |
|-----------|-------------|-----------|
| **Solo** | claude-wt or Custom | Simple, no overhead |
| **2-5** | WorkTrunk | Status tracking, hooks |
| **5-20** | WorkTrunk + scripts | Standardized workflow |
| **20+** | ccswarm | Full orchestration |

---

*Comparison maintained by Multi-Agent Ralph Loop team*
