---
# VERSION: 2.50.0
name: codex-plan
prefix: "@codex-plan"
category: planning
color: purple
description: "Generate implementation plans using Codex 5.2 with deep reasoning"
argument-hint: "<task-description>"
---

# Codex Plan Generator

Generate comprehensive implementation plans using OpenAI Codex 5.2 with maximum reasoning depth (`xhigh`). Uses AskUser for clarifying questions before planning.

## Usage

```
/codex-plan <task-description>
```

## Workflow

### Phase 1: Clarification (AskUser)

Ask 3-6 clarifying questions using the AskUser tool:

**MUST_HAVE questions** (required to proceed):
1. What's the primary goal and expected outcome?
2. Are there specific technologies, frameworks, or languages to use?
3. What's the target environment (production, development, local)?

**NICE_TO_HAVE questions** (optional but valuable):
4. Any specific constraints or requirements to consider?
5. Expected scale or performance requirements?
6. Any existing code or patterns to follow?

### Phase 2: Codex Execution

Execute Codex with maximum reasoning:

```bash
codex plan \
  --model "gpt-5.2-codex" \
  --reasoning "xhigh" \
  --prompt "Based on user clarifications:
  - Goal: {user_goal}
  - Tech stack: {tech_stack}
  - Environment: {environment}
  - Constraints: {constraints}

Generate a detailed implementation plan following these guidelines:
1. Analyze requirements thoroughly
2. Design architecture with clean separation of concerns
3. Identify all files to create/modify
4. Include security considerations
5. Add error handling strategy
6. Plan testing strategy
7. Consider edge cases and failure modes

Output format:
## Implementation Plan: {task}

### Summary
[Brief overview]

### Architecture
[System design]

### Files to Create
| File | Purpose |
|------|---------|
| path/to/file | Description |

### Files to Modify
| File | Change |
|------|--------|
| path/to/file | Description |

### Implementation Steps
1. [Step with details]
2. [Step with details]
...

### Security Considerations
- [Consideration 1]
- [Consideration 2]

### Testing Strategy
- [Test approach]

### Edge Cases
- [Edge case 1]
- [Edge case 2]

### Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Risk 1 | High | Mitigation |

Output ONLY the plan, no conversational text." \
  --output "http://codex-plan.md" \
  --full-auto \
  --skip-git-repo-check
```

### Phase 3: Save Plan

The generated plan is saved to `http://codex-plan.md` in the current directory.

## Integration with Orchestrator

When `/orchestrator` is invoked with Codex preference, this command is automatically suggested:

```
/orchestrator "Implement feature X" --use-codex
```

Or via clarification response:
- User: "Use Codex for planning"
- System: "/codex-plan Implement feature X"

## Output Example

```
=== Codex Plan Generator ===
Goal: Create REST API for user management
Tech: Python, FastAPI, PostgreSQL
Environment: Production

Executing Codex 5.2 with xhigh reasoning...

Plan saved to: /Users/.../http://codex-plan.md

✓ Plan generated successfully
```

## Requirements

| Tool | Purpose |
|------|---------|
| `codex` | OpenAI Codex CLI (`npm install -g @openai/codex`) |
| `gpt-5.2-codex` | Model with maximum reasoning capability |

## Notes

- **Reasoning Level**: `xhigh` provides deepest analysis but takes longer
- **Auto-Mode**: `--full-auto` prevents interactive prompts
- **Git Check**: `--skip-git-repo-check` allows running outside git repos
- **Plan Location**: `http://codex-plan.md` uses local file path syntax
