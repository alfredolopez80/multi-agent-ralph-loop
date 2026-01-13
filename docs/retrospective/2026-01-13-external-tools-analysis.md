# External Tools Analysis - Retrospective

**Date**: 2026-01-13
**Task**: Analyze planning-with-files and superpowers to identify improvements for multi-agent-ralph-loop
**Complexity**: 6 (Medium - Research and Analysis)
**Models Used**: Claude Opus 4.5

---

## Summary

Analysis of two popular Claude Code workflow tools:
1. **planning-with-files** (OthmanAdi) - Manus-style persistent markdown planning
2. **superpowers** (obra) - Complete software development workflow with TDD

Both tools offer complementary patterns that can enrich multi-agent-ralph-loop.

---

## Analysis: planning-with-files

### Core Concept
Implements the "Context Engineering" pattern that made Manus worth $2B: treating filesystem as persistent memory and context window as volatile RAM.

### Key Features

| Feature | Description | Ralph Equivalent |
|---------|-------------|------------------|
| **3-File Pattern** | task_plan.md + findings.md + progress.md | Ledger + Handoff system |
| **2-Action Rule** | Save findings after every 2 operations | No direct equivalent |
| **PreToolUse Hook** | Re-read plan before major decisions | Partial (PostToolUse only) |
| **Stop Hook** | Verify completion before stopping | No direct equivalent |
| **Error Logging** | Track failures to avoid repetition | No direct equivalent |

### What Ralph Could Adopt

1. **The 2-Action Rule**
   - Current: No intermediate save triggers
   - Proposed: Auto-save context after N tool uses (configurable)
   - Impact: HIGH - Prevents context loss mid-task

2. **PreToolUse Plan Re-read Hook**
   - Current: Only PostToolUse hooks
   - Proposed: Add PreToolUse hook to re-read plan before critical operations
   - Impact: MEDIUM - Reduces goal drift

3. **Dedicated Findings File**
   - Current: Everything goes to ledger
   - Proposed: Separate research findings from execution state
   - Impact: MEDIUM - Better context organization

4. **Stop Hook Verification**
   - Current: VERIFIED_DONE is manual
   - Proposed: Automatic completion checklist before Stop
   - Impact: HIGH - Ensures true completion

---

## Analysis: superpowers

### Core Concept
Complete workflow orchestration with emphasis on TDD, Socratic design refinement, and subagent-driven development with two-stage code review.

### Key Features

| Feature | Description | Ralph Equivalent |
|---------|-------------|------------------|
| **Brainstorming Phase** | Socratic questioning before design | /clarify (partial) |
| **Two-Stage Review** | Spec compliance THEN code quality | Single-stage /adversarial |
| **RED-GREEN-REFACTOR** | Strict TDD enforcement | Not enforced |
| **Subagent-Driven Dev** | Fresh subagent per task | Task() subagents |
| **Systematic Debugging** | 4-phase root cause process | Not specified |
| **3-Fix Rule** | Stop after 3 failed fixes | Not enforced |
| **Plan Document Format** | 2-5 min tasks with exact code | Higher-level plans |

### What Ralph Could Adopt

1. **Two-Stage Code Review**
   - Current: Single adversarial validation
   - Proposed: Stage 1 (spec compliance) -> Stage 2 (code quality)
   - Impact: HIGH - Catches more issues, clearer feedback

2. **Strict TDD Enforcement**
   - Current: Testing is recommended but not enforced
   - Proposed: Add TDD skill with "delete code written before tests" rule
   - Impact: HIGH - Better code quality

3. **Systematic Debugging Skill**
   - Current: No structured debugging approach
   - Proposed: 4-phase mandatory debugging (root cause -> patterns -> hypothesis -> fix)
   - Impact: HIGH - 95% first-time fix rate vs 40% ad-hoc

4. **The 3-Fix Rule**
   - Current: Unlimited fix attempts
   - Proposed: After 3 failed fixes, escalate to user (architectural issue)
   - Impact: MEDIUM - Prevents endless loops

5. **Granular Task Format**
   - Current: High-level plans
   - Proposed: 2-5 minute tasks with exact file paths and code
   - Impact: MEDIUM - Better subagent execution

6. **Brainstorming Skill Enhancement**
   - Current: /clarify focuses on requirements
   - Proposed: Add Socratic design exploration (2-3 alternatives with trade-offs)
   - Impact: MEDIUM - Better architecture decisions

---

## Comparative Matrix

| Capability | Ralph | planning-with-files | superpowers |
|------------|-------|---------------------|-------------|
| Persistent Planning | Ledger/Handoff | 3-file pattern | docs/plans/ |
| Context Preservation | 100% automatic | Hooks + files | Files only |
| Multi-Model Routing | Yes (complexity) | No | No |
| Subagent Orchestration | Yes | No | Yes (fresh per task) |
| TDD Enforcement | No | No | Yes (strict) |
| Two-Stage Review | No | No | Yes |
| Systematic Debugging | No | No | Yes (4-phase) |
| Quality Gates | 9 languages | No | TDD verification |
| Adversarial Validation | 2/3 consensus | No | No |
| Goal Drift Prevention | Implicit | PreToolUse hook | Scene-setting context |
| Error Tracking | No | Yes (logs) | No |
| Stop Verification | No | Stop hook | No |

---

## Proposed Improvements

### High Priority

```json
{
  "type": "agent_behavior",
  "file": "~/.claude/skills/tdd-enforcement/SKILL.md",
  "change": "Create TDD enforcement skill with RED-GREEN-REFACTOR cycle",
  "justification": "95% first-time fix rate with systematic TDD vs 40% ad-hoc"
}
```

```json
{
  "type": "quality_gate",
  "file": "~/.claude/skills/gates/SKILL.md",
  "change": "Add two-stage review: spec compliance THEN code quality",
  "justification": "Catches specification violations before code quality review"
}
```

```json
{
  "type": "new_command",
  "file": "~/.claude/skills/systematic-debugging/SKILL.md",
  "change": "Add systematic-debugging skill with 4-phase process and 3-fix rule",
  "justification": "Structured debugging prevents endless fix loops"
}
```

### Medium Priority

```json
{
  "type": "clarification_enhancement",
  "file": "~/.claude/skills/clarify/SKILL.md",
  "change": "Add Socratic design exploration with 2-3 alternatives and trade-offs",
  "justification": "Better architecture decisions through structured exploration"
}
```

```json
{
  "type": "routing_adjustment",
  "file": "~/.claude/CLAUDE.md",
  "change": "Add 2-Action Rule: auto-save context after N tool uses",
  "justification": "Prevents context loss during long tasks"
}
```

```json
{
  "type": "quality_gate",
  "file": "~/.claude/hooks/stop-verification.sh",
  "change": "Add Stop hook to verify completion checklist before session end",
  "justification": "Ensures true completion, not assumed completion"
}
```

### Low Priority

```json
{
  "type": "agent_behavior",
  "file": "~/.ralph/config.yaml",
  "change": "Separate findings.md from ledger for research context",
  "justification": "Better organization of research vs execution state"
}
```

---

## Implementation Roadmap

### Phase 1 (Immediate)
1. Create `systematic-debugging` skill
2. Add TDD enforcement to existing workflow
3. Implement 3-fix rule in Ralph Loop

### Phase 2 (Short-term)
1. Add two-stage review to /adversarial
2. Enhance /clarify with Socratic exploration
3. Create Stop hook for verification

### Phase 3 (Medium-term)
1. Implement 2-Action Rule
2. Separate findings from ledger
3. Add PreToolUse plan re-read hook

---

## What Went Well

- Multi-model routing (unique to Ralph) - neither tool has this
- Context preservation is more automatic than both tools
- Quality gates cover more languages than superpowers
- Adversarial validation with consensus is unique

## Improvement Opportunities

1. **TDD Enforcement**: HIGH impact, prevents broken code from accumulating
   - Current: Not enforced
   - Proposed: Create skill with strict RED-GREEN-REFACTOR
   - Risk: LOW (additive change)

2. **Two-Stage Review**: HIGH impact, better issue categorization
   - Current: Single-pass adversarial
   - Proposed: Spec compliance -> Code quality
   - Risk: LOW (additive change)

3. **Systematic Debugging**: HIGH impact, better fix rate
   - Current: Ad-hoc debugging
   - Proposed: 4-phase mandatory process
   - Risk: LOW (additive change)

4. **Stop Verification**: MEDIUM impact, ensures completion
   - Current: Manual VERIFIED_DONE
   - Proposed: Automatic checklist hook
   - Risk: LOW (additive change)

---

## Conclusion

Both tools offer valuable patterns that complement Ralph's existing strengths:

- **planning-with-files** excels at context persistence and goal tracking
- **superpowers** excels at development discipline (TDD, debugging, reviews)
- **Ralph** excels at multi-model orchestration and automatic context preservation

The recommended integrations focus on development discipline from superpowers (TDD, systematic debugging, two-stage review) and goal tracking from planning-with-files (Stop hook, 2-action rule).

**Recommended Next Steps**:
1. Create `systematic-debugging` skill (HIGH priority)
2. Create `test-driven-development` skill (HIGH priority)
3. Enhance `/adversarial` with two-stage review (HIGH priority)
4. Add Stop hook verification (MEDIUM priority)

---

*Generated via /orchestrator analysis task*

---

## Implementation Status (v2.42)

**Implemented: 2026-01-13**

### Completed Changes

| # | Mejora | Estado | Archivo |
|---|--------|--------|---------|
| 1 | Stop Hook Verification | ✅ | `~/.claude/hooks/stop-verification.sh` |
| 2 | 2-Action Rule (auto-save) | ✅ | `~/.claude/hooks/auto-save-context.sh` |
| 3 | Two-Stage Review | ✅ | `~/.claude/skills/adversarial/SKILL.md` |
| 4 | 3-Fix Rule Enforcement | ✅ | `~/.claude/skills/systematic-debugging/SKILL.md` |
| 5 | Socratic Design Exploration | ✅ | `~/.claude/skills/deep-clarification.md` |

### Hooks Registered

- **Stop Event:** `stop-verification.sh` (antes de `sentry-report.sh`)
- **PostToolUse Event:** `auto-save-context.sh` (Edit|Write|Bash|Read|Grep|Glob)

### Verification

```bash
# Stop hook test
echo '{}' | ~/.claude/hooks/stop-verification.sh
# Output: STOP_VERIFICATION: All 4 checks passed

# Auto-save hook test
echo '{}' | ~/.claude/hooks/auto-save-context.sh
# Output: (silent unless interval reached)
```

### Configuration

- Auto-save interval: 5 operations (configurable via `RALPH_AUTO_SAVE_INTERVAL`)
- Context snapshots: `~/.ralph/state/context-snapshot-*.md` (keeps last 10)
