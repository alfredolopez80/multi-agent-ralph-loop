# Repository Isolation Rule v1.0.0

## Purpose

Prevent context confusion, token waste, and accidental modifications when working in a repository by enforcing strict boundaries.

## Core Principle

> **When working in Repository A, you MUST NOT treat Repository B as your workspace.**

## What This Means

### PROHIBITED Actions on External Repositories

When your current working directory is in Repository A:

1. **DO NOT** edit/write files in another repository
2. **DO NOT** analyze another repository's codebase as if it were your task
3. **DO NOT** run commands (git, tests, builds) in another repository
4. **DO NOT** search for bugs/issues in another repository
5. **DO NOT** create commits/branches in another repository

### ALLOWED Actions (Reference Use Only)

External repositories MAY be accessed ONLY for:

1. **Learning patterns** via `/repo-learn` or `/curator`
2. **Copying specific code snippets** as reference (with attribution)
3. **Comparing implementations** to inform current work
4. **Fetching documentation** from official repos

## Detection Criteria

A prompt likely violates this rule if:

| Signal | Example | Risk |
|--------|---------|------|
| Path mentions another repo | "fix bug in ~/GitHub/OtherRepo" | HIGH |
| Git commands for other repo | "commit changes to project-x" | HIGH |
| Analysis scope mismatch | "analyze the auth module" when that module doesn't exist here | MEDIUM |
| Mixed file references | "copy from A and modify B" where B is external | MEDIUM |

## Correct Patterns

### Learning from External Repo
```bash
# CORRECT: Learn patterns, apply to current repo
/repo-learn https://github.com/fastapi/fastapi
# Then implement learned patterns HERE

# CORRECT: Curator workflow
/curator full --type backend --lang python
# Approved repos are learned, patterns applied HERE
```

### Referencing Code
```bash
# CORRECT: Read reference, implement locally
"Look at how FastAPI handles dependency injection, then implement similar pattern in OUR auth module"

# INCORRECT: Work in FastAPI repo
"Fix the bug in FastAPI's dependency injection"
```

## Implementation

This rule is enforced by:
1. `repo-boundary-guard.sh` - PreToolUse hook for Edit/Write/Bash
2. Context analysis in orchestrator prompts
3. User prompt validation

## Exceptions

The rule does NOT apply when:
1. User explicitly says "switch to repo X" or "now work on project Y"
2. The session was started from a different repository root
3. The action is reading global configs (`~/.claude/`, `~/.ralph/`)

## Error Response

When violation detected:

```
⚠️ REPO BOUNDARY VIOLATION
━━━━━━━━━━━━━━━━━━━━━━━━━━
Current repo: /path/to/current-repo
Attempted access: /path/to/other-repo

This appears to be an attempt to work in a different repository.

Options:
1. Use /repo-learn to learn from the external repo
2. Use /curator to curate and learn patterns
3. If intentional, explicitly say "switch to [repo-name]"
```
