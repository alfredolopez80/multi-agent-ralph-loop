# Changelog

All notable changes to Multi-Agent Ralph Wiggum are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.43.0] - 2026-01-16

### Added (Context Engineering & LSP Integration)

Based on Claude Code v2.0.71-v2.1.9 analysis (43+ improvements).

#### StatusLine Git Enhancement (NEW)
- **Wrapper script pattern**: `~/.claude/scripts/statusline-git.sh` extends claude-hud without modifying plugin
- **Branch indicator**: Shows `⎇ main*` with change indicator (`*` for uncommitted changes)
- **Worktree detection**: Shows `🌳worktree-name` when in a git worktree
- **Unpushed commits**: Shows `↑N` for N unpushed commits
- **Plugin-resilient**: Survives claude-hud plugin updates (wrapper pattern)

#### VERSION Markers System (NEW)
- **379 files processed**: 88 project + 291 global config files now have `# VERSION: 2.43.0`
- **Tracking script**: `scripts/add-version-markers.sh` for automated versioning
- **CLI integration**: `ralph add-version-markers` (aliases: `version-markers`, `avm`)
- **Check mode**: `ralph add-version-markers --check` validates current versions

#### Config Cleanup (NEW)
- **Global inheritance**: Projects now inherit from `~/.claude/settings.json` automatically
- **Cleanup command**: `ralph cleanup-project-configs` removes redundant local configs
- **Safer defaults**: `--yolo` renamed to `--auto-approve` (backward compatible)

#### Context Preservation (claude-mem Integration)
- **SessionStart hook enhanced**: Now integrates with claude-mem MCP for semantic context retrieval
- **PreToolUse additionalContext**: Task calls automatically receive session goal and progress context
- **3-layer workflow**: search → timeline → get_observations for efficient memory retrieval

#### LSP Integration (90%+ Token Savings)
- **New `/lsp-explore` skill**: Token-free code navigation via Language Server Protocol
- **Hybrid pattern**: Combine llm-tldr semantic search with LSP navigation
- **Token comparison**: LSP hover ~50 tokens vs Read file ~2000 tokens (96% savings)

#### MCP Optimization
- **mcpToolSearchMode: auto:10**: Deferred MCP tool loading until 10% context usage
- **plansDirectory**: Configurable plans storage at `~/.ralph/plans/`

#### Keybindings System
- **New `~/.claude/keybindings.json`**: Custom keyboard shortcuts for commands
- **Quick access**: `ctrl+shift+o` (orchestrator), `ctrl+shift+g` (gates), `ctrl+shift+l` (lsp-explore)

### New Hooks (v2.43)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `inject-session-context.sh` | PreToolUse (Task) | Inject goal/progress into subagent context |

### New Skills (v2.43)

| Skill | Description |
|-------|-------------|
| `/lsp-explore` | Token-free code navigation via LSP (go-to-definition, find-references, hover) |

### New CLI Commands (v2.43)

| Command | Description |
|---------|-------------|
| `ralph worktree-dashboard` | Show status of all worktrees with PR integration |
| `ralph tldr warm` | Now auto-adds `.tldr/` to .gitignore |
| `ralph add-version-markers` | Add VERSION markers to all config files (aliases: `avm`, `version-markers`) |
| `ralph cleanup-project-configs` | Remove redundant local settings.json for global inheritance |

### Modified (v2.43)

#### Codex CLI Security
- **Replaced `--yolo` with `--full-auto`** in all command files
- Updated `bugs.md` and `security-loop.md` for safer defaults
- Added `CODEX_ALLOW_DANGEROUS=true` override documentation

#### Skill System Modernization
- **YAML-style allowed-tools**: Converted from comma-separated to list format
- **Agent field**: Added to critical skills (orchestrator, task-classifier)
- **Hooks in frontmatter**: Skills can now define hooks directly

#### Git Operations Policy
- **MANDATORY**: Use `git` CLI or `gh` for all git operations
- **DO NOT USE**: GitHub MCP or similar for git operations

### Configuration (v2.43)

New settings in `~/.claude/settings.json`:
```json
{
  "mcpToolSearchMode": "auto:10",
  "plansDirectory": "~/.ralph/plans/"
}
```

### Files Changed

| File | Type | Description |
|------|------|-------------|
| `~/.claude/scripts/statusline-git.sh` | NEW | StatusLine wrapper with git branch/worktree info |
| `~/.claude/settings.json` | MODIFIED | statusLine command uses wrapper script |
| `~/.claude/hooks/session-start-ledger.sh` | MODIFIED | claude-mem integration, VERSION: 2.43.0 |
| `~/.claude/hooks/inject-session-context.sh` | NEW | PreToolUse additionalContext |
| `~/.claude/skills/lsp-explore/SKILL.md` | NEW | LSP navigation skill |
| `~/.claude/keybindings.json` | NEW | Custom keyboard shortcuts |
| `scripts/add-version-markers.sh` | NEW | VERSION marker automation |
| `scripts/ralph` | MODIFIED | add-version-markers, cleanup-project-configs, --auto-approve |
| `.claude/commands/bugs.md` | MODIFIED | --yolo → --full-auto |
| `.claude/commands/security-loop.md` | MODIFIED | --yolo → --full-auto, --auto-approve |
| `.claude/skills/orchestrator/SKILL.md` | MODIFIED | v2.43, agent field, hooks |
| `.claude/skills/task-classifier/SKILL.md` | MODIFIED | YAML frontmatter added |
| `CLAUDE.md` | MODIFIED | v2.43 section with new commands |
| `README.md` | MODIFIED | v2.43 highlights, StatusLine, VERSION markers |
| `CHANGELOG.md` | MODIFIED | Full v2.43 changelog |

---

## [2.42.0] - 2026-01-13

### Added (Context Preservation & Review Improvements)

Based on analysis of [planning-with-files](https://github.com/OthmanAdi/planning-with-files) and [superpowers](https://github.com/obra/superpowers):

- **Stop Hook Verification**: Validates completitud before session end (TODOs, git status, lint errors, test failures)
- **2-Action Rule (Auto-Save)**: Auto-saves context every 5 operations to prevent mid-task context loss
- **Two-Stage Review**: `/adversarial` now separates Spec Compliance (Stage 1) from Code Quality (Stage 2)
- **3-Fix Rule Enforcement**: `systematic-debugging` skill now has mandatory escalation after 3 failed fix attempts
- **Socratic Design Exploration**: `/clarify` presents 2-3 alternatives with trade-offs for architectural decisions

### New Hooks (v2.42)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `stop-verification.sh` | Stop | Verify completion checklist before session end |
| `auto-save-context.sh` | PostToolUse(Edit,Write,Bash,Read,Grep,Glob) | Auto-save context every N operations |

### Modified Skills (v2.42)

| Skill | Changes |
|-------|---------|
| `orchestrator/SKILL.md` | Step 1b Socratic Design, Step 6 Two-Stage Review, 3-Fix Rule in Anti-Patterns |
| `adversarial/SKILL.md` | Two-Stage Review (compliance → quality) |
| `systematic-debugging/SKILL.md` | 3-Fix Rule with mandatory escalation message |
| `deep-clarification.md` | Phase 5: Socratic Design Exploration |

### Configuration (v2.42)

- **Auto-save interval**: 5 operations (configurable via `RALPH_AUTO_SAVE_INTERVAL`)
- **Context snapshots**: `~/.ralph/state/context-snapshot-*.md` (keeps last 10)

### Origin

Improvements extracted from:
- **planning-with-files**: Stop Hook, 2-Action Rule (Manus "Context Engineering" pattern)
- **superpowers**: Two-Stage Review, 3-Fix Rule, Socratic Design (95% first-time fix rate)

### Documentation

- Added retrospective analysis: `docs/retrospective/2026-01-13-external-tools-analysis.md`

---

## [2.41.0] - 2026-01-13

### Added (Context Engineering Optimization)

- **`context: fork` for Task() Skills**: 5 skills now use context isolation (orchestrator, bugs, refactor, prd, ast-search)
- **progress-tracker.sh Hook**: PostToolUse hook auto-logs Edit/Write/Bash results to `.claude/progress.md`
- **PIN/Lookup Table System**: New `/pin` skill for managing keyword tables that improve search tool hit rate
- **Session Refresh Hints**: PreCompact hook generates recommendations when context approaches compaction

### New Skill (v2.41)

| Skill | Description |
|-------|-------------|
| `/pin` | Manage PIN/Lookup tables for improved search tool precision |

**Commands**: `/pin init`, `/pin show`, `/pin add`, `/pin scan`, `/pin search`

### New Hook (v2.41)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `progress-tracker.sh` | PostToolUse(Edit,Write,Bash) | Auto-log tool results/errors to `.claude/progress.md` |

### Modified Files (v2.41)

| File | Changes |
|------|---------|
| `~/.claude/skills/orchestrator/SKILL.md` | Added `context: fork` |
| `~/.claude/skills/bugs/SKILL.md` | Added `context: fork` |
| `~/.claude/skills/refactor/SKILL.md` | Added `context: fork` |
| `~/.claude/skills/prd/SKILL.md` | Added `context: fork` |
| `~/.claude/skills/ast-search/SKILL.md` | Added `context: fork` |
| `~/.claude/hooks/session-start-ledger.sh` | Loads project progress.md at session start |
| `~/.claude/hooks/pre-compact-handoff.sh` | Generates session refresh hints |

### New Project Structure (v2.41)

```
.claude/
├── pins/
│   └── readme.md          # Lookup table for search optimization
├── progress.md            # Auto-generated by progress-tracker.sh
└── settings.local.json    # Project permissions
```

### Philosophy (from Ralph Loop creator)

> "Context windows are arrays. The less you use, the less the window needs to slide, the better outcomes you get."

> "Multiple words that describe the functionality increases the hit rates of the search tool."

---

## [2.40.0] - 2026-01-12

### Added (Integration Testing & OpenCode Sync)

- **Integration Test Suite**: 26 pytest tests validate skills, hooks, llm-tldr, and configuration
- **OpenCode Synchronization**: `ralph sync-to-opencode` with naming conversion (plural → singular)
- **Validation Command**: `ralph validate-integration` for quick bash validation (23 checks)

---

## [2.39.0] - 2026-01-12

### Added (Ultrathink Doctrine)

- **Ultrathink Guidance**: All agents and skills now include ultrathink vision + step-by-step workflow
- **Domain-Specific Steps**: Each agent/skill defines how ultrathink applies to its domain

### Modified Files (v2.39)

| File | Changes |
|------|---------|
| `CLAUDE.md` | Updated title to v2.39 |
| `README.md` | Updated latest version summary |
| `.claude/agents/*` | Added ultrathink workflow blocks |
| `.claude/skills/*` | Added ultrathink workflow blocks |
| `.codex/skills/*` | Added ultrathink workflow blocks |

---

## [2.38.0] - 2026-01-11

### Added (Adversarial-Spec Integration)

- **Adversarial-Spec Wrapper**: `/adversarial` now refines specs via adversarial-spec with env-aware models
- **Runtime Detection**: Detect Claude vs OpenCode via command/skill path hints (RALPH_COMMAND_PATH/RALPH_SKILL_PATH)
- **Model Routing**: Claude Code uses `claude-4.5-opus` + `claude-4.5-sonnet` + OpenAI + MiniMax; OpenCode uses OpenAI + MiniMax
- **Docs & Skills Updates**: Updated commands, orchestrator flow, and global skills to reflect spec refinement
- **CLI Help & Examples**: Updated usage to show spec prompts/files

### Modified Files (v2.38)

| File | Changes |
|------|---------|
| `scripts/ralph` | Adversarial-spec runtime selection + model routing |
| `README.md` | Updated adversarial docs and examples |
| `CLAUDE.md` | Updated adversarial step wording |
| `.claude/commands/*` | Updated adversarial references |
| `.claude/agents/orchestrator.md` | Spec refinement in Step 6 |
| `config/models.json` | New adversarial model routing |
| `tests/test_orchestrator_flow.bats` | Updated adversarial expectations |

---

## [2.33.0] - 2026-01-08

### Added (Sentry Observability Integration)

- **Sentry Skills Integration**: 4 official Sentry skills for SDK setup, code review, and validation
- **Skills-First Approach**: 80% of value WITHOUT requiring Sentry MCP configuration
- **Orchestrator Enhancements**: Optional Sentry steps (2c, 6b, 7b) with 100% backward compatibility
- **Context Isolation**: All Sentry skills use `context: fork` for clean execution
- **PR Workflow Integration**: Sentry bot priority in iterate-pr, auto-fix via sentry-code-review
- **Production Correlation**: find-bugs correlates local issues with live Sentry data
- **Anti-Pattern Detection**: deslop removes Sentry over-instrumentation
- **Graceful Degradation**: All Sentry features optional, no breaking changes to v2.32

### New CLI Commands (v2.33)

| Command | Purpose |
|---------|---------|
| `ralph sentry-init [--tracing\|--logging\|--metrics\|--ai\|--all]` | Auto-detect project type and configure Sentry SDK |
| `ralph sentry-validate` | Validate Sentry configuration (DSN, sample rates, etc.) |
| `ralph code-review-sentry <branch>` | Wait for Sentry bot checks, auto-fix issues, iterate until pass |

### New Hooks (v2.33)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `sentry-check-status.sh` | PostToolUse(gh pr *) | Check Sentry CI status, suggest fixes |
| `sentry-correlation.sh` | PostToolUse(gh api *) | Correlate bugs with Sentry production issues |
| `sentry-report.sh` | Stop | Generate Sentry integration summary at session end |

### Enhanced Skills (v2.33)

| Skill | Enhancement | Uses MCP? |
|-------|-------------|-----------|
| **iterate-pr** | Sentry bot priority, auto-fix via sentry-code-review, context: fork | ❌ NO |
| **find-bugs** | Phase 0: Sentry pre-check, Phase 6: production correlation, context: fork | ❌ NO |
| **deslop** | Sentry anti-patterns detection (4 categories + checklist), context: fork | ❌ NO |

### Enhanced Orchestrator Steps (v2.33)

| Step | Enhancement | Optional |
|------|-------------|----------|
| **Step 2c: SENTRY SETUP** | Auto-detect project type (Node.js, Python, Go, Rust), offer SDK configuration | ✅ YES |
| **Step 6b: SENTRY VALIDATION** | Pre-merge Sentry configuration checks (DSN, sample rates, breadcrumbs) | ✅ YES |
| **Step 7b: PR REVIEW (Enhanced)** | Prioritize Sentry bot comments, auto-fix, iterate until pass | ✅ YES |

### Settings & Permissions (v2.33)

**New Permissions**:
- `Bash(gh pr *)` - For PR operations
- `Bash(gh api *sentry*)` - For Sentry API queries
- `Bash(gh api repos/*/pulls/*/comments)` - For PR comment fetching
- `Bash(sentry-cli *)` - For Sentry CLI operations

**New Hooks Configuration**:
- Added `Stop` hook section with sentry-report.sh
- Added skill-level PostToolUse hooks for iterate-pr, find-bugs (via frontmatter)

### Modified Files (v2.33)

| File | Changes | Lines Modified |
|------|---------|----------------|
| `~/.claude/agents/orchestrator.md` | Added Steps 2c, 6b, enhanced 7b | +100 lines |
| `scripts/ralph` | Added 3 command functions + dispatcher cases | +180 lines |
| `~/.claude/settings.json` | Added Stop hook + Bash permissions | +13 lines |
| `~/.claude/skills/iterate-pr/SKILL.md` | Added context:fork, hooks, Step 3a, Sentry priority | +50 lines |
| `~/.claude/skills/find-bugs/SKILL.md` | Added context:fork, hooks, Phase 0, Phase 6 | +100 lines |
| `~/.claude/skills/deslop/SKILL.md` | Added context:fork, Sentry anti-patterns section | +90 lines |
| `CLAUDE.md` | Added v2.33 section, updated title to v2.33 | +60 lines |
| `CHANGELOG.md` | Added v2.33 release notes | +80 lines |

### Backward Compatibility (v2.33)

- ✅ **Zero Breaking Changes**: All v2.32 workflows work unchanged
- ✅ **Optional Features**: Sentry steps trigger only when conditions met
- ✅ **Graceful Degradation**: Skills skip Sentry features if not configured
- ✅ **No MCP Required**: 80% of functionality works without Sentry MCP
- ✅ **Existing Commands**: All pre-v2.33 commands unaffected

### Architecture Highlights (v2.33)

**Skills vs MCP Hierarchy**:
- **Skills-First**: sentry-setup-*, sentry-code-review, iterate-pr, find-bugs, deslop (NO MCP)
- **MCP Optional**: issue-summarizer agent, /seer, /getIssues commands (requires MCP for analytics)

**Integration Philosophy**:
1. Core workflows (setup, code review, PR iteration) use skills only
2. Advanced analytics (issue analysis, queries) require optional MCP
3. Users get 80% value without MCP, 100% with MCP

---

## [2.31.0] - 2026-01-07

### Added (Memvid Memory Integration)

- **Memvid Integration**: Semantic memory system with HNSW + BM25 hybrid search (sub-5ms latency)
- **Memory Automation**: Auto-save checkpoints to semantic memory via hooks
- **Time-travel Queries**: Query across session history with semantic search
- **Single-file Storage**: Portable `.mv2` memory file (no database required)
- **Startup Validation**: Memvid installation verified at startup
- **Apache 2.0 License**: 100% free, no cloud dependencies

### New Components (v2.31)

| Component | Path | Purpose |
|-----------|------|---------|
| `memvid-core.py` | `~/.claude/scripts/memvid-core.py` | Core memory library |
| `memvid-memory/` | `~/.claude/skills/memvid-memory/` | @memvid skill |
| `migrate-checkpoints.py` | `~/.claude/scripts/migrate-checkpoints.py` | JSON → .mv2 migration |

### New CLI Commands (v2.31)

| Command | Purpose |
|---------|---------|
| `ralph memvid init` | Initialize memory system |
| `ralph memvid save "text"` | Save context to memory |
| `ralph memvid search "query"` | Semantic memory search |
| `ralph memvid timeline` | View session history |
| `ralph memvid status` | Show memory status |

### Validation (v2.31)

- Added `memvid` to `FEATURE_TOOLS` array
- Added `validate_memvid_packages()` function for package verification
- Added startup validation in `startup_validation()`

---

## [2.30.0] - 2026-01-07

### Added (Context Engineering)

- **Context Monitoring Hook**: @context-monitor alerts at 60% context threshold via `context-warning.sh` hook
- **Auto-Checkpointing System**: Full checkpoint management with 4 new commands (`/checkpoint save/restore/list/clear`)
- **System Reminders (Manus Pattern)**: Periodic goal reminders every N messages to prevent "lost in middle" syndrome
- **Fresh Context Explorer**: @fresh-explorer skill for independent analysis without context contamination
- **CC + Codex Workflow**: Documented dual-agent pattern (Claude Code implements → Codex reviews → iterate)
- **CLAUDE.md Modularization**: 10 new skills created, global config reduced from 285→119 lines (58% reduction)

### New Skills (v2.30)

| Skill | Purpose | Lines |
|-------|---------|-------|
| `@context-monitor` | Context usage monitoring at 60% threshold | 99 |
| `@checkpoint-manager` | Session state preservation | 119 |
| `@system-reminders` | Periodic goal reminders | 194 |
| `@fresh-explorer` | Fresh context exploration | 196 |
| `@cc-codex-workflow` | CC + Codex dual-agent pattern | 210 |
| `@ralph-loop-pattern` | Loop pattern (split from CLAUDE.md) | 50 |
| `@model-selection` | Model configuration | 40 |
| `@tool-selection` | Tool matrix | 60 |
| `@workflow-patterns` | Execution patterns | 40 |
| `@security-patterns` | Security functions | 30 |

### New Hooks (v2.30)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `context-warning.sh` | user-prompt-submit | Alert at 60% context |
| `periodic-reminder.sh` | user-prompt-submit | Goal reminders every N messages |

### New Commands (v2.30)

| Command | Purpose |
|---------|---------|
| `/checkpoint save "desc"` | Save current session state |
| `/checkpoint list` | List all checkpoints |
| `/checkpoint restore N` | Restore checkpoint N |
| `/checkpoint clear` | Clear all checkpoints |

### Validation Results

| Metric | Value |
|--------|-------|
| Overall Score | 9.5/10 |
| Skills Created | 10 |
| Hooks Created | 2 |
| Commands Created | 4 |
| Total Files | ~50 |
| CLAUDE.md Reduction | 58% (285→119 lines) |

---

## [2.28.0] - 2026-01-04

### Added
- **Comprehensive Test Suite**: 476 total tests covering all components
- **7 New Test Files**: CLI commands, slash commands, skills, security functions, cross-platform, orchestrator flow, worktree workflow
- **Expanded Slash Commands**: All 7 sparse commands expanded to production-quality (150-543 lines each)

## [2.29.0] - 2026-01-07

### Added
- **Smart Execution**: Background tasks by default with `run_in_background: true`
- **Quality Criteria**: Explicit stop conditions defined per agent/task type
- **Auto Discovery**: Explorer/Plan invoked automatically for complex tasks (complexity >= 7)
- **Tool Selection Matrix**: Intelligent routing to optimal tools (ast-grep, Context7, WebSearch, MiniMax MCP)
- **New Skill**: `auto-intelligence` for automatic context exploration and planning

### Updated Agents
- orchestrator.md - Added quality criteria + tool selection + auto discovery
- security-auditor.md - Added quality criteria + run_in_background
- debugger.md - Added quality criteria + run_in_background
- code-reviewer.md - Added quality criteria + run_in_background
- test-architect.md - Added quality criteria + run_in_background
- refactorer.md - Added quality criteria + run_in_background
- frontend-reviewer.md - Added quality criteria + run_in_background
- docs-writer.md - Added quality criteria + run_in_background
- minimax-reviewer.md - Added quality criteria + run_in_background

### Updated Skills
- ai-code-auditor/SKILL.md - Added quality criteria
- isms-audit-expert/SKILL.md - Added quality criteria
- polymarket-risk-and-position-sizing/SKILL.md - Added quality criteria

### Updated Configuration
- ~/.claude/CLAUDE.md - Added v2.29 Smart Execution section
- CLAUDE.md (project) - Updated to v2.29 with tool selection matrix

### Testing Coverage

| Test File | Tests | Coverage |
|-----------|-------|----------|
| `test_cli_commands.bats` | ~80 | All 33 CLI commands |
| `test_slash_commands.py` | ~50 | All 24 slash command metadata |
| `test_skills.py` | ~25 | All 8 skills validation |
| `test_security_functions.bats` | ~45 | Security hardening functions |
| `test_cross_platform.bats` | ~30 | macOS/Linux compatibility |
| `test_orchestrator_flow.bats` | ~40 | 8-step orchestration flow |
| `test_worktree_workflow.bats` | ~35 | 7 worktree commands |

### Expanded Commands

| Command | Before | After | Improvement |
|---------|--------|-------|-------------|
| `/loop` | 18 | 543 | +30x |
| `/security` | 25 | 475 | +19x |
| `/refactor` | 18 | 448 | +25x |
| `/bugs` | 18 | 309 | +17x |
| `/retrospective` | 17 | 194 | +11x |
| `/gates` | 17 | 171 | +10x |
| `/unit-tests` | 18 | 150 | +8x |

### Fixed
- **((ITER++)) Bug**: Fixed bash arithmetic bug with `set -e` when ITER=0
- **v2.27 Security Audit Findings**: All 3 HIGH severity issues resolved
  - HIGH-1: Command injection via TARGET path (now uses SAFE_TARGET)
  - HIGH-2: MAX_ROUNDS parameter validation (1-100 range)
  - HIGH-3: APPROVAL_MODE parameter validation (yolo|strict|hybrid)

### Security
- Full security audit passed with Codex + Claude
- All user inputs validated
- All JSON construction uses jq
- All temp files use mktemp with permission verification

---

## [2.27.0] - 2026-01-04

### Added
- **Multi-Level Security Loop**: Iterative security audit (`ralph security-loop`) that runs → fixes → re-audits until 0 vulnerabilities
- **Hybrid Approval Mode**: Auto-fix LOW/MEDIUM issues, manual approval for CRITICAL/HIGH
- **New CLI Command**: `ralph security-loop <path> [--max-rounds N]` (alias: `ralph secloop`)
- **New Slash Command**: `/security-loop` with `@secloop` prefix

### Changed
- **README Restructured**: Professional documentation with Overview, Key Features, Core Workflows at top
- **Changelog Separated**: Version history moved to dedicated CHANGELOG.md

---

## [2.26.0] - 2026-01-03

### Added
- **Prefix-Based Commands**: All 23 slash commands support short `@prefix` invocation
- **Task Persistence**: Tasks survive session restarts via `.ralph/tasks.json`
- **New Commands**: `/commands` (`@cmds`), `/diagram` (`@diagram`)
- **Anthropic Best Practices**: Official Claude 4 directives integrated

### Prefix System

| Category | Prefix Examples |
|----------|-----------------|
| Orchestration | `@orch`, `@clarify`, `@loop` |
| Review | `@sec`, `@bugs`, `@tests`, `@ref`, `@review`, `@par`, `@adv` |
| Research | `@research`, `@lib`, `@mmsearch`, `@ast`, `@browse`, `@img` |
| Tools | `@gates`, `@mm`, `@imp`, `@audit`, `@retro`, `@cmds`, `@diagram` |

### Anthropic Directives

| Directive | Purpose |
|-----------|---------|
| `<investigate_before_answering>` | Never speculate about unread code |
| `<use_parallel_tool_calls>` | Maximize parallel tool execution |
| `<default_to_action>` | Implement rather than suggest |
| `<avoid_overengineering>` | Keep solutions simple |
| `<code_exploration>` | Read files before editing |

---

## [2.25.0] - 2026-01-04

### Added
- **Search Hierarchy**: WebSearch (FREE) → Context7 MCP → MiniMax MCP (8% fallback)
- **Context7 MCP Integration**: Optimized library/framework documentation search
- **dev-browser Integration**: Primary browser automation (17% faster, 39% cheaper)
- **New CLI Commands**: `ralph library`, `ralph browse`
- **New Slash Commands**: `/library-docs`, `/browse`

### Changed
- **Gemini Scope**: Now ONLY for short, punctual tasks (NOT research/long-context)
- **Research Command**: Now uses WebSearch → MiniMax instead of Gemini

### Cost Savings

| Change | Before | After | Savings |
|--------|--------|-------|---------|
| Web Research | Gemini (60%) | WebSearch (FREE) | 60% |
| Library Docs | MiniMax (8%) | Context7 (optimized) | ~50% tokens |
| Browser | Playwright | dev-browser | 39% cost, 17% faster |

---

## [2.24.2] - 2026-01-04

### Security - Complete Hardening

| Fix | CWE | Severity | Description |
|-----|-----|----------|-------------|
| Command Substitution Block | CWE-78 | HIGH | Block `$()` and backticks before path expansion |
| Canonical Path Validation | CWE-59 | HIGH | Validate resolved path after symlink resolution |
| Decompression Bomb Protection | CWE-400 | HIGH | Post-download size + pixel dimension validation |
| Structured Security Logging | CWE-778 | MEDIUM | JSON audit trail in `~/.ralph/security-audit.log` |
| Tmpdir Permission Verification | CWE-362 | MEDIUM | TOCTOU race condition mitigation |

---

## [2.24.1] - 2026-01-03

### Security - Initial Hardening

| Fix | CWE | Description |
|-----|-----|-------------|
| URL Validation | CWE-20 | 20MB size limit + MIME type check |
| Path Allowlist | CWE-22 | Interactive confirmation for files outside project |
| Prompt Injection | CWE-94 | Heredoc blocks with SECURITY INSTRUCTION markers |
| Doc Guardrails | CWE-1325 | Prompt injection warnings in commands |

---

## [2.24.0] - 2026-01-02

### Added
- **MiniMax MCP Web Search**: 8% cost web research via MCP protocol
- **MiniMax MCP Image Analysis**: Screenshot/UI/diagram analysis capability
- **New CLI Commands**: `ralph websearch`, `ralph image`
- **New Slash Commands**: `/minimax-search`, `/image-analyze`

### Changed
- **Gemini Deprecation**: Research queries migrate to MiniMax (87% savings)

---

## [2.23.0] - 2025-12-30

### Added
- **AST-Grep MCP Integration**: Structural code search (~75% less tokens)
- **Hybrid Search**: Combines ast-grep (patterns) + Explore agent (semantic)
- **New CLI Command**: `ralph ast '<pattern>' <path>`
- **New Slash Command**: `/ast-search`

### Pattern Syntax

| Pattern | Meaning | Example |
|---------|---------|---------|
| `$VAR` | Single AST node | `console.log($MSG)` |
| `$$$` | Multiple nodes | `function($$$)` |
| `$$VAR` | Optional nodes | `async $$AWAIT function` |

---

## [2.22.0] - 2025-12-28

### Added
- **Startup Validation**: Fast check warns about missing tools
- **On-Demand Validation**: Blocking error with install instructions
- **Tool Categories**: Critical, Feature, Quality Gates
- **Clear Error Messages**: ASCII box with exact install command

### Tool Validation

| Category | Startup | On-Demand | Blocking |
|----------|---------|-----------|----------|
| Critical (claude, jq, git) | Warning | Error + Exit | Yes |
| Feature (wt, gh, mmc, codex, gemini, sg) | Info | Error + Exit | When needed |
| Quality Gates (9 languages) | Count | Warning | No (graceful) |

---

## [2.21.0] - 2025-12-26

### Added
- **Self-Update**: `ralph self-update` syncs scripts from repo
- **Pre-Merge Validation**: `ralph pre-merge` validates before PR
- **Integrations Check**: `ralph integrations` shows tool status
- **Commit Prefix**: Per-agent prefixes (security:, test:, ui:, docs:)
- **Model by Task**: Optimized model selection

### Model Configuration

| Task Type | Model | Why |
|-----------|-------|-----|
| Exploration | MiniMax | 1M context, 8% cost |
| Implementation | Sonnet | Balanced quality/speed |
| Review | Opus | Surgical precision |
| Validation | MiniMax | Second opinion at 8% |

---

## [2.20.0] - 2025-12-24

### Added
- **Git Worktree Workflow**: Isolated feature development
- **Human-in-the-Loop**: Orchestrator asks about worktree isolation (Step 2b)
- **Multi-Agent PR Review**: Claude Opus + Codex GPT-5 review
- **One Worktree Per Feature**: Multiple subagents share worktree
- **WorkTrunk Integration**: Required for worktree management
- **8-Step Flow**: Updated orchestration with worktree/PR phases

### New Commands

| Command | Description |
|---------|-------------|
| `ralph worktree "task"` | Create worktree + launch Claude |
| `ralph worktree-pr <branch>` | Create PR + multi-agent review |
| `ralph worktree-merge <pr>` | Approve and merge |
| `ralph worktree-fix <pr>` | Apply review fixes |
| `ralph worktree-close <pr>` | Close and cleanup |
| `ralph worktree-status` | Show all worktrees |
| `ralph worktree-cleanup` | Clean merged worktrees |

---

## [2.19.0] - 2025-12-22

### Security Fixes

| Fix | Description |
|-----|-------------|
| VULN-001 | `escape_for_shell()` uses `printf %q` |
| VULN-003 | Improved rm -rf regex in git-safety-guard.py |
| VULN-004 | `validate_path()` uses `realpath -e` |
| VULN-005 | Log files chmod 600 |
| VULN-008 | All scripts start with `umask 077` |

---

## [2.17.0] - 2025-12-18

### Security

- **Input Validation**: All user inputs validated and shell-escaped
- **Enhanced validate_path()**: Blocks control chars, path traversal
- **New validate_text_input()**: Validates free-form text
- **Safe JSON Construction**: Uses jq for all JSON building

---

## [2.16.0] - 2025-12-15

### Added
- **Auto Plan Mode**: Automatic `EnterPlanMode` for non-trivial tasks
- **AskUserQuestion**: Native Claude tool for MUST_HAVE/NICE_TO_HAVE
- **Deep Clarification Skill**: Comprehensive questioning patterns
- **7-Step Flow**: Updated from 6 to 7 steps

---

## [2.15.0] - 2025-12-12

### Added
- **Safe Settings Merge**: Installation preserves existing settings.json
- **Non-Destructive Install/Uninstall**: Only Ralph entries modified

---

## [2.14.0] - 2025-12-10

### Added
- **Multi-Agent Orchestration**: Coordinate Claude, Codex, MiniMax
- **Adversarial Validation**: 2/3 consensus (Claude + Codex + Gemini)
- **15 Slash Commands**: Full command suite
- **Self-Improvement**: Retrospective analysis
- **9 Language LSP**: TS, JS, Python, Go, Rust, Solidity, Swift, JSON, YAML
- **9 Specialized Agents**: orchestrator, security-auditor, code-reviewer, etc.
- **Quality Gates Hook**: Post-edit validation
- **Git Safety Guard**: Pre-bash command validation

---

[2.28.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.27.0...v2.28.0
[2.27.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.26.0...v2.27.0
[2.26.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.25.0...v2.26.0
[2.25.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.24.2...v2.25.0
[2.24.2]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.24.1...v2.24.2
[2.24.1]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.24.0...v2.24.1
[2.24.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.23.0...v2.24.0
[2.23.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.22.0...v2.23.0
[2.22.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.21.0...v2.22.0
[2.21.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.20.0...v2.21.0
[2.20.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.19.0...v2.20.0
[2.19.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.17.0...v2.19.0
[2.17.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.16.0...v2.17.0
[2.16.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.15.0...v2.16.0
[2.15.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/compare/v2.14.0...v2.15.0
[2.14.0]: https://github.com/alfredolopez80/multi-agent-ralph-loop/releases/tag/v2.14.0
