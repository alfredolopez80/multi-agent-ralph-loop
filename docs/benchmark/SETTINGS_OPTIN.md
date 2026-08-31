# Settings Opt-in Companion — T106-m2-optin

**Date**: 2026-08-28 · **Worker**: mmx-2
**Companion to**: `.claude/settings.json.example` (security-only active JSON)

This document is the source of truth for opt-in hook entries — entries that
the repo ships in `.claude/hooks/` but does NOT register by default in
`.claude/settings.json.example`. The example is strict JSON so it can be
parsed by `jq` (the test in `tests/hooks/test_session_end_extractors.sh` does
that); this file is markdown so we can document cost/benefit inline.

## How to opt in

1. Copy the relevant JSON snippet below.
2. Paste it into your `~/.claude/settings.json` under the appropriate event
   key (PreToolUse, PostToolUse, etc.).
3. Save the file. Claude Code re-reads it on next session.

Each snippet is a complete `{ "matcher": "...", "hooks": [...] }` tuple —
insert it into the array for that event.

## Path convention

All hook paths use `$CLAUDE_PROJECT_DIR/.claude/hooks/<basename>`. The
hooks themselves live in the repo and are NEVER deleted by M2 (criterion
#48: "Preserve as optional capabilities").

## Cost source

Numbers are median wall-time per invocation, N=12 each, from
`docs/benchmark/HOTPATH_M1_2026-08-28.md`. "0 ms" means by construction —
the hook never fires on the relevant event for an ordinary prompt.

---

## UserPromptSubmit (1 tuple, 2 hook commands)

```json
{
  "matcher": "*",
  "hooks": [
    { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/command-router.sh" },
    { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/context-warning.sh" }
  ]
}
```

- `command-router.sh` — routes prompts to specialized handlers. COST: ~10 ms.
- `context-warning.sh` — warns when context budget is low. COST: ~5 ms.

## PreToolUse (2 tuples, 5 hook commands)

```json
[
  {
    "matcher": "Task",
    "hooks": [
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/smart-memory-search.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/orchestrator-auto-learn.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/fast-path-check.sh" }
    ]
  },
  {
    "matcher": "Edit|Write",
    "hooks": [
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/checkpoint-smart-save.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/inject-session-context.sh" }
    ]
  }
]
```

- `smart-memory-search.sh` — semantic search on Task for memory hits. COST: ~30 ms/Task.
- `orchestrator-auto-learn.sh` — captures orchestrator learning on subagent spawns. COST: ~14 ms/A|T (M1), but 0 ms on ordinary Bash/Edit (doesn't fire).
- `fast-path-check.sh` — trivial-task detector (T96 survey: NOT registered by default, only suggests). COST: ~10 ms/Task.
- `checkpoint-smart-save.sh` — smart checkpoint on Edit|Write. COST: ~15 ms/E|W.
- `inject-session-context.sh` — inject context into Edit/Write input. COST: ~20 ms/E|W.

## PreToolUse (additional opt-in for Aristotle users)

```json
{
  "matcher": "*",
  "hooks": [
    { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/universal-aristotle-gate.sh" }
  ]
}
```

- `universal-aristotle-gate.sh` — methodology gate for tool calls. COST: 22 ms/Bash (M1). User-mandated methodology; opt-in only for users not running Aristotle.

## PostToolUse — hot-path chain (4 tuples, 12 hook commands)

These are the bulk of the 226 ms/edición M1 measurement. All emit ~5
stdout tokens (side-state, not context). Top candidates for
async-ification in M2 follow-ups. **Note**: the test
`tests/hooks/test_session_end_extractors.sh` rejects registering these
on the hot-path events because they are memory-maintenance hooks (the
"preserve as optional" cap they fit into is opt-in, not default).

```json
[
  {
    "matcher": "Edit|Write|Bash",
    "hooks": [
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/status-auto-check.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/quality-parallel-async.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-code-audit.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/console-log-detector.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/auto-format-prettier.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/progress-tracker.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/checkpoint-auto-save.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/vault-fact-extractor.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-accumulator.sh" }
    ]
  }
]
```

Per-hook costs:
- `status-auto-check.sh` — 67 ms/E|W|B (BIGGEST single contributor; top async candidate).
- `quality-parallel-async.sh` — 37 ms/E|W|B.
- `ai-code-audit.sh` — 22 ms/E|W|B.
- `console-log-detector.sh` — 14 ms/E|W|B.
- `auto-format-prettier.sh` — 13 ms/E|W|B.
- `progress-tracker.sh` — 13 ms/E|W|B.
- `checkpoint-auto-save.sh` — 15 ms/E|W.
- `vault-fact-extractor.sh` — 11 ms/E|W|B.
- `session-accumulator.sh` — 10 ms/E|W|B.

Total chain: 226 ms/edición (M1).

## PostToolUse — Task / TodoWrite orchestration (2 tuples, 4 hook commands)

```json
[
  {
    "matcher": "Task",
    "hooks": [
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/parallel-explore.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/recursive-decompose.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/plan-analysis-cleanup.sh" }
    ]
  },
  {
    "matcher": "TodoWrite",
    "hooks": [
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/todo-plan-sync.sh" }
    ]
  }
]
```

- `parallel-explore.sh` — Task parallelism coordinator. COST: ~30 ms/Task.
- `recursive-decompose.sh` — Task recursion handler. COST: ~25 ms/Task.
- `plan-analysis-cleanup.sh` — Task cleanup. COST: ~15 ms/Task.
- `todo-plan-sync.sh` — TodoWrite → plan-state sync. COST: ~10 ms.

## PreCompact (1 tuple, 1 hook command)

```json
{
  "matcher": "*",
  "hooks": [
    { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-compact-handoff.sh" }
  ]
}
```

- `pre-compact-handoff.sh` — writes handoff before compaction. COST: ~210 ms/PreCompact (M1). Opt-in if you want explicit handoff; otherwise SessionStart:compact's post-compact-restore (mandatory) reconstructs from disk.

## SessionStart (2 tuples, 4 hook commands)

```json
[
  {
    "matcher": "*",
    "hooks": [
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/wake-up-layer-stack.sh" }
    ]
  },
  {
    "matcher": "*",
    "hooks": [
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-start-restore-context.sh" },
      { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/auto-migrate-plan-state.sh" }
    ]
  }
]
```

- `wake-up-layer-stack.sh` — injects L0-L1 essential rules at session start. COST: ~110 ms/session start, 827 tok wake-up block. Already REDUCED in T74 (broad recall retired).
- `session-start-restore-context.sh` — restores session context. COST: ~80 ms (T74).
- `auto-migrate-plan-state.sh` — schema migration for plan-state across versions. COST: ~50 ms (cold-path). NOTE: plan-sync-post-step (mandatory on PostToolUse) keeps state canonical for #47 C1 regardless.

## Stop (1 tuple, 2 hook commands)

```json
{
  "matcher": "*",
  "hooks": [
    { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/sentry-report.sh" },
    { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/orchestrator-report.sh" }
  ]
}
```

- `sentry-report.sh` — error report on Stop. COST: ~30 ms/Stop.
- `orchestrator-report.sh` — orchestrator status on Stop. COST: ~25 ms.

---

## Summary

| Event | Opt-in matcher tuples | Opt-in hook commands |
|---|---:|---:|
| UserPromptSubmit | 1 | 2 |
| PreToolUse | 3 | 6 |
| PostToolUse (hot-path chain) | 1 | 9 |
| PostToolUse (Task/TodoWrite) | 2 | 4 |
| PreCompact | 1 | 1 |
| SessionStart | 2 | 4 |
| Stop | 1 | 2 |
| **Total** | **11** | **28** |

Compare to active `.claude/settings.json.example`: 17 matcher tuples, 22
hook commands (security-only default).

---

*Authored by `mmx-2` on 2026-08-28 as part of T106-m2-optin + RETURN-fix. Cost numbers cited from `docs/benchmark/HOTPATH_M1_2026-08-28.md`.*
