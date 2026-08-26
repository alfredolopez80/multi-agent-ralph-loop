# Baseline A — native Claude + SECURITY_BASELINE (issue #46, T82)

Date: 2026-08-26 · Worker: zc-1 · Machine: this laptop, one work session (both
conditions measured in the same window, per lead's instruction).

## Variant definition and activation

Variant A = Claude Code with ONLY the security plane active, where the plane is
`.claude/security/settings.security-only.json` — derived from
`SECURITY_BASELINE.json` (never hand-listed; equivalence gate:
`tests/test_security_only_profile.py`).

Activation used for these numbers: `CLAUDE_CONFIG_DIR=<empty dir>` +
`--settings <profile>` (the config-dir relocation leaves no user settings layer
underneath, so the additive `--settings` flag is the only layer). NOTE:
`--settings` alone over the real user config is ADDITIVE and cannot produce
variant A (lead, verified). The officially sanctioned mechanism (issue update)
is a sandbox HOME whose `.claude/settings.json` IS the profile; that form is
currently BLOCKED from inside a worktree-isolated session by the isolation
guard (it refuses HOME overrides) — runnable by the user from a terminal:

```
mkdir -p /tmp/t82-sandbox/.claude
cp .claude/security/settings.security-only.json /tmp/t82-sandbox/.claude/settings.json
HOME=/tmp/t82-sandbox claude --allowedTools "Bash" -p "Run: echo ok — reply only its output"
```

## The 9 metrics (measured, or declared not measurable — never estimated)

| # | Metric | Variant A | Full (live config) | Status |
|---|---|---|---|---|
| 1 | Security guard latency | **350,3 ms** per Bash call (4 hooks, median each, summed) | 426,7 ms (same 4 registrations; run-to-run variance) | MEASURED (`scripts/benchmark_hook_planes.py`, 5 runs/hook, JSON with min/max) |
| 2 | Ralph context tokens/bytes injected | **0 by construction, asserted**: allows emit decision JSON only (smoke test asserts no `additionalContext`) | ~2,0K tok wake-up block (F7a/CLAUDE.md figures, cited not re-measured) | MEASURED (A) / cited (full) |
| 3 | Startup time (wall of a minimal one-command prompt, median n=3) | **15,6 s** (8,8 / 15,6 / 24,0) | **57,3 s** (55,5 / 57,3 / 58,1) | MEASURED (proxy: includes model+network; same window, same machine) |
| 4 | Time to first useful action | — | — | **NO MEDIBLE** hoy (needs an instrumented first-action marker; metric 3 is the closest proxy) |
| 5 | Task completion time | — | — | **NO MEDIBLE** (needs a controlled task suite under both variants) |
| 6 | Unnecessary hook invocations | **0**: per Bash call 4 hooks (all security), per Edit 2, per Read **0** | 22 invocations per Bash call + turn, of which 4 security → **18 non-security** | MEASURED by construction (profile/settings × matcher arithmetic) |
| 7 | Subagent behavior | — | — | **NO MEDIBLE** (no subagent task run under variant A yet) |
| 8 | Compaction/resume shadowing | **None by construction**: the profile registers NO PreCompact/SessionStart/SessionEnd hooks (equivalence-gated) | 1+12+6 registrations respectively shadow native compaction/continuity | MEASURED by construction (profile JSON + gate) |
| 9 | User corrections | — | — | **NO MEDIBLE** (longitudinal; needs real usage over time) |

## C6 — Overhead attribution (per ordinary Bash tool call + turn)

Matcher-aware (only registrations whose matcher fires on Bash count for
Pre/PostToolUse; UserPromptSubmit/Stop fire always). Plane map declared in the
driver; 'security' = the five manifest controls.

| Plane | Variant A | Full live | Share (full) |
|---|---|---|---|
| security | 350,3 ms | 426,7 ms | 29 % |
| orchestration+state | **0** | **880,3 ms** | **61 %** |
| aristotle (user-mandated) | 0 | 96,9 ms | 6,7 % |
| security-adjacent | 0 | 28,9 ms | 2 % |
| memory | 0 | 20,0 ms | 1,4 % |

Headline: the dominant NON-security overhead is orchestration+state (61 %),
not memory (1,4 %). Variant A's total hot-path overhead is the security plane
itself and nothing else.

## Findings beyond the numbers

1. **Tool-discovery flakiness in the standalone sandbox**: 2 of 6 live runs
   under the isolated config answered "no command-execution tool available
   (only ToolSearch)" — the model sometimes cannot surface Bash without the
   user settings layer. The profile alone is not yet a stable standalone
   runtime; boot-critical keys (tool availability/deferment) live outside the
   manifest. First-class finding for the issue's casilla 1.
2. **Live negative-path proof (full plane)**: a probe whose command line
   carried a destructive git literal was BLOCKED by this session's own
   git-safety-guard with the deny message relayed as the tool result — the
   plane fires in real sessions, not just in fixtures.
3. **Run-to-run variance** of individual hook medians is ±20 % (min/max in
   `results/t82-hook-planes.json`); comparisons use same-window medians.

## Reproduction

- `python3 scripts/benchmark_hook_planes.py` (attribution, both profiles)
- `python3 -m pytest tests/test_variant_a_smoke.py -q` (mechanical smoke, 5 tests)
- Live probes: see "Activation" above and `results/t82-probe-runs.txt`
