---
name: gates
prefix: "@gates"
category: tools
color: green
description: "Run quality gates for 9 languages (TypeScript, JavaScript, Python, Go, Rust, Solidity, Swift, JSON, YAML)"
---

# /gates

Run comprehensive quality gates across 9 programming languages to validate code before commits, merges, or deployments.

## Overview

Quality gates provide automated validation using language-specific linters, type checkers, and static analysis tools. This ensures code quality, type safety, and adherence to best practices across the entire codebase.

## When to Use

- After implementing new features or bug fixes
- Before creating commits or pull requests
- In CI/CD pipelines for automated validation
- During code review preparation
- As part of the Ralph Loop validation step

## Supported Languages

| Language | Type Checker | Linter | Formatter |
|----------|-------------|--------|-----------|
| TypeScript | tsc | eslint | prettier |
| JavaScript | - | eslint | prettier |
| Python | pyright | ruff | ruff |
| Go | go vet | staticcheck | gofmt |
| Rust | cargo check | cargo clippy | rustfmt |
| Solidity | forge | solhint | forge fmt |
| Swift | - | swiftlint | - |
| JSON | jq | - | jq |
| YAML | - | yamllint | - |

## Tools per Language

**TypeScript/JavaScript:**
- `npx tsc --noEmit` - Type checking
- `npx eslint` - Linting
- Install: `brew install node`

**Python:**
- `pyright` - Type checking
- `ruff check` - Linting
- Install: `npm i -g pyright && pip install ruff`

**Go:**
- `go vet` - Built-in static analysis
- `staticcheck` - Advanced linting
- Install: `brew install go staticcheck`

**Rust:**
- `cargo check` - Type checking
- `cargo clippy` - Linting
- Install: `brew install rust`

**Solidity:**
- `forge build` - Compilation
- `solhint` - Linting
- Install: `foundryup && npm i -g solhint`

**Swift:**
- `swiftlint` - Linting and style checking
- Install: `brew install swiftlint`

**JSON:**
- `jq` - Validation and formatting
- Install: `brew install jq`

**YAML:**
- `yamllint` - Linting
- Install: `pip install yamllint`

## CLI Execution

```bash
# Run all quality gates
ralph gates

# Specific language validation (via quality-gates.sh)
~/.ralph/hooks/quality-gates.sh /path/to/file.ts

# Check tool availability
ralph integrations
```

## Task Tool Invocation

```yaml
Task:
  subagent_type: "quality-validation"
  model: "sonnet"
  run_in_background: true
  description: "Running quality gates for validation"
  prompt: |
    Execute quality gates validation:
    cd /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop && ralph gates

    Iterate until all quality gates pass.
    Apply Ralph Loop pattern: max 15 iterations.
```

## Blocking vs Non-Blocking

**Non-Blocking Mode (default):**
- Reports violations but continues execution
- Suitable for development and iteration
- Used in quality-gates.sh hook

**Blocking Mode (CI/CD):**
- Exits on first violation
- Suitable for pre-merge validation
- Use: `ralph pre-merge`

## Hook Integration

The `quality-gates.sh` hook automatically runs after Edit/Write operations:

```bash
# Triggered automatically after file edits
~/.ralph/hooks/quality-gates.sh <file-path>

# Validates only modified files
# Non-blocking to allow iteration
# Reports issues for correction
```

## Related Commands

- `/orchestrator` - Full 8-step workflow (includes gates at step 5)
- `/adversarial` - adversarial-spec refinement (includes gates)
- `/loop` - Iterative task execution with validation
- `ralph pre-merge` - Pre-PR validation with blocking gates
- `ralph integrations` - Check tool installation status

## Example Output

```
Quality Gates Report
====================

TypeScript (3 files):
✓ tsc - No type errors
✓ eslint - No violations

Python (2 files):
✓ pyright - No type errors
⚠ ruff - 1 violation:
  src/utils.py:42:1 - Line too long (120 > 88)

Summary: 1 warning, 0 errors
```

## Integration with Ralph Loop

Quality gates are automatically enforced at Step 5 of the orchestration flow:

```
1. /clarify     → Intensive questions
2. /classify    → Complexity routing
3. PLAN         → User approval
4. @orchestrator → Subagent delegation
5. ralph gates  → Quality validation ← YOU ARE HERE
6. /adversarial → adversarial-spec refinement (if critical)
7. /retrospective → Self-improvement
→ VERIFIED_DONE
```
