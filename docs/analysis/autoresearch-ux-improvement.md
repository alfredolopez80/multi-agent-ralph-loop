# Autoresearch UX Improvement Analysis

**Date**: 2026-04-05
**Branch**: `feat/autoresearch-ux-improvement`
**Version**: v3.1.0 proposal
**Status**: Analysis complete, ready for implementation

## Problem Statement

The `/autoresearch` skill (inspired by Karpathy's autoresearch) requires **14+ parameters** before starting the experiment loop. This creates a high barrier to entry:

- 4 mandatory fields that require technical knowledge (eval_harness, primary_metric, metric extraction regex, metric_direction)
- 10 optional fields with non-obvious defaults
- No auto-detection of project type or available metrics
- No progressive disclosure (all fields shown at once)

**Goal**: Reduce setup friction from ~5 minutes of manual configuration to ~60 seconds of guided selection, **without losing any capability**.

## Friction Map

### High Friction (Blocks Users)

| ID | Point | Why | Pain Example |
|---|---|---|---|
| F1 | User must know exact eval command | Not everyone knows how to extract metrics | "How do I extract val_bpb from my training script?" |
| F2 | User must write grep regex for metric | Regex is not user-friendly | `grep "^val_bpb:" run.log \| awk '{print "METRIC val_bpb="$2}'` |
| F3 | User must know which files are safe to modify | Requires understanding project structure | "Is it safe for you to modify webpack.config.js?" |
| F4 | Setup contract is monolithic | 14+ fields at once overwhelm users | User sees a wall of YAML and abandons |

### Medium Friction (Slows Down)

| ID | Point |
|---|---|
| F5 | Choosing `metric_direction` (lower_is_better vs higher_is_better) |
| F6 | Configuring `metric_mode` (single, pareto, weighted) |
| F7 | Choosing checkpoint_mode and budgets (no smart heuristics) |
| F8 | Branch tag is manual (could be auto-generated semantically) |

### Low Friction (Minor Annoyances)

| ID | Point |
|---|---|
| F9 | off_limits has reasonable defaults but user doesn't know |
| F10 | constraints is free text without suggestions |
| F11 | No automatic project type detection |

## Proposed Solution: 3-Phase Intelligent Onboarding

### Architecture

```
/autoresearch "optimize my tests"
     |
  [PHASE 0: SCOUT] - Silent auto-detection (~5 sec)
     |  Glob: project type (package.json, pyproject.toml, Cargo.toml)
     |  Grep: available scripts (test, build, train, bench)
     |  Grep: existing metric patterns (time, score, loss, size)
     |  Bash: framework detection (pytest, vitest, jest, cargo test)
     |
  [PHASE 1: WIZARD] - AskUserQuestion with pre-fill (~2-3 questions)
     |  Q1: "Detected X. What do you want to optimize?" [options with preview]
     |  Q2: "Experimentation budget?" [sensible defaults]
     |  Q3: (ONLY if ambiguous) "Allowed files?" [pre-selected]
     |
  [PHASE 2: VALIDATE] - Adversarial dry-run (~10 sec)
     |  Does eval_harness execute? (dry-run)
     |  Does metric extract correctly? (regex test)
     |  Is the baseline deterministic? (2x run comparison)
     |  Is git clean?
     |
  [CONFIRM] - Single question: "Ready. Start?"
     |
  [LOOP] - Unchanged autonomous execution
```

### Phase 0: SCOUT (Auto-detection)

The agent silently analyzes the project to pre-fill ~80% of fields:

| Detection | How | Field Filled |
|---|---|---|
| Project type | `package.json` -> Node, `pyproject.toml` -> Python, etc. | `eval_harness` template |
| Available scripts | `scripts` in package.json, Makefile targets | `eval_harness` candidates |
| Existing metrics | Grep for patterns: `time`, `score`, `loss`, `accuracy`, `size` | `primary_metric` candidates |
| Test framework | vitest, jest, pytest, cargo test | `checks_script` |
| File structure | Glob `src/`, `lib/`, `app/` | `target` candidates |
| Sensitive files | `.env`, `config/`, `migrations/` | `off_limits` defaults |

**Implementation**: Run these as parallel Glob/Grep/Bash calls (no user interaction).

### Phase 1: WIZARD (Smart Questions)

Instead of 14 fields, present **max 3 AskUserQuestion** with pre-filled options:

#### Question 1 - Objective (always)

```yaml
AskUserQuestion:
  questions:
    - question: "What should I optimize? I detected these opportunities:"
      header: "Objective"
      multiSelect: false
      options:
        - label: "Test speed (Recommended)"
          description: "Detected: pnpm test -> 12.3s. Target: reduce execution time"
          preview: |
            Target:     src/
            Eval:       pnpm test --run
            Metric:     duration_seconds (lower is better)
            Checks:     pnpm typecheck
        - label: "Bundle size"
          description: "Detected: pnpm build -> 245KB. Target: reduce output size"
          preview: |
            Target:     src/
            Eval:       pnpm build && du -sb dist
            Metric:     bundle_kb (lower is better)
            Checks:     pnpm test --run
        - label: "Build speed"
          description: "Detected: pnpm build -> 8.1s. Target: reduce build time"
          preview: |
            Target:     src/, vite.config.ts
            Eval:       time pnpm build
            Metric:     build_seconds (lower is better)
```

#### Question 2 - Budget (always, with smart defaults)

```yaml
AskUserQuestion:
  questions:
    - question: "How much experimentation budget?"
      header: "Budget"
      multiSelect: false
      options:
        - label: "Quick (~30 min) (Recommended)"
          description: "10 experiments, good for parameter tweaks"
        - label: "Standard (~2h)"
          description: "50 experiments, structural changes"
        - label: "Deep (~4h+)"
          description: "100+ experiments, radical approaches"
        - label: "Unlimited"
          description: "I'll stop you manually when ready"
```

#### Question 3 - Scope (conditional, only if ambiguous)

```yaml
AskUserQuestion:
  questions:
    - question: "Which files can I modify?"
      header: "Scope"
      multiSelect: true
      options:
        - label: "src/components/ (14 files)"
          description: "React components"
        - label: "src/lib/ (8 files)"
          description: "Utility libraries"
        - label: "src/app/ (routes)"
          description: "Warning: modifying routes is risky"
        - label: "Config files"
          description: "vite.config.ts, tsconfig.json, etc."
```

### Phase 2: VALIDATE (Adversarial Dry-Run)

Before starting the loop, run a quick validation:

| Check | How | On Failure |
|---|---|---|
| eval_harness executes | `timeout 60 bash -c "$EVAL"` | Ask for correct command |
| Metric extracts | `grep "^METRIC" run.log` | Auto-adjust regex |
| Baseline is deterministic | Run 2x, compare | Warn user, suggest higher threshold |
| Git is clean | `git status --porcelain` | Ask to commit/stash first |
| Target files exist | `ls -la $TARGET` | Correct path |
| Checks script works | Run if configured | Disable or fix |

### Domain Templates

The biggest friction reduction comes from domain-specific templates detected by SCOUT:

| Detected Domain | Template |
|---|---|
| **ML Training** (train.py + torch/tf) | eval: `python train.py`, metric: `val_loss`, direction: `lower` |
| **Node.js Tests** (vitest/jest) | eval: `pnpm test --run`, metric: `duration_seconds`, direction: `lower` |
| **Bundle Size** (webpack/vite/esbuild) | eval: `pnpm build`, metric: `bundle_kb`, direction: `lower` |
| **Python Tests** (pytest) | eval: `pytest -q`, metric: `duration_seconds`, direction: `lower` |
| **Lighthouse** (next.js/SPA) | eval: `lighthouse --output=json`, metric: `perf_score`, direction: `higher` |
| **Prompt Engineering** (.txt + eval) | eval: `./eval.sh`, metric: `accuracy`, direction: `higher` |
| **SQL** (.sql files) | eval: `./bench_query.sh`, metric: `exec_time_ms`, direction: `lower` |
| **Rust** (Cargo.toml) | eval: `cargo bench`, metric: custom |
| **Custom** (fallback) | Full wizard with all questions |

### Intent Parsing

Parse natural language intent from the user's command:

| User Says | Parsed Intent | Mapped Domain |
|---|---|---|
| "optimize my tests" | test_speed | Node.js/Python Tests |
| "reduce bundle size" | bundle_size | Bundle Size |
| "improve accuracy" | ml_accuracy | ML Training |
| "speed up build" | build_speed | Bundle/Build |
| "optimize prompts" | prompt_quality | Prompt Engineering |
| "make queries faster" | sql_speed | SQL |

Keywords: `optimize`, `reduce`, `improve`, `speed up`, `minimize`, `maximize`, `make X faster/smaller/better`

## Before/After Comparison

| Aspect | Before (current) | After (proposed) |
|---|---|---|
| Questions to user | 14+ fields | 2-3 questions with options |
| Technical knowledge required | Regex, grep, metric extraction | Select from detected options |
| Setup time | 3-5 minutes of typing | 30-60 seconds of clicking |
| Setup error probability | High (wrong regex, wrong path) | Low (automatic validation) |
| Loop capabilities | 100% | **100% (unchanged)** |
| Advanced customization | Available | Available via "Other" and flags |
| Resumability | Unchanged | Unchanged |
| Supported domains | All | All + improved auto-detection |
| First-time user experience | Intimidating | Guided and friendly |

## Edge Cases

| Edge Case | Handling |
|---|---|
| No detectable scripts | Fallback to full wizard (clarify mode) |
| Non-deterministic metric (varies +/-5%) | Detect in dry-run, warn, suggest higher threshold |
| Eval takes >5 min | Detect in dry-run, auto-adjust time_budget |
| Git with uncommitted changes | Ask to commit or stash before continuing |
| Multiple possible metrics | Present all as options in Q1 |
| Monorepo | Ask for specific workspace/package |
| No existing tests | Warn that checks_script doesn't apply |
| User wants full control | Provide `--manual` flag for classic mode |

## Tool Orchestration

| Tool | Role | Phase |
|---|---|---|
| **Glob/Grep/Bash** (parallel) | Silent project analysis | Phase 0: SCOUT |
| **AskUserQuestion** (with previews) | Present pre-filled options | Phase 1: WIZARD |
| **/clarify patterns** | MUST_HAVE vs NICE_TO_HAVE classification | Phase 1: WIZARD |
| **/adversarial patterns** | Validate setup for edge cases | Phase 2: VALIDATE |
| **Smart defaults** | Reduce 14 fields to ~3 decisions | Cross-cutting |

## Implementation Plan

### Step 1: Add SCOUT detection logic to SKILL.md
- Project type detection (Glob patterns)
- Script discovery (package.json, Makefile, pyproject.toml)
- Metric pattern detection (Grep for common output patterns)
- File structure analysis for target/off_limits defaults

### Step 2: Create domain templates
- 9 templates (ML, Node tests, Bundle, Python tests, Lighthouse, Prompt, SQL, Rust, Custom)
- Each template pre-fills all 14 fields with sensible defaults
- Matching logic: project_type + user_intent -> template

### Step 3: Refactor setup flow in SKILL.md
- Replace monolithic setup contract with 3-phase flow
- Phase 0: SCOUT (auto-detection, no user interaction)
- Phase 1: WIZARD (2-3 AskUserQuestion with previews)
- Phase 2: VALIDATE (adversarial dry-run)

### Step 4: Add intent parsing
- Natural language patterns for common optimization goals
- Keyword extraction from user's command
- Mapping to domain templates

### Step 5: Add --manual flag
- Preserve classic mode for power users
- `--manual` bypasses SCOUT and WIZARD, uses current monolithic setup

### Step 6: Update program-template.md
- Add SCOUT section before initialization
- Add WIZARD section with AskUserQuestion templates
- Add VALIDATE section with dry-run checks

### Step 7: Update agent definition
- Add AskUserQuestion to allowed-tools (already present)
- Add Glob to allowed-tools (already present)
- Update agent prompt with new 3-phase flow

## Preserved Capabilities

**NOTHING is removed.** Every capability of the current skill is preserved:

- All 14+ parameters still configurable
- Dual metric modes (single, primary_secondary, pareto, weighted)
- Checkpoint system unchanged
- Budget management unchanged
- Crash handling unchanged
- Resumability unchanged
- Simplicity criterion unchanged
- Session files unchanged (autoresearch.md, .jsonl, .tsv, .sh)
- Branch management unchanged
- Anti-rationalization table unchanged

The improvement is purely in the **onboarding experience** — how the user gets from "I want to optimize X" to the loop starting.

## Risks

| Risk | Mitigation |
|---|---|
| Auto-detection guesses wrong | User can always override via wizard options |
| Dry-run adds startup time | Keep under 30s; skip with `--skip-validate` |
| Domain templates become stale | Templates are in SKILL.md, easy to update |
| Power users feel constrained | `--manual` flag preserves classic flow |

## Success Metrics

- **Setup time**: 5 min -> 60 sec (6x reduction)
- **Setup errors**: ~30% -> <5% (dry-run catches problems)
- **User questions needed**: 14 -> 2-3 (80% reduction)
- **Capabilities preserved**: 100%
- **First-time user completion rate**: Estimated 40% -> 90%
