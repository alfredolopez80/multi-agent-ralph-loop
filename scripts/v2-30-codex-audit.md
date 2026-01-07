# v2.30 Context Engineering - Codex Validation Audit

You are Claude Code's validation agent. Perform a comprehensive audit of the v2.30 Context Engineering implementation.

## Audit Scope

Review all files in the `~/Documents/claude-audit/v2-30/` directory and verify:

### 1. Context Monitoring Hook (Fase 1)
- [ ] `context-monitor/SKILL.md` - Valid YAML frontmatter, quality criteria defined
- [ ] `context-monitor/README.md` - Complete documentation
- [ ] `context-warning.sh` - Valid bash script, safe operations, proper error handling

### 2. Auto-Checkpointing (Fase 2)
- [ ] `checkpoint-manager/SKILL.md` - Complete checkpoint format defined
- [ ] All 4 checkpoint commands exist (`checkpoint-save.md`, `checkpoint-list.md`, `checkpoint-restore.md`, `checkpoint-clear.md`)
- [ ] Hook integration documented

### 3. CLAUDE.md Split (Fase 3)
- [ ] `CLAUDE.md` reduced to <200 lines (goal: 70% reduction from 285)
- [ ] `ralph-loop-pattern/SKILL.md` - Loop pattern documented
- [ ] `model-selection/SKILL.md` - Model configuration
- [ ] `tool-selection/SKILL.md` - Tool matrix
- [ ] `workflow-patterns/SKILL.md` - CC + Codex patterns
- [ ] `security-patterns/SKILL.md` - Security functions

### 4. System Reminders (Fase 4)
- [ ] `system-reminders/SKILL.md` - Manus pattern documented
- [ ] `periodic-reminder.sh` - Hook script functional

### 5. Fresh Context Explorer (Fase 5)
- [ ] `fresh-context-explorer/SKILL.md` - Fresh context pattern documented

### 6. Esc+Esc Documentation (Fase 6)
- [ ] `CLAUDE.md` contains Esc+Esc documentation
- [ ] Checkpoint commands documented

### 7. CC + Codex Workflow (Fase 7)
- [ ] `cc-codex-workflow/SKILL.md` - Dual-agent pattern complete

## Validation Criteria

For each skill file:
1. Valid YAML frontmatter with `name` and `description`
2. Clear documentation with examples
3. No broken links or missing references
4. Consistent formatting

For each hook script:
1. Valid bash syntax (`bash -n` check)
2. No `set -e` in non-blocking hooks
3. Safe file operations with error handling
4. Proper variable quoting

## Output Format

```markdown
# v2.30 Validation Results - [PASS|FAIL|PARTIAL]

## Overall Score: X/10

## Phase-by-Phase Results

### Fase 1: Context Monitoring
- Status: [PASS|FAIL]
- Files: X/Y found
- Quality Score: X/100
- Notes: ...

### Fase 2: Auto-Checkpointing
- ...

## Critical Issues Found
1. [Issue description]
2. [Issue description]

## Recommendations
1. [Recommendation]
2. [Recommendation]

## Final Verdict
[PASS if all critical issues resolved]
```

## Execute Audit

Run the validation and output results in the specified format.
