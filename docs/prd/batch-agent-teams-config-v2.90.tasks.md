# Batch: agent-teams-config-v2.90

**Created**: 2026-02-15
**Config**: stop_on_failure=false, auto_commit=true

## Tasks

### Phase 1: Claude-Mem Full Configuration

1. [P1] Add missing claude-mem Stop hooks to settings.json
   - Files: ~/.claude/settings.json
   - Criteria: Stop hooks contain 3 claude-mem hooks before ralph hooks, JSON valid

2. [P1] Add missing smart-install.js hook to SessionStart
   - Files: ~/.claude/settings.json
   - Criteria: smart-install.js first in SessionStart, timeout=300, JSON valid

3. [P1] Add CLAUDE_MEM_ROOT environment variable
   - Files: ~/.claude/settings.json
   - Criteria: CLAUDE_MEM_ROOT in env block pointing to plugin cache dir

4. [P2] Validate claude-mem MCP tools (5 tools)
   - Files: runtime validation
   - Criteria: All 5 MCP tools respond, search/save/timeline/get_observations functional
   - Depends on: 2, 3

5. [P2] Validate claude-mem context injection in CLAUDE.md
   - Files: CLAUDE.md, .claude/CLAUDE.md
   - Criteria: Context blocks exist, recent activity present, no worker errors
   - Depends on: 1

6. [P2] Validate claude-mem auto-learning integration
   - Files: ~/.claude-mem/claude-mem.db
   - Criteria: Recent observations exist, correct types, vector search works
   - Depends on: 4

### Phase 2: CC-Mirror Configuration Sync

7. [P1] Sync zai/config/settings.json (all non-env fields)
   - Files: ~/.cc-mirror/zai/config/settings.json
   - Criteria: hooks/permissions/plugins/statusLine synced, env preserved, JSON valid

8. [P1] Sync minimax/config/settings.json (all non-env fields)
   - Files: ~/.cc-mirror/minimax/config/settings.json
   - Criteria: hooks/permissions/plugins/statusLine synced, env preserved, JSON valid

9. [P1] Create skills symlinks (zai + minimax -> ~/.claude/skills/)
   - Files: ~/.cc-mirror/zai/config/skills, ~/.cc-mirror/minimax/config/skills
   - Criteria: Symlinks resolve, 1852+ skills visible, backup of originals

10. [P1] Sync plugins directories (cache symlinks)
    - Files: ~/.cc-mirror/zai/config/plugins/cache, ~/.cc-mirror/minimax/config/plugins/cache
    - Criteria: Symlinks resolve, claude-mem accessible from both

11. [P2] Add CLAUDE.md to variant config dirs
    - Files: ~/.cc-mirror/zai/config/CLAUDE.md, ~/.cc-mirror/minimax/config/CLAUDE.md
    - Criteria: Symlinks to project CLAUDE.md resolve correctly

12. [P2] Programmatic validation of variant configs
    - Files: tests/integration/test_cc_mirror_sync.sh
    - Criteria: Script exits 0, all fields match, symlinks resolve
    - Depends on: 7, 8, 9, 10, 11

### Phase 3: Comprehensive Validation

13. [P1] Run all unit tests (pytest, bats, shell)
    - Files: tests/
    - Criteria: All pass or documented known failures
    - Depends on: Phase 1 + Phase 2

14. [P1] Run integration and e2e tests
    - Files: tests/end-to-end/, tests/integration/
    - Criteria: All pass or documented known failures
    - Depends on: 13

15. [P1] Run pre-commit validation
    - Files: .git/hooks/pre-commit
    - Criteria: Exit 0, no format/unification violations
    - Depends on: 14

16. [P2] Run /adversarial validation
    - Criteria: No critical findings, no exposed secrets
    - Depends on: 15

17. [P2] Run /codex-cli validation
    - Criteria: Critical/high findings fixed
    - Depends on: 15

18. [P2] Run /gemini-cli validation
    - Criteria: Critical findings fixed, coverage gaps documented
    - Depends on: 15

19. [P3] Fix all findings from reviews (16-18)
    - Files: docs/audits/BATCH_VALIDATION_v2.90.md
    - Criteria: All critical/high resolved, tracking doc created, no regressions
    - Depends on: 16, 17, 18

## Execution Order

1. Tasks 1, 2, 3 (parallel)
2. Task 4 (after 2, 3)
3. Tasks 5, 6 (after 1, 4)
4. Tasks 7, 8, 9, 10, 11 (parallel, can overlap with Phase 1 P2 tasks)
5. Task 12 (after 7-11)
6. Task 13 (after Phase 1 + Phase 2)
7. Task 14 (after 13)
8. Task 15 (after 14)
9. Tasks 16, 17, 18 (parallel, after 15)
10. Task 19 (after 16-18)
