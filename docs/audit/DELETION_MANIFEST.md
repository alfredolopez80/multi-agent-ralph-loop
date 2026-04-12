# Deletion Manifest — Wave H1

**Generated**: 2026-04-12
**Action**: Delete DEAD files, archive ORPHANED files

---

## DEAD Files — Action: DELETE

These are backup/archived files with no purpose.

| # | File | Reason |
|---|------|--------|
| 1 | `.claude/hooks/post-compact-restore.sh.ARCHIVED` | Archived backup of active hook |
| 2 | `.claude/hooks/session-start-repo-summary.sh.pre-claude-mem-removal.20260407.bak` | Pre-removal backup (data migrated to Obsidian) |
| 3 | `.claude/hooks/session-start-restore-context.sh.pre-claude-mem-removal.20260407.bak` | Pre-removal backup (data migrated to Obsidian) |
| 4 | `.claude/hooks/smart-memory-search.sh.pre-claude-mem-removal.20260407.bak` | Pre-removal backup (data migrated to Obsidian) |

---

## ORPHANED Files — Action: ARCHIVE

Moved to `.claude/archive/` via `git mv` (orphaned-hooks subdirectory could not be created due to permissions; files archived directly in `.claude/archive/`).

| # | File | Notes |
|---|------|-------|
| 1 | `deslop-auto-clean.sh` | Deslop auto-clean — not wired |
| 2 | `glm-visual-validation.sh` | GLM visual validation — not wired |
| 3 | `glm5-subagent-stop.sh` | Superseded by subagent-stop-universal.sh |
| 4 | `quality-gates-v2.sh` | Superseded by quality-parallel-async.sh |
| 5 | `sec-context-validate.sh` | Security context validation — not wired |
| 6 | `security-full-audit.sh` | Full security audit — not wired |
| 7 | `typescript-quick-check.sh` | TypeScript quick check — not wired |
| 8 | `vault-lint.sh` | Vault linting — not wired |
| 9 | `universal-aristotle-gate.sh` | Repo copy — global `~/.claude/hooks/` copy is wired |
| 10 | `universal-prompt-classifier.sh` | Repo copy — global `~/.claude/hooks/` copy is wired |
| 11 | `universal-step-tracker.sh` | Repo copy — global `~/.claude/hooks/` copy is wired |

---

## Execution Summary

- **4 files deleted** (DEAD)
- **11 files archived** (ORPHANED -> `.claude/archive/`)
- **71 repo-wired hooks remain** (untouched)
