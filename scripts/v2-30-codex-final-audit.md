# v2.30 Final Codex Validation Audit

You are Codex GPT-5. Perform a comprehensive code review of the v2.30 Context Engineering implementation.

## Audit Scope

Review all files in `~/Documents/claude-audit/v2-30-final/` and validate:

### 1. Skills Validation (10 skills)
For each skill in `skills/*/SKILL.md`:
- [ ] Valid YAML frontmatter (`name:`, `description:`)
- [ ] Complete documentation
- [ ] Quality criteria defined
- [ ] Examples provided
- [ ] No broken references

### 2. Hooks Validation (3 hooks)
For each hook in `*.sh`:
- [ ] Valid bash syntax (`bash -n` passes)
- [ ] Safe error handling (no `set -e` in hooks)
- [ ] Proper file permissions (755)
- [ ] No security vulnerabilities
- [ ] Proper logging

### 3. Commands Validation (4 commands)
For each command in `checkpoint-*.md`:
- [ ] Valid YAML frontmatter
- [ ] Shortcut defined
- [ ] Complete description

### 4. Config Validation
- [ ] `checkpoint-config.json` valid JSON
- [ ] Auto-save enabled by default
- [ ] Reasonable thresholds

### 5. CLAUDE.md Validation
- [ ] Lines < 200 (target: ~110)
- [ ] References to all skills
- [ ] v2.30 features documented
- [ ] No broken links

## Deliverables

Provide a detailed audit report with:

```markdown
# v2.30 Codex Validation Report

## Overall Score: X/10

## Skills Audit (10/10)
| Skill | Status | Score | Issues |
|-------|--------|-------|--------|
| context-monitor | PASS | 100/100 | None |
| ... | ... | ... | ... |

## Hooks Audit (3/3)
| Hook | Status | Score | Issues |
|------|--------|-------|--------|
| context-warning.sh | PASS | 95/100 | None critical |
| ... | ... | ... | ... |

## Commands Audit (4/4)
All commands have valid YAML frontmatter and shortcuts.

## Config Audit
checkpoint-config.json: VALID

## CLAUDE.md Audit
- Lines: 110 (< 200 target)
- Skills referenced: 10/10
- v2.30 features: Documented

## Critical Issues Found
1. [Issue description]
2. [Issue description]

## Recommendations
1. [Recommendation]
2. [Recommendation]

## Final Verdict
[PASS if score >= 8/10 and no critical issues]
```

## Execute

Run the audit and output the complete report.
