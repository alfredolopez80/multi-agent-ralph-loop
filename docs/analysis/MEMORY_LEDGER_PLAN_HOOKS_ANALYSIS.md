# Memory, Ledger, and Plan Hooks Analysis

**Date**: 2026-01-29
**Version**: v2.81.0
**Status**: ANALYSIS COMPLETE

## Executive Summary

This analysis examines all hooks related to `ralph memory`, `ralph ledger`, and `ralph plan` functionality to determine:
1. Which hooks are currently active/registered
2. Where data is being stored
3. Which hooks are obsolete and can be removed
4. Data classification (learning vs critical)

## Key Findings

### 1. **ralph memory** - DEPRECATED ✅
- **Status**: Confirmed deprecated
- **Replacement**: `claude-mem` MCP plugin
- **Evidence**: No `ralph-memory` CLI command found
- **Data migration**: Completed (see `~/.ralph/backups/migration-to-claude-mem-20260129-184720`)

### 2. **ralph ledger** - LEARNING ONLY ✅
- **Status**: Active for learning purposes only
- **Data type**: Session continuity, handoffs, learning patterns
- **Critical data**: NONE (confirmed)
- **Storage**: `~/.ralph/ledgers/` (452 files)

### 3. **ralph plan** - BACKUP ONLY ✅
- **Status**: Active as backup to Claude Code's native plans
- **Data type**: Plan state, orchestration metadata
- **Critical data**: NONE (Claude Code has source of truth)
- **Storage**: `~/.ralph/archive/plans/`, `.claude/plan-state.json` (per-project)

## Registered Hooks Analysis

### Active Hooks (11)

| Hook | Event | Purpose | Data Storage | Status |
|------|-------|---------|--------------|--------|
| `memory-write-trigger.sh` | UserPromptSubmit | Detect memory intent phrases | `.ralph/logs/` | **KEEP** - memory trigger |
| `session-start-ledger.sh` | SessionStart | Initialize session ledger | `~/.ralph/ledgers/` | **KEEP** - learning |
| `plan-state-adaptive.sh` | UserPromptSubmit | Adaptive plan complexity detection | `.claude/plan-state.json` | **KEEP** - plan backup |
| `auto-migrate-plan-state.sh` | SessionStart | Migrate plan-state v1→v2 | `.claude/plan-state.json` | **KEEP** - migration |
| `plan-sync-post-step.sh` | PostToolUse | Detect drift and patch downstream | `.claude/plan-state.json` | **KEEP** - plan sync |
| `smart-memory-search.sh` | PreToolUse | PARALLEL search across memory | `.claude/memory-context.json` | **KEEP** - claude-mem |
| `semantic-realtime-extractor.sh` | PostToolUse | Extract facts from code changes | `~/.ralph/memory/` | **KEEP** - learning |
| `decision-extractor.sh` | PostToolUse | Extract architectural decisions | `~/.ralph/episodes/` | **KEEP** - learning |
| `procedural-inject.sh` | PreToolUse | Inject rules into subagent context | `~/.ralph/procedural/` | **KEEP** - learning |
| `reflection-engine.sh` | Stop | Extract patterns after session | `~/.ralph/episodes/` | **KEEP** - learning |
| `orchestrator-report.sh` | Stop | Generate session report | `~/.ralph/reports/` | **KEEP** - reporting |

### Inactive Hooks (9) - CANDIDATES FOR REMOVAL

| Hook | Purpose | Reason for Inactivation | Recommendation |
|------|---------|------------------------|----------------|
| `plan-state-init.sh` | Initialize plan-state from analysis | Manual init, not needed | **REMOVE** - redundant |
| `plan-state-lifecycle.sh` | Auto-archive stale plans | Not used, manual archive preferred | **REMOVE** - unused |
| `plan-analysis-cleanup.sh` | Cleanup plan analysis files | Not used | **REMOVE** - obsolete |
| `semantic-auto-extractor.sh` | Extract semantic facts from session | Replaced by semantic-realtime-extractor.sh | **REMOVE** - duplicate |
| `orchestrator-auto-learn.sh` | Trigger learning on complex tasks | Replaced by curator workflow | **REMOVE** - obsolete |
| `agent-memory-auto-init.sh` | Auto-init agent memory buffers | Not used, memory initialized on demand | **REMOVE** - unused |
| `curator-suggestion.sh` | Suggest curator when memory empty | Not used, manual curator invocation | **REMOVE** - optional |
| `global-task-sync.sh` | Sync plan-state to Claude Code tasks | Unidirectional, not needed | **REMOVE** - obsolete |
| `orchestrator-init.sh` | Initialize orchestrator state | Not used, state auto-initialized | **REMOVE** - redundant |

## Data Storage Locations

### Active Storage (Verified)

| Location | Type | Files | Purpose | Critical? |
|----------|------|-------|---------|-----------|
| `~/.ralph/memory/` | Semantic | 6 files | Long-term facts | NO (learning) |
| `~/.ralph/episodes/` | Episodic | 4785 files | Session experiences (30d TTL) | NO (learning) |
| `~/.ralph/procedural/` | Procedural | 10 files | Learned patterns | NO (learning) |
| `~/.ralph/ledgers/` | Ledger | 452 files | Session continuity | NO (learning) |
| `~/.ralph/checkpoints/` | Checkpoints | 1249 files | Time travel state | NO (backup) |
| `~/.ralph/events/` | Events | 4 files | Event log | NO (observability) |
| `~/.ralph/agent-memory/` | Agent Memory | 47 dirs | Per-agent memory | NO (learning) |
| `.claude/memory-context.json` | Project | 19KB | Memory search cache | NO (cache) |
| `.claude/plan-state.json` | Project | Per-project | Plan state backup | NO (backup) |

### Inactive Storage (Deprecated)

| Location | Status | Reason |
|----------|--------|--------|
| `~/.ralph/plans/` | NOT FOUND | Never created, plans in archive |
| `~/.ralph/memory/ralph-memory` | DEPRECATED | Replaced by claude-mem MCP |

## Data Classification Summary

### Learning Data (Non-Critical)
- **Semantic memory**: Facts, preferences, patterns
- **Episodic memory**: Session experiences (auto-expire 30d)
- **Procedural memory**: Learned rules from repositories
- **Agent memory**: Per-agent working memory
- **Ledgers**: Session continuity data

### Backup Data (Non-Critical)
- **Checkpoints**: Time travel snapshots
- **Plan state**: Backup of Claude Code plans
- **Events**: Observability log

### NO Critical Data Found
- All data in `~/.ralph/` is learning/backup/cache
- Safe to delete entire `~/.ralph/` without project impact
- Source of truth: Claude Code native plans + MCP plugins

## Recommendations

### 1. Remove Inactive Hooks (9 files)

```bash
# Safe to remove - these hooks are not registered and obsolete
rm ~/.claude/hooks/plan-state-init.sh
rm ~/.claude/hooks/plan-state-lifecycle.sh
rm ~/.claude/hooks/plan-analysis-cleanup.sh
rm ~/.claude/hooks/semantic-auto-extractor.sh
rm ~/.claude/hooks/orchestrator-auto-learn.sh
rm ~/.claude/hooks/agent-memory-auto-init.sh
rm ~/.claude/hooks/curator-suggestion.sh
rm ~/.claude/hooks/global-task-sync.sh
rm ~/.claude/hooks/orchestrator-init.sh
```

### 2. Keep Active Hooks (11 files)

All registered hooks are actively used and should be kept:
- Memory integration (claude-mem MCP)
- Learning system (semantic, episodic, procedural)
- Plan state management (backup to Claude Code)
- Session reporting (observability)

### 3. Data Cleanup (Optional)

```bash
# Safe to clean up old learning data (optional)
find ~/.ralph/episodes/ -type f -mtime +30 -delete  # Remove episodes older than 30 days
find ~/.ralph/backups/ -type d -mtime +90 -exec rm -rf {} +  # Remove old backups
```

### 4. Documentation Updates

Update `README.md` and `CLAUDE.md` to reflect:
- `ralph memory` is deprecated (use `claude-mem` MCP)
- `ralph ledger` is learning-only (no critical data)
- `ralph plan` is backup-only (Claude Code has source of truth)

## Validation Commands

```bash
# Verify hooks registration
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.hooks'

# Check active storage locations
ls -la ~/.ralph/
find ~/.ralph/ -maxdepth 1 -type d | wc -l  # Should be ~15 directories

# Verify no critical data
grep -r "password\|secret\|token\|api_key" ~/.ralph/ 2>/dev/null | wc -l  # Should be 0

# Check claude-mem integration
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.enabledPlugins."claude-mem@thedotmack"'
```

## Migration History

### 2026-01-29: Migration to claude-mem
- **Backup created**: `~/.ralph/backups/migration-to-claude-mem-20260129-184720`
- **Old system**: `ralph memory` CLI + custom hooks
- **New system**: `claude-mem` MCP plugin + semantic/episodic/procedural memory
- **Status**: Migration complete, old hooks removed

## Conclusion

All hooks related to `ralph memory`, `ralph ledger`, and `ralph plan` have been analyzed:

1. **ralph memory**: ✅ Deprecated and migrated to claude-mem
2. **ralph ledger**: ✅ Active for learning only (no critical data)
3. **ralph plan**: ✅ Active as backup only (Claude Code is source of truth)

**9 inactive hooks can be safely removed.**
**11 active hooks should be kept.**
**All data is learning/backup (no critical project data).**

---

**Next Steps**:
1. Review and approve removal of 9 inactive hooks
2. Update documentation to reflect deprecations
3. Optional: Clean up old learning data (>30 days)
