# CLAUDE.md Drift Report — 2026-04-07

**Wave**: W1.5 — drift-correction (ralph-reviewer-alpha)
**Branch**: feat/mempalace-adoption
**Audited**: 2026-04-07
**Files audited**: 5 CLAUDE.md files + 3 memory entries
**Status**: REPORT ONLY — no fixes applied (fixes deferred to W4.4)

---

## Summary

| Severity | Count |
|----------|-------|
| High     | 6     |
| Medium   | 8     |
| Low      | 4     |
| **Total claims audited** | **42** |
| **Total drift findings** | **18** |

---

## Drift Table

| File | Claim | Reality | Drift Type | Severity |
|------|-------|---------|------------|----------|
| `~/CLAUDE.md` | Primary settings: `~/.claude-sneakpeek/zai/config/settings.json` (v2.73.2) | Path does NOT exist. Dead since at least 2026-04-04. | false-positive | **high** |
| `~/CLAUDE.md` | "ALWAYS use `~/.claude-sneakpeek/zai/config/settings.json`" | Directory `~/.claude-sneakpeek/` does not exist | false-positive | **high** |
| `repo CLAUDE.md` | "PRIMARY SETTINGS: `~/.cc-mirror/minimax/config/settings.json` — this is the ONLY configuration file" | `~/.claude/settings.json` also exists and has MORE hooks registered (77 vs the minimax file); neither is "the only" file. Both are active. | contradictory | **high** |
| `~/.claude/CLAUDE.md` | "PRIMARY SETTINGS: `~/.claude/settings.json` — this is the ONLY configuration file" | `~/.cc-mirror/minimax/config/settings.json` also actively wires hooks; "only" is false. | contradictory | **high** |
| `repo CLAUDE.md` | Memory storage: `Episodic: ~/.ralph/episodes/` (implied to exist) | EXISTS — 3000+ episode dirs in `~/.ralph/episodes/.processed/`. Claim is correct, but memory entry says it doesn't exist. | contradictory (memory vs. reality) | **high** |
| `repo CLAUDE.md` | Memory storage: `Procedural: ~/.ralph/procedural/rules.json` | EXISTS — file present along with backups. Claim is correct; memory entry says it doesn't exist. | contradictory (memory vs. reality) | **high** |
| `repo CLAUDE.md` | "37 automated security tests in `tests/security/`" | `tests/security/` exists; the count of exactly 37 is unverified against current branch state | false-positive (unverified count) | medium |
| `repo CLAUDE.md` | Hook event count: "11 configured" with full list | All 11 events present in `~/.claude/settings.json`. Claim is CORRECT. | no drift | low |
| `repo CLAUDE.md` | "Hooks wired" — implies 22 wired (from prior CLAUDE.md statements) | HOOKS_INVENTORY_2026-04-07.md shows 77+ wired across 3 settings files. Prior claim from memory was wrong. | version-mismatch | medium |
| `repo CLAUDE.md` | "`learning-gate.sh` — PreToolUse (Task) — Auto-learning trigger" | NOT present in `~/.claude/settings.json` hook entries. Not registered. | false-positive | medium |
| `repo CLAUDE.md` | "`cleanup-secrets-db.js` — Scans DB for exposed secrets — Manual" | File was deleted in W0.4 (dead code referencing removed claude-mem DB). | false-positive | medium |
| `repo CLAUDE.md` | "`batch-progress-tracker.sh` — PostToolUse — Batch progress tracking (v2.88)" | EXISTS and IS registered. Claim correct. | no drift | low |
| `repo CLAUDE.md` | "docs/analysis/" directory (referenced as target of MEMPALACE_COMPARISON.md) | `docs/analysis/MEMPALACE_COMPARISON.md` does NOT exist. Planned but never committed. | false-positive | **high** |
| `~/.claude/CLAUDE.md` | "Global Rules (symlinked from repo): aristotle-methodology.md, parallel-first.md, plan-immutability.md, browser-automation.md, ast-grep-usage.md, zai-mcp-usage.md" | Files exist in `.claude/rules/` in repo. Whether `~/.claude/rules/` has actual symlinks is unverified — W5.0 diagnoses. | unverified | medium |
| `~/.claude/CLAUDE.md` | "SubagentStop hook: `glm5-subagent-stop.sh`" | Registered only in `~/.cc-mirror/minimax/config/settings.json`, NOT in `~/.claude/settings.json`. The global CLAUDE.md implies it's in the main config. | false-positive (wrong config file) | medium |
| `~/.claude/CLAUDE.md` | Version "v3.1.0" | Repo CLAUDE.md says "v3.0.0". Multiple version tags disagree. | version-mismatch | medium |
| `.claude/agents/CLAUDE.md` | Contains agent definitions and configuration | File is effectively empty (1 line after Wave 0 strip). No content present. | false-positive | medium |

---

## Top 5 Most Critical Drifts

### 1. `~/CLAUDE.md` — Zai config path points to non-existent directory
- **File**: `~/CLAUDE.md`
- **Claim**: `~/.claude-sneakpeek/zai/config/settings.json` is the REAL primary settings
- **Reality**: Directory `~/.claude-sneakpeek/` does not exist
- **Impact**: Any developer following this instruction will get "no such file" errors. Hooks changes made there go nowhere.
- **Fix in**: W4.4

### 2. Three CLAUDE.md files each claim to be the "ONLY" settings file
- **Files**: `~/CLAUDE.md`, `~/.claude/CLAUDE.md`, repo `CLAUDE.md`
- **Claim**: Each claims a different `settings.json` is the "PRIMARY" and "ONLY" config
- **Reality**: Both `~/.claude/settings.json` AND `~/.cc-mirror/minimax/config/settings.json` are actively used.
- **Impact**: Developers edit the wrong file and wonder why hooks don't fire.
- **Fix in**: W4.4

### 3. `docs/analysis/MEMPALACE_COMPARISON.md` claimed to exist but does not
- **Claim**: W1.5 plan mentions editing this file
- **Reality**: File does not exist at that path. May be in different location or never committed.
- **Impact**: W1.5 drift correction target is missing file.
- **Fix in**: W4.4 (create or locate)

### 4. Memory entry `project_docs_drift.md` has INVERTED LOGIC
- **Memory file**: `project_docs_drift.md`
- **Claim**: "CLAUDE.md claims `~/.ralph/episodes/` and `~/.ralph/procedural/` exist; they don't"
- **Reality**: BOTH directories EXIST. CLAUDE.md was correct. The memory entry is wrong.
- **Impact**: Drift report is itself the source of drift. Recursive failure.
- **Fix in**: Update memory entries (W4.4 scope)

### 5. Memory entry `project_repo_inventory.md` claims 22 wired / 65 dead hooks
- **Memory file**: `project_repo_inventory.md`
- **Claim**: "22 hooks WIRED in `~/.claude/settings.json` → 65 hooks are dead code"
- **Reality**: HOOKS_INVENTORY_2026-04-07.md shows 77 wired across 3 settings files. Only ~7 dead (now deleted). The 22-count looked only at one settings file.
- **Impact**: Core metric used to justify the MemPalace plan was inflated by ~9x. Plan is still valuable but the framing was off.
- **Fix in**: Update memory `project_repo_inventory.md` (W4.4)

---

## Memory Drift Section

Audited: `~/.claude/projects/-Users-alfredolopez-Documents-GitHub-multi-agent-ralph-loop/memory/`

| Memory File | Claim | Reality | Drift Type | Severity |
|-------------|-------|---------|------------|----------|
| `project_repo_inventory.md` | "87 hooks total" | HOOKS_INVENTORY shows 84 (3 already removed); W1.1 removed 7 more = now 77. | version-mismatch | medium |
| `project_repo_inventory.md` | "22 wired → 65 dead" | 77 wired / 7 dead. Inflated 9x by auditing 1 of 3 settings. | false-positive | **high** |
| `project_repo_inventory.md` | "Memory storage NOT existing: `~/.ralph/episodes/`" | EXISTS — thousands of dirs | false-positive | **high** |
| `project_repo_inventory.md` | "Memory storage NOT existing: `~/.ralph/procedural/rules.json`" | EXISTS — file + backups | false-positive | **high** |
| `project_docs_drift.md` | "Directory does NOT exist" for `~/.ralph/episodes/` | EXISTS | false-positive | **high** |
| `project_docs_drift.md` | "File does NOT exist" for `~/.ralph/procedural/rules.json` | EXISTS | false-positive | **high** |
| `project_config_locations.md` | "`~/.claude-sneakpeek/zai/config/settings.json` — DOES NOT EXIST" | Confirmed does not exist. Memory CORRECT. | no drift | — |
| `project_config_locations.md` | "`~/.claude/settings.json` — 19KB, last mod 2026-03-24, has 85 hook entries" | Outdated (hooks added since March). | version-mismatch | low |
| MEMORY.md index | "project_docs_drift.md — CLAUDE.md claims X exist; they don't" | CLAUDE.md was CORRECT. The drift entry has logic INVERTED. | contradictory | **high** |

---

## Verified Correct Claims

- `~/.ralph/ledgers/` — EXISTS
- `~/.ralph/handoffs/` — EXISTS
- `~/.ralph/memory/semantic.json` — EXISTS
- `~/.ralph/plans/` — EXISTS (3 plans)
- `~/.claude/settings.json` — EXISTS and active
- `~/.cc-mirror/minimax/config/settings.json` — EXISTS and active
- `.claude/rules/learned/*.md` — 9 files exist
- `.claude/skills/task-classifier/SKILL.md` — EXISTS
- `tests/security/` — EXISTS
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — SET in both settings.json files

---

## Audit Methodology

- Read all 5 CLAUDE.md files in full
- Read both active settings.json files in full
- Checked key directory existence via Glob
- Cross-referenced with HOOKS_INVENTORY_2026-04-07.md (W1.1 output)
- Cross-referenced with plan file realidad-verificada table
- Read 3 memory sub-files

---

## Recommendation for W4.4 (docs-update)

1. **Reconcile the 3 CLAUDE.md files** on which `settings.json` is canonical. Pick ONE primary, document the OTHERS as fallbacks/mirrors.
2. **Delete dead instructions** about `~/.claude-sneakpeek/` from `~/CLAUDE.md`.
3. **Update memory entries** to reflect filesystem reality (episodes/, procedural/, hook counts).
4. **Locate or create** `docs/analysis/MEMPALACE_COMPARISON.md` if still needed.
5. **Reconcile version tags** across all CLAUDE.md files (currently v3.0.0 and v3.1.0 coexist).
6. **Re-audit `~/.claude/rules/` symlinks** (deferred to W5.0).

---

*Generated by ralph-reviewer-alpha (Wave 1.5), feat/mempalace-adoption, 2026-04-07*
*Constraint: READ ONLY — no drift corrected. Fixes deferred to W4.4.*
