# Multi-Agent Ralph v2.49.1

> "Me fail English? That's unpossible!" - Ralph Wiggum

**Smart Memory-Driven Orchestration** with parallel memory search, RLM-inspired routing, and quality-first validation.

---

## Quick Start

```bash
# Full orchestration
/orchestrator "Implement OAuth2 authentication"
ralph orch "Migrate database from MySQL to PostgreSQL"

# Quality validation
/gates          # Quality gates
/adversarial    # Spec refinement

# Loop until VERIFIED_DONE
/loop "fix all type errors"
```

---

## Core Workflow (12 Steps) - v2.46

```
0. EVALUATE     → 3-dimension classification (FAST_PATH vs STANDARD)
1. CLARIFY      → AskUserQuestion (MUST_HAVE + NICE_TO_HAVE)
2. CLASSIFY     → Complexity 1-10 + Info Density + Context Req
3. PLAN         → orchestrator-analysis.md → Plan Mode
4. PLAN MODE    → EnterPlanMode (reads analysis)
5. DELEGATE     → Route to optimal model
6. EXECUTE-WITH-SYNC → LSA-VERIFY → IMPLEMENT → PLAN-SYNC → MICRO-GATE
7. VALIDATE     → CORRECTNESS (block) + QUALITY (block) + CONSISTENCY (advisory)
8. RETROSPECT   → Analyze and improve
```

**Fast-Path** (complexity ≤ 3): DIRECT_EXECUTE → MICRO_VALIDATE → DONE (3 steps)

---

## 3-Dimension Classification (RLM)

| Dimension | Values |
|-----------|--------|
| **Complexity** | 1-10 |
| **Information Density** | CONSTANT / LINEAR / QUADRATIC |
| **Context Requirement** | FITS / CHUNKED / RECURSIVE |

### Workflow Routing

| Density | Context | Complexity | Route |
|---------|---------|------------|-------|
| CONSTANT | FITS | 1-3 | **FAST_PATH** |
| CONSTANT | FITS | 4-10 | STANDARD |
| LINEAR | CHUNKED | ANY | PARALLEL_CHUNKS |
| QUADRATIC | ANY | ANY | RECURSIVE_DECOMPOSE |

---

## Memory Architecture (v2.49)

```
SMART MEMORY SEARCH (PARALLEL)
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│claude-mem│ │ memvid   │ │ handoffs │ │ ledgers  │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │ PARALLEL   │ PARALLEL   │ PARALLEL   │ PARALLEL
     └────────────┴────────────┴────────────┘
                    ↓
         .claude/memory-context.json
```

**Three Memory Types**:
| Type | Purpose | Storage |
|------|---------|---------|
| **Semantic** | Facts, preferences | `~/.ralph/memory/semantic.json` |
| **Episodic** | Experiences (30-day TTL) | `~/.ralph/episodes/` |
| **Procedural** | Learned behaviors | `~/.ralph/procedural/rules.json` |

---

## Quality-First Validation (v2.46)

```
Stage 1: CORRECTNESS → Syntax errors (BLOCKING)
Stage 2: QUALITY     → Type errors (BLOCKING)
Stage 2.5: SECURITY  → semgrep + gitleaks (BLOCKING)
Stage 3: CONSISTENCY → Linting (ADVISORY - not blocking)
```

---

## Model Routing

| Route | Primary | Secondary | Max Iter |
|-------|---------|-----------|----------|
| FAST_PATH | sonnet | - | 3 |
| STANDARD (1-4) | minimax-m2.1 | sonnet | 25 |
| STANDARD (5-6) | sonnet | opus | 25 |
| STANDARD (7-10) | opus | sonnet | 25 |

---

## Commands Reference

```bash
# Core
ralph orch "task"         # Full orchestration
ralph gates               # Quality gates
ralph loop "task"         # Loop (25 iter)
ralph compact             # Manual context save

# Memory (v2.49)
ralph memory-search "query"  # Parallel search
ralph fork-suggest "task"    # Find sessions to fork

# Security
ralph security src/       # Security audit
ralph security-loop src/  # Iterative audit

# Worktree
ralph worktree "task"     # Create worktree
ralph worktree-pr <branch> # PR + review

# Context
ralph ledger save         # Save session state
ralph handoff create      # Create handoff
```

---

## Agents (9)

| Agent | Model | Purpose |
|-------|-------|---------|
| `@orchestrator` | opus | Coordinator |
| `@security-auditor` | opus | Security |
| `@debugger` | opus | Bug detection |
| `@code-reviewer` | sonnet | Reviews |
| `@test-architect` | sonnet | Tests |
| `@refactorer` | sonnet | Refactoring |
| `@frontend-reviewer` | sonnet | UI/UX |
| `@docs-writer` | minimax | Docs |
| `@minimax-reviewer` | minimax | Second opinion |

---

## Hooks (29 registered)

| Event Type | Purpose |
|------------|---------|
| SessionStart | Context preservation at startup |
| PreCompact | Save state before compaction |
| PostToolUse | Quality gates after Edit/Write |
| PreToolUse | Safety guards before Bash/Skill |
| UserPromptSubmit | Context warnings, reminders |
| Stop | Session reports |

---

## Ralph Loop Pattern

```
EXECUTE → VALIDATE → Quality Passed?
                          ↓ NO
                      ITERATE (max 25)
                          ↓
                    Back to EXECUTE
```

`VERIFIED_DONE` = plan approved + MUST_HAVE answered + classified + implemented + gates passed + retrospective done

---

## Completion Criteria

| Requirement | Status |
|-------------|--------|
| Smart Memory Search complete | Required |
| Task classified (3 dimensions) | Required |
| MUST_HAVE questions answered | Required |
| Plan approved | Required |
| CORRECTNESS passed (blocking) | Required |
| QUALITY passed (blocking) | Required |
| Retrospective done | Required |

---

## References

| Topic | Documentation |
|-------|---------------|
| Complete Architecture | `ARCHITECTURE_DIAGRAM_v2.49.1.md` |
| Version History | `CHANGELOG.md` |
| Hook Testing | `tests/HOOK_TESTING_PATTERNS.md` |
| Full README | `README.md` |
| Installation | `install.sh` |

---

## Aliases

```bash
rh=ralph rho=orch rhs=security rhb=bugs rhg=gates
mm=mmc mml="mmc --loop 30"
```

---

*Full documentation: See README.md and ARCHITECTURE_DIAGRAM_v2.49.1.md*
