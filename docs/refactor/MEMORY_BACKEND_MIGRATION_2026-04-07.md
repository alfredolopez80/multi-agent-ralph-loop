# Memory Backend Migration — claude-mem → Obsidian Vault

**Date**: 2026-04-07
**Branch**: `feat/mempalace-adoption`
**Scope**: Memory subsystem refactor

---

## Summary

As part of the `feat/mempalace-adoption` work stream, the project's memory/observation backend has been migrated from the `claude-mem` plugin to the Obsidian vault (`~/Documents/Obsidian/MiVault/`) as the single source of truth.

This decision follows the architectural principle established during the MemPalace comparison analysis: **Obsidian is the canonical store**, and all memory/context retrieval should read from it directly rather than through parallel systems.

## Rationale

1. **Single source of truth**: Obsidian vault was already the de facto canonical store for wiki articles, lessons, and project knowledge. Maintaining a second parallel store (claude-mem SQLite) created sync complexity and drift risk.
2. **Simpler architecture**: Reading directly from markdown files avoids the overhead of maintaining an additional database format and its associated hooks.
3. **Better auditability**: Markdown is human-readable and version-controllable. Any observation stored in the vault can be reviewed with standard tools.
4. **Coherent retrieval**: Obsidian's native Graph View and search work across everything in one unified index.

## What changed

### Data migration

The existing observations from the previous backend were exported to JSON format and placed in:

```
~/Documents/Obsidian/MiVault/migrated-from-claude-mem/
├── decisions.json   (historical decisions)
├── refactors.json   (architectural changes)
├── bugfixs.json     (bug fix history)
└── _README.md       (index + format documentation)
```

Only the high-signal types (`decision`, `refactor`, `bugfix`) were migrated — lower-signal types like `discovery` and `change` are recoverable from git history and were not included.

### Hooks updated to v3.2.0

Three hooks previously depended on the old backend and have been refactored to read from the Obsidian vault instead:

1. **`session-start-repo-summary.sh`** — replaces plugin query with:
   - Ralph semantic memory (`~/.ralph/memory/semantic.json`)
   - Ralph ledgers (`~/.ralph/ledgers/`)
   - Migrated observations filtered by `$PROJECT_NAME`
   - Obsidian wiki recent articles

2. **`session-start-restore-context.sh`** — `get_vault_hints()` function replaces the prior hints function, reading from migrated decisions + Obsidian vault wiki.

3. **`smart-memory-search.sh`** — memory source #1 is now "vault" (Obsidian + migrated JSONs), removing the prior plugin dependency while preserving parallelism across handoffs, ledgers, and web search sources.

### Settings files cleaned

Four settings.json files had references to the previous backend removed via a surgical Python script (key deletion, not null replacement) to avoid leaving orphan `null` values that would fail linter validation:

- `~/.claude/settings.json`
- `~/.cc-mirror/minimax/config/settings.json`
- `~/.cc-mirror/zai/config/settings.json`
- `~/.cc-mirror/zai/config/settings2.json`

All four files are valid JSON with 0 nulls, 0 empty objects, and 0 references to the old backend.

## What stayed the same

- Ralph's native memory stores (`~/.ralph/memory/semantic.json`, `~/.ralph/handoffs/`, `~/.ralph/ledgers/`, `~/.ralph/episodes/`) are unchanged.
- The vault graduation pipeline (`vault-graduation.sh`) continues to operate.
- All 77 wired hooks (excluding the 3 refactored above) work without modification.
- The 5-layer memory model (semantic → procedural → episodic → vault → web) is preserved.

## Verification

Post-migration:

- ✅ `bash -n` syntax check passes on all 3 refactored hooks
- ✅ 4 settings.json files are valid JSON
- ✅ Migrated JSONs (7,982 entries) readable via `jq`
- ✅ Obsidian vault structure intact

## References

- Planning document: `.ralph/plans/cheeky-dazzling-catmull.md` (gitignored)
- Architectural context: `docs/analysis/MEMPALACE_COMPARISON.md` (on `analysis/mempalace-comparison` branch)
- Migrated data: `~/Documents/Obsidian/MiVault/migrated-from-claude-mem/_README.md`
