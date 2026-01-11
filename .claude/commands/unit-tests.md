---
name: unit-tests
prefix: "@tests"
category: review
color: red
description: "Generate unit tests with Codex (90% coverage)"
argument-hint: "<path>"
---

# /unit-tests

Comprehensive unit test generation using Codex GPT-5.2 with 90% coverage targets.

## Overview

Generate high-quality unit tests for any codebase using Codex's advanced code understanding capabilities. This command analyzes your code structure, identifies critical paths, edge cases, and generates comprehensive test suites with proper mocking, assertions, and coverage.

## When to Use

- After implementing new features (before PR)
- When coverage drops below threshold
- During TDD workflow (red-green-refactor)
- Before major refactoring
- When onboarding new testing frameworks
- For legacy code without tests

## Testing Frameworks

Automatically detects and uses appropriate framework:

| Language | Framework | Coverage Tool |
|----------|-----------|---------------|
| Bash | BATS (bats-core) | - |
| Python | pytest + unittest | pytest-cov |
| JavaScript/TypeScript | Jest | jest --coverage |
| Go | testing + testify | go test -cover |
| Rust | cargo test | tarpaulin |
| Solidity | Foundry (forge test) | forge coverage |

## Test Patterns Generated

1. **Unit Tests** - Isolated function/method tests
2. **Edge Cases** - Boundary conditions, null/undefined
3. **Error Handling** - Exception paths, validation
4. **Mocking** - External dependencies (APIs, DB, filesystem)
5. **Assertions** - Output verification, state checks
6. **Setup/Teardown** - Test fixtures, cleanup

## CLI Execution

```bash
# Generate tests for specific file
ralph unit-tests src/utils/validator.ts

# Generate tests for directory
ralph unit-tests src/services/

# Generate tests for entire project
ralph unit-tests .

# With coverage report
ralph unit-tests src/ --coverage
```

## Task Tool Invocation

Use the Task tool for programmatic test generation:

```yaml
Task:
  subagent_type: "test-architect"
  model: "sonnet"
  run_in_background: true
  description: "Codex: Generate unit tests"
  prompt: |
    Execute via Codex CLI:
    cd /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop && \
    codex exec -m gpt-5.2-codex -C . "
    Generate comprehensive unit tests for: $ARGUMENTS

    Requirements:
    - 90% code coverage target
    - Test all edge cases and error paths
    - Mock external dependencies
    - Follow project testing conventions
    - Include setup/teardown fixtures
    - Add descriptive test names
    "

    Apply Ralph Loop: iterate until quality gates pass.
```

## Coverage Goals

| Project Type | Minimum Coverage | Target Coverage |
|--------------|------------------|-----------------|
| Production API | 80% | 90% |
| Library/SDK | 85% | 95% |
| CLI Tool | 75% | 85% |
| Frontend Components | 70% | 80% |

## Output Format

Tests are generated following project conventions:

```
project/
├── src/
│   └── utils/
│       └── validator.ts
└── tests/
    └── utils/
        └── validator.test.ts
```

Or inline for some frameworks:
```
project/
└── src/
    └── utils/
        ├── validator.ts
        └── validator.test.ts
```

## Related Commands

- `/bugs` - Find bugs before writing tests
- `/refactor` - Improve code structure before testing
- `/gates` - Run quality gates including coverage checks
- `/full-review` - Comprehensive review including test generation
- `/adversarial` - Refine associated PRD/tech spec

## Example Workflow

```bash
# 1. Implement feature
vim src/features/auth.ts

# 2. Generate tests
ralph unit-tests src/features/auth.ts

# 3. Run quality gates
ralph gates

# 4. If coverage low, iterate
ralph unit-tests src/features/auth.ts --focus-coverage

# 5. Commit when VERIFIED_DONE
git add . && git commit -m "feat(auth): Add authentication with tests"
```
