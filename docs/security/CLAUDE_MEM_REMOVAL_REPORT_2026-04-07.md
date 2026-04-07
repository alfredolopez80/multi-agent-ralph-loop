# claude-mem Removal Report — 2026-04-07

**Plan reference**: `.ralph/plans/cheeky-dazzling-catmull.md` — Wave 0.3 (remove-claude-mem, 12 atomic steps) + Wave 0.4 (refactor-affected-hooks)
**Status**: ✅ COMPLETE
**Validated by**: `tests/security/test-claude-mem-removed.sh` — 19/19 PASS

## Executive Summary

`claude-mem` plugin and all associated runtime artifacts were removed from the system. Forensic backups were taken before destruction and locked read-only in `~/.security-archive/`. Zero residue confirmed via automated validation suite.

## Removal Inventory

### Runtime artifacts removed
| Surface | Status | Evidence |
|---|---|---|
| `~/.claude-mem/` data directory | ✅ removed | Test PASS: `~/.claude-mem data dir absent` |
| `~/.claude/plugins/cache/thedotmack/claude-mem/` | ✅ removed | Test PASS: `plugin cache (thedotmack) absent` |
| `~/.cache/claude-mem`, `~/.local/share/claude-mem` | ✅ removed | Test PASS |
| `~/Library/Caches/claude-mem` (macOS) | ✅ removed | Test PASS |
| `~/Library/Application Support/claude-mem` (macOS) | ✅ removed | Test PASS |
| Process `claude-mem*`, `mcp-server.cjs`, `worker-service.cjs` | ✅ none running | `pgrep` count=0 |
| Port 37777 listening | ✅ free | `lsof` count=0 |
| `mcpServers` entries in `~/.claude/settings.json` | ✅ stripped | `grep` count=0 |
| `mcpServers` entries in `~/.cc-mirror/minimax/config/settings.json` | ✅ stripped | `grep` count=0 |

### Forensic backups (locked, read-only)
Stored in `~/.security-archive/`:

| File | Size | Purpose |
|---|---|---|
| `claude-mem-data-20260407-135943.tar.gz` | 759 MB | Full data directory |
| `claude-mem-plugin-20260407-135943.tar.gz` | 537 MB | Plugin cache |
| `claude-mem-residuals-20260407-143104.tar.gz` | 436 MB | Secondary cleanup pass |
| `cc-mirror-thedotmack-residuals-20260407-144815.tar.gz` | 442 B | cc-mirror specific |
| `claude-mem-inventory-20260407-135943.txt` | 3 KB | Pre-removal file inventory |
| `claude-mem-observations-sample-20260407-135943.json` | 2.2 MB | Observations sample |
| `claude-mem-sha256-manifest-20260407-135943.txt` | 610 KB | SHA-256 hashes manifest |
| `com.claude-mem.chroma.plist.backup-20260407-140501` | 908 B | macOS plist |

**Total backup size**: ~1.7 GB

**Backup hash (data tarball)**:
```
3d65b5f536b151f00cf9ae50e9ebeea5415648e40ff8a54c25eca25bfde2c63e  claude-mem-data-20260407-135943.tar.gz
```

All backup files are `chmod 0400` (owner read-only) to prevent accidental modification.

## Migration Output

`W0.2 — migrate-unique-data`: data extracted from claude-mem DB and migrated to Obsidian vault before destruction.

**Destination**: `~/Documents/Obsidian/MiVault/migrated-from-claude-mem/`

| File | Size |
|---|---|
| `bugfixs.json` | 5.6 MB |
| `decisions.json` | 1.7 MB |
| `refactors.json` | 1.7 MB |
| `_README.md` | 1.9 KB |

The migrated data is now the canonical source, accessible via Obsidian's Graph View and grep-based queries from hooks (`session-start-restore-context.sh`, `smart-memory-search.sh`).

## Hook Refactoring (W0.4)

3 hooks were refactored to use Obsidian as memory source instead of claude-mem MCP:

| Hook | Lines changed | `.bak` evidence |
|---|---|---|
| `session-start-repo-summary.sh` | 54 lines | `*.pre-claude-mem-removal.20260407.bak` |
| `smart-memory-search.sh` | 112 lines | `*.pre-claude-mem-removal.20260407.bak` |
| `session-start-restore-context.sh` | 73 lines | `*.pre-claude-mem-removal.20260407.bak` |

**Total**: 239 lines refactored. The `.bak` files preserve the pre-removal state for forensic comparison.

### Stale references cleaned in same pass

| File | Action |
|---|---|
| 9× `.claude/skills/*/SKILL.md` (kaizen, task-batch, testing-anti-patterns, minimax, edd, glm-mcp, smart-fork, orchestrator, context-engineer) | Stripped `<claude-mem-context>` auto-generated XML blocks; removed `mcp__plugin_claude-mem_*` from tools allowlists; replaced description text with `vault` (Obsidian) |
| `.claude/agents/orchestrator.md` | Updated description, smart memory search, source list, diagram |
| `.claude/agents/CLAUDE.md` | Stripped `<claude-mem-context>` block |
| `.claude/hooks/semantic-realtime-extractor.sh` | Comment updated (was claiming claude-mem migration); body still disabled pending Obsidian refactor (TODO W4.2) |
| `.claude/hooks/cleanup-secrets-db.js` | DELETED — dead code referencing `~/.claude-mem/claude-mem.db` (no longer exists), not registered as a hook |

## Verification

```bash
$ bash tests/security/test-claude-mem-removed.sh
=== Summary: 19 passed / 0 failed ===
✅ Wave 0 validation PASSED.
```

19 checks: processes, ports, data dirs, settings.json files, hook refs, skill refs, agent refs, XML blocks, backup existence, migration data existence.

## Anti-Recreation Guards

The following safeguards prevent silent reinstallation:

1. **Settings.json stripped**: no claude-mem MCP entries in any `settings.json`. Cold restart of Claude Code will not auto-install.
2. **Forensic backup chmod 0400**: prevents accidental modification of evidence.
3. **`.bak` files preserved**: any future "where did this code go?" question answered by diff against `.bak`.
4. **`tests/security/test-claude-mem-removed.sh`**: regression test — run before any release to catch reinstallation drift.

## Out of Scope (Not Removed)

| Item | Why kept |
|---|---|
| `~/Documents/GitHub/claude-mem` (89 MB) | Source code clone of upstream repo. NOT an installation. Not in scope of W0.3. May be deleted manually if no longer needed. |
| `~/Documents/Obsidian/MiVault/migrated-from-claude-mem/` | Intentional W0.2 destination — this is the migrated data we kept. |

## References

- Plan: `.ralph/plans/cheeky-dazzling-catmull.md` (Wave 0)
- Test: `tests/security/test-claude-mem-removed.sh`
- Leakage report: `docs/security/CLAUDE_MEM_LEAKAGE_SWEEP_2026-04-07.md`
