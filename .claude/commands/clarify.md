---
# VERSION: 2.43.0
name: clarify
prefix: "@clarify"
category: orchestration
color: purple
description: "Deep clarification using AskUserQuestion - MUST_HAVE and NICE_TO_HAVE questions"
argument-hint: "<task description>"
---

# /clarify - Deep Clarification Command

This command implements intensive clarification using Claude's native `AskUserQuestion` tool.

## Philosophy

**The key to successful agentic coding is MAXIMUM CLARIFICATION before implementation.**

- Never assume - always ask
- Categorize questions as MUST_HAVE (blocking) or NICE_TO_HAVE (optional)
- Use structured multiple-choice questions when possible
- Continue asking until the task is fully understood

## Execution

When `/clarify` is invoked, you MUST:

### Step 1: Analyze the Task

Read the task description and identify:
- What is explicitly stated
- What is ambiguous or unclear
- What assumptions would need to be made
- What decisions have multiple valid options

### Step 2: Generate MUST_HAVE Questions

These are **blocking** - implementation cannot proceed without answers.

Use `AskUserQuestion` with structured options:

```yaml
AskUserQuestion:
  questions:
    - question: "What is the primary objective of this task?"
      header: "Objective"
      multiSelect: false
      options:
        - label: "Option A"
          description: "Description of option A"
        - label: "Option B"
          description: "Description of option B"
```

Categories of MUST_HAVE questions:

1. **Scope Definition**
   - What exactly needs to be changed?
   - What files/modules are in scope?
   - What is explicitly out of scope?

2. **Functional Requirements**
   - What are the inputs?
   - What are the expected outputs?
   - What are the edge cases?

3. **Critical Decisions**
   - Technology/library choices
   - Architectural patterns
   - Security considerations

### Step 3: Generate NICE_TO_HAVE Questions

These are helpful but not blocking. Defaults can be assumed if user skips.

```yaml
AskUserQuestion:
  questions:
    - question: "Any preferences for implementation style?"
      header: "Style"
      multiSelect: true
      options:
        - label: "Minimal changes (Recommended)"
          description: "Only what's strictly necessary"
        - label: "Include tests"
          description: "Add comprehensive test coverage"
        - label: "Add documentation"
          description: "Include inline docs"
```

Categories of NICE_TO_HAVE questions:

1. **Implementation Preferences**
   - Coding style preferences
   - Comment/documentation level
   - Test coverage expectations

2. **Future Considerations**
   - Extensibility needs
   - Performance requirements
   - Maintenance expectations

### Step 4: Summarize Understanding

After all questions are answered, provide a clear summary:

```
## Clarification Summary

**Task**: [Original task]

**MUST_HAVE Answers**:
- Objective: [answer]
- Scope: [answer]
- Key decision: [answer]

**NICE_TO_HAVE Answers**:
- Style: [answer or "default assumed"]
- Tests: [answer or "default assumed"]

**Ready to proceed**: Yes/No
**Next step**: [Plan Mode / Direct Implementation]
```

## Example

```
User: /clarify Implement user authentication

Claude uses AskUserQuestion:

Q1 (MUST_HAVE): "Which authentication method?"
   - [ ] Username/Password
   - [ ] OAuth (Google, GitHub, etc.)
   - [ ] Magic links (email)
   - [ ] Multi-factor

Q2 (MUST_HAVE): "Scope of implementation?"
   - [ ] Backend only (API endpoints)
   - [ ] Full stack (frontend + backend)
   - [ ] Backend + mobile SDK

Q3 (MUST_HAVE): "Session management?"
   - [ ] JWT tokens
   - [ ] Server-side sessions
   - [ ] Hybrid approach

Q4 (NICE_TO_HAVE): "Additional features?"
   - [ ] Password reset
   - [ ] Email verification
   - [ ] Rate limiting
   - [ ] Audit logging

After answers → Summarize → Enter Plan Mode
```

## Integration with Orchestrator

When called from `/orchestrator`, this clarify step is mandatory.
The orchestrator will NOT proceed until all MUST_HAVE questions are answered.

## Anti-Patterns

❌ Don't ask questions that can be answered by reading the codebase
❌ Don't ask redundant questions
❌ Don't make the user repeat themselves
❌ Don't assume answers without explicit confirmation
❌ Don't skip clarification for "simple" tasks (they're rarely simple)
