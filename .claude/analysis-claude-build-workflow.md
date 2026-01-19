# Analysis: claude-build-workflow by @rohunjauhar

**Date**: 2026-01-19
**Sources Analyzed**:
- Repository: https://github.com/rohunj/claude-build-workflow
- Tweet: https://x.com/rohunjauhar/status/2012983351288692941
- Related: https://x.com/affaanmustafa/status/2012378465664745795 (BMAD Method context)

---

## Executive Summary

The `claude-build-workflow` is a **complete autonomous development workflow** that combines:
1. **BMAD Method** - Structured discovery and PRD generation
2. **Ralph Loop** - Autonomous iteration (adapted from snarktank/ralph)
3. **Skills System** - Modular, auto-triggered capabilities
4. **Phone Notifications** - True "close laptop" autonomy
5. **Build-Test-Fix Cycle** - Full QA automation

**Key Insight**: This workflow addresses the **complete lifecycle** - from idea to deployed, tested, bug-fixed product - not just the implementation phase.

---

## Key Learnings for /orchestrator v2.48+

### 1. **Structured Discovery Interview (BMAD Method)**

**Current Gap**: Our `/clarify` step asks questions but lacks the structured BMAD methodology.

**BMAD Questions (adopt these)**:
1. Problem & Value: "What specific problem does this solve? What happens if this doesn't exist?"
2. Users: "Who exactly will use this? Be specific."
3. Core Features: "If this could only do 3 things, what would they be?"
4. Success: "How will you know this is working?"
5. Scope: "What should this explicitly NOT do?"

**Action**: Enhance `/clarify` skill to use BMAD-style discovery before technical questions.

```yaml
# Proposed CLARIFY v2 structure:
PHASE_1_DISCOVERY:
  - problem_value  # Why does this need to exist?
  - users          # Who benefits?
  - core_features  # Top 3 capabilities?
  - success_metrics # How to measure success?
  - explicit_scope  # What's OUT of scope?

PHASE_2_TECHNICAL:
  - existing_patterns
  - technology_preferences
  - constraints
```

---

### 2. **User Story Quality Gates (Critical for Autonomous Execution)**

**Key Principle**: Each story must be completable in ONE iteration (one context window).

**Story Quality Checklist** (add to `/orchestrator`):
- [ ] 1-2 lines maximum description
- [ ] "As a [user], I want [feature] so that [benefit]" format
- [ ] Single focused capability (no "and also")
- [ ] Completable in one session
- [ ] Dependencies properly ordered
- [ ] Acceptance criteria are VERIFIABLE (not vague)
- [ ] Always includes "Typecheck passes"
- [ ] UI stories include "Verify in browser"

**Red Flags to Reject**:
- Story longer than 2 lines
- Multiple "and" conjunctions
- Vague criteria like "works correctly"
- Dependencies on later stories

**Action**: Add `story-quality-gate` hook before EXECUTE phase.

---

### 3. **Edge Case Analysis Phase (NEW STEP)**

**Current Gap**: We do gap analysis but not systematic edge case discovery.

**Edge Case Categories to Check**:
1. **Input Edge Cases**: Empty, null, boundary values, unicode, large data
2. **State Edge Cases**: Race conditions, stale data, partial completion
3. **User Behavior**: Rapid clicks, back button, refresh, abandoned flows
4. **Error Handling**: Network failures, validation errors, permission errors
5. **Data Edge Cases**: First-time use, legacy data, cascade deletes
6. **Security Edge Cases**: Session expiry, auth changes, injection attempts
7. **Performance Edge Cases**: Cold start, large payloads, N+1 queries

**Action**: Add EDGE_CASE_ANALYSIS between GAP_ANALYST and PLAN steps.

---

### 4. **Progress.txt Pattern (Session Continuity)**

**Brilliant Concept**: Progress log with **Codebase Patterns** section at TOP.

```markdown
## Codebase Patterns
- Use `sql<number>` template for aggregations
- Always use `IF NOT EXISTS` for migrations
- Export types from actions.ts for UI components

---

## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered
  - Gotchas encountered
  - Useful context
```

**Key Insight**: Patterns are CONSOLIDATED at top so each iteration reads them first.

**Action**: Our `progress.md` should adopt this structure:
- Top section: Consolidated patterns (stable knowledge)
- Body: Chronological progress (transient details)

---

### 5. **Completion Signal Pattern**

**Clean Stop Condition**:
```bash
# Count remaining stories
cat prd.json | jq '[.userStories[] | select(.passes == false)] | length'
```

Only output `<promise>COMPLETE</promise>` if count is 0.

**Current Gap**: Our VERIFIED_DONE is implicit. Consider explicit completion signals.

**Action**: Add explicit completion check to `stop-verification.sh`:
```bash
# Before declaring VERIFIED_DONE, verify:
INCOMPLETE=$(jq '[.steps[] | select(.status != "verified")] | length' .claude/plan-state.json)
if [ "$INCOMPLETE" -gt 0 ]; then
  echo "INCOMPLETE: $INCOMPLETE steps remaining"
  exit 1
fi
echo "<verified>COMPLETE</verified>"
```

---

### 6. **Build-Test-Fix Cycle (Post-Deploy Automation)**

**Current Gap**: Our workflow ends at VERIFIED_DONE. We don't have post-deploy testing.

**Their Cycle**:
```
BUILD (Ralph 50 iter) --> DEPLOY --> TEST (agent-browser) --> BUG REPORT
                                                                    |
                                                                    v
                   <-- RALPH FIX <-- CONVERT TO STORIES <-- PRIORITIZE
```

**Action**: Consider adding optional POST_DEPLOY phase:
1. `/deploy-verify` - Test deployed app
2. `/bugs-to-stories` - Convert findings to stories
3. Re-run orchestrator with bug-fix stories

---

### 7. **Automatic Skill Application (Context-Triggered)**

**Their Pattern**: Skills auto-trigger based on context, NOT manual invocation.

**SKILLS-INDEX.md** defines when each skill fires:
| Project Type | Auto-Apply Skills |
|-------------|-------------------|
| Web App (React/Next.js) | `react-best-practices`, `web-design-guidelines`, `security/*` |
| API/Backend | `security/*` |
| Any with UI | `web-design-guidelines`, `frontend-design` |

**Action**: We already have contextual triggers (v2.35), but should:
1. Make them more aggressive (assume context, don't ask)
2. Add SKILLS-INDEX equivalent for transparency
3. Auto-apply security skills on EVERY code change

---

### 8. **prd.json Schema (Structured Plan Tracking)**

**Their Schema**:
```json
{
  "project": "Project Name",
  "branchName": "ralph/feature-name",
  "description": "Feature description",
  "userStories": [
    {
      "id": "US-001",
      "title": "Story title",
      "description": "As a...",
      "acceptanceCriteria": ["Criterion 1", "Typecheck passes"],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

**vs Our plan-state.json**:
```json
{
  "steps": [
    {
      "id": "1",
      "title": "...",
      "status": "pending|in_progress|completed|verified",
      "spec": {...},
      "actual": {...},
      "drift": {...}
    }
  ]
}
```

**Key Difference**: Their schema is USER-CENTRIC (user stories), ours is IMPLEMENTATION-CENTRIC (steps).

**Action**: Add `userStories` section to plan-state.json that maps to steps:
```json
{
  "userStories": [...],  // User-facing requirements
  "steps": [...]         // Implementation tasks (can map 1:many to stories)
}
```

---

### 9. **Phone Notifications for True Autonomy**

**Their Pattern**: ntfy.sh integration for "close laptop" workflows.

```bash
send_notification() {
  curl -s -d "$message" "ntfy.sh/$NTFY_TOPIC"
}
```

**Events to Notify**:
- Build started
- Build complete
- Build needs attention (errors detected)
- Max iterations reached

**Action**: Add optional ntfy.sh integration:
```bash
ralph config set NTFY_TOPIC my-ralph-builds
ralph orch "task" --notify  # Sends notifications
```

---

### 10. **Security Scanning EVERY Story**

**Their Pattern**: Security is NOT optional, runs on EVERY code change:

```bash
# Before marking any story complete:
semgrep --config=auto --severity=ERROR --severity=WARNING .
gitleaks protect --staged --redact
```

**Action**: Enforce security scanning in `micro-gate`:
```bash
# micro-gate.sh additions:
semgrep --config=auto --severity=ERROR . || exit 1
gitleaks protect --staged || exit 1
```

---

## Proposed v2.48 Enhancements

Based on this analysis, here are concrete additions for `/orchestrator`:

### New Steps

```
0. EVALUATE        (existing)
0b. SMART_MEMORY   (existing v2.47)
1. CLARIFY         (ENHANCED: BMAD-style discovery)
1b. GAP_ANALYST    (existing)
1c. EDGE_CASE_ANALYSIS (NEW: systematic edge case discovery)
1d. PARALLEL_EXPLORE (existing v2.46)
2. CLASSIFY        (existing)
2b. STORY_QUALITY_GATE (NEW: ensure stories are right-sized)
2c. WORKTREE       (existing)
3. PLAN            (existing)
3b. PERSIST        (existing, ENHANCED: prd.json format)
3c. PLAN_STATE     (existing)
... (rest remains same)
8. RETROSPECT      (existing)
8b. POST_DEPLOY    (NEW: optional test-and-fix cycle)
```

### New Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `bmad-discovery.sh` | PreToolUse (AskUserQuestion) | Structure questions as BMAD |
| `edge-case-analysis.sh` | PostToolUse (Write plan) | Auto-analyze for edge cases |
| `story-quality-gate.sh` | PreToolUse (Task - implement) | Verify story is right-sized |
| `security-scan.sh` | PostToolUse (Edit/Write) | semgrep + gitleaks |
| `notify-progress.sh` | PostToolUse (Task complete) | ntfy.sh notifications |

### New Skills

| Skill | Purpose |
|-------|---------|
| `/bmad-interview` | Structured discovery interview |
| `/edge-cases` | Edge case analysis |
| `/story-quality` | User story quality review |
| `/test-and-break` | Post-deploy testing |
| `/bugs-to-stories` | Convert bugs to plan items |

### Configuration Additions

```json
// .claude/settings.local.json
{
  "ralph": {
    "ntfy_topic": "my-ralph-builds",
    "auto_security_scan": true,
    "story_max_lines": 2,
    "edge_case_analysis": true
  }
}
```

---

## Summary: What to Adopt

| Feature | Priority | Effort | Impact |
|---------|----------|--------|--------|
| BMAD Discovery Questions | HIGH | LOW | Better requirements |
| Story Quality Gate | HIGH | MEDIUM | Fewer failed iterations |
| Edge Case Analysis | MEDIUM | MEDIUM | More robust implementations |
| Progress.txt Patterns Section | HIGH | LOW | Better continuity |
| Security Scanning Every Step | HIGH | LOW | Secure by default |
| Post-Deploy Test Cycle | LOW | HIGH | Full lifecycle |
| Phone Notifications | LOW | LOW | True autonomy |

---

## References

- **BMAD Method**: https://github.com/bmad-code-org/BMAD-METHOD
- **Original Ralph**: https://github.com/snarktank/ralph
- **Amp Skills**: https://github.com/snarktank/amp-skills
- **ntfy.sh**: https://ntfy.sh/ (push notifications)
- **agent-browser**: Browser automation for testing
