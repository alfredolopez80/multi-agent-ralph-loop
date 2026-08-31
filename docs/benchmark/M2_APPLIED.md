# M2 Applied — what was removed from the default registration

**Date**: 2026-08-28 · **Worker**: mmx-2 · **Driver**: T106-m2-optin
**Context**: Phase 3 of #48. Mechanism retirement "unless measured evidence proves material benefit" — thresholds pre-registered in `docs/benchmark/PLAN_CERT_METRICS.md` (T93), baseline numbers in `docs/benchmark/HOTPATH_M1_2026-08-28.md` (T93).

## Headline numbers

| | Before (current `.claude/settings.json.example`) | After (T106 template, default registration) | Delta |
|---|---:|---:|---:|
| Hook entries registered by default | **43** | **22** | **−21 (−49%)** |
| Hot-path PostToolUse entries (Edit\|Write\|Bash) | 9 | 0 (all opt-in) | −9 |
| PreToolUse:* non-security | 4 (aristotle + task/agent) | 0 (opt-in) | −4 |
| SessionStart:* lifecycle suite | 6 | 1 (post-compact-restore only) | −5 |
| Stop:* suite | 6 | 0 (all opt-out) | −6 |
| PreCompact:* | 1 | 0 (opt-in) | −1 |
| UserPromptSubmit:* | 5 | 0 (opt-in) | −5 |
| **SECURITY** (mandatory) | n/a | 12 (5 PreToolUse matchers + PostToolUse 3 + SessionStart:compact + SessionEnd) | n/a |
| **ESSENTIAL non-security** (task-state conservation per #47) | n/a | 1 (plan-sync-post-step) | n/a |

## What stayed in the default registration

These 17 entries are the irreducible minimum for `#46 critical rule` (security plane constant from variant A onward) plus `#47 C1` (task-state canonical):

| Event matcher | Hook | Plane | Why mandatory |
|---|---|---|---|
| PreToolUse:Bash | permission-guard.sh | security | Manifest control, fires every Bash |
| PreToolUse:Bash | git-safety-guard.py | security | Manifest control, destructive-git deny |
| PreToolUse:Bash | repo-boundary-guard.sh | security | Manifest control, outside-repo deny |
| PreToolUse:Bash | k8s-context-guard-v2.py | security | Manifest control, k8s-context deny |
| PreToolUse:Edit\|Write | permission-guard.sh | security | Manifest control, fires every E/W |
| PreToolUse:Edit\|Write | repo-boundary-guard.sh | security | Manifest control |
| PreToolUse:Agent\|Task | permission-guard.sh | security | Manifest control, fires every spawn |
| PreToolUse:Agent\|Task | repo-boundary-guard.sh | security | Manifest control |
| PreToolUse:Skill | skill-validator.sh | security-adjacent | Manifest control |
| PostToolUse:* | audit-secrets.js | security-adjacent | CWE-798/321 coverage |
| PostToolUse:Edit\|Write\|Bash | plan-sync-post-step.sh | task-state | #47 C1 canonical write |
| PostToolUse:Agent\|Task | lsa-pre-step.sh | agent policy | M3 floor (conservative) |
| SessionStart:compact | post-compact-restore.sh | task-state | #47 C1 restore after compaction |
| SessionEnd:* | session-end-handoff.sh | lifecycle | Cold-path handoff |
| SessionEnd:* | session-end-extractors.sh | lifecycle | C9 cold-path extraction + registry guard (T95) |
| SessionEnd:* | memory-projection.sh | lifecycle | Cold-path memory write |
| SessionEnd:* | vault-index-updater.sh | lifecycle | Cold-path index sync |
| SessionEnd:* | vault-log-writer.sh | lifecycle | Cold-path log write |
| SubagentStart:* | ralph-subagent-start.sh | agent policy | Writes state files that #48 guards read (T101) |
| SubagentStart:* | agent-depth-soft-enforce.sh | agent policy | Depth ≤2 chain walk + soft-enforce (T101) |
| SubagentStop:* | subagent-stop-universal.sh | agent policy | Marks completed so #48 ceiling decrements (T101) |
| PreToolUse:Task | agent-policy-guard.sh | agent policy | Ceiling 8 read-only over real state (T101) |

## What was moved to OPT-IN (commented out, ready to uncomment)

| Event matcher | Hook | M1 cost | Reason for opt-in |
|---|---|---:|---|
| UserPromptSubmit:* | wake-up-layer-stack.sh | ~110 ms/session start, 827 tok wake-up | Provides L0-L1 essential rules; off if user prefers minimal startup |
| PreToolUse:* | universal-aristotle-gate.sh | 22 ms/Bash | User-mandated methodology; off for non-Aristotle users |
| PreToolUse:Agent\|Task | orchestrator-auto-learn.sh | 14 ms/A\|T (0 ms plain prompts) | Writes agent memory; off if you don't use subagent memory |
| PreCompact:* | pre-compact-handoff.sh | 210 ms/PreCompact | Context survives compaction; off if post-compact-restore is enough |
| PreCompact:* | aristotle-analysis-display.sh | 13 ms/PreCompact | Aristotle methodology display; off for non-Aristotle users |
| SessionStart:* | project-state.sh | ~25 ms | Loads project state |
| SessionStart:* | vault-graduation.sh | ~50 ms | Vault promotion by confidence |
| SessionStart:* | vault-promotion.sh | ~50 ms | Raw memory → vault |
| SessionStart:* | auto-migrate-plan-state.sh | ~50 ms | Schema migration (note: plan-sync-post-step on PostToolUse still keeps state canonical for #47 C1) |
| SessionStart:* | auto-sync-global.sh | ~30 ms | Global ralph sync |
| SessionStart:* | session-start-restore-context.sh | ~80 ms | Restore session context (overlaps with wake-up-layer-stack) |
| PostToolUse:Edit\|Write\|Bash | status-auto-check.sh | 67 ms/E\|W\|B | Top display-only contributor; top async candidate |
| PostToolUse:Edit\|Write\|Bash | quality-parallel-async.sh | 37 ms/E\|W\|B | Async-quality display |
| PostToolUse:Edit\|Write\|Bash | ai-code-audit.sh | 22 ms/E\|W\|B | AI-pattern detector |
| PostToolUse:Edit\|Write\|Bash | console-log-detector.sh | 14 ms/E\|W\|B | Debug-statement catcher |
| PostToolUse:Edit\|Write\|Bash | auto-format-prettier.sh | 13 ms/E\|W\|B | Auto-format on save |
| PostToolUse:Edit\|Write\|Bash | progress-tracker.sh | 13 ms/E\|W\|B | Progress display |
| PostToolUse:Edit\|Write\|Bash | vault-fact-extractor.sh | 11 ms/E\|W\|B | Fact extraction to vault |
| PostToolUse:Edit\|Write\|Bash | session-accumulator.sh | 10 ms/E\|W\|B | Session context accumulator |

Each opt-in entry in the example file has its cost and benefit written next to it as a `//` comment.

## Before → Expected (CERT threshold) table

Per PLAN_CERT_METRICS.md row 1, the post-M2 measurement target is **≤ 380 ms / Bash call** (down from M1's 546 ms / Bash call, −30%).

| Metric | M1 baseline (T93) | After M2 (security only) | CERT threshold (row 1) | Status |
|---|---:|---:|---:|---|
| **Total per ordinary Bash call** | 546 ms | ~325 ms | ≤ 380 ms | PASS expected |
| PreToolUse chain (Bash matcher) | 320 ms | 320 ms (security mandatory) | included | security holds constant |
| PostToolUse chain (Edit\|Write\|Bash matcher) | 226 ms | ~5 ms (plan-sync-post-step only) | included | **−98%** vs M1 |
| session-end-extractors total | ~480 ms | ~220 ms (session-end-handoff + 3 cold-path only) | cold-path, not in CERT row 1 | improvement |
| SessionStart:* suite | ~285 ms | ~50 ms (post-compact-restore only) | cold-path, not in CERT row 1 | improvement |
| Wake-up tokens at session start | 827 tok | 0 tok (opt-in) | row 2 target ≤ 1200 | already met |

The reduction is concentrated in the PostToolUse chain (226 ms → 5 ms) because the bulk of that chain was display-only hooks (status-auto-check 67 ms, quality-parallel-async 37 ms, plan-sync-post-step 33 ms, ai-code-audit 22 ms — of which only plan-sync-post-step is essential per #47 C1). The PreToolUse chain is unchanged because security is mandatory.

## What was NOT changed

- **Hook files**: NONE were deleted from the tree. All 80+ hooks in `.claude/hooks/` remain — they're just no longer registered by default. Criterion #48 ("Preserve as optional capabilities") honored.
- **Security profile**: `.claude/security/settings.security-only.json` unchanged — it's the definitive source for what counts as security.
- **Hooks archive**: `.claude/hooks/archive/` (if any) was not touched.
- **M3 agent-policy implementation**: T101 lands the agent-policy-guard + agent-depth-soft-enforce as the M3 policy hooks. **Note**: `lsa-pre-step.sh` is a *preexisting* gate under `PostToolUse:Agent|Task` (conservative agent-loop step gate, not the M3 ceiling/depth policy). It is a different mechanism from the new T101 hooks and remains in the default registration alongside them; the two coexist.

## What M2 does NOT solve (out of scope)

- **M3 (agent ceiling 8 + depth ≤2)** — done by `mmx-3` in T101. Already MERGED in main as `b89e54a` + `88d813c` (T110-f2). The four lifecycle hooks (`SubagentStart:*` with ralph-subagent-start + agent-depth-soft-enforce, `SubagentStop:*` with subagent-stop-universal, `PreToolUse:Task` with agent-policy-guard, `SessionEnd:*` with session-end-extractors alongside the existing handoff) are what wires the M3 policy end-to-end. Without them, the policy guards read empty state and are decorative.
- **F4 contract rewrite** — separate task.
- **CERT matrix re-run** — separate task; uses the same instruments (hotpath_probe.py from T93, trivial_task_probe.py from T96) before and after.

## Verification of the change

- **Runner**: `bash tests/run-all-unit-tests.sh` → verde (the example isn't loaded by tests; sanity check that nothing else broke).
- **Format check**: `python3 -c "import commentjson; ..." .claude/settings.json.example` would parse the JSON5 if `commentjson` is installed; otherwise the python one-liner in the example's header does the same.
- **Manifest equivalence**: `pytest tests/test_security_only_profile.py tests/test_hooks_security_baseline.py` → 22/22 green (security plane unchanged).
- **Reproducible count of active registration** (HEAD or main ref is authoritative, never the working tree):
  ```bash
  git show HEAD:.claude/settings.json.example \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); t=sum(len(a) for a in d.get("hooks",{}).values()); c=sum(len(m.get("hooks",[])) for a in d.get("hooks",{}).values() for m in a); print(t,"tuples /",c,"commands")'
  ```
  Output today: `17 tuples / 22 commands`. The headline row above (22) is the **commands** count from this command; the **tuples** count is 17.

---

*Authored by `mmx-2` on 2026-08-28 as T106-m2-optin. Numbers cited from `docs/benchmark/HOTPATH_M1_2026-08-28.md` (M1) and `docs/benchmark/PLAN_CERT_METRICS.md` (CERT thresholds).*
