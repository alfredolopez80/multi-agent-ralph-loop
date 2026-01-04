---
name: commands
prefix: "@cmds"
category: tools
color: green
description: "List all available slash commands grouped by category"
argument-hint: "[category]"
---

# /commands - Command Discovery (v2.26)

List all available slash commands with their prefixes, grouped by category with color coding.

## Usage

```bash
/commands              # List all commands
/commands review       # List review category only
/commands --search "test"  # Search by name/description
@cmds                  # Prefix invocation
```

## Execution

When `/commands` is invoked, display the following command reference:

### Orchestration (Purple)

| Prefix | Command | Description |
|--------|---------|-------------|
| `@orch` | `/orchestrator` | Full orchestration: clarify → classify → delegate → execute → validate → retrospective |
| `@clarify` | `/clarify` | Deep clarification using AskUserQuestion - MUST_HAVE and NICE_TO_HAVE questions |
| `@loop` | `/loop` | Ralph loop until VERIFIED_DONE |

### Review (Red)

| Prefix | Command | Description |
|--------|---------|-------------|
| `@sec` | `/security` | Security audit with Codex + MiniMax |
| `@bugs` | `/bugs` | Bug hunting with Codex CLI |
| `@tests` | `/unit-tests` | Generate unit tests with Codex (90% coverage) |
| `@ref` | `/refactor` | Systematic refactoring with Codex |
| `@review` | `/full-review` | Multi-model review with 6 parallel subagents |
| `@par` | `/parallel` | Run all 6 subagents in parallel (async) |
| `@adv` | `/adversarial` | 2/3 consensus validation (Claude + Codex + Gemini) |

### Research (Blue)

| Prefix | Command | Description |
|--------|---------|-------------|
| `@research` | `/research` | Web research using WebSearch (native) with MiniMax fallback |
| `@lib` | `/library-docs` | Search library/framework documentation via Context7 MCP |
| `@mmsearch` | `/minimax-search` | Web search via MiniMax MCP (8% cost, Opus quality) |
| `@ast` | `/ast-search` | Hybrid search: ast-grep (structural) + Explore agent (semantic) |
| `@browse` | `/browse` | Browser automation with dev-browser |
| `@img` | `/image-analyze` | Analyze images via MiniMax MCP (screenshots, UI, diagrams) |

### Tools (Green)

| Prefix | Command | Description |
|--------|---------|-------------|
| `@gates` | `/gates` | Run quality gates for 9 languages |
| `@mm` | `/minimax` | Query MiniMax M2.1 for second opinion |
| `@imp` | `/improvements` | Manage pending improvements |
| `@audit` | `/audit` | Generate usage report for MiniMax and token optimization |
| `@retro` | `/retrospective` | Analyze task and propose improvements |
| `@cmds` | `/commands` | List all available slash commands (this command) |
| `@diagram` | `/diagram` | Generate Mermaid diagrams for documentation |

## Category Filter

If a category argument is provided, filter by that category:

```
/commands orchestration  → Shows only purple commands
/commands review         → Shows only red commands
/commands research       → Shows only blue commands
/commands tools          → Shows only green commands
```

## Search

Search across all commands by name or description:

```
/commands --search "test"  → Shows /unit-tests, /ast-search
/commands --search "mcp"   → Shows /minimax-search, /library-docs, /image-analyze
```

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH v2.26 COMMANDS                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🟣 ORCHESTRATION        🔴 REVIEW           🔵 RESEARCH       │
│  ───────────────         ─────────           ──────────        │
│  @orch  Full flow        @sec   Security     @research Web     │
│  @clarify Questions      @bugs  Bug hunt     @lib     Docs     │
│  @loop  Iterate          @tests Unit tests   @mmsearch MM      │
│                          @ref   Refactor     @ast     Code     │
│                          @review 6 agents    @browse  Browser  │
│                          @par   Parallel     @img     Image    │
│                          @adv   Consensus                      │
│                                                                 │
│  🟢 TOOLS                                                       │
│  ─────────                                                      │
│  @gates Quality gates    @mm   MiniMax       @imp  Improve     │
│  @audit Usage report     @retro Retrospect   @cmds Commands    │
│  @diagram Mermaid                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## CLI Alternative

```bash
ralph commands              # List all
ralph commands review       # Filter by category
ralph help                  # Same as /commands
```
