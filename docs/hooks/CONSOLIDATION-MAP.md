# Hook Consolidation Map (deferred plan)

**Date**: 2026-06-14
**Version**: v3.1.1
**Status**: DEFERRED — speed/reliability work is DONE; this is the documented plan for a
future, dedicated consolidation effort.

## Why this is deferred (read before executing)

The v3.1.1 performance pass removed the only real latency offenders (recursive `claude`
subprocess ×3; synchronous vault scans). After that, **warm hook chains run at ~25ms**
because the hooks have stateful early-exit guards. Consequence:

> Merging hooks into dispatchers now yields **~0ms latency benefit in steady state**
> (only ~400ms saved on the first cold spawn). The remaining motivation is
> **maintainability** (fewer hook entries), not speed.

Do NOT undertake this for performance. Undertake it only if the maintainability win is
judged worth the regression risk, and only with the test suite
(`tests/test_hooks_optimization.py`) plus an output-equivalence check as a guard.

## Consolidation candidates (group by SHARED EVENT, never by name prefix)

| Event | Hooks | Safe approach | Risk |
|-------|-------|---------------|------|
| `SessionEnd` | vault-index-updater, vault-wing-compiler, vault-log-writer | One **sequential** dispatcher (`vault-session-end.sh`) that runs the 3 in order. Once-per-session, so latency is irrelevant and sequential = no races. | LOW |
| `PreToolUse Agent\|Task` | 10 hooks (see below) | Move pure side-effects to async-post; sequential or bucketed-parallel dispatcher for the rest. | MED-HIGH |
| `UserPromptSubmit` | plan-state-adaptive + plan-state-lifecycle (2 plan-state); universal-prompt-classifier + command-router + aristotle-analysis-display (3 prompt-analysis) | Merge each related pair/triple only after confirming no shared-state writes. | MED |

## Agent|Task chain — detailed analysis (the risky one)

Ten hooks, each 40–77ms cold, ~25ms warm. Classification:

| Hook | Role | Notes for consolidation |
|------|------|-------------------------|
| permission-guard | GATE | Must stay PreToolUse, blocking. No file writes. |
| lsa-pre-step | injects context | Keep pre; emits additionalContext. |
| smart-memory-search | injects context | Keep pre; writes its own memory/ledger files. |
| inject-session-context | injects context | Keep pre; emits additionalContext. |
| auto-plan-state | injects context | Keep pre; **writes `$PLAN_STATE`**. |
| fast-path-check | gate-ish | Keep pre. |
| skill-validator | validator | Keep pre. |
| promptify-security | security | Keep pre; writes consent/audit. |
| orchestrator-auto-learn | **pure side-effect** (0 deny, 0 context) | **Safe to move to PostToolUse:Task async.** Writes `$PLAN_STATE`. |
| checkpoint-smart-save | **pure side-effect** (0 deny, 0 context) | A **pre-work snapshot** — moving to post defeats its purpose. Keep pre OR redesign. |

### Confirmed hazards

1. **`$PLAN_STATE` race**: `orchestrator-auto-learn` and `auto-plan-state` both write
   `.claude/plan-state.json`. They are currently SERIAL (safe). Any **parallel** dispatcher
   MUST serialize these two (or use `flock`).
2. **Stateful early-exit**: hooks no-op on repeat invocation. Equivalence tests must reset
   or account for per-session state.
3. **deny-merge**: a parallel dispatcher must collect each hook's output and propagate any
   `permissionDecision: deny` (cannot short-circuit once spawned in parallel).
4. **pre/post semantics**: `checkpoint-smart-save` is a *before-work* snapshot; do not
   relocate it to PostToolUse without redesign.

## Recommended safe execution order (when picked up)

1. `SessionEnd` sequential dispatcher (lowest risk, do first).
2. Move `orchestrator-auto-learn` → `PostToolUse:Task` async (pure side-effect, learning
   belongs post-execution). Removes it from the blocking path and from the `$PLAN_STATE`
   parallel hazard.
3. Only then consider an `Agent|Task` dispatcher — bucketed parallel (independent hooks in
   parallel; the two `$PLAN_STATE` writers serial), with `flock` on plan-state and a
   deny-merge step.
4. Gate every step with `tests/test_hooks_optimization.py` + an output-equivalence diff
   (capture each hook's stdout/exit before and after; assert identical for representative
   payloads).

## Tooling already in place

- `scripts/hook-optimization/optimize-settings.py` — idempotent settings.json patcher
  (dry-run default). Extend it with a `--consolidate` mode to swap N hook entries for a
  dispatcher entry, with the same backup + validate discipline.
- `tests/test_hooks_optimization.py` — 38 tests (structural + per-hook timing). The
  per-hook timing assertions and the no-recursive-claude guard are the key regression nets.
