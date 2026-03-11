# Autoresearch Program Template

This template defines the execution program for an autoresearch session.

## Configuration

```yaml
target: "{{TARGET}}"
metric_cmd: "{{METRIC_CMD}}"
metric_direction: "{{METRIC_DIRECTION}}"
threshold: "{{THRESHOLD}}"
checkpoint_mode: "{{CHECKPOINT_MODE}}"
max_stagnation: {{MAX_STAGNATION}}
time_budget: "{{TIME_BUDGET}}"
tag: "{{TAG}}"
```

## Initialization

```bash
# Create experiment branch
git checkout -b autoresearch/{{TAG}}

# Capture baseline metric
BASELINE=$({{METRIC_CMD}})
echo "Baseline metric: $BASELINE"

# Initialize results tracking
echo -e "iteration\tcommit\tmetric\tdelta\tstatus\tdescription\ttimestamp" > results.tsv
```

## Loop Body (per iteration)

```
1. Read target files and results.tsv history
2. Identify ONE improvement opportunity
3. Implement the change
4. git add -A && git commit -m "autoresearch: <description>"
5. METRIC=$({{METRIC_CMD}})
6. DELTA = METRIC - BEST_KNOWN
7. If {{METRIC_DIRECTION}} and DELTA is improvement:
     - Update BEST_KNOWN = METRIC
     - Log: iteration  commit  metric  delta  KEEP  description  timestamp
     - Reset stagnation counter
   Else:
     - git revert HEAD --no-edit
     - Log: iteration  commit  metric  delta  DISCARD  description  timestamp
     - Increment stagnation counter
8. If stagnation >= {{MAX_STAGNATION}}: STOP
9. If checkpoint triggers: ASK USER
```

## Checkpoint Template

```
Autoresearch Checkpoint
=======================
Branch: autoresearch/{{TAG}}
Iterations: N (K improvements, J discards)
Baseline: BASELINE_VALUE
Current best: BEST_VALUE (DELTA_PCT% improvement)
Success rate: K/N%

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
Improvements: K / N (success_rate%)
Baseline metric: BASELINE
Final best metric: BEST (total_improvement%)

Top improvements:
1. <description> (+delta)
2. <description> (+delta)
...

Results file: results.tsv
To merge: git checkout main && git merge autoresearch/{{TAG}}
```
