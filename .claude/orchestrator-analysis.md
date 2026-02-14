# Agent Teams Integration Plan - Multi-Agent Ralph v2.85

**Date**: 2026-02-14
**Version**: v2.85.0
**Status**: PLANNING
**Source**: https://code.claude.com/docs/en/agent-teams

---

## Executive Summary

Integration plan for Claude Code's new **Agent Teams** feature with Multi-Agent Ralph orchestration system. This plan covers:

1. **TeammateIdle Hook** - Enforce quality gates when teammates go idle
2. **TaskCompleted Hook** - Prevent premature task completion
3. **Agent Teams Configuration** - Enable via environment variable
4. **Integration with existing GLM-5 teammates** - Unify with current swarm mode

---

## 1. Feature Analysis

### 1.1 Agent Teams Overview

Claude Code Agent Teams allows spawning multiple AI teammates that work in parallel on different aspects of a task.

**Key Components:**
- **Teammates**: Specialized agents (coder, reviewer, tester, orchestrator)
- **TeammateIdle Event**: Triggered when teammate is about to go idle
- **TaskCompleted Event**: Triggered when task is being marked complete

### 1.2 New Hook Events

| Event | Trigger | Exit Code 2 Behavior |
|-------|---------|---------------------|
| **TeammateIdle** | Teammate about to go idle | Send feedback + keep working |
| **TaskCompleted** | Task being marked complete | Prevent completion + send feedback |

### 1.3 Current Configuration Status

**Already configured in settings.json:**
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Existing SubagentStop hook for GLM-5:**
```json
{
  "SubagentStop": [
    {
      "matcher": "glm5-*",
      "hooks": [
        {
          "type": "command",
          "command": ".../glm5-subagent-stop.sh"
        }
      ]
    }
  ]
}
```

---

## 2. Integration Architecture

### 2.1 Hook Event Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      AGENT TEAMS HOOK INTEGRATION                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────┐     ┌──────────────────┐     ┌─────────────────────┐    │
│   │   TEAMMATE   │     │  TeammateIdle    │     │  teammate-idle-     │    │
│   │   WORKING    │ ──► │  HOOK TRIGGER    │ ──► │  quality-gate.sh    │    │
│   └──────────────┘     └──────────────────┘     └──────────┬──────────┘    │
│                                                             │               │
│                              ┌──────────────────────────────┤               │
│                              │                              │               │
│                              ▼                              ▼               │
│                    ┌──────────────────┐          ┌──────────────────┐       │
│                    │  Exit 0: Allow   │          │  Exit 2: Block   │       │
│                    │  teammate idle   │          │  + send feedback │       │
│                    └──────────────────┘          └──────────────────┘       │
│                                                                             │
│   ┌──────────────┐     ┌──────────────────┐     ┌─────────────────────┐    │
│   │    TASK      │     │ TaskCompleted    │     │  task-completed-    │    │
│   │   COMPLETE   │ ──► │  HOOK TRIGGER    │ ──► │  quality-gate.sh    │    │
│   └──────────────┘     └──────────────────┘     └──────────┬──────────┘    │
│                                                             │               │
│                              ┌──────────────────────────────┤               │
│                              │                              │               │
│                              ▼                              ▼               │
│                    ┌──────────────────┐          ┌──────────────────┐       │
│                    │  Exit 0: Allow   │          │  Exit 2: Block   │       │
│                    │  task complete   │          │  + send feedback │       │
│                    └──────────────────┘          └──────────────────┘       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Quality Gate Logic

**TeammateIdle Hook:**
```bash
# Quality checks before teammate goes idle
1. Run linting on modified files
2. Run type checking if TypeScript
3. Check for console.log statements
4. Verify tests pass (if applicable)
5. Check security patterns

# Exit codes:
# 0 = All checks passed, teammate can go idle
# 2 = Issues found, send feedback to teammate
```

**TaskCompleted Hook:**
```bash
# Quality checks before task marked complete
1. Verify all acceptance criteria met
2. Run full quality gates (CORRECTNESS + QUALITY + SECURITY)
3. Check code coverage (if applicable)
4. Verify no TODOs or placeholders left
5. Review for AI-generated slop

# Exit codes:
# 0 = Task meets quality standards
# 2 = Quality issues, prevent completion
```

---

## 3. Implementation Plan

### Phase 1: Hook Scripts Creation (3 files)

**Files to create:**

| File | Purpose | Location |
|------|---------|----------|
| `teammate-idle-quality-gate.sh` | Quality gate for idle teammates | `.claude/hooks/` |
| `task-completed-quality-gate.sh` | Quality gate for task completion | `.claude/hooks/` |
| `agent-teams-coordinator.sh` | Central coordinator for both hooks | `.claude/hooks/` |

### Phase 2: Settings.json Configuration

**Add to hooks configuration:**
```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/.claude/hooks/teammate-idle-quality-gate.sh"
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/.claude/hooks/task-completed-quality-gate.sh"
          }
        ]
      }
    ]
  }
}
```

### Phase 3: Integration with Existing Systems

**GLM-5 Teammates Integration:**
- Unify SubagentStop (existing) with TeammateIdle (new)
- Share quality check functions
- Consolidate reporting

**Quality Gates Integration:**
- Reuse `quality-gates-v2.sh` functions
- Leverage `quality-parallel-async.sh` for parallel checks
- Integrate with `security-full-audit.sh`

### Phase 4: Documentation

**Create documentation:**
- `docs/agent-teams/` folder
- `INTEGRATION_GUIDE.md` - Step-by-step setup
- `HOOK_REFERENCE.md` - Hook behavior details
- `BEST_PRACTICES.md` - Usage patterns

---

## 4. Detailed Hook Specifications

### 4.1 teammate-idle-quality-gate.sh

**Purpose:** Prevent teammates from going idle with low-quality work

**Input (stdin JSON):**
```json
{
  "teammateId": "coder-001",
  "teammateType": "coder",
  "taskId": "task-abc123",
  "filesModified": ["src/api/auth.ts", "src/services/auth.ts"],
  "workSummary": "Implemented OAuth authentication"
}
```

**Output:**
```json
{
  "decision": "approve",
  "reason": "All quality checks passed"
}
```
OR
```json
{
  "decision": "request_changes",
  "reason": "Type errors found in src/api/auth.ts",
  "feedback": "Please fix type errors before going idle",
  "issues": [
    {
      "file": "src/api/auth.ts",
      "line": 42,
      "message": "Property 'token' does not exist on type 'AuthResult'"
    }
  ]
}
```

**Exit Codes:**
- `0`: Allow teammate to go idle
- `2`: Block idle + send feedback to continue working

### 4.2 task-completed-quality-gate.sh

**Purpose:** Ensure task meets quality standards before completion

**Input (stdin JSON):**
```json
{
  "taskId": "task-abc123",
  "taskDescription": "Implement OAuth authentication",
  "completedBy": ["coder-001", "reviewer-001"],
  "filesModified": ["src/api/auth.ts", "tests/auth.test.ts"],
  "acceptanceCriteria": [
    "OAuth login works with Google",
    "Tokens are properly refreshed",
    "Logout clears session"
  ]
}
```

**Output:**
```json
{
  "decision": "approve",
  "reason": "All acceptance criteria verified",
  "verification": {
    "oauth_login": "passed",
    "token_refresh": "passed",
    "logout_clears_session": "passed"
  }
}
```
OR
```json
{
  "decision": "request_changes",
  "reason": "Acceptance criteria not fully met",
  "feedback": "Token refresh functionality needs tests",
  "missingCriteria": [
    "Tokens are properly refreshed"
  ]
}
```

**Exit Codes:**
- `0`: Allow task to complete
- `2`: Prevent completion + send feedback

---

## 5. Quality Check Functions

### 5.1 Shared Functions (agent-teams-coordinator.sh)

```bash
#!/bin/bash
# agent-teams-coordinator.sh - Shared functions for Agent Teams hooks
#
# VERSION: 2.85.0

# Quality check stages
QUALITY_STAGES=("CORRECTNESS" "QUALITY" "SECURITY" "CONSISTENCY")

# Run quality checks on files
run_quality_checks() {
    local files=("$@")
    local results=()
    local has_critical=false

    for file in "${files[@]}"; do
        # Stage 1: CORRECTNESS (blocking)
        if ! check_correctness "$file"; then
            results+=("{\"stage\":\"CORRECTNESS\",\"file\":\"$file\",\"status\":\"FAIL\",\"blocking\":true}")
            has_critical=true
        fi

        # Stage 2: QUALITY (blocking)
        if ! check_quality "$file"; then
            results+=("{\"stage\":\"QUALITY\",\"file\":\"$file\",\"status\":\"FAIL\",\"blocking\":true}")
            has_critical=true
        fi

        # Stage 3: SECURITY (blocking)
        if ! check_security "$file"; then
            results+=("{\"stage\":\"SECURITY\",\"file\":\"$file\",\"status\":\"FAIL\",\"blocking\":true}")
            has_critical=true
        fi

        # Stage 4: CONSISTENCY (advisory)
        if ! check_consistency "$file"; then
            results+=("{\"stage\":\"CONSISTENCY\",\"file\":\"$file\",\"status\":\"WARN\",\"blocking\":false}")
        fi
    done

    echo "${results[@]}"
    if $has_critical; then
        return 1
    fi
    return 0
}

# Check correctness (syntax, logic)
check_correctness() {
    local file="$1"

    # TypeScript/JavaScript
    if [[ "$file" =~ \.(ts|tsx|js|jsx)$ ]]; then
        npx tsc --noEmit "$file" 2>/dev/null
        return $?
    fi

    # Python
    if [[ "$file" =~ \.py$ ]]; then
        python3 -m py_compile "$file" 2>/dev/null
        return $?
    fi

    # Default: assume OK
    return 0
}

# Check quality (types, patterns)
check_quality() {
    local file="$1"

    # Check for console.log
    if grep -q "console\.log\|console\.debug" "$file" 2>/dev/null; then
        return 1
    fi

    # Check for TODO/FIXME
    if grep -q "TODO\|FIXME\|XXX" "$file" 2>/dev/null; then
        return 1
    fi

    return 0
}

# Check security patterns
check_security() {
    local file="$1"

    # Use existing security audit hook
    if [[ -f "$PROJECT_ROOT/.claude/hooks/security-full-audit.sh" ]]; then
        bash "$PROJECT_ROOT/.claude/hooks/security-full-audit.sh" "$file"
        return $?
    fi

    return 0
}

# Check consistency (style)
check_consistency() {
    local file="$1"

    # Use Prettier check
    if command -v prettier &>/dev/null; then
        prettier --check "$file" 2>/dev/null
        return $?
    fi

    return 0
}
```

---

## 6. Configuration Changes

### 6.1 settings.json Updates

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "AGENT_TEAMS_QUALITY_GATES": "enabled",
    "AGENT_TEAMS_BLOCK_ON_SECURITY": "true"
  },
  "hooks": {
    "TeammateIdle": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/teammate-idle-quality-gate.sh",
            "timeout": 120
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/task-completed-quality-gate.sh",
            "timeout": 180
          }
        ]
      }
    ]
  }
}
```

### 6.2 Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `1` | Enable Agent Teams feature |
| `AGENT_TEAMS_QUALITY_GATES` | `enabled` | Enable quality gate hooks |
| `AGENT_TEAMS_BLOCK_ON_SECURITY` | `true` | Block on security failures |
| `AGENT_TEAMS_MAX_RETRIES` | `3` | Max feedback iterations |

---

## 7. Integration with GLM-5 Teammates

### 7.1 Unified Hook Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                 UNIFIED AGENT TEAMS FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Claude Teammate          GLM-5 Teammate                       │
│        │                        │                               │
│        ▼                        ▼                               │
│   TeammateIdle            SubagentStop                          │
│        │                        │                               │
│        └────────────┬───────────┘                               │
│                     │                                           │
│                     ▼                                           │
│          agent-teams-coordinator.sh                             │
│                     │                                           │
│                     ▼                                           │
│          ┌─────────────────────┐                                │
│          │   Quality Checks    │                                │
│          │  - Correctness      │                                │
│          │  - Quality          │                                │
│          │  - Security         │                                │
│          │  - Consistency      │                                │
│          └──────────┬──────────┘                                │
│                     │                                           │
│           ┌────────┴────────┐                                   │
│           │                 │                                   │
│           ▼                 ▼                                   │
│      Exit 0            Exit 2                                   │
│   (Allow idle)    (Block + feedback)                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 Shared State

**File:** `.ralph/agent-teams-status.json`

```json
{
  "activeTeammates": {
    "coder-001": {
      "type": "claude",
      "status": "working",
      "files": ["src/api/auth.ts"],
      "startedAt": "2026-02-14T10:00:00Z"
    },
    "glm5-coder-001": {
      "type": "glm5",
      "status": "idle",
      "files": ["src/services/auth.ts"],
      "completedAt": "2026-02-14T10:30:00Z"
    }
  },
  "qualityResults": {
    "coder-001": {
      "lastCheck": "2026-02-14T10:25:00Z",
      "status": "passed",
      "issues": []
    }
  }
}
```

---

## 8. Testing Strategy

### 8.1 Unit Tests

**Location:** `tests/agent-teams/`

| Test File | Purpose |
|-----------|---------|
| `test-teammate-idle-hook.sh` | Test TeammateIdle hook behavior |
| `test-task-completed-hook.sh` | Test TaskCompleted hook behavior |
| `test-quality-gates.sh` | Test quality check functions |
| `test-exit-codes.sh` | Verify exit code handling |

### 8.2 Integration Tests

| Test | Description |
|------|-------------|
| `test-full-workflow.sh` | End-to-end teammate workflow |
| `test-glm5-integration.sh` | GLM-5 teammate integration |
| `test-feedback-loop.sh` | Exit code 2 feedback loop |

### 8.3 Validation Checklist

```markdown
## Agent Teams Integration Validation

- [ ] TeammateIdle hook triggers correctly
- [ ] Exit 0 allows teammate to idle
- [ ] Exit 2 blocks idle and sends feedback
- [ ] TaskCompleted hook triggers correctly
- [ ] Exit 0 allows task completion
- [ ] Exit 2 prevents completion with feedback
- [ ] GLM-5 SubagentStop unified with TeammateIdle
- [ ] Quality checks run in parallel
- [ ] Security checks block on critical issues
- [ ] Feedback is actionable and clear
```

---

## 9. Documentation Plan

### 9.1 Files to Create

```
docs/agent-teams/
├── README.md                    # Overview and quick start
├── INTEGRATION_GUIDE.md         # Step-by-step setup
├── HOOK_REFERENCE.md            # Hook behavior details
├── QUALITY_GATES.md             # Quality check specifications
├── GLM5_INTEGRATION.md          # GLM-5 teammate integration
├── BEST_PRACTICES.md            # Usage patterns
├── TROUBLESHOOTING.md           # Common issues
└── examples/
    ├── basic-team.json          # Basic team configuration
    ├── quality-focused.json     # Quality-focused team
    └── security-focused.json    # Security-focused team
```

### 9.2 CLAUDE.md Updates

Add to project CLAUDE.md:

```markdown
## Agent Teams Integration (v2.85)

### New Hook Events

| Event | Purpose | Exit Code 2 |
|-------|---------|-------------|
| TeammateIdle | Quality gate when teammate goes idle | Block + feedback |
| TaskCompleted | Quality gate before task completion | Block + feedback |

### Configuration

Agent Teams is enabled via environment variable:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### Quality Gates

Both hooks enforce:
1. CORRECTNESS (blocking) - Syntax, logic
2. QUALITY (blocking) - Types, patterns
3. SECURITY (blocking) - Vulnerabilities
4. CONSISTENCY (advisory) - Style

### See Also

- [Agent Teams Documentation](docs/agent-teams/)
- [Hook Reference](docs/hooks/COMPLETE_HOOKS_REFERENCE.md)
```

---

## 10. Rollout Plan

### Phase 1: Development (Week 1)
- Create hook scripts
- Add configuration to settings.json
- Write unit tests

### Phase 2: Testing (Week 2)
- Run integration tests
- Validate with GLM-5 teammates
- Document findings

### Phase 3: Documentation (Week 2)
- Create docs/agent-teams/ folder
- Write all documentation files
- Update CLAUDE.md

### Phase 4: Release (Week 3)
- Merge to main
- Tag release v2.85.0
- Announce in changelog

---

## 11. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Hook timeout issues | Medium | High | Set appropriate timeouts (120-180s) |
| False positives in quality checks | Medium | Medium | Allow CONSISTENCY to be advisory |
| GLM-5 integration conflicts | Low | High | Unify via coordinator script |
| Performance degradation | Low | Medium | Use parallel async checks |

---

## 12. Success Criteria

1. **Functional Requirements:**
   - [ ] TeammateIdle hook blocks low-quality work
   - [ ] TaskCompleted hook prevents premature completion
   - [ ] Exit code 2 sends actionable feedback
   - [ ] GLM-5 teammates unified with Claude teammates

2. **Quality Requirements:**
   - [ ] All quality gates pass before teammate goes idle
   - [ ] Security issues always block (never advisory)
   - [ ] Feedback is specific and actionable

3. **Documentation Requirements:**
   - [ ] Complete docs/agent-teams/ folder
   - [ ] Updated CLAUDE.md
   - [ ] Updated COMPLETE_HOOKS_REFERENCE.md

---

## 13. Next Steps

1. **IMMEDIATE:** Create hook scripts (teammate-idle-quality-gate.sh, task-completed-quality-gate.sh)
2. **NEXT:** Update settings.json with new hook events
3. **THEN:** Create tests in tests/agent-teams/
4. **FINALLY:** Create documentation in docs/agent-teams/

---

## References

- [Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams)
- [settings.json](/.claude-sneakpeek/zai/config/settings.json)
- [COMPLETE_HOOKS_REFERENCE.md](/docs/hooks/COMPLETE_HOOKS_REFERENCE.md)
- [glm5-subagent-stop.sh](/.claude/hooks/glm5-subagent-stop.sh)
- [quality-gates-v2.sh](/.claude/hooks/quality-gates-v2.sh)
