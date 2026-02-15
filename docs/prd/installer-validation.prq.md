# Feature: Installer & Configuration Validation Suite

**Created**: 2026-02-15
**Version**: 2.88.0
**Timeframe**: Multi-session
**Priority**: Critical

## Overview

Comprehensive validation suite to ensure multi-agent-ralph-loop installer works correctly and all hooks, skills, and configuration are properly set up in Claude Code global configuration (`~/.claude/settings.json`).

---

## PHASE 1: INSTALLER ENVIRONMENT VALIDATION

### Task 1.1: System Dependencies Validator

**Priority**: P1
**Estimated Time**: 2-3 hours

**Description**:
Create comprehensive validation for all system tools and dependencies required by multi-agent-ralph-loop to function at 100%.

**Required Tools to Validate**:

| Category | Tool | Required | Purpose |
|----------|------|----------|---------|
| Core | `bash` >= 4.0 | YES | Shell execution |
| Core | `jq` | YES | JSON parsing |
| Core | `curl` | YES | HTTP requests |
| Core | `git` >= 2.0 | YES | Version control |
| Runtime | `node` >= 18 | Optional | TypeScript/ESLint |
| Runtime | `python3` >= 3.9 | Optional | Python tools |
| Runtime | `bun` | Optional | claude-mem plugin |
| Linter | `npx` | Optional | npm executor |
| Linter | `pyright` | Optional | Python types |
| Linter | `ruff` | Optional | Python linter |
| Security | `semgrep` | Optional | Security scanning |
| Security | `gitleaks` | Optional | Secret detection |
| CLI | `claude` | Recommended | Claude Code |
| CLI | `gh` | Recommended | GitHub CLI |
| CLI | `bats` | Recommended | Bash testing |

**Files to Create/Modify**:
- `tests/installer/test-system-dependencies.bats` (new)
- `scripts/validate-system-requirements.sh` (new)

**Acceptance Criteria**:
- [ ] All required tools checked with version validation
- [ ] Optional tools checked with warning (not error) if missing
- [ ] Version minimum requirements validated
- [ ] Clear report of missing/invalid tools
- [ ] Exit code 0 if all required pass, non-zero otherwise
- [ ] JSON output option for programmatic use

**Verification Method**:
```bash
# Run unit tests
bats tests/installer/test-system-dependencies.bats

# Run script
./scripts/validate-system-requirements.sh --format json
```

---

### Task 1.2: Shell Environment Validator

**Priority**: P1
**Estimated Time**: 1-2 hours

**Description**:
Validate shell environment configuration including PATH, aliases, and environment variables.

**Checks**:
- PATH contains `~/.local/bin`
- Shell rc file (.zshrc/.bashrc) has Ralph markers
- All Ralph aliases are defined
- Environment variables for Claude Code are set

**Files to Create/Modify**:
- `tests/installer/test-shell-environment.bats` (new)
- `scripts/validate-shell-config.sh` (new)

**Acceptance Criteria**:
- [ ] Detects current shell (zsh/bash)
- [ ] Validates PATH configuration
- [ ] Validates Ralph section markers in rc file
- [ ] Validates all 16 Ralph aliases
- [ ] Validates MiniMax aliases
- [ ] Reports misconfigured items

**Verification Method**:
```bash
bats tests/installer/test-shell-environment.bats
./scripts/validate-shell-config.sh
```

---

### Task 1.3: Directory Structure Validator

**Priority**: P1
**Estimated Time**: 1 hour

**Description**:
Validate that all required directories are created with correct permissions.

**Required Directories**:
```
~/.local/bin/           # CLI scripts (755)
~/.ralph/               # Main data dir (700)
~/.ralph/config/        # Configuration (700)
~/.ralph/logs/          # Log files (700)
~/.ralph/memory/        # Memory storage (700)
~/.ralph/plans/         # Plan files (700)
~/.ralph/episodes/      # Episodic memory (700)
~/.ralph/ledgers/       # Session ledgers (700)
~/.ralph/handoffs/      # Session handoffs (700)
~/.ralph/improvements/  # Improvements (700)
~/.claude/              # Claude config (755)
~/.claude/agents/       # Agents (755)
~/.claude/commands/     # Commands (755)
~/.claude/skills/       # Skills (755)
~/.claude/hooks/        # Hooks (755)
```

**Files to Create/Modify**:
- `tests/installer/test-directory-structure.bats` (new)
- `scripts/validate-directories.sh` (new)

**Acceptance Criteria**:
- [ ] All directories exist
- [ ] Permissions are correct (security-sensitive dirs are 700)
- [ ] Ownership is correct (current user)
- [ ] Reports missing/incorrect directories

**Verification Method**:
```bash
bats tests/installer/test-directory-structure.bats
./scripts/validate-directories.sh
```

---

## PHASE 2: HOOKS CONFIGURATION VALIDATION

### Task 2.1: Hooks Registration Validator

**Priority**: P1
**Estimated Time**: 3-4 hours

**Description**:
Validate that all hooks are properly registered in `~/.claude/settings.json` and scripts exist and are executable.

**Hooks to Validate** (based on current settings.json):

| Event | Hook Script | Purpose |
|-------|-------------|---------|
| SessionStart | auto-migrate-plan-state.sh | Plan state migration |
| SessionStart | auto-sync-global.sh | Global sync |
| SessionStart | session-start-restore-context.sh | Context restore |
| SessionStart | orchestrator-init.sh | Orchestrator init |
| SessionStart | project-backup-metadata.sh | Backup metadata |
| SessionStart | session-start-repo-summary.sh | Repo summary |
| PreToolUse (Edit/Write) | checkpoint-auto-save.sh | Auto-save checkpoint |
| PreToolUse (Edit/Write) | smart-skill-reminder.sh | Skill reminder |
| PreToolUse (Bash) | git-safety-guard.py | Git safety |
| PreToolUse (Bash) | repo-boundary-guard.sh | Repo boundary |
| PreToolUse (Task) | lsa-pre-step.sh | LSA pre-step |
| PreToolUse (Task) | fast-path-check.sh | Fast path |
| PreToolUse (Task) | smart-memory-search.sh | Memory search |
| PreToolUse (Task) | skill-validator.sh | Skill validation |
| PreToolUse (Task) | procedural-inject.sh | Procedural inject |
| PreToolUse (Task) | checkpoint-smart-save.sh | Smart save |
| PreToolUse (Task) | orchestrator-auto-learn.sh | Auto learn |
| PreToolUse (Task) | promptify-security.sh | Security prompt |
| PreToolUse (Task) | inject-session-context.sh | Session context |
| PreToolUse (Task) | rules-injector.sh | Rules inject |
| Stop | reflection-engine.sh | Reflection |
| Stop | orchestrator-report.sh | Report |
| PostToolUse (Edit/Write/Bash) | sec-context-validate.sh | Security validate |
| PostToolUse (Edit/Write/Bash) | security-full-audit.sh | Full audit |
| PostToolUse (Edit/Write/Bash) | quality-gates-v2.sh | Quality gates |
| PostToolUse (Edit/Write/Bash) | decision-extractor.sh | Decision extract |
| PostToolUse (Edit/Write/Bash) | semantic-realtime-extractor.sh | Semantic extract |
| PostToolUse (Edit/Write/Bash) | plan-sync-post-step.sh | Plan sync |
| PostToolUse (Edit/Write/Bash) | glm-context-update.sh | Context update |
| PostToolUse (Edit/Write/Bash) | progress-tracker.sh | Progress track |
| PostToolUse (Edit/Write/Bash) | typescript-quick-check.sh | TypeScript check |
| PostToolUse (Edit/Write/Bash) | quality-parallel-async.sh | Parallel quality |
| PostToolUse (Edit/Write/Bash) | status-auto-check.sh | Status check |
| PostToolUse (Edit/Write/Bash) | console-log-detector.sh | Console detect |
| PostToolUse (Edit/Write/Bash) | ai-code-audit.sh | AI audit |
| PostToolUse (Task) | auto-background-swarm.sh | Background swarm |
| PostToolUse (Task) | parallel-explore.sh | Parallel explore |
| PostToolUse (Task) | recursive-decompose.sh | Recursive decompose |
| PostToolUse (Task) | adversarial-auto-trigger.sh | Adversarial |
| PostToolUse (Task) | code-review-auto.sh | Code review |
| PostToolUse (TodoWrite) | todo-plan-sync.sh | Todo sync |
| PreCompact | pre-compact-handoff.sh | Compact handoff |
| UserPromptSubmit | context-warning.sh | Context warning |
| UserPromptSubmit | command-router.sh | Command router |
| UserPromptSubmit | memory-write-trigger.sh | Memory trigger |
| UserPromptSubmit | periodic-reminder.sh | Periodic remind |
| UserPromptSubmit | plan-state-adaptive.sh | Plan adaptive |
| UserPromptSubmit | plan-state-lifecycle.sh | Plan lifecycle |
| SubagentStop | glm5-subagent-stop.sh | GLM5 stop |

**Files to Create/Modify**:
- `tests/installer/test-hooks-registration.bats` (new)
- `scripts/validate-hooks-registration.sh` (enhance existing)

**Acceptance Criteria**:
- [ ] All hooks registered in settings.json
- [ ] All hook scripts exist at specified paths
- [ ] All hook scripts are executable
- [ ] Hook paths use absolute paths
- [ ] No orphan hooks (scripts without registration)
- [ ] No missing hooks (registration without script)
- [ ] JSON validation for settings.json

**Verification Method**:
```bash
bats tests/installer/test-hooks-registration.bats
./scripts/validate-hooks-registration.sh --verbose
```

---

### Task 2.2: Hook Execution Validator

**Priority**: P1
**Estimated Time**: 4-5 hours

**Description**:
Test that each hook executes correctly without errors when triggered.

**Test Strategy**:
1. Create mock tool input for each hook type
2. Execute hook with mock input
3. Validate exit code and output
4. Check for common errors (missing deps, syntax errors)

**Files to Create/Modify**:
- `tests/installer/test-hooks-execution.bats` (new)
- `tests/installer/fixtures/mock-tool-inputs/` (new directory)
- `scripts/validate-hooks-execution.sh` (new)

**Acceptance Criteria**:
- [ ] Each hook tested individually
- [ ] Mock input provided for each hook type
- [ ] Exit code 0 for successful execution
- [ ] No stderr output (unless expected)
- [ ] Timeout handling for hanging hooks
- [ ] Report of failed hooks with error details

**Verification Method**:
```bash
bats tests/installer/test-hooks-execution.bats
./scripts/validate-hooks-execution.sh
```

---

### Task 2.3: Hook Script Syntax Validator

**Priority**: P2
**Estimated Time**: 1-2 hours

**Description**:
Validate syntax of all shell and Python hook scripts.

**Checks**:
- Shell scripts: `bash -n` syntax check
- Python scripts: `python3 -m py_compile`
- Common patterns validation (shebang, error handling)

**Files to Create/Modify**:
- `tests/installer/test-hooks-syntax.bats` (new)
- `scripts/validate-hooks-syntax.sh` (new)

**Acceptance Criteria**:
- [ ] All .sh files pass bash syntax check
- [ ] All .py files pass python compile check
- [ ] Report of syntax errors with line numbers
- [ ] Validates shebang exists and is correct

**Verification Method**:
```bash
bats tests/installer/test-hooks-syntax.bats
./scripts/validate-hooks-syntax.sh
```

---

## PHASE 3: SKILLS CONFIGURATION VALIDATION

### Task 3.1: Skills Registration Validator

**Priority**: P1
**Estimated Time**: 2-3 hours

**Description**:
Validate that all skills are properly installed and have valid SKILL.md files.

**Skills to Validate** (from .claude/skills/):
- orchestrator
- loop
- gates
- adversarial
- bugs
- security
- retrospective
- clarify
- curator
- curator-repo-learn
- task-batch
- create-task-batch
- research
- research-blockchain
- glm5
- glm5-parallel
- parallel
- plan
- prd
- audit
- deslop
- readme
- kaizen
- edd
- task-classifier
- checkpoint-manager
- code-reviewer
- quality-gates-parallel
- And ~150+ more skills

**Files to Create/Modify**:
- `tests/installer/test-skills-registration.bats` (new)
- `scripts/validate-skills-registration.sh` (new)

**Acceptance Criteria**:
- [ ] All skill directories exist in ~/.claude/skills/
- [ ] Each skill has SKILL.md or skill.md file
- [ ] SKILL.md has valid frontmatter (name, description)
- [ ] Symlinks from global to repo are valid (if applicable)
- [ ] Report of missing/invalid skills

**Verification Method**:
```bash
bats tests/installer/test-skills-registration.bats
./scripts/validate-skills-registration.sh --verbose
```

---

### Task 3.2: Skills Execution Validator

**Priority**: P2
**Estimated Time**: 3-4 hours

**Description**:
Test that core skills can be loaded without errors.

**Test Strategy**:
1. Test skill discovery/loading
2. Validate skill content is readable
3. Test skill invocation (dry-run where possible)

**Files to Create/Modify**:
- `tests/installer/test-skills-execution.bats` (new)
- `scripts/validate-skills-execution.sh` (new)

**Acceptance Criteria**:
- [ ] Core skills load without errors
- [ ] Skill descriptions are valid
- [ ] No circular dependencies
- [ ] Report of unloadable skills

**Verification Method**:
```bash
bats tests/installer/test-skills-execution.bats
```

---

## PHASE 4: AGENTS CONFIGURATION VALIDATION

### Task 4.1: Agents Registration Validator

**Priority**: P1
**Estimated Time**: 1-2 hours

**Description**:
Validate that all agent definitions are properly installed.

**Agents to Validate**:
- ralph-coder.md
- ralph-reviewer.md
- ralph-tester.md
- ralph-researcher.md

**Files to Create/Modify**:
- `tests/installer/test-agents-registration.bats` (new)
- `scripts/validate-agents-registration.sh` (new)

**Acceptance Criteria**:
- [ ] All agent files exist in ~/.claude/agents/
- [ ] Agent markdown is valid
- [ ] Agent has required fields (name, description, tools)
- [ ] Agent tools are valid Claude Code tools

**Verification Method**:
```bash
bats tests/installer/test-agents-registration.bats
./scripts/validate-agents-registration.sh
```

---

## PHASE 5: SETTINGS.JSON VALIDATION

### Task 5.1: Settings Structure Validator

**Priority**: P1
**Estimated Time**: 2-3 hours

**Description**:
Validate that settings.json has correct structure and all required fields.

**Required Fields**:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    // ... other env vars
  },
  "permissions": {
    "allow": [...],
    "deny": [...],
    "defaultMode": "delegate"
  },
  "hooks": {
    "SessionStart": [...],
    "PreToolUse": [...],
    "PostToolUse": [...],
    "Stop": [...],
    "PreCompact": [...],
    "UserPromptSubmit": [...],
    "SubagentStop": [...]
  },
  "statusLine": {...},
  "enabledPlugins": {...}
}
```

**Files to Create/Modify**:
- `tests/installer/test-settings-structure.bats` (new)
- `scripts/validate-settings-structure.sh` (new)

**Acceptance Criteria**:
- [ ] Valid JSON structure
- [ ] All required top-level keys present
- [ ] Hooks structure is correct
- [ ] Permissions structure is correct
- [ ] No duplicate hook entries
- [ ] JSON schema validation

**Verification Method**:
```bash
bats tests/installer/test-settings-structure.bats
./scripts/validate-settings-structure.sh
```

---

### Task 5.2: Settings Merge Validator

**Priority**: P1
**Estimated Time**: 2-3 hours

**Description**:
Validate that installer merge logic preserves user settings correctly.

**Test Scenarios**:
1. Fresh install (no existing settings)
2. Merge with existing settings (preserve user config)
3. Merge with Ralph already installed (update)
4. Invalid JSON in existing settings (backup and replace)

**Files to Create/Modify**:
- `tests/installer/test-settings-merge.bats` (new)
- `tests/installer/fixtures/settings-*.json` (new)

**Acceptance Criteria**:
- [ ] Fresh install creates correct settings
- [ ] Existing user settings preserved
- [ ] Ralph hooks added without duplicates
- [ ] Invalid JSON handled gracefully
- [ ] Backup created before modification

**Verification Method**:
```bash
bats tests/installer/test-settings-merge.bats
```

---

## PHASE 6: END-TO-END INTEGRATION TESTS

### Task 6.1: Full Installation E2E Test

**Priority**: P1
**Estimated Time**: 4-6 hours

**Description**:
Complete end-to-end test simulating fresh installation on a clean environment.

**Test Flow**:
1. Create temp test environment (simulate fresh home dir)
2. Run install.sh
3. Validate all components
4. Run uninstall.sh
5. Validate cleanup

**Files to Create/Modify**:
- `tests/installer/test-e2e-installation.bats` (new)
- `tests/installer/e2e-setup.sh` (new)
- `tests/installer/e2e-cleanup.sh` (new)

**Acceptance Criteria**:
- [ ] Installation completes without errors
- [ ] All components installed correctly
- [ ] All validation checks pass
- [ ] Uninstallation cleans up properly
- [ ] Idempotent (can run multiple times)

**Verification Method**:
```bash
bats tests/installer/test-e2e-installation.bats
```

---

### Task 6.2: Hook Chain Integration Test

**Priority**: P1
**Estimated Time**: 3-4 hours

**Description**:
Test that hooks fire correctly in sequence during typical Claude Code operations.

**Test Scenarios**:
1. Session start → SessionStart hooks fire
2. Edit file → PreToolUse/Edit hooks → PostToolUse hooks
3. Run bash → PreToolUse/Bash hooks → PostToolUse hooks
4. Create task → PreToolUse/Task hooks → PostToolUse hooks
5. Session end → Stop hooks

**Files to Create/Modify**:
- `tests/installer/test-hook-chain.bats` (new)
- `tests/installer/fixtures/hook-scenarios/` (new)

**Acceptance Criteria**:
- [ ] Hooks fire in correct order
- [ ] No hook conflicts
- [ ] Timeout handling works
- [ ] Error in one hook doesn't break chain

**Verification Method**:
```bash
bats tests/installer/test-hook-chain.bats
```

---

### Task 6.3: CLI Commands E2E Test

**Priority**: P2
**Estimated Time**: 2-3 hours

**Description**:
Test that all ralph CLI commands work after installation.

**Commands to Test**:
- `ralph help`
- `ralph orch --help`
- `ralph gates`
- `ralph curator`
- `ralph repo-learn --help`
- `mmc --help`

**Files to Create/Modify**:
- `tests/installer/test-cli-commands.bats` (new)

**Acceptance Criteria**:
- [ ] All commands return exit code 0
- [ ] Help text is displayed correctly
- [ ] Commands found in PATH
- [ ] No runtime errors

**Verification Method**:
```bash
bats tests/installer/test-cli-commands.bats
```

---

## PHASE 7: TEST INFRASTRUCTURE

### Task 7.1: BATS Test Framework Setup

**Priority**: P1
**Estimated Time**: 1-2 hours

**Description**:
Set up BATS (Bash Automated Testing System) for all installer tests.

**Setup Requirements**:
- Install bats-core
- Install bats-support (helpers)
- Install bats-assert (assertions)
- Create test helper library

**Files to Create/Modify**:
- `tests/installer/test_helper.bash` (new)
- `tests/installer/install-bats.sh` (new)

**Acceptance Criteria**:
- [ ] BATS installed and available
- [ ] Test helpers loaded correctly
- [ ] Sample test runs successfully

**Verification Method**:
```bash
./tests/installer/install-bats.sh
bats tests/installer/test_helper.bash
```

---

### Task 7.2: CI Integration

**Priority**: P2
**Estimated Time**: 2-3 hours

**Description**:
Create GitHub Actions workflow to run all installer tests on CI.

**Workflow Steps**:
1. Setup test environment
2. Install dependencies
3. Run all BATS tests
4. Generate test report
5. Upload artifacts on failure

**Files to Create/Modify**:
- `.github/workflows/test-installer.yml` (new)

**Acceptance Criteria**:
- [ ] Workflow runs on PR and push to main
- [ ] All tests executed
- [ ] Test results visible in PR checks
- [ ] Artifacts uploaded for debugging

**Verification Method**:
```bash
# Check workflow syntax
actionlint .github/workflows/test-installer.yml
```

---

### Task 7.3: Master Validation Script

**Priority**: P1
**Estimated Time**: 2-3 hours

**Description**:
Create a single master script that runs all validations.

**Features**:
- Run all validators in sequence
- Generate comprehensive report
- Exit with appropriate code
- JSON output option
- Quiet/verbose modes

**Files to Create/Modify**:
- `scripts/validate-installation.sh` (new)

**Usage**:
```bash
# Run all validations
./scripts/validate-installation.sh

# JSON output
./scripts/validate-installation.sh --format json

# Verbose mode
./scripts/validate-installation.sh --verbose

# Quick check (critical only)
./scripts/validate-installation.sh --quick
```

**Acceptance Criteria**:
- [ ] Runs all validation scripts
- [ ] Aggregates results
- [ ] Clear summary output
- [ ] JSON output for automation
- [ ] Exit code reflects overall status

**Verification Method**:
```bash
./scripts/validate-installation.sh
echo "Exit code: $?"
```

---

## Dependencies

```
Task 1.1 (System Deps) ──────┐
Task 1.2 (Shell Env)  ───────┤
Task 1.3 (Dir Struct) ───────┼──► Task 6.1 (E2E Install)
Task 2.1 (Hooks Reg)  ───────┤
Task 2.2 (Hooks Exec) ───────┤
Task 2.3 (Hooks Syntax) ─────┤
Task 3.1 (Skills Reg) ───────┤
Task 3.2 (Skills Exec) ───────┤
Task 4.1 (Agents Reg) ───────┤
Task 5.1 (Settings Struct) ──┤
Task 5.2 (Settings Merge) ───┤
Task 7.1 (BATS Setup) ───────┴──► All tests depend on this
Task 6.2 (Hook Chain) ───────────► Task 2.1, 2.2
Task 6.3 (CLI Commands) ─────────► Task 1.1
Task 7.2 (CI Integration) ───────► All tests
Task 7.3 (Master Script) ────────► All validation scripts
```

---

## Technical Notes

### Test File Naming Convention

```
tests/
├── installer/
│   ├── test-system-dependencies.bats
│   ├── test-shell-environment.bats
│   ├── test-directory-structure.bats
│   ├── test-hooks-registration.bats
│   ├── test-hooks-execution.bats
│   ├── test-hooks-syntax.bats
│   ├── test-skills-registration.bats
│   ├── test-skills-execution.bats
│   ├── test-agents-registration.bats
│   ├── test-settings-structure.bats
│   ├── test-settings-merge.bats
│   ├── test-e2e-installation.bats
│   ├── test-hook-chain.bats
│   ├── test-cli-commands.bats
│   ├── test_helper.bash
│   ├── install-bats.sh
│   ├── fixtures/
│   │   ├── mock-tool-inputs/
│   │   ├── settings-*.json
│   │   └── hook-scenarios/
│   ├── e2e-setup.sh
│   └── e2e-cleanup.sh
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All validations passed |
| 1 | One or more critical failures |
| 2 | Missing dependencies |
| 3 | Configuration error |
| 4 | Test execution error |

---

## Risks

1. **BATS Compatibility**: Different BATS versions may have different behavior
   - Mitigation: Pin BATS version in install script

2. **Environment Isolation**: Tests may affect user environment
   - Mitigation: Use temp directories, mock HOME

3. **Hook Side Effects**: Some hooks may have side effects during testing
   - Mitigation: Use --dry-run flags, mock external services

4. **Timeout Issues**: Some hooks may hang
   - Mitigation: Implement timeout handling in all tests

---

## Summary

| Phase | Tasks | Est. Time | Priority |
|-------|-------|-----------|----------|
| 1. Environment | 3 | 4-6 hours | P1 |
| 2. Hooks | 3 | 8-11 hours | P1 |
| 3. Skills | 2 | 5-7 hours | P1/P2 |
| 4. Agents | 1 | 1-2 hours | P1 |
| 5. Settings | 2 | 4-6 hours | P1 |
| 6. E2E Tests | 3 | 9-13 hours | P1/P2 |
| 7. Infrastructure | 3 | 5-8 hours | P1/P2 |
| **TOTAL** | **17** | **36-53 hours** | - |

---

## Execution Order

1. Task 7.1 (BATS Setup) - Foundation
2. Task 1.1-1.3 (Environment) - Core validations
3. Task 5.1-5.2 (Settings) - Configuration
4. Task 2.1-2.3 (Hooks) - Hook system
5. Task 3.1-3.2 (Skills) - Skills system
6. Task 4.1 (Agents) - Agents
7. Task 6.1-6.3 (E2E) - Integration
8. Task 7.2 (CI) - Automation
9. Task 7.3 (Master Script) - Final assembly
