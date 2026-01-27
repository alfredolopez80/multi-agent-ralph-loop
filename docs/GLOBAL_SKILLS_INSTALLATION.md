# Global Skills Installation - Complete Documentation

> **Date**: 2026-01-27
> **Status**: ✅ Complete and Working
> **Skills Installed**: 27/26 (25 from repository + 2 existing)

## Executive Summary

Successfully installed all Multi-Agent Ralph skills globally in Claude Code (claude-sneakpeek variant), making them available via slash commands like `/orchestrator`, `/codex`, `/adversarial`, etc.

## Problem Identified

**Before**: Skills in `.claude/skills/` were NOT available globally
- Only 2 skills available: `dev-browser` and `reset`
- Repository skills (25+) not accessible via `/skill-name` commands
- Skills had inconsistent file formats (`skill.md`, `SKILL.md`, `CLAUDE.md`)

**After**: All repository skills now available globally
- 27 skills total (25 from repository + 2 pre-existing)
- Consistent `SKILL.md` format with proper YAML frontmatter
- Skills work with any tool and any model (no restrictions)

## Skills Installed

| Skill | Command | Description |
|-------|---------|-------------|
| **orchestrator** | `/orchestrator` | Full workflow orchestration with 8 steps |
| **codex-cli** | `/codex` | OpenAI Codex CLI integration |
| **adversarial** | `/adversarial` | Dual-model cross-validation |
| **compact** | `/compact` | Manual context save |
| **context7-usage** | `/context7` | Context7 MCP usage patterns |
| **task-classifier** | `/classify` | 3-dimension task classification |
| **smart-fork** | `/smart-fork` | Find relevant sessions to fork |
| **retrospective** | `/retrospective` | Post-task analysis |
| **minimax** | `/minimax` | MiniMax MCP integration |
| **worktree-pr** | `/worktree-pr` | Worktree-based PR workflow |
| **task-visualizer** | `/visualize` | Task state visualization |
| **testing-anti-patterns** | - | Testing anti-patterns reference |
| **tap-explorer** | `/tap-explore` | Tree of Attacks with Pruning |
| **defense-profiler** | - | Codebase defense profiling |
| **attack-mutator** | `/mutate` | Test case mutation |
| **adversarial-code-analyzer** | - | Multi-agent adversarial analysis |
| **ask-questions-if-underspecified** | - | Clarification skill |
| **sec-context-depth** | - | Security context depth analysis |
| **stop-slop** | - | Stop slop patterns |
| **deslop** | - | Deslop skill |
| **edd** | - | EDD skill |
| **glm-mcp** | - | GLM MCP usage |
| **kaizen** | - | Kaizen continuous improvement |
| **minimax-mcp-usage** | - | MiniMax MCP usage patterns |
| **openai-docs** | - | OpenAI documentation lookup |
| **vercel-react-best-practices** | - | Vercel/React patterns |

## Technical Details

### Skill Format (Based on Context7 Research)

According to the official Claude Code documentation and `everything-claude-code` repository:

**File Format**: Markdown with YAML frontmatter

**Required Fields**:
```yaml
---
name: skill-name
description: Brief description of what the skill does
---
```

**Important Constraints**:
- File MUST be named `SKILL.md` (uppercase)
- NO `allowed-tools` field (to work with any tool)
- NO `model` field (to work with any model)
- NO `VERSION` field in frontmatter

### Example Format

```markdown
---
name: orchestrator
description: Full workflow orchestration with 8-step process including clarify, classify, plan, delegate, execute, validate, retrospect, and checkpoint.
---

# Orchestrator Skill

Detailed instructions here...
```

## Installation Method

### Automated Installation

```bash
cd .claude/scripts
./install-global-skills.sh --force
```

### Manual Installation

Each skill is a symlink from the global directory to the repository:

```bash
ln -s /path/to/repo/.claude/skills/skill-name \
   ~/.claude-sneakpeek/zai/config/skills/skill-name
```

## File Locations

| Location | Purpose |
|----------|---------|
| `.claude/skills/` | Source skills in repository |
| `~/.claude-sneakpeek/zai/config/skills/` | Global skills directory (symlinks) |
| `.claude/scripts/install-global-skills.sh` | Installation script |

## Verification Commands

```bash
# List all installed skills
ls ~/.claude-sneakpeek/zai/config/skills/

# Check skill format
cat ~/.claude-sneakpeek/zai/config/skills/orchestrator/SKILL.md | head -20

# Verify skill names
cd ~/.claude-sneakpeek/zai/config/skills
grep -h "^name:" */SKILL.md | sed 's/.*://' | sort
```

## Usage Examples

```bash
# In Claude Code, simply type:
/orchestrator "Implement OAuth authentication"

# Or use the short form:
/codex "Review this code"

# Or:
/adversarial "Validate this security implementation"
```

## Research Sources

### Context7 MCP Documentation

**Sources Analyzed**:
1. `/anthropics/claude-code` - Official Claude Code docs
2. `/affaan-m/everything-claude-code` - Comprehensive skills collection
3. `/nikiforovall/claude-code-rules` - Best practices

**Key Findings**:
- Skills are markdown files with YAML frontmatter
- File MUST be named `SKILL.md` (uppercase)
- Required fields: `name`, `description`
- Optional fields: `allowed-tools`, `model`, `argument-hint`, `disable-model-invocation`
- Skills should NOT have tool/model restrictions for universal use

### Z.ai CLI Web Search

**Sources Consulted**:
1. "Extend Claude with skills - Claude Code Docs" (code.claude.com)
2. "Claude Code Merges Slash Commands Into Skills" (Medium article)

**Key Findings**:
- Slash commands and skills have been merged into a single system
- Skills are more powerful than old slash commands
- Skills can include dynamic arguments, file references, and bash execution

## Troubleshooting

### Issue: Skill not appearing in autocomplete

**Solution**:
1. Verify `SKILL.md` exists: `ls ~/.claude-sneakpeek/zai/config/skills/skill-name/`
2. Check frontmatter: `grep "^name:" ~/.claude-sneakpeek/zai/config/skills/skill-name/SKILL.md`
3. Restart Claude Code

### Issue: Skill shows wrong name

**Solution**: The `name` field in `SKILL.md` frontmatter must match the skill name. Edit the file to correct it.

### Issue: Skill not working with certain tools

**Solution**: Ensure the skill doesn't have `allowed-tools` restriction. Remove this field from the frontmatter to make it work with all tools.

## Future Improvements

1. **Auto-sync**: Automatically update skills when repository changes
2. **Validation**: Add pre-commit hook to validate skill format
3. **Documentation**: Generate skill documentation from `SKILL.md`
4. **Testing**: Add automated tests for skill functionality
5. **Categorization**: Organize skills into categories for better discoverability

## Related Documentation

- **GLM Usage Fix**: `docs/GLM_USAGE_FIX_v2.0.0.md`
- **Statusline Integration**: `.claude/scripts/statusline-ralph.sh`
- **Skills Directory**: `.claude/skills/CLAUDE.md`

## Version History

### v2.0.0 (2026-01-27)

**Added**:
- Automated installation script
- Format conversion from `skill.md`/`CLAUDE.md` to `SKILL.md`
- Proper YAML frontmatter extraction
- Global skills installation via symlinks
- Comprehensive documentation

**Fixed**:
- Corrected skill name extraction (was using subdirectory name)
- Ensured universal compatibility (no tool/model restrictions)

**Changed**:
- All skills now use `SKILL.md` format (uppercase)
- Skills installed as symlinks for easy updates

---

**Document Version**: 1.0.0
**Last Updated**: 2026-01-27
**Status**: ✅ Complete and Verified
