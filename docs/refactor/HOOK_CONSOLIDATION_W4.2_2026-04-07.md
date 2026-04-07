# Hook Consolidation Analysis — W4.2

**Date**: 2026-04-07
**Wave**: W4.2 — hook-consolidation
**Branch**: feat/mempalace-adoption
**Agent**: ralph-coder (theta)

---

## Task 1: wake-up-layer-stack.sh Registration

**Status**: DONE

The hook was registered as a SessionStart hook (matcher: `*`) in `~/.cc-mirror/minimax/config/settings.json`.

- Executable: `chmod +x` applied
- JSON validation: PASS (produces valid `{"hookSpecificOutput": {...}}` with `additionalContext`)
- Layer files exist: `~/.ralph/layers/L0_identity.md` (922 bytes) + `~/.ralph/layers/L1_essential.md` (2513 bytes)

---

## Task 2: SessionStart Hook Inventory + Consolidation Analysis

### Current SessionStart Hooks (10 total)

| # | Hook | Matcher | Purpose | Token Cost | Action |
|---|------|---------|---------|------------|--------|
| 1 | `post-compact-restore.sh` | `compact` | Restore context after compaction | Low (only on compact) | KEEP |
| 2 | `auto-migrate-plan-state.sh` | `*` | Migrate plan-state.json v1 to v2 | Low (no-op unless migration needed) | KEEP |
| 3 | `auto-sync-global.sh` | `*` | Sync global commands/agents/hooks to project | Low (file copy, early exit if synced) | KEEP |
| 4 | `session-start-restore-context.sh` | `*` | Restore plan state + ledgers + handoffs + vault hints | **HIGH** (~8000 chars context injected) | **CONSOLIDATION CANDIDATE** |
| 5 | `orchestrator-init.sh` | `*` | Initialize agent memory buffers + plan-state | Medium (dir/file creation) | **CONSOLIDATION CANDIDATE** |
| 6 | `project-backup-metadata.sh` | `*` | Track project sessions, save metadata | Medium (git operations) | KEEP |
| 7 | `session-start-repo-summary.sh` | `*` | Display project history from vault + ralph stores | **HIGH** (vault scanning + context injection) | **CONSOLIDATION CANDIDATE** |
| 8 | `project-state.sh` | `*` | Skills sync validation + context tracking | Medium (CLI tool, dual-purpose) | KEEP |
| 9 | `vault-graduation.sh` | `*` | Promote vault learnings to rules/learned/ | Medium (find + file ops) | KEEP |
| 10 | `wake-up-layer-stack.sh` | `*` | Load L0 (identity) + L1 (essential rules) | **Target: <1500 tokens** | NEW (registered) |

### Consolidation Candidates

#### Candidate 1: session-start-restore-context.sh -- OVERLAP with wake-up-layer-stack.sh

**What it does**:
1. Checks plan-state.json for active plans
2. Loads most recent session ledger (first 50 lines)
3. Loads session handoff files
4. Gets vault hints from Obsidian
5. Composes and injects all of the above as `additionalContext`

**Overlap with wake-up-layer-stack.sh**:
- Both inject `additionalContext` via `hookSpecificOutput`
- `session-start-restore-context.sh` is the OLD context injection mechanism
- `wake-up-layer-stack.sh` is the NEW MemPalace mechanism (L0+L1 layers)
- When L1 is fully built (containing all essential rules), the vault hints from `session-start-restore-context.sh` become redundant

**Recommendation**: **DEFER removal until L1_essential.md is verified complete** (W4.3 layer verification). Once L1 contains all essential rules, `session-start-restore-context.sh` can be retired. The wake-up hook's comment on line 13 explicitly states: "W4.2 hook-consolidation will activate this hook and retire session-start-restore-context.sh."

**Risk**: LOW. The plan-state.json restoration (item 1) is also handled by `orchestrator-init.sh`. Ledger/handoff restoration could be moved to L2 on-demand loading.

#### Candidate 2: orchestrator-init.sh -- PARTIAL OVERLAP with wake-up-layer-stack.sh

**What it does**:
1. Creates agent memory buffers for 11 default agents (directories + empty JSON)
2. Initializes procedural memory (rules.json)
3. Creates/migrates plan-state.json
4. Records session start time in plan-state

**Overlap with wake-up-layer-stack.sh**:
- `orchestrator-init.sh` does NOT inject context -- it does filesystem setup only
- No direct overlap with the wake-up hook's L0+L1 loading
- However, its plan-state initialization is duplicated by `auto-migrate-plan-state.sh` and partially by `session-start-restore-context.sh`

**Recommendation**: **KEEP for now**. It provides infrastructure initialization that the wake-up hook does not cover (directory creation, agent memory buffers). Could be consolidated with `auto-migrate-plan-state.sh` in a future wave.

#### Candidate 3: session-start-repo-summary.sh -- OVERLAP with session-start-restore-context.sh

**What it does**:
1. Reads semantic memory (last 3 facts)
2. Reads latest session ledger
3. Reads migrated decisions from Obsidian vault
4. Reads recent wiki articles from vault
5. Injects all as `additionalContext`

**Overlap**:
- Items 2, 3, and 4 overlap heavily with `session-start-restore-context.sh` (both read ledgers and vault data)
- Together they inject 2 separate `additionalContext` payloads, both containing vault hints and ledger data

**Recommendation**: **Merge into session-start-restore-context.sh or retire**. These two hooks duplicate vault/ledger reading. If `session-start-restore-context.sh` is retired (per Candidate 1), this hook could be simplified to only inject the repo summary portion that isn't covered by L1.

### Consolidation Priority

| Priority | Action | Wave | Impact |
|----------|--------|------|--------|
| P1 | Retire `session-start-restore-context.sh` after L1 verification | W4.3 | Removes ~8000 chars of duplicate context injection |
| P2 | Merge `session-start-repo-summary.sh` into wake-up or retire | W4.3 | Removes duplicate vault/ledger scanning |
| P3 | Consolidate `orchestrator-init.sh` + `auto-migrate-plan-state.sh` | W5 | Reduces plan-state duplication |

### Token Budget Analysis

| Hook | Estimated Context Injected |
|------|--------------------------|
| `session-start-restore-context.sh` | ~6000-8000 chars |
| `session-start-repo-summary.sh` | ~2000-4000 chars |
| `project-backup-metadata.sh` | ~200 chars |
| `project-state.sh` | ~100 chars |
| `vault-graduation.sh` | ~100 chars |
| `auto-migrate-plan-state.sh` | ~100 chars (when migrating) |
| **wake-up-layer-stack.sh** | **~3400 chars (L0+L1, target <1500 tokens)** |

**Total SessionStart context injection**: ~8000-13000 chars across all hooks (excluding compact-restore and auto-sync which inject minimal/no context).

**Post-consolidation target**: ~4000-6000 chars after retiring `session-start-restore-context.sh` and `session-start-repo-summary.sh`.

---

## Actions Taken

1. `chmod +x .claude/hooks/wake-up-layer-stack.sh` -- made executable
2. Validated JSON output: PASS
3. Registered in `~/.cc-mirror/minimax/config/settings.json` as SessionStart hook (matcher: `*`)
4. Backup of settings.json created at `settings.json.bak.{timestamp}`

## Actions NOT Taken (per instructions)

- No hooks were deleted or disabled
- No hooks were modified
- `session-start-restore-context.sh`, `orchestrator-init.sh`, and `session-start-repo-summary.sh` remain registered
