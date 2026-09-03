# Commands to Skills Migration Guide

> Historical record. Model/provider names below describe the state at the time of writing; the current rule is that the model is whatever the session runs.

**Date**: 2026-02-14
**Version**: v2.88.0
**Status**: MIGRATION PLAN

## Overview

As of v2.87, commands and skills have been unified into a single `SKILL.md` format. The `.claude/commands/` directory is deprecated and all commands should be migrated to the skills format.

## Current State

### Commands Directory (28 files)

The following files exist in `.claude/commands/` and need migration:

| Command | Status | Migration Path |
|---------|--------|----------------|
| `bug.md` | ✅ Duplicate | Already exists as `skills/bugs/` |
| `docs.md` | 🔄 Migrate | Create `skills/docs/` |
| `research.md` | 🔄 Migrate | Create `skills/research/` |
| `diagram.md` | 🔄 Migrate | Create `skills/diagram/` |
| `plan.md` | 🔄 Migrate | Create `skills/plan/` |
| `refactor.md` | 🔄 Migrate | Create `skills/refactor/` |
| `repo-learn.md` | 🔄 Migrate | Create `skills/repo-learn/` |
| `unit-tests.md` | 🔄 Migrate | Create `skills/unit-tests/` |
| `full-review.md` | 🔄 Migrate | Create `skills/full-review/` |
| `improvements.md` | 🔄 Migrate | Create `skills/improvements/` |
| `security-loop.md` | 🔄 Migrate | Create `skills/security-loop/` |
| `skill.md` | 🔄 Migrate | Create `skills/skill/` |
| `codex-plan.md` | 🔄 Migrate | Create `skills/codex-plan/` |
| `prd.md` | 🔄 Migrate | Create `skills/prd/` |
| `library-docs.md` | 🔄 Migrate | Create `skills/library-docs/` |
| `minimax-search.md` | 🔄 Migrate | Create `skills/minimax-search/` |
| `ast-search.md` | 🔄 Migrate | Create `skills/ast-search/` |
| `image-analyze.md` | 🔄 Migrate | Create `skills/image-analyze/` |
| `image-to-3d.md` | ❌ Remove | Blender-specific, not needed |
| `blender-3d.md` | ❌ Remove | Blender-specific, not needed |
| `blender-status.md` | ❌ Remove | Blender-specific, not needed |
| `browse.md` | 🔄 Migrate | Create `skills/browse/` |
| `checkpoint-save.md` | 🔄 Migrate | Create `skills/checkpoint/` |
| `checkpoint-restore.md` | 🔄 Migrate | Merge into `skills/checkpoint/` |
| `checkpoint-list.md` | 🔄 Migrate | Merge into `skills/checkpoint/` |
| `checkpoint-clear.md` | 🔄 Migrate | Merge into `skills/checkpoint/` |
| `commands.md` | ❌ Remove | Meta-command, not needed |
| `CLAUDE.md` | ❌ Remove | Documentation, not a command |

## Migration Process

### Step 1: Convert Command to SKILL.md Format

Old command format (`.claude/commands/bug.md`):
```markdown
# Bug Hunting

Description of bug hunting...
```

New skill format (`.claude/skills/bugs/SKILL.md`):
```markdown
---
# VERSION: 2.88.0
name: bugs
description: "Systematic bug hunting with Codex CLI..."
argument-hint: "<file or directory>"
user-invocable: true
allowed-tools:
  - Read
  - Bash
---

# Bug Hunting (v2.88)

## v2.88 Key Changes (MODEL-AGNOSTIC)

- **Model-agnostic**: Uses model configured in `~/.claude/settings.json`
...

Description of bug hunting...
```

### Step 2: Create Skill Directory Structure

```bash
mkdir -p .claude/skills/command-name
mv .claude/commands/command-name.md .claude/skills/command-name/SKILL.md
```

### Step 3: Add Frontmatter

Add YAML frontmatter with:
- `# VERSION: 2.88.0`
- `name: skill-name`
- `description: "When to use this skill"`
- `argument-hint: "<expected args>"`
- `user-invocable: true`
- `allowed-tools: [...]` (if needed)

### Step 4: Add Model-Agnostic Section

After the first heading, add:
```markdown
## v2.88 Key Changes (MODEL-AGNOSTIC)

- **Model-agnostic**: Uses model configured in `~/.claude/settings.json` or CLI/env vars
- **No flags required**: Works with the configured default model
- **Flexible**: Works with GLM-5, Claude, Minimax, or any configured model
- **Settings-driven**: Model selection via `ANTHROPIC_DEFAULT_*_MODEL` env vars
```

### Step 5: Remove Old Command

```bash
rm .claude/commands/command-name.md
```

## Migration Script

```bash
#!/bin/bash
# migrate-commands-to-skills.sh

COMMANDS_DIR=".claude/commands"
SKILLS_DIR=".claude/skills"

# Commands to migrate (name -> skill_name)
declare -A MIGRATIONS=(
    ["docs"]="docs"
    ["research"]="research"
    ["diagram"]="diagram"
    ["plan"]="plan"
    ["refactor"]="refactor"
    ["repo-learn"]="repo-learn"
    ["unit-tests"]="unit-tests"
    ["full-review"]="full-review"
)

for cmd in "${!MIGRATIONS[@]}"; do
    skill="${MIGRATIONS[$cmd]}"
    src="$COMMANDS_DIR/${cmd}.md"
    dst="$SKILLS_DIR/$skill/SKILL.md"

    if [[ -f "$src" ]]; then
        mkdir -p "$(dirname "$dst")"
        echo "Migrating $cmd -> $skill"
        # Migration logic here
    fi
done
```

## Skills to Keep Model-Specific

The following skills should remain at v2.87.0 and NOT be made model-agnostic:

| Skill | Reason |
|-------|--------|
| `glm5` | GLM-5 specific evaluation |
| `glm5-parallel` | GLM-5 parallel execution |
| `minimax` | Minimax specific |
| `minimax-mcp-usage` | Minimax MCP |
| `glm-mcp` | GLM MCP integration |

These are used for specific model evaluation and testing.

## Post-Migration Validation

After migration, run:

```bash
# Check all skills have proper frontmatter
for skill in .claude/skills/*/SKILL.md; do
    echo "Checking $skill"
    grep -q "^# VERSION:" "$skill" || echo "  Missing VERSION"
    grep -q "^name:" "$skill" || echo "  Missing name"
    grep -q "^description:" "$skill" || echo "  Missing description"
done

# Verify no broken symlinks
find ~/.claude/skills -xtype l -delete

# Run skills unification test
./tests/unit/test-skills-unification-v2.87.sh --verbose
```

## Timeline

| Phase | Tasks | Status |
|-------|-------|--------|
| Phase 1 | Update core skills to v2.88 | ✅ Complete |
| Phase 2 | Update auxiliary skills to v2.88 | 🔄 In Progress |
| Phase 3 | Migrate high-priority commands | ⏳ Pending |
| Phase 4 | Migrate remaining commands | ⏳ Pending |
| Phase 5 | Remove deprecated commands | ⏳ Pending |
| Phase 6 | Update documentation | ⏳ Pending |

## References

- [Unified Architecture v2.88](./UNIFIED_ARCHITECTURE_v2.88.md)
- [Skills/Commands Unification v2.87](./SKILLS_COMMANDS_UNIFICATION_v2.87.md)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
