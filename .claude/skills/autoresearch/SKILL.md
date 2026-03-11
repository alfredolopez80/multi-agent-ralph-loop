---
# VERSION: 2.94.0
name: autoresearch
description: "Autonomous research loop: modifies code, runs experiments, evaluates metrics, keeps improvements. Inspired by karpathy/autoresearch. Triggers: /autoresearch, 'auto research', 'optimize continuously', 'experiment loop', 'autonomous optimization'."
argument-hint: "<target-path> <metric-command> [--checkpoint=infinity|5|10] [--max-stagnation=50]"
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

# /autoresearch - Autonomous Experimentation Loop (v2.94)

Continuously modify code, run experiments, evaluate metrics, and keep improvements. Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch).

## Overview

```
+------------------------------------------------------------------+
|                   AUTORESEARCH LOOP                                |
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
|          |           /        \                                   |
|          v         YES        NO                                  |
|       REPEAT      KEEP     DISCARD                                |
|                  (merge)  (git checkout)                           |
+------------------------------------------------------------------+
```

## Setup Phase (MANDATORY before loop)

When `/autoresearch` is invoked, ALWAYS gather these parameters interactively:

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `target` | File/directory to modify | `src/model.py`, `lib/` |
| `metric_cmd` | Shell command that outputs a number | `pytest -q \| tail -1`, `node bench.js` |
| `metric_direction` | Which direction is better | `lower_is_better` or `higher_is_better` |

### Optional Parameters (with defaults)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `threshold` | any improvement | Minimum delta to keep a change |
| `checkpoint_mode` | `infinity` | When to pause: `infinity` (never), `5` (every 5%), `10` (every 10%) |
| `max_stagnation` | `50` | Consecutive iterations without improvement before stopping |
| `time_budget` | `5m` | Max time per experiment |
| `tag` | auto-generated | Branch name: `autoresearch/<tag>` |

### Parameter Collection

Use `AskUserQuestion` to confirm parameters before starting:

```
Target: <target>
Metric: <metric_cmd>
Direction: <metric_direction>
Checkpoint: every <N>% | never
Max stagnation: <N> iterations
Branch: autoresearch/<tag>

Proceed? (y/n)
```

## Branch Management

1. Create branch: `git checkout -b autoresearch/<tag>`
2. Each improvement is committed on this branch
3. Failed experiments are discarded with `git checkout -- .`
4. Final results can be merged to the original branch

## Loop Execution Pattern

```
LOOP FOREVER:
  1. HYPOTHESIZE - Analyze current code, identify potential improvement
  2. MODIFY      - Make ONE focused change to target files
  3. COMMIT      - git add + git commit (tentative)
  4. RUN         - Execute metric_cmd, capture output number
  5. EVALUATE    - Compare to best known metric
     - IMPROVED  -> Update best, log as KEEP
     - NOT       -> git revert HEAD, log as DISCARD
  6. LOG         - Append to results.tsv
  7. CHECKPOINT? - If checkpoint_mode triggers, ask user
  8. STAGNATION? - If max_stagnation consecutive failures, STOP
  9. REPEAT
```

## Results Tracking

All results are logged to `results.tsv` in the autoresearch branch:

```tsv
iteration	commit	metric	delta	status	description	timestamp
1	abc1234	0.847	+0.012	KEEP	Added dropout layer	2026-03-11T20:00:00Z
2	def5678	0.841	-0.006	DISCARD	Changed learning rate	2026-03-11T20:05:00Z
3	ghi9012	0.853	+0.006	KEEP	Batch normalization	2026-03-11T20:10:00Z
```

## Stop Conditions

The loop stops when ANY of these conditions are met:

1. **Stagnation**: `max_stagnation` consecutive iterations without improvement (default: 50)
2. **Metric failure**: Metric command fails 3 times consecutively
3. **User interrupt**: Manual interruption or checkpoint decision to stop
4. **Branch conflict**: Unable to commit or revert cleanly

## Checkpoint System

When `checkpoint_mode` triggers (every N% improvement), pause and ask user via `AskUserQuestion`:

```
Checkpoint reached! Current best metric: <value> (+<total_delta>% from baseline)
Iterations: <N>, Improvements: <K>, Success rate: <K/N>%

Options:
1. Continue with same strategy
2. Change approach (describe new direction)
3. Stop and keep results
```

## Stagnation Recovery

After N/2 stagnation iterations, try progressively more radical changes:
- First N/4: Small parameter tweaks
- Next N/4: Structural changes
- Final N/2: Radically different approaches

## Safety Rules

1. NEVER modify files outside the `target` path
2. NEVER delete existing tests
3. NEVER commit broken code (metric must run successfully)
4. Always maintain a clean git state between iterations
5. All changes are on a separate branch (never touch main)

## Example Usage

```bash
# Optimize a Python model's accuracy
/autoresearch src/model.py "python eval.py --metric accuracy" --checkpoint=5

# Reduce bundle size
/autoresearch src/ "npm run build 2>&1 | grep 'bundle size' | awk '{print $3}'" --max-stagnation=30

# Improve test performance
/autoresearch tests/ "time pytest -q 2>&1 | grep real | awk '{print $2}'" --checkpoint=10
```

## Related Skills

- `/iterate` - Iterative execution with quality gates
- `/orchestrator` - Full orchestration workflow
- `/gates` - Quality validation
- `/curator` - Learning from external sources
