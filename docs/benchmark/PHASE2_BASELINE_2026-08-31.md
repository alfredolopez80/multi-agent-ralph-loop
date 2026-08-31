# Phase 2 Baseline — certification reference before any deletion (PR 4, #69)

Generated: 2026-08-31T17:50Z · Worker: zc-3 · Assignment: PR4-BASE
Role of this artifact: the BEFORE reference that Phase 5 certification measures
the deletion against. Same instruments, same window rule (PLAN_CERT_METRICS.md,
rows 1-7). No probe was invented or modified; every number below has a raw log.

## Provenance

| field | value |
|---|---|
| `main` SHA (security-final snapshot) | `bfcfef251ee53972ce900a9cfa94ea37f3d16260` |
| worktree branch / HEAD at measurement | `worktree-zc-3` @ `bfcfef2` (rebased, clean) |
| ACTIVE settings | `~/.claude/settings.json` |
| ACTIVE settings sha256 | `c6195c54ec7b2477bdf7f600e53821475c0f784ba5a48c39605a4ed72e7177ad` |
| settings drift note | differs from the P0-INV morning snapshot (`46efd9e6…`) — user-side activations during the day; this baseline records the CURRENT active config |
| machine | macOS 26.6.2 (Build 25G83), arm64 |
| wrapper | `zc` (alias of `zai-claude`), Claude Code 2.1.251 binary underneath; nested probes run plain `claude -p`/hooks directly |
| tiktoken | cl100k_base via `scripts/benchmark/.venv` (setup per hotpath_probe docstring; gitignored) |
| date | 2026-08-31T15:00–18:00Z window, single session |

## Row 1 — Hook latency per ordinary turn (`scripts/benchmark/hotpath_probe.py`)

Command: `python3 scripts/benchmark/hotpath_probe.py --out results/pr4-base-hotpath`
(N=12 per hook, isolated probe HOME; setup: `--setup`).
Raw: `results/pr4-base-hotpath/hotpath-probe.json` + `.txt` (20 hooks, all status OK).

Per-ordinary-turn aggregates (sum of hook medians):

| plane | median ms (sum) | hooks |
|---|---:|---:|
| security (PreToolUse) | 261.7 | 4 |
| security-adjacent (PostToolUse audit) | 8.1 | 1 |
| orchestration (PostToolUse) | 194.7 | 7 |
| memory (PostToolUse) | 30.2 | 3 |
| aristotle (PreToolUse/PreCompact) | 33.0 | 2 |
| lifecycle (PreCompact/SessionStart:compact/SessionEnd) | 420.7 | 3 |
| **TOTAL (all 20 mechanisms)** | **948.3** | 20 |

Per-Bash-call comparison against the pre-registered row-1 baseline (546 ms =
PreToolUse 320 + PostToolUse 226): **PreToolUse 293.1 + PostToolUse 220.9 =
514.0 ms** — within the documented ±10% run-to-run variance (T83); lifecycle
hooks (420.7 ms, dominated by pre-compact-handoff 191.8 + session-end-handoff
190.0) fire on compact/end, not per turn, and are listed separately.

Variance: per-hook N=12 min/median/p90/max are in the raw JSON (e.g.
permission-guard 174.3/192.2/238.5; status-auto-check 67.2/72.0/81.4).

## Row 2 — SessionStart wake-up block tokens (tiktoken cl100k_base)

Command (literal from PLAN_CERT_METRICS "How to run", stdin-closed variant):
`bash .claude/hooks/wake-up-layer-stack.sh 2>/dev/null </dev/null | head -c 100000`
captured to `results/pr4-wakeup-block.txt` (6542 bytes), then
`scripts/benchmark/.venv/bin/python -c "… len(enc.encode(...))"`.

| measure | tokens |
|---|---:|
| whole hook stdout (literal instrument) | **1792** |
| `additionalContext` value only (what enters the prompt) | **1615** |

NOTE: the hook blocks forever without stdin closure (`INPUT=$(cat)`); the
literal doc command needs `</dev/null` (or a timeout) to terminate —
invocation fix, not an instrument change. Baseline for row 2 was ~1950-2000
(2026-08-23); today's 1615 is within the same regime, already below it.

## Row 6 — Trivial task zero-subagent (`scripts/benchmark/trivial_task_probe.py`)

Command: `python3 scripts/benchmark/trivial_task_probe.py`
Raw: `results/trivial-task-probe.json` + `.txt`.

**cells=27, allow=24, deny=0, ask=0, other=3** (k8s-context-guard emits cluster
context, not a decision) — exact replica of the T96 baseline (2026-08-28).
`any_deny=False`, `any_ask=False`.

## Row 4-adjacent — Active registration count (`count_active_hooks.py`)

Commands: `python3 scripts/benchmark/count_active_hooks.py --ref main --json`
(repo example profile) and `--path ~/.claude/settings.json --json` (ACTIVE).
Raw: `results/pr4-count-example.json`, `results/pr4-count-active.json`.

| config | events | commands | matchers |
|---|---:|---:|---:|
| example (repo, ref=main) | 6 | **21** | 16 |
| ACTIVE user settings | 14 | **74** | 25 |

Arithmetic note: the example profile is 22→**21** commands after PR3-C7
(audit-secrets.js deregistered) — verified by this run. The ACTIVE 74-command
count uses the instrument's tally (commands per event; deduplicated identical
commands); it is consistent with the P0-INV census of 76 hook registrations +
statusLine under a different counting rule, and is the number the certification
will compare against.

## Row 7 — Maintenance executions in ordinary prompts (trace sampling)

Method (pre-registered): manual trace audit over N≥20 ordinary-prompt
transcripts under `~/.claude/projects/**/*.jsonl`.
Instrument: `results/pr4-maintenance-sample.py` → `results/pr4-maintenance-sample.txt`
+ `results/pr4-maintenance-evidence.txt` (evidence lines for line-level review).

Sample: 25 most-recent transcripts (of 1689 present), all 25 ordinary (≥1 user
message). String-mention totals:

| hook | mentions |
|---|---:|
| vault-graduation | 65 |
| vault-promotion | 61 |
| auto-sync-global | 65 |
| vault-weekly-compile | 27 |
| vault-index-updater | 30 |

10 of 25 ordinary transcripts carry ≥1 mention. CAVEAT (same signal class as
the C9 baseline): a mention is a string occurrence — SessionStart-injected
context ("vault-graduation: maintenance running in background") counts, so
mentions scale with compactions/restarts, not only mid-prompt executions. The
certification threshold (0 mid-prompt executions) requires the line-level
evidence review, which the evidence file enables; this baseline records the
raw counts, not a verdict.

## Cache counters

**Not measured** — no cache-invalidation counter is observable without adding
runtime instrumentation, which the assignment forbids. Recorded as
"not measured" per the pre-registration rule (a number invented here would be
a placebo).

## Reproduce

```bash
python3 scripts/benchmark/hotpath_probe.py --setup
python3 scripts/benchmark/hotpath_probe.py --out results/pr4-base-hotpath
python3 scripts/benchmark/trivial_task_probe.py
python3 scripts/benchmark/count_active_hooks.py --ref main --json
python3 scripts/benchmark/count_active_hooks.py --path ~/.claude/settings.json --json
bash .claude/hooks/wake-up-layer-stack.sh 2>/dev/null </dev/null | head -c 100000 > /tmp/wu.txt
scripts/benchmark/.venv/bin/python -c "import tiktoken;print(len(tiktoken.get_encoding('cl100k_base').encode(open('/tmp/wu.txt').read())))"
python3 results/pr4-maintenance-sample.py
```
