# Git Worktree + Claude Code: Parallel Development Research

> **Research Date**: January 2026
> **Version**: v1.0
> **Status**: Complete Analysis

## Executive Summary

This document analyzes options for integrating git worktree-based parallel development with Claude Code, enabling multiple AI agents to work on different features/tasks simultaneously while maintaining isolation and version control.

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Available Tools Comparison](#available-tools-comparison)
3. [Architecture Options](#architecture-options)
4. [Security Analysis](#security-analysis)
5. [Implementation Recommendations](#implementation-recommendations)
6. [Integration with Multi-Agent Ralph](#integration-with-multi-agent-ralph)

---

## Problem Statement

### Current Limitations
- Single Claude Code session = single context, single branch
- Context switching destroys accumulated understanding
- Sequential development blocks parallel progress
- No isolation between concurrent feature work

### Desired Capabilities
- Run 5-10+ Claude instances in parallel
- Each instance works on isolated branch/worktree
- Easy rollback via branch deletion
- PR-based integration workflow
- Unified orchestration and monitoring

---

## Available Tools Comparison

### 1. WorkTrunk (Recommended for Production)

| Attribute | Details |
|-----------|---------|
| **Repository** | [github.com/max-sixty/worktrunk](https://github.com/max-sixty/worktrunk) |
| **Language** | Rust (99.2%) |
| **Installation** | `brew install max-sixty/worktrunk/wt` or `cargo install worktrunk` |
| **License** | MIT |
| **Version** | 0.9.1 (Jan 2026) |

**Key Features:**
```bash
# Core commands
wt switch feat           # Navigate to worktree
wt switch -c -x claude feat  # Create + launch Claude
wt remove               # Clean up worktree
wt list                 # Status with Claude activity indicators
wt merge                # Squash + rebase + merge + cleanup

# Claude integration
wt list statusline --claude-code  # For Claude statusline
```

**Advantages:**
- Native Claude Code integration with status tracking (🤖 working, 💬 waiting)
- Hook system for automation (create, pre-merge, post-merge)
- LLM commit message generation
- Battle-tested (daily driver since Dec 2025)
- Rust performance and safety

**Disadvantages:**
- macOS/Linux only (no Windows)
- Requires shell integration setup
- Learning curve for advanced features

---

### 2. claude-wt (Simpler Alternative)

| Attribute | Details |
|-----------|---------|
| **Repository** | [github.com/jlowin/claude-wt](https://github.com/jlowin/claude-wt) |
| **Language** | Python (100%) |
| **Installation** | `uvx claude-wt new "task"` (no install required) |
| **License** | MIT |
| **Version** | 0.2.0 (Jul 2025) |

**Key Features:**
```bash
# Quick start (no installation)
uvx claude-wt new "implement auth"

# Session management
uvx claude-wt new "task" --name feature-x --branch main
uvx claude-wt resume 20241201-143022
uvx claude-wt list
uvx claude-wt clean --all
```

**Advantages:**
- Zero-install usage via `uvx`
- Simple mental model
- Python ecosystem (easier to extend)
- Great for quick experiments

**Disadvantages:**
- Less mature than WorkTrunk
- No hook system
- No Claude status integration
- Python dependency chain risks (supply chain)

---

### 3. ccswarm (Enterprise/Complex)

| Attribute | Details |
|-----------|---------|
| **Repository** | [github.com/nwiizo/ccswarm](https://github.com/nwiizo/ccswarm) |
| **Language** | Rust |
| **Architecture** | Multi-agent orchestration with ACP |
| **License** | Open Source |

**Key Features:**
- Specialized agent pool (Frontend, Backend, DevOps, QA, Search)
- Claude ACP (Agent Client Protocol) via WebSocket
- Task delegation with priority/category
- Real-time TUI monitoring
- Git worktree isolation built-in
- OpenTelemetry observability

**Best For:**
- Large teams
- Complex multi-agent workflows
- Enterprise deployments

---

### 4. Custom /worktree Command (DIY)

From [motlin.com](https://motlin.com/blog/claude-code-worktree):

```bash
# Add to .claude/commands/worktree.md
# Automates:
# 1. Mark todo item as in-progress
# 2. Create worktree + branch
# 3. Copy .envrc, run direnv
# 4. Create focused .llm/todo.md
# 5. Launch terminal + Claude
```

**Advantages:**
- Full customization
- No external dependencies
- Integrates with existing /todo workflow

**Disadvantages:**
- Requires manual maintenance
- No built-in monitoring

---

### 5. Native Claude Code (Proposed)

[GitHub Issue #4963](https://github.com/anthropics/claude-code/issues/4963) proposes:

```bash
/fork "task"              # Create worktree + headless agent
/tasks list               # Monitor all background agents
/tasks view <id>          # See agent transcript
/tasks merge <id>         # Create PR + cleanup
```

**Status:** Open feature request (Aug 2025), not yet implemented.

---

## Architecture Options

### Option A: Multiple Terminal Sessions

```
┌─────────────────────────────────────────────────────────────┐
│                    Terminal Multiplexer (tmux)               │
├──────────────┬──────────────┬──────────────┬────────────────┤
│   Pane 1     │    Pane 2    │    Pane 3    │     Pane 4     │
│  ../wt-auth  │  ../wt-api   │  ../wt-ui    │   ../wt-docs   │
│   claude     │   claude     │   claude     │    claude      │
│  (feature-a) │  (feature-b) │  (feature-c) │  (feature-d)   │
└──────────────┴──────────────┴──────────────┴────────────────┘
```

**Pros:** Simple, no extra tooling
**Cons:** Manual management, no unified view

---

### Option B: WorkTrunk Orchestration

```
┌────────────────────────────────────────────────────────────┐
│                     WorkTrunk (wt)                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ wt list                                              │   │
│  │ ──────────────────────────────────────────────────── │   │
│  │ Branch        Status  HEAD±  main↕  Path            │   │
│  │ feature-auth   🤖     +12    ↑3     ../repo.auth    │   │
│  │ feature-api    💬     +5     ↑1     ../repo.api     │   │
│  │ feature-ui     🤖     +8     ↑2     ../repo.ui      │   │
│  │ bugfix-123     ✓      +2     ↑1     ../repo.fix     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Hooks: pre-merge → lint + test                            │
│         post-merge → cleanup                                │
└────────────────────────────────────────────────────────────┘
```

**Pros:** Status visibility, hooks, merge workflow
**Cons:** Requires setup, learning curve

---

### Option C: Task Queue Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Orchestrator (Meta-Agent)                 │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Redis Task Queue                          │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      │ │
│  │  │ Task 1  │ │ Task 2  │ │ Task 3  │ │ Task 4  │      │ │
│  │  │frontend │ │backend  │ │ tests   │ │  docs   │      │ │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘      │ │
│  └───────┼──────────┼──────────┼──────────┼──────────────┘ │
│          │          │          │          │                 │
│          ▼          ▼          ▼          ▼                 │
│  ┌───────────┐┌───────────┐┌───────────┐┌───────────┐      │
│  │ Claude #1 ││ Claude #2 ││ Claude #3 ││ Claude #4 │      │
│  │ wt-front  ││ wt-back   ││ wt-test   ││ wt-docs   │      │
│  │ Container ││ Container ││ Container ││ Container │      │
│  └───────────┘└───────────┘└───────────┘└───────────┘      │
│                                                              │
│  File Locking: Redis-based exclusive locks (300s timeout)   │
│  Monitoring: Vue.js dashboard with real-time status         │
└─────────────────────────────────────────────────────────────┘
```

**Pros:** Scalable, conflict resolution, monitoring
**Cons:** Complex setup, infrastructure costs (~$70/day)

---

### Option D: Subagent Pattern (Within Session)

```
┌─────────────────────────────────────────────────────────────┐
│              Main Claude Session (Orchestrator)              │
│                                                              │
│  Task: "Implement payment integration"                       │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Parallel Subagents (Task tool with run_in_background) │   │
│  │                                                        │   │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐        │   │
│  │  │ Backend    │ │ Frontend   │ │ Tests      │        │   │
│  │  │ subagent   │ │ subagent   │ │ subagent   │        │   │
│  │  └────────────┘ └────────────┘ └────────────┘        │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  Note: Same context, no worktree isolation                   │
│        Best for research/analysis, not parallel file edits   │
└─────────────────────────────────────────────────────────────┘
```

**Pros:** No setup, within single session
**Cons:** No file isolation, context sharing issues

---

## Comparison Matrix

| Feature | WorkTrunk | claude-wt | ccswarm | Custom /wt | Subagents |
|---------|-----------|-----------|---------|------------|-----------|
| **Installation** | Homebrew/Cargo | uvx (none) | Cargo | Manual | Built-in |
| **Learning Curve** | Medium | Low | High | Medium | Low |
| **Claude Status** | ✅ 🤖💬 | ❌ | ✅ | ❌ | N/A |
| **Hook System** | ✅ | ❌ | ✅ | Manual | N/A |
| **File Isolation** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Monitoring** | CLI list | CLI list | TUI | Manual | TaskOutput |
| **Merge Workflow** | ✅ auto | Manual | ✅ auto | Manual | N/A |
| **Multi-Agent** | External | External | Built-in | External | Internal |
| **Windows** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Security** | Medium | Lower | Higher | Depends | Highest |
| **Cost** | Free | Free | Free | Free | API only |

---

## Security Analysis

### Critical Findings (from Codex GPT-5 Analysis)

#### CRITICAL: Shared .git Hooks
- Hooks are shared across worktrees by default
- Malicious hooks can exfiltrate code, run commands

**Mitigation:**
```bash
# Enable per-worktree config
git config extensions.worktreeConfig true

# Disable hooks per worktree
mkdir -p .git-hooks-empty && chmod 500 .git-hooks-empty
git config --worktree core.hooksPath "$PWD/.git-hooks-empty"
```

#### HIGH: Credential Exposure
- Credential helpers accessible across worktrees
- SSH agent forwarding risks

**Mitigation:**
```bash
# Disable credentials per worktree
git config --worktree credential.helper ""

# Disable push capability
git remote set-url --push origin DISABLED
```

#### HIGH: Command Injection
- Branch names in shell commands without escaping
- Tool-specific injection vectors

**Mitigation:**
- Always use `--` separator
- Validate branch names (no `-` prefix, no special chars)
- Use arrays, not string interpolation

### Severity Summary

| Severity | Count | Key Issues |
|----------|-------|------------|
| **CRITICAL** | 2 | Shared hooks, shell hook injection |
| **HIGH** | 5 | Credentials, command injection, Python deps |
| **MEDIUM** | 2 | Branch contamination, argument injection |

### Recommended Security Defaults

```bash
# Per-worktree hardening script
secure_worktree() {
  local wt_path="$1"
  cd "$wt_path"

  # Disable hooks
  mkdir -p .git-hooks-empty && chmod 500 .git-hooks-empty
  git config --worktree core.hooksPath "$PWD/.git-hooks-empty"

  # Disable credentials
  git config --worktree credential.helper ""

  # Disable push
  git remote set-url --push origin DISABLED

  # Safe push default
  git config --worktree push.default current

  # Enable object integrity checking
  git config --worktree transfer.fsckObjects true
  git config --worktree receive.fsckObjects true
}
```

---

## Implementation Recommendations

### For Multi-Agent Ralph Loop

#### Phase 1: WorkTrunk Integration

1. **Install WorkTrunk:**
   ```bash
   brew install max-sixty/worktrunk/wt && wt config shell install
   ```

2. **Add to ralph commands:**
   ```bash
   # scripts/ralph
   ralph_worktree() {
     local task="$1"
     local branch="ai/ralph/$(date +%Y%m%d)-${task// /-}"
     wt switch -c -x claude "$branch"
   }
   ```

3. **Create skill for worktree management:**
   ```yaml
   # .claude/skills/git-worktree/skill.md
   name: git-worktree
   description: Manage parallel Claude sessions with git worktrees
   ```

#### Phase 2: Orchestrator Integration

1. **Modify orchestrator agent to spawn worktrees:**
   ```bash
   @orchestrator:
     - Analyze task complexity
     - If parallelizable: spawn worktrees via wt
     - Monitor via wt list
     - Merge via wt merge when complete
   ```

2. **Add status tracking:**
   ```json
   // .claude/settings.json
   {
     "statusLine": {
       "type": "command",
       "command": "wt list statusline --claude-code"
     }
   }
   ```

#### Phase 3: PR Workflow

```bash
# Workflow for completed feature
wt switch feature-x        # Switch to worktree
# ... Claude completes work ...
wt merge                   # Auto: squash, rebase, merge, cleanup
gh pr create               # Create PR for review
```

---

## Sources

### Primary Sources
- [WorkTrunk Documentation](https://worktrunk.dev/claude-code/)
- [WorkTrunk GitHub](https://github.com/max-sixty/worktrunk)
- [claude-wt GitHub](https://github.com/jlowin/claude-wt)
- [ccswarm GitHub](https://github.com/nwiizo/ccswarm)

### Technical References
- [incident.io Blog: Shipping Faster with Claude Code and Git Worktrees](https://incident.io/blog/shipping-faster-with-claude-code-and-git-worktrees)
- [Simon Willison: Parallel Coding Agents](https://simonwillison.net/2025/Oct/5/parallel-coding-agents/)
- [Parallel Claude Code Sessions Tutorial](https://nateross.dev/blog/claude-code-tutorials/part-1-git-worktrees)
- [Claude Code Subagents Guide](https://zachwills.net/how-to-use-claude-code-subagents-to-parallelize-development/)
- [Multi-Agent Orchestration: 10+ Claude Instances](https://dev.to/bredmond1019/multi-agent-orchestration-running-10-claude-instances-in-parallel-part-3-29da)

### Feature Requests
- [GitHub Issue #4963: Integrated Parallel Task Management](https://github.com/anthropics/claude-code/issues/4963)

### Security References
- [Git Security Vulnerabilities CVE-2025-48384](https://github.blog/open-source/git/git-security-vulnerabilities-announced-6/)
- Codex GPT-5 Security Analysis (this document)

---

## Appendix: Quick Start

### Fastest Path to Parallel Development

```bash
# 1. Install WorkTrunk
brew install max-sixty/worktrunk/wt
wt config shell install
source ~/.zshrc  # or restart terminal

# 2. Create feature worktrees
wt switch -c feature-auth
wt switch -c feature-api
wt switch -c feature-ui

# 3. Launch Claude in each (separate terminals)
cd ../repo.feature-auth && claude
cd ../repo.feature-api && claude
cd ../repo.feature-ui && claude

# 4. Monitor progress
wt list

# 5. Merge completed work
wt switch feature-auth
wt merge  # Auto squash, rebase, merge

# 6. Create PR
gh pr create --fill
```

---

*Document generated by Multi-Agent Ralph Loop v2.19 research system*
