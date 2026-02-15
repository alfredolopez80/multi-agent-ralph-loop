# Feature: Agent Teams Batch - Claude-Mem + CC-Mirror Config + Full Validation

**Created**: 2026-02-15
**Version**: 2.90
**Timeframe**: Single session (Agent Teams batch)

## Priority: CRITICAL

## Overview

Three-phase batch execution to: (1) fully configure and validate claude-mem integration, (2) synchronize cc-mirror variant configs (zai/minimax) with the primary ~/.claude/ configuration, and (3) run comprehensive test validation with adversarial, codex-cli, and gemini-cli review.

---

## Phase 1: Claude-Mem Full Configuration and Validation

### Context & Analysis

**Current State:**
- Plugin installed: `~/.claude/plugins/cache/thedotmack/claude-mem/10.0.6/`
- Worker service: RUNNING (http://localhost:37777/health returns `{"status":"ok"}`)
- Data directory: `~/.claude-mem/` with SQLite DB (344MB), vector-db, settings.json
- Plugin enabled in settings.json: `"claude-mem@thedotmack": true`
- Permission granted: `"claude-mem@thedotmack": true` in permissions

**Hooks Registered (current settings.json):**
- SessionStart: `worker-service.cjs start` + `hook claude-code context` -- OK
- UserPromptSubmit: `worker-service.cjs start` + `hook claude-code session-init` -- OK
- PostToolUse: `worker-service.cjs start` + `hook claude-code observation` -- OK

**MISSING Hooks (per hooks.json reference):**
- Stop: `hook claude-code summarize` -- MISSING
- Stop: `hook claude-code session-complete` -- MISSING
- SessionStart: `smart-install.js` -- MISSING (dependency checker)

**Missing Environment Variables:**
- `CLAUDE_MEM_ROOT` not set in `~/.claude/settings.json` env block
- `CLAUDE_PLUGIN_ROOT` not set (used by hooks.json internally)

**MCP Search Tools Status:**
- 5 MCP tools available: search, timeline, get_observations, save_memory, __IMPORTANT
- Need validation that all 5 tools are accessible and functional

---

## Tasks

### Task 1 - [P1] Add missing claude-mem Stop hooks to settings.json

**Description**: Add the three missing claude-mem hooks to the Stop event in `~/.claude/settings.json`:
1. `worker-service.cjs start` (ensure worker is alive)
2. `worker-service.cjs hook claude-code summarize` (session summarization)
3. `bun-runner.js worker-service.cjs hook claude-code session-complete` (session completion)

These hooks MUST be added BEFORE the existing Ralph Stop hooks (reflection-engine, orchestrator-report, session-end-handoff) so claude-mem captures the session state before Ralph's own session-end processing.

**Files**:
- `~/.claude/settings.json` (Stop hooks section)

**Completion Criteria**:
- [ ] Stop hooks contain all 3 claude-mem hooks
- [ ] claude-mem hooks appear BEFORE ralph hooks in the Stop array
- [ ] Validate JSON is valid: `python3 -c "import json; json.load(open('$HOME/.claude/settings.json'))"`
- [ ] Worker correctly responds to summarize command: `bun ~/.claude/plugins/cache/thedotmack/claude-mem/10.0.6/scripts/worker-service.cjs hook claude-code summarize`

**Verification**: command

---

### Task 2 - [P1] Add missing smart-install.js hook to SessionStart

**Description**: Add the `smart-install.js` hook as the FIRST hook in the SessionStart wildcard matcher (before the worker-service start). This ensures dependencies are checked/installed before the worker starts.

Command: `/Users/alfredolopez/.bun/bin/bun "/Users/alfredolopez/.claude/plugins/cache/thedotmack/claude-mem/10.0.6/scripts/smart-install.js"`

**Files**:
- `~/.claude/settings.json` (SessionStart hooks section)

**Completion Criteria**:
- [ ] smart-install.js hook is present in SessionStart, before worker-service start
- [ ] Hook timeout set to 300 (per hooks.json spec)
- [ ] JSON validates cleanly
- [ ] Run smart-install.js manually to verify: `node ~/.claude/plugins/cache/thedotmack/claude-mem/10.0.6/scripts/smart-install.js`

**Verification**: command

---

### Task 3 - [P1] Add CLAUDE_MEM_ROOT environment variable

**Description**: Add the `CLAUDE_MEM_ROOT` environment variable to `~/.claude/settings.json` env block. This variable is used by the worker service and hooks to locate the claude-mem plugin root directory.

Value: `/Users/alfredolopez/.claude/plugins/cache/thedotmack/claude-mem/10.0.6`

**Files**:
- `~/.claude/settings.json` (env section)

**Completion Criteria**:
- [ ] `CLAUDE_MEM_ROOT` key exists in the env block
- [ ] Value points to the correct plugin cache directory
- [ ] JSON validates cleanly

**Verification**: code_contains, pattern: `CLAUDE_MEM_ROOT`

---

### Task 4 - [P2] Validate claude-mem MCP tools are accessible

**Description**: Verify all 5 MCP search tools provided by claude-mem are accessible and functional:
1. `mcp__plugin_claude-mem_mcp-search__search` - Compact index queries
2. `mcp__plugin_claude-mem_mcp-search__timeline` - Chronological retrieval
3. `mcp__plugin_claude-mem_mcp-search__get_observations` - Full observation details
4. `mcp__plugin_claude-mem_mcp-search__save_memory` - Manual memory storage
5. `mcp__plugin_claude-mem_mcp-search____IMPORTANT` - Workflow documentation

Test each tool programmatically to confirm functionality.

**Files**:
- None (runtime validation only)

**Completion Criteria**:
- [ ] Each MCP tool responds without errors when invoked via ToolSearch
- [ ] `search` tool returns results for a known query
- [ ] `save_memory` tool can write and the saved memory is retrievable
- [ ] `timeline` returns chronological entries
- [ ] `get_observations` returns detail for a known observation ID

**Verification**: command

---

### Task 5 - [P2] Validate claude-mem context injection in CLAUDE.md files

**Description**: Verify that claude-mem's context hook (`hook claude-code context`) is correctly injecting `<claude-mem-context>` blocks into CLAUDE.md files. Check that:
1. The project CLAUDE.md has the context block
2. The global ~/.claude/CLAUDE.md has the context block (if applicable)
3. Context blocks contain recent activity (not "*No recent activity*" everywhere)

If context injection is not working, investigate the worker logs at `~/.claude-mem/logs/` for errors.

**Files**:
- `/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/CLAUDE.md`
- `/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/CLAUDE.md`
- `~/.claude-mem/logs/` (for troubleshooting)

**Completion Criteria**:
- [ ] `<claude-mem-context>` blocks exist in at least 2 CLAUDE.md files
- [ ] At least one context block shows recent activity (not all empty)
- [ ] Worker logs show no ERROR-level entries in the last 24 hours
- [ ] Context hook completes within 60 seconds

**Verification**: file_exists + command

---

### Task 6 - [P2] Validate claude-mem auto-learning integration

**Description**: Verify the PostToolUse observation hook is correctly capturing observations during tool use. The hook `hook claude-code observation` should be firing after every tool use and storing observations in the SQLite database.

Test by:
1. Checking recent observations in the DB via the MCP search tool
2. Verifying the observation count is growing (not stale)
3. Confirming observation types match settings: `bugfix,feature,refactor,discovery,decision,change`

**Files**:
- `~/.claude-mem/claude-mem.db` (read-only query)
- `~/.claude-mem/settings.json` (verify CLAUDE_MEM_CONTEXT_OBSERVATION_TYPES)

**Completion Criteria**:
- [ ] Recent observations exist (within last hour of active session)
- [ ] Observations contain correct types from settings
- [ ] Vector search returns semantic results for known queries
- [ ] No duplicate observations for the same tool use event

**Verification**: command

---

## Phase 2: CC-Mirror Configuration Synchronization

### Context & Analysis

**Current State:**
- `~/.cc-mirror/zai/config/settings.json` - Has env vars, minimal permissions, NO hooks/plugins/statusLine
- `~/.cc-mirror/minimax/config/settings.json` - Has env vars, minimal permissions, NO hooks/plugins/statusLine
- `~/.cc-mirror/zai/config/skills/` - Has 3 native skills (dev-browser, orchestration, task-manager), NOT symlinked to ~/.claude/skills
- `~/.cc-mirror/minimax/config/skills/` - Does NOT exist
- `~/.cc-mirror/zai/config/plugins/` - Has known_marketplaces.json + marketplaces dir, NOT synced
- `~/.cc-mirror/minimax/config/plugins/` - Has known_marketplaces.json + marketplaces dir, NOT synced

**Security Note**: The zai and minimax settings.json files contain API keys. These MUST NOT be committed to git. The `env` block should be excluded from synchronization.

**Target State:**
- Both variants get: hooks, permissions, enabledPlugins, statusLine, outputStyle, language, alwaysThinkingEnabled, plansDirectory, skipDangerousModePermissionPrompt, mcpToolSearchMode from `~/.claude/settings.json`
- Skills directories symlinked to `~/.claude/skills/` (or to repo skills)
- Plugins directories symlinked to `~/.claude/plugins/`
- CLAUDE.md copied/symlinked for context

---

### Task 7 - [P1] Synchronize zai/config/settings.json with primary settings

**Description**: Merge all non-env fields from `~/.claude/settings.json` into `~/.cc-mirror/zai/config/settings.json`. The `env` block in zai MUST be preserved as-is (contains provider-specific API keys and model routing).

Fields to copy:
- `permissions` (merge with existing, preserve zai-specific deny entries like WebSearch, WebFetch)
- `hooks` (entire block)
- `enabledPlugins` (entire block)
- `statusLine` (entire block)
- `outputStyle`
- `language`
- `alwaysThinkingEnabled`
- `plansDirectory`
- `skipDangerousModePermissionPrompt`
- `mcpToolSearchMode`

**Files**:
- `~/.cc-mirror/zai/config/settings.json`

**Completion Criteria**:
- [ ] All non-env fields from primary settings present in zai settings
- [ ] zai `env` block unchanged (API keys, model routing preserved)
- [ ] zai-specific deny entries preserved (WebSearch, WebFetch)
- [ ] JSON validates cleanly
- [ ] `python3 -c "import json; json.load(open('$HOME/.cc-mirror/zai/config/settings.json'))"`

**Verification**: command

---

### Task 8 - [P1] Synchronize minimax/config/settings.json with primary settings

**Description**: Same as Task 7 but for minimax. Merge all non-env fields from `~/.claude/settings.json` into `~/.cc-mirror/minimax/config/settings.json`. Preserve minimax env block and minimax-specific deny entries.

**Files**:
- `~/.cc-mirror/minimax/config/settings.json`

**Completion Criteria**:
- [ ] All non-env fields from primary settings present in minimax settings
- [ ] minimax `env` block unchanged
- [ ] minimax-specific deny entries preserved (WebSearch)
- [ ] JSON validates cleanly

**Verification**: command

---

### Task 9 - [P1] Create skills symlinks for zai and minimax

**Description**: Replace the native skills directories in zai/config/skills and create minimax/config/skills, both symlinked to `~/.claude/skills/` so all variants share the same skill set (1852 skills).

Steps:
1. Back up existing `~/.cc-mirror/zai/config/skills/` to `~/.cc-mirror/zai/config/skills.bak/`
2. Remove `~/.cc-mirror/zai/config/skills/`
3. Create symlink: `ln -sf ~/.claude/skills ~/.cc-mirror/zai/config/skills`
4. Create symlink: `ln -sf ~/.claude/skills ~/.cc-mirror/minimax/config/skills`
5. Verify symlinks point to correct target

**Files**:
- `~/.cc-mirror/zai/config/skills` (symlink)
- `~/.cc-mirror/minimax/config/skills` (symlink)

**Completion Criteria**:
- [ ] `~/.cc-mirror/zai/config/skills` is a symlink to `~/.claude/skills`
- [ ] `~/.cc-mirror/minimax/config/skills` is a symlink to `~/.claude/skills`
- [ ] `ls ~/.cc-mirror/zai/config/skills/ | wc -l` returns 1852+
- [ ] `ls ~/.cc-mirror/minimax/config/skills/ | wc -l` returns 1852+
- [ ] Original zai skills backed up in skills.bak

**Verification**: command

---

### Task 10 - [P1] Synchronize plugins directories for zai and minimax

**Description**: Ensure zai and minimax plugin directories have access to the same plugins as `~/.claude/plugins/`. Create symlinks for the `cache` subdirectory (which contains the actual plugin installations).

Steps:
1. Symlink plugin cache: `ln -sf ~/.claude/plugins/cache ~/.cc-mirror/zai/config/plugins/cache`
2. Symlink plugin cache: `ln -sf ~/.claude/plugins/cache ~/.cc-mirror/minimax/config/plugins/cache`
3. Copy `known_marketplaces.json` from `~/.claude/plugins/` if it differs

**Files**:
- `~/.cc-mirror/zai/config/plugins/cache` (symlink)
- `~/.cc-mirror/minimax/config/plugins/cache` (symlink)

**Completion Criteria**:
- [ ] Plugin cache symlinks exist and point to `~/.claude/plugins/cache`
- [ ] `ls ~/.cc-mirror/zai/config/plugins/cache/thedotmack/claude-mem/` shows 10.0.6
- [ ] `ls ~/.cc-mirror/minimax/config/plugins/cache/thedotmack/claude-mem/` shows 10.0.6

**Verification**: command

---

### Task 11 - [P2] Add CLAUDE.md to zai and minimax config dirs

**Description**: Create CLAUDE.md files (or symlinks) in the zai and minimax config directories so that context injection works for those variants too.

Options (prefer symlink):
- `ln -sf ~/Documents/GitHub/multi-agent-ralph-loop/CLAUDE.md ~/.cc-mirror/zai/config/CLAUDE.md`
- `ln -sf ~/Documents/GitHub/multi-agent-ralph-loop/CLAUDE.md ~/.cc-mirror/minimax/config/CLAUDE.md`

**Files**:
- `~/.cc-mirror/zai/config/CLAUDE.md` (symlink)
- `~/.cc-mirror/minimax/config/CLAUDE.md` (symlink)

**Completion Criteria**:
- [ ] CLAUDE.md exists in both variant config dirs
- [ ] Content matches the project CLAUDE.md
- [ ] Symlinks resolve correctly

**Verification**: file_exists

---

### Task 12 - [P2] Programmatic validation of variant configurations

**Description**: Write and execute a validation script that confirms both variants (zai, minimax) have identical non-env configuration to the primary `~/.claude/settings.json`. The script should:

1. Load all three settings files
2. Compare hooks, permissions, enabledPlugins, statusLine fields
3. Verify skills symlinks resolve correctly
4. Verify plugins cache symlinks resolve correctly
5. Run a simple skill invocation test (e.g., check that `/adversarial` skill file is accessible from each variant's skills dir)

**Files**:
- `tests/integration/test_cc_mirror_sync.sh` (new validation script)

**Completion Criteria**:
- [ ] Validation script exits 0
- [ ] All non-env fields match between primary and variants
- [ ] Symlinks for skills and plugins resolve correctly
- [ ] At least one skill (adversarial) accessible from both variants

**Verification**: command

---

## Phase 3: Comprehensive Test Validation

### Task 13 - [P1] Run all unit tests

**Description**: Execute all unit tests in the repository. This includes:
- Python tests: `pytest tests/ -v`
- Bash tests (bats): `bats tests/*.bats`
- Shell tests: `bash tests/run_tests.sh` or `bash tests/run-all-unit-tests.sh`
- Skills tests: `bash tests/skills/test-task-batch.sh`, `bash tests/skills/test-create-task-batch.sh`

Collect and report all failures. Fix any that are caused by the configuration changes in Phase 1 and Phase 2.

**Files**:
- `tests/` (all test files)

**Completion Criteria**:
- [ ] All Python tests pass or have documented known failures
- [ ] All BATS tests pass or have documented known failures
- [ ] All shell tests pass or have documented known failures
- [ ] Skills tests pass
- [ ] No test failures caused by Phase 1/2 changes

**Verification**: command

---

### Task 14 - [P1] Run integration and end-to-end tests

**Description**: Execute all integration and e2e tests:
- `tests/end-to-end/`
- `tests/integration/`
- `tests/hook-integration/`
- `tests/agent-teams/`
- `tests/session-lifecycle/`
- `tests/security/`
- `tests/test_all_integration.sh`

Fix any failures caused by configuration changes.

**Files**:
- `tests/end-to-end/`
- `tests/integration/`
- `tests/hook-integration/`

**Completion Criteria**:
- [ ] Integration tests exit 0 or have documented known failures
- [ ] E2E tests exit 0 or have documented known failures
- [ ] Security tests pass
- [ ] Agent Teams tests pass
- [ ] No test failures caused by Phase 1/2 changes

**Verification**: command

---

### Task 15 - [P1] Run pre-commit validation

**Description**: Execute the pre-commit hook to validate hooks, skills, and architecture:
```bash
bash .git/hooks/pre-commit
```

This validates:
1. Hook JSON format (PostToolUse/PreToolUse/UserPromptSubmit use `{"continue": true/false}`, Stop hooks use `{"decision": "approve"/"block"}`)
2. Skills unification
3. Architecture documentation

Fix all failures.

**Files**:
- `.git/hooks/pre-commit`

**Completion Criteria**:
- [ ] Pre-commit hook exits 0
- [ ] No hook format violations
- [ ] No skills unification issues
- [ ] No architecture validation errors

**Verification**: command

---

### Task 16 - [P2] Run /adversarial validation

**Description**: Execute the adversarial validation skill against the configuration changes made in Phase 1 and Phase 2. This includes:
- Security review of settings.json changes
- Hook chain validation
- Configuration integrity checks
- Attack surface analysis of symlink changes

Focus areas:
- Are API keys properly protected in variant configs?
- Do symlinks introduce path traversal risks?
- Are hook permissions correctly scoped?

**Files**:
- Adversarial skill output

**Completion Criteria**:
- [ ] Adversarial review completes without critical findings
- [ ] All security recommendations addressed or documented
- [ ] No exposed secrets in any config file tracked by git
- [ ] Symlink targets validated as safe

**Verification**: manual_review

---

### Task 17 - [P2] Run /codex-cli validation

**Description**: Execute the codex-cli validation skill to review the codebase for:
- Code quality issues
- Unused imports/variables
- Potential bugs
- Configuration inconsistencies

Fix all critical and high-severity findings.

**Files**:
- Codex-cli skill output

**Completion Criteria**:
- [ ] Codex-cli review completes
- [ ] All critical findings fixed
- [ ] All high-severity findings fixed or documented
- [ ] Medium/low findings documented for future resolution

**Verification**: manual_review

---

### Task 18 - [P2] Run /gemini-cli validation

**Description**: Execute the gemini-cli validation skill for an external perspective on:
- Architecture consistency
- Configuration completeness
- Test coverage gaps
- Documentation accuracy

Fix all critical findings.

**Files**:
- Gemini-cli skill output

**Completion Criteria**:
- [ ] Gemini-cli review completes
- [ ] All critical findings fixed
- [ ] Test coverage gaps identified and documented
- [ ] Documentation inaccuracies corrected

**Verification**: manual_review

---

### Task 19 - [P3] Fix all findings from adversarial/codex/gemini reviews

**Description**: Consolidate and fix all findings, issues, and recommendations from Tasks 16-18. Create a tracking document with:
- Finding ID
- Severity
- Source (adversarial/codex/gemini)
- Status (fixed/deferred/wontfix)
- Resolution details

**Files**:
- `docs/audits/BATCH_VALIDATION_v2.90.md` (new tracking document)
- Various source files as needed for fixes

**Completion Criteria**:
- [ ] All critical findings resolved
- [ ] All high findings resolved or mitigated
- [ ] Tracking document created with full audit trail
- [ ] No regressions introduced by fixes (re-run tests)

**Verification**: file_exists + command (re-run tests)

---

## Dependencies

```
Phase 1 (claude-mem):
  Task 1 (Stop hooks) -> Task 5 (context validation)
  Task 2 (smart-install) -> Task 4 (MCP validation)
  Task 3 (env vars) -> Task 4 (MCP validation)
  Task 4 (MCP tools) -> Task 6 (auto-learning)

Phase 2 (cc-mirror):
  Task 7 (zai settings) -> Task 12 (validation)
  Task 8 (minimax settings) -> Task 12 (validation)
  Task 9 (skills symlinks) -> Task 12 (validation)
  Task 10 (plugins symlinks) -> Task 12 (validation)
  Task 11 (CLAUDE.md) -> Task 12 (validation)

Phase 3 (testing):
  Phase 1 + Phase 2 -> Task 13 (unit tests)
  Task 13 -> Task 14 (integration tests)
  Task 14 -> Task 15 (pre-commit)
  Task 15 -> Task 16 (adversarial)
  Task 15 -> Task 17 (codex-cli)
  Task 15 -> Task 18 (gemini-cli)
  Tasks 16-18 -> Task 19 (fix findings)
```

## Execution Order

1. Tasks 1, 2, 3 (parallel - Phase 1 config)
2. Task 4 (after 2, 3)
3. Tasks 5, 6 (after 1, 4)
4. Tasks 7, 8, 9, 10, 11 (parallel - Phase 2 config, can start after Phase 1)
5. Task 12 (after 7-11)
6. Task 13 (after Phase 1 + Phase 2)
7. Task 14 (after 13)
8. Task 15 (after 14)
9. Tasks 16, 17, 18 (parallel - after 15)
10. Task 19 (after 16-18)

## Technical Notes

- **SECURITY**: API keys in zai/minimax settings.json MUST NOT be committed to git. The `.cc-mirror/` directory should be in `.gitignore`.
- **Symlinks**: Use `-sf` flag for symlinks to force-overwrite if target exists.
- **JSON Editing**: Since settings.json is in the deny list for Write/Edit, use `python3 -c` or `jq` for programmatic edits, or temporarily adjust permissions.
- **Bun Runtime**: claude-mem hooks use bun, not node. Path: `/Users/alfredolopez/.bun/bin/bun`
- **Hook Order Matters**: claude-mem hooks should run before Ralph hooks in Stop event to capture session state first.
- **Worker Health**: Always check `curl -s http://localhost:37777/health` before running claude-mem commands.

## Risks

- Settings.json Write/Edit is denied in permissions - may need temporary override
- Symlink changes could break variant-specific skill behavior
- Large test suite (80+ test files) may have pre-existing failures unrelated to this batch
- claude-mem worker restart may be needed after settings changes
- API keys in variant configs could be accidentally exposed if .cc-mirror is not gitignored

## Acceptance Criteria (Batch-Level)

1. **claude-mem is 100% configured**: All 5 hook events registered, all 5 MCP tools functional, context injection working, auto-learning capturing observations
2. **cc-mirror variants synchronized**: zai and minimax have identical non-env settings to primary, shared skills/plugins via symlinks, CLAUDE.md accessible
3. **All tests pass**: Unit, integration, e2e, pre-commit all green (or known failures documented)
4. **External reviews complete**: adversarial, codex-cli, gemini-cli reviews done, all critical/high findings resolved

---

## Execution Command

```bash
/task-batch docs/prd/batch-agent-teams-config-v2.90.prq.md
```
