# WorkTrunk Integration Guide for Multi-Agent Ralph Loop

> **Version**: v2.19+
> **Status**: Recommended Implementation

## Overview

This guide describes how to integrate WorkTrunk with Multi-Agent Ralph Loop for parallel Claude Code development using git worktrees.

---

## Prerequisites

### System Requirements
- macOS or Linux
- Git 2.20+
- Homebrew (macOS) or Cargo (Rust)
- Claude Code CLI installed and authenticated

### Installation

```bash
# Install WorkTrunk
brew install max-sixty/worktrunk/wt

# Enable shell integration
wt config shell install

# Reload shell
source ~/.zshrc  # or ~/.bashrc
```

### Verify Installation

```bash
wt --version
# worktrunk 0.9.1

wt --help
```

---

## Configuration

### 1. Claude Code Statusline

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "wt list statusline --claude-code"
  }
}
```

### 2. Shell Aliases

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# WorkTrunk aliases
alias wts="wt switch"
alias wtc="wt switch -c"
alias wtl="wt list"
alias wtm="wt merge"
alias wtr="wt remove"

# WorkTrunk + Claude
alias wtclaude="wt switch -c -x claude"

# Multi-Agent Ralph + WorkTrunk
alias rw="ralph worktree"
alias rwp="ralph worktree-parallel"
```

### 3. Git Configuration

```bash
# Enable per-worktree config
git config --global extensions.worktreeConfig true

# Safe push defaults
git config --global push.default current

# Recommended aliases
git config --global alias.wt "worktree"
git config --global alias.wta "worktree add"
git config --global alias.wtl "worktree list"
git config --global alias.wtr "worktree remove"
```

---

## Ralph Integration

### Add Worktree Commands to Ralph

Edit `scripts/ralph` to add:

```bash
# --- WORKTREE COMMANDS ---

ralph_worktree() {
  local task="$1"
  local branch_name

  if [ -z "$task" ]; then
    echo "Usage: ralph worktree <task-description>"
    return 1
  fi

  # Generate branch name from task
  branch_name="ai/ralph/$(date +%Y%m%d)-${task// /-}"
  branch_name="${branch_name:0:50}"  # Limit length

  echo "Creating worktree for: $task"
  echo "Branch: $branch_name"

  # Create worktree and launch Claude
  wt switch -c -x claude "$branch_name"
}

ralph_worktree_parallel() {
  local tasks=("$@")
  local pids=()

  if [ ${#tasks[@]} -eq 0 ]; then
    echo "Usage: ralph worktree-parallel <task1> <task2> ..."
    return 1
  fi

  echo "Creating ${#tasks[@]} parallel worktrees..."

  for task in "${tasks[@]}"; do
    local branch="ai/ralph/$(date +%Y%m%d)-${task// /-}"
    branch="${branch:0:50}"

    echo "Spawning: $branch"
    wt switch -c "$branch" &
    pids+=($!)
  done

  # Wait for all worktree creation
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  echo ""
  echo "Worktrees created. Launch Claude in each:"
  wt list

  echo ""
  echo "To launch Claude in a worktree:"
  echo "  wt switch <branch> && claude"
}

ralph_worktree_status() {
  echo "Active Worktrees:"
  echo ""
  wt list
}

ralph_worktree_merge() {
  local branch="$1"

  if [ -z "$branch" ]; then
    echo "Usage: ralph worktree-merge <branch>"
    return 1
  fi

  echo "Merging worktree: $branch"
  wt switch "$branch"
  wt merge
}

ralph_worktree_cleanup() {
  echo "Cleaning up completed worktrees..."

  # List merged branches
  git branch --merged main | grep "ai/ralph" | while read branch; do
    echo "Removing: $branch"
    wt remove "$branch" 2>/dev/null || true
    git branch -d "$branch" 2>/dev/null || true
  done

  # Prune worktree metadata
  git worktree prune

  echo "Cleanup complete."
  wt list
}
```

### Usage

```bash
# Single worktree
ralph worktree "implement authentication"

# Multiple parallel worktrees
ralph worktree-parallel "backend api" "frontend ui" "test suite"

# Check status
ralph worktree-status

# Merge completed work
ralph worktree-merge feature-auth

# Cleanup
ralph worktree-cleanup
```

---

## Skill: git-worktree

Create `.claude/skills/git-worktree/skill.md`:

```markdown
---
name: git-worktree
description: Manage parallel Claude sessions with git worktrees using WorkTrunk
triggers:
  - worktree
  - parallel
  - spawn
  - wt
---

# Git Worktree Management Skill

## Purpose
Enable parallel Claude Code development by creating isolated git worktrees for each task.

## Prerequisites
- WorkTrunk installed: `brew install max-sixty/worktrunk/wt`
- Shell integration: `wt config shell install`

## Commands

### Create Single Worktree
```bash
wt switch -c -x claude <branch-name>
```

### Create Multiple Worktrees (Parallel)
```bash
# From orchestrator, spawn parallel tasks:
wt switch -c task-1 &
wt switch -c task-2 &
wt switch -c task-3 &
wait

# List all worktrees
wt list
```

### Monitor Status
```bash
wt list
# Shows: Branch, Status (🤖/💬), HEAD±, main↕, Path
```

### Merge Completed Work
```bash
wt switch <branch>
wt merge  # Squash + rebase + merge + cleanup
```

### Cleanup
```bash
wt remove <branch>  # Remove single
git worktree prune  # Clean metadata
```

## Workflow Example

1. User requests: "Implement feature X with tests and docs"
2. Orchestrator creates worktrees:
   ```bash
   wt switch -c feat-x-impl
   wt switch -c feat-x-tests
   wt switch -c feat-x-docs
   ```
3. Each worktree gets Claude session
4. Monitor: `wt list`
5. When complete: `wt merge` for each
6. Create PRs: `gh pr create --fill`

## Security Notes
- Apply security hardening per worktree (see SECURITY.md)
- Use branch naming: `ai/<tool>/<task>-<date>`
- Disable push capability when needed
```

---

## Orchestrator Integration

Update `.claude/agents/orchestrator.md`:

```markdown
## Parallel Task Execution (v2.19+)

When a task can be parallelized:

1. **Analyze for parallelization**:
   - Independent subtasks (no dependencies)
   - Different files/components
   - Separate concerns (backend/frontend/tests)

2. **Create worktrees**:
   ```bash
   wt switch -c ai/orch/<subtask-1>
   wt switch -c ai/orch/<subtask-2>
   wt switch -c ai/orch/<subtask-3>
   ```

3. **Delegate to subagents**:
   - Each subagent works in its worktree
   - Use Task tool with run_in_background: true
   - Monitor via `wt list`

4. **Merge and validate**:
   ```bash
   wt merge  # For each completed worktree
   ralph gates  # Run quality gates
   ```

5. **Create PRs**:
   ```bash
   gh pr create --fill
   ```

### Example: Full-Stack Feature

```
User: "Add user profile feature with avatar upload"

Orchestrator Analysis:
- Backend API: /api/profile, /api/avatar
- Frontend UI: ProfilePage, AvatarUpload
- Tests: Unit + Integration
- Docs: API documentation

Parallel Execution:
1. wt switch -c ai/orch/profile-backend
2. wt switch -c ai/orch/profile-frontend
3. wt switch -c ai/orch/profile-tests
4. wt switch -c ai/orch/profile-docs

Monitor: wt list (shows 🤖/💬 status)

Merge Order:
1. profile-backend (no deps)
2. profile-frontend (after backend)
3. profile-tests (after both)
4. profile-docs (last)
```
```

---

## Hooks Configuration

### Pre-Merge Hook (Validation)

```bash
wt config hooks create pre-merge "npm test && npm run lint"
```

### Post-Merge Hook (Cleanup)

```bash
wt config hooks create post-merge "git push origin HEAD"
```

### Custom Hook Script

```bash
#!/bin/bash
# .wt-hooks/pre-merge.sh

echo "Running pre-merge validation..."

# Run tests
npm test || exit 1

# Run linting
npm run lint || exit 1

# Security scan
npm audit --audit-level=high || exit 1

# Type check
npm run type-check || exit 1

echo "Pre-merge validation passed!"
```

---

## Monitoring Dashboard

### Terminal-Based Monitoring

```bash
# Watch worktree status
watch -n 5 'wt list'

# Or with more detail
watch -n 5 'wt list && echo "" && git status -sb'
```

### Tmux Layout

```bash
# Create monitoring layout
tmux new-session -d -s worktrees

# Main pane: status
tmux send-keys -t worktrees 'watch -n 5 "wt list"' C-m

# Split for each worktree
tmux split-window -h -t worktrees
tmux send-keys -t worktrees 'cd ../repo.feat-1 && claude' C-m

tmux split-window -v -t worktrees
tmux send-keys -t worktrees 'cd ../repo.feat-2 && claude' C-m

# Attach
tmux attach -t worktrees
```

---

## Troubleshooting

### Common Issues

**"Cannot create worktree"**
```bash
# Check existing worktrees
wt list

# Prune orphaned entries
git worktree prune
```

**"Branch already checked out"**
```bash
# Find where branch is checked out
git worktree list | grep <branch>

# Remove or switch away
wt remove <path>
```

**"Hook permission denied"**
```bash
chmod +x .git/hooks/*
```

**"Claude status not showing"**
```bash
# Verify statusline config
cat ~/.claude/settings.json | jq '.statusLine'

# Test command manually
wt list statusline --claude-code
```

### Debug Mode

```bash
# Enable verbose output
WT_DEBUG=1 wt switch -c test-branch
```

---

## Best Practices

### Branch Naming Convention

| Pattern | Example |
|---------|---------|
| AI worktrees | `ai/<tool>/<task>-<yyyymmdd>` |
| Feature | `ai/ralph/user-auth-20260103` |
| Bugfix | `ai/debug/fix-login-20260103` |
| Experiment | `ai/exp/try-new-lib-20260103` |

### Worktree Directory Structure

```
~/projects/
├── my-repo/                 # Main repository
├── my-repo.feat-auth/       # WorkTrunk worktree
├── my-repo.feat-api/        # WorkTrunk worktree
└── my-repo.feat-ui/         # WorkTrunk worktree
```

### Cleanup Schedule

```bash
# Daily cleanup of merged worktrees
ralph worktree-cleanup

# Weekly full prune
git worktree prune
git gc
```

---

## Migration from Manual Worktrees

### Before (Manual)
```bash
git checkout -b feat-x
git worktree add ../repo-feat-x feat-x
cd ../repo-feat-x
claude
# ... work ...
cd ../repo
git merge feat-x
git worktree remove ../repo-feat-x
git branch -d feat-x
```

### After (WorkTrunk)
```bash
wt switch -c -x claude feat-x
# ... work ...
wt merge  # Does all cleanup automatically
```

---

*Integration guide for Multi-Agent Ralph Loop v2.19+*
