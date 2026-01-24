# Changelog

All notable changes to Multi-Agent Ralph Wiggum are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.69.0] - 2026-01-25

### GLM-4.7 Full Ecosystem Integration

Complete GLM-4.7 ecosystem integration with 4-planner Adversarial Council and unified MCP access.

#### Adversarial Council 4-Planner Upgrade

Updated `adversarial_council.py` to v2.68.26 with **GLM-4.7 as 4th planner**:

| Planner | Model | Kind | API | Cost |
|---------|-------|------|-----|------|
| codex | gpt-5.2-codex | CLI | OpenAI | Variable |
| claude-opus | opus | CLI | Anthropic | 15x |
| gemini | gemini-2.5-pro | CLI | Google | Variable |
| **glm-4.7** | glm-4.7 | **curl** | **Z.AI Coding** | **~15%** |

**Exit Criteria**: All 4 models must agree "NO ISSUES FOUND" for validation to pass.

#### Unified `/glm-mcp` Skill (NEW)

**~/.claude/skills/glm-mcp/** - Single skill to access 14 GLM/Z.AI MCP tools:

**Vision Tools (zai-mcp-server - 9 tools)**:
```bash
/glm-mcp ui2code <screenshot>   # UI to code/prompt
/glm-mcp ocr <screenshot>       # Extract text (OCR)
/glm-mcp diagnose <error.png>   # Diagnose errors
/glm-mcp diagram <arch.png>     # Understand diagrams
/glm-mcp chart <dashboard.png>  # Analyze visualizations
/glm-mcp diff <old> <new>       # UI comparison
/glm-mcp analyze <image>        # General analysis
/glm-mcp video <video.mp4>      # Video analysis
```

**Web Tools (2 tools)**:
```bash
/glm-mcp search "query"         # Web search (webSearchPrime)
/glm-mcp fetch <url>            # Fetch content (webReader)
```

**Repository Tools (zread - 3 tools)**:
```bash
/glm-mcp docs <github-url>      # Search repo docs
/glm-mcp structure <github-url> # Get repo structure
/glm-mcp read <url> <path>      # Read specific file
```

#### Standalone GLM Skills

| Skill | Script | Purpose |
|-------|--------|---------|
| `/glm-4.7` | `glm-query.sh` | Direct GLM-4.7 queries |
| `/glm-web-search` | `glm-web-search.sh` | Web search with GLM |

#### Key Technical Discovery

**MCP vs Coding API**:
- MCP endpoints (`/api/mcp/...`) require **paas balance** (separate billing)
- Coding API (`/api/coding/paas/v4`) uses **plan quota** (included)
- All GLM integrations now use Coding API for cost efficiency

#### Documentation Updates

- README.md: Updated to v2.69 with 4-planner diagram
- AGENTS.md: Updated Multi-Model Adversarial Validation section
- CLAUDE.md: Added GLM MCP skills to Quick Start
- CHANGELOG.md: This entry

---

## [2.68.26] - 2026-01-24/25

### GLM-4.7 Integration - ALL 5 PHASES COMPLETE ✅

Complete implementation of GLM-4.7 integration with MiniMax fallback strategy.

**Key Discovery**: MCP endpoints (`/api/mcp/...`) require paas balance, but **GLM Coding API** (`/api/coding/paas/v4`) uses plan quota. All hooks updated to use Coding API.

#### Adversarial Council Integration (NEW)

**adversarial_council.py** v2.68.26 now has 4 planners:

| Planner | Model | Kind | API |
|---------|-------|------|-----|
| codex | gpt-5.2-codex | CLI | OpenAI |
| claude-opus | opus | CLI | Anthropic |
| gemini | gemini-2.5-pro | CLI | Google |
| **glm-4.7** | glm-4.7 | **curl** | **Coding API** |

Features:
- `build_command()` constructs curl calls to GLM Coding API
- `extract_agent_response()` handles both `content` and `reasoning_content`
- Anonymization includes GLM/Zhipu/Z.AI identifiers
- JSON escaping via Python's `json.dumps()` for robust handling

#### Standalone `/glm-4.7` Skill (NEW)

**~/.claude/skills/glm-4.7/glm-query.sh** - Query GLM-4.7 directly:

```bash
# Basic query
/glm-4.7 "Review this code for security"

# With code file
~/.claude/skills/glm-4.7/glm-query.sh --code src/auth.ts "Find vulnerabilities"

# Custom system prompt
~/.claude/skills/glm-4.7/glm-query.sh --system "You are a security auditor" "Audit this"
```

Features:
- Auto-loads `Z_AI_API_KEY` from `~/.zshrc` if not in environment
- Handles `reasoning_content` for reasoning models
- Colored output with progress indicators
- `--raw` option for JSON output

#### Phase 1-3: (See previous entry)

#### Phase 4: Documentation Search (COMPLETE)

**smart-memory-search.sh** now searches 6 parallel sources (was 5):
- Added Task 6: GLM docs search via Coding API
- Extracts `reasoning_content` for GLM-4.7 reasoning models
- Results in `memory-context.json` under `sources.docs_search`

#### Phase 5: MiniMax Fallback Strategy (COMPLETE)

Both GLM tasks now have MiniMax fallback:

```bash
# If GLM fails -> try MiniMax via mmc CLI
if command -v mmc >/dev/null 2>&1; then
    MM_RESULT=$(mmc --query "..." --max-tokens 400)
fi
```

**Fallback Matrix**:
| Primary (GLM) | Fallback (MiniMax) | Trigger |
|---------------|-------------------|---------|
| GLM web search | `mmc --query` | API error/empty |
| GLM docs search | `mmc --query` | API error/empty |

#### Updated Architecture

**smart-memory-search.sh** now:
1. claude-mem MCP (local)
2. memvid (local)
3. handoffs (local)
4. ledgers (local)
5. GLM web search (via Coding API + MiniMax fallback)
6. GLM docs search (via Coding API + MiniMax fallback)

---

#### DAY 1-2: Web Search + Visual Validation (COMPLETE)

**smart-memory-search.sh** originally searched 5 parallel sources:
1. claude-mem MCP
2. memvid vector storage
3. handoffs (session context)
4. ledgers (continuity data)
5. **NEW: webSearchPrime (GLM-4.7)**

```bash
# New Task 5 in parallel search
[5/5] Searching web via GLM webSearchPrime...
```

Features:
- Automatic API key sourcing from `~/.zshrc` if not in environment
- Graceful 401 handling with actionable error message
- Results aggregated into `memory-context.json` under `sources.web_search`

#### DAY 2: Visual Validation Hook (COMPLETE)

**NEW: glm-visual-validation.sh** - Visual regression testing for frontend changes

| Trigger | Event |
|---------|-------|
| File Pattern | `.tsx, .jsx, .css, .scss, .vue, .svelte` |
| Event Type | PostToolUse (Edit\|Write) |
| GLM Tool | `ui_diff_check` |

Features:
- Detects frontend file modifications
- Looks for before/after screenshots in `~/.ralph/screenshots/` or `.claude/screenshots/`
- Calls GLM `ui_diff_check` for visual diff
- Reports significant vs minor UI changes

#### Hook Registration

```json
{
  "PostToolUse": [
    {
      "hooks": [{"command": "${HOME}/.claude/hooks/glm-visual-validation.sh", "timeout": 30}],
      "matcher": "Edit|Write"
    }
  ]
}
```

#### coding-helper Validation

- **Version**: 0.0.6
- **Status**: Available via `npx @z_ai/coding-helper`
- **Doctor Check**: Identifies API key status and tool availability

#### MCP Configuration Verified

| Server | Type | Status |
|--------|------|--------|
| zai-mcp-server | stdio | ✅ Configured |
| web-search-prime | HTTP | ✅ Configured |
| web-reader | HTTP | ✅ Configured |
| zread | HTTP | ✅ Configured |

**Note**: API key requires renewal - run `npx @z_ai/coding-helper auth glm_coding_plan_global <TOKEN>`

---

## [2.68.25] - 2026-01-24

### CRIT-001: Double stdin Read Pattern Fix (30 hooks)

Critical bug fix for hooks that were completely broken due to SEC-111 implementation.

#### Root Cause Analysis

When SEC-111 was implemented to prevent DoS attacks via stdin length limiting, the fix added `INPUT=$(head -c 100000)` at the top of hooks. However, the original `INPUT=$(cat)` lines were not removed, causing:

1. First read (`head -c 100000`) - Consumes entire stdin
2. Second read (`cat`) - Returns EMPTY because stdin is exhausted

**Impact**: 30 hooks were affected - most returning empty JSON or skipping all logic.

#### Affected Hooks (30 total)

**Phase 1 - Manual Fix (6 critical hooks):**

| Hook | Event Type | Status |
|------|------------|--------|
| `fast-path-check.sh` | PreToolUse (Task) | FIXED |
| `smart-memory-search.sh` | PreToolUse (Task) | FIXED |
| `inject-session-context.sh` | PreToolUse (Task) | FIXED |
| `orchestrator-auto-learn.sh` | PreToolUse (Task) | FIXED |
| `pre-compact-handoff.sh` | PreCompact | FIXED |
| `stop-verification.sh` | Stop | FIXED |

**Phase 2 - Automated Fix (24 additional hooks):**

| Hook | Event Type | Status |
|------|------------|--------|
| `agent-memory-auto-init.sh` | PreToolUse | FIXED |
| `auto-format-prettier.sh` | PostToolUse | FIXED |
| `auto-save-context.sh` | PostToolUse | FIXED |
| `checkpoint-smart-save.sh` | PreToolUse | FIXED |
| `console-log-detector.sh` | PostToolUse | FIXED |
| `context-injector.sh` | SessionStart | FIXED |
| `continuous-learning.sh` | Stop | FIXED |
| `curator-suggestion.sh` | UserPromptSubmit | FIXED |
| `decision-extractor.sh` | PostToolUse | FIXED |
| `episodic-auto-convert.sh` | PostToolUse | FIXED |
| `memory-write-trigger.sh` | UserPromptSubmit | FIXED |
| `parallel-explore.sh` | PostToolUse | FIXED |
| `plan-state-lifecycle.sh` | UserPromptSubmit | FIXED |
| `procedural-inject.sh` | PreToolUse | FIXED |
| `progress-tracker.sh` | PostToolUse | FIXED |
| `quality-gates-v2.sh` | PostToolUse | FIXED |
| `recursive-decompose.sh` | PostToolUse | FIXED |
| `reflection-engine.sh` | Stop | FIXED |
| `semantic-auto-extractor.sh` | Stop | FIXED |
| `semantic-realtime-extractor.sh` | PostToolUse | FIXED |
| `session-start-ledger.sh` | SessionStart | FIXED |
| `status-auto-check.sh` | PostToolUse | FIXED |
| `typescript-quick-check.sh` | PostToolUse | FIXED |
| `verification-subagent.sh` | PostToolUse | FIXED |

#### Fix Pattern

```bash
# BEFORE (broken):
INPUT=$(head -c 100000)  # First read
...
INPUT=$(cat)             # Second read = EMPTY!

# AFTER (fixed):
INPUT=$(head -c 100000)  # Single read, use throughout
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top
```

#### Validation

All 30 hooks now:
- Read stdin exactly once via SEC-111 pattern
- Use the same $INPUT variable throughout
- Have explicit CRIT-001 FIX comment documenting the change

#### GLM-4.7 Integration Plan

New integration plan created: `.claude/GLM-4.7-INTEGRATION-PLAN.md`

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Critical bug fixes (30 hooks) | COMPLETE |
| 2 | Web search integration (smart-memory-search) | PLANNED |
| 3 | Visual validation hook | PLANNED |
| 4 | Documentation search (zread) | PLANNED |
| 5 | MiniMax fallback strategy | PLANNED |

---

## [2.68.24] - 2026-01-24

### Statusline Ralph Enhancement & GLM-4.7 MCP Integration

Major statusline upgrade with multi-model adversarial validation and GLM-4.7 ecosystem integration.

#### FEAT-001: Statusline Ralph Context Percentage Display (FIXED)

| Component | Before | After |
|-----------|--------|-------|
| claude-hud | v0.0.1 (57 lines, basic) | v0.0.6 (11 JS modules, full tracking) |
| dist/ directory | Incomplete (3 files) | Complete (45 files) |
| stdin.js | Missing (ERR_MODULE_NOT_FOUND) | Present (2.4K) |
| Context percentage | Not displayed | Displaying correctly |

**Statusline Output:**
```
main* 2 | 2/3 66% main | [Unknown | Max] 60% | 2% (4h 40m / 5h)
```

**Files Modified:**
- `~/.claude/plugins/cache/claude-hud/claude-hud/0.0.6/dist/` (45 files)

#### VALIDATION-001: Multi-Model Adversarial Review (PASSED)

| Model | Task ID | Veredict |
|-------|---------|----------|
| Adversarial (ab4e825) | Completed | PASSED |
| Codex-CLI (a8e15bb) | Completed | PASSED |
| Gemini-CLI (a259dd0) | Completed | PASSED |

**Consensus:** "NO ISSUES FOUND - STATUSLINE RALPH IS VERIFIED"

#### FEAT-002: GLM-4.7 MCP Ecosystem Integration

| Component | Type | Status | Tools |
|-----------|------|--------|-------|
| **zai-mcp-server** | Node.js | Connected | ui_to_artifact, extract_text_from_screenshot, diagnose_error_screenshot, understand_technical_diagram, analyze_data_visualization, ui_diff_check, image_analysis, video_analysis |
| **web-search-prime** | HTTP | Connected | webSearchPrime |
| **web-reader** | HTTP | Connected | webReader |
| **zread** | HTTP | Connected | search_doc, get_repo_structure, read_file |

**Plugin Installed:**
- `glm-plan-usage@zai-coding-plugins` - Plan usage monitoring (`/glm-plan-usage:usage-query`)

**Configuration:**
- Node.js v22.18.0 configured for vision-mcp-server
- API key configured via ANTHROPIC_AUTH_TOKEN

**Total MCP Servers:** 26 (4 new from GLM-4.7)

---

## [2.68.23] - 2026-01-24

### Adversarial Validation Phase 9 - Critical Security & Code Quality Fixes

Comprehensive adversarial audit cycle fixing critical security vulnerabilities and code quality issues.

#### CRIT-001: SEC-117 Command Injection via eval (FIXED)

| File | Issue | Fix |
|------|-------|-----|
| `~/.local/bin/ralph` | `eval echo "$path"` allowed command injection | Replaced with safe parameter expansion `${path/#\~/$HOME}` |

#### HIGH-001: SEC-104 Weak Cryptographic Hash (FIXED)

| File | Issue | Fix |
|------|-------|-----|
| `checkpoint-smart-save.sh` | MD5 used for file hash (cryptographically weak) | Replaced with SHA-256 via `shasum -a 256` |

#### HIGH-003: SEC-111 Input Length Validation (Added - but incomplete)

DoS prevention by limiting stdin input to 100KB - however, original `INPUT=$(cat)` lines were not removed, causing CRIT-001 in v2.68.25.

---

## Previous Versions

See git history for earlier versions.
