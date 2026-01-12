---
name: deep-clarification
description: "Intensive task clarification using AskUserQuestion - use when starting any non-trivial task"
---

**ultrathink** - Take a deep breath. We're not here to write code. We're here to make a dent in the universe.

## The Vision
Clarity creates inevitability. Every question should narrow the path to truth.

## Your Work, Step by Step
1. **Task understanding**: Identify the type of work.
2. **Scope definition**: Bound the change clearly.
3. **Technical decisions**: Surface approach preferences.
4. **Quality requirements**: Define tests/docs expectations.
5. **Confirm**: Summarize and proceed only when clear.

## Ultrathink Principles in Practice
- **Think Different**: Challenge implicit assumptions.
- **Obsess Over Details**: Capture constraints precisely.
- **Plan Like Da Vinci**: Build the question set first.
- **Craft, Don't Code**: Ask fewer, better questions.
- **Iterate Relentlessly**: Refine after answers.
- **Simplify Ruthlessly**: Remove nonessential questions.

# Deep Clarification Skill

This skill provides patterns for intensive task clarification using Claude's native `AskUserQuestion` tool.

## When to Use

**ALWAYS use this skill when:**
- Starting any new feature implementation
- The task could be interpreted multiple ways
- There are architectural decisions to make
- The scope is not 100% clear
- The user's request is brief or high-level

## Clarification Framework

### Phase 1: Task Understanding

Ask about the fundamental nature of the task:

```yaml
AskUserQuestion:
  questions:
    - question: "What type of work is this?"
      header: "Task Type"
      multiSelect: false
      options:
        - label: "New Feature"
          description: "Adding new functionality that doesn't exist"
        - label: "Enhancement"
          description: "Improving existing functionality"
        - label: "Bug Fix"
          description: "Correcting incorrect behavior"
        - label: "Refactoring"
          description: "Improving code without changing behavior"
```

### Phase 2: Scope Definition

Clarify the boundaries:

```yaml
AskUserQuestion:
  questions:
    - question: "What is the scope of this change?"
      header: "Scope"
      multiSelect: false
      options:
        - label: "Single file"
          description: "Changes confined to one file"
        - label: "Single module/feature"
          description: "Changes within one logical area"
        - label: "Cross-cutting"
          description: "Changes spanning multiple areas"
        - label: "System-wide"
          description: "Architectural changes"
```

### Phase 3: Technical Decisions

For implementation choices:

```yaml
AskUserQuestion:
  questions:
    - question: "Do you have preferences for the implementation approach?"
      header: "Approach"
      multiSelect: true
      options:
        - label: "Follow existing patterns (Recommended)"
          description: "Match codebase conventions"
        - label: "Introduce new pattern"
          description: "Implement a better approach"
        - label: "Minimal changes"
          description: "Smallest possible diff"
        - label: "Comprehensive solution"
          description: "Full implementation with all edge cases"
```

### Phase 4: Quality Requirements

Clarify expectations:

```yaml
AskUserQuestion:
  questions:
    - question: "What quality gates apply?"
      header: "Quality"
      multiSelect: true
      options:
        - label: "Unit tests required"
          description: "Add comprehensive unit tests"
        - label: "Integration tests required"
          description: "Add integration/e2e tests"
        - label: "Documentation required"
          description: "Add/update documentation"
        - label: "Code review required"
          description: "Multi-model adversarial review"
```

## Question Templates by Domain

### Authentication Tasks

```yaml
AskUserQuestion:
  questions:
    - question: "Which authentication methods should be supported?"
      header: "Auth Method"
      multiSelect: true
      options:
        - label: "Username/Password"
          description: "Traditional credentials"
        - label: "OAuth 2.0"
          description: "Social/external providers"
        - label: "Magic Links"
          description: "Email-based passwordless"
        - label: "API Keys"
          description: "For service-to-service auth"

    - question: "What session management approach?"
      header: "Sessions"
      multiSelect: false
      options:
        - label: "JWT (Recommended)"
          description: "Stateless, scalable"
        - label: "Server Sessions"
          description: "Stateful, more control"
        - label: "Hybrid"
          description: "JWT with refresh tokens in DB"
```

### API Tasks

```yaml
AskUserQuestion:
  questions:
    - question: "What API style?"
      header: "API Style"
      multiSelect: false
      options:
        - label: "REST"
          description: "Resource-oriented HTTP API"
        - label: "GraphQL"
          description: "Query language for APIs"
        - label: "gRPC"
          description: "High-performance RPC"
        - label: "Match existing"
          description: "Follow current codebase patterns"

    - question: "What response format?"
      header: "Format"
      multiSelect: false
      options:
        - label: "JSON (Recommended)"
          description: "Standard JSON responses"
        - label: "JSON:API"
          description: "JSON:API specification"
        - label: "Custom format"
          description: "Project-specific format"
```

### Database Tasks

```yaml
AskUserQuestion:
  questions:
    - question: "What type of database operation?"
      header: "DB Operation"
      multiSelect: true
      options:
        - label: "Schema changes"
          description: "New tables, columns, indexes"
        - label: "Query optimization"
          description: "Improve existing queries"
        - label: "Data migration"
          description: "Transform existing data"
        - label: "New ORM models"
          description: "Add new entity models"

    - question: "Migration approach?"
      header: "Migration"
      multiSelect: false
      options:
        - label: "Rolling (Recommended)"
          description: "Zero-downtime compatible"
        - label: "Maintenance window"
          description: "Can have brief downtime"
        - label: "Background migration"
          description: "Large data transformations"
```

### Frontend Tasks

```yaml
AskUserQuestion:
  questions:
    - question: "What type of frontend work?"
      header: "Frontend"
      multiSelect: true
      options:
        - label: "New component"
          description: "Create new UI component"
        - label: "Modify existing"
          description: "Update existing component"
        - label: "Styling only"
          description: "CSS/design changes"
        - label: "State management"
          description: "Redux/context changes"

    - question: "Browser support requirements?"
      header: "Browsers"
      multiSelect: false
      options:
        - label: "Modern only (Recommended)"
          description: "Chrome, Firefox, Safari, Edge latest"
        - label: "Extended support"
          description: "Include older versions"
        - label: "Legacy required"
          description: "Must support IE11 or older"
```

## Best Practices

1. **Ask in batches of 2-4 questions** - Don't overwhelm with 10 questions at once
2. **MUST_HAVE first** - Get critical answers before nice-to-haves
3. **Provide defaults** - Mark recommended options clearly
4. **Context-aware** - Skip questions you can answer from codebase
5. **Summarize understanding** - Confirm before proceeding

## Integration

After clarification is complete:

1. **Summarize** all answers in a structured format
2. **Classify** the task complexity (1-10)
3. **Enter Plan Mode** for non-trivial tasks
4. **Proceed** only when user confirms understanding is correct
