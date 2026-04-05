---
# VERSION: 3.1.0
name: autoresearch
description: "Autonomous experiment loop: modifies code, runs experiments, evaluates metrics, keeps improvements. Inspired by karpathy/autoresearch + pi-autoresearch + autoexp. Triggers: /autoresearch, 'auto research', 'optimize continuously', 'experiment loop', 'autonomous optimization'."
argument-hint: "[\"<goal>\"] [<target-path>] [--manual] [--budget=quick|standard|deep|unlimited] [--checkpoint=5|10|infinity]"
user-invocable: true
context: fork
agent: autoresearch
allowed-tools:
  - Task
  - Read
  - Edit
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# /autoresearch - Autonomous Experimentation Loop (v3.1.0)

Continuously modify code, run experiments, evaluate metrics, and keep improvements. The agent is a tireless researcher, not an assistant waiting for permission.

Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch), [davebcn87/pi-autoresearch](https://github.com/davebcn87/pi-autoresearch), and [autoexp](https://gist.github.com/adhishthite/16d8fd9076e85c033b75e187e8a6b94e).

## Overview

```
+------------------------------------------------------------------+
|                   AUTORESEARCH LOOP                               |
+------------------------------------------------------------------+
|                                                                   |
|   +-------------+    +----------+    +-----------+                |
|   | HYPOTHESIZE |--->|  MODIFY  |--->|  COMMIT   |                |
|   | (strategy)  |    | (code)   |    | (git)     |                |
|   +-------------+    +----------+    +-----+-----+                |
|                                            |                      |
|                                            v                      |
|   +-------------+    +----------+    +-----------+                |
|   | CHECKPOINT? |<---| EVALUATE |<---|    RUN    |                |
|   | (ask user?) |    | (delta)  |    | (metric)  |                |
|   +------+------+    +----+-----+    +-----------+                |
|          |                |                                       |
|     continue?        improved?                                    |
|          |           /    |    \                                   |
|          v         YES  EQUAL   NO                                |
|       REPEAT      KEEP  SIMPLICITY  DISCARD                      |
|                  (keep)  CHECK?    (git reset)                    |
+------------------------------------------------------------------+
```

## Invocation Modes

### Smart Mode (Default) — `/autoresearch "optimize my tests"`

Three-phase intelligent onboarding that auto-detects project configuration:

| Phase | Name | Duration | User Interaction |
|---|---|---|---|
| 0 | SCOUT | ~5 sec | None (silent) |
| 1 | WIZARD | ~30 sec | 2-3 AskUserQuestion |
| 2 | VALIDATE | ~10 sec | None (automatic) |

### Manual Mode — `/autoresearch --manual`

Classic monolithic setup contract (full 14+ parameter form). Use when:
- Auto-detection guesses wrong and you want full control
- Advanced configurations (weighted metrics, custom thresholds)
- Resuming an existing session with different parameters

### Direct Mode — `/autoresearch src/model.py "uv run train.py" --checkpoint=5`

When all required params are provided inline, skip SCOUT/WIZARD entirely. Still runs VALIDATE.

### Resume Mode — automatic on `autoresearch/<tag>` branch

If `autoresearch.md` exists on the current branch, skip ALL setup phases (SCOUT, WIZARD, VALIDATE) and resume the experiment loop immediately. See [Resumability](#resumability) for details.

---

## Phase 0: SCOUT (Silent Auto-Detection)

Before asking the user anything, silently analyze the project to pre-fill ~80% of configuration fields. Run these checks in parallel:

### Project Type Detection

| Check | Tool | Detects |
|---|---|---|
| `package.json` exists | Glob | Node.js (check `tsconfig.json` for TypeScript) |
| `pyproject.toml` or `requirements.txt` | Glob | Python |
| `Cargo.toml` | Glob | Rust |
| `go.mod` | Glob | Go |
| `pom.xml` or `build.gradle` | Glob | Java |
| `Makefile` | Glob | C/C++ or generic |

Reference: Reuse patterns from `detect_language()` in `.claude/scripts/curator-learn.sh` (lines 98-118).

### Script Discovery

| Project Type | Where to Look | What to Extract |
|---|---|---|
| Node.js | `scripts` in `package.json` | test, build, bench, lint commands |
| Python | `[project.scripts]` in `pyproject.toml`, `Makefile` targets | test, train, bench commands |
| Rust | `Cargo.toml` `[[bench]]` sections, `Makefile` | bench, test commands |
| Generic | `Makefile`, `*.sh` scripts in root | Any runnable targets |

### Metric Pattern Detection

Grep target files and scripts for common metric output patterns:

| Pattern | Likely Metric | Direction |
|---|---|---|
| `loss`, `val_loss`, `bpb`, `val_bpb` | ML training loss | lower_is_better |
| `accuracy`, `acc`, `f1`, `precision`, `recall` | ML evaluation | higher_is_better |
| `duration`, `time`, `seconds`, `elapsed` | Speed/performance | lower_is_better |
| `size`, `bytes`, `kb`, `bundle` | Size reduction | lower_is_better |
| `score`, `perf`, `lighthouse` | Quality score | higher_is_better |
| `latency`, `p50`, `p95`, `p99` | API latency | lower_is_better |

### File Structure Analysis

| What | How | Purpose |
|---|---|---|
| Source directories | Glob `src/`, `lib/`, `app/`, `pkg/` | Pre-fill `target` |
| Config files | Glob `*.config.*`, `tsconfig.*`, `vite.*`, `webpack.*` | Pre-fill `target` (optional) |
| Test directories | Glob `tests/`, `test/`, `__tests__/`, `spec/` | Pre-fill `checks_script` |
| Sensitive files | Glob `.env*`, `config/`, `migrations/`, `*.key` | Pre-fill `off_limits` |

### SCOUT Output

The SCOUT phase produces a `scout_result` object used by WIZARD and VALIDATE:

```yaml
scout_result:
  project_type: "typescript"       # detected language/framework
  package_manager: "pnpm"          # npm/yarn/pnpm/bun/pip/cargo
  available_scripts:               # discovered runnable commands
    - name: "test"
      command: "pnpm test --run"
    - name: "build"
      command: "pnpm build"
    - name: "typecheck"
      command: "pnpm typecheck"
  source_dirs: ["src/", "lib/"]
  test_dirs: ["tests/"]
  config_files: ["vite.config.ts", "tsconfig.json"]
  sensitive_files: [".env", ".env.local"]
  detected_metrics: []
  domain_match: "node_tests"       # matched domain template (or "custom")
```

---

## Domain Templates

Templates pre-fill ALL 14 fields based on detected project type + user intent. The user only needs to confirm or override. If no template matches, fall through to full WIZARD (equivalent to `--manual` mode).

| Template | Detection | Metric | Direction | Budget | Tag |
|---|---|---|---|---|---|
| ML Training | `train.py` or `import torch\|tensorflow\|jax` | `val_loss` | lower | 50 | `ml-training` |
| Node.js Test Speed | `package.json` + `vitest\|jest` in devDeps | `duration_seconds` | lower | 30 | `test-speed` |
| Bundle Size | `package.json` + `vite\|webpack\|esbuild` | `bundle_kb` | lower | 30 | `bundle-size` |
| Python Test Speed | `pyproject.toml` + `pytest` | `duration_seconds` | lower | 30 | `pytest-speed` |
| Prompt Engineering | `.txt`/`.md` prompt files + eval script | `accuracy` | higher | 50 | `prompt-engineering` |
| SQL Optimization | `.sql` files + bench script | `exec_time_ms` | lower | 20 | `sql-optimization` |
| Rust Performance | `Cargo.toml` + `[[bench]]`/`criterion` | `time_ns` | lower | 30 | `rust-perf` |
| Lighthouse | `next.config.*` or `index.html` | `perf_score` | higher | 20 | `lighthouse` |

### Representative Template: ML Training (multi-metric)
```yaml
target: "train.py"
eval_harness: "uv run train.py"
primary_metric: "val_loss"
metric_direction: "lower_is_better"
secondary_metrics: {"peak_vram_mb": "lower_is_better"}
metric_mode: "primary_secondary"
checkpoint_mode: "5"
time_budget: "10m"
budget_max_experiments: 50
off_limits: ".git/, .claude/, tests/, data/"
constraints: "No new dependencies. No modifying evaluation logic."
tag: "ml-training"
```

### Representative Template: Node.js Test Speed (single metric)
```yaml
target: "src/"
eval_harness: "{pkg_manager} test --run"
primary_metric: "duration_seconds"
metric_direction: "lower_is_better"
metric_mode: "single"
checkpoint_mode: "infinity"
time_budget: "2m"
budget_max_experiments: 30
checks_script: "{pkg_manager} typecheck"
off_limits: ".git/, .claude/, node_modules/"
constraints: "All tests must still pass. No removing test cases."
tag: "test-speed"
```

All templates share: `off_limits` always includes `.git/, .claude/`; `metric_mode` defaults to `single` unless secondary metrics are configured.



---

## Intent Parsing

Parse the user's natural language to determine optimization goal:

| User Input Pattern | Parsed Intent | Domain Template |
|---|---|---|
| "optimize tests", "speed up tests", "faster tests" | test_speed | Node.js Tests / Python Tests |
| "reduce bundle", "smaller bundle", "bundle size" | bundle_size | Bundle Size Reduction |
| "improve accuracy", "better model", "train" | ml_training | ML Training |
| "optimize prompts", "better prompts" | prompt_quality | Prompt Engineering |
| "faster queries", "optimize SQL" | sql_speed | SQL Query Optimization |
| "lighthouse score", "web performance" | web_perf | Lighthouse |
| "cargo bench", "rust performance" | rust_perf | Rust Performance |
| "speed up build", "faster build" | build_speed | Bundle Size (build variant) |

Keywords that signal direction:
- **lower_is_better**: "reduce", "minimize", "speed up", "faster", "smaller", "less", "lower"
- **higher_is_better**: "improve", "maximize", "increase", "better", "higher", "more"

---

## Phase 1: WIZARD (Smart Questions)

Present 2-3 AskUserQuestion calls with pre-filled options from SCOUT + Domain Template. Follows the `/clarify` MUST_HAVE/NICE_TO_HAVE pattern.

### Question 1 — Objective (MUST_HAVE, always asked)

Based on SCOUT results, present detected optimization opportunities with previews:

```yaml
AskUserQuestion:
  questions:
    - question: "I analyzed your project. What should I optimize?"
      header: "Objective"
      multiSelect: false
      options:
        # Options generated dynamically from SCOUT results
        # Each option shows a preview with the full pre-filled config
        - label: "{detected_option_1} (Recommended)"
          description: "Detected: {command} -> {current_value}. Goal: {direction}"
          preview: |
            Target:     {target}
            Eval:       {eval_harness}
            Metric:     {metric} ({direction})
            Checks:     {checks_script}
            Budget:     {budget} experiments
        - label: "{detected_option_2}"
          description: "Detected: {command} -> {current_value}"
          preview: |
            Target:     {target}
            Eval:       {eval_harness}
            Metric:     {metric} ({direction})
        # "Other" is always available via AskUserQuestion default behavior
```

### Question 2 — Budget (NICE_TO_HAVE, always asked, has recommended default)

```yaml
AskUserQuestion:
  questions:
    - question: "Experimentation budget?"
      header: "Budget"
      multiSelect: false
      options:
        - label: "Quick - 10 experiments (~30 min) (Recommended)"
          description: "Good for parameter tweaks and small optimizations"
        - label: "Standard - 50 experiments (~2h)"
          description: "Structural changes and algorithm exploration"
        - label: "Deep - 100+ experiments (~4h+)"
          description: "Radical approaches and comprehensive exploration"
        - label: "Unlimited - I'll stop you manually"
          description: "Run indefinitely until interrupted"
```

### Question 3 — Scope (MUST_HAVE, only if ambiguous)

Only ask this if SCOUT found multiple candidate target directories or the intent is unclear:

```yaml
AskUserQuestion:
  questions:
    - question: "Which files can I modify?"
      header: "Scope"
      multiSelect: true
      options:
        # Generated from SCOUT file structure analysis
        - label: "{dir_1} ({n1} files)"
          description: "{dir_description}"
        - label: "{dir_2} ({n2} files)"
          description: "{dir_description}"
        - label: "Config files ({list})"
          description: "Warning: may affect project setup"
```

### Wizard Output

Merge user answers with SCOUT data and domain template to produce the full configuration:

```
full_config = domain_template
  .override(scout_result)      # Auto-detected values
  .override(user_answers)      # User's explicit choices
  .apply_defaults()            # Fill remaining with defaults from Optional Parameters table
```

---

## Phase 2: VALIDATE (Adversarial Dry-Run)

Before starting the loop, validate the configuration with a quick dry-run. Inspired by `/adversarial` graduated escalation pattern.

### Validation Checks

| # | Check | How | On Failure | Severity |
|---|---|---|---|---|
| V1 | Git is clean | `git status --porcelain` | Ask user to commit/stash | CRITICAL |
| V2 | Target files exist | `ls $TARGET` | Correct path, re-ask | CRITICAL |
| V3 | Eval harness executes | `timeout 120 bash -c "$EVAL_HARNESS" > run.log 2>&1` | Show error, ask for correct command | CRITICAL |
| V4 | Metric extracts | `grep "^METRIC" run.log` | Auto-adjust extraction pattern OR ask user | CRITICAL |
| V5 | Checks script works | `timeout 60 $CHECKS_SCRIPT 2>&1` (if configured) | Warn, offer to disable | WARNING |
| V6 | Baseline is stable | Run eval_harness 2nd time, compare metrics | Warn about non-determinism, suggest higher threshold | WARNING |

### Auto-Fix for Metric Extraction (V4)

If `METRIC name=value` not found in eval output, attempt automatic fixes:

1. Search for `name: value` pattern → transform to `METRIC name=value` in autoresearch.sh
2. Search for `name = value` pattern → transform to `METRIC name=value`
3. Search for JSON output → extract with `jq` or `python -c`
4. If no pattern found, show last 20 lines of output and ask user which line contains the metric

### Final Confirmation

After all checks pass, present the complete configuration for user approval:

```yaml
AskUserQuestion:
  questions:
    - question: "Configuration validated. Ready to start?"
      header: "Confirm"
      multiSelect: false
      options:
        - label: "Start experimenting (Recommended)"
          description: "Begin the autonomous optimization loop"
          preview: |
            Branch:     autoresearch/{tag}
            Target:     {target} ({n} files)
            Eval:       {eval_harness}
            Metric:     {primary_metric} ({metric_direction})
            Baseline:   {baseline_value}
            Budget:     {budget_description}
            Checks:     {checks_script | "none"}
            Off-limits: {off_limits}
        - label: "Adjust configuration"
          description: "Go back and change settings"
        - label: "Switch to manual mode"
          description: "Use the full 14-parameter setup form"
```

---

## Setup Contract — Manual Mode

> **Note**: This section describes the manual setup flow (`--manual` flag or "Adjust configuration" from VALIDATE). For the default smart setup, see [Phase 0: SCOUT](#phase-0-scout-silent-auto-detection), [Phase 1: WIZARD](#phase-1-wizard-smart-questions), and [Phase 2: VALIDATE](#phase-2-validate-adversarial-dry-run) above.

Every autoresearch run needs these components defined upfront. Use `AskUserQuestion` to collect them interactively.

### Required Parameters

| Component | Description | Example |
|-----------|-------------|---------|
| `target` | File(s) the agent CAN modify | `src/model.py`, `lib/`, `prompt.txt` |
| `eval_harness` | Command that produces the metric(s) | `uv run train.py`, `pnpm test`, `./bench.sh` |
| `primary_metric` | Name + extraction pattern | `val_bpb` via `grep "^val_bpb:" run.log` |
| `metric_direction` | Which direction is better | `lower_is_better` or `higher_is_better` |

### Optional Parameters (with defaults)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `secondary_metrics` | none | Additional metrics to track (dict: name -> direction) |
| `metric_mode` | `single` | `single`, `primary_secondary`, `pareto`, or `weighted` |
| `metric_weights` | none | For weighted mode: `{metric1: 0.7, metric2: 0.3}` |
| `threshold` | any improvement | Minimum delta to keep a change |
| `checkpoint_mode` | `infinity` | When to pause: `infinity` (never), `5` (every 5%), `10` (every 10%) |
| `time_budget` | `5m` | Max time per experiment run |
| `budget_max_experiments` | `infinity` | Hard stop after N experiments |
| `budget_max_hours` | `infinity` | Hard stop after N hours wall clock |
| `budget_max_cost_usd` | `infinity` | Estimated cost cap (tokens/compute) |
| `checks_script` | none | Path to correctness checks script (tests, types, lint) |
| `checks_timeout` | `300s` | Timeout for checks script |
| `tag` | auto-generated | Branch name: `autoresearch/<tag>` |
| `off_limits` | `.git/, .claude/, tests/` | Files/dirs the agent must NEVER touch |
| `constraints` | none | Additional constraints (e.g., "no new dependencies") |

### Parameter Collection

Use `AskUserQuestion` to confirm parameters before starting:

```
Autoresearch Setup
==================
Target:          <target>
Eval harness:    <eval_command>
Primary metric:  <metric_name> (<direction>)
Secondary:       <metric2_name> (<direction>), ... | none
Metric mode:     single | primary_secondary | pareto | weighted
Checkpoint:      every <N>% | never
Budget:          <max_experiments> runs | <max_hours>h | unlimited
Checks:          <checks_script> | none
Branch:          autoresearch/<tag>

Proceed? (y/n)
```

## Session Files

The loop creates and maintains these files on the experiment branch:

### `autoresearch.md` — Living Session Document

The heart of the session. A fresh agent with zero context should be able to read this file and continue the loop effectively. Invest time making it excellent.

```markdown
# Autoresearch: <objective>

## Objective
<clear description of what we're optimizing>

## Metrics
- **Primary**: <name> (<unit>, lower/higher is better)
- **Secondary**: <name>, <name>, ...

## How to Run
`./autoresearch.sh` or `<eval_command>` — outputs `METRIC name=number` lines.

## Files in Scope
- <file1> — <what it contains>
- <file2> — <what it contains>

## Off Limits
- <file/dir> — <why>

## Constraints
- <constraint1>
- <constraint2>

## Baseline
- Primary: <value>
- Secondary: <values>
- Commit: <hash>

## Best Result
- Primary: <value> (<delta>% from baseline)
- Secondary: <values>
- Commit: <hash>
- Iteration: <N>

## What's Been Tried
### Kept
- [iter N] <description> — metric: <value> (+<delta>)
### Discarded
- [iter N] <description> — metric: <value> (<delta>)
### Crashed
- [iter N] <description> — <error summary>
### Dead Ends
- <approach> — why it doesn't work

## Key Insights
- <insight1>
- <insight2>
```

Update `autoresearch.md` periodically — especially "What's Been Tried" and "Key Insights" — so resuming agents have full context.

### `autoresearch.sh` — Benchmark Script

Bash script (`set -euo pipefail`) that: pre-checks fast (syntax errors in <1s), runs the workload, outputs `METRIC name=number` lines. Keep it fast — every second is multiplied by hundreds of runs.

```bash
#!/bin/bash
set -euo pipefail

# Pre-check: fast syntax validation
python -c "import ast; ast.parse(open('train.py').read())"

# Run experiment, redirect to log (don't flood agent context)
<eval_command> > run.log 2>&1

# Extract metrics
grep "^val_bpb:" run.log | awk '{print "METRIC val_bpb="$2}'
grep "^peak_vram_mb:" run.log | awk '{print "METRIC peak_vram_mb="$2}'
```

### `autoresearch.checks.sh` — Backpressure Checks (optional)

Only create when constraints require correctness validation (e.g., "tests must pass", "types must check"). When this file exists:

- Runs automatically after every passing benchmark
- If checks fail, log as `checks_failed` (revert, no commit)
- Execution time does NOT affect the primary metric
- Has a separate timeout (default 300s)
- Keep output minimal — only last 80 lines on failure

```bash
#!/bin/bash
set -euo pipefail
# Suppress success output, only show errors
pnpm test --run --reporter=dot 2>&1 | tail -50
pnpm typecheck 2>&1 | grep -i error || true
```

### `autoresearch.ideas.md` — Ideas Backlog

When you discover complex but promising optimizations you won't pursue right now, append them as bullets. Don't let good ideas get lost.

On resume (context limit, crash), check this file — prune stale/tried entries, experiment with the rest. When all paths exhausted, delete the file.

```markdown
# Ideas Backlog

## High Priority
- [ ] <idea with rationale>
- [ ] <idea with rationale>

## Speculative
- [ ] <wild idea>
```

### `autoresearch.jsonl` — Structured Log

Append-only, one JSON object per line. Survives restarts and context resets.

```jsonl
{"iter":1,"commit":"abc1234","primary":{"val_bpb":0.997},"secondary":{"peak_vram_mb":44.0},"delta":0,"status":"keep","description":"baseline","timestamp":"2026-03-14T20:00:00Z","wall_seconds":305}
{"iter":2,"commit":"def5678","primary":{"val_bpb":0.993},"secondary":{"peak_vram_mb":44.2},"delta":-0.004,"status":"keep","description":"increased LR to 0.04","timestamp":"2026-03-14T20:05:30Z","wall_seconds":302}
{"iter":3,"commit":"ghi9012","primary":{"val_bpb":1.005},"secondary":{"peak_vram_mb":44.0},"delta":+0.012,"status":"discard","description":"switched to GeLU","timestamp":"2026-03-14T20:11:00Z","wall_seconds":301}
```

### `results.tsv` — Human-Readable Log

Tab-separated, simple, diffable. Kept in sync with JSONL.

```tsv
iteration	commit	metric	secondary	delta	status	description	timestamp
1	abc1234	0.997	vram=44.0	+0.000	keep	baseline	2026-03-14T20:00:00Z
2	def5678	0.993	vram=44.2	-0.004	keep	increased LR to 0.04	2026-03-14T20:05:30Z
3	ghi9012	1.005	vram=44.0	+0.012	discard	switched to GeLU	2026-03-14T20:11:00Z
```

## Branch Management

1. Create branch: `git checkout -b autoresearch/<tag>`
2. Each improvement is committed: `git add -A && git commit -m "autoresearch: <description>"`
3. Failed experiments are **reset** (NOT reverted): `git reset --hard HEAD~1`
4. This avoids polluting history with revert commits
5. Final results can be merged to the original branch

## Loop Execution Pattern

```
LOOP FOREVER:
  1. ANALYZE    - Read target files, autoresearch.md, results history, ideas backlog
  2. HYPOTHESIZE - Identify ONE specific improvement with rationale
  3. MODIFY      - Make ONE focused change to target files only
  4. COMMIT      - git add -A && git commit -m "autoresearch: <description>"
  5. RUN         - Execute: ./autoresearch.sh > run.log 2>&1
                   Extract: grep "^METRIC" run.log
  6. CHECKS      - If autoresearch.checks.sh exists: run it
                   If checks fail: status = checks_failed, reset
  7. EVALUATE    - Compare primary metric to best known:
                   - IMPROVED  -> status = keep, update best
                   - EQUAL     -> apply simplicity criterion (see below)
                   - WORSE     -> status = discard, git reset --hard HEAD~1
  8. LOG         - Append to autoresearch.jsonl AND results.tsv
                   Update autoresearch.md periodically
  9. BUDGET?     - Check budget caps (experiments, hours, cost)
  10. CHECKPOINT? - If checkpoint_mode triggers, ask user
  11. REPEAT      - NEVER ASK "should I continue?"
```

## NEVER STOP

Once the experiment loop has begun, do NOT pause to ask if you should continue. Do NOT ask "should I keep going?" or "is this a good stopping point?". The user might be asleep or away and expects you to continue working **indefinitely** until:

1. **Budget cap hit**: max_experiments, max_hours, or max_cost_usd reached
2. **Manual interrupt**: User interrupts or sends a stop message
3. **Metric failure**: eval harness fails 3 times consecutively with unfixable errors

If you run out of ideas:
- Re-read source files for new angles
- Check `autoresearch.ideas.md` for untried approaches
- Try combining previous near-misses
- Try more radical architectural changes
- Think harder — the best ideas come from deep understanding

**The agent is a tireless researcher, not an assistant waiting for permission.**

## Dual Metric Mode

When multiple metrics are configured, use the selected mode:

### `single` (default)
Only one metric matters. Standard hill-climbing.

### `primary_secondary`
Improve primary; secondary is a soft constraint.
- KEEP if primary improved AND secondary didn't degrade beyond threshold
- Example: "accuracy must improve; latency shouldn't 2x"

### `pareto`
Keep if better on either metric without regressing on the other.
- KEEP if (metric1 improved AND metric2 not worse) OR (metric2 improved AND metric1 not worse)

### `weighted`
Collapse to single scalar: `score = w1 * metric1_normalized + w2 * metric2_normalized`
- Normalize each metric to 0-1 range using baseline as reference
- Apply weights from `metric_weights` config

## Simplicity Criterion

**Simpler is better.** When evaluating whether to keep a change, weigh the complexity cost against the improvement magnitude:

- **Equal metric + fewer lines of code** -> KEEP (simplification win)
- **Tiny improvement + lots of ugly complexity** -> probably DISCARD
- **Removing code for equal or better results** -> definitely KEEP
- **Metric ~0 improvement but much simpler code** -> KEEP

A 0.001 improvement that adds 20 lines of hacky code? Probably not worth it.
A 0.001 improvement from deleting code? Definitely keep.

## Crash Handling

Statuses: `keep` | `discard` | `crash` | `checks_failed`

- **`crash`**: Eval harness failed (OOM, bug, timeout)
  - If trivial to fix (typo, missing import): fix and re-run
  - If fundamentally broken: log as crash, move on
  - 3 consecutive crashes with same root cause: STOP and report
- **`checks_failed`**: Benchmark passed but correctness checks failed
  - Always revert — cannot keep broken code
  - Log what check failed for future reference
- **`discard`**: Metric equal or worse
- **`keep`**: Metric improved (or simplicity criterion met)

## Output Redirect

ALWAYS redirect experiment output to a log file to avoid flooding the agent's context window:

```bash
./autoresearch.sh > run.log 2>&1
```

Then extract metrics with grep:
```bash
grep "^METRIC" run.log
```

If the run crashes, read the tail:
```bash
tail -n 50 run.log
```

This is critical for long-running experiments that produce verbose output.

## Cost Awareness

Track and respect budget limits:

| Budget Type | Config Key | Example |
|-------------|------------|---------|
| Max experiments | `budget_max_experiments` | 100 runs |
| Max wall clock | `budget_max_hours` | 8 hours |
| Max cost | `budget_max_cost_usd` | $10.00 |

Log cumulative stats in `autoresearch.md` header and check after each iteration.

## Checkpoint System

When `checkpoint_mode` triggers (every N% improvement), pause and ask user via `AskUserQuestion`:

```
Autoresearch Checkpoint
=======================
Branch: autoresearch/<tag>
Iterations: N (K kept, J discarded, C crashed, F checks_failed)
Baseline: BASELINE_VALUE
Current best: BEST_VALUE (DELTA_PCT% improvement)
Success rate: K/N%
Budget used: X/Y experiments | Xh/Yh hours

Recent changes:
- [KEEP] description (metric: value)
- [DISCARD] description (metric: value)
...

Options:
1. Continue with same strategy
2. Change approach: <describe>
3. Stop and keep results
```

## Resumability

If `autoresearch.md` exists on the current branch, the agent should:

1. Read `autoresearch.md` for full session context
2. Read `autoresearch.jsonl` for detailed history
3. Check `autoresearch.ideas.md` for untried ideas
4. Read `git log --oneline -20` for recent commits
5. Continue looping from where the previous session left off

A fresh agent with no memory should be able to resume from these files alone.

## User Messages During Loop

If the user sends a message while an experiment is running:
1. Finish the current run_experiment + log cycle
2. Incorporate their feedback in the next iteration
3. Don't abandon a running experiment

## Safety Rules

1. ONLY modify files within the declared `target` path
2. NEVER modify files in `off_limits` (default: `.git/`, `.claude/`, test files)
3. NEVER delete existing tests (unless target explicitly includes tests)
4. NEVER commit broken code (metric must run successfully)
5. NEVER install new packages unless explicitly allowed in constraints
6. All changes are on a separate branch (never touch main)
7. Always maintain a clean git state between iterations
8. Redirect experiment output to log files

## Where This Applies

| Domain | Target file | Metric | Eval harness |
|--------|-------------|--------|--------------|
| ML training | `train.py` | val_loss / val_bpb | `uv run train.py` |
| Test speed | `src/`, `vitest.config.ts` | seconds | `pnpm test` |
| Bundle size | `src/`, `webpack.config.js` | KB | `pnpm build && du -sb dist` |
| Prompt engineering | `prompt.txt` | eval_accuracy | LLM judge / test suite |
| Build speed | `src/` | seconds | `pnpm build` |
| Lighthouse | `src/`, `styles.css` | perf score | `lighthouse --output=json` |
| SQL queries | `query.sql` | exec_time_ms | `EXPLAIN ANALYZE` wrapper |
| API latency | `handler.py` | p99_latency | Load test script |
| RAG pipelines | `config.yaml` | retrieval_precision | Benchmark query set |
| Infrastructure | `terraform.tf` | cost_per_hour | `terraform plan` parser |

## What This Doesn't Work For

- **Subjective quality** (UI aesthetics, writing style) — no scalar metric
- **Slow feedback** (deploy -> wait for traffic -> measure) — loop stalls
- **Safety-critical systems** — autonomous modification without human review
- **Multi-repo changes** — too much surface area

## Example Usage

```bash
# Optimize a Python model's accuracy
/autoresearch src/model.py "uv run train.py" --checkpoint=5

# Reduce bundle size with test validation
/autoresearch src/ "npm run build 2>&1 | grep 'bundle size'" --checks="npm test"

# Optimize test performance with budget cap
/autoresearch tests/ "time pytest -q" --budget=50

# Dual metric: accuracy up, latency down
/autoresearch src/ "./bench.sh" --metrics="accuracy:higher,latency_ms:lower" --mode=primary_secondary

# Prompt optimization
/autoresearch prompt.txt "./eval_prompt.sh" --budget=8h
```

## Completion Report

When the loop ends (budget, interrupt, or manual stop):

```
Autoresearch Complete
=====================
Branch: autoresearch/<tag>
Total iterations: N
Results: K kept | J discarded | C crashed | F checks_failed
Success rate: K/N%
Baseline metric: BASELINE
Final best metric: BEST (total_improvement%)
Budget used: X experiments | Xh wall clock

Top improvements:
1. <description> (+delta)
2. <description> (+delta)
...

Key insights:
- <insight1>
- <insight2>

Files: autoresearch.md, autoresearch.jsonl, results.tsv
To merge: git checkout main && git merge autoresearch/<tag>
```

## Related Skills

- `/iterate` - Iterative execution with quality gates
- `/orchestrator` - Full orchestration workflow
- `/gates` - Quality validation
- `/curator` - Learning from external sources

## Anti-Rationalization

See master table: `docs/reference/anti-rationalization.md`

| Excuse | Rebuttal |
|---|---|
| "First experiment worked, stopping" | N=1 is not evidence. Run 3+ experiments. |
| "The metric improved slightly, good enough" | Slight improvement may be noise. Validate. |
| "I can't reproduce the improvement" | Non-reproducible results are not results. |
| "The experiment takes too long" | Budget management, not experiment cancellation. |
| "I modified too many variables" | One variable per experiment. Start over. |
