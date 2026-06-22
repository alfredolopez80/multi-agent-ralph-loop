# Orchestrator Visual Diagrams - v2.81.0

**Date**: 2026-01-29
**Version**: v2.81.0
**Status**: DIAGRAMS COMPLETE

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MULTI-AGENT RALPH v2.81.0                         │
│                       Orchestrator Learning System                         │
└─────────────────────────────────────────────────────────────────────────────┘

                                    ┌─────────────────┐
                                    │   USER REQUEST  │
                                    │ "Implement API" │
                                    └────────┬────────┘
                                             │
                                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STEP 0: EVALUATE                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              SMART MEMORY SEARCH (PARALLEL)                          │   │
│  │  ┌──────────┐      ┌──────────┐      ┌──────────┐                  │   │
│  │  │claude-mem│      │handoffs  │      │ ledgers  │                  │   │
│  │  │          │      │          │      │          │                  │   │
│  │  │ Semantic │      │ Session  │      │Continuity│                  │   │
│  │  │   facts  │      │snapshots │      │   data   │                  │   │
│  │  └────┬─────┘      └────┬─────┘      └────┬─────┘                  │   │
│  └───────┼─────────────────┼─────────────────┼────────────────────────┘   │
│          │                 │                 │                             │
│          └─────────────────┴─────────────────┘                             │
│                               │                                             │
│                               ▼                                             │
│                    .claude/memory-context.json                               │
│                    ├── past_successes                                       │
│                    ├── past_errors                                          │
│                    ├── recommended_patterns                                  │
│                    └── fork_suggestions                                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                             │
                                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STEP 1: CLARIFY + CLASSIFY                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────┐      ┌──────────────────────┐                    │
│  │   AskUserQuestion    │      │   Detect Project     │                    │
│  │                      │      │        Type          │                    │
│  │ • MUST_HAVE          │      │ • package.json → TS  │                    │
│  │ • NICE_TO_HAVE       │      │ • requirements.txt → │                    │
│  │ • Blocking questions │      │   Python             │                    │
│  └──────────┬───────────┘      │ • go.mod → Go        │                    │
│             │                  └──────────┬───────────┘                    │
│             ▼                             │                                 │
│  ┌──────────────────────┐                 │                                 │
│  │    Classification     │◄────────────────┘                                 │
│  │                      │                                                   │
│  │ • Complexity (1-10)  │                                                   │
│  │ • Info Density       │                                                   │
│  │ • Context Req        │                                                   │
│  └──────────┬───────────┘                                                   │
│             │                                                               │
└─────────────┼───────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                  STEP 2: CHECK LEARNING STATE (v2.81.0)                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    LEARNING BRIDGE HOOK                             │   │
│  │  orchestrator-learning-bridge.sh (PreToolUse: Task)                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CHECK: Procedural Rules                                           │   │
│  │  ~/.ralph/procedural/rules.json                                     │   │
│  │                                                                     │   │
│  │  Total Rules: X                                                     │   │
│  │  Context-Relevant: Y                                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CHECK: Curator Corpus                                             │   │
│  │  ~/.ralph/curator/corpus/approved/                                  │   │
│  │                                                                     │   │
│  │  Approved Repos: Z                                                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│                    ┌──────────────┴──────────────┐                         │
│                    │                             │                         │
│               YES  │                             │  NO                     │
│          ┌─────────┴─────────┐         ┌─────────┴─────────┐              │
│          │   APPLY LEARNED    │         │   SUGGEST CURATOR  │              │
│          │      PATTERNS      │         │                     │              │
│          └─────────┬─────────┘         │ 💡 Consider:        │              │
│                    │                   │ /curator full --type │              │
│                    │                   │ backend --lang ts   │              │
│                    │                   └─────────┬───────────┘              │
│                    │                             │                         │
│                    └────────────┬────────────────┘                         │
│                                 │                                         │
└─────────────────────────────────┼─────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       STEP 3: PLAN WITH MEMORY                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  INPUT: Memory Context                                              │   │
│  │  • Past successes → Use these patterns                              │   │
│  │  • Past errors → Avoid these pitfalls                               │   │
│  │  • Fork suggestions → Similar successful sessions                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CREATE: Plan State                                                 │   │
│  │  .claude/plan-state.json                                             │   │
│  │                                                                     │   │
│  │  {                                                                 │   │
│  │    "version": "2.62.0",                                            │   │
│  │    "phases": [...],                                                │   │
│  │    "steps": {...},                                                 │   │
│  │    "barriers": {...}                                               │   │
│  │  }                                                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STEP 4: EXECUTE WITH LEARNING                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  FOR EACH STEP:                                                             │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  4a. APPLY LEARNED PATTERNS                                          │   │
│  │  ┌───────────────────────────────────────────────────────────┐     │   │
│  │  │ QUERY: Procedural Rules                                   │     │   │
│  │  │ jq '.rules[] | select(.domain == "backend")              │     │   │
│  │  │     | select(.confidence > 0.7)'                          │     │   │
│  │  │   ~/.ralph/procedural/rules.json                          │     │   │
│  │  └───────────────────────────────────────────────────────────┘     │   │
│  │                              │                                     │   │
│  │                              ▼                                     │   │
│  │  ┌───────────────────────────────────────────────────────────┐     │   │
│  │  │ APPLY: Pattern to Implementation                          │     │   │
│  │  │                                                          │     │   │
│  │  │ 💡 Using pattern from nestjs/nest (confidence: 0.92):    │     │   │
│  │  │    • Error handling: Custom exception classes            │     │   │
│  │  │    • Validation: class-validator decorators              │     │   │
│  │  │    • Logging: Winston with structured format             │     │   │
│  │  └───────────────────────────────────────────────────────────┘     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  4b. VERIFY PLAN STATE                                              │   │
│  │  plan-state-verification.sh (PostToolUse: Edit/Write)              │   │
│  │                                                                     │   │
│  │  • Check JSON validity                                             │   │
│  │  • Check in_progress steps                                         │   │
│  │  • Detect drift from spec                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  4c. DETECT DRIFT + SYNC                                            │   │
│  │  plan-sync-post-step.sh                                            │   │
│  │                                                                     │   │
│  │  IF drift detected:                                                │   │
│  │    • Update downstream steps                                       │   │
│  │    • Patch spec to actual                                          │   │
│  │    • Log to drift_log                                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  4d. MICRO-GATE VALIDATION                                          │   │
│  │                                                                     │   │
│  │  • Lint                                                            │   │
│  │  • Type check                                                      │   │
│  │  • Security scan                                                   │   │
│  │  • Max 3 retries                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  CONTEXT COMPACTION:                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  PreCompact: Save plan-state → ~/.ralph/active-plan/               │   │
│  │  Compaction occurs (old messages removed)                          │   │
│  │  Post-compact: Restore plan-state ← ~/.ralph/active-plan/          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                  STEP 5: RETROSPECTIVE + LEARNING                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  CONTINUOUS LEARNING DAEMON                                          │   │
│  │  continuous-learning-daemon.sh (Stop hook)                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  5a. EXTRACT PATTERNS                                              │   │
│  │  ┌───────────────────────────────────────────────────────────┐     │   │
│  │  │ git diff HEAD → Analyze changes                           │     │   │
│  │  │                                                          │     │   │
│  │  │ • Functions extracted: N                                 │     │   │
│  │  │ • Classes extracted: M                                   │     │   │
│  │  │ • Patterns found: K                                      │     │   │
│  │  └───────────────────────────────────────────────────────────┘     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  5b. SAVE TO PROCEDURAL                                            │   │
│  │  ~/.ralph/procedural/rules.json                                     │   │
│  │                                                                     │   │
│  │  {                                                                 │   │
│  │    "id": "rule_123456",                                           │   │
│  │    "pattern": "async-error-handling",                             │   │
│  │    "domain": "backend",                                           │   │
│  │    "confidence": 0.85,                                            │   │
│  │    "source_repo": "user-project",                                 │   │
│  │    "code": "try { await op() } catch (e) { handle(e) }"          │   │
│  │  }                                                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  5c. SUGGEST REPO LEARNING                                         │   │
│  │                                                                     │   │
│  │  💡 Consider learning from quality repos:                          │   │
│  │     /curator learn --type backend --lang typescript                │   │
│  │     repo-learn https://github.com/nestjs/nest                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                             │
│                              ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  5d. UPDATE MEMORY                                                  │   │
│  │  ┌───────────────────────────────────────────────────────────┐     │   │
│  │  │ claude-mem: Save successful pattern                        │     │   │
│  │  │  │ ledgers: Log session completion                             │     │   │
│  │  └───────────────────────────────────────────────────────────┘     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                           VERIFIED_DONE
```

## Component Integration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COMPONENT INTEGRATION                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐         ┌──────────────────────┐         ┌──────────────────────┐
│    REPO CURATOR      │         │   REPOSITORY LEARNER │         │      PLAN STATE       │
│                      │         │                      │         │                      │
│  Location:           │         │  Location:           │         │  Location:           │
│  ~/.ralph/curator/   │         │  ~/.ralph/scripts/   │         │  .claude/plan-state   │
│                      │         │  repo-learn.sh       │         │  .json                │
│  Scripts: 9          │         │                      │         │                      │
│  • discovery         │         │  Version: 1.4.0      │         │  Schema: v2.62.0      │
│  • scoring           │         │  v2.68.23            │         │                      │
│  • ranking           │         │                      │         │  Scripts: 2           │
│  • show              │         │  Features:           │         │  • plan.sh            │
│  • pending           │         │  • AST extraction    │         │  • migrate.sh         │
│  • approve           │         │  • Domain classify   │         │                      │
│  • reject            │         │  • Procedural rules  │         │  Hooks: 5             │
│  • learn             │         │  • Source attr       │         │  • auto-migrate       │
│  • full              │         │                      │         │  • auto-plan-state    │
│                      │         │  Security:           │         │  • init               │
│  Hooks: 2            │         │  • SEC-106 path val  │         │  • lifecycle          │
│  • curator-suggestion│         │  • DUP-001 library   │         │  • adaptive           │
│  • auto-learn        │         │                      │         │                      │
│                      │         │  Hooks: 0            │         │  CLI: 5 commands      │
└──────────┬───────────┘         └──────────┬───────────┘         │  • show               │
           │                               │                      │  • archive            │
           │                               │                      │  • reset               │
           └───────────────┬───────────────┘                      │  • history            │
                           │                                      │  • restore            │
                           │                                      └──────────┬───────────┘
                           ▼                                                 │
                   ┌──────────────────────────────────────────────────────────┤
                   │          ORCHESTRATOR INTEGRATION LAYER                 │
                   │  (NEW v2.81.0)                                          │
                   ├──────────────────────────────────────────────────────────┤
                   │                                                          │
                   │  ┌─────────────────────────────────────────────────┐    │
                   │  │  orchestrator-learning-bridge.sh                │    │
                   │  │  • Detect project type                          │    │
                   │  │  • Check learning state                         │    │
                   │  │  • Suggest curator if needed                    │    │
                   │  └─────────────────────────────────────────────────┘    │
                   │                                                          │
                   │  ┌─────────────────────────────────────────────────┐    │
                   │  │  plan-state-verification.sh                     │    │
                   │  │  • Verify plan-state consistency               │    │
                   │  │  • Detect drift                                │    │
                   │  │  • Trigger sync                                 │    │
                   │  └─────────────────────────────────────────────────┘    │
                   │                                                          │
                   │  ┌─────────────────────────────────────────────────┐    │
                   │  │  continuous-learning-daemon.sh                   │    │
                   │  │  • Extract patterns from git diff               │    │
                   │  │  • Update procedural rules                      │    │
                   │  │  • Suggest repo learning                        │    │
                   │  └─────────────────────────────────────────────────┘    │
                   │                                                          │
                   └───────────────────────────┬──────────────────────────────┘
                                               │
                                               ▼
                           ┌────────────────────────────────────────┐
                           │        PROCEDURAL RULES               │
                           │  ~/.ralph/procedural/rules.json       │
                           │                                        │
                           │  Patterns from:                        │
                           │  • Repo Curator discovery              │
                           │  • Repository Learner extraction       │
                           │  • User implementations                 │
                           │                                        │
                           │  Used by:                               │
                           │  • Orchestrator during implementation  │
                           │  • Pattern application display         │
                           └────────────────────────────────────────┘
```

## Hook Chain

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          HOOK CHAIN v2.81.0                                 │
└─────────────────────────────────────────────────────────────────────────────┘

SessionStart
  │
  ├─── auto-migrate-plan-state.sh
  │    └──→ Migrate plan-state schema if needed
  │
  ├─── auto-curator-trigger.sh (NEW v2.81.0)
  │    └──→ Detect new project, suggest curator
  │
  ├─── session-start-reset-counters.sh
  │    └──→ Reset operation counters
  │
  └─── session-start-ledger.sh
       └──→ Load session ledger

UserPromptSubmit
  │
  ├─── smart-memory-search.sh
  │    └──→ PARALLEL search: claude-mem + handoffs + ledgers
  │
  ├─── curator-suggestion.sh
  │    └──→ Suggest curator if procedural memory empty
  │
  └─── context-warning.sh
       └──→ Warn at 75%/85% context usage

PreToolUse (Task)
  │
  ├─── orchestrator-learning-bridge.sh (NEW v2.81.0)
  │    ├──→ Detect project type
  │    ├──→ Check learning state
  │    └──→ Suggest curator if needed
  │
  ├─── orchestrator-auto-learn.sh
  │    └──→ Auto-learning trigger (complexity >= 7, rules < 3)
  │
  └─── task-orchestration-optimizer.sh
       └──→ Detect parallelization opportunities

PreToolUse (Edit/Write)
  │
  ├─── pattern-application-display.sh (NEW v2.81.0)
  │    └──→ Show which patterns are being applied
  │
  └─── plan-state-verification.sh (NEW v2.81.0)
       └──→ Verify plan-state consistency

PostToolUse (Edit/Write)
  │
  ├─── session-cleanup-guard.sh
  │    └──→ Clean up session files
  │
  ├─── plan-sync-post-step.sh
  │    └──→ Detect drift and sync plan
  │
  └─── status-auto-check.sh
       └──→ Auto-show status every 5 operations

PreCompact
  │
  ├─── pre-compact-handoff.sh
  │    └──→ Save plan-state before compaction
  │
  └─── plan-state-adaptive.sh
       └──→ Adaptive compaction based on plan state

Stop
  │
  ├─── continuous-learning-daemon.sh (NEW v2.81.0)
  │    ├──→ Extract patterns from git diff
  │    ├──→ Update procedural rules
  │    └──→ Suggest repo learning
  │
  ├─── orchestrator-report.sh
  │    └──→ Generate orchestration report
  │
  └─── semantic-auto-extractor.sh
       └──→ Extract semantic facts from changes
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA FLOW                                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│REPO CURATOR  │────▶│REPO LEARNER  │────▶│PROCEDURAL    │
│              │     │              │     │RULES         │
│• Discovery   │     │• AST analysis│     │              │
│• Scoring     │     │• Extraction  │     │• Patterns    │
│• Ranking     │     │• Classification│    │• Confidence  │
│• Review      │     │• Domain      │     │• Source attr │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                 │
                                                 │
                                                 ▼
                                    ┌──────────────────────┐
                                    │   ORCHESTRATOR       │
                                    │                      │
                                    │ 1. Query rules       │
                                    │ 2. Apply patterns    │
                                    │ 3. Extract new       │
                                    │ 4. Update rules      │
                                    └──────────┬───────────┘
                                               │
                                               ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│PLAN STATE    │◀────│LEARNING      │────▶│MEMORY        │
│              │     │BRIDGE        │     │              │
│• Phases      │     │              │     │• Semantic    │
│• Steps       │     │• Detect type │     │• Episodic    │
│• Barriers    │     │• Check state │     │• Procedural  │
│• Context     │     │• Suggest     │     │              │
│  survival    │     │  learning    │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
```

## Auto-Learning Triggers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       AUTO-LEARNING TRIGGERS                               │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ TRIGGER 1: High Complexity + Low Rules                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  IF complexity >= 7 AND procedural_rules < 3:                               │
│    → orchestrator-auto-learn.sh triggers                                   │
│    → Suggest: /curator full --type <detected> --lang <detected>            │
│                                                                             │
│  Example:                                                                   │
│    User: /orchestrator "Implement distributed caching system"                │
│    Complexity: 8 (high)                                                     │
│    Rules: 1 (low)                                                          │
│    → 💡 Suggest: /curator full --type backend --lang typescript             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ TRIGGER 2: No Context-Relevant Rules                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  IF no context-relevant rules for project type:                             │
│    → orchestrator-learning-bridge.sh triggers                              │
│    → Suggest: /curator scoring --context "<patterns>"                       │
│                                                                             │
│  Example:                                                                   │
│    Project: TypeScript backend                                              │
│    Rules: 50 total, 0 relevant to "typescript"                              │
│    → 💡 Suggest: /curator full --type backend --lang typescript             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ TRIGGER 3: New Project Detected                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  IF new project (no .claude history):                                       │
│    → auto-curator-trigger.sh triggers                                      │
│    → Suggest: /curator full --type <detected> --lang <detected>            │
│                                                                             │
│  Example:                                                                   │
│    New project: package.json found                                         │
│    No .claude/plan-state.json                                               │
│    → 💡 Suggest: /curator full --type backend --lang typescript             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ TRIGGER 4: Git Diff with Patterns                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  IF git diff contains pattern-worthy code:                                  │
│    → continuous-learning-daemon.sh triggers                                │
│    → Suggest: repo-learn for current implementation                         │
│                                                                             │
│  Example:                                                                   │
│    Git diff shows: 15 new functions, 5 classes                             │
│    → 💡 Suggest: repo-learn . --category implementation_patterns           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Pattern Application Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      PATTERN APPLICATION FLOW                               │
└─────────────────────────────────────────────────────────────────────────────┘

STEP 1: USER REQUEST
┌─────────────────────────────────────────────────────────────────────────────┐
│  User: "Implement error handling for REST API"                              │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
STEP 2: QUERY PROCEDURAL RULES
┌─────────────────────────────────────────────────────────────────────────────┐
│  $ jq '.rules[] | select(.pattern | contains("error"))                     │
│      | select(.confidence > 0.7)' ~/.ralph/procedural/rules.json           │
│                                                                             │
│  Found: 5 patterns (confidence > 0.7)                                       │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
STEP 3: DISPLAY PATTERNS
┌─────────────────────────────────────────────────────────────────────────────┐
│  💡 Applying 5 learned patterns for error handling (confidence > 0.7)     │
│                                                                             │
│  1. nestjs/nest (0.92) - Custom exception classes                          │
│  2. fastapi/fastapi (0.89) - HTTPException handling                         │
│  3. expressjs/express (0.85) - Error middleware                            │
│  4. go-gin/gonic (0.78) - Middleware panic recovery                        │
│  5. actix/actix-web (0.76) - Error response builders                      │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
STEP 4: APPLY PATTERN
┌─────────────────────────────────────────────────────────────────────────────┐
│  Using pattern from nestjs/nest (confidence: 0.92):                        │
│                                                                             │
│  • Create custom exception class                                            │
│  • Extend base HttpException                                               │
│  • Add error code and metadata                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
STEP 5: IMPLEMENT CODE
┌─────────────────────────────────────────────────────────────────────────────┐
│  class NotFoundException extends HttpException {                             │
│    constructor(message: string) {                                          │
│      super(message, HttpStatus.NOT_FOUND);                                 │
│    }                                                                       │
│  }                                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
STEP 6: VERIFY APPLICATION
┌─────────────────────────────────────────────────────────────────────────────┐
│  ✓ Pattern applied correctly                                               │
│  ✓ Custom exception class created                                          │
│  ✓ Extends HttpException                                                   │
│  ✓ Includes error code                                                     │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
STEP 7: EXTRACT NEW PATTERN (IF IMPROVED)
┌─────────────────────────────────────────────────────────────────────────────┐
│  IF implementation improved pattern:                                       │
│    • Extract new variant                                                   │
│    • Update procedural rules                                               │
│    • Increment confidence score                                            │
│                                                                             │
│  ELSE:                                                                      │
│    • Continue with existing pattern                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Context Survival Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONTEXT SURVIVAL FLOW                                    │
└─────────────────────────────────────────────────────────────────────────────┘

BEFORE COMPACTION
┌─────────────────────────────────────────────────────────────────────────────┐
│  Current Context Window:                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • User request                                                       │   │
│  │ • Plan discussion                                                    │   │
│  │ • Step 1: Analysis                                                  │   │
│  │ • Step 2: Implementation                                            │   │
│  │ • Step 3: Testing (IN PROGRESS)                                     │   │
│  │ • plan-state.json in memory                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Context: 180K/200K (90%) - THRESHOLD REACHED                             │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
COMPACT TRIGGERED
┌─────────────────────────────────────────────────────────────────────────────┐
│  PreCompact Hook: pre-compact-handoff.sh                                   │
│                                                                             │
│  1. Save plan-state to disk:                                               │
│     $ cp .claude/plan-state.json ~/.ralph/active-plan/plan-state.json      │
│                                                                             │
│  2. Create handoff:                                                        │
│     $ ralph handoff create --context "Step 3 in progress"                  │
│                                                                             │
│  ✓ State saved                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
COMPACTION OCCURS
┌─────────────────────────────────────────────────────────────────────────────┐
│  Claude Code compacts context:                                             │
│                                                                             │
│  Removed messages:                                                         │
│  • User request                                                            │
│  • Plan discussion                                                         │
│  • Step 1: Analysis                                                        │
│  • Step 2: Implementation                                                  │
│                                                                             │
│  Current Context Window:                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ • Step 3: Testing (IN PROGRESS)                                     │   │
│  │ • System: Context compacted                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Context: 90K/200K (45%)                                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
POST-COMPACT RESTORATION
┌─────────────────────────────────────────────────────────────────────────────┐
│  SessionStart Hook (post-compact):                                         │
│                                                                             │
│  1. Restore plan-state:                                                    │
│     $ cp ~/.ralph/active-plan/plan-state.json .claude/plan-state.json      │
│                                                                             │
│  2. Load handoff:                                                          │
│     $ ralph handoff load                                                  │
│                                                                             │
│  3. Verify state:                                                          │
│     $ jq '.steps["step3"].status' .claude/plan-state.json                  │
│     "in_progress"                                                          │
│                                                                             │
│  ✓ State restored                                                          │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
CONTINUE EXECUTION
┌─────────────────────────────────────────────────────────────────────────────┐
│  Orchestrator continues:                                                   │
│                                                                             │
│  • Step 3: Testing (IN PROGRESS)                                           │
│  • Plan fully restored                                                     │
│  • No data loss                                                            │
│                                                                             │
│  ✓ Execution continues seamlessly                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Summary

Este documento visualiza:

1. **Architecture Overview** - Flujo completo del orchestrator con integración de aprendizaje
2. **Component Integration** - Cómo los tres componentes principales se conectan
3. **Hook Chain** - Todos los hooks y cuándo se ejecutan
4. **Data Flow** - Cómo fluyen los datos entre componentes
5. **Auto-Learning Triggers** - Cuándo se activa el aprendizaje automático
6. **Pattern Application Flow** - Cómo se aplican los patrones aprendidos
7. **Context Survival Flow** - Cómo sobrevive el plan a la compactación de contexto

Para más detalles, ver:
- [ORCHESTRATOR_COMPONENTS_ANALYSIS_v2.81.0.md](./ORCHESTRATOR_COMPONENTS_ANALYSIS_v2.81.0.md)
- [ORCHESTRATOR_IMPROVEMENT_PLAN_v2.81.0.md](./ORCHESTRATOR_IMPROVEMENT_PLAN_v2.81.0.md)
- [RESUMEN_EJECUTIVO_ORCHESTRATOR_v2.81.0.md](./RESUMEN_EJECUTIVO_ORCHESTRATOR_v2.81.0.md)
