# Multi-Agent Ralph Loop - Documentation Standards

**Last Updated**: 2026-02-14
**Version**: v2.88.0

## Documentation Organization

All project documentation is organized under the `docs/` directory with a professional folder structure.

## Directory Structure

```
docs/
├── adversarial/              # Adversarial validation system
├── agent-teams/              # Agent Teams integration (v2.88)
├── architecture/             # Architecture diagrams and design docs
│   ├── MULTI_AGENT_SCENARIOS_v2.88.md  # Multi-Agent Scenarios Guide
│   ├── UNIFIED_ARCHITECTURE_v2.88.md   # Canonical Architecture
│   └── SCENARIO_FINAL_DECISIONS_v2.88.md
├── audits/                   # Audit reports and technical debt
├── context-monitoring/       # Context tracking and monitoring
├── examples/                 # Code examples and tutorials
├── git-worktree/             # Git worktree documentation
├── glm-integration/          # Historical provider-integration notes
├── implementation/           # Implementation summaries and plans
├── orchestrator/             # Orchestrator workflow and fixes
├── plans/                    # Implementation plans
├── quality-gates/            # Quality gates and validation
├── retrospective/            # Project retrospectives
├── security/                 # Security audits and fixes
└── CLAUDE.md                 # This file - documentation guidelines
```

## Creating New Documentation

When creating documentation for a new subject:

### 1. Create a New Folder

```bash
mkdir -p docs/subject-name/
```

- Use lowercase with hyphens for multi-word subjects
- Example: `docs/feature-name/`

### 2. Use Descriptive Filenames

| Pattern | Purpose |
|---------|---------|
| `ANALYSIS.md` | Analysis and investigation documents |
| `FIX_SUMMARY.md` | Complete fix summaries |
| `VALIDATION_vX.Y.Z.md` | Validation reports with version numbers |
| `IMPLEMENTATION.md` | Implementation guides |
| `README.md` | Folder overview and navigation |

### 3. Document Template

```markdown
# [Title]

**Date**: YYYY-MM-DD
**Version**: vX.Y.Z
**Status**: [ANALYSIS COMPLETE | FIX REQUIRED | RESOLVED]

## Summary
[Brief description of the document purpose]

## Details
[Main content]

## References
- [Related documentation](../other-folder/file.md)
```

## Language Policy

| Content Type | Language | Notes |
|--------------|----------|-------|
| **Code** | English | Variables, functions, classes, comments |
| **Documentation** | English | All files in `docs/` |
| **Commit Messages** | English | Conventional commits format |
| **Code Comments** | English | Inline documentation |

## Documentation Reorganization (2026-01-28)

### Completed Movements

All documentation files have been reorganized from `.claude/` to appropriate `docs/` folders. Each folder now has a README.md for navigation.

#### New Folders Created

- `docs/adversarial/` - Adversarial validation system documentation
- `docs/glm-integration/` - Historical provider-integration documentation
- `docs/orchestrator/` - Orchestrator workflow and fixes
- `docs/plans/` - Implementation plans
- `docs/quality-gates/` - Quality gates and validation
- `docs/implementation/` - Implementation summaries
- `docs/security/` - Security audits and fixes

#### Files Moved

35 documentation files were moved from `.claude/` to categorized folders in `docs/`. See individual folder READMEs for complete file listings.

### Files Remaining in `.claude/`

- `.claude/CLAUDE.md` - Project instructions (updated with new standards)
- `.claude/progress.md` - Session progress tracking

## Documentation Standards

### Formatting

- Use GitHub Flavored Markdown
- Include tables of contents for longer documents
- Use proper heading hierarchy (H1, H2, H3...)
- Include date and version at the top of each document

### Linking

- Use relative paths for links within `docs/`
- Example: `[Related doc](../context-monitoring/ANALYSIS.md)`
- Use absolute paths for repository root links
- Example: `[Script](../../.claude/hooks/example.sh)`

### Metadata

Each document should include:

```markdown
**Date**: YYYY-MM-DD
**Version**: vX.Y.Z (if applicable)
**Status**: [DRAFT | IN PROGRESS | COMPLETE | DEPRECATED]
**Related**: [links to related documents]
```

## Navigation

- Start here: [Project README](../README.md)
- **NEW** Multi-Agent Scenarios: [docs/architecture/MULTI_AGENT_SCENARIOS_v2.88.md](architecture/MULTI_AGENT_SCENARIOS_v2.88.md)
- Architecture: [docs/architecture/](architecture/)
- Agent Teams: [docs/agent-teams/](agent-teams/)
- Context monitoring: [docs/context-monitoring/](context-monitoring/)
- Quality validation: [docs/quality-gates/](quality-gates/)
- Implementation plans: [docs/plans/](plans/)
- Adversarial system: [docs/adversarial/](adversarial/)
- GLM integration: [docs/glm-integration/](glm-integration/)
- Orchestrator: [docs/orchestrator/](orchestrator/)
- Security: [docs/security/](security/)
- Audits: [docs/audits/](audits/)
- Implementation: [docs/implementation/](implementation/)

## Multi-Agent Scenarios (v2.88.0)

The Ralph system supports three execution scenarios for multi-agent coordination:

| Scenario | Description | Skills |
|----------|-------------|--------|
| **A: Pure Agent Teams** | Native Claude Code teams | clarify, retrospective, glm5-parallel |
| **B: Custom Subagents** | Direct ralph-* spawn | bugs, code-reviewer |
| **C: Integrated** | TeamCreate + ralph-* + hooks | orchestrator, parallel, loop, security, gates, quality-gates-parallel, adversarial |

**Full documentation**: [MULTI_AGENT_SCENARIOS_v2.88.md](architecture/MULTI_AGENT_SCENARIOS_v2.88.md)
