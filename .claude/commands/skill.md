---
name: skill
prefix: "@skill"
category: tools
color: green
description: "YAML-based skills system for lightweight skill management (H70-inspired, +36.7pts improvement)"
---

# /skill

Manage YAML-based skills following the H70 architecture pattern that achieved 94.5% average performance vs 57.8% baseline (+36.7 points improvement).

## Overview

The skills system provides a lightweight, YAML-based architecture for creating specialized AI capabilities. Each skill consists of 4 files defining identity, gotchas, validations, and collaboration rules.

## When to Use

- Creating new specialized skills for domain-specific tasks
- Validating skill structure and patterns before execution
- Listing available skills in your workflow
- Implementing H70-style lightweight agents

## Skill Architecture

Each skill follows a 4-file structure in `~/.ralph/skills/<skill-name>/`:

| File | Purpose | Content |
|------|---------|---------|
| **skill.yaml** | Identity & config | name, triggers, execution phases, metrics |
| **sharp-edges.yaml** | Gotchas & mitigations | Detection patterns for common pitfalls |
| **validations.yaml** | Quality checks | Regex-based pattern validation rules |
| **collaboration.yaml** | Inter-skill coordination | Delegation rules and workflows |

## Available Commands

### Create New Skill

```bash
ralph skill create api-security
ralph skill create performance-tuning
```

Creates a new skill directory with template files at `~/.ralph/skills/<name>/`.

### Validate Skill

```bash
ralph skill validate security-hardening
```

Runs comprehensive validation:
- YAML syntax checking
- Required fields validation
- Regex pattern compilation
- File reference verification

### List Skills

```bash
ralph skill list
```

Shows all available skills with versions and categories.

### Get Help

```bash
ralph skill help
```

Displays full documentation with examples.

## Task Tool Invocation

```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"
  run_in_background: true
  description: "Creating new skill"
  prompt: |
    Create a new YAML-based skill for API security auditing:

    cd ~/.ralph/skills && ralph skill create api-security

    Then customize the 4 YAML files:
    1. skill.yaml - Add triggers for API patterns
    2. sharp-edges.yaml - Document breaking changes
    3. validations.yaml - Add security validation rules
    4. collaboration.yaml - Define delegation to test-automation

    Validate when complete: ralph skill validate api-security
```

## Example: Security Hardening Skill

The included `security-hardening` skill demonstrates the architecture:

**skill.yaml**
```yaml
name: security-hardening
version: 1.0.0
category: security
triggers:
  keywords: [security, auth, vulnerability, injection]
  file_patterns: ["**/*auth*.{py,js,ts}"]
execution:
  phases: [scan, analyze, fix, verify]
  require_approval: true
```

**sharp-edges.yaml**
```yaml
sharp_edges:
  - id: SE001
    title: "Breaking Changes in Authentication"
    severity: high
    mitigation:
      - Check for existing API consumers
      - Add grace period with warnings
```

**validations.yaml**
```yaml
validations:
  - id: V001
    name: "No Raw SQL Queries"
    severity: critical
    pattern:
      regex: '(execute|query).*\%s'
```

**collaboration.yaml**
```yaml
delegation:
  - skill: test-automation
    when: ["Changes applied and need testing"]
    context_to_share: [affected_files]
```

## CLI Execution Examples

```bash
# Create a new skill
ralph skill create database-optimization

# Edit the 4 YAML files
code ~/.ralph/skills/database-optimization/

# Validate structure
ralph skill validate database-optimization

# List all skills
ralph skill list
```

## Validation Hook

The `skill-validator.sh` hook automatically runs before skill execution:

```bash
# Triggered on PreToolUse/Skill
~/.claude/hooks/skill-validator.sh

# Validates:
- YAML syntax
- Required fields (name, version, role, triggers)
- Regex pattern compilation
- File references integrity
```

## H70 Architecture Benefits

| Metric | Result |
|--------|--------|
| **Performance** | 94.5% avg vs 57.8% baseline |
| **Improvement** | +36.7 points |
| **Token Usage** | Minimal (lightweight YAML) |
| **Validation** | Automated regex-based checks |
| **Collaboration** | Inter-skill delegation rules |

## Related Commands

- `/orchestrator` - Full workflow (can load skills dynamically)
- `/gates` - Quality validation (used by skills)
- `/loop` - Iterative execution (applies skill patterns)
- `ralph integrations` - Check tool availability

## Integration with Ralph Loop

Skills integrate at execution phase:

```
1. /clarify     → Intensive questions
2. /classify    → Complexity routing
3. PLAN         → User approval
4. Load Skill   → ralph skill validate <name> ← VALIDATION
5. Execute      → Apply skill phases (scan→analyze→fix→verify)
6. /gates       → Quality validation
7. /adversarial → adversarial-spec refinement (if critical)
→ VERIFIED_DONE
```

## Extended Iteration Limits (v2.32)

Skills benefit from extended iterations:
- Claude: **25 iterations** (+10 from v2.31)
- MiniMax: **50 iterations** (+20 from v2.31)
- Lightning: **100 iterations** (+40 from v2.31)

## Example Workflow

```bash
# 1. Create skill for API security
ralph skill create api-security

# 2. Customize YAML files
# Edit ~/.ralph/skills/api-security/*.yaml

# 3. Validate structure
ralph skill validate api-security
# ✅ All validation checks passed

# 4. Use in Claude Code
# Skills are automatically discovered by orchestrator
# or invoke explicitly: ralph skill validate api-security
```

## Best Practices

1. **Start with Templates** - Use `ralph skill create` for consistency
2. **Validate Early** - Run `ralph skill validate` during development
3. **Document Sharp Edges** - Capture gotchas as you discover them
4. **Define Validations** - Add regex patterns for quality checks
5. **Enable Collaboration** - Define delegation rules for multi-skill workflows

## Troubleshooting

**Validation Fails:**
```bash
# Check YAML syntax
python3 -c "import yaml; yaml.safe_load(open('skill.yaml'))"

# View validation log
cat ~/.ralph/skill-validation.log
```

**Missing Validator:**
```bash
# Ensure hook is executable
chmod +x ~/.claude/hooks/skill-validator.sh

# Test manually
echo '{"skill": "security-hardening"}' | ~/.claude/hooks/skill-validator.sh
```

## References

- Based on: [Meta Alchemist H70 Claude Skills](https://x.com/meta_alchemist/status/2008837751756705869)
- Benchmark: 94.5% vs 57.8% baseline (+36.7 pts)
- Architecture: 4-file YAML structure
- Validation: Automated with skill-validator.sh hook
