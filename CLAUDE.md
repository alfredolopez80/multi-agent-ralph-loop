# Multi-Agent Ralph v2.35

Orchestration with **automatic planning**, **intensive clarification**, **git worktree isolation**, adversarial validation, self-improvement, 9-language quality gates, **multi-level security loop**, **context engineering**, **Memvid semantic memory**, **Sentry observability integration**, **Codex CLI v0.79.0 security hardening**, **automatic context preservation (ledgers + handoffs)**, and **comprehensive testing (517+ tests)**.

## v2.35 Key Changes (Context Engineering Optimization)

- **100% AUTOMATIC CONTEXT PRESERVATION**: No user intervention required after initial setup
- **LEDGER SYSTEM**: CONTINUITY_RALPH-<session>.md files for persistent session state (~500 tokens)
- **HANDOFF SYSTEM**: handoff-<timestamp>.md for context transfer documents (~300 tokens)
- **SESSIONSTART HOOK**: Auto-loads ledger + handoff at session start
- **PRECOMPACT HOOK**: Auto-saves state BEFORE context compaction (prevents information loss)
- **MEMVID INTEGRATION**: Hybrid storage with HNSW + BM25 semantic search for handoffs
- **85-90% CONTEXT REDUCTION**: Estimated token savings through optimized context injection
- **NEW CLI COMMANDS**: `ralph ledger`, `ralph handoff`, `ralph setup-context-engine`
- **FEATURE FLAGS**: ~/.ralph/config/features.json for enabling/disabling features
- **33 NEW TESTS**: Comprehensive test suite for context engine components

### Context Preservation Architecture (v2.35)

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH v2.35 CONTEXT ENGINE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [SessionStart Hook] - Auto-load at session start               │
│  ├── Auto-load CONTINUITY_RALPH.md (~500 tokens)               │
│  ├── Auto-load last handoff.md (~300 tokens)                   │
│  └── Inject via hookSpecificOutput.additionalContext           │
│                                                                 │
│  [PreCompact Hook] - Auto-save before compaction                │
│  ├── Auto-save ledger to ~/.ralph/ledgers/                     │
│  ├── Auto-create handoff to ~/.ralph/handoffs/                 │
│  └── Index to Memvid for semantic search                       │
│                                                                 │
│  [Storage Layer]                                                │
│  ├── ~/.ralph/ledgers/CONTINUITY_RALPH-<session>.md            │
│  ├── ~/.ralph/handoffs/<session>/handoff-<ts>.md               │
│  └── Memvid (.mv2) for semantic search (optional)              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Automation Matrix (v2.35)

| Event | Trigger | Automatic Action | User Action |
|-------|---------|------------------|-------------|
| **Session start** | SessionStart hook | Loads ledger + handoff | ❌ None |
| **Context 70%+** | claude-hud | Yellow warning | ❌ None |
| **Context 85%+** | claude-hud | Red warning | ❌ None |
| **Pre-compaction** | PreCompact hook | Saves ledger + handoff + Memvid | ❌ None |
| **Post-compaction** | SessionStart hook | Reloads fresh context | ❌ None |

### Context Engine Commands (v2.35)

```bash
# One-time setup (REQUIRED ONCE)
ralph setup-context-engine  # Creates dirs, registers hooks, validates

# Ledger management (usually automatic, manual for special cases)
ralph ledger save           # Save current session state
ralph ledger load [session] # Load specific ledger
ralph ledger list           # List available ledgers
ralph ledger show           # Display current ledger
ralph ledger delete <id>    # Delete a ledger

# Handoff management (usually automatic)
ralph handoff create        # Create manual handoff
ralph handoff load [session] # Load latest handoff
ralph handoff search "query" # Search handoffs (uses Memvid if available)
ralph handoff list          # List available handoffs
ralph handoff cleanup       # Clean old handoffs (>30 days, keep min 5)

# Combined context
ralph ledger context        # Get context for injection (ledger + handoff)
```

### Feature Flags (v2.35)

```json
// ~/.ralph/config/features.json
{
  "RALPH_ENABLE_LEDGER": true,     // Auto-load ledger on SessionStart
  "RALPH_ENABLE_HANDOFF": true,    // Auto-save on PreCompact
  "RALPH_ENABLE_STATUSLINE": true  // Show context % in status (claude-hud)
}
```

### Migration Guide (v2.34 → v2.35)

**Required Action (ONE TIME):**
```bash
ralph setup-context-engine
```

**After Setup - Everything is Automatic:**
- No commands needed for context preservation
- Ledgers auto-saved before compaction
- Handoffs auto-created for session transfer
- Context auto-loaded on session start

**Backward Compatibility:**
- 100% compatible with v2.34
- Feature flags can disable any v2.35 feature
- If disabled = exact v2.34 behavior

### Global vs Project-Local Configuration (v2.35)

Claude Code merges configurations from two locations:
1. **Global**: `~/.claude/` - Available in ALL projects
2. **Project-local**: `PROJECT/.claude/` - Project-specific overrides

```
┌─────────────────────────────────────────────────────────────────┐
│              CONFIGURATION HIERARCHY                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [GLOBAL - ~/.claude/]                                         │
│  ├── agents/         (27 agents - always available)            │
│  ├── commands/       (33 commands - always available)          │
│  ├── skills/         (169 skills - always available)           │
│  ├── hooks/          (17 hook files)                           │
│  └── settings.json   (6 hook event types registered)           │
│                                                                 │
│  [PROJECT-LOCAL - .claude/]                                    │
│  ├── agents/         (project-specific overrides)              │
│  ├── hooks/          (project-specific hooks)                  │
│  └── settings.json   (can extend/override global hooks)        │
│                                                                 │
│  [MERGED VIEW - What Claude Code Sees]                         │
│  └── Global + Project-local merged (project-local wins on      │
│      conflicts)                                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Global Sync Command (v2.35):**

```bash
# Sync configurations from ralph repo to global ~/.claude/
ralph sync-global           # Full sync
ralph sync-global --dry-run # Preview changes
ralph sync-global --force   # Overwrite all files

# This syncs:
# 1. Agents (*.md files)
# 2. Commands (*.md files)
# 3. Skills (directories)
# 4. Hooks (script files)
# 5. settings.json (hooks configuration)
```

**Important:** Run `ralph sync-global` after updating the ralph repo to propagate changes to all projects.

**Required Hook Event Types (6):**
| Hook Type | Purpose | Auto-registered |
|-----------|---------|-----------------|
| PostToolUse | Quality gates after Edit/Write | ✅ |
| PreToolUse | Safety guards before Bash/Skill | ✅ |
| SessionStart | Context preservation at startup | ✅ |
| PreCompact | Save state before compaction | ✅ |
| UserPromptSubmit | Context warnings, reminders | ✅ |
| Stop | Session reports | ✅ |

## v2.34 Key Changes (Codex CLI v0.79.0 Security Hardening)

- **CODEX CLI UPGRADE**: v0.77.0 → v0.79.0 with comprehensive security improvements
- **SANDBOX MODES**: Granular isolation (read-only, workspace-write, danger-full-access)
- **APPROVAL POLICIES**: Fine-grained control (untrusted, on-failure, on-request, never)
- **OUTPUT SCHEMAS**: JSON validation for 100% consistent parsing (eliminates ~20% failures)
- **CONFIGURATION PROFILES**: 5 specialized profiles (security-audit, bug-hunting, code-review, unit-tests, ci-cd)
- **SECURE BY DEFAULT**: Global config changed to `approval_policy=on-request` + `sandbox_mode=workspace-write`
- **NEW FLAGS**: `--full-auto` convenience flag (workspace-write + on-request)
- **DEPRECATED**: `--yolo` → `--dangerously-bypass-approvals-and-sandbox` (explicit danger warning)
- **NATIVE REVIEW**: `codex review` for Git-aware PR reviews
- **ZERO --yolo USAGE**: 10/11 invocations (91%) eliminated → 0/11 (0%) ✅
- **100% SANDBOX ISOLATION**: All Codex invocations now use proper sandboxing
- **NEW FUNCTION**: `init_codex_schemas()` auto-creates JSON schemas on startup
- **NEW TEST SUITE**: 20 comprehensive tests validating security hardening

### Codex CLI v0.79.0 Configuration Profiles

| Profile | Model | Sandbox | Approval | Use Case |
|---------|-------|---------|----------|----------|
| **security-audit** | o3 (max reasoning) | read-only | on-failure | Security audits - no file modifications |
| **bug-hunting** | gpt-5.2-codex | workspace-write | on-request | Bug detection + fixes |
| **code-review** | gpt-5.2-codex | workspace-write | on-request | PR reviews, refactoring |
| **unit-tests** | gpt-5.2-codex | workspace-write | on-request | Test generation |
| **ci-cd** | gpt-5.2-codex | danger-full-access | never | ⚠️ CI/CD pipelines ONLY (with external sandboxing) |

### Migration Guide (v2.33 → v2.34)

**Breaking Changes:**
- `--yolo` flag removed → use `--dangerously-bypass-approvals-and-sandbox` OR profiles
- Global config defaults now SECURE (`approval_policy=on-request`, `sandbox_mode=workspace-write`)
- Skills require explicit enable via features or `--enable <skill-name>`

**Backward Compatibility:**
- All CLI commands work with safer defaults
- Use `--profile ci-cd` to match old `--yolo` behavior (CI/CD only)
- All 11 Codex invocations updated automatically

**Migration Statistics:**
- Files modified: 11 (ralph script + 6 agents + 4 skills)
- Codex invocations updated: 11/11 (100%)
- `--yolo` usage eliminated: 10/11 (91%) → 0/11 (0%)
- Sandbox isolation: 0/11 (0%) → 11/11 (100%)
- JSON parsing reliability: ~80% → 100% (with schemas)

### Codex CLI v0.79.0 Commands (v2.34)

```bash
# Security audit (read-only sandbox, o3 model)
ralph security src/
# Internally uses:
# codex exec --profile security-audit --output-schema ~/.ralph/schemas/security-output.json

# Bug hunting (workspace-write, interactive approval)
ralph bugs src/
# Internally uses:
# codex exec --full-auto --output-schema ~/.ralph/schemas/bugs-output.json

# Unit test generation (workspace-write)
ralph unit-tests src/
# Internally uses:
# codex exec --profile unit-tests --full-auto --output-schema ~/.ralph/schemas/tests-output.json

# Code review (Git-aware native review)
ralph review main..feature-branch
# Internally uses:
# codex review --base main --uncommitted --profile code-review

# Security loop (iterative audit + fix)
ralph security-loop src/ --max-rounds 10
# Uses security-audit profile with read-only sandbox
```

### JSON Output Schemas (v2.34)

**Location:** `~/.ralph/schemas/`

**Auto-created on startup** via `init_codex_schemas()` function:

1. **security-output.json** - Security audit results
   - Required fields: `vulnerabilities[]`, `summary{}`
   - CWE classification, severity levels (CRITICAL/HIGH/MEDIUM/LOW)
   - Structured fix recommendations

2. **bugs-output.json** - Bug hunting results
   - Required fields: `bugs[]`, `summary{}`
   - Bug types: logic, null, boundary, leak, race, error, async
   - Reproduction steps + fixes

3. **tests-output.json** - Test generation results
   - Required fields: `tests[]`, `summary{}`
   - Test types: unit, integration, e2e
   - Coverage estimation

**Benefits:**
- 100% consistent JSON parsing (eliminates ~20% parsing failures)
- Type-safe result handling
- Automated validation via JSON Schema

### Sandbox Security Model (v2.34)

| Sandbox Mode | File Access | Use When | Security Level |
|--------------|-------------|----------|----------------|
| **read-only** | Read files only | Security audits, analysis | ✅ Highest |
| **workspace-write** | Write within project | Bug fixes, tests, features | ✅ Medium |
| **danger-full-access** | Unrestricted | ⚠️ CI/CD with external sandbox | ❌ Lowest |

**Approval Policies:**

| Policy | Behavior | Use When |
|--------|----------|----------|
| **on-request** | Model decides when to ask | Default - balanced automation |
| **on-failure** | Ask only if command fails | Trusted environments |
| **untrusted** | Ask for untrusted commands | Paranoid mode |
| **never** | Auto-approve everything | ⚠️ CI/CD ONLY |

**Convenience Flags:**

```bash
# Instead of: --sandbox workspace-write --ask-for-approval on-request
# Use:
--full-auto

# Instead of: --yolo (deprecated)
# Use (only in CI/CD):
--dangerously-bypass-approvals-and-sandbox
# OR better:
--profile ci-cd
```

## v2.33 Key Changes (Sentry Observability Integration)

- **SENTRY SKILLS INTEGRATION**: 4 official Sentry skills for setup, code review, and validation
- **SKILLS-FIRST APPROACH**: 80% of value WITHOUT requiring Sentry MCP configuration
- **ORCHESTRATOR ENHANCEMENTS**: Optional Sentry steps (2c, 6b, 7b) with 100% backward compatibility
- **CONTEXT ISOLATION**: All Sentry skills use `context: fork` for clean execution
- **PR WORKFLOW INTEGRATION**: Sentry bot priority in iterate-pr, auto-fix via sentry-code-review
- **PRODUCTION CORRELATION**: find-bugs correlates local issues with live Sentry data
- **ANTI-PATTERN DETECTION**: deslop removes Sentry over-instrumentation
- **NEW CLI COMMANDS**: `ralph sentry-init|sentry-validate|code-review-sentry`
- **NEW HOOKS**: sentry-check-status, sentry-correlation, sentry-report
- **GRACEFUL DEGRADATION**: All Sentry features optional, no breaking changes

### Sentry Integration Components

| Component | Uses MCP? | When to Use |
|-----------|-----------|-------------|
| **sentry-setup-*** skills | ❌ NO | Auto-configure SDK (tracing, logging, metrics, AI) |
| **sentry-code-review** skill | ❌ NO | Fix Sentry bot PR comments |
| **iterate-pr** (enhanced) | ❌ NO | Prioritize Sentry checks in PR workflow |
| **find-bugs** (enhanced) | ❌ NO | Correlate with production issues (optional) |
| **deslop** (enhanced) | ❌ NO | Remove Sentry over-instrumentation |
| issue-summarizer agent | ✅ YES | Deep issue analysis (optional) |
| /seer, /getIssues commands | ✅ YES | Natural language queries (optional) |

### Sentry Commands

```bash
# Phase 1: Setup (No MCP required)
ralph sentry-init              # Auto-detect and configure SDK
ralph sentry-init --tracing    # Setup tracing only
ralph sentry-init --all        # Full observability stack

# Phase 2: Validation & PR Review (No MCP required)
ralph sentry-validate          # Check configuration
ralph code-review-sentry <branch>  # Wait for Sentry bot + auto-fix
ralph iterate <pr>             # Enhanced with Sentry priority

# Orchestrator integration (automatic)
/orchestrator "task"           # Offers Sentry setup for new projects
```

### Orchestrator Integration (v2.33)

New optional steps in the 8-step workflow:

- **Step 2c: SENTRY SETUP** - Auto-detect project type, offer SDK configuration
- **Step 6b: SENTRY VALIDATION** - Pre-merge Sentry configuration checks
- **Step 7b: PR REVIEW (Enhanced)** - Prioritize Sentry bot comments, auto-fix, iterate

All steps are OPTIONAL and maintain 100% backward compatibility with v2.32.

## v2.31 Key Changes (Memvid Memory Integration)

- **MEMVID INTEGRATION**: Semantic memory system with HNSW + BM25 hybrid search
- **MEMORY AUTOMATION**: Auto-save checkpoints to semantic memory via hooks
- **TIME-TRAVEL QUERIES**: Query across session history with sub-5ms latency
- **SINGLE-FILE STORAGE**: Portable `.mv2` memory file (no database required)
- **STARTUP VALIDATION**: Memvid installation verified at startup
- **NEW CLI COMMANDS**: `ralph memvid init|save|search|timeline|status`
- **NEW SKILL**: @memvid for semantic memory operations
- **100% OFFLINE**: Apache 2.0 license, no cloud dependencies

### Memvid vs claude-mem

| Feature | claude-mem | Memvid (v2.31) |
|---------|------------|----------------|
| Vector Search | SQLite basic | HNSW + BM25 |
| Time-travel | No | Yes |
| Single-file | No | Yes (.mv2) |
| Latency | Slow | Sub-5ms |
| License | Open | Apache 2.0 |

### Memvid Commands

```bash
ralph memvid init          # Initialize memory system
ralph memvid save "context"  # Save current context
ralph memvid search "query"  # Semantic search
ralph memvid timeline       # View session history
```

## v2.30 Key Changes (Context Engineering)

- **CONTEXT MONITORING**: @context-monitor alerts at 60% context threshold
- **AUTO-CHECKPOINTING**: /checkpoint save/restore/list/clear for session preservation
- **SYSTEM REMINDERS**: Periodic goal reminders (Manus pattern) to prevent "lost in middle"
- **FRESH CONTEXT EXPLORER**: @fresh-explorer for independent analysis
- **CC + CODEX WORKFLOW**: Claude Code implements → Codex reviews → iterate
- **CLAUDE.md MODULARIZATION**: 10 new skills created, reduced 58% (285→119 lines)

## v2.29 Key Changes (Smart Execution)

- **BACKGROUND TASKS DEFAULT**: All agents use `run_in_background: true` by default
- **QUALITY CRITERIA**: Explicit stop conditions defined for each agent/task type
- **AUTO DISCOVERY**: Explorer/Plan invoked automatically for complex tasks (complexity >= 7)
- **SMART TOOL SELECTION**: Intelligent routing to ast-grep, Context7, WebSearch, MiniMax MCP
- **PARALLEL EXECUTION**: Multiple subagents run concurrently when possible
- **9 AGENTS UPDATED**: orchestrator, security-auditor, debugger, code-reviewer, test-architect, refactorer, frontend-reviewer, docs-writer, minimax-reviewer
- **NEW SKILL**: auto-intelligence for automatic context exploration and planning

### Tool Selection Matrix (v2.29)
| Task Type | Primary Tool | Fallback |
|-----------|--------------|----------|
| Code patterns (AST) | ast-grep MCP | Explore agent |
| Code search (strings) | grep/rg | ast-grep MCP |
| Library docs | Context7 MCP | WebSearch |
| Web research | WebSearch (native) | MiniMax MCP |
| Code review | Codex GPT-5 | Claude Opus |
| Second opinion | MiniMax (8% cost) | Claude Sonnet |

## v2.28 Key Changes (Comprehensive Testing & Audit)

- **COMPREHENSIVE TEST SUITE**: 476 tests covering CLI commands, slash commands, skills, security functions
- **7 NEW TEST FILES**: CLI, slash commands, skills, security, cross-platform, orchestrator, worktree
- **EXPANDED COMMANDS**: All 7 sparse commands expanded to 150-543 lines with full documentation
- **SECURITY AUDIT**: All v2.27 HIGH findings fixed (TARGET escaping, parameter validation)

## v2.27 Key Changes (Multi-Level Security Loop)

- **MULTI-LEVEL SECURITY LOOP**: Iterative `ralph security-loop` audits and fixes until 0 vulnerabilities
- **HYBRID APPROVAL MODE**: Auto-fix LOW/MEDIUM, manual approval for CRITICAL/HIGH
- **README RESTRUCTURED**: Professional documentation with Overview, Features, Workflows at top
- **CHANGELOG.md**: Version history moved to dedicated file
- **NEW CLI COMMAND**: `ralph security-loop <path> [--max-rounds N] [--yolo|--strict|--hybrid]`
- **NEW SLASH COMMAND**: `/security-loop` with `@secloop` prefix

### Multi-Level Security Loop (v2.27)

```
┌─────────────────────────────────────────────────────────────────┐
│                 MULTI-LEVEL SECURITY LOOP                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Round 1                                                       │
│   ┌──────────┐    ┌──────────────┐    ┌─────────────────┐      │
│   │  AUDIT   │───▶│   FINDINGS   │───▶│ Issues Found?   │      │
│   │  (Codex) │    │   (Parse)    │    └────────┬────────┘      │
│   └──────────┘    └──────────────┘             │               │
│                                          NO ◀──┴──▶ YES        │
│                                           │         │          │
│                                           ▼         ▼          │
│                                   ┌───────────┐  ┌──────────┐  │
│                                   │  DONE     │  │   FIX    │  │
│                                   │  0 issues │  │ (Hybrid) │  │
│                                   └───────────┘  └────┬─────┘  │
│                                                       │        │
│   Round 2+                                            ▼        │
│   ┌──────────┐    ┌──────────────┐    ┌─────────────────┐      │
│   │ RE-AUDIT │◀───│   VALIDATE   │◀───│ Fixes Applied   │      │
│   │  (Codex) │    │   (Check)    │    └─────────────────┘      │
│   └──────────┘    └──────────────┘                             │
│                                                                 │
│   Config: Max 10 rounds, Codex GPT-5, Hybrid approval          │
└─────────────────────────────────────────────────────────────────┘
```

### Approval Modes (v2.27)

| Mode | Flag | Behavior | Use Case |
|------|------|----------|----------|
| **Hybrid** | (default) | Auto-fix LOW/MEDIUM, ask for HIGH/CRITICAL | Production code |
| YOLO | `--yolo` | Auto-approve ALL fixes | CI/CD pipelines |
| Strict | `--strict` | Ask approval for EVERY fix | Critical systems |

### Usage Examples (v2.27)

```bash
# Multi-level security loop
ralph security-loop src/                    # Default: 10 rounds, hybrid
ralph security-loop . --max-rounds 5        # Custom rounds
ralph secloop src/ --yolo                   # Auto-approve all
@secloop src/auth/ --strict                 # Manual approval for all

# Slash command
/security-loop src/
@secloop .
```

## Anthropic Best Practices (v2.26)

The following directives are from Anthropic's official Claude 4 best practices documentation:

<investigate_before_answering>
Never speculate about code you have not opened. If the user
references a specific file, you MUST read the file before
answering. Make sure to investigate and read relevant files BEFORE
answering questions about the codebase. Never make any claims about
code before investigating unless you are certain of the correct
answer - give grounded and hallucination-free answers.
</investigate_before_answering>

<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the tool calls,
make all of the independent tool calls in parallel. Prioritize calling tools simultaneously
whenever the actions can be done in parallel rather than sequentially.
</use_parallel_tool_calls>

<default_to_action>
By default, implement changes rather than only suggesting them. If the user's intent is unclear,
infer the most useful likely action and proceed, using tools to discover any missing details
instead of guessing.
</default_to_action>

<avoid_overengineering>
Avoid over-engineering. Only make changes that are directly requested or clearly necessary.
Keep solutions simple and focused. Don't add features, refactor code, or make "improvements"
beyond what was asked.
</avoid_overengineering>

<code_exploration>
ALWAYS read and understand relevant files before proposing code edits. Do not speculate about
code you have not inspected. Be rigorous and persistent in searching code for key facts.
</code_exploration>

## v2.26 Key Changes (Prefix-Based Slash Commands)

- **`@` PREFIX SYSTEM**: All slash commands now support `@prefix` invocation (e.g., `@orch`, `@sec`)
- **CATEGORY COLORS**: Commands grouped by category with color coding
- **`/commands` HELP**: New command to list all available commands by category
- **`@diagram` MERMAID**: Generate Mermaid diagrams for documentation
- **TASK PERSISTENCE**: Tasks survive session restarts (`.ralph/tasks.json`)
- **ANTHROPIC DIRECTIVES**: Official Claude 4 best practices integrated

### Prefix System (v2.26)

| Category | Color | Commands |
|----------|-------|----------|
| **Orchestration** | Purple | `@orch`, `@clarify`, `@loop` |
| **Review** | Red | `@sec`, `@bugs`, `@tests`, `@ref`, `@review`, `@par`, `@adv` |
| **Research** | Blue | `@research`, `@lib`, `@mmsearch`, `@ast`, `@browse`, `@img` |
| **Tools** | Green | `@gates`, `@mm`, `@imp`, `@audit`, `@retro`, `@cmds`, `@diagram` |

### Usage Examples (v2.26)

```bash
# Prefix invocation (NEW)
@orch "Implement OAuth2"       # Full orchestration
@sec src/                      # Security audit
@lib "React 19 hooks"          # Library documentation
@diagram "architecture"        # Generate Mermaid diagram
@cmds                          # List all commands

# Traditional invocation (still works)
/orchestrator "Implement OAuth2"
/security src/
/library-docs "React 19 hooks"
```

## v2.25 Key Changes (Search Hierarchy + Context7 + dev-browser)

- **SEARCH HIERARCHY**: WebSearch (native, FREE) → MiniMax MCP (8% fallback)
- **CONTEXT7 MCP**: Library/framework documentation search (indexed docs, optimized tokens)
- **DEV-BROWSER**: Primary browser automation (17% faster, 39% cheaper than Playwright)
- **GEMINI SCOPE CHANGE**: ONLY for short, punctual tasks (NOT for research or long-context)
- **NEW CLI COMMANDS**: `ralph library`, `ralph browse`
- **NEW SLASH COMMANDS**: `/library-docs`, `/browse`

### Search Tool Hierarchy (v2.25)

| Priority | Tool | Cost | Use When |
|----------|------|------|----------|
| 1 | WebSearch (native) | FREE | Default for all web research |
| 2 | Context7 MCP | Optimized | Library/framework documentation |
| 3 | MiniMax MCP | 8% | Fallback + specialized queries |
| 4 | Gemini CLI | ~60% | Short punctual tasks ONLY |

```
Search Decision Tree:
┌────────────────────────────────────────┐
│ Is it about a library/framework?       │
├────────────────────────────────────────┤
│ YES → Context7 MCP → MiniMax fallback  │
│ NO  → WebSearch → MiniMax fallback     │
└────────────────────────────────────────┘
Gemini: ONLY for short, punctual tasks
```

### New Commands (v2.25)

```bash
# Library documentation (Context7 MCP)
ralph library "React 19 useTransition"
ralph lib "Next.js 15 app router"
ralph docs "TypeScript generics"

# Browser automation (dev-browser)
ralph browse https://example.com --snapshot
ralph browse localhost:3000 --screenshot

# Slash commands
/library-docs React hooks best practices
/browse https://docs.react.dev
```

### Browser Automation (v2.25)

| Tool | Speed | Cost | Use When |
|------|-------|------|----------|
| dev-browser | **+17%** | **-39%** | Primary for all browser tasks |
| Playwright MCP | Baseline | Baseline | Complex automation fallback |

### Cost Optimization (v2.25)

| Subscription | Included Tools | Priority |
|--------------|----------------|----------|
| Claude Max 20x | WebSearch (native), WebFetch | PRIMARY |
| MiniMax Coding Plans | web_search, understand_image | SECONDARY |
| Gemini | CLI only | SHORT TASKS ONLY |

---

## v2.24.2 Key Changes (Complete Security Hardening)

| Fix | CWE | Severity | Description |
|-----|-----|----------|-------------|
| Command Substitution Block | CWE-78 | HIGH | Block `$()` and backticks before path expansion |
| Canonical Path Validation | CWE-59 | HIGH | Validate resolved path after symlink resolution |
| Decompression Bomb Protection | CWE-400 | HIGH | Post-download size check + pixel dimension validation |
| Structured Security Logging | CWE-778 | MEDIUM | JSON audit trail in `~/.ralph/security-audit.log` |
| Tmpdir Permission Verification | CWE-362 | MEDIUM | TOCTOU race condition mitigation |

## v2.24.1 Security Hardening

| Fix | CWE | Description |
|-----|-----|-------------|
| URL Validation | CWE-20 | `curl --max-filesize 20MB` + `file --mime-type` validation |
| Path Allowlist | CWE-22 | User confirmation for files outside project root |
| Prompt Injection | CWE-94 | Heredoc blocks + SECURITY INSTRUCTION markers |
| Doc Guardrails | CWE-1325 | Security sections in `/minimax-search`, `/image-analyze` |

## v2.24 Key Changes

- **MINIMAX MCP WEB_SEARCH**: 8% cost web research via MCP protocol
- **MINIMAX MCP UNDERSTAND_IMAGE**: New image analysis capability (screenshots, UI, diagrams)
- **GEMINI DEPRECATION**: Research queries migrate to MiniMax (87% cost savings)
- **NEW CLI COMMANDS**: `ralph websearch`, `ralph image`
- **NEW SLASH COMMANDS**: `/minimax-search`, `/image-analyze`

### Research Tools (v2.24)

| Tool | Use | Cost |
|------|-----|------|
| `mcp__MiniMax__web_search` | Web research | ~8% |
| `mcp__MiniMax__understand_image` | Screenshot/UI analysis | ~10% |

```bash
# Web search
ralph websearch "React 19 features 2025"

# Image analysis
ralph image "Describe error" /tmp/screenshot.png

# Slash commands
/minimax-search "query"
/image-analyze "prompt" /path/to/image
```

### Cost Comparison

| Research Method | Cost | Quality |
|-----------------|------|---------|
| MiniMax MCP | ~8% | 74% SWE-bench |
| Gemini CLI | ~60% | Variable |
| WebSearch | Free | US-only |

## v2.23 Key Changes

- **AST-GREP MCP**: Structural code search via MCP (~75% less tokens)
- **HYBRID SEARCH**: Combines ast-grep (patterns) + Explore agent (semantic)
- **SEARCH STRATEGY**: Use /ast-search for intelligent tool selection
- **TOKEN OPTIMIZATION**: AST-based search reduces token usage significantly

### Search Tools (v2.23)

| Query Type | Tool | Example | Token Savings |
|------------|------|---------|---------------|
| Exact pattern | ast-grep MCP | `console.log($MSG)` | ~75% less |
| Code structure | ast-grep MCP | `async function $NAME` | ~75% less |
| Semantic/context | Explore agent | "authentication functions" | Variable |
| Hybrid | /ast-search | Combines both | Optimized |

### Pattern Syntax

| Pattern | Meaning | Example |
|---------|---------|---------|
| `$VAR` | Single AST node | `console.log($MSG)` |
| `$$$` | Multiple nodes | `function($$$)` |
| `$$VAR` | Optional nodes | `async $$AWAIT function` |

```bash
# CLI usage
ralph ast 'console.log($MSG)' src/
ralph ast 'async function $NAME' .

# Slash command (hybrid)
/ast-search "authentication functions"
```

## v2.22 Key Changes

- **STARTUP VALIDATION**: `startup_validation()` checks critical tools at every command
- **ON-DEMAND VALIDATION**: `require_tool()` blocks with installation instructions
- **TOOL CATEGORIES**: Critical, Feature, Quality Gates with appropriate validation levels
- **CLEAR ERRORS**: ASCII box format with exact install commands

### Tool Validation Behavior

| Category | Startup | On-Demand | Blocking |
|----------|---------|-----------|----------|
| Critical (claude, jq, git) | Warning | Error + Exit | Yes |
| Feature (wt, gh, mmc, codex, gemini, sg) | Info | Error + Exit | When needed |
| Quality Gates (9 languages) | Count | Warning | No (graceful) |

### Quality Gate Tools (9 Languages)

| Language | Tools | Install |
|----------|-------|---------|
| TypeScript/JavaScript | npx, tsc | `brew install node` |
| Python | pyright, ruff | `npm i -g pyright && pip install ruff` |
| Go | go, staticcheck | `brew install go` |
| Rust | cargo | `brew install rust` |
| Solidity | forge, solhint | `foundryup && npm i -g solhint` |
| Swift | swiftlint | `brew install swiftlint` |
| JSON | jq | `brew install jq` |
| YAML | yamllint | `pip install yamllint` |

## v2.21 Key Changes

- **SELF-UPDATE**: `ralph self-update` syncs scripts from repo to ~/.local/bin/
- **PRE-MERGE VALIDATION**: `ralph pre-merge` validates shellcheck + versions + tests before PR
- **INTEGRATIONS CHECK**: `ralph integrations` shows status of all tools (Greptile always OPTIONAL)
- **COMMIT PREFIX**: Per-agent commit prefixes for consistent commit messages (security:, test:, ui:, etc.)
- **MODEL BY TASK**: Optimized model selection based on efficiency analysis (see below)

## Model Configuration by Task Type (v2.21)

Based on efficiency analysis prioritizing: **quality > speed > rework > context**

| Task Type | Model | Why |
|-----------|-------|-----|
| **Exploration** | MiniMax | 1M context, 8% cost, 74% SWE-bench |
| **Implementation** | Sonnet | Balanced quality/speed for 85% of tasks |
| **Review** | Opus | Surgical precision, catches bugs others miss |
| **Validation** | MiniMax | Second opinion at Opus quality, 8% cost |

```bash
# Environment variables in ralph
EXPLORATION_MODEL="minimax"     # Research, docs
IMPLEMENTATION_MODEL="sonnet"   # Features, tests
REVIEW_MODEL="opus"             # Pre-merge critical
VALIDATION_MODEL="minimax"      # Parallel review
```

**Why NOT Haiku?** Rework rate >30% cancels cost savings for code tasks.

## v2.20 Key Changes

- **WORKTREE WORKFLOW**: Git worktree isolation for features via `ralph worktree`
- **HUMAN-IN-THE-LOOP**: Orchestrator asks user about worktree isolation (Step 2b)
- **MULTI-AGENT PR REVIEW**: Claude Opus + Codex GPT-5 review before merge
- **ONE WORKTREE PER FEATURE**: Multiple subagents share same worktree
- **WorkTrunk Integration**: Required for worktree management (`brew install max-sixty/worktrunk/wt`)

## v2.19 Key Changes

- **VULN-001 FIX**: escape_for_shell() now uses `printf %q` (prevents command injection)
- **VULN-003 FIX**: Improved rm -rf regex patterns in git-safety-guard.py
- **VULN-004 FIX**: validate_path() uses `realpath -e` (resolves symlinks)
- **VULN-005 FIX**: Log files now chmod 600 (user-only read/write)
- **VULN-008 FIX**: All scripts start with `umask 077` (secure file creation)

## v2.17 Key Changes

- **Security Hardening**: All user inputs validated and shell-escaped
- **Enhanced validate_path()**: Blocks control chars, path traversal attacks
- **New validate_text_input()**: Validates non-path inputs (tasks, queries)
- **Safe JSON Construction**: Uses jq for all JSON building in mmc

## v2.16 Key Changes

- **Auto Plan Mode**: Automatically enters `EnterPlanMode` for non-trivial tasks
- **AskUserQuestion**: Uses native Claude tool for interactive MUST_HAVE/NICE_TO_HAVE questions
- **Deep Clarification**: New skill for comprehensive task understanding

## Mandatory Flow (8 Steps)

```
0. AUTO-PLAN    → EnterPlanMode (automatic for non-trivial)
1. /clarify     → AskUserQuestion (MUST_HAVE + NICE_TO_HAVE)
2. /classify    → Complexity 1-10
2b. WORKTREE    → Ask user: "¿Requiere worktree aislado?" (v2.20)
3. PLAN         → Write plan, get user approval
4. @orchestrator → Delegate to subagents (in worktree if selected)
5. ralph gates  → Quality gates (9 languages)
6. /adversarial → 2/3 consensus (complexity >= 7)
7. /retrospective → Propose improvements
7b. PR REVIEW   → If worktree: ralph worktree-pr (Claude + Codex review)
→ VERIFIED_DONE
```

## Clarification Philosophy

**The key to successful agentic coding is MAXIMUM CLARIFICATION before implementation.**

- **NEVER assume** - always use `AskUserQuestion`
- **MUST_HAVE questions** are blocking - cannot proceed without answers
- **NICE_TO_HAVE questions** can assume defaults if skipped
- **Enter Plan Mode** automatically for any non-trivial task

## Iteration Limits (v2.32 Extended)

| Model | Max Iter | Use Case | Change from v2.31 |
|-------|----------|----------|-------------------|
| Claude | **25** | Complex reasoning | +10 iterations |
| MiniMax M2.1 | **50** | Standard (2x) | +20 iterations |
| MiniMax-lightning | **100** | Extended (4x) | +40 iterations |

## CRITICAL: Ralph Loop Pattern

**ALL tasks, subagents, tools, and MCPs MUST follow the Ralph Loop pattern:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH LOOP PATTERN                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────┐    ┌──────────────┐    ┌─────────────────┐      │
│   │ EXECUTE  │───▶│   VALIDATE   │───▶│ Quality Passed? │      │
│   │   Task   │    │ (hooks/gates)│    └────────┬────────┘      │
│   └──────────┘    └──────────────┘             │               │
│                                          NO ◀──┴──▶ YES        │
│                                           │         │          │
│                          ┌────────────────┘         │          │
│                          ▼                          ▼          │
│                   ┌─────────────┐          ┌──────────────┐    │
│                   │  ITERATE    │          │ VERIFIED_DONE│    │
│                   │ (max 15/30) │          │   (output)   │    │
│                   └──────┬──────┘          └──────────────┘    │
│                          │                                     │
│                          └──────────▶ Back to EXECUTE          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Iteration Limits by Model (v2.32 Extended):**
| Model | Max Iterations | Rationale | Change |
|-------|----------------|-----------|--------|
| Claude (Sonnet/Opus) | **25** | Complex reasoning, higher accuracy per iteration | +10 from v2.31 |
| MiniMax M2.1 | **50** | Good quality at 8% cost, needs more iterations | +20 from v2.31 |
| MiniMax-lightning | **100** | Fast model, compensate with more iterations | +40 from v2.31 |

**Quality Hooks (automatic enforcement):**
- `quality-gates.sh` → Post-Edit/Write: tsc, eslint, pyright, ruff, etc. (9 languages)
- `git-safety-guard.py` → Pre-Bash: validates git commands for safety

**Subagent Configuration:**
```yaml
# Primary: Sonnet manages all Task() subagents
Task:
  subagent_type: "general-purpose"
  model: "sonnet"  # MANDATORY - Haiku causes infinite retries
  run_in_background: true
  prompt: "Primary task execution"

# Secondary: MiniMax for second opinion / validation
Task:
  subagent_type: "minimax-reviewer"
  model: "sonnet"  # Sonnet MANAGES the call to mmc
  run_in_background: true
  prompt: 'mmc --query "Second opinion on: $TOPIC"'
```

**Why Sonnet + MiniMax?**
- **Sonnet** (60% cost): Manages subagents reliably, no infinite loops
- **MiniMax** (8% cost): Second opinion with Opus-level quality (74% SWE-bench)
- **Haiku** (NOT recommended): 30%+ rework rate cancels cost savings

## Quick Commands

```bash
# CLI
ralph orch "task"         # Full orchestration (8 steps)
ralph adversarial src/    # 2/3 consensus
ralph parallel src/       # 6 subagents
ralph security src/       # Security audit
ralph bugs src/           # Bug hunting
ralph gates               # Quality gates
ralph loop "task"         # Loop (15 iter)
ralph loop --mmc "task"   # Loop (30 iter)
ralph retrospective       # Self-improvement

# Git Worktree + PR Workflow (v2.20)
ralph worktree "task"     # Create worktree + Claude
ralph worktree-pr <branch> # PR + multi-agent review
ralph worktree-merge <pr>  # Approve and merge
ralph worktree-fix <pr>    # Apply review fixes
ralph worktree-close <pr>  # Close and cleanup
ralph worktree-status      # Show worktree status
ralph worktree-cleanup     # Clean merged worktrees

# Maintenance (v2.21)
ralph self-update          # Sync scripts from repo
ralph pre-merge            # Validate before PR
ralph integrations         # Show tool status (Greptile optional)

# MiniMax
mmc                       # Launch with MiniMax
mmc --loop 30 "task"      # Extended loop

# Slash Commands (Claude Code)
/orchestrator /clarify /full-review /parallel
/security /bugs /unit-tests /refactor
/research /minimax /gates /loop
/adversarial /retrospective /improvements
```

## Native Claude Tools (v2.16+)

```yaml
# Automatic for non-trivial tasks
EnterPlanMode: {}

# Intensive clarification
AskUserQuestion:
  questions:
    - question: "What is the primary goal?"
      header: "Goal"
      multiSelect: false
      options:
        - label: "New feature"
          description: "Adding new functionality"
        - label: "Bug fix"
          description: "Correcting behavior"

# Exit only when plan approved
ExitPlanMode: {}
```

## Agents (9) with Model Assignment

```bash
# Critical tasks (Opus - surgical precision)
@orchestrator       # Opus - Coordinator (uses EnterPlanMode + AskUserQuestion)
@security-auditor   # Opus - Security requires maximum accuracy
@debugger           # Opus - Bug detection needs deep reasoning

# Implementation tasks (Sonnet - balanced)
@code-reviewer      # Sonnet - Balanced for code reviews
@test-architect     # Sonnet - Test generation
@refactorer         # Sonnet - Refactoring
@frontend-reviewer  # Sonnet - UI/UX reviews

# Cost-effective tasks (MiniMax - 8% cost)
@docs-writer        # MiniMax - Long context for documentation
@minimax-reviewer   # MiniMax - Second opinion/validation
```

## Skills (v2.20)

```bash
deep-clarification  # Intensive AskUserQuestion patterns
task-classifier     # Complexity 1-10 routing
retrospective       # Self-improvement analysis
worktree-pr         # Git worktree + PR workflow (v2.20)
```

## Aliases

```bash
rh=ralph rho=orch rhr=review rhs=security
rhb=bugs rhu=unit-tests rhg=gates rha=adversarial
mm=mmc mml="mmc --loop 30"
```

## Completion

`VERIFIED_DONE` = plan approved + all MUST_HAVE answered + classified + implemented + gates passed + adversarial passed (if critical) + retrospective done
