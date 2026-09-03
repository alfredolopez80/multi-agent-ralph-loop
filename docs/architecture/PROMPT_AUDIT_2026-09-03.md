# Prompt Audit — 2026-09-03

> Historical record. Model/provider names below describe the state at the time of writing; the current rule is that the model is whatever the session runs.

Run via `/claude-api prompt-audit` ("clear old junk"). Edits at high/medium
confidence were applied in the same pass; `flag` items were not.

## Assumptions

- **Scope**: this repository's prompt surface — `CLAUDE.md`, `.claude/rules-src/`
  (source of the globally synced rules), 62 `SKILL.md`, 36 agent files,
  1 command. 105 files, ~840 KB. `~/.claude/` files that are copies or
  symlinks of these were resynced, not audited separately.
- **Target model**: Claude Fable 5.1 (the session model in
  `~/.claude/settings.json`). Thinking is always on and depth is set by
  `effort`; the model follows instructions literally and under-narrates
  rather than over-narrates.
- **Non-Anthropic markers**: skills `codex-cli`, `gemini-cli`, `openai-docs`
  and agent `codex-reviewer` orchestrate OpenAI/Google CLIs by design. The
  audit touched only pinned version strings in their prompt text, never the
  provider.
- **Provenance**: `git blame` on every edited range. Two eras: April 2026
  (MemPalace v3.0 refresh, 46 files) and August 2026 (47 files).

## Summary

| Group | Findings | Applied |
|---|---|---|
| 1b Scaffolds replaced by API features | 1 pattern × 23 agents | 23 hunks |
| 1d Fossils (migration-relative, pinned models) | 8 | 8 |
| 1a Pressure language | 4 files | 15 hunks |
| 1c/1e Prohibition clusters | 8 | 8 |
| 2 Volatile version pins in skill metadata | 4 | 4 |
| 4 Roster redundancy | 3 pairs | 0 (proposal only) |
| Flag only | 4 | 0 |

Highest impact:

1. **`**ultrathink** - Take a deep breath ... ## The Vision ...` in 23 of 36
   agents.** A thinking incantation plus an identity paragraph ("You're not
   just an AI assistant. You're a craftsman. An artist.") on a model where
   thinking is always on and depth is `effort`, not prose. Removed from all
   23; the role line in each frontmatter description already sets focus.
2. **A model-selection prohibition that contradicted the repo's own
   invariant.** `orchestrator/SKILL.md` said "Never use model: haiku for
   subagents" while CLAUDE.md (#45) says the model is the user's choice and
   subagents inherit it. Rewritten as the invariant.
3. **Migration-relative fossils in `orchestrator.md`** — two paragraphs
   describing a MiniMax table that was removed on 2026-07-31. The model never
   saw the old version; the text implied routes that do not exist.

## Findings

### High

| Location | Evidence | Pattern | Why obsolete | Action |
|---|---|---|---|---|
| `.claude/agents/*.md:9-12` (23 files) | `**ultrathink** - Take a deep breath. We're not here to write code...` + `## The Vision` paragraph | 1b think incantation; 1d identity stub | Fable 5.1 thinks on every request; depth is `output_config.effort`. The identity paragraph substitutes for context the description already gives. | remove — applied |
| `.claude/agents/debugger.md:4` | `Uses Opus for reasoning.` with `model: inherit` | Group 2 pinned model name | Description no longer matches the frontmatter; the agent inherits the session model. | rewrite — applied |
| `.claude/agents/orchestrator.md:775-780, 1071-1073` | `> **Removed 2026-07-31**: the "When to Use Each Approach" table compared four MiniMax invocation routes ... no longer exist` | 1d migration-relative phrasing | A diff against a prompt version the model never saw; names retired routes. | rewrite to the current rule — applied |
| `.claude/skills/orchestrator/SKILL.md:244-250` | `- Never use model: "haiku" for subagents` inside a 7-line `Never` list | 1e prohibition cluster; contradicts #45 | Conflicts with CLAUDE.md "subagents inherit the model; the user decides with /model". | rewrite as reasoned constraints — applied |

### Medium

| Location | Evidence | Pattern | Why obsolete | Action |
|---|---|---|---|---|
| `.claude/skills/bugs/SKILL.md:23-27` | `## v3.1 — Claude is the engine (was Codex-only)` + "Earlier versions shelled out to `codex exec -m gpt-5.2-codex`..." | Group 2 history narrative; 1d relative | Archaeology of a previous version; the current rule is the bullets that follow. | rewrite heading, drop narrative — applied |
| `CLAUDE.md:78` | `since 2026-09-01 also runs ... (they diverged silently for 30+ runs before that; local green no longer means CI green by accident)` | 1d relative phrasing | Describes a change, not a rule. | rewrite — applied |
| `openai-docs/SKILL.md:166`, `task-visualizer/SKILL.md:148-149`, `adversarial-plan-validator.md:402`, `codex-cli/SKILL.md:223` | `gpt-5.2-codex`, `gemini-2.5-pro`, `codex-gpt-5.2`, "`gpt-5.3-codex` or `gpt-5.2`?" | Group 2 pinned versions / option menus | `codex-cli` itself documents the gpt-5.3 family as current; the visualizer example assigned agents by external model instead of by repo agent. | rewrite — applied |
| `gemini-cli` desc `(v0.22.0+)`, `edd` desc `v2.87.0`, `quality-gates-parallel` desc+body `Claude Code 2.1+`, L276 `2.1.16+` | version pins in trigger text | Group 2 volatile specifics | Descriptions ride in every request and nothing re-verifies the pins. | remove pins — applied |
| `parallel:255-258`, `iterate:347-350`, `clarify:207-210`, `gates:425-427`, `create-task-batch:433-437`, `task-batch:613-619`, `lead-software-architect:333-337` | `## Anti-Patterns` lists of 3-7 unconditional `Never`/`NEVER` lines | 1c prohibition lists; 1e | Each list restated rules given above it, mostly without the reason. Real constraints (5 agents, 4 questions, 3-Fix, max_iterations) kept with their reason; style-only lines rewritten positively. | rewrite — applied |
| `create-task-batch:192-237`, `task-batch:72-94, 347`, `rules-src/plan-immutability.md:7-29` | `CRITICAL`, `MANDATORY`, `MUST NEVER`, `⚠️ CRITICAL RULE`, `NEVER` (5-9 markers per section) | 1a pressure language | Fable 5.1 reads the register literally; stacked markers stop carrying information and make output anxious. Every constraint kept at normal volume. | rewrite — applied |

### Group 4 — roster (proposal, not applied)

Three pairs do the same job with near-duplicate prompts, differing only in tool
set and in being an Agent Teams teammate or a standalone agent:

| Standalone | Teammate | One real difference |
|---|---|---|
| `test-architect` | `ralph-tester` | teammate has `LSP` + scoped `Bash(npm test:*, pytest:*)`; standalone has `Task` |
| `refactorer` | `ralph-coder` | teammate has `Edit`/`Grep`/`Glob`/`Skill`; standalone has `Task` |
| `security-auditor` | `ralph-security` | teammate has `LSP`/`Skill` + scoped scanners; standalone has `Task` |

Proposed edit: delete the standalone file, add `Task` to the teammate's tool
list, and repoint the 12/6/29 references (orchestrator, `quality-gates-parallel`,
`security` skill, `install-claude-native-agents.sh`, parity test). Not applied:
the standalone set is what `install-claude-native-agents.sh` distributes as
"claude-native" copies, and `tests/test_claude_native_copies_parity.py` pins
that roster — the decision is a distribution-policy change, not a prompt fix.

### Flag only (no edit)

- **`<example>` dialogue blocks in `ralph-*` descriptions** (Group 3 "worked
  examples in descriptions"). Claude Code documents this convention for
  subagent trigger text and the official `pr-review-toolkit` uses it. Trigger
  text may carry examples; left as is. Low.
- **Numbered `Step 0..8` choreography in `orchestrator.md` / `orchestrator/SKILL.md`** (1c).
  Order is the product (clarify → plan → execute → validate); this is a
  fragile-order workflow, not judgment choreography. Keep.
- **`ralph-security.md:3-5` frontmatter comment** narrating the old
  `model: default` bug. A YAML comment, not prompt text; harmless. Low.
- **`scripts/ralph:794,801,1004` pins `gpt-5.2-codex` in runtime code.** Out of
  the prompt surface; the same drift as the skill text but lives in a shell
  script with its own tests. Report only.
- **Tool names in skill prose** (`Task tool`, `WebFetch`). In Claude Code the
  tool name is the interface; not a shadow list. Keep.

## Verification

- 41 + 19 hunks applied by asserted replacement (each `old` matched exactly once).
- `install-claude-native-agents.sh` resynced the global copies (parity test 4/4);
  `sync-rules-from-source.sh` propagated `plan-immutability.md`; 8 drifted
  global skill copies resynced; `validate-global-infrastructure.sh` 92/92;
  `validate-skills-unification.sh` OK; `test-skills-unification-v2.87.sh` 318/318.
- `tests/test_v2.36_skills_unification.sh` fails 7 checks before and after
  (excluded from the gate: needs the installed v2.36 reference state).
- Behavioral probe: none run — the repo has no eval for its prompts. Per
  Step 7, if a rewritten skill under-triggers or an agent regresses, re-add
  the instruction in its minimal form rather than restoring the original.
