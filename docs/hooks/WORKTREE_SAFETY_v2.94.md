# Worktree-Safe Hooks v2.94.0

## Problem

Git worktrees create working copies where `.git` is a **file** (not a directory) pointing to the main repo's `.git/worktrees/<name>`. Hooks using `git rev-parse --show-toplevel` get the worktree path, not the main repo where `.claude/` lives.

## Solution

Shared library at `.claude/hooks/lib/worktree-utils.sh` provides worktree-aware path resolution.

### Functions

| Function | Description |
|----------|-------------|
| `get_project_root` | Current working tree root (worktree or main) |
| `get_main_repo` | Always returns the main repository root |
| `get_claude_dir` | Path to `.claude/` in the main repo |
| `is_worktree` | Returns 0 if in a worktree, 1 otherwise |
| `resolve_claude_path <rel>` | Full path to a file under `.claude/` |

### Usage in Hooks

```bash
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  get_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"; }
  get_main_repo() { get_project_root; }
  get_claude_dir() { echo "$(get_main_repo)/.claude"; }
}
REPO_ROOT="$(get_project_root)"
```

The inline fallback ensures hooks still work even if the library is not found.

## Updated Hooks (17)

- `session-start-repo-summary.sh`
- `ralph-subagent-start.sh`
- `pre-commit-batch-skills-test.sh`
- `task-completed-quality-gate.sh`
- `teammate-idle-quality-gate.sh`
- `ralph-stop-quality-gate.sh`
- `subagent-stop-universal.sh`
- `quality-parallel-async.sh`
- `glm-visual-validation.sh`
- `repo-boundary-guard.sh`
- `session-end-handoff.sh`
- `global-task-sync.sh`
- `plan-state-init.sh`
- `auto-plan-state.sh`
- `stop-verification.sh`
- `auto-save-context.sh`
- `agent-teams-coordinator.sh`

## Tests

```bash
bash tests/hooks/test-worktree-utils.sh
```

Validates: library sourcing, path resolution, worktree simulation, hook integration, no hardcoded paths.
