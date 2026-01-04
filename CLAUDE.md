# Multi-Agent Ralph v2.26

Orchestration with **automatic planning**, **intensive clarification**, **git worktree isolation**, adversarial validation, self-improvement, and 9-language quality gates.

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

## Iteration Limits

| Model | Max Iter | Use Case |
|-------|----------|----------|
| Claude | **15** | Complex reasoning |
| MiniMax M2.1 | **30** | Standard (2x) |
| MiniMax-lightning | **60** | Extended (4x) |

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

**Iteration Limits by Model:**
| Model | Max Iterations | Rationale |
|-------|----------------|-----------|
| Claude (Sonnet/Opus) | **15** | Complex reasoning, higher accuracy per iteration |
| MiniMax M2.1 | **30** | Good quality at 8% cost, needs more iterations |
| MiniMax-lightning | **60** | Fast model, compensate with more iterations |

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
