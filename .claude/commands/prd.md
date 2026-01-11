---
name: prd
prefix: "@prd"
category: tools
color: green
description: "Product Requirements Document generation and management system"
---

# /prd

Generate and manage Product Requirements Documents (PRDs) with INVEST-compliant user stories for structured task breakdown.

## Overview

The PRD system provides a structured approach to defining features before implementation. It generates comprehensive PRDs with user stories, acceptance criteria, technical requirements, and implementation plans.

## When to Use

- Planning new features or major enhancements
- Breaking down complex projects into user stories
- Creating structured task lists for Ralph Loop execution
- Documenting requirements for team collaboration
- Converting PRDs into actionable implementation tasks

## PRD Structure

Each PRD includes:

| Section | Purpose |
|---------|---------|
| **Overview** | Brief description and business value |
| **Goals** | Measurable objectives |
| **User Stories** | INVEST-compliant stories with acceptance criteria |
| **Technical Requirements** | Architecture, stack, dependencies, security |
| **Success Criteria** | Metrics and targets |
| **Out of Scope** | What's explicitly NOT included |
| **Implementation Plan** | Phased tasks breakdown |
| **Risks & Mitigations** | Potential issues and solutions |

## Available Commands

### Create PRD

```bash
ralph prd create "Implement OAuth2 authentication"
ralph prd create "Add real-time notifications" --priority high
```

Creates a new PRD file in `tasks/prd-<feature>.md` using the template.

### Convert to Stories

```bash
ralph prd convert tasks/prd-auth.md
```

Converts PRD into actionable user stories in `tasks/prd-auth.json`.

### Show Status

```bash
ralph prd status
```

Shows progress across all PRDs (stories completed, remaining).

### Get Next Story

```bash
ralph prd next
```

Returns the next uncompleted story for implementation.

## Task Tool Invocation

```yaml
Task:
  subagent_type: "general-purpose"
  model: "opus"
  run_in_background: false
  description: "Creating PRD for OAuth2 feature"
  prompt: |
    Create a comprehensive PRD for implementing OAuth2 authentication:

    1. Use ralph prd create "OAuth2 authentication"
    2. Fill in all sections of tasks/prd-oauth2.md:
       - Overview: Why OAuth2? Benefits?
       - Goals: What metrics define success?
       - User Stories: INVEST-compliant stories
       - Technical Requirements: Stack, dependencies
       - Implementation Plan: Phased approach
    3. Convert to stories: ralph prd convert tasks/prd-oauth2.md
    4. Validate structure and completeness

    Apply EnterPlanMode before starting.
```

## User Story Format (INVEST)

PRDs generate stories following INVEST principles:

```
As a {{persona}},
I want to {{action}},
So that {{benefit}}.

Acceptance Criteria:
- [ ] {{criterion_1}}
- [ ] {{criterion_2}}
- [ ] {{criterion_3}}

Technical Notes:
{{implementation_hints}}
```

**INVEST Principles:**
- **I**ndependent: Can be completed standalone
- **N**egotiable: Details can be adjusted
- **V**aluable: Provides user/business value
- **E**stimable: Complexity can be estimated
- **S**mall: Fits within iteration limits
- **T**estable: Clear acceptance criteria

## CLI Execution Examples

```bash
# 1. Create PRD for new feature
ralph prd create "User notification system"

# 2. Edit the PRD file
code tasks/prd-notifications.md

# 3. Convert to user stories
ralph prd convert tasks/prd-notifications.md
# Creates: tasks/prd-notifications.json

# 4. Check status
ralph prd status
# Shows: 5 stories, 2 completed, 3 remaining

# 5. Get next story
ralph prd next
# Returns: Story 3 - As a user, I want to...

# 6. Execute with Ralph Loop
ralph loop --prd tasks/prd-notifications.json
```

## Template Placeholders

The PRD template (`~/.claude/templates/prd-template.md`) uses these placeholders:

```markdown
{{feature_name}}       - Feature title
{{status}}             - Draft/Active/Complete
{{priority}}           - Critical/High/Medium/Low
{{overview}}           - Feature description
{{goal_N}}             - Measurable objectives
{{story_N_title}}      - User story title
{{persona_N}}          - User type
{{action_N}}           - Desired action
{{benefit_N}}          - User benefit
{{criterion_N_M}}      - Acceptance criterion
{{technical_notes_N}}  - Implementation hints
{{architecture_description}}
{{frontend_tech}}
{{backend_tech}}
{{security_req_N}}
{{metric_N}}
{{out_of_scope_N}}
{{task_N_M}}
{{risk_N}}
```

## Integration with Ralph Loop

PRDs integrate at planning phase:

```
0. PRD CREATION     → ralph prd create "feature"
1. /clarify         → Intensive questions (populate PRD)
2. /classify        → Complexity routing
3. PLAN             → User approval (review PRD)
4. PRD CONVERSION   → ralph prd convert tasks/prd-feature.md
5. EXECUTION        → ralph loop --prd tasks/prd-feature.json
6. /gates           → Quality validation per story
7. /retrospective   → Propose PRD improvements
→ VERIFIED_DONE
```

## PRD-Driven Development Workflow

```bash
# Step 1: Create PRD
ralph prd create "Payment processing integration"

# Step 2: Populate PRD (manual or with Claude)
# Edit: tasks/prd-payments.md
# Fill: Overview, Goals, Stories, Technical Requirements

# Step 3: Review with stakeholders
# Get approval on PRD structure and scope

# Step 4: Convert to user stories
ralph prd convert tasks/prd-payments.md
# Output: tasks/prd-payments.json with 10 stories

# Step 5: Execute story-by-story
ralph loop --prd tasks/prd-payments.json
# Iterates through each story with Ralph Loop

# Step 6: Track progress
ralph prd status
# Shows: 7/10 stories completed

# Step 7: Get next story
ralph prd next
# Returns: Story 8 - As a merchant...
```

## Example PRD Sections

**User Story Example:**
```markdown
### Story 1: Basic OAuth2 Flow

**As a** web application user,
**I want to** sign in using my Google account,
**So that** I don't need to create and remember another password.

**Acceptance Criteria:**
- [ ] "Sign in with Google" button displays on login page
- [ ] Clicking button redirects to Google OAuth consent screen
- [ ] After authorization, user is redirected back with access token
- [ ] User profile is created/updated from Google user info
- [ ] User session is established and persistent

**Technical Notes:**
- Use passport.js with passport-google-oauth20 strategy
- Store tokens securely in session with encryption
- Implement PKCE flow for additional security
- Add rate limiting to prevent OAuth abuse
```

**Technical Requirements Example:**
```markdown
### Architecture
Stateless OAuth2 flow with JWT tokens:
1. Client requests authorization URL
2. User authenticates with provider
3. Provider redirects with authorization code
4. Server exchanges code for access token
5. Server issues JWT for session management

### Security Requirements
- Use HTTPS for all OAuth endpoints
- Implement CSRF protection with state parameter
- Store client secrets in environment variables
- Add rate limiting (5 attempts per 15 minutes)
- Implement token rotation for refresh tokens
```

## CLI Commands

```bash
# Create new PRD
ralph prd create <feature-name> [--priority high|medium|low]

# Convert PRD to user stories
ralph prd convert <prd-file.md>

# Show PRD status
ralph prd status [<prd-file.md>]

# Get next uncompleted story
ralph prd next [<prd-file.md>]

# List all PRDs
ralph prd list

# Validate PRD structure
ralph prd validate <prd-file.md>

# Execute PRD with Ralph Loop
ralph loop --prd <prd-file.json>
```

## Related Commands

- `/clarify` - Intensive questions (populate PRD details)
- `/loop` - Execute PRD stories iteratively
- `/orchestrator` - Full workflow with PRD integration
- `/skill` - Create skills referenced in PRD technical notes

## Best Practices

1. **Start with Overview** - Clear problem statement before solutions
2. **Measurable Goals** - Use specific metrics (e.g., "reduce load time by 30%")
3. **INVEST Stories** - Ensure each story is independent and testable
4. **Scope Management** - Explicitly document "Out of Scope" items
5. **Risk Assessment** - Identify risks early with mitigations
6. **Stakeholder Review** - Get approval before converting to stories
7. **Iterative Execution** - Execute one story at a time with validation

## Troubleshooting

**PRD Template Not Found:**
```bash
# Ensure template exists
ls -la ~/.claude/templates/prd-template.md

# Create from example
ralph prd template
```

**Invalid Story Format:**
```bash
# Validate PRD structure
ralph prd validate tasks/prd-feature.md

# Check for missing acceptance criteria
# Ensure "As a/I want to/So that" format
```

**Story Not Converting:**
```bash
# View conversion log
cat ~/.ralph/prd-conversion.log

# Manually convert with explicit format
ralph prd convert tasks/prd-feature.md --format json
```

## Example: Complete PRD Workflow

```bash
# 1. Create PRD
ralph prd create "Real-time collaboration features"
# Creates: tasks/prd-collaboration.md

# 2. Populate with Claude's help
/prd create "Real-time collaboration features"
# Claude fills in:
# - Overview: WebSocket-based real-time editing
# - Goals: <200ms latency, 10K concurrent users
# - Stories: 8 INVEST-compliant stories
# - Technical: Node.js, Socket.io, Redis pub/sub
# - Risks: Race conditions, conflict resolution

# 3. Review and approve
code tasks/prd-collaboration.md
# Make adjustments, get stakeholder sign-off

# 4. Convert to stories
ralph prd convert tasks/prd-collaboration.md
# Creates: tasks/prd-collaboration.json (8 stories)

# 5. Execute first story
ralph loop --prd tasks/prd-collaboration.json
# Story 1: Setup WebSocket server
# Applies Ralph Loop: execute → validate → iterate
# Gates pass: TypeScript types, ESLint, tests

# 6. Check progress
ralph prd status
# Shows: 1/8 stories completed

# 7. Continue with next story
ralph prd next
# Returns: Story 2 - Implement room management

# Repeat steps 5-7 until all stories complete
```

## References

- Template: `~/.claude/templates/prd-template.md`
- INVEST Principles: Independent, Negotiable, Valuable, Estimable, Small, Testable
- Ryan Carson workflow: PRD → Stories → Ralph (25 iterations)

---

**PRD System v2.32**
Part of: Multi-Agent Ralph Wiggum orchestration system
