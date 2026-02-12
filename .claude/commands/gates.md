---
# VERSION: 2.84.1
name: gates
prefix: "@gates"
category: tools
color: green
description: "Run quality gates for 9 languages (TypeScript, JavaScript, Python, Go, Rust, Solidity, Swift, JSON, YAML)"
argument-hint: "[--with-glm5]"
---

# /gates - Quality Gates with Swarm Mode (v2.84.1)

Run comprehensive quality gates across 9 programming languages with parallel validation using swarm mode.

## v2.84.1 Key Change (GLM-5 INTEGRATION)

**`--with-glm5` flag** enables GLM-5 quality validation:

```
/gates --with-glm5
```

When `--with-glm5` is set:
- Uses `glm5-reviewer` for code quality analysis
- Captures reasoning for gate failures
- Provides detailed explanations with thinking mode

## Overview

Quality gates provide automated validation using language-specific linters, type checkers, and static analysis tools. **Swarm mode enables parallel validation** where multiple language groups are checked simultaneously, dramatically reducing validation time.

```
┌─────────────────────────────────────────────────────────────────┐
│               QUALITY GATES SWARM MODE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌───────────┐ ┌──────────┐ ┌──────────┐ ┌─────────────┐   │
│   │TypeScript/│ │  Python  │ │  Rust/   │ │ Solidity/   │   │
│   │JavaScript │ │          │ │   Go     │ │  Swift      │   │
│   │   Gate    │ │   Gate   │ │   Gate   │ │    Gate     │   │
│   └─────┬─────┘ └─────┬────┘ └─────┬────┘ └──────┬──────┘   │
│         │             │            │             │          │
│         └─────────────┴────────────┴─────────────┘          │
│                            │                                │
│                    ┌───────┴────────┐                       │
│                    │ JSON/YAML Gate │                       │
│                    └───────┬────────┘                       │
│                            │                                │
│                            ▼                                │
│                   ┌─────────────────┐                       │
│                   │  Gates Lead     │                       │
│                   │  (gates-lead)   │                       │
│                   └─────────────────┘                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## When to Use

- After implementing new features or bug fixes
- Before creating commits or pull requests
- In CI/CD pipelines for automated validation
- During code review preparation
- As part of the Ralph Loop validation step
- **When speed matters**: Parallel validation reduces gate time by 60-80%

---

## Swarm Mode Integration (v2.81.1)

`/gates` uses swarm mode with **language-group specialists** for parallel quality validation.

### Auto-Spawn Configuration

```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"
  team_name: "quality-gates-team"
  name: "gates-lead"
  mode: "delegate"
  run_in_background: true
  prompt: |
    Execute quality gates validation for: $ARGUMENTS

    Quality Gates Pattern:
    1. DISTRIBUTE - Assign language groups to specialists
    2. DETECT - Detect files for each language group
    3. VALIDATE - Run gates in parallel per group
    4. COLLECT - Gather results from all specialists
    5. REPORT - Synthesize into comprehensive report
```

### Team Composition (5 Language Groups)

| Role | Purpose | Specialization |
|------|---------|----------------|
| **Coordinator** | Gates workflow orchestration | Manages 5 language groups, synthesizes results |
| **Teammate 1** | TypeScript/JavaScript specialist | tsc, eslint, prettier for .ts, .tsx, .js, .jsx |
| **Teammate 2** | Python specialist | pyright, ruff for .py files |
| **Teammate 3** | Compiled Languages specialist | cargo, go vet, staticcheck for .rs, .go |
| **Teammate 4** | Smart Contract Languages specialist | forge, solhint for .sol, swiftlint for .swift |
| **Teammate 5** | Config/Data specialist | jq, yamllint for .json, .yaml, .yml |

### Swarm Mode Workflow

```
User invokes: /gates

1. Team "quality-gates-team" created
2. Coordinator (gates-lead) scans codebase
3. 5 Teammates spawned with language specializations
4. Language groups distributed:
   - Teammate 1 → TypeScript/JavaScript files
   - Teammate 2 → Python files
   - Teammate 3 → Rust/Go files
   - Teammate 4 → Solidity/Swift files
   - Teammate 5 → JSON/YAML files
5. All teammates run gates in parallel (background execution)
6. Each validates only their language group
7. Coordinator collects all results
8. Comprehensive quality report synthesized
9. Final report with all findings returned
```

### Parallel Validation Pattern

Each teammate focuses on their language group:

```yaml
# Teammate 1: TypeScript/JavaScript
- Detect: .ts, .tsx, .js, .jsx files
- Validate: npx tsc --noEmit, npx eslint
- Report: Type errors, linting violations
- Duration: ~15s for 10 files

# Teammate 2: Python
- Detect: .py files
- Validate: pyright, ruff check
- Report: Type errors, style violations
- Duration: ~10s for 5 files

# Teammate 3: Compiled Languages
- Detect: .rs, .go files
- Validate: cargo check, go vet, staticcheck
- Report: Compilation errors, static analysis warnings
- Duration: ~20s for 8 files

# Teammate 4: Smart Contract Languages
- Detect: .sol, .swift files
- Validate: forge build, solhint, swiftlint
- Report: Compilation errors, style violations
- Duration: ~12s for 3 files

# Teammate 5: Config/Data
- Detect: .json, .yaml, .yml files
- Validate: jq, yamllint
- Report: Syntax errors, formatting issues
- Duration: ~5s for 15 files
```

**Parallel vs Sequential**:
- **Sequential**: ~62 seconds (15+10+20+12+5)
- **Parallel (Swarm)**: ~20 seconds (max of individual times)
- **Speedup**: 3.1x faster

### Communication Between Teammates

```yaml
# Teammate reports findings to coordinator
SendMessage:
  type: "message"
  recipient: "gates-lead"
  content: "TypeScript: 3 type errors, 2 eslint warnings"

# Coordinator requests summary
SendMessage:
  type: "message"
  recipient: "teammate-2"
  content: "Provide Python gate summary with file paths"
```

### Task List Coordination

```bash
# Location: ~/.claude/tasks/quality-gates-team/tasks.json

# Example tasks:
[
  {"id": "1", "subject": "Detect TypeScript files", "owner": "teammate-1"},
  {"id": "2", "subject": "Detect Python files", "owner": "teammate-2"},
  {"id": "3", "subject": "Detect compiled language files", "owner": "teammate-3"},
  {"id": "4", "subject": "Detect smart contract files", "owner": "teammate-4"},
  {"id": "5", "subject": "Detect config files", "owner": "teammate-5"},
  {"id": "6", "subject": "Run all gates in parallel", "owner": "gates-lead"},
  {"id": "7", "subject": "Synthesize report", "owner": "gates-lead"}
]
```

## Supported Languages

| Language | Type Checker | Linter | Formatter | Teammate |
|----------|-------------|--------|-----------|----------|
| TypeScript | tsc | eslint | prettier | 1 |
| JavaScript | - | eslint | prettier | 1 |
| Python | pyright | ruff | ruff | 2 |
| Go | go vet | staticcheck | gofmt | 3 |
| Rust | cargo check | cargo clippy | rustfmt | 3 |
| Solidity | forge | solhint | forge fmt | 4 |
| Swift | - | swiftlint | - | 4 |
| JSON | jq | - | jq | 5 |
| YAML | - | yamllint | - | 5 |

## Tools per Language

**TypeScript/JavaScript (Teammate 1):**
- `npx tsc --noEmit` - Type checking
- `npx eslint` - Linting
- Install: `brew install node`

**Python (Teammate 2):**
- `pyright` - Type checking
- `ruff check` - Linting
- Install: `npm i -g pyright && pip install ruff`

**Go (Teammate 3):**
- `go vet` - Built-in static analysis
- `staticcheck` - Advanced linting
- Install: `brew install go staticcheck`

**Rust (Teammate 3):**
- `cargo check` - Type checking
- `cargo clippy` - Linting
- Install: `brew install rust`

**Solidity (Teammate 4):**
- `forge build` - Compilation
- `solhint` - Linting
- Install: `foundryup && npm i -g solhint`

**Swift (Teammate 4):**
- `swiftlint` - Linting and style checking
- Install: `brew install swiftlint`

**JSON (Teammate 5):**
- `jq` - Validation and formatting
- Install: `brew install jq`

**YAML (Teammate 5):**
- `yamllint` - Linting
- Install: `pip install yamllint`

## CLI Execution

```bash
# Run all quality gates with swarm mode (default)
ralph gates

# Run gates for specific path
ralph gates src/

# Specific language validation (via quality-gates.sh)
~/.ralph/hooks/quality-gates.sh /path/to/file.ts

# Check tool availability
ralph integrations
```

### Manual Override

```bash
# Disable swarm mode (sequential execution)
ralph gates --no-swarm

# Custom language groups
ralph gates --groups typescript,python
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

## Output Format

### Console Output (Swarm Mode)

```
╔══════════════════════════════════════════════════════════════╗
║            Quality Gates (Swarm Mode - Parallel)             ║
╠══════════════════════════════════════════════════════════════╣
║ Team: quality-gates-team (5 specialists)                    ║
╚══════════════════════════════════════════════════════════════╝

[Parallel Execution Started]
├─ Teammate 1: TypeScript/JavaScript → SCANNING (12 files)
├─ Teammate 2: Python → SCANNING (5 files)
├─ Teammate 3: Compiled Languages → SCANNING (8 files)
├─ Teammate 4: Smart Contracts → SCANNING (3 files)
└─ Teammate 5: Config/Data → SCANNING (15 files)

[Results - 5/5 COMPLETE]
├─ Teammate 1: ✓ tsc (0 errors), ⚠ eslint (2 warnings)
├─ Teammate 2: ✓ pyright (0 errors), ✓ ruff (0 violations)
├─ Teammate 3: ✓ cargo (0 errors), ⚠ clippy (1 warning)
├─ Teammate 4: ✓ forge (0 errors), ✓ solhint (0 violations)
└─ Teammate 5: ✓ jq (0 errors), ✓ yamllint (0 violations)

[Summary]
├─ Files Scanned: 43
├─ Type Errors: 0
├─ Linting Warnings: 3
├─ Duration: 18.5s (parallel) vs ~55s (sequential)
└─ Speedup: 3.0x faster

╔══════════════════════════════════════════════════════════════╗
║                    Quality Gates Report                      ║
╠══════════════════════════════════════════════════════════════╣
║ Status: ⚠ WARNINGS                                          ║
║ Type Errors: 0                                              ║
║ Linting Warnings: 3                                         ║
║ Files Scanned: 43                                           ║
║ Duration: 18.5s (3.0x faster than sequential)               ║
╚══════════════════════════════════════════════════════════════╝
```

## Hook Integration

The `quality-gates.sh` hook automatically runs after Edit/Write operations:

```bash
# Triggered automatically after file edits
~/.ralph/hooks/quality-gates.sh <file-path>

# Validates only modified files
# Non-blocking to allow iteration
# Reports issues for correction
```

**With Swarm Mode**:
- Hook triggers quality gates in background
- Multiple files validated in parallel by language group
- Results reported when all groups complete

## Related Commands

- `/orchestrator` - Full 8-step workflow (includes gates at step 5)
- `/adversarial` - Adversarial validation (includes gates)
- `/loop` - Iterative task execution with validation
- `ralph pre-merge` - Pre-PR validation with blocking gates
- `ralph integrations` - Check tool installation status

## Integration with Ralph Loop

Quality gates are automatically enforced at Step 5 of the orchestration flow:

```
1. /clarify     → Intensive questions
2. /classify    → Complexity routing
3. PLAN         → User approval
4. @orchestrator → Subagent delegation
5. ralph gates  → Quality validation (PARALLEL) ← YOU ARE HERE
6. /adversarial → adversarial-spec refinement (if critical)
7. /retrospective → Self-improvement
→ VERIFIED_DONE
```

## Examples

### Example 1: Full Codebase

```bash
ralph gates
```

**Output**:
- 5 language groups validated in parallel
- 43 files scanned in 18.5s
- 3 warnings found
- 3.0x faster than sequential

### Example 2: Specific Directory

```bash
ralph gates src/auth/
```

**Output**:
- Only files in src/auth/ validated
- Parallel execution by language
- Faster than full codebase validation

### Example 3: CI/CD Pipeline

```bash
ralph pre-merge  # Blocking mode
```

**Output**:
- Stops on first violation
- Suitable for pre-commit hooks
- Exits with error code if gates fail

## Best Practices

1. **Use swarm mode by default**: Parallel validation is 3x faster
2. **Fix warnings iteratively**: Run gates after each fix
3. **Trust the specialists**: Each teammate knows their language tools
4. **Review all reports**: Coordinator synthesizes all findings
5. **Configure in CI/CD**: Use blocking mode for pipelines

---

**Version**: 2.81.1 | **Status**: SWARM MODE ENABLED | **Team Size**: 6 agents (1 lead + 5 language groups)

## GLM-5 Integration (v2.84.1)

When `--with-glm5` flag is present:

**Execution Pattern:**
```bash
# Spawn GLM-5 reviewer for quality analysis
.claude/scripts/glm5-teammate.sh "glm5-reviewer" "Analyze code quality for $FILES" "${TASK_ID}"

# View reasoning for detailed analysis
cat .ralph/reasoning/${TASK_ID}.txt
```

**Output Files:**
- `.ralph/teammates/{task_id}/status.json` - Gate analysis status
- `.ralph/reasoning/{task_id}.txt` - GLM-5 quality reasoning
