# Multi-Agent Ralph v2.83.1

> "Me fail English? That's unpossible!" - Ralph Wiggum

**Smart Memory-Driven Orchestration** with parallel memory search, RLM-inspired routing, quality-first validation, **checkpoints**, **agent handoffs**, local observability, autonomous self-improvement, **Dynamic Contexts**, **Eval Harness (EDD)**, **Cross-Platform Hooks**, **Claude Code Task Primitive integration**, **Plan Lifecycle Management**, **adversarial-validated hook system**, **Claude Code Documentation Mirror**, **GLM-4.7 PRIMARY**, **Dual Context Display System**, **full CLI implementation**, **Automatic Context Compaction**, **Intelligent Command Routing**, and **Hook System v2.83.1** (100% validated, race-condition-free, TypeScript caching).

> **🆕 v2.83.1**: **Hook System 5-Phase Audit Complete** - 100% validation achieved. Eliminated 4 race conditions with atomic file locking, fixed 3 JSON malformations, added TypeScript caching (80-95% speedup), multilingual support (EN/ES), 5 new critical hooks (`orchestrator-auto-learn.sh`, `promptify-security.sh`, `parallel-explore.sh`, `recursive-decompose.sh`, `todo-plan-sync.sh`). All 83 hooks production-ready.

> **v2.82.0**: **Intelligent Command Router Hook** - Analyzes prompts and suggests optimal commands. Multilingual support (English + Spanish). Confidence-based filtering (≥ 80%). See [docs/command-router/README.md](docs/command-router/README.md) for details.

> **v2.81.1**: Fixed critical compaction hooks issue - `PostCompact` does NOT exist in Claude Code. Use `PreCompact` for saving state and `SessionStart` for restoring. See [docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md](docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md) for critical information.

---

## Context7 MCP Auto-Usage Policy

> **IMPORTANT**: Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps **without me having to explicitly ask**.

### When to Use Context7 MCP Automatically

| Scenario | Action |
|----------|--------|
| **Library Documentation** | Query docs for any library/framework (e.g., /supabase/supabase) |
| **API Reference** | Get API methods, parameters, examples |
| **Code Generation** | Generate boilerplate using latest API patterns |
| **Setup/Configuration** | Get installation and setup instructions |
| **Troubleshooting** | Find solutions for library-specific issues |

### Usage Pattern

```javascript
// User request: "Implement basic authentication with Supabase"
// Claude AUTO-uses Context7 MCP:
// 1. Resolve library: /supabase/supabase
// 2. Query: "How to implement basic authentication with email/password?"
// 3. Generate code using latest API patterns

import { createClient } from '@supabase/supabase-js'

// Context7-fetched code pattern...
```

### Context7 MCP Tools

| Tool | Purpose |
|------|---------|
| `resolve-library-id` | Get exact Context7 library ID from package name |
| `query-docs` | Query documentation for code examples, API reference |

**Never wait for user to request docs** - if they mention a library or framework, automatically fetch its docs via Context7 MCP.

---

## Language Policy (Politica de Idioma)

> **IMPORTANT**: This repository follows English-only documentation standards.

| Content Type | Language | Notes |
|--------------|----------|-------|
| **Code** | English | Variables, functions, classes, comments |
| **Documentation** | English | README.md, CLAUDE.md, AGENTS.md, CHANGELOG.md |
| **Commit Messages** | English | Conventional commits format |
| **Code Comments** | English | Inline documentation |
| **Pull Requests** | English | Titles, descriptions, reviews |

### Exception for Spanish-Speaking Users

- **Prompt/Chat Responses**: Claude may respond in Spanish when the user writes in Spanish
- **README.es.md**: Spanish translation available for initial understanding
- **Technical discussions**: Should remain in English for consistency

### Why English-Only?

1. **Global Collaboration**: English is the universal language for software development
2. **Searchability**: English documentation is easier to find and index
3. **Tooling Compatibility**: Linters, formatters, and AI tools work best with English
4. **Onboarding**: New contributors can understand the codebase immediately

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

# v2.66.8: Claude Code Documentation (NEW)
/docs hooks           # Read hooks documentation
/docs mcp             # Read MCP documentation
/docs what's new      # See recent doc changes
/docs changelog       # Claude Code release notes

# v2.51: Checkpoints (Time Travel)
ralph checkpoint save "before-refactor" "Pre-auth module refactoring"
ralph checkpoint restore "before-refactor"

# v2.51: Handoffs (Agent-to-Agent)
ralph handoff transfer --from orchestrator --to security-auditor --task "Audit auth module"
ralph handoff agents   # List available agents

# v2.63: Dynamic Contexts
ralph context dev       # Development mode (code first)
ralph context review    # Code review mode (analysis)
ralph context research  # Research mode (exploration)
ralph context debug     # Debug mode (investigation)

# v2.69: GLM-4.7 MCP Ecosystem (NEW)
/glm-mcp diagnose ~/error.png    # Diagnose error screenshot
/glm-mcp diagram ~/arch.png      # Understand architecture diagram
/glm-mcp search "React 2026"     # Web search
/glm-mcp structure github/repo   # Repo structure
/glm-4.7 "Review this code"      # Direct GLM-4.7 query
/glm-web-search "latest news"    # GLM web search
```

---

## Hook System v2.83.1 ✅ 100% VALIDATED

**Status**: 5-phase audit complete. All 83 hooks production-ready with race-condition-free operations.

### Audit Results

```
╔══════════════════════════════════════════════════════════════════════════╗
║                    v2.83.1 HOOK SYSTEM AUDIT                             ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  Phase 1: Critical Fixes              ✅ 6/6 items     (100%)            ║
║  ├── Race conditions eliminated       ✅ 4/4 fixed     (100%)            ║
║  ├── JSON malformations fixed         ✅ 3/3 fixed     (100%)            ║
║  ├── Timeouts added                   ✅ 38 hooks      (100%)            ║
║  └── Invalid hooks archived           ✅ 1 archived    (100%)            ║
║                                                                          ║
║  Phase 2: Robustness                  ✅ 6/6 items     (100%)            ║
║  ├── TypeScript cache                 ✅ 80-95% faster                   ║
║  ├── Multilingual support             ✅ EN/ES (20+ ext)                 ║
║  ├── File locking                     ✅ 2 critical hooks                ║
║  └── Security hardening               ✅ umask 077 (38 hooks)            ║
║                                                                          ║
║  Phase 3: Documentation               ✅ 4/4 items     (100%)            ║
║  ├── New hooks created                ✅ 2 hooks                         ║
║  ├── Hooks documented                 ✅ +24 hooks                       ║
║  └── Settings.json example            ✅ 41 hooks                        ║
║                                                                          ║
║  Phase 4: Optimization                ✅ 5/5 items     (100%)            ║
║  ├── File extensions                  ✅ 8 new (20 total)                ║
║  ├── Rate limiting                    ✅ GLM-4.7 API                     ║
║  └── Structured logging               ✅ JSON format                     ║
║                                                                          ║
║  Phase 5: Testing                     ✅ 6/6 items     (100%)            ║
║  ├── Syntax validation                ✅ 83/83 hooks   (100%)            ║
║  ├── JSON parseability                ✅ 83/83 hooks   (100%)            ║
║  ├── Integration tests                ✅ 18/18 tests   (100%)            ║
║  └── Overall validation               ✅ 100% (target: 95%)              ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### Key Improvements

#### 1. Race Condition Elimination

**Atomic File Locking Pattern**:
```bash
# Using mkdir for atomic lock acquisition
acquire_lock() {
    local lock_dir="$1"
    local timeout="${2:-10}"
    while [ $timeout -gt 0 ]; do
        if mkdir "$lock_dir" 2>/dev/null; then
            trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
            return 0
        fi
        sleep 1; ((timeout--))
    done
    return 1
}
```

Applied to:
- `promptify-security.sh` - Log rotation
- `orchestrator-auto-learn.sh` - plan-state.json updates
- `checkpoint-smart-save.sh` - Checkpoint operations
- `quality-gates-v2.sh` - Cache operations

#### 2. TypeScript Compilation Cache

**Cache Implementation**:
```bash
get_cache_key() {
    local file="$1"
    local mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
    local hash=$(md5sum "$file" 2>/dev/null | cut -d' ' -f1 || md5 -q "$file" 2>/dev/null)
    echo "${mtime}_${hash}"
}
```

- **Performance**: 80-95% reduction in TypeScript compile times
- **Storage**: `~/.ralph/cache/typescript/` (1000 entry LRU)
- **Invalidation**: Automatic based on file mtime + content hash

#### 3. Multilingual Support

**Spanish Keywords Added** to `fast-path-check.sh`:
- `arreglar`, `corregir` - fix
- `cambio simple`, `cambio menor` - simple/minor change
- `renombrar` - rename
- `actualizar` - update
- `limpiar` - cleanup

**Supported File Extensions** (20 total):
- TypeScript/JavaScript: `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`
- Vue/Svelte: `.vue`, `.svelte`
- Python: `.py`
- PHP: `.php`
- Ruby: `.rb`
- Go: `.go`
- Rust: `.rs`
- Java/Kotlin: `.java`, `.kt`

#### 4. New Critical Hooks (5)

| Hook | Event | Matcher | Purpose |
|------|-------|---------|---------|
| `orchestrator-auto-learn.sh` | PreToolUse | Task | Detect knowledge gaps, trigger curator |
| `promptify-security.sh` | PreToolUse | Task | Security validation for prompts |
| `parallel-explore.sh` | PostToolUse | Task | Launch 5 concurrent exploration tasks |
| `recursive-decompose.sh` | PostToolUse | Task | Trigger sub-orchestrators |
| `todo-plan-sync.sh` | PostToolUse | TodoWrite | Sync todos with plan-state.json |

#### 5. Security Hardening

- `umask 077` applied to 38 hooks (files created with 700 permissions)
- Removed insecure `.zshrc` API key extraction pattern
- Sensitive data redaction in logs (passwords, tokens, API keys)
- Input validation: 100KB max size for all hooks

### Hook Registration Status

```
User Settings.json:     39 hooks registered
Project hooks dir:      83 hooks available
Coverage:              47% (39/83)
```

**Note**: Only critical hooks are auto-registered to avoid performance overhead. Additional hooks available in `.claude/hooks/` can be manually registered.

---

## Swarm Mode (v2.81.1)

**Swarm mode** enables parallel multi-agent execution for faster, more comprehensive task completion. When enabled, commands spawn specialized teammates that work simultaneously on different aspects of a task.

### How Swarm Mode Works

```
User invokes command
       ↓
┌──────────────────────────────────────┐
│  1. Create Team (spawnTeam)           │
│  2. Spawn N Teammates (Task)          │
│  3. Create Tasks (TaskCreate)         │
│  4. Assign Tasks (TaskUpdate)          │
│  5. Coordinate via TeammateTool       │
└──────────────────────────────────────┘
       ↓
   Parallel Execution (background)
       ↓
  Results Consolidated
```

### Commands with Swarm Mode

| Command | Team Size | Specialization | Speedup |
|---------|-----------|----------------|---------|
| `/orchestrator` | 4 agents | Analysis, planning, implementation | 3x |
| `/loop` | 4 agents | Execute, validate, quality check | 3x |
| `/edd` | 4 agents | Capability, behavior, non-functional checks | 3x |
| `/bug` | 4 agents | Analyze, reproduce, locate, fix | 3x |
| `/adversarial` | 4 agents | Challenge, identify gaps, validate | 3x |
| `/parallel` | 7 agents | 6 review aspects + coordination | 6x |
| `/gates` | 6 agents | 5 language groups + coordination | 3x |

### Enabling Swarm Mode

Swarm mode is **enabled by default** for all supported commands. To use:

```bash
# Automatic swarm mode (default)
/orchestrator "Implement feature X"

# Manual override - disable swarm mode
/orchestrator "Simple task" --no-swarm

# Custom teammate count
/parallel "Complex task" --teammates 10
```

### Configuration

Swarm mode requires:

```json
{
  "permissions": {
    "defaultMode": "delegate"
  }
}
```

**Note**: Environment variables (`CLAUDE_CODE_AGENT_*`) are set **dynamically** by Claude Code when spawning teammates. No manual configuration needed.

### Team Composition Example

Each command spawns specialized teammates:

```yaml
/orchestrator "Implement feature"
├── Lead: Workflow coordinator
├── Teammate 1: Requirements analyst
├── Teammate 2: Implementation specialist
└── Teammate 3: Quality validation specialist
```

### Communication

Teammates communicate via built-in mailbox system:

```yaml
SendMessage:
  type: "message"
  recipient: "team-lead"
  content: "Implementation complete, found edge case"
```

### Task Coordination

All teammates share a unified task list:

```bash
~/.claude/tasks/<team-name>/tasks.json
```

### Background Execution

All swarm mode commands run in background:

```yaml
Task:
  run_in_background: true  # Always enabled for swarm mode
  team_name: "command-team"
  mode: "delegate"
```

### Hook Integration

The `auto-background-swarm.sh` hook automatically detects Task tool usage and suggests swarm mode when applicable.

### Documentation

- **Integration Plan**: `docs/architecture/SWARM_MODE_INTEGRATION_PLAN_v2.81.1.md`
- **Environment Investigation**: `docs/architecture/SWARM_MODE_ENV_INVESTIGATION_v2.81.1.md`
- **Test Validation**: `tests/swarm-mode/test-phase-1-validation.sh`
- **Usage Guide**: `docs/swarm-mode/SWARM_MODE_USAGE_GUIDE.md`
- **Consolidated Audits**: `docs/swarm-mode/CONSOLIDATED_AUDITS_v2.81.1.md`
- **Progress Report**: `docs/swarm-mode/INTEGRATION_PROGRESS_REPORT_v2.81.1.md`

### Validation Summary (v2.81.1)

**Integration Tests**: 27/27 tests passing (100%)

**External Audits**:
| Audit | Model | Result | Score |
|-------|-------|--------|-------|
| **Adversarial** | ZeroLeaks-inspired | ✅ PASS | Strong defense |
| **Codex CLI** | gpt-5.2-codex | ✅ PASS | 9.3/10 Excellent |
| **Gemini CLI** | Gemini 3 Pro | ✅ PASS | 9.8/10 Outstanding |

**Production Readiness**: ✅ YES (All 7 commands validated, no critical vulnerabilities, comprehensive documentation)

---

## Repository Structure - v2.81.0

> **Important**: This project follows specific organizational patterns for tests and documentation.

### Directory Layout

```
multi-agent-ralph-loop/
├── docs/                    # All development documentation (English only)
│   ├── analysis/            # Analysis reports
│   ├── architecture/        # Architecture diagrams and design docs
│   ├── context-monitoring/  # Context tracking analysis
│   ├── quality-gates/       # Quality gates and audits
│   └── security/            # Security-related documentation
├── tests/                   # Test suites at PROJECT ROOT (not .claude/tests/)
│   ├── quality-parallel/    # Quality gate validation tests
│   ├── swarm-mode/          # Swarm mode integration tests
│   └── unit/                # Unit tests (Python, JS, etc.)
├── .claude/                 # Claude Code workspace (session data)
│   ├── agents/              # Agent configurations
│   ├── commands/            # Custom commands (/orchestrator, /loop, etc.)
│   ├── hooks/               # Hook scripts (80+ registrations)
│   └── tasks/               # Task primitive storage
└── frontend/                # Frontend application (if applicable)
```

### Test Organization Pattern

**DO**:
- Place tests in `tests/` at project root
- Use descriptive test names: `test-quality-parallel-v3-robust.sh`
- Document test purpose in header comments

**DON'T**:
- Place tests in `.claude/tests/` (legacy location, deprecated)
- Mix test types without clear categorization

**Rationale**: Tests at project root are:
- More discoverable by contributors
- Following standard conventions
- Easier to run independently of Claude Code workspace

### Documentation Creation Pattern

When creating new documentation:

1. **Create folder** under `docs/` named after subject
   - Example: `docs/swarm-mode/`
   - Use lowercase with hyphens for multi-word subjects

2. **Use descriptive filenames**
   - `ANALYSIS.md` - Investigation and analysis
   - `FIX_SUMMARY.md` - Complete fix summaries
   - `VALIDATION_vX.Y.Z.md` - Validation reports with version numbers
   - `IMPLEMENTATION.md` - Implementation guides

3. **Include metadata header**
   ```markdown
   **Date**: YYYY-MM-DD
   **Version**: vX.Y.Z
   **Status**: [ANALYSIS COMPLETE | FIX REQUIRED | RESOLVED]
   ```

4. **Link related documents** using relative paths

### Swarm Mode Configuration (v2.81.0)

Swarm mode requires specific configuration in **claude-sneakpeek/zai** variant:

**Configuration Location**:
- **Settings**: `~/.claude-sneakpeek/zai/config/settings.json` ← USE THIS
- **NOT**: `~/.claude/settings.json` (legacy, unused in zai variant)

**Required Settings**:
```json
{
  "defaultMode": "delegate",
  "defaultModel": "claude-opus-4-5-20251101",
  "teammateCount": 3,
  "swarmTimeoutMinutes": 30
}
```

**Swarm Mode Demo**: See [@NicerInPerson's demo](https://x.com/NicerInPerson/status/2014989679796347375) for live swarm mode execution example.

### External Resources & Inspirations

This project builds upon excellent work from the community:

| Resource | Purpose | Link |
|----------|---------|------|
| **claude-sneakpeek** | Zai variant inspiration, swarm mode implementation | [github.com/mikekelly/claude-sneakpeek](https://github.com/mikekelly/claude-sneakpeek/tree/main) |
| **cc-mirror** | Claude Code documentation mirror patterns | [github.com/numman-ali/cc-mirror](https://github.com/numman-ali/cc-mirror) |
| **everything-claude-code** | Claude Code patterns and examples | [github.com/affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) |
| **claude-code-docs** | Official documentation mirror | [github.com/ericbuess/claude-code-docs](https://github.com/ericbuess/claude-code-docs) |

**Special Thanks**:
- **@mikekelly** for claude-sneakpeek (zai variant) and swarm mode implementation
- **@numman-ali** for cc-mirror documentation patterns
- **@NicerInPerson** for the swarm mode demo showing real-world usage

---

## Core Workflow (12 Steps) - v2.69.0

```
0. EVALUATE     -> 3-dimension classification (FAST_PATH vs STANDARD)
1. CLARIFY      -> AskUserQuestion (MUST_HAVE + NICE_TO_HAVE)
1b. GAP-ANALYST -> Pre-implementation gap analysis (v2.55 auto-learning)
1c. PARALLEL_EXPLORE -> 5 concurrent searches (v2.46)
2. CLASSIFY     -> Complexity 1-10 + Info Density + Context Req
2b. WORKTREE    -> Ask user about isolated worktree (v2.46)
3. PLAN         -> orchestrator-analysis.md -> Plan Mode
3b. PERSIST     -> Write to .claude/orchestrator-analysis.md (v2.44)
3c. PLAN-STATE  -> Initialize plan-state.json (v2.51 schema)
3d. RECURSIVE_DECOMPOSE -> Spawn sub-orchestrators if needed (v2.46)
4. PLAN MODE    -> EnterPlanMode (reads analysis)
5. DELEGATE     -> Route to optimal model (GLM-4.7 PRIMARY for 1-4)
6. EXECUTE-WITH-SYNC -> LSA-VERIFY -> IMPLEMENT -> PLAN-SYNC -> MICRO-GATE
   6a. LSA-VERIFY  -> Lead Software Architect pre-check
   6b. IMPLEMENT   -> Execute (parallel if independent)
   6c. PLAN-SYNC   -> Detect drift, patch downstream (v2.51)
   6d. MICRO-GATE  -> Per-step quality (3-Fix Rule)
7. VALIDATE     -> CORRECTNESS (block) + QUALITY (block) + CONSISTENCY (advisory)
   7a. CORRECTNESS -> Meets requirements? (BLOCKING)
   7b. QUALITY     -> Security, performance, tests? (BLOCKING)
   7c. CONSISTENCY -> Style, patterns? (ADVISORY - v2.46)
   7d. ADVERSARIAL -> Dual model validation (if complexity >= 7)
8. RETROSPECT   -> Analyze and improve
9. CHECKPOINT   -> Optional state save (v2.51)
10. HANDOFF     -> Optional agent transfer (v2.51)
```

**Fast-Path** (complexity <= 3): DIRECT_EXECUTE -> MICRO_VALIDATE -> DONE (3 steps)

**v2.69.0 Key Changes**:
- GLM-4.7 is now PRIMARY for complexity 1-4 tasks
- MiniMax fully DEPRECATED (optional fallback only)
- Auto-learning triggers (v2.55): Repository learning when memory is empty
- Task primitive integration (v2.62): Sync with Claude Code tasks
- Dynamic contexts (v2.63): dev, review, research, debug modes

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

## Claude Code Documentation Mirror (v2.66.8) - NEW

Local mirror of official Claude Code documentation with auto-updates.

```bash
# List all available topics
/docs

# Read specific documentation
/docs hooks           # Hooks reference
/docs mcp             # MCP integration
/docs skills          # Skills documentation
/docs settings        # Configuration reference
/docs memory          # Memory system

# Check sync status
/docs -t              # Show freshness status
/docs -t hooks        # Check + read

# Recent changes
/docs what's new      # Documentation updates
/docs changelog       # Claude Code release notes
```

### Available Topics

| Category | Topics |
|----------|--------|
| **Getting Started** | overview, quickstart, setup, features-overview |
| **Core Features** | hooks, hooks-guide, mcp, memory, skills, sub-agents |
| **Configuration** | settings, model-config, terminal-config, network-config |
| **IDE Integration** | vs-code, jetbrains, devcontainer |
| **Cloud Providers** | amazon-bedrock, google-vertex-ai, microsoft-foundry |
| **CI/CD** | github-actions, gitlab-ci-cd, headless |
| **Security** | security, sandboxing, iam, data-usage |
| **Advanced** | plugins, plugins-reference, statusline, output-styles |

### Auto-Updates

- Documentation syncs automatically when accessed (~0.4s)
- PreToolUse hook triggers git pull on Read operations
- Source: [ericbuess/claude-code-docs](https://github.com/ericbuess/claude-code-docs)

### Installation (if needed)

```bash
curl -fsSL https://raw.githubusercontent.com/ericbuess/claude-code-docs/main/install.sh | bash
```

---

## Dual Context Display System (v2.80.9) - NEW

Comprehensive context monitoring with dual metric display addressing unreliable Claude Code 2.1.19 context window fields.

### Display Format

```
⎇ main* | 🤖 ██████████░░ 391k/200k (195%) | CtxUse: 133k/200k (66.6%) | Free: 22k (10.9%) | Buff 45.0k (22.5%)
          └───────────────── Cumulative ─────┘ └────────────────── Current Window ──────────────────┘
```

### Two Context Metrics

**1. Cumulative Session Progress (`🤖` progress bar)**
- **Source**: `total_input_tokens + total_output_tokens`
- **Purpose**: Show overall session token accumulation
- **Format**: `🤖 391k/200k (195%)`
- **Note**: Can exceed 100% because it includes messages compacted out of current window

**2. Current Window Usage (`CtxUse`)**
- **Source**: Project-specific cache from `/context` command
- **Purpose**: Show actual current window usage (matches `/context` exactly)
- **Format**: `CtxUse: 133k/200k (66.6%) | Free: 22k (10.9%) | Buff 45.0k (22.5%)`
- **Accuracy**: Matches `/context` command output exactly

### Project-Specific Cache

**Cache Location**: `~/.ralph/cache/<project-id>/context-usage.json`

Project ID derived from:
1. Git remote URL (e.g., `alfredolopez80/multi-agent-ralph-loop`)
2. Directory hash (fallback for non-git projects)

**Cache Update Mechanism**:
- **Hook**: `context-from-cli.sh` (UserPromptSubmit)
- **Trigger**: Before each user prompt
- **Action**: Calls `/context` command and parses output
- **Expiry**: 300 seconds (5 minutes) for stale cache detection

**Why `/context` Command?**
- Provides accurate values from Claude Code's internal calculation
- Includes buffer tokens (45k by default) for autocompaction
- Consistent with what users see when they run `/context` manually
- Works around unreliable JSON fields in stdin

### Utility Scripts

| Script | Purpose |
|--------|---------|
| `parse-context-output.sh` | Parse `/context` command output |
| `update-context-cache.sh` | Manual cache update |
| `verify-statusline-context.sh` | Validation script |

### Fallback Strategy

When cache is unavailable or stale:
1. Try stdin JSON `used_percentage` (if 5-95% range, for Zai compatibility)
2. Use cumulative tokens with 75% estimate when maxed out

### Documentation

- **Implementation Report**: `docs/context-monitoring/STATUSLINE_V2.78_IMPLEMENTATION.md`
- **Fix Summary**: `docs/context-monitoring/FIX_SUMMARY.md`
- **Original Analysis**: `docs/context-monitoring/ANALYSIS.md`

---

## Context Simulation Tools (v2.72.1) - NEW

Test and validate the GLM context monitoring system with real-time statusline updates.

### Available Scripts

| Script | Mode | Purpose |
|--------|------|---------|
| `simulate-context.sh` | Interactive | Step-by-step 10% increments with pauses |
| `simulate-context-auto.sh` | Automatic | Continuous simulation with configurable delay |
| `test-context-thresholds.sh` | Testing | Test specific warning thresholds (75%, 85%) |
| `SIMULATION_README.md` | Documentation | Complete usage guide |

### Usage

```bash
# Interactive simulation (press Enter between increments)
./simulate-context.sh

# Automatic simulation with 2 second delay
./simulate-context-auto.sh 2

# Fast automatic simulation (0.5s delay)
./simulate-context-auto.sh 0.5

# Test warning threshold (75%)
./test-context-thresholds.sh 75

# Test critical threshold (85%)
./test-context-thresholds.sh 85
```

### What It Does

1. **Progressive Simulation**: Increments context from 10% → 100% in 10% steps
2. **Real-Time Validation**: Statusline updates live with new format: `🤖 75% · 96K/128K`
3. **Color Thresholds**: Validates color changes (CYAN → GREEN → YELLOW → RED)
4. **Auto-Backup**: Creates `.backup` file before simulation
5. **Easy Restore**: `cp glm-context.json.backup glm-context.json`

### Statusline Format (v2.72.1)

**Before**: `🤖 75%` (percentage only)
**After**: `🤖 75% · 96K/128K` (percentage + exact tokens)

| Percentage | Display Format | Tokens | Color |
|------------|----------------|--------|-------|
| 1-49% | `🤖 X% · XK/128K` | 1K-63K | CYAN |
| 50-74% | `🤖 X% · XK/128K` | 64K-94K | GREEN |
| 75-84% | `🤖 X% · XK/128K` | 96K-107K | YELLOW |
| 85-100% | `🤖 X% · XK/128K` | 108K-128K | RED |

### Thresholds Validation

| Threshold | Percentage | Hook Trigger | Expected Behavior |
|-----------|------------|--------------|-------------------|
| Warning | ≥75% | `context-warning.sh` | YELLOW display + warning message |
| Critical | ≥85% | `context-warning.sh` | RED display + critical warning |
| Auto-compact | ~90% | `PreCompact` | State saved before compaction |

---

## Memory Architecture (v2.49)

```
SMART MEMORY SEARCH (PARALLEL)
+----------+ +----------+ +----------+ +----------+
|claude-mem| | memvid   | | handoffs | | ledgers  |
+----+-----+ +----+-----+ +----+-----+ +----+-----+
     | PARALLEL   | PARALLEL   | PARALLEL   | PARALLEL
     +------------+------------+------------+
                    |
         .claude/memory-context.json
```

**Three Memory Types**:
| Type | Purpose | Storage |
|------|---------|---------|
| **Semantic** | Facts, preferences | `~/.ralph/memory/semantic.json` |
| **Episodic** | Experiences (30-day TTL) | `~/.ralph/episodes/` |
| **Procedural** | Learned behaviors | `~/.ralph/procedural/rules.json` |

### Repository Learner (v2.50) - NEW

```
/repo-learn https://github.com/{owner}/{repo}
```

**What it does**:
1. Acquire repository via git clone or GitHub API
2. Analyze code using AST-based pattern extraction
3. Classify patterns into categories (error_handling, async_patterns, type_safety, architecture, testing, security)
4. Generate procedural rules with confidence scores
5. Enrich `~/.ralph/procedural/rules.json` with deduplication

**Result**: Claude learns best practices from quality repositories and applies them in future implementations.

### Repo Curator (v2.55)

```
/curator "best backend TypeScript repos with clean architecture"
```

**What it does**:
1. **DISCOVERY** -> GitHub API search for candidate repositories
2. **SCORING** -> Quality metrics + Context Relevance (v2.55)
3. **RANKING** -> Top N repos (configurable, max per org)
4. **USER REVIEW** -> Interactive queue for approve/reject
5. **LEARN** -> Extract patterns from approved repos via repository-learner

**Pricing Tiers**:
| Tier | Cost | Features |
|------|------|----------|
| `--tier free` | $0.00 | GitHub API + local scoring |
| `--tier economic` | ~$0.30 | + OpenSSF + GLM-4.7 (DEFAULT) |
| `--tier full` | ~$0.95 | + Claude + Codex adversarial (with fallback) |

**All Scripts (v2.55)**:
| Script | Key Options |
|--------|-------------|
| `curator-discovery.sh` | `--type`, `--lang`, `--query`, `--tier`, `--max-results`, `--output` |
| `curator-scoring.sh` | `--input`, `--output`, `--tier`, `--context` (NEW), `--verbose` |
| `curator-rank.sh` | `--input`, `--output`, `--top-n`, `--max-per-org` |
| `curator-ingest.sh` | `--repo`, `--output-dir`, `--approve`, `--source`, `--depth` |
| `curator-approve.sh` | `--repo`, `--all` |
| `curator-reject.sh` | `--repo`, `--reason` |
| `curator-learn.sh` | `--type`, `--lang`, `--repo`, `--all` |
| `curator-queue.sh` | `--type`, `--lang` |

**Usage**:
```bash
# Full pipeline (economic tier, default)
/curator full --type backend --lang typescript

# Discovery with options
/curator discovery --query "microservice" --max-results 200 --tier free

# Scoring with context relevance (v2.55 NEW)
/curator scoring --context "error handling,retry,resilience"

# Custom ranking
/curator rank --top-n 15 --max-per-org 3

# Show ranking / queue
/curator show --type backend --lang typescript
/curator pending --type backend

# Approve/reject repos
/curator approve nestjs/nest
/curator approve --all
/curator reject some/repo --reason "Low test coverage"

# Execute learning
/curator learn --type backend --lang typescript
/curator learn --repo nestjs/nest
/curator learn --all
```

### Codex Planner (v2.50) - NEW

```
/codex-plan "Design a distributed caching system"
/orchestrator "Implement microservices" --use-codex
```

**What it does**:
1. **CLARIFY** -> AskUser questions (MUST_HAVE + NICE_TO_HAVE)
2. **EXECUTE** -> Codex 5.2 with `xhigh` reasoning
3. **SAVE** -> Plan saved to `http://codex-plan.md`

**Integration with Orchestrator**:
Use `--use-codex` or `--codex` flag to invoke Codex planning:
```bash
/orchestrator "Implement distributed system" --use-codex
/orchestrator "Design microservices architecture" --codex
```

**Requirements**:
- Codex CLI: `npm install -g @openai/codex`
- Access to `gpt-5.2-codex` model

### Checkpoint System (v2.51) - NEW

LangGraph-style "time travel" for orchestration state.

```bash
# Save state before risky operation
ralph checkpoint save "before-auth-refactor" "Pre-authentication module changes"

# List all checkpoints
ralph checkpoint list

# Restore if something goes wrong
ralph checkpoint restore "before-auth-refactor"

# Compare checkpoint vs current state
ralph checkpoint diff "before-auth-refactor"
```

**What it saves**:
| File | Purpose |
|------|---------|
| `plan-state.json` | Current orchestration state |
| `orchestrator-analysis.md` | Planning analysis |
| `git-status.txt` | Uncommitted changes |
| `git-diff.patch` | Unstaged changes as patch |
| `metadata.json` | Checkpoint metadata |

**Storage**: `~/.ralph/checkpoints/<name>/`

### Handoff API (v2.51) - NEW

OpenAI Agents SDK-style explicit agent-to-agent transfers.

```bash
# Transfer task from orchestrator to security-auditor
ralph handoff transfer --from orchestrator --to security-auditor \
    --task "Audit authentication module" \
    --context '{"files": ["src/auth/"]}'

# List available agents
ralph handoff agents

# Validate agent exists
ralph handoff validate debugger

# View handoff history
ralph handoff history
```

**Default Agents (11)**:
| Agent | Model | Capabilities |
|-------|-------|--------------|
| `orchestrator` | opus | planning, classification, delegation, validation |
| `security-auditor` | opus | security, vulnerability-scan, code-review |
| `debugger` | opus | debugging, error-analysis, fix-generation |
| `code-reviewer` | sonnet | code-review, pattern-analysis, quality-check |
| `test-architect` | sonnet | testing, test-generation, coverage-analysis |
| `refactorer` | sonnet | refactoring, pattern-application, code-improvement |
| `frontend-reviewer` | sonnet | frontend, ui-review, accessibility |
| `docs-writer` | sonnet | documentation, readme, api-docs |
| `glm-reviewer` | GLM-4.7 | validation, vision, web search (PRIMARY) |
| `repository-learner` | sonnet | learning, pattern-extraction, rule-generation |
| `repo-curator` | sonnet | curation, scoring, discovery |

**Agent Registry**: `~/.ralph/config/agents.json` (optional override)

### Plan State v2 Schema (v2.51) - NEW

Phases + barriers for strict WAIT-ALL consistency.

```json
{
  "version": "2.51.0",
  "phases": [
    {"phase_id": "clarify", "step_ids": ["1"], "execution_mode": "sequential"},
    {"phase_id": "implement", "step_ids": ["6a", "6b"], "execution_mode": "parallel"}
  ],
  "barriers": {
    "clarify_complete": false,
    "implement_complete": false
  }
}
```

**Automatic Migration**: Run `ralph migrate check` or it auto-migrates at session start.

### Agent-Scoped Memory (v2.51) - NEW

LlamaIndex AgentWorkflow-style isolated memory buffers per agent.

```bash
# Initialize memory for an agent
ralph agent-memory init security-auditor

# Write to agent's memory
ralph agent-memory write security-auditor semantic "Found SQL injection in auth.py:42"
ralph agent-memory write security-auditor working "Currently analyzing user input validation"

# Read agent's memory
ralph agent-memory read security-auditor          # All types
ralph agent-memory read security-auditor semantic # Only semantic

# Transfer memory during handoff (default: relevant)
ralph agent-memory transfer security-auditor code-reviewer relevant

# List all agents with memory buffers
ralph agent-memory list

# Garbage collect expired episodic entries
ralph agent-memory gc
```

**Memory Types**:
| Type | Purpose | TTL |
|------|---------|-----|
| `semantic` | Persistent facts and knowledge | Never expires |
| `episodic` | Experiences and observations | 30 days |
| `working` | Current task context | Session-based |

**Transfer Filters**:
- `all`: Transfer all memory
- `relevant`: Semantic + recent working (default for handoffs)
- `working`: Only working memory

**Storage**: `~/.ralph/agent-memory/<agent_id>/`

### Event-Driven Engine (v2.51) - NEW

LangGraph-style event bus with WAIT-ALL phase barriers.

```bash
# Emit an event
ralph events emit step.complete '{"step_id": "step1"}' orchestrator

# Subscribe to events
ralph events subscribe phase.complete /path/to/handler.sh

# Check barrier status (WAIT-ALL)
ralph events barrier check phase-1

# Wait for barrier (blocks until all steps complete)
ralph events barrier wait phase-1 300  # 300s timeout

# List all barriers and status
ralph events barrier list

# Determine next phase based on state
ralph events route

# Advance to next phase
ralph events advance phase-2

# Show event bus status
ralph events status

# View event history
ralph events history 20
```

**Event Types**:
| Event | Trigger |
|-------|---------|
| `barrier.complete` | Phase barrier satisfied (all steps done) |
| `phase.start` | Phase started |
| `phase.complete` | Phase completed |
| `step.complete` | Individual step completed |
| `handoff.transfer` | Agent-to-agent transfer |

**WAIT-ALL Pattern**:
Phase N+1 **never** starts until ALL sub-steps of Phase N complete. This ensures strict consistency in multi-agent orchestration.

**Storage**: `~/.ralph/events/event-log.jsonl`

### Local Observability (v2.52) - NEW

Query-based status and traceability without external services.

```bash
# Full orchestration status
ralph status

# Compact one-liner
ralph status --compact
# Output: STANDARD Step 3/7 (42%) - in_progress

# Detailed step breakdown
ralph status --steps

# JSON for scripts
ralph status --json | jq '.plan.status'
```

**StatusLine Integration**:
Progress is shown in the statusline automatically:
```
main* | 3/7 42% | [claude-hud metrics]
```

| Icon | Meaning |
|------|---------|
| `📊` | Active plan |
| `🔄` | Executing |
| `⚡` | Fast-path |
| `✅` | Completed |

**Traceability**:
```bash
# Show recent events
ralph trace show 30

# Search for specific events
ralph trace search "handoff"

# Visual timeline
ralph trace timeline

# Export for analysis
ralph trace export csv ./trace-report.csv

# Session summary
ralph trace summary
```

**Event Log**: `~/.ralph/events/event-log.jsonl` (shared with event-bus)

### Autonomous Self-Improvement (v2.55) - NEW

Proactive learning and memory population for higher code quality.

```bash
# Memory system health check
ralph health                    # Full health report
ralph health --compact          # One-line summary
ralph health --json             # JSON output for scripts
ralph health --fix              # Auto-fix critical issues
```

**Health Checks**: Semantic, Procedural, Episodic, Agent-Memory, Curator, Events, Ledgers, Handoffs, Checkpoints

**Auto-Learning Triggers**:
| Condition | Severity | Action |
|-----------|----------|--------|
| ZERO relevant rules (any complexity) | CRITICAL | Learning REQUIRED before implementation |
| <3 rules AND complexity >=7 | HIGH | Learning RECOMMENDED for better quality |

**New Hooks (v2.55)**:
| Hook | Trigger | Purpose |
|------|---------|---------|
| `orchestrator-auto-learn.sh` | PreToolUse (Task) | Detects knowledge gaps, recommends `/curator` |
| `agent-memory-auto-init.sh` | PreToolUse (Task) | Auto-initializes agent memory buffers |
| `semantic-auto-extractor.sh` | Stop | Extracts facts from git diff (functions, classes) |
| `decision-extractor.sh` | PostToolUse | Detects architectural patterns and decisions |
| `curator-suggestion.sh` | UserPromptSubmit | Suggests `/curator` when memory is empty |

**Automatic Extraction**:
- **Semantic**: New functions, classes, dependencies from git diff
- **Decisions**: Design patterns (Singleton, Repository, Factory...), architectural choices (async/await, caching, logging)
- **Source tracking**: `"source": "auto-extract"` with deduplication

### Automated Monitoring (v2.56) - NEW

100% automatic monitoring via hooks - no manual commands needed.

**Automation Hooks (v2.56)**:
| Hook | Trigger | Purpose |
|------|---------|---------|
| `status-auto-check.sh` | PostToolUse (Edit/Write/Bash) | Auto-shows status every 5 operations |
| `checkpoint-smart-save.sh` | PreToolUse (Edit/Write) | Smart checkpoints on risky edits |
| `statusline-health-monitor.sh` | UserPromptSubmit | Health checks every 5 minutes |

**Smart Checkpoint Triggers**:
| Trigger | Condition |
|---------|-----------|
| `high_complexity` | Plan complexity >= 7 |
| `high_risk_step` | Step involves auth/security/payment |
| `critical_file` | Config, settings, .env, database files |
| `security_file` | Files with auth/secret/credential in name |

**Health Checks**:
- Script existence and permissions
- Plan-state JSON validity
- Stuck detection (in_progress > 30 min)
- StatusLine sync verification

---

## Quality-First Validation (v2.46)

```
Stage 1: CORRECTNESS -> Syntax errors (BLOCKING)
Stage 2: QUALITY     -> Type errors (BLOCKING)
Stage 2.5: SECURITY  -> semgrep + gitleaks (BLOCKING)
Stage 3: CONSISTENCY -> Linting (ADVISORY - not blocking)
```

---

## Model Routing (v2.69.0)

| Route | Primary | Secondary | Max Iter |
|-------|---------|-----------|----------|
| FAST_PATH | sonnet | - | 3 |
| STANDARD (1-4) | **GLM-4.7** (PRIMARY) | sonnet | 25 |
| STANDARD (5-6) | sonnet | opus | 25 |
| STANDARD (7-10) | opus | sonnet | 25 |
| PARALLEL_CHUNKS | sonnet (chunks) | opus (aggregate) | 15/chunk |
| RECURSIVE | opus (root) | sonnet (sub) | 15/sub |

**v2.69.0 Changes**:
- ✅ GLM-4.7 is now **PRIMARY** for complexity 1-4 tasks (cost-effective, fast)
- ❌ MiniMax fully **DEPRECATED** (optional fallback only, not recommended)
- ✅ 14 GLM-4.7 MCP tools available for vision, web search, and analysis
- ✅ Multi-model validation: GLM-4.7 + Codex for quality assurance

---

## Commands Reference

```bash
# Core
ralph orch "task"         # Full orchestration
ralph gates               # Quality gates
ralph loop "task"         # Loop (25 iter)
ralph compact             # Manual context save
ralph health              # Memory system health check (v2.55)
ralph health --compact    # One-line health summary
ralph health --fix        # Auto-fix critical issues

# Documentation (v2.66.8 NEW)
/docs                     # List all topics
/docs <topic>             # Read documentation (hooks, mcp, skills, etc.)
/docs -t                  # Check sync status
/docs what's new          # Recent documentation changes
/docs changelog           # Claude Code release notes

# Contexts (v2.63)
ralph context dev         # Development mode
ralph context review      # Code review mode
ralph context research    # Research mode
ralph context debug       # Debug mode
ralph context show        # Show active context
ralph context list        # List all contexts

# Memory (v2.49)
ralph memory-search "query"  # Parallel search
ralph fork-suggest "task"    # Find sessions to fork

# Repository Learning (v2.50)
repo-learn https://github.com/python/cpython          # Learn from repo
repo-learn https://github.com/fastapi/fastapi --category error_handling  # Focused

# Repo Curator (v2.55)
ralph curator full --type backend --lang typescript   # Full pipeline
ralph curator discovery --query "microservice" --max-results 200  # Custom search
ralph curator scoring --context "error handling,retry"  # Context relevance (v2.55)
ralph curator rank --top-n 15 --max-per-org 3         # Custom ranking
ralph curator show --type backend --lang typescript   # View ranking
ralph curator pending --type backend                  # View queue
ralph curator approve nestjs/nest                     # Approve single
ralph curator approve --all                           # Approve all staged
ralph curator reject some/repo --reason "Low quality" # Reject with reason
ralph curator ingest --repo x/y --approve --source "patterns"  # Direct ingest
ralph curator learn --repo nestjs/nest                # Learn specific
ralph curator learn --all                             # Learn all approved

# Codex Planning (v2.50)
codex-plan "Design distributed system"                # Codex planning
/orchestrator "task" --use-codex                      # Orchestrator with Codex

# Checkpoint System (v2.51)
ralph checkpoint save "name" "description"            # Save state
ralph checkpoint restore "name"                       # Restore from checkpoint
ralph checkpoint list                                 # List all checkpoints
ralph checkpoint show "name"                          # Show checkpoint details
ralph checkpoint diff "n1" "n2"                       # Compare checkpoints

# Plan Lifecycle (v2.65.2)
ralph plan show                                       # Show current plan status
ralph plan archive "description"                      # Archive plan and start fresh
ralph plan reset                                      # Reset to empty plan
ralph plan history [n]                                # Show last n archived plans
ralph plan restore <archive-id>                       # Restore from archive

# Handoff API (v2.51)
ralph handoff transfer --from X --to Y --task "desc"  # Agent handoff
ralph handoff agents                                  # List available agents
ralph handoff validate <agent>                        # Validate agent exists
ralph handoff history                                 # View handoff history

# Schema Migration (v2.51)
ralph migrate check                                   # Check if migration needed
ralph migrate run                                     # Execute migration
ralph migrate dry-run                                 # Preview migration

# Agent-Scoped Memory (v2.51)
ralph agent-memory init <agent>                       # Initialize memory buffer
ralph agent-memory write <agent> <type> <content>     # Write to memory
ralph agent-memory read <agent> [type]                # Read from memory
ralph agent-memory transfer <from> <to> [filter]      # Transfer during handoff
ralph agent-memory list                               # List all agents
ralph agent-memory gc                                 # Garbage collect expired

# Event-Driven Engine (v2.51)
ralph events emit <type> [payload]                    # Emit event
ralph events subscribe <type> <handler>               # Subscribe to events
ralph events barrier check <phase>                    # Check WAIT-ALL barrier
ralph events barrier wait <phase> [timeout]           # Wait for barrier
ralph events barrier list                             # List all barriers
ralph events route                                    # Determine next phase
ralph events advance [phase]                          # Advance to next phase
ralph events status                                   # Event bus status
ralph events history [count]                          # Event history

# Observability (v2.52)
ralph status                                          # Full orchestration status
ralph status --compact                                # One-line summary
ralph status --steps                                  # Detailed step breakdown
ralph status --json                                   # JSON output
ralph trace show [count]                              # Recent events
ralph trace search <query>                            # Search events
ralph trace timeline                                  # Visual timeline
ralph trace export [format]                           # Export to JSON/CSV
ralph trace summary                                   # Session summary

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

## Agents (11+)

| Agent | Model | Purpose |
|-------|-------|---------|
| `@orchestrator` | opus | Coordinator |
| `@security-auditor` | opus | Security |
| `@debugger` | opus | Bug detection |
| `@code-reviewer` | sonnet | Reviews |
| `@test-architect` | sonnet | Tests |
| `@refactorer` | sonnet | Refactoring |
| `@frontend-reviewer` | sonnet | UI/UX |
| `@docs-writer` | sonnet | Docs |
| `@glm-reviewer` | GLM-4.7 | Vision, web search, validation |
| `@repository-learner` | sonnet | Learn best practices from repos |
| `@repo-curator` | sonnet | Curate quality repos for learning |

---

## Hooks (83 files, 100% validated) - v2.83.1

> **🆕 NEW v2.82.0**: **Intelligent Command Router Hook** - Analyzes prompts and suggests optimal commands (`/bug`, `/edd`, `/orchestrator`, `/loop`, `/adversarial`, `/gates`, `/security`, `/parallel`, `/audit`). Multilingual support (English + Spanish). Confidence-based filtering (≥ 80%). See [docs/command-router/README.md](docs/command-router/README.md) for details.

> **⚠️ CRITICAL v2.81.2**: PreToolUse hooks now use correct JSON schema with `hookSpecificOutput` wrapper. Fixed validation errors on Edit/Write/Bash operations. See [docs/bugs/PRETOOLUSE_JSON_SCHEMA_FIX_v2.81.2.md](docs/bugs/PRETOOLUSE_JSON_SCHEMA_FIX_v2.81.2.md) for details.

> **⚠️ CRITICAL v2.81.1**: `PostCompact` does NOT exist in Claude Code. Use `PreCompact` for saving state and `SessionStart` for restoring. See [docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md](docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md) for critical information.

> **v2.69.0**: GLM-4.7 now PRIMARY for complexity 1-4 tasks. MiniMax deprecated. `mmc` and `ralph` CLI updated. 14 GLM tools. 26 MCP servers total.

| Event Type | Purpose |
|------------|---------|
| SessionStart | Context preservation at startup, **auto-migrate plan-state** (v2.51), **restore context after compaction** (v2.81.1) |
| PreCompact | Save state before compaction (ONLY compaction event) |
| PostToolUse | Quality gates after Edit/Write/Bash, **verification subagent** (v2.62) |
| PreToolUse | Safety guards before Bash/Skill/Task, **task optimization** (v2.62), **docs auto-update** (v2.66.8) |
| UserPromptSubmit | Context warnings, **command suggestions** (v2.82.0), reminders |
| Stop | Session reports |
| **PostCompact** | ❌ **DOES NOT EXIST** - Feature request #14258 |

### Intelligent Command Router (v2.82.0) - NEW

**Hook**: `command-router.sh` (UserPromptSubmit event)

**Purpose**: Analyze user prompts and intelligently suggest the optimal command based on detected patterns.

**Supported Commands**:
| Command | Use Case | Trigger Patterns | Confidence |
|---------|----------|------------------|------------|
| `/bug` | Systematic debugging | bug, error, fallo, excepción | 90% |
| `/edd` | Feature definition | define, specification, capability | 85% |
| `/orchestrator` | Complex tasks | implement, create, build + multi-step | 85% |
| `/loop` | Iterative tasks | iterate, loop, until, iterar, hasta | 85% |
| `/adversarial` | Spec refinement | spec, refine, edge cases, gaps | 85% |
| `/gates` | Quality validation | quality gates, lint, validation | 85% |
| `/security` | Security audit | security, vulnerability, OWASP | 88% |
| `/parallel` | Comprehensive review | comprehensive review, multiple aspects | 85% |
| `/audit` | Quality audit | audit, health check, auditoría | 82% |

**Features**:
- **Multilingual**: English + Spanish support
- **Confidence-based**: Only suggests when confidence >= 80%
- **Non-intrusive**: Uses `additionalContext` instead of `action: "ask_user"`
- **Security**: Input validation (100KB limit), sensitive data redaction, error trap
- **Configurable**: `~/.ralph/config/command-router.json`
- **Logging**: `~/.ralph/logs/command-router.log`

**Example**:
```bash
# User prompt
"Tengo un bug en el login"

# Hook response
💡 **Sugerencia**: Detecté una tarea de debugging. Considera usar `/bug` para debugging sistemático.
```

**Documentation**: See [docs/command-router/README.md](docs/command-router/README.md) for complete documentation.

### ⚠️ CRITICAL: PostCompact Does NOT Exist (v2.81.1)

**Discovery**: During compaction hooks fix, we discovered that `PostCompact` is **NOT a valid hook event** in Claude Code as of January 2026.

**What This Means**:
- ❌ There is NO `PostCompact` event that fires after compaction
- ✅ Only `PreCompact` exists (fires BEFORE compaction)
- ✅ Use `SessionStart` for post-compaction context restoration

**Correct Pattern**:
```
PreCompact Event → Save state before compaction
    ↓
Compaction Happens → Old messages removed
    ↓
SessionStart Event → Restore state in new session ✅
```

**Documentation**: See [docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md](docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md) for complete details.

**Feature Request**: [GitHub #14258](https://github.com/anthropics/claude-code/issues/14258) - PostCompact Hook Event

### Error Trap Coverage (v2.62.3) - NEW

| Type | Hook Count | Trap Pattern | Required |
|------|------------|--------------|----------|
| PreToolUse | 12 | `{"decision": "allow"}` | All have traps |
| PostToolUse | 18 | `{"continue": true}` | All have traps |
| PreCompact | 1 | `{"continue": true}` | Has trap |
| Stop | 5 | `{"decision": "approve"}` | All have traps |
| UserPromptSubmit | 8 | `{}` or context | All have traps |
| SessionStart | 6 | (no JSON required) | N/A |
| Helpers | 2 | N/A (not registered) | N/A |

### Task Primitive Integration (v2.62.0) - NEW

Claude Code's evolved Task primitive patterns integrated via 3 new hooks:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `global-task-sync.sh` | PostToolUse (TodoWrite/TaskUpdate/TaskCreate) | Sync plan-state with `~/.claude/tasks/<session>/` |
| `verification-subagent.sh` | PostToolUse (TaskUpdate) | Suggest verification subagent after step completion |
| `task-orchestration-optimizer.sh` | PreToolUse (Task) | Detect parallelization + context-hiding opportunities |

**Key Patterns**:
- **Verification via Subagent**: Auto-suggest review for high-complexity or security-related steps
- **Parallelization Detection**: Identify independent tasks that can run concurrently
- **Context-Hiding**: Suggest `run_in_background: true` for large prompts (>2000 chars)
- **Model Optimization**: Recommend `model: "sonnet"` for low-complexity tasks using opus

### Hook Review Policy (v2.57.0)

> **IMPORTANT**: When updating hook versions, ALL hooks must be validated.

**Review Checklist**:
1. Verify JSON output format matches event type (see Known Limitations)
2. Test hook execution with manual invocation
3. Check hook logs for errors: `~/.ralph/logs/`
4. Validate version numbers are consistent across all hooks
5. Run `/gates` to ensure no regressions

**Version Bump Command**:
```bash
cd ~/.claude/hooks && for f in *.sh; do
  sed -i '' "s/VERSION: [0-9]*\.[0-9]*\.[0-9]*/VERSION: X.Y.Z/g" "$f"
done
```

### Known Limitations (v2.57.0)

#### 0. CLAUDE_PLUGIN_ROOT Path Resolution in Bun (v2.72.2) - CRITICAL FIX

**Issue**: The claude-mem plugin's hooks fail because Bun cannot resolve `${CLAUDE_PLUGIN_ROOT}` correctly when used as part of a path argument.

**Error**:
```bash
bun "${CLAUDE_PLUGIN_ROOT}/scripts/worker-service.cjs" start
# Error: Module not found "/scripts/worker-service.cjs"
```

**Solution** (Applied):
```bash
(cd "${CLAUDE_PLUGIN_ROOT}" && bun scripts/worker-service.cjs start)
```

**Affected Files** (BOTH must be updated):
1. `~/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10/hooks/hooks.json`
2. `~/.claude-sneakpeek/zai/config/plugins/marketplaces/thedotmack/plugin/hooks/hooks.json`

> **Why both?** Marketplace is source for updates. If only cache is fixed, updates overwrite the fix.

**Auto-Detection for Claude Code/z.ai**:
```bash
# Detect incorrect patterns
find ~/.claude-sneakpeek/zai/config/plugins -name "hooks.json" -path "*/claude-mem/*" -exec grep -l 'bun "\${CLAUDE_PLUGIN_ROOT}/scripts/worker-service' {} \;

# Auto-fix using provided script
./.claude/scripts/fix-claude-mem-hooks.sh
```

**Documentation**: See `docs/CLAUDE_MEM_HOOKS_FIX.md` for complete details.

**Note**: Both files are now fixed. Future claude-mem updates should preserve the marketplace fix.

#### 1. TodoWrite Does NOT Trigger Hooks (By Design)

**This is intentional, not a bug.** Claude Code categorizes tools into two types:

| Type | Tools | Hooks |
|------|-------|-------|
| **Executive** (modify system) | `Edit`, `Write`, `Bash` | PreToolUse + PostToolUse |
| **Declarative** (organize/plan) | `TodoWrite` | No hooks |

**Rationale** (from Claude.ai):
- **Executive tools** need PostToolUse hooks to validate effects (file created? command succeeded?)
- **TodoWrite** is purely declarative - it just updates an internal task list with no filesystem effects
- PostToolUse hooks are for validating side effects; TodoWrite has none

| Tool | Type | PreToolUse | PostToolUse |
|------|------|------------|-------------|
| `Bash` | Executive | Yes | Yes |
| `Edit` | Executive | Yes | Yes |
| `Write` | Executive | Yes | Yes |
| `Read` | Read-only | Yes | Yes |
| `Glob` | Read-only | Yes | Yes |
| `Grep` | Read-only | Yes | Yes |
| `Task` | Orchestration | Yes | Yes |
| `mcp__*` | Varies | Yes | Yes |
| **`TodoWrite`** | Declarative | No | No |

**Impact**: Hooks cannot react to todo list changes directly.

**Workaround**: Use `status-auto-check.sh` which triggers on Edit/Write/Bash (every 5 ops) for periodic plan-state updates.

#### 2. Relative Paths in Hooks

Hooks execute from unpredictable directories. Always use **absolute paths**:

```bash
# BAD - May fail depending on CWD
PLAN_STATE=".claude/plan-state.json"

# GOOD - Always works
PLAN_STATE="${PROJECT_ROOT}/.claude/plan-state.json"
# or
PLAN_STATE="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/plan-state.json"
```

---

## Ralph Loop Pattern

```
EXECUTE -> VALIDATE -> Quality Passed?
                          | NO
                      ITERATE (max 25)
                          |
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

## Repository Isolation Rule (v2.62.3) - NEW

> **When working in Repository A, you MUST NOT treat Repository B as your workspace.**

### Prohibited Actions on External Repos

| Action | Example | Risk |
|--------|---------|------|
| Edit/Write files | Modify files in `~/GitHub/OtherRepo/` | HIGH |
| Git operations | Commit/push to external repo | HIGH |
| Run commands | Execute tests in another project | MEDIUM |
| Extensive analysis | Debug issues in external codebase | MEDIUM |

### Allowed Actions (Reference Only)

| Action | Skill | Purpose |
|--------|-------|---------|
| Learn patterns | `/repo-learn` | Extract best practices for local use |
| Curate repos | `/curator` | Discover quality repos to learn from |
| Copy snippets | Manual | Reference with attribution |
| Compare code | Read tool | Inform local implementation |

### Detection

The `repo-boundary-guard.sh` hook automatically blocks:
- File operations outside current repo
- Bash commands targeting `~/Documents/GitHub/<other-repo>/`
- Git commands referencing external repositories

### Error Response

```
REPO BOUNDARY VIOLATION
Current repo: /path/to/current-repo
Attempted access: /path/to/other-repo

Options:
1. Use /repo-learn to learn from external repo
2. Use /curator to curate and learn patterns
3. Explicitly say "switch to [repo-name]" if intentional
```

---

## References & Community Resources

### Internal Documentation

| Topic | Documentation |
|-------|---------------|
| Complete Architecture | `ARCHITECTURE_DIAGRAM_v2.52.0.md` |
| Version History | `CHANGELOG.md` |
| Hook Testing | `tests/HOOK_TESTING_PATTERNS.md` |
| **Claude-Mem Hooks Fix** | `docs/CLAUDE_MEM_HOOKS_FIX.md` ⚠️ |
| Full README | `README.md` |
| Installation | `install.sh` |
| Plan State v2 Schema | `.claude/schemas/plan-state-v2.schema.json` |
| v2.51 Improvements | `.claude/v2.51-improvements-analysis.md` |
| v2.55 Auto-Learning | `~/.claude/hooks/orchestrator-auto-learn.sh` |
| v2.62 Task Primitive | `.claude/hooks/verification-subagent.sh` |
| Claude Code Docs | `~/.claude-code-docs/` |

### External Resources & Inspirations

| Resource | Purpose | Maintainer |
|----------|---------|------------|
| **claude-sneakpeek** | Zai variant, swarm mode, GLM-4.7 integration | [@mikekelly](https://github.com/mikekelly) |
| **cc-mirror** | Claude Code documentation mirror patterns | [@numman-ali](https://github.com/numman-ali) |
| **everything-claude-code** | Claude Code patterns and examples | [@affaan-m](https://github.com/affaan-m) |
| **claude-code-docs** | Official Claude Code documentation | [@ericbuess](https://github.com/ericbuess) |

### Key Links

- **claude-sneakpeek**: [github.com/mikekelly/claude-sneakpeek](https://github.com/mikekelly/claude-sneakpeek/tree/main)
- **cc-mirror**: [github.com/numman-ali/cc-mirror](https://github.com/numman-ali/cc-mirror)
- **Swarm Mode Demo**: [x.com/NicerInPerson/status/2014989679796347375](https://x.com/NicerInPerson/status/2014989679796347375)

**Acknowledgments**: This project stands on the shoulders of giants. Special thanks to @mikekelly for the zai variant and swarm mode implementation, @numman-ali for documentation patterns, and the entire Claude Code community for the invaluable patterns and examples.

---

## Aliases

```bash
rh=ralph rho=orch rhs=security rhb=bugs rhg=gates
mm=mmc mml="mmc --loop 30"
```

---

*Full documentation: See README.md and ARCHITECTURE_DIAGRAM_v2.52.0.md*
