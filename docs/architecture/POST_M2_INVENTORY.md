# T107 — Inventario post-M2 del repo multi-agent-ralph-loop

**Task**: T107-diagrama-inventario (frente de retiro, T106/M2 en curso).
**Date**: 2026-08-28
**Worker**: mmx-3
**Status**: M2_APPLIED.md does NOT exist yet — table follows the T106 target taxonomy and is marked "pending M2 landing" where the canonical-source attribution depends on the M2 landing commit. The source references below point to files that exist today.

This document is the input to the diagram in `docs/assets/` and the new section in `README.md`. It is also the basis on which a reviewer can audit "what survives vs what gets retired" without having to grep 84 hooks.

---

## A. SECURITY (always on)

These six hooks form the non-negotiable security baseline. The repository
deliberately keeps them registered on `PreToolUse` even when the rest of the
hooks are pulled off the hot path.

| id | hook | event/matcher | source | properties (one line) |
|---|---|---|---|---|
| permission-pipeline | `.claude/hooks/permission-guard.sh` | PreToolUse:Bash\|Edit\|Write\|Agent\|Task | `.claude/security/SECURITY_BASELINE.json:14-50` (control `permission-pipeline`) | Fail-closed on every path; delegates to git-safety and repo-boundary; unparseable stdin denies |
| git-safety | `.claude/hooks/git-safety-guard.py` | PreToolUse:Bash | `.claude/security/SECURITY_BASELINE.json:51-72` (control `git-safety`) | Blocks destructive git (reset --hard, push --force), destructive fs (rm -rf /), command chaining (;, &&, eval, xargs rm); JSON on every terminal path |
| repo-boundary | `.claude/hooks/repo-boundary-guard.sh` | PreToolUse:Bash\|Edit\|Write\|Agent\|Task | `.claude/security/SECURITY_BASELINE.json:73-110` (control `repo-boundary`) | GitHub-repo boundary; registered directly (does not depend on a wrapper); v2.99.0 portable (no GNU-only `realpath -m`) |
| k8s-context | `.claude/hooks/k8s-context-guard-v2.py` | PreToolUse:Bash | `.claude/security/SECURITY_BASELINE.json:111-131` (control `k8s-context`) | Every kubectl/helm/minikube must declare `--context` explicitly; factual minikube verification, not name matching |
| worktree-utils (lib) | `.claude/hooks/lib/worktree-utils.sh` | (sourced) | `.claude/security/SECURITY_BASELINE.json:132-148` (control `worktree-utils`) | `get_project_root`/`get_main_repo` for boundary + worktree guards; inline fallbacks if unreachable |
| skill-security | `.claude/hooks/skill-validator.sh` | PreToolUse:Skill | `.claude/security/SECURITY_BASELINE.json:149-170` (control `skill-security`) | Six deterministic patterns (invisible unicode, base64+exec, exfil IOCs, pipe-to-shell, secret literals, quote-aware override); audited allowlist with written-reason requirement |

**Gaps declared** (no-hook, tracked but not implemented): `secrets-ordinary-work`, `red-toxic`, `mcp-egress`, `package-manager`, `symlink-escape` — from `.claude/security/SECURITY_BASELINE.json:174-202` (key `gaps`). These are tracked separately and are NOT inventoried below as "retired"; they are explicitly *open*.

---

## B. CANÓNICO #47 (survives active)

The `#47` clean-state-and-bounded-recall architecture. These are the
mechanisms that survive after M2 because they are the actual answer to
"what useful verified thing did we learn, where did we verify it, and
how do we get it without paying the cost on every prompt".

| component | role | source | survives because |
|---|---|---|---|
| plan-state writer | atomic write + freshness timestamps | `.claude/hooks/lib/plan-state-writer.sh:53-91` (`plan_state_update`) | single source for state writes; dual-write `.last_updated` + `.updated_at` so any reader sees consistent freshness (T97 finding) |
| plan-state readers | hot-path reads of plan-state | `.claude/hooks/anti-rationalization-gate.sh`, `.claude/hooks/plan-state-lifecycle.sh` | the canonical state is read by every quality gate; the writer above keeps it atomic |
| recall on-demand | bounded two-stage retrieval, .47 hot path #2 | `scripts/memory/recall_v2.py:513-592` (`recall`) and `scripts/memory/tree_store.py` | the answer to "what useful verified thing applies now" without paying a corpus-wide search per prompt |
| task-state writer | atomic task-state CRUD | `.claude/hooks/lib/plan-state-writer.sh` (same library, different files) | task-state shares the writer invariant |
| `RISK_EMITTED_FIELDS` (T103 #1) | single source of truth for per-risk emitted field set | `scripts/memory/recall_v2.py:476-498` (table + `_validate_risk_table`) | drift between `render_context` and `_emitted_text` is no longer possible |
| `agent-policy-guard` (T101) | ceiling enforcement, read-only on real state | `.claude/hooks/agent-policy-guard.sh` | enforces `RALPH_AGENT_CEILING` without a parallel counter (subagent state is the source of truth) |
| `agent-depth-soft-enforce` (T101) | depth chain walk exact + early-exit directive | `.claude/hooks/agent-depth-soft-enforce.sh` | enforces `RALPH_AGENT_DEPTH` with chain truth (no heuristic); soft-enforce via SubagentStart |
| `subagent-start` writer | creates the state my guards read | `.claude/hooks/ralph-subagent-start.sh:380-396` | without it, the two guards above read empty state and are decorative |
| `subagent-stop` writer | marks `status: completed` | `.claude/hooks/subagent-stop-universal.sh:97-99` | without it, completed subagents stay counted and the ceiling is wrong |
| `audit-secrets.js` | PostToolUse secret pattern detection (LOG ONLY) | `.claude/hooks/audit-secrets.js` | one of the post-write controls the SECURITY_BASELINE defines as "detection-after-the-fact"; not on hot path (PostToolUse is not hot); survives but does not block |
| `session-start-ledger` + restore-context | session resume machinery | `.claude/hooks/session-start-ledger.sh`, `.claude/hooks/session-start-restore-context.sh` | the answer to "where are we now" without paying wake-up cost on every prompt |

---

## C. OPT-IN (retired from default; T106/M2 in course)

These components exist in the repo today but are being removed from the
default SessionStart/PreToolUse wake-up chain by T106/M2. They survive as
OPT-IN capabilities (`.claude/rules/learned/` mentions, or explicit
`/skillname` invocation) but they are NO LONGER on the hot path. After M2
lands, a clean install no longer registers them in `~/.claude/settings.json`
by default.

| component | category | source | retired because |
|---|---|---|---|
| `aristotle-analysis-display.sh` | Aristotle gate (display) | `.claude/hooks/aristotle-analysis-display.sh:3-9` | per-prompt complexity/depth analysis; the user can invoke `/aristotle` for genuine high-impact work |
| `universal-aristotle-gate.sh` | Aristotle gate (enforcement) | `.claude/hooks/universal-aristotle-gate.sh` | universal per-prompt enforcement of Aristotle 5 phases; keeps the model from acting until the analysis is done — overhead dominates benefits |
| `universal-prompt-classifier.sh` | classifier | `.claude/hooks/universal-prompt-classifier.sh` | upstream of every prompt; classifies complexity — overhead per prompt |
| `continuous-learning.sh` | learning gate | `.claude/hooks/continuous-learning.sh` | auto-curation on session boundaries; moved to cold path |
| `orchestrator-auto-learn.sh` | learning gate | `.claude/hooks/orchestrator-auto-learn.sh` | auto-capture patterns from orchestrator runs; moved to cold path |
| `plan-state-lifecycle.sh` | lifecycle | `.claude/hooks/plan-state-lifecycle.sh` | archive stale plans; moved to cold path |
| `plan-analysis-cleanup.sh` | lifecycle | `.claude/hooks/plan-analysis-cleanup.sh` | cleanup of analysis artefacts; moved to cold path |
| `status-auto-check.sh` | status check | `.claude/hooks/status-auto-check.sh` | per-prompt status emission; not what the user asked for |
| `quality-parallel-async.sh` | quality parallel | `.claude/hooks/quality-parallel-async.sh` | parallel gate runner; gate is opt-in via `/gates`, not per-prompt |
| `batch-progress-tracker.sh` | progress tracker | `.claude/hooks/batch-progress-tracker.sh` | per-batch progress emission; only useful in batch runs |
| `progress-tracker.sh` | progress tracker | `.claude/hooks/progress-tracker.sh` | same as above; legacy entry, kept for backwards compat |
| `auto-format-prettier.sh` | display hook | `.claude/hooks/auto-format-prettier.sh` | auto-format on every save; user invokes `/format` |
| `ai-code-audit.sh` | display hook | `.claude/hooks/ai-code-audit.sh` | auto-audit on every change; user invokes `/audit` |
| `code-review-auto.sh` | display hook | `.claude/hooks/code-review-auto.sh` | auto-review on every change; user invokes `/review` |
| `anti-rationalization-gate.sh` | display hook | `.claude/hooks/anti-rationalization-gate.sh` | gate on every reasoning step; user invokes `/adversarial` |
| `console-log-detector.sh` | display hook | `.claude/hooks/console-log-detector.sh` | detector on every console output; user invokes detector |
| `task-orchestration-optimizer.sh` | display hook | `.claude/hooks/task-orchestration-optimizer.sh` | per-task optimization; user invokes optimizer |

**PENDING M2 LANDING**: this whole group moves out of the default
`settings.json.example` chain only when T106/M2 lands. Until then, they
remain registered; after M2, they remain OPT-IN via explicit invocation.

---

## D. COLD-PATH (SessionEnd / scheduler; never on hot path)

These components run on session boundaries or on a scheduler. They are
NEVER registered on `PreToolUse` or per-prompt events. They are the
"compaction, consolidation, extraction" tier that was always meant to be
async and now is explicitly so.

| component | trigger | source | runs because |
|---|---|---|---|
| `decision-extractor.sh` | PostToolUse (low-prio) | `.claude/hooks/decision-extractor.sh` | extracts decisions from tool output after the fact; async to user |
| `semantic-realtime-extractor.sh` | PostToolUse | `.claude/hooks/semantic-realtime-extractor.sh` | realtime semantic extraction; off the hot path (PostToolUse is not hot) |
| `vault-fact-extractor.sh` | SessionEnd / scheduler | `.claude/hooks/vault-fact-extractor.sh` | vault migration; runs at session end |
| `dream-consolidate.sh` | SessionEnd / scheduler | `.claude/hooks/dream-consolidate.sh` | compaction + consolidation; off the per-prompt path by design |
| `periodic-reminder.sh` | SessionEnd | `.claude/hooks/periodic-reminder.sh` | periodic reminder emission; session-boundary only |
| `memory-projection.sh` | SessionEnd | `.claude/hooks/memory-projection.sh` | memory state projection at session end |
| `vault-promotion.sh` / `vault-graduation.sh` / `auto-migrate-plan-state.sh` | SessionStart (one-shot) | `.claude/hooks/vault-promotion.sh` etc. | plan-state migration at session start; once per session, not per prompt |
| `checkpoint-auto-save.sh` / `checkpoint-smart-save.sh` | PostToolUse (debounced) | `.claude/hooks/checkpoint-auto-save.sh` | debounced checkpoint; not per-prompt |
| `auto-migrate-plan-state.sh` | SessionStart | `.claude/hooks/auto-migrate-plan-state.sh` | plan-state migration; once per session |

---

## E. Summary by category (4 rows, used in README)

| category | survives? | shape |
|---|---|---|
| SECURITY | always | 6 hooks on `PreToolUse` for Bash/Edit/Write/Agent/Task/Skill (and one sourced lib) |
| CANÓNICO #47 | active | plan-state writer + readers, recall on-demand, task-state, T101 guards + writers |
| OPT-IN | retired from default | 17 hooks (aristotle, learning, lifecycle, status, quality-parallel, progress, display, extract-moved) survive as `/skillname` opt-in only |
| COLD-PATH | always | ~10 hooks on SessionEnd/PostToolUse/scheduler; never on per-prompt events |

**Total**: 84 hooks in `.claude/hooks/`. After M2, the default SessionStart/PreToolUse wake-up chain drops from ~50 to ~12 (the 6 security + ~5 canonical + the session lifecycle minimum), shifting the per-prompt cost from "every hook fires" to "the 12 that matter fire". The remaining ~70 hooks become opt-in (user-invoked) or cold-path (session-end).

---

## F. Source-of-truth references

Every row above traces to one of:

- `.claude/security/SECURITY_BASELINE.json` (version 1.2.0, issue 46, STEP B)
- `.claude/security/settings.security-only.json` (registration surface)
- `scripts/memory/recall_v2.py` (canonical recall + RISK_EMITTED_FIELDS table)
- `.claude/hooks/lib/plan-state-writer.sh` (canonical atomic writer)
- `.claude/hooks/ralph-subagent-start.sh` + `.claude/hooks/subagent-stop-universal.sh` (state writers)
- `.claude/hooks/agent-policy-guard.sh` + `.claude/hooks/agent-depth-soft-enforce.sh` (T101 guards)

If a row in this document claims a source that does not exist when
audited, delete the row — the inventory is meant to be deletable, not
decorative.

The README section (PART 3) embeds the diagram (SVG+PNG from
`docs/assets/`) and a one-line-per-category summary. It does not
duplicate this table; this is the table, the README is the visual.
