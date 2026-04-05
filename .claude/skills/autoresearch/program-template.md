# Autoresearch Program Template v3.1.0

This template defines the execution program for an autoresearch session.

## Smart Setup (Default — skip with `--manual`)

Before filling the configuration template, run the 3-phase intelligent onboarding:

### Phase 0: SCOUT (Silent, ~5 sec)
```
# Run in parallel (no user interaction):
1. PROJECT_TYPE  = detect from package.json / pyproject.toml / Cargo.toml / go.mod
2. PKG_MANAGER   = detect pnpm / npm / yarn / bun / pip / cargo
3. SCRIPTS       = discover from package.json scripts / Makefile / pyproject.toml
4. SOURCE_DIRS   = Glob for src/, lib/, app/, pkg/
5. TEST_DIRS     = Glob for tests/, test/, __tests__/, spec/
6. SENSITIVE     = Glob for .env*, config/, migrations/, *.key
7. DOMAIN        = match template from USER_INTENT + PROJECT_TYPE + SCRIPTS
8. TEMPLATE      = load domain template (see SKILL.md Domain Templates)
```

### Phase 1: WIZARD (2-3 AskUserQuestion)
```
# Q1 (MUST_HAVE): Confirm objective from SCOUT + intent parsing
#   Show preview with full pre-filled config for each option
# Q2 (NICE_TO_HAVE): Budget selection (Quick/Standard/Deep/Unlimited)
# Q3 (MUST_HAVE, conditional): Scope — only if target is ambiguous

# Merge answers:
CONFIG = merge(TEMPLATE, SCOUT_DATA, USER_ANSWERS, DEFAULTS)
```

### Phase 2: VALIDATE (Adversarial Dry-Run, ~10 sec)
```bash
# V1: Check git is clean
[[ -n $(git status --porcelain) ]] && ask_user_to_commit_or_stash

# V2: Verify target exists
[[ ! -e "$TARGET" ]] && ask_for_correct_path

# V3: Dry-run eval harness
timeout 120 bash -c "$EVAL_HARNESS" > run.log 2>&1
[[ $? -ne 0 ]] && show_error_and_ask_for_correct_command

# V4: Verify metric extraction (with auto-fix)
METRIC_LINE=$(grep "^METRIC" run.log | head -1)
[[ -z "$METRIC_LINE" ]] && try_auto_fix_patterns_or_ask_user

# V5: Extract baseline from dry-run
BASELINE=$(echo "$METRIC_LINE" | cut -d= -f2)

# V6 (optional): Run eval a 2nd time to check determinism
# If delta > 5%, warn about non-determinism

# Show final confirmation with AskUserQuestion
```

### Skip to Manual Mode
If `--manual` flag is set, skip directly to the Configuration section below.

---

## Configuration

> Values below are filled by Smart Setup (Phase 0-2) or manually by the user.

```yaml
target: "{{TARGET}}"
eval_harness: "{{EVAL_HARNESS}}"
primary_metric: "{{PRIMARY_METRIC}}"
metric_direction: "{{METRIC_DIRECTION}}"
secondary_metrics: "{{SECONDARY_METRICS}}"
metric_mode: "{{METRIC_MODE}}"
metric_weights: "{{METRIC_WEIGHTS}}"
threshold: "{{THRESHOLD}}"
checkpoint_mode: "{{CHECKPOINT_MODE}}"
time_budget: "{{TIME_BUDGET}}"
budget_max_experiments: {{BUDGET_MAX_EXPERIMENTS}}
budget_max_hours: {{BUDGET_MAX_HOURS}}
budget_max_cost_usd: {{BUDGET_MAX_COST_USD}}
checks_script: "{{CHECKS_SCRIPT}}"
checks_timeout: "{{CHECKS_TIMEOUT}}"
tag: "{{TAG}}"
off_limits: "{{OFF_LIMITS}}"
constraints: "{{CONSTRAINTS}}"
```

## Initialization

```bash
# 1. Create experiment branch
git checkout -b autoresearch/{{TAG}}

# 2. Read target files deeply — understand the workload before writing anything
# Read: {{TARGET}}

# 3. Create autoresearch.sh benchmark script
cat > autoresearch.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail

# Pre-check: fast validation (<1s)
# Example for Python: python -c "import ast; ast.parse(open('{{TARGET}}').read())"
# Example for JS/TS: npx tsc --noEmit 2>/dev/null || true

# Run experiment (redirect output — don't flood agent context)
{{EVAL_HARNESS}} > run.log 2>&1

# Extract metrics — output METRIC name=number lines
grep "^{{PRIMARY_METRIC}}:" run.log | awk '{print "METRIC {{PRIMARY_METRIC}}="$2}'
# Add secondary metrics extraction here if configured
SCRIPT
chmod +x autoresearch.sh

# 4. Create autoresearch.checks.sh (ONLY if constraints require correctness validation)
# cat > autoresearch.checks.sh << 'CHECKS'
# #!/bin/bash
# set -euo pipefail
# # Suppress verbose output, only show errors
# <test_command> 2>&1 | tail -50
# <typecheck_command> 2>&1 | grep -i error || true
# CHECKS
# chmod +x autoresearch.checks.sh

# 5. Create autoresearch.md session document
cat > autoresearch.md << 'SESSION'
# Autoresearch: {{TAG}}

## Objective
<describe what we're optimizing>

## Metrics
- **Primary**: {{PRIMARY_METRIC}} ({{METRIC_DIRECTION}})
- **Secondary**: {{SECONDARY_METRICS}}

## How to Run
`./autoresearch.sh` — outputs `METRIC name=number` lines.

## Files in Scope
- {{TARGET}}

## Off Limits
- {{OFF_LIMITS}}

## Constraints
- {{CONSTRAINTS}}

## Baseline
- Primary: <to be filled after first run>
- Commit: <to be filled>

## Best Result
- Primary: <to be filled>
- Commit: <to be filled>
- Iteration: 0

## What's Been Tried
### Kept
### Discarded
### Crashed
### Dead Ends

## Key Insights
SESSION

# 6. Initialize results tracking
echo -e "iteration\tcommit\tmetric\tsecondary\tdelta\tstatus\tdescription\ttimestamp" > results.tsv

# 7. Initialize JSONL log (empty file)
touch autoresearch.jsonl

# 8. Initialize ideas backlog
cat > autoresearch.ideas.md << 'IDEAS'
# Ideas Backlog

## High Priority

## Speculative
IDEAS

# 9. Commit setup files
git add -A
git commit -m "autoresearch: initialize session {{TAG}}"

# 10. Run baseline
./autoresearch.sh > run.log 2>&1
BASELINE=$(grep "^METRIC" run.log | head -1 | cut -d= -f2)
echo "Baseline metric: $BASELINE"

# 11. Log baseline
COMMIT=$(git rev-parse --short HEAD)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo -e "0\t$COMMIT\t$BASELINE\t\t+0.000\tkeep\tbaseline\t$TIMESTAMP" >> results.tsv
echo "{\"iter\":0,\"commit\":\"$COMMIT\",\"primary\":{\"{{PRIMARY_METRIC}}\":$BASELINE},\"secondary\":{},\"delta\":0,\"status\":\"keep\",\"description\":\"baseline\",\"timestamp\":\"$TIMESTAMP\",\"wall_seconds\":0}" >> autoresearch.jsonl
```

## Loop Body (per iteration)

```
BEST_KNOWN = BASELINE
STAGNATION = 0
ITER = 1
START_TIME = now()
EXPERIMENTS_RUN = 0

LOOP FOREVER:
  1. Read target files, autoresearch.md, results history, ideas backlog
  2. Identify ONE improvement opportunity (consider stagnation level for strategy)
  3. Implement the change (single focused diff)
  4. git add -A && git commit -m "autoresearch: <description>"
  5. ./autoresearch.sh > run.log 2>&1
  6. METRICS = grep "^METRIC" run.log

  7. If METRICS is empty (crash):
       tail -n 50 run.log  # read error
       If trivial to fix: fix and re-run
       Else: status = "crash", git reset --hard HEAD~1, log, continue
       If 3 consecutive crashes same cause: STOP

  8. If autoresearch.checks.sh exists AND benchmark passed:
       ./autoresearch.checks.sh > checks.log 2>&1
       If checks fail: status = "checks_failed", git reset --hard HEAD~1, log, continue

  9. PRIMARY = extract primary metric from METRICS
     DELTA = PRIMARY - BEST_KNOWN

  10. Evaluate based on metric_mode:
      single:
        If {{METRIC_DIRECTION}} and DELTA is improvement:
          status = "keep", BEST_KNOWN = PRIMARY, STAGNATION = 0
        Elif DELTA == 0 and code is simpler (fewer lines, less complexity):
          status = "keep" (simplicity win), STAGNATION = 0
        Else:
          status = "discard", git reset --hard HEAD~1, STAGNATION += 1

      primary_secondary:
        If primary improved AND secondary not degraded beyond threshold:
          status = "keep"
        Else: status = "discard"

      pareto:
        If (primary better AND secondary not worse) OR (secondary better AND primary not worse):
          status = "keep"
        Else: status = "discard"

      weighted:
        SCORE = w1 * normalize(primary) + w2 * normalize(secondary)
        If SCORE > BEST_SCORE: status = "keep"
        Else: status = "discard"

  11. Log to autoresearch.jsonl:
      {"iter":ITER, "commit":HASH, "primary":{...}, "secondary":{...},
       "delta":DELTA, "status":STATUS, "description":DESC,
       "timestamp":ISO8601, "wall_seconds":ELAPSED}

  12. Log to results.tsv:
      ITER  HASH  PRIMARY  SECONDARY_STR  DELTA  STATUS  DESC  TIMESTAMP

  13. Update autoresearch.md every 5-10 iterations (What's Been Tried, Best Result, Key Insights)

  14. Budget checks:
      If EXPERIMENTS_RUN >= budget_max_experiments: STOP
      If elapsed_hours() >= budget_max_hours: STOP
      If estimated_cost() >= budget_max_cost_usd: STOP

  15. Checkpoint check:
      If checkpoint_mode triggers (every N% improvement from baseline):
        AskUserQuestion with checkpoint template

  16. ITER += 1, EXPERIMENTS_RUN += 1
  17. NEVER ASK "should I continue?" — REPEAT
```

## Checkpoint Template

```
Autoresearch Checkpoint
=======================
Branch: autoresearch/{{TAG}}
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

## Completion Report

```
Autoresearch Complete
=====================
Branch: autoresearch/{{TAG}}
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

Session files:
- autoresearch.md    — session document (resumable)
- autoresearch.jsonl — structured log
- results.tsv        — human-readable log
- autoresearch.ideas.md — remaining ideas

To merge: git checkout main && git merge autoresearch/{{TAG}}
```

## Domain Examples

### ML Training (karpathy-style)
```yaml
target: "train.py"
eval_harness: "uv run train.py"
primary_metric: "val_bpb"
metric_direction: "lower_is_better"
secondary_metrics: {"peak_vram_mb": "lower_is_better"}
time_budget: "5m"
off_limits: "prepare.py"
constraints: "No new dependencies. No modifying evaluation."
```

### Test Speed Optimization
```yaml
target: "src/"
eval_harness: "pnpm test --run"
primary_metric: "duration_seconds"
metric_direction: "lower_is_better"
checks_script: "pnpm typecheck"
constraints: "All tests must still pass."
```

### Bundle Size Reduction
```yaml
target: "src/"
eval_harness: "pnpm build && du -sb dist"
primary_metric: "bundle_kb"
metric_direction: "lower_is_better"
secondary_metrics: {"build_seconds": "lower_is_better"}
metric_mode: "primary_secondary"
constraints: "No removing features. Tests must pass."
```

### Prompt Engineering
```yaml
target: "prompt.txt"
eval_harness: "./eval_prompt.sh"
primary_metric: "accuracy"
metric_direction: "higher_is_better"
secondary_metrics: {"cost_usd": "lower_is_better"}
metric_mode: "primary_secondary"
budget_max_experiments: 50
budget_max_cost_usd: 10.00
```

### SQL Query Optimization
```yaml
target: "query.sql"
eval_harness: "./bench_query.sh"
primary_metric: "exec_time_ms"
metric_direction: "lower_is_better"
constraints: "Results must be identical. No schema changes."
```
