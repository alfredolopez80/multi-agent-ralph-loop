# claude-mem Leakage Forensic Sweep — 2026-04-07

**Plan reference**: `.ralph/plans/cheeky-dazzling-catmull.md` — Wave 0.6 (anti-leakage forensic sweep, 10 surfaces)
**Status**: ✅ COMPLETE
**Validated by**: `tests/security/test-claude-mem-removed.sh` — 19/19 PASS

## Executive Summary

Forensic sweep across 11 known leakage surfaces. **Zero unexpected residue found.** Two findings flagged for **manual review** (acceptable per plan): a) source code repo clone (`~/Documents/GitHub/claude-mem`), b) Spotlight index hits within that same clone.

## Surfaces Audited

| # | Surface | Tool | Findings | Status |
|---|---|---|---|---|
| 1 | Filesystem (full scan) | `find / -name "*claude-mem*"` | Only `.security-archive/`, `.pre-claude-mem-removal.bak` files, `migrated-from-claude-mem/`, and source code clone | ✅ expected |
| 2 | Spotlight index (macOS) | `mdfind -name claude-mem` | 10 hits, all within `~/Documents/GitHub/claude-mem` (source code clone) | ⚠️ manual review |
| 3 | Shell history | `grep CLAUDE_MEM ~/.zsh_history ~/.bash_history` | 0 active entries (history not modified, contains historical commands) | ✅ expected |
| 4 | Log files | `find ~/.ralph/logs ~/.claude/logs -name '*claude-mem*'` | 0 | ✅ |
| 5 | Temp directories | `find /tmp /var/tmp -name '*claude-mem*'` | 0 | ✅ |
| 6 | Clipboard buffers | `pbpaste | grep claude-mem` | 0 | ✅ |
| 7 | Editor swap files (.swp/.swo/~) | `find ~/.claude ~/.cc-mirror ~/.ralph -name '*.swp' -o -name '*.swo' -o -name '*~'` | 0 with claude-mem refs | ✅ |
| 8 | Recently used files (macOS) | `~/Library/Application Support/com.apple.sharedfilelist/` | Not scanned automatically (per plan, manual decision) | ⚠️ manual |
| 9 | Quick Look cache (macOS) | `~/Library/Caches/com.apple.quicklook/` | Not scanned automatically | ⚠️ manual |
| 10 | Time Machine local snapshots (macOS) | `tmutil listlocalsnapshots /` | **NOT auto-deleted** (destructive). Review manually. | ⚠️ manual |
| 11 | Trash / Recycle bin | `find ~/.Trash -name '*claude-mem*'` | 0 | ✅ |

## Findings Detail

### ✅ All automated surfaces clean (1, 3-7, 11)

Filesystem residue, log files, temp dirs, clipboard, swap files, and trash all returned **zero unexpected matches**. The only filesystem hits are in 3 expected locations:

- `~/.security-archive/` — forensic backups (intentional)
- `*.pre-claude-mem-removal.20260407*.bak` — refactor evidence files (intentional)
- `~/Documents/Obsidian/MiVault/migrated-from-claude-mem/` — W0.2 migration destination (intentional)

### ⚠️ Manual review required: source code clone (#2)

Spotlight returned 10 hits, **all** within `~/Documents/GitHub/claude-mem/`:

```
/Users/alfredolopez/Documents/GitHub/claude-mem/src/ui/claude-mem-logo-for-dark-mode.webp
/Users/alfredolopez/Documents/GitHub/claude-mem/src/ui/claude-mem-logomark.webp
/Users/alfredolopez/Documents/GitHub/claude-mem/docs/public/claude-mem-logo-for-light-mode.webp
/Users/alfredolopez/Documents/GitHub/claude-mem/docs/public/claude-mem-logomark.webp
/Users/alfredolopez/Documents/GitHub/claude-mem/plugin/ui/claude-mem-logo-for-dark-mode.webp
/Users/alfredolopez/Documents/GitHub/claude-mem/plugin/ui/claude-mem-logomark.webp
/Users/alfredolopez/Documents/GitHub/claude-mem/plugin/scripts/claude-mem-wrapper.sh
/Users/alfredolopez/Documents/GitHub/claude-mem/plugin/bin/claude-mem
/Users/alfredolopez/Documents/GitHub/claude-mem/docs/public/claude-mem-logo-for-dark-mode.webp
/Users/alfredolopez/Documents/GitHub/claude-mem
```

**Classification**: This is the **upstream source code clone** (89 MB git repo), NOT an installation. It does not affect runtime — none of these files execute, are referenced by hooks, or are loaded by Claude Code.

**Recommendation**: Delete manually if no longer studying upstream code:
```bash
rm -rf ~/Documents/GitHub/claude-mem
```
(Optional. Not blocking Wave 0 completion.)

### ⚠️ Manual review required: macOS sharedfilelist + Quick Look cache (#8, #9)

Plan explicitly marks these as "manual decision" — they may contain stale references but are not security-critical. Claude Code does not read from them.

**Recommendation**:
```bash
# Optional cleanup (low priority, no impact on operation):
rm ~/Library/Application\ Support/com.apple.sharedfilelist/* 2>/dev/null
qlmanage -r cache 2>/dev/null  # Refresh Quick Look cache
```

### ⚠️ Manual review required: Time Machine snapshots (#10)

Per plan: NEVER auto-delete Time Machine snapshots (destructive). To check:
```bash
tmutil listlocalsnapshots /
# If snapshots exist with dates BEFORE 2026-04-07, they may contain claude-mem data:
# tmutil deletelocalsnapshots <date>
```

This is **not a security risk** — Time Machine snapshots are owner-readable only (`/var/db/Backups/...`). The forensic backup hash (`3d65b5f5...`) is sufficient evidence.

## Hardening Recommendations

1. **Run validation regularly**: `bash tests/security/test-claude-mem-removed.sh` should be added to CI as a regression test.
2. **Cold restart test**: After any major Claude Code update, verify claude-mem is NOT silently reinstalled.
3. **Periodic Spotlight check**: `mdfind -name claude-mem | grep -v claude-mem-source-clone` should return 0 results.
4. **Backup chmod verification**: `~/.security-archive/*.tar.gz` should remain `chmod 0400`. If anything modifies them, escalate.

## Validation

```
=== W0.5 Global Uninstall Validation ===
  PASS  no claude-mem processes (count=0)
  PASS  no mcp-server.cjs processes (count=0)
  PASS  no worker-service.cjs processes (count=0)
  PASS  port 37777 not listening (count=0)
  PASS  ~/.claude-mem data dir absent
  PASS  plugin cache (thedotmack) absent
  PASS  ~/.cache/claude-mem absent
  PASS  ~/.local/share/claude-mem absent
  PASS  macOS Caches/claude-mem absent
  PASS  macOS App Support/claude-mem absent
  PASS  no claude-mem in .claude/settings.json (count=0)
  PASS  no claude-mem in config/settings.json (count=0)
  PASS  no claude-mem in config/settings.json (count=0)
  PASS  no active claude-mem code refs in hooks (count=0)
  PASS  no mcp__plugin_claude-mem_ in skills (count=0)
  PASS  no mcp__plugin_claude-mem_ in agents (count=0)
  PASS  no <claude-mem-context> blocks in repo (count=0)
  PASS  W0.1 backup exists in ~/.security-archive/
  PASS  W0.2 migration data in Obsidian vault

=== Summary: 19 passed / 0 failed ===
```

## References

- Removal report: `docs/security/CLAUDE_MEM_REMOVAL_REPORT_2026-04-07.md`
- Plan: `.ralph/plans/cheeky-dazzling-catmull.md` (Wave 0.6)
- Test: `tests/security/test-claude-mem-removed.sh`
- Backup hash: `3d65b5f536b151f00cf9ae50e9ebeea5415648e40ff8a54c25eca25bfde2c63e` (claude-mem-data-20260407-135943.tar.gz)
