# Batch: Installer & Configuration Validation Suite

**Created**: 2026-02-15
**Version**: 2.88.0
**Config**: stop_on_failure=false, auto_commit=true

## Execution Order

```
PHASE 0: Infrastructure Setup
  └── TASK-0.1: BATS Framework Setup

PHASE 1: Environment Validation
  ├── TASK-1.1: System Dependencies Validator
  ├── TASK-1.2: Shell Environment Validator
  └── TASK-1.3: Directory Structure Validator

PHASE 2: Hooks Validation
  ├── TASK-2.1: Hooks Registration Validator
  ├── TASK-2.2: Hooks Execution Validator
  └── TASK-2.3: Hooks Syntax Validator

PHASE 3: Skills Validation
  ├── TASK-3.1: Skills Registration Validator
  └── TASK-3.2: Skills Execution Validator

PHASE 4: Agents Validation
  └── TASK-4.1: Agents Registration Validator

PHASE 5: Settings Validation
  ├── TASK-5.1: Settings Structure Validator
  └── TASK-5.2: Settings Merge Validator

PHASE 6: End-to-End Tests
  ├── TASK-6.1: Full Installation E2E Test
  ├── TASK-6.2: Hook Chain Integration Test
  └── TASK-6.3: CLI Commands E2E Test

PHASE 7: Master Integration
  ├── TASK-7.1: Master Validation Script
  └── TASK-7.2: CI Integration
```

## Tasks Detail

### TASK-0.1: BATS Framework Setup
- **Priority**: P1
- **Time**: 1-2 hours
- **Files**:
  - `tests/installer/install-bats.sh`
  - `tests/installer/test_helper.bash`
- **Criteria**:
  - bats --version returns valid version
  - bats-support library installed
  - bats-assert library installed
  - test_helper.bash loads without errors

### TASK-1.1: System Dependencies Validator
- **Priority**: P1
- **Time**: 2-3 hours
- **Dependencies**: TASK-0.1
- **Files**:
  - `tests/installer/test-system-dependencies.bats`
  - `scripts/validate-system-requirements.sh`
- **Criteria**:
  - Test file exists and is executable
  - Validates required tools (bash, jq, curl, git)
  - Validates optional tools with warnings
  - All tests pass

### TASK-1.2: Shell Environment Validator
- **Priority**: P1
- **Time**: 1-2 hours
- **Dependencies**: TASK-0.1
- **Files**:
  - `tests/installer/test-shell-environment.bats`
  - `scripts/validate-shell-config.sh`
- **Criteria**:
  - Test file exists
  - Validates PATH contains ~/.local/bin
  - Validates Ralph markers in shell rc
  - All tests pass

### TASK-1.3: Directory Structure Validator
- **Priority**: P1
- **Time**: 1 hour
- **Dependencies**: TASK-0.1
- **Files**:
  - `tests/installer/test-directory-structure.bats`
  - `scripts/validate-directories.sh`
- **Criteria**:
  - Test file exists
  - Validates ~/.ralph directory structure
  - Validates ~/.claude directory structure
  - All tests pass

### TASK-2.1: Hooks Registration Validator
- **Priority**: P1
- **Time**: 3-4 hours
- **Dependencies**: TASK-0.1, TASK-1.1
- **Files**:
  - `tests/installer/test-hooks-registration.bats`
  - `scripts/validate-hooks-registration.sh`
- **Criteria**:
  - Test file exists
  - Validates hooks are registered in settings.json
  - Checks hook scripts exist and are executable
  - All tests pass

### TASK-2.2: Hooks Execution Validator
- **Priority**: P1
- **Time**: 4-5 hours
- **Dependencies**: TASK-2.1
- **Files**:
  - `tests/installer/test-hooks-execution.bats`
  - `tests/installer/fixtures/mock-tool-inputs/`
  - `scripts/validate-hooks-execution.sh`
- **Criteria**:
  - Test file exists
  - Mock input fixtures created
  - Tests hook execution with mock input
  - All tests pass

### TASK-2.3: Hooks Syntax Validator
- **Priority**: P2
- **Time**: 1-2 hours
- **Dependencies**: TASK-0.1
- **Files**:
  - `tests/installer/test-hooks-syntax.bats`
  - `scripts/validate-hooks-syntax.sh`
- **Criteria**:
  - Test file exists
  - Validates bash syntax with bash -n
  - Validates Python syntax with py_compile
  - All tests pass

### TASK-3.1: Skills Registration Validator
- **Priority**: P1
- **Time**: 2-3 hours
- **Dependencies**: TASK-0.1
- **Files**:
  - `tests/installer/test-skills-registration.bats`
  - `scripts/validate-skills-registration.sh`
- **Criteria**:
  - Test file exists
  - Validates SKILL.md exists for each skill
  - Validates skill frontmatter
  - All tests pass

### TASK-3.2: Skills Execution Validator
- **Priority**: P2
- **Time**: 3-4 hours
- **Dependencies**: TASK-3.1
- **Files**:
  - `tests/installer/test-skills-execution.bats`
  - `scripts/validate-skills-execution.sh`
- **Criteria**:
  - Test file exists
  - Tests core skills load without errors
  - All tests pass

### TASK-4.1: Agents Registration Validator
- **Priority**: P1
- **Time**: 1-2 hours
- **Dependencies**: TASK-0.1
- **Files**:
  - `tests/installer/test-agents-registration.bats`
  - `scripts/validate-agents-registration.sh`
- **Criteria**:
  - Test file exists
  - Validates all ralph-* agents exist
  - All tests pass

### TASK-5.1: Settings Structure Validator
- **Priority**: P1
- **Time**: 2-3 hours
- **Dependencies**: TASK-0.1
- **Files**:
  - `tests/installer/test-settings-structure.bats`
  - `scripts/validate-settings-structure.sh`
- **Criteria**:
  - Test file exists
  - Validates JSON structure
  - Validates required top-level keys
  - All tests pass

### TASK-5.2: Settings Merge Validator
- **Priority**: P1
- **Time**: 2-3 hours
- **Dependencies**: TASK-5.1
- **Files**:
  - `tests/installer/test-settings-merge.bats`
  - `tests/installer/fixtures/settings-*.json`
- **Criteria**:
  - Test file exists
  - Tests fresh install scenario
  - Tests merge with existing settings
  - All tests pass

### TASK-6.1: Full Installation E2E Test
- **Priority**: P1
- **Time**: 4-6 hours
- **Dependencies**: TASK-1.1, TASK-2.1, TASK-3.1, TASK-4.1, TASK-5.1
- **Files**:
  - `tests/installer/test-e2e-installation.bats`
  - `tests/installer/e2e-setup.sh`
  - `tests/installer/e2e-cleanup.sh`
- **Criteria**:
  - Test file exists
  - Simulates clean environment
  - Tests full install.sh execution
  - All tests pass

### TASK-6.2: Hook Chain Integration Test
- **Priority**: P1
- **Time**: 3-4 hours
- **Dependencies**: TASK-2.2
- **Files**:
  - `tests/installer/test-hook-chain.bats`
  - `tests/installer/fixtures/hook-scenarios/`
- **Criteria**:
  - Test file exists
  - Tests hook firing order
  - All tests pass

### TASK-6.3: CLI Commands E2E Test
- **Priority**: P2
- **Time**: 2-3 hours
- **Dependencies**: TASK-1.1
- **Files**:
  - `tests/installer/test-cli-commands.bats`
- **Criteria**:
  - Test file exists
  - Tests ralph help command
  - Tests mmc help command
  - All tests pass

### TASK-7.1: Master Validation Script
- **Priority**: P1
- **Time**: 2-3 hours
- **Dependencies**: All previous tasks
- **Files**:
  - `scripts/validate-installation.sh`
- **Criteria**:
  - Script exists and is executable
  - Runs all validation scripts
  - Supports JSON output
  - Returns appropriate exit code

### TASK-7.2: CI Integration
- **Priority**: P2
- **Time**: 2-3 hours
- **Dependencies**: TASK-7.1
- **Files**:
  - `.github/workflows/test-installer.yml`
- **Criteria**:
  - Workflow file exists
  - Runs on PR and push to main
  - Installs BATS and runs tests

## Summary

| Phase | Tasks | Priority | Est. Time |
|-------|-------|----------|-----------|
| 0. Infrastructure | 1 | P1 | 1-2h |
| 1. Environment | 3 | P1 | 4-6h |
| 2. Hooks | 3 | P1/P2 | 8-11h |
| 3. Skills | 2 | P1/P2 | 5-7h |
| 4. Agents | 1 | P1 | 1-2h |
| 5. Settings | 2 | P1 | 4-6h |
| 6. E2E | 3 | P1/P2 | 9-13h |
| 7. Master | 2 | P1/P2 | 4-6h |
| **TOTAL** | **17** | - | **36-53h** |

## Usage

```bash
# Execute batch with task-batch skill
/task-batch docs/prd/installer-validation.prq.md

# Or run individual validation scripts
./scripts/validate-installation.sh

# Run all BATS tests
bats tests/installer/
```
