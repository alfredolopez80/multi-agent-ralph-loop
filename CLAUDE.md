# Multi-Agent Ralph v2.48.0

## Multi-Agent Ralph Loop Orchestration

### Primary Commands (Always Available)

| Command | Description |
|---------|-------------|
| `/orchestrator` | **Full workflow** with fast-path for trivial tasks |
| `/loop` | Execute until VERIFIED_DONE with quality gates |
| `/clarify` | Intensive AskUserQuestion (MUST_HAVE + NICE_TO_HAVE) |
| `/gates` | Quality-first validation (quality over consistency) |
| `/adversarial` | Adversarial spec refinement (adversarial-spec) |
| `/retrospective` | Post-task analysis and improvements |
| `/parallel` | Run multiple loops concurrently |
| `/lsp-explore` | Token-free code navigation via LSP |
| `/compact` | Manual context save (extension workaround) |
| `/classify` | 3-dimension task classification |
| `/smart-fork` | Smart memory-driven fork suggestions |
| `/hook-test` | Run behavioral hook tests (38 tests) ← NEW v2.47.3 |

### Orchestration Flow - v2.46 (RLM-Inspired)

**Key v2.46 Changes** (based on RLM paper arXiv:2512.24601v1):
- **Fast-path**: Trivial tasks → 3 steps instead of full workflow
- **3-Dimension Classification**: Complexity + Information Density + Context Requirement
- **Parallel Exploration**: 5 concurrent searches before planning
- **Recursive Decomposition**: Sub-orchestrators for complex tasks (max depth 3)
- **Quality over Consistency**: Style issues don't block, quality does

```
0. EVALUATE        → 3-dimension classification (route to FAST_PATH or STANDARD)
                     └─ FAST_PATH: DIRECT_EXECUTE → MICRO_VALIDATE → DONE (3 steps)
1. CLARIFY         → AskUserQuestion intensively (MUST_HAVE + NICE_TO_HAVE)
1b. GAP-ANALYST    → Pre-implementation gap analysis
1c. PARALLEL_EXPLORE → 5 concurrent searches ← NEW v2.46
2. CLASSIFY        → Complexity 1-10 + Info Density + Context Req ← ENHANCED v2.46
2b. WORKTREE       → Ask user about isolated worktree
3. PLAN            → Design detailed plan (orchestrator analysis)
3b. PERSIST        → Write to .claude/orchestrator-analysis.md
3c. PLAN-STATE     → Initialize plan-state.json (v2.46 schema)
3d. RECURSIVE_DECOMPOSE → Spawn sub-orchestrators if needed ← NEW v2.46
4. PLAN MODE       → EnterPlanMode (reads analysis as foundation)
5. DELEGATE        → Route to model/agent (based on classification)
6. EXECUTE-WITH-SYNC → Nested loop per step (parallel substeps)
   6a. LSA-VERIFY  → Lead Software Architect pre-check
   6b. IMPLEMENT   → Execute (parallel if independent)
   6c. PLAN-SYNC   → Detect drift, patch downstream
   6d. MICRO-GATE  → Per-step quality (3-Fix Rule)
7. VALIDATE        → Quality-first validation ← ENHANCED v2.46
   7a. CORRECTNESS → Meets requirements? (BLOCKING)
   7b. QUALITY     → Security, performance, tests? (BLOCKING)
   7c. CONSISTENCY → Style, patterns? (ADVISORY - not blocking)
   7d. ADVERSARIAL → Dual model (if complexity >= 7)
8. RETROSPECT      → Analyze and improve
```

### Usage Examples

```bash
# Full orchestration for features
/orchestrator Implement user authentication with JWT

# Loop for iterative fixes
/loop "fix all type errors"

# Quality validation (v2.46 - quality over consistency)
/gates
/adversarial "Design a rate limiter service"

# 3-dimension classification
/classify "Implement OAuth for Google, GitHub, Microsoft"
```

Orchestration with fast-path detection, parallel exploration, recursive decomposition, quality-first validation, and automatic context preservation.

> **Historical versions**: See [CHANGELOG.md](./CHANGELOG.md) for v2.19-v2.45 details.

## v2.48.0 Security Scanning (NEW)

**Stage 2.5 SECURITY** added to quality gates - automatic security scanning on every code change.

### Features

| Feature | Description |
|---------|-------------|
| **semgrep SAST** | Static Application Security Testing for 30+ languages |
| **gitleaks** | Secret detection (API keys, passwords, tokens) |
| **Graceful Degradation** | Works without tools, shows SKIP + one-time install hint |
| **Timeout Protection** | 5s max for semgrep to prevent blocking |
| **20 Unit Tests** | Comprehensive test coverage in `tests/test_security_scan.py` |

### Quality Gates Flow (v2.48)

```
Stage 1: CORRECTNESS → Syntax errors (BLOCKING)
Stage 2: QUALITY     → Type errors (BLOCKING)
Stage 2.5: SECURITY  → semgrep + gitleaks (BLOCKING) ← NEW
Stage 3: CONSISTENCY → Linting (ADVISORY - not blocking)
```

### Installation

```bash
# Install security tools (one-time)
./scripts/install-security-tools.sh

# Check status
./scripts/install-security-tools.sh --check

# Verify tests
python -m pytest tests/test_security_scan.py -v
```

### Security Rules

| Tool | Config | Detects |
|------|--------|---------|
| semgrep | `p/python`, `p/javascript`, etc. | Command injection, SQL injection, XSS, insecure crypto |
| gitleaks | default rules | API keys, passwords, tokens, credentials |

### Graceful Degradation

If tools not installed:
1. First run: Shows one-time advisory tip to install
2. Subsequent runs: Silently skips (logs SKIP)
3. Never blocks workflow due to missing tools

---

## v2.47.3 Comprehensive Hook Testing

**38 behavioral tests** validate that hooks work correctly - not just code presence.

### Test Categories

| Category | Tests | Purpose |
|----------|-------|---------|
| JSON Output | 7 | Hook ALWAYS returns valid `{"decision": "continue"}` |
| Command Injection | 4 | Shell metacharacters blocked |
| Path Traversal | 2 | Symlinks resolved, paths validated |
| Race Conditions | 4 | umask 077, noclobber, chmod 700 |
| Edge Cases | 6 | Unicode, long inputs, null bytes |
| Error Handling | 3 | Exit 0 always, stderr clean |
| Regressions | 5 | Past bugs don't return |
| Performance | 3 | Hooks complete in <5s |

### Running Tests

```bash
# All hook tests
python -m pytest tests/test_hooks_comprehensive.py -v

# Codex CLI independent review
codex exec -m gpt-5.2-codex --sandbox read-only \
  --config model_reasoning_effort=high \
  "review ~/.claude/hooks/<hook>.sh --focus security" 2>/dev/null
```

### Known Limitations (Documented)

| ID | Severity | Issue |
|----|----------|-------|
| SMMS-001 | HIGH | ERR trap needed for guaranteed JSON output |
| SMMS-002 | MEDIUM | Full JSON escaping needed in additionalContext |
| SMMS-003 | MEDIUM | Atomic file write (temp+mv) needed |
| SMMS-005 | LOW | Input size limit needed (currently unbounded) |

---

## v2.47 Smart Memory-Driven Orchestration

Based on @PerceptualPeak Smart Forking concept:
> "Why not utilize the knowledge gained from your hundreds/thousands of other Claude code sessions? Don't let that valuable context go to waste!!"

### Smart Memory Search (Step 0b)

**NEW**: Before every orchestration, search ALL memory sources in **PARALLEL**:

```
┌────────────────────────────────────────────────────────────────┐
│              SMART MEMORY SEARCH (PARALLEL)                    │
├────────────────────────────────────────────────────────────────┤
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│   │claude-mem│ │ memvid   │ │ handoffs │ │ ledgers  │        │
│   └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘        │
│        │ PARALLEL   │ PARALLEL   │ PARALLEL   │ PARALLEL      │
│        └────────────┴────────────┴────────────┘               │
│                         ↓                                      │
│              .claude/memory-context.json                       │
│              ├── past_successes                                │
│              ├── past_errors                                   │
│              ├── recommended_patterns                          │
│              └── fork_suggestions (top 5)                      │
└────────────────────────────────────────────────────────────────┘
```

### New CLI Commands (v2.47)

| Command | Description |
|---------|-------------|
| `ralph memory-search "query"` | Search all memory sources in parallel |
| `ralph fork-suggest "task"` | Find relevant sessions to fork from |
| `ralph memory-stats` | Show memory statistics across all sources |

### New Hook (v2.47)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `smart-memory-search.sh` | PreToolUse (Task) | Parallel memory search before orchestration |

### Memory Sources

| Source | Content | Speed |
|--------|---------|-------|
| **claude-mem MCP** | Semantic observations | Fast |
| **memvid** | Vector-encoded context | Sub-5ms |
| **handoffs** | Session snapshots (30 days) | Fast |
| **ledgers** | Session continuity data | Fast |

### Key Principles

1. **PARALLEL EXECUTION**: Memory searches run concurrently, not sequentially
2. **LEARN FROM HISTORY**: Past successes inform current implementation
3. **AVOID PAST ERRORS**: Historical failures prevent repeat mistakes
4. **SMART FORKING**: Suggest best session to fork from

### Updated Orchestration Flow (v2.47)

```
0. EVALUATE
   0a. 3-Dimension Classification (v2.46)
   0b. SMART MEMORY SEARCH (v2.47 NEW) ← Parallel memory search
       └─ Results in .claude/memory-context.json
1. CLARIFY (Memory-Enhanced)
   └─ Check memory context for similar implementations
...
8. RETROSPECT
   └─ Save learnings to memory for future sessions
```

---


## v2.46 RLM-Inspired Enhancements (NEW)

### 3-Dimension Classification (RLM Paper)

| Dimension | Values | Purpose |
|-----------|--------|---------|
| **Complexity** | 1-10 | Scope, risk, ambiguity |
| **Information Density** | CONSTANT / LINEAR / QUADRATIC | How answer scales with input |
| **Context Requirement** | FITS / CHUNKED / RECURSIVE | Whether decomposition needed |

### Workflow Routing

| Density | Context | Complexity | → Route |
|---------|---------|------------|---------|
| CONSTANT | FITS | 1-3 | **FAST_PATH** (3 steps) |
| CONSTANT | FITS | 4-10 | STANDARD |
| LINEAR | CHUNKED | ANY | **PARALLEL_CHUNKS** |
| QUADRATIC | ANY | ANY | **RECURSIVE_DECOMPOSE** |
| ANY | RECURSIVE | ANY | **RECURSIVE_DECOMPOSE** |

### New Hooks (v2.46)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `fast-path-check.sh` | PreToolUse (Task) | Detect trivial tasks → FAST_PATH |
| `parallel-explore.sh` | PostToolUse (Task) | Launch 5 concurrent exploration tasks |
| `recursive-decompose.sh` | PostToolUse (Task) | Trigger sub-orchestrators for complex tasks |
| `quality-gates-v2.sh` | PostToolUse (Edit/Write) | Quality-first validation (consistency advisory) |

### Quality-First Validation

```
Stage 1: CORRECTNESS → Syntax errors (BLOCKING)
Stage 2: QUALITY     → Type errors (BLOCKING)
Stage 3: CONSISTENCY → Linting (ADVISORY - not blocking)
```

### Model Routing by Route

| Route | Primary | Secondary | Max Iter |
|-------|---------|-----------|----------|
| FAST_PATH | sonnet | - | 3 |
| STANDARD (1-4) | minimax-m2.1 | sonnet | 25 |
| STANDARD (5-6) | sonnet | opus | 25 |
| STANDARD (7-10) | opus | sonnet | 25 |
| PARALLEL_CHUNKS | sonnet (chunks) | opus (aggregate) | 15/chunk |
| RECURSIVE | opus (root) | sonnet (sub) | 15/sub |

### v2.46 Metrics Targets

| Metric | v2.45 | v2.46 Target |
|--------|-------|--------------|
| Trivial task time | 5-10 min | **1-2 min** |
| Complex task success | 70% | **85%** |
| Plan survival rate | 80% | **95%** |
| Token usage | 100% | **70%** |

---

## v2.45 Lead Software Architect + Plan-Sync Integration

### The LSA Philosophy

**"Plans never survive implementation. But with Plan-Sync, we catch drift and maintain consistency."**

v2.45 introduces a comprehensive plan execution tracking system inspired by:
- **RLM Paper**: Context as queryable variable (plan-state.json)
- **gmickel/flow-next**: Plan-Sync pattern for drift detection
- **Spawn Architecture**: Continuous validation against plan

### New Components (v2.45)

| Component | Purpose |
|-----------|---------|
| **Lead Software Architect (LSA)** | Architecture guardian - verifies each step against ARCHITECTURE.md |
| **Plan-Sync** | Catches drift when implementation diverges, patches downstream specs |
| **Gap-Analyst** | Pre-implementation gap analysis for missing requirements |
| **Quality-Auditor** | 6-phase pragmatic code audit |
| **Adversarial-Plan-Validator** | Cross-validation between Claude Opus and Codex GPT-5.2 |
| **plan-state.json** | Structured tracking of spec vs actual implementation |

### Plan-State Schema

```json
{
  "plan_id": "uuid",
  "task": "description",
  "classification": {
    "complexity": 7,
    "model_routing": "opus",
    "adversarial_required": true
  },
  "steps": [
    {
      "id": "1",
      "title": "Create auth service",
      "status": "pending|in_progress|completed|verified",
      "spec": {
        "file": "src/auth.ts",
        "exports": ["authService", "authenticate"],
        "signatures": {"authenticate": "(creds: Credentials) => Promise<Result>"}
      },
      "actual": {
        "exports": [...],
        "updated_at": "timestamp"
      },
      "drift": {
        "detected": false,
        "items": [],
        "needs_sync": false
      },
      "lsa_verification": {
        "pre_check": {"passed": true},
        "post_check": {"passed": true}
      }
    }
  ],
  "loop_state": {
    "current_iteration": 0,
    "max_iterations": 25,
    "validate_attempts": 0
  }
}
```

### Nested Loop Architecture (v2.45)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EXTERNAL RALPH LOOP (max 25 iter)                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│    For EACH step in plan:                                           │
│    ┌─────────────────────────────────────────────────────────┐     │
│    │           INTERNAL PER-STEP LOOP (3-Fix Rule)          │     │
│    │                                                         │     │
│    │   LSA-VERIFY → IMPLEMENT → PLAN-SYNC → MICRO-GATE      │     │
│    │       ↑                                   │             │     │
│    │       └──── retry if MICRO-GATE fails ───┘             │     │
│    │                  (max 3 attempts)                       │     │
│    └─────────────────────────────────────────────────────────┘     │
│                              ↓                                      │
│    After ALL steps: VALIDATE (Gates + Adversarial-Plan)            │
│                              ↓                                      │
│    If VALIDATE fails → iterate back to step with issues            │
│                              ↓                                      │
│    If VALIDATE passes → RETROSPECT → VERIFIED_DONE                 │
└─────────────────────────────────────────────────────────────────────┘
```

### New CLI Commands (v2.45)

```bash
# Plan-State Management
ralph plan init "task" [complexity] [model]  # Initialize plan state
ralph plan status                            # Show plan status
ralph plan add-step <id> <title> [file]      # Add step
ralph plan start <id>                        # Mark in_progress
ralph plan complete <id>                     # Mark completed
ralph plan verify <id>                       # Mark verified (post-LSA)
ralph plan sync                              # Check drift
ralph plan clear                             # Clear (archives first)

# LSA & Validation
ralph lsa [target]                           # Architecture verification
ralph gap "task"                             # Gap analysis
ralph audit [target]                         # Quality audit
ralph adversarial-plan                       # Cross-validate plan
```

### New Hooks (v2.45.1)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `auto-plan-state.sh` | PostToolUse (Write) | Auto-creates plan-state.json when orchestrator-analysis.md is written |
| `plan-state-init.sh` | CLI | Initialize/manage plan-state.json |
| `lsa-pre-step.sh` | PreToolUse (Edit/Write) | LSA verification before implementation |
| `plan-sync-post-step.sh` | PostToolUse (Edit/Write) | Drift detection after implementation |

### Adversarial Plan Validation

The final gate before VERIFIED_DONE uses dual-model validation:

```
┌──────────────────┐         ┌──────────────────┐
│   CLAUDE OPUS    │ ◄─────► │   CODEX GPT-5.2  │
│                  │ DEBATE  │                  │
│  • Reviews impl  │         │  • Reviews impl  │
│  • Checks specs  │         │  • Checks specs  │
│  • Finds gaps    │         │  • Finds gaps    │
└────────┬─────────┘         └────────┬─────────┘
         │    ┌───────────────┐       │
         └───►│   RECONCILE   │◄──────┘
              │               │
              │ • Merge findings
              │ • Resolve conflicts
              │ • Final verdict
              └───────┬───────┘
                      ↓
            ┌─────────────────┐
            │ COVERAGE REPORT │
            │  100% Required  │
            └─────────────────┘
```

**Verdicts**:
| Verdict | Coverage | Action |
|---------|----------|--------|
| PASS | 100% | Proceed to RETROSPECT → VERIFIED_DONE |
| CONDITIONAL_PASS | >90% | Fix blocking issues, re-validate |
| FAIL | <90% | Return to EXECUTE with gap list |

### New Agents (v2.45)

| Agent | Model | Purpose |
|-------|-------|---------|
| `@lead-software-architect` | opus | Architecture verification |
| `@plan-sync` | sonnet | Drift detection & downstream patching |
| `@gap-analyst` | opus | Pre-implementation gap analysis |
| `@quality-auditor` | opus | 6-phase pragmatic audit |
| `@adversarial-plan-validator` | opus | Dual-model plan validation |

---

## v2.44 Plan Mode Integration + Context Management

### Plan Mode Integration (NEW)

**Problem Solved**: The orchestrator's exhaustive analysis was being discarded when `EnterPlanMode` was called, causing Claude Code to generate a completely new plan from scratch.

**Solution**: Filesystem-based handoff pattern:

```
Steps 0-3: Orchestrator Analysis (exhaustive)
    ↓
Step 3b: Write analysis to .claude/orchestrator-analysis.md
    ↓
Step 4: EnterPlanMode → Claude Code READS file → Refines plan (not from scratch)
    ↓
Steps 5-8: Execute, Validate, Retrospect
```

**Key Components**:
| Component | Purpose |
|-----------|---------|
| `.claude/orchestrator-analysis.md` | Analysis file written by orchestrator |
| `~/.claude/rules/plan-mode-orchestrator.md` | Rule that instructs Plan Mode to read analysis |
| `~/.claude/hooks/plan-analysis-cleanup.sh` | Cleans up after ExitPlanMode (backs up to `~/.ralph/analysis/`) |

**Benefits**:
- ONE unified plan instead of conflicting orchestrator + Claude Code plans
- User clarifications preserved through Plan Mode
- Analysis file automatically cleaned up after ExitPlanMode

---

### Context Management for Extensions + Worktrees

**Problem Solved**: GitHub issue #15021 - Claude Code hooks don't fire reliably in VSCode/Cursor extensions, causing context loss on compaction.

### New Features (v2.44)

| Feature | Description |
|---------|-------------|
| **Environment Detection** | Detects CLI vs VSCode/Cursor and adjusts behavior |
| **Rich Context Extraction** | `context-extractor.py` captures git, progress, transcript |
| **Manual Compact** | `/compact` skill + `ralph compact` for extensions |
| **Worktree Symlinks** | Auto-symlink node_modules, .venv, etc. to main project |
| **Native Worktree Fallback** | Works without WorkTrunk (wt) installed |
| **Operation Counter** | Estimates context usage when /context fails |

### New CLI Commands (v2.44)

```bash
# Context Management (Extension Workaround)
ralph compact              # Manual context save (triggers pre-compact hook)
ralph env                  # Show environment detection + feature flags

# Worktree Enhancements
ralph worktree "task"      # Now with symlinks + native fallback
ralph worktree-sync-deps   # Repair dependency symlinks
```

### Extension Mode Detection

| Environment | Detection Method | Capability |
|-------------|------------------|------------|
| CLI | `CLAUDE_CODE_ENTRYPOINT=cli` | Full |
| VSCode | `VSCODE_PID` or entrypoint | Limited |
| Cursor | `CURSOR_PID` or `TERM_PROGRAM` | Limited |
| Unknown | Fallback | Limited (conservative) |

### Context Warning Improvements

When context reaches 80%+, warnings now include environment-specific recommendations:

```
⚠️  Context at 82%

📌 Extension mode detected (vscode):
  • Use /compact skill to manually save context
  • Or run: ralph compact
```

### Worktree Dependency Symlinks

New worktrees automatically symlink dependency directories:

| Package Manager | Symlinked Directory |
|-----------------|---------------------|
| npm/yarn/pnpm/bun | `node_modules` |
| cargo | `target` |
| poetry/pip | `.venv`, `venv` |

This saves disk space and avoids re-installing dependencies.

---

## v2.43 Context Engineering & LSP Integration

Based on Claude Code v2.0.71-v2.1.9 analysis (43+ improvements).

### New Features (v2.43)

| Feature | Description |
|---------|-------------|
| **claude-mem Integration** | SessionStart hook now integrates with claude-mem MCP for semantic context |
| **PreToolUse additionalContext** | Task calls receive session context automatically |
| **LSP-Explore Skill** | Token-free code navigation (90%+ savings) |
| **mcpToolSearchMode: auto:10** | Deferred MCP tool loading until 10% context usage |
| **Keybindings** | Custom shortcuts for orchestration commands |
| **Worktree Dashboard** | `ralph worktree-dashboard` for parallel work visibility |
| **tldr .gitignore** | Auto-adds `.tldr/` to .gitignore on `ralph tldr warm` |

### New Hooks (v2.43)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `inject-session-context.sh` | PreToolUse (Task) | Inject goal/progress into subagent context |
| Enhanced `session-start-ledger.sh` | SessionStart | claude-mem hints + context engineering tips |

### LSP Integration (90%+ Token Savings)

Use LSP tools for efficient code navigation without reading files:

```yaml
# Token comparison
Read entire file:     ~2000 tokens
LSP hover:            ~50 tokens (96% savings)
LSP go-to-definition: ~100 tokens (95% savings)
LSP find-references:  ~150 tokens (92% savings)
```

**Hybrid Pattern: llm-tldr + LSP**
1. `ralph tldr semantic "authentication"` → Find candidates
2. LSP go-to-definition → Navigate to implementation
3. LSP find-references → Understand usage
4. Read ONLY specific functions needed

### Codex CLI Security (v2.43)

**IMPORTANT**: `--yolo` replaced with `--full-auto` for safer defaults.

| Flag | Behavior | Use Case |
|------|----------|----------|
| `--full-auto` | Auto-approve workspace writes only | Default for all Codex calls |
| `--profile <name>` | Use security profile | `security-audit`, `code-review` |
| `CODEX_ALLOW_DANGEROUS=true` | Override safety gates | Trusted environments only |

### Git Operations Policy

- **MANDATORY**: Use `git` CLI or GitHub CLI (`gh`) for all git operations
- **DO NOT USE**: GitHub MCP or similar for git operations
- **Alternatives**: `mcp__gordon__git` for Gordon MCP users

### New CLI Commands (v2.43)

```bash
# Worktree visibility
ralph worktree-dashboard    # Show all worktrees with status

# Enhanced tldr (auto-adds .gitignore)
ralph tldr warm .           # Now auto-adds .tldr/ to .gitignore

# VERSION Markers (v2.43)
ralph add-version-markers            # Add VERSION: 2.43.0 to all config files
ralph add-version-markers --check    # Verify current versions
ralph add-version-markers --global   # Process global ~/.claude/ only

# Config Cleanup (v2.43)
ralph cleanup-project-configs        # Remove redundant local settings.json
```

### StatusLine Git Enhancement (v2.43)

Shows current branch/worktree in StatusLine:
- `⎇ main*` - Branch with uncommitted changes
- `⎇ feature ↑3` - Branch with 3 unpushed commits
- `⎇ fix-123 🌳worktree` - Worktree indicator

Configured via wrapper script: `~/.claude/scripts/statusline-git.sh`

### Configuration (v2.43)

New settings in `~/.claude/settings.json`:
```json
{
  "mcpToolSearchMode": "auto:10",
  "plansDirectory": "~/.ralph/plans/"
}
```

New keybindings in `~/.claude/keybindings.json`:
```json
{
  "ctrl+shift+o": "/orchestrator",
  "ctrl+shift+g": "/gates",
  "ctrl+shift+l": "/lsp-explore"
}
```

---

## v2.42 Context Preservation & Review Improvements

Based on analysis of [planning-with-files](https://github.com/OthmanAdi/planning-with-files) and [superpowers](https://github.com/obra/superpowers).

### New Hooks (v2.42)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `stop-verification.sh` | Stop | Verify completion checklist before session end |
| `auto-save-context.sh` | PostToolUse | Auto-save context every 5 operations |

### Improved Skills (v2.42)

| Skill | Improvement |
|-------|-------------|
| `/orchestrator` | **Full v2.42 Integration**: Step 1b Socratic, Step 6 Two-Stage, 3-Fix Rule in Anti-Patterns |
| `/adversarial` | **Two-Stage Review**: Stage 1 (spec compliance) → Stage 2 (code quality) |
| `systematic-debugging` | **3-Fix Rule Enforcement**: Mandatory escalation after 3 failed attempts |
| `/clarify` | **Socratic Design**: Present 2-3 alternatives with trade-offs |

### Stop Verification Checklist

Before session ends, the hook verifies:
- [ ] All TODOs completed (from progress.md)
- [ ] No uncommitted git changes
- [ ] No recent lint errors
- [ ] No recent test failures

### Auto-Save Configuration

```bash
export RALPH_AUTO_SAVE_INTERVAL=5  # Save every N operations (default: 5)
```

Context snapshots stored in `~/.ralph/state/context-snapshot-*.md` (keeps last 10).

### Two-Stage Review Process

```
Stage 1: Spec Compliance          Stage 2: Code Quality
├── Meets requirements?           ├── Follows patterns?
├── Covers use cases?             ├── Performance OK?
├── Respects constraints?         ├── Security applied?
└── Handles edge cases?           └── Tests adequate?
```

**Exit Stage 1 before proceeding to Stage 2.**

---

## v2.41 Context Engineering

### New Features

| Feature | Description |
|---------|-------------|
| **`context: fork`** | 5 skills now use isolated context (orchestrator, bugs, refactor, prd, ast-search) |
| **progress.md** | Auto-tracking of tool results/errors via `progress-tracker.sh` |
| **PIN/Lookup Tables** | `/pin` skill improves search tool hit rate with keywords |
| **Session Refresh Hints** | PreCompact hook generates recommendations for fresh context |

### New Commands

| Command | Description |
|---------|-------------|
| `/pin init` | Create `.claude/pins/readme.md` from template |
| `/pin show` | Show current lookup table |
| `/pin add` | Add area/keywords/files entry |
| `/pin scan` | Scan project and suggest keywords |

### Storage Structure

```
.claude/
├── pins/
│   └── readme.md          # Lookup table for search optimization
├── progress.md            # Auto-generated by progress-tracker.sh
└── settings.local.json    # Project permissions
```

## v2.40 Features

### Integration Testing Suite (26 tests)

Comprehensive pytest suite for validating v2.40 integration:

```bash
# Run all v2.40 tests
pytest tests/test_v2_40_integration.py -v

# Quick bash validation (23 checks)
ralph validate-integration
```

**Tests cover**:
- Skills discovery and frontmatter validation
- llm-tldr SessionStart hook registration
- ultrathink skill with model: opus
- Hooks configuration and executability
- Configuration hierarchy (global vs local)
- OpenCode synchronization
- Ralph backups and context preservation

### OpenCode Synchronization (v2.40)

Sync Claude Code configuration to OpenCode with naming conversion:

```bash
ralph sync-to-opencode           # Sync ~/.claude/ → ~/.config/opencode/
ralph sync-to-opencode --dry-run # Preview changes
```

**Mapping** (Claude plural → OpenCode singular):
- `~/.claude/skills/` → `~/.config/opencode/skill/`
- `~/.claude/agents/` → `~/.config/opencode/agent/`
- `~/.claude/commands/` → `~/.config/opencode/command/`

### LLM-TLDR Integration (95% Token Savings)

Token-efficient code analysis for exploring large codebases:

| Feature | Description |
|---------|-------------|
| **95% Token Savings** | 21,000 tokens → 175 tokens for function context |
| **155x Faster Queries** | Daemon mode with 100ms latency |
| **5-Layer Analysis** | AST → Call Graph → CFG → DFG → PDG |
| **16 Languages** | Python, TypeScript, Go, Rust, Java, C, C++, etc. |

**Commands**:
```bash
ralph tldr warm .              # Build index (first time)
ralph tldr semantic "query" .  # Semantic code search
ralph tldr context function .  # LLM-optimized context
ralph tldr impact function .   # Call graph analysis
ralph tldr structure src/      # Codebase structure
```

**Orchestrator Integration** (via /tldr-context skill):
- **Step 1 (CLARIFY)**: `tldr semantic` finds existing functionality
- **Step 3 (PLAN)**: `tldr impact` shows change blast radius
- **Step 5 (EXECUTE)**: `tldr context` prepares minimal context for subagents
- **Step DEBUG**: `tldr slice` for root cause analysis

**Installation**: `pip install llm-tldr`

## v2.36 Features

### Commands → Skills Unification (Claude Code v2.1.3)

All commands migrated to global skills (`~/.claude/skills/`):
- **Hot-reload**: Skills auto-reload without restart
- **Progressive Disclosure**: ~100 words in context until activated
- **`context: fork`**: Available for isolation (gates, adversarial, parallel)
- **185+ skills** available globally

### Context Preservation (100% Automatic)

| Event | Trigger | Action |
|-------|---------|--------|
| Session start | SessionStart hook | Loads ledger + handoff |
| Pre-compaction | PreCompact hook | Saves ledger + handoff |
| Post-compaction | SessionStart:compact | Restores with claude-mem hints |
| Context 80%+ | claude-hud | Yellow warning |
| Context 85%+ | claude-hud | Red warning |

**Threshold updated**: 60%→80% (aligned with Claude Code v2.1.0 auto-compact)

### Agent Hooks (v2.36)

5 agents now have frontmatter hooks for logging:
- `@security-auditor` - Audit logging
- `@orchestrator` - Orchestration tracking
- `@code-reviewer` - Review metrics
- `@test-architect` - Coverage tracking
- `@debugger` - Debug session logging

Logs: `~/.ralph/logs/`

**One-time setup**: `ralph setup-context-engine`

### Global Hooks Inheritance Pattern

Projects inherit hooks from `~/.claude/settings.json` automatically:

```
GLOBAL ~/.claude/
├── agents/            (27 agents)
├── commands/          (33 commands)
├── hooks/             (17 hooks)
└── settings.json      (6 hook types - INHERITED)

PROJECT .claude/
├── agents/            (synced from global)
├── commands/          (synced from global)
├── hooks/             (synced from global)
├── settings.local.json (permissions only)
└── NO settings.json   (inherits global)
```

**Benefits**: Zero maintenance, consistent behavior, updates apply everywhere.

**Commands**:
```bash
ralph sync-global                # Sync repo to global
ralph cleanup-project-settings   # Remove redundant settings.json
```

## Anthropic Best Practices

<investigate_before_answering>
Never speculate about code you have not opened. Read files BEFORE answering.
</investigate_before_answering>

<use_parallel_tool_calls>
Make independent tool calls in parallel, not sequentially.
</use_parallel_tool_calls>

<default_to_action>
Implement changes rather than only suggesting them.
</default_to_action>

<avoid_overengineering>
Only make changes that are directly requested. Keep solutions simple.
</avoid_overengineering>

## Ralph Loop Pattern (CRITICAL)

ALL tasks MUST follow this pattern:

```
EXECUTE → VALIDATE → Quality Passed? → YES → VERIFIED_DONE
                          ↓ NO
                      ITERATE (max 25)
                          ↓
                    Back to EXECUTE
```

**Iteration Limits**:
| Model | Max Iterations |
|-------|----------------|
| Claude (Sonnet/Opus) | 25 |
| MiniMax M2.1 | 50 |
| MiniMax-lightning | 100 |

**Quality Hooks (v2.46)**:
- `quality-gates-v2.sh` → Post-Edit/Write (quality-first, consistency advisory)
- `fast-path-check.sh` → Pre-Task (trivial task detection)
- `git-safety-guard.py` → Pre-Bash (validates git commands)

## Subagent Configuration

```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"  # MANDATORY - Haiku causes infinite retries
  run_in_background: true
```

**Why Sonnet + MiniMax?**
- Sonnet (60% cost): Manages subagents reliably
- MiniMax (8% cost): Second opinion with Opus-level quality
- Haiku: NOT recommended (30%+ rework rate)

## Mandatory Flow - v2.46 (RLM-Inspired)

```
0. EVALUATE     → 3-dimension classification (FAST_PATH vs STANDARD) ← v2.46
   └─ FAST_PATH → DIRECT_EXECUTE → MICRO_VALIDATE → DONE (3 steps)
1. /clarify     → AskUserQuestion (MUST_HAVE + NICE_TO_HAVE)
1b. GAP-ANALYST → Pre-implementation gap analysis
1c. PARALLEL_EXPLORE → 5 concurrent searches ← NEW v2.46
2. /classify    → Complexity + Info Density + Context Req ← v2.46
2b. WORKTREE    → Ask about worktree isolation
3. PLAN         → Design detailed plan (orchestrator analysis)
3b. PERSIST     → Write to .claude/orchestrator-analysis.md
3c. PLAN-STATE  → Initialize plan-state.json (v2.46 schema)
3d. RECURSIVE_DECOMPOSE → Spawn sub-orchestrators if needed ← v2.46
4. PLAN MODE    → EnterPlanMode (reads analysis as foundation)
5. @orchestrator → Delegate to subagents
6. EXECUTE-WITH-SYNC → LSA-VERIFY → IMPLEMENT → PLAN-SYNC → MICRO-GATE
7. VALIDATE     → CORRECTNESS (block) + QUALITY (block) + CONSISTENCY (advisory)
8. /retrospective → Propose improvements
→ VERIFIED_DONE
```

## Quick Commands

```bash
# Core
ralph orch "task"         # Full orchestration
ralph gates               # Quality gates
ralph loop "task"         # Loop (25 iter)

# Review
ralph security src/       # Security audit
ralph bugs src/           # Bug hunting
ralph adversarial "Design a rate limiter service"

# Git Worktree
ralph worktree "task"     # Create worktree
ralph worktree-pr <branch> # PR + review
ralph worktree-dashboard  # Show all worktrees (v2.43)

# Context
ralph ledger save         # Save session state
ralph ledger load         # Load ledger
ralph handoff create      # Create handoff

# Sync & Maintenance (v2.43)
ralph sync-global                 # Sync to ~/.claude/ AND ~/.local/bin/ralph
ralph sync-to-projects            # Sync to all projects
ralph add-version-markers         # Add VERSION markers
ralph cleanup-project-configs     # Remove redundant configs
```

## Agents (9)

```bash
# Critical (Opus)
@orchestrator       # Coordinator
@security-auditor   # Security
@debugger           # Bug detection

# Implementation (Sonnet)
@code-reviewer      # Code reviews
@test-architect     # Test generation
@refactorer         # Refactoring
@frontend-reviewer  # UI/UX

# Cost-effective (MiniMax - 8%)
@docs-writer        # Documentation
@minimax-reviewer   # Second opinion
```

## Hook Event Types (6)

| Hook | Purpose |
|------|---------|
| SessionStart | Context preservation at startup |
| PreCompact | Save state before compaction |
| PostToolUse | Quality gates after Edit/Write |
| PreToolUse | Safety guards before Bash/Skill |
| UserPromptSubmit | Context warnings, reminders |
| Stop | Session reports |

## Aliases

```bash
rh=ralph rho=orch rhs=security rhb=bugs rhg=gates
mm=mmc mml="mmc --loop 30"
```

## Completion

`VERIFIED_DONE` = plan approved + MUST_HAVE answered + classified + implemented + gates passed + adversarial passed (if critical) + retrospective done

## v2.42 Retrospective Improvements (from @claudecoders tweet)

Based on Claude Code official prompt structure (2026-01-13):

### Self-Identification Guidelines
- Claude should NOT refer to itself as "Claude Code" unless directly asked
- Claude runs on top of Claude Code and Claude Agent SDK, but IS NOT Claude Code
- Focus on user-facing capabilities, not implementation details

### Model Versions Update
Update model references to latest versions:
| Model | Current | Latest Available |
|-------|---------|------------------|
| Opus | (not specified) | `claude-opus-4-5-20251101` |
| Sonnet | sonnet | `claude-sonnet-4-5-20250929` |
| Haiku | haiku | `claude-haiku-4-5-20251001` |

### Security Sandbox Pattern
Claude Code runs in a lightweight Linux VM providing **secure sandbox** for code execution. Consider:
- Adding sandbox validation for sensitive operations
- Documenting workspace isolation behavior
- Implementing controlled access patterns for workspace folders

### Product Context (Optional)
When users ask about Claude/Anthropic products, Claude can mention:
- Claude Code (command line tool for agentic coding)
- Claude for Chrome (browsing agent) - beta
- Claude for Excel (spreadsheet agent) - beta
- API and developer platform access

**Source**: https://x.com/claudecoders/status/2010895731549487409
