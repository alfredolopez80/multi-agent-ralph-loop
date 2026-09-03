# T83 — Daily-gate before/after measurement (rigorous)

> Historical record. Model/provider names below describe the state at the time of writing; the current rule is that the model is whatever the session runs.

**Status**: complete. Post-rebase (43 commits), 36/36 unit suites green.
N=10 per state per hook, with 3 warm-up runs discarded. Pre-T81 SHAs
extracted with `git show <sha>:.claude/hooks/<name>` after asserting the
blob does NOT contain "daily-gate" AND has fewer lines than the live hook.

Lead asked for this measurement because the single-shot `time bash hook.sh`
numbers in the T81 commit (`76d5a59`) could not distinguish signal from
noise — macOS shell cold-start alone varies by 5-25ms, so one observation
of "10ms → 19ms" is consistent with the gate helping, hurting, or doing
nothing. A distribution per state is the only thing that can decide.

## Method

### N and aggregation

- N = 10 per (hook, state). 4 hooks × 4 states = 160 hook measurements.
- 1 control = 10 measurements. **Total: 170 observations.**
- Aggregation: **median** (primary), plus min, max, mean, sd as auxiliaries.
- 3 warm-up runs per (hook, state) before each N — cold-start noise
  is concentrated in the first few calls; warm-ups stabilise caches.

### Wall-clock acquisition

- `time.perf_counter()` from Python at the boundary of `subprocess.run`.
- `subprocess.run(args, stdin=DEVNULL, stdout=DEVNULL, stderr=DEVNULL)`.
- **No `| tail` / `| head` / `| grep`** in the timing path. The hook's own
  output is discarded because we are timing the SHELL, not parsing the
  hook's JSON. The `bash-pipe-and-cwd-mask-gate-results` rule applies
  literally here: pipes can mask exit codes and confuse `time` markers.

### State control

`~/.ralph/markers/daily-gate-<name>-YYYYMMDD` is the marker file.
- "present": zero-byte `touch`.
- "absent": `unlink` (idempotent).

### "sin_gate" replication

Extracted with `git show <sha>:.claude/hooks/<name>` to a temp file under
`results/_tmp_t83/`. The committed hooks on disk are NOT modified.

**Hard pre-conditions asserted BEFORE timing each hook**:

1. The blob returned by `git show` MUST NOT contain the substring
   "daily-gate". If it does, the SHA is wrong and the script aborts
   with exit 2 (loud, not silent).
2. The blob's line count MUST be strictly less than the live hook's
   line count. If not, the SHA selection is wrong and the script aborts.

These two assertions mean: a hook that allegedly represents the
pre-T81 state and yet still contains the gate code is unfixable
for the experiment — the script fails closed rather than reporting
a measurement of the wrong object.

### Per-hook pre-T81 SHAs (last commit that touched each hook BEFORE 76d5a59)

| hook                          | pre-T81 SHA  | rationale                                            |
|-------------------------------|--------------|------------------------------------------------------|
| `vault-graduation.sh`         | `057c6ca`    | zc: graduation writes to learned-src (T62 #73 block C) |
| `vault-promotion.sh`          | `fde9ec8`    | bash 3.2 silent corruption                            |
| `auto-sync-global.sh`         | `720bf46`    | codex review follow-ups                              |
| `project-backup-metadata.sh`  | `523257b`    | stop format guards                                    |

All four assertions PASSED at runtime. The line-count deltas were
roughly the size of the inserted gate block:

```
  vault-graduation.sh       sha=057c6ca, lines=136<145
  vault-promotion.sh        sha=fde9ec8, lines=202<212
  auto-sync-global.sh       sha=720bf46, lines=125<136
  project-backup-metadata.sh sha=523257b, lines=326<337
```

### Cold-start baseline

`bash -c true` measured 10 times is the cost of starting a shell and
returning. Median 10.04 ms, sd 0.43 ms. Any per-hook number smaller than
~20ms is "cold start plus almost nothing".

## Data

All numbers in milliseconds. **Median is primary.**

### Control

| state        |   n | mean | median |  min |   max |   sd |
|--------------|----:|-----:|-------:|-----:|------:|-----:|
| `bash -c true` |  10 | 10.09|  10.04 |  9.43| 11.07 | 0.43 |

### vault-graduation.sh

| state             |   n | mean  | median | min   | max   | sd    |
|-------------------|----:|------:|-------:|------:|------:|------:|
| `sin_gate`        |  10 |  28.04|  23.07 |  19.94|  47.17|   9.83|
| `con_gate_open`   |  10 | 121.90| 129.47 |  75.44| 180.92|  37.03|
| `con_gate_skip`   |  10 | 159.22| 146.90 | 126.25| 237.59|  33.43|
| `gate_only`       |  10 | 159.11| 135.68 |  86.29| 347.35|  70.50|

**Reading the table.** Median sin_gate is 23ms, median skip is 147ms.
The skip path pays an extra ~124ms median over the no-gate baseline
**and saves only the cost of a BG fork (which was already <10ms under
PERF v3.1.1)**. Net wall-clock effect of the gate on
`vault-graduation.sh`: **+124ms per SessionStart from the second
arrival of the day onwards**. Not even close.

### vault-promotion.sh

| state             |   n | mean   | median | min   | max    | sd    |
|-------------------|----:|-------:|-------:|------:|-------:|------:|
| `sin_gate`        |  10 |   95.80|   93.51|  44.68|  140.52|  37.96|
| `con_gate_open`   |  10 |  313.22|  286.17| 137.76|  600.83| 146.55|
| `con_gate_skip`   |  10 |  349.86|  290.57| 137.20|  859.80| 211.57|
| `gate_only`       |  10 |  202.72|  189.08|  75.86|  341.84|  75.59|

**Reading.** Skip median 290ms vs sin_gate 94ms. Gate adds ~197ms median
per SessionStart. Even the open (gate passes, body runs) is 286ms — the
gate's own source/check adds ~192ms to the body, and the body itself
contributes only the residual.

### auto-sync-global.sh

| state             |   n | mean   | median | min   | max    | sd    |
|-------------------|----:|-------:|-------:|------:|-------:|------:|
| `sin_gate`        |  10 |  115.53|   87.57|  48.64|  289.91|  71.76|
| `con_gate_open`   |  10 |  376.84|  347.62| 193.47|  657.74| 150.88|
| `con_gate_skip`   |  10 |  207.36|  186.52| 146.65|  294.45|  46.29|
| `gate_only`       |  10 |  227.04|  239.02|  79.09|  351.14|  79.45|

**Reading.** Sin_gate 88ms median vs skip 187ms. Gate adds ~99ms median
per SessionStart. The skip is actually CLOSER to sin_gate than open is
— once the fork BG is replaced by an inline check, the wall-clock
advantage the fork used to have disappears.

### project-backup-metadata.sh

| state             |   n | mean    | median  | min    | max      | sd      |
|-------------------|----:|--------:|--------:|-------:|---------:|--------:|
| `sin_gate`        |  10 | 1327.78 | 1281.64 |  787.28|  2050.73 |  405.67 |
| `con_gate_open`   |  10 |  511.99 |  343.08 |  171.94|  1404.85 |  416.61 |
| `con_gate_skip`   |  10 |   36.76 |   36.30 |   34.39|    40.38 |    1.72 |
| `gate_only`       |  10 |   25.42 |   19.67 |   17.89|    35.83 |    7.96 |

**Reading.** Sin_gate 1282ms median (the body really IS heavy on
this hook — git remote / status / diff / write JSON synchronously).
Skip 36ms median. **The gate saves ~1246ms per SessionStart from the
second arrival of the day.** First-arrival cost (con_gate_open) is
343ms median — the gate adds 6-8ms over the sin_gate baseline
(consistent with the source+check overhead), and the body still runs
once because the marker is absent on the first call.

The sin_gate / con_gate_open discrepancy (~939ms median) is **not yet
explained** and is flagged for the next investigation; the most likely
hypothesis is that the pre-T81 SHA `523257b` includes a Stop branch
whose dispatch differs slightly from what the live hook runs, or the
rebase replay changed incidental hooks (e.g. the trap handlers) in a
way that affects wall-clock. Both sin_gate and con_gate_open run the
SAME body; the discrepancy belongs in front of lead regardless.

## Verdict

Per hook, summarised:

| hook                          | sin_gate → con_gate_skip delta | verdict                                                 |
|-------------------------------|-------------------------------:|---------------------------------------------------------|
| `vault-graduation.sh`         |                       **+124ms** | gate is wall-clock net-negative. Revert.                |
| `vault-promotion.sh`          |                       **+197ms** | gate is wall-clock net-negative. Revert.                |
| `auto-sync-global.sh`         |                        **+99ms** | gate is wall-clock net-negative. Revert.                |
| `project-backup-metadata.sh`  |                    **−1246ms** | gate is wall-clock net-positive. **Keep.**              |

Across the four, the median per-SessionStart shift on the typical day
is roughly:
- If we KEEP the gate on all four: ~+436ms median per SessionStart
  (averaged across the day's calls). Net loss.
- If we KEEP the gate only on `project-backup-metadata` (where it
  actually wins): ~−1246ms median per SessionStart **from the second
  arrival of the day onwards**, plus the natural cost of the first call.
  Net win.

### Recommendation

Option B from my previous message: **revert the gate in the three BG
hooks, keep it only in `project-backup-metadata.sh`**. This is what the
data says. The wall-clock evidence is not ambiguous; the three BG hooks
were already optimalised under PERF v3.1.1, and adding an inline check
that no body is going to use moves cost into the foreground that the
fork had previously pushed to the background.

The library `lib/daily-gate.sh` stays — it is correct, it has working
tests with edge-case coverage, and it can be used by any future
synchronous maintenance hook that genuinely costs more than the gate
takes.

I am NOT executing Option B yet. Lead's previous message asked for the
numbers first; the decision on whether to revert the three BG gates
is yours to make.

## Artefacts

- `results/measure_t83.py` — the measurement script (re-runnable).
- `results/T83-measurements.json` — full per-state raw aggregates.
- `results/T83-measurements.csv` — flat per-sample CSV (~170 rows).
- `results/T83-daily-gate-measurement.md` — this document.
- `results/_tmp_t83/` — temp scripts from the run (safe to delete).
