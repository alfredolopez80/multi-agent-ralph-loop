# Multi-Agent Ralph Loop - Project Instructions

> **Documentation Standards**: All development documentation is in English and stored in the `docs/` directory.

## Project-Specific Patterns

### Test File Locations

**DO**:
- Place tests in `tests/` at project root
- Use descriptive test names: `test-quality-parallel-v3-robust.sh`
- Document test purpose in header comments

**DON'T**:
- Place tests in `.claude/tests/` (legacy location, deprecated)
- Mix test types without clear categorization

**Rationale**: Tests at project root are more discoverable and follow standard conventions. The `.claude/tests/` location was legacy and has been migrated to `tests/` as of v2.81.0.

### Test Organization Structure

```
tests/
├── quality-parallel/         # Quality gate validation tests
│   ├── test-quality-parallel-v3-robust.sh
│   ├── test-quality-parallel-v4-final.sh
│   └── README.md
├── swarm-mode/               # Swarm mode integration tests
│   ├── test-swarm-mode-config.sh
│   ├── configure-swarm-mode.sh
│   └── README.md
└── unit/                     # Unit tests (Python, JS, etc.)
```

### Documentation Creation Pattern

When creating new documentation:

1. **Create folder** under `docs/` named after subject
   - Example: `docs/swarm-mode/`
   - Use lowercase with hyphens for multi-word subjects

2. **Use descriptive filenames**
   - `ANALYSIS.md` - Investigation and analysis
   - `FIX_SUMMARY.md` - Complete fix summaries
   - `VALIDATION_vX.Y.Z.md` - Validation reports with version numbers
   - `IMPLEMENTATION.md` - Implementation guides

3. **Include metadata header**
   ```markdown
   **Date**: YYYY-MM-DD
   **Version**: vX.Y.Z
   **Status**: [ANALYSIS COMPLETE | FIX REQUIRED | RESOLVED]
   ```

4. **Link related documents** using relative paths

### Swarm Mode Testing

Swarm mode requires:
- Configuration in `~/.claude-sneakpeek/zai/config/settings.json`
- Validation scripts in `tests/swarm-mode/`
- TeammateTool available (swarm mode v2.81.0+)

**Swarm Mode Demo**: See [@NicerInPerson's demo](https://x.com/NicerInPerson/status/2014989679796347375) for live swarm mode execution example.

### External Resources & Inspirations

This project builds upon excellent work from the community:

| Resource | Purpose | Link |
|----------|---------|------|
| **claude-sneakpeek** | Zai variant inspiration, swarm mode implementation | [github.com/mikekelly/claude-sneakpeek](https://github.com/mikekelly/claude-sneakpeek/tree/main) |
| **cc-mirror** | Claude Code documentation mirror patterns | [github.com/numman-ali/cc-mirror](https://github.com/numman-ali/cc-mirror) |

**Special Thanks**:
- **@mikekelly** for claude-sneakpeek (zai variant) and swarm mode implementation
- **@numman-ali** for cc-mirror documentation patterns
- **@NicerInPerson** for the swarm mode demo showing real-world usage

---

## Documentation Organization

### Structure

All project documentation follows a professional folder structure under `docs/`:

```
docs/
├── analysis/                # Analysis reports (adversarial, validation, consolidation)
├── architecture/            # Architecture diagrams and design docs
├── context-monitoring/      # Context tracking analysis and fixes
├── context-management/      # Context management coordination
├── quality-gates/           # Quality gates and hooks audits
├── security/                # Security-related documentation
├── retrospective/           # Project retrospectives
├── examples/                # Code examples and tutorials
└── CLAUDE.md                # General documentation guidelines
```

### Creating New Documentation

When creating documentation for a new subject:

1. **Create a new folder** under `docs/` named after the subject
   - Example: `docs/feature-name/`
   - Use lowercase with hyphens for multi-word subjects

2. **Use descriptive filenames**
   - `ANALYSIS.md` - Analysis and investigation documents
   - `FIX_SUMMARY.md` - Complete fix summaries
   - `VALIDATION_vX.Y.Z.md` - Validation reports with version numbers
   - `IMPLEMENTATION.md` - Implementation guides

3. **Write in English**
   - All documentation must be in English
   - Follow standard markdown formatting
   - Include date, version, and status at the top

4. **Link related documents**
   - Add references to related documentation
   - Use relative paths for links within `docs/`

### Example Documentation Template

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

## Recent Documentation Reorganization

**Date**: 2026-01-28

The following documentation files were reorganized from `.claude/` to `docs/context-monitoring/`:

- `ANALYSIS.md` - Context monitoring analysis (was `ANALYSIS_CONTEXT_MONITORING.md`)
- `FIX_SUMMARY.md` - Complete fix summary (was `CONTEXT_MONITORING_FIX_SUMMARY.md`)
- `VALIDATION_v2.75.0.md` - Validation report (was `VALIDATION_REPORT_v2.75.0.md`)
- `FIX_CORRECTION_v2.75.1.md` - Fix correction analysis (was `FIX_CORRECTION_v2.75.1.md`)

This follows the project standard of storing all development documentation in the `docs/` repository with appropriate folder organization.


<claude-mem-context>
# Recent Activity

<!-- This section is auto-generated by claude-mem. Edit content outside the tags. -->

### Jan 28, 2026

| ID | Time | T | Title | Read |
|----|------|---|-------|------|
| #18139 | 2:50 PM | ✅ | Staged 40 documentation files for commit with reorganization from .claude/ to docs/ structure | ~343 |
| #18137 | 2:49 PM | ✅ | Documentation reorganization completed - 49 files moved to 8 categorized directories under docs/ | ~394 |
| #18135 | " | ✅ | Comprehensive documentation reorganization staged - 35 files moved to docs/ directory structure | ~341 |
| #18114 | 2:44 PM | ✅ | Git cleanup removed 26 deleted .md files from .claude/ directory and updated CLAUDE.md files | ~173 |
| #18103 | 2:43 PM | 🔄 | Documentation reorganization staged for git commit | ~311 |
</claude-mem-context>