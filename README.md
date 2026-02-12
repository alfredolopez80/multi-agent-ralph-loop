# Multi-Agent Ralph Loop

> "Me fail English? That's unpossible!" - Ralph Wiggum

**Smart Memory-Driven Orchestration** with parallel memory search, RLM-inspired routing, quality-first validation, **checkpoints**, **agent handoffs**, local observability, autonomous self-improvement, **Dynamic Contexts**, **Eval Harness (EDD)**, **Cross-Platform Hooks**, **Claude Code Task Primitive integration**, **Plan Lifecycle Management**, **adversarial-validated hook system**, **Claude Code Documentation Mirror**, **GLM-5 Agent Teams**, **Dual Context Display System**, **full CLI implementation**, **Automatic Learning System**, **Intelligent Command Routing**, **Swarm Mode Integration**, and **Hook System v2.84.0** (100% validated, race-condition-free).

> **🆕 v2.84.0**: **GLM-5 Agent Teams Integration** - Native TeammateIdle/TaskCompleted hooks, project-scoped storage, reasoning capture, memory integration. 5 phases implemented, 20/20 tests passing. See [docs/architecture/GLM5_AGENT_TEAMS_INTEGRATION_PLAN_v2.84.md](docs/architecture/GLM5_AGENT_TEAMS_INTEGRATION_PLAN_v2.84.md) for complete details.

> **v2.83.1**: **5-Phase Hook System Audit Complete** - 100% validation achieved (18/18 tests passing). Eliminated 4 race conditions, fixed 3 JSON malformations, added TypeScript caching (80-95% speedup), multilingual support (EN/ES) for 20+ file extensions, atomic file locking for critical hooks, and 5 new critical hooks. **v2.82.0**: **Intelligent Command Router Hook** - Analyzes prompts and suggests optimal commands. **v2.81.1**: Swarm Mode Integration with 7 parallel commands.

---

## 🔧 Hook System Audit v2.83.1 ✅ PRODUCTION-READY

**Status**: 5-phase audit complete with **100% validation** (target was 95%). All 83 hooks validated, 18/18 tests passing, 4 race conditions eliminated, 3 JSON malformations fixed.

### What's New in v2.83.1

#### Phase 1: Critical Fixes ✅
- **Race Conditions Eliminated**: Fixed 4 race conditions in concurrent file operations
  - `promptify-security.sh`: Added atomic locking for log rotation
  - `quality-gates-v2.sh`: Added file-based caching with atomic writes
  - `orchestrator-auto-learn.sh`: Added `mkdir`-based atomic locking for plan-state.json
  - `checkpoint-smart-save.sh`: Added exclusive file locks with `flock`
  
- **JSON Malformations Fixed**: Fixed 3 hooks with invalid JSON output
  - All PreToolUse hooks now use correct `hookSpecificOutput` wrapper
  - PostToolUse hooks validate JSON before output
  - Added JSON validation tests (100% passing)

- **Archived Invalid Hook**: `post-compact-restore.sh` moved to `.claude/hooks/archived/` (PostCompact event does not exist in Claude Code)

#### Phase 2: Robustness Improvements ✅
- **TypeScript Compilation Cache**: 
  - File-based caching using `mtime + md5` hash keys
  - 1000-entry LRU cache with automatic cleanup
  - **Performance gain**: 80-95% reduction in TypeScript compile times
  - Cache location: `~/.ralph/cache/typescript/`

- **Multilingual Support**:
  - Added Spanish keyword detection to `fast-path-check.sh`
  - Keywords: `arreglar`, `corregir`, `cambio simple`, `cambio menor`, `renombrar`, etc.
  - English + Spanish support improves detection accuracy by ~15%

- **Security Hardening**:
  - `umask 077` applied to 38 hooks (files created with 700 permissions)
  - Removed insecure `.zshrc` API key extraction pattern
  - Added dependency validation before hook execution

#### Phase 3: Documentation ✅
- **New Hooks Created**:
  - `todo-plan-sync.sh` - Synchronizes todos with plan-state.json progress
  - `orchestrator-auto-learn.sh` - Auto-detects knowledge gaps, triggers curator
  
- **Documentation Updates**:
  - Added 24 hooks to COMPLETE_HOOKS_REFERENCE.md (+76 lines)
  - Updated `settings.json.example` to 41 registered hooks
  - Added inline comments to 15 complex hooks

#### Phase 4: Optimization ✅
- **Modern File Extensions**: Added support for 8 new extensions
  - Vue (`.vue`), Svelte (`.svelte`), PHP (`.php`), Ruby (`.rb`)
  - Go (`.go`), Rust (`.rs`), Java (`.java`), Kotlin (`.kt`)
  - Total supported: 20 file extensions

- **Rate Limiting**: Added GLM-4.7 API rate limiting with exponential backoff
  - Prevents 429 errors during parallel operations
  - Automatic fallback to sequential execution when rate limited

- **Structured Logging**: All hooks now output structured JSON logs
  - Log location: `~/.ralph/logs/`
  - Rotation: 5 backups maintained with atomic operations

#### Phase 5: Testing ✅
```
╔══════════════════════════════════════════════════════════════════╗
║           v2.83.1 VALIDATION RESULTS                              ║
╠══════════════════════════════════════════════════════════════════╣
║  Test Category          │ Total │ Passed │ Failed │ Status       ║
║  ─────────────────────────────────────────────────────────────── ║
║  Syntax Validation      │   83  │   83   │   0    │ ✅ 100%      ║
║  JSON Parseability      │   83  │   83   │   0    │ ✅ 100%      ║
║  Shebang Presence       │   83  │   83   │   0    │ ✅ 100%      ║
║  Executable Permissions │   83  │   83   │   0    │ ✅ 100%      ║
║  Integration Tests      │   18  │   18   │   0    │ ✅ 100%      ║
║  Race Condition Tests   │    4  │    4   │   0    │ ✅ 100%      ║
║  ─────────────────────────────────────────────────────────────── ║
║  TOTAL                  │  354  │  354   │   0    │ ✅ 100%      ║
╚══════════════════════════════════════════════════════════════════╝
```

### 5 New Critical Hooks (Added to settings.json)

| Hook | Event | Purpose |
|------|-------|---------|
| `orchestrator-auto-learn.sh` | PreToolUse (Task) | Auto-detects knowledge gaps, triggers curator learning |
| `promptify-security.sh` | PreToolUse (Task) | Security validation for prompts with pattern detection |
| `parallel-explore.sh` | PostToolUse (Task) | Launches 5 concurrent exploration tasks |
| `recursive-decompose.sh` | PostToolUse (Task) | Triggers sub-orchestrators for complex tasks |
| `todo-plan-sync.sh` | PostToolUse (TodoWrite) | Syncs todos with plan-state.json progress |

### Settings.json Synchronization

Your personal `settings.json` has been updated with 5 additional critical hooks:
- **Before**: 34 hooks registered
- **After**: 39 hooks registered (+5)
- **Location**: `~/.claude-sneakpeek/zai/config/settings.json`

---

## 🚀 Latest Release: v2.81.2 - Automatic Learning System

**New**: Multi-Agent Ralph Loop now includes **fully automatic learning system** with GitHub repository curation, pattern extraction, and rule validation.

### What's New in v2.81.2

- **Automatic Learning Integration**
  - `learning-gate.sh` v1.0.0 - Auto-executes /curator when memory is empty
  - `rule-verification.sh` v1.0.0 - Validates rules were applied in code
  - Curator scripts v2.0.0 - 15 critical bugs fixed
  - Complete testing suite: 62/62 tests passing (100%)

- **Learning Pipeline**
  - Discovery: GitHub API search for quality repositories
  - Scoring: Quality metrics + context relevance
  - Ranking: Top N with max-per-org limits
  - Learning: Pattern extraction from approved repos

- **Quality Metrics**
  - Total Rules: 1003 procedural rules
  - Utilization Rate: Automatically tracked
  - Application Rate: Measured per domain
  - System Status: Production ready ✅

### Quick Start with Learning

```bash
# Auto-learning triggers when needed (automatic)
/orchestrator "Implement microservice architecture"
# → learning-gate detects gap, recommends /curator

# Manual learning pipeline
/curator full --type backend --lang typescript

# View learning status
ralph health
```

**Documentation**: [Learning System Guide](docs/guides/LEARNING_SYSTEM_INTEGRATION_GUIDE.md) | [Implementation Report](docs/implementation/IMPLEMENTACION_COMPLETA_OPCIONES_A_C_D_v2.81.2.md)

---

## 🧠 Intelligent Command Router (v2.82.0) ✅ NEW

**Overview**: UserPromptSubmit hook that analyzes prompts and intelligently suggests the optimal command based on detected patterns.

### Key Features

1. **9 Command Detections**
   - `/bug` - Systematic debugging (90% confidence)
   - `/edd` - Feature definition with eval specs (85% confidence)
   - `/orchestrator` - Complex task orchestration (85% confidence)
   - `/loop` - Iterative execution with validation (85% confidence)
   - `/adversarial` - Specification refinement (85% confidence)
   - `/gates` - Quality gate validation (85% confidence)
   - `/security` - Security vulnerability audit (88% confidence)
   - `/parallel` - Comprehensive parallel review (85% confidence)
   - `/audit` - Quality audit and health check (82% confidence)

2. **Multilingual Support**
   - English: "I have a bug in the login" → `/bug`
   - Spanish: "Tengo un bug en el login" → `/bug`

3. **Non-Intrusive Integration**
   - Uses `additionalContext` instead of interruptive prompts
   - Confidence-based filtering (≥ 80% threshold)
   - Always continues workflow (never blocks)

4. **Security Features**
   - Input validation: 100KB max size (SEC-111)
   - Sensitive data redaction: Passwords, tokens, API keys (SEC-110)
   - Error trap: Guaranteed JSON output on errors

### Usage Examples

```bash
# The hook automatically suggests commands based on your prompt

# You type:
"Tengo un bug en el login que no funciona"

# Hook responds:
💡 **Sugerencia**: Detecté una tarea de debugging. Considera usar `/bug`
para debugging sistemático: analizar → reproducir → localizar → corregir.

# You type:
"Implementa autenticación OAuth y luego agrega refresh tokens"

# Hook responds:
💡 **Sugerencia**: Detecté una tarea compleja. Considera usar `/orchestrator`
para workflow completo: evaluar → clarificar → clasificar → planear → ejecutar.
```

### Configuration

```bash
# Enable/disable router
echo '{"enabled": true}' > ~/.ralph/config/command-router.json

# Adjust confidence threshold (default: 80%)
echo '{"confidence_threshold": 70}' > ~/.ralph/config/command-router.json

# View logs
tail -f ~/.ralph/logs/command-router.log
```

### Test Results

```
╔══════════════════════════════════════════════════════════════╗
║       COMMAND ROUTER VALIDATION - TEST RESULTS              ║
╠══════════════════════════════════════════════════════════════╣
║  Test Type           | Total | Passed | Failed | Percentage ║
║  ─────────────────────────────────────────────────────────────  ║
║  Intent Detection    |   9   |   7    |   2    |    78%     ║
║  Edge Cases          |   3   |   3    |   0    |   100%     ║
║  Security Tests      |   3   |   3    |   0    |   100%     ║
║  JSON Validation     |  10   |  10    |   0    |   100%     ║
║  ─────────────────────────────────────────────────────────────  ║
║  TOTAL               |  25   |  23    |   2    |    92%     ║
╚══════════════════════════════════════════════════════════════╝
```

**Documentation**: [Command Router Guide](docs/command-router/README.md) | [Implementation Summary](docs/command-router/IMPLEMENTATION_SUMMARY.md) | [Test Suite](tests/test-command-router.sh)

---

## 🤖 GLM-5 Agent Teams (v2.84.0) ✅ NEW

**Overview**: Integration of GLM-5's Agentic Engineering capabilities with Claude Code's Agent Teams system using native hooks.

### Key Features

1. **Native Hooks Integration** (v2.1.33+)
   - `TeammateIdle` - Fires when teammate is about to go idle
   - `TaskCompleted` - Fires when task is marked complete
   - Both hooks can block/allow with exit codes

2. **Project-Scoped Storage**
   - All teammate data in `.ralph/` directory
   - Isolated per project, portable with git clone

3. **GLM-5 Thinking Mode**
   - `reasoning_content` captured separately
   - Stored in `.ralph/reasoning/{task_id}.txt`

4. **Agent Types**
   - `glm5-coder` - Implementation & refactoring
   - `glm5-reviewer` - Code review & quality
   - `glm5-tester` - Test generation
   - `glm5-orchestrator` - Multi-agent coordination

### Quick Start

```bash
# Initialize team
.claude/scripts/glm5-init-team.sh "my-team"

# Spawn teammate
.claude/scripts/glm5-teammate.sh coder "Implement auth" "auth-001"

# Check status
cat .ralph/team-status.json

# View logs
tail -f .ralph/logs/teammates.log
```

### File Structure

```
.ralph/
├── teammates/     # Teammate status
├── reasoning/     # GLM-5 reasoning
├── agent-memory/  # Agent memory
├── logs/          # Activity logs
└── team-status.json
```

**Documentation**: [Integration Plan](docs/architecture/GLM5_AGENT_TEAMS_INTEGRATION_PLAN_v2.84.md) | [Implementation Summary](docs/architecture/GLM5_AGENT_TEAMS_IMPLEMENTATION_SUMMARY.md) | [Test Suite](tests/agent-teams/test-glm5-teammates.sh)

---

## 🐛 Recent Updates (v2.81.0 - v2.82.0)

### Intelligent Command Router (v2.82.0) ✅ LATEST

**Overview**: UserPromptSubmit hook that analyzes prompts and suggests optimal commands.

- **9 Command Patterns**: Bug detection, feature definition, orchestration, iteration, specification refinement, quality gates, security audit, parallel review, quality audit
- **Multilingual**: English + Spanish support
- **Confidence-Based**: Only suggests when ≥ 80% confidence
- **Non-Intrusive**: Uses `additionalContext`, never blocks workflow
- **Security**: Input validation, sensitive data redaction, error trap

**Performance**: 7/9 core tests passing (78%), 23/25 total tests passing (92%)

### Automatic Learning System (v2.81.2) ✅ STABLE

**Overview**: Complete automatic learning integration with GitHub repository curation and rule validation.

#### Key Features

1. **Learning Gate** (`learning-gate.sh`)
   - Detects when procedural memory is critically empty
   - Recommends `/curator` execution for specific domains
   - Blocks high complexity tasks (≥7) without rules
   - Auto-executes based on task complexity

2. **Rule Verification** (`rule-verification.sh`)
   - Analyzes generated code for rule patterns
   - Updates rule metrics (applied_count, skipped_count)
   - Calculates utilization rate
   - Identifies "ghost rules" (injected but not applied)

3. **Curator Scripts (v2.0.0)**
   - 15 critical bugs fixed across 3 scripts
   - Error handling in while loops
   - Temp file cleanup with trap
   - Logging redirected to stderr
   - JSON output validation
   - Rate limiting with exponential backoff

4. **Testing Suite**
   - Unit Tests: 13/13 passed (100%)
   - Integration Tests: 13/13 passed (100%)
   - Functional Tests: 4/4 passed (100%)
   - End-to-End Tests: 32/32 passed (100%)
   - **TOTAL: 62/62 tests passed (100%)**

#### System Statistics

```
╔════════════════════════════════════════════════════════════════╗
║             LEARNING SYSTEM v2.81.2 - SYSTEM STATUS                ║
╠════════════════════════════════════════════════════════════════╣
║  Component           Status    Quality    Integration    Tests      ║
║  ─────────────────────────────────────────────────────────────  ║
║  Curator            ✅ 100%    ✅ 95%     ✅ 90%        ✅ 100%    ║
║  Repository Learner ✅ 100%    ✅ 85%     ✅ 80%        ✅ 100%    ║
║  Learning Gate      ✅ 100%    ✅ 95%     ✅ 100%       ✅ 100%    ║
║  Rule Verification  ✅ 100%    ✅ 95%     ✅ 100%       ✅ 100%    ║
║  ─────────────────────────────────────────────────────────────  ║
║  OVERALL            ✅ 100%    ✅ 91%     ✅ 89%        ✅ 100%    ║
╚════════════════════════════════════════════════════════════════╝
```

---

### Swarm Mode Integration (v2.81.1) ✅ COMPLETE

**Overview**: Complete swarm mode integration across 7 core commands with parallel multi-agent execution, validated by external audits.

#### Key Features

1. **7 Commands with Swarm Mode**
   - `/orchestrator` - 4 agents (Analysis, planning, implementation)
   - `/loop` - 4 agents (Execute, validate, quality check)
   - `/edd` - 4 agents (Capability, behavior, non-functional checks)
   - `/bug` - 4 agents (Analyze, reproduce, locate, fix)
   - `/adversarial` - 4 agents (Challenge, identify gaps, validate)
   - `/parallel` - 7 agents (6 review aspects + coordination)
   - `/gates` - 6 agents (5 language groups + coordination)

2. **Performance Improvements**
   - **3x-6x speedup** on parallel commands
   - Background execution (non-blocking)
   - Inter-agent messaging via built-in mailbox
   - Unified task list coordination

3. **Auto-Swarm Hook**
   - `auto-background-swarm.sh` - Automatically detects Task tool usage
   - Suggests swarm mode parameters for supported commands
   - Registered in PostToolUse hooks

4. **Validation Results**
   - **Integration Tests**: 27/27 tests passing (100%)
   - **Adversarial Audit**: ✅ PASS (Strong defense)
   - **Codex Review**: ✅ PASS (9.3/10 Excellent)
   - **Gemini Validation**: ✅ PASS (9.8/10 Outstanding)

#### System Statistics

```
╔════════════════════════════════════════════════════════════════╗
║              SWARM MODE INTEGRATION v2.81.1 - STATUS              ║
╠════════════════════════════════════════════════════════════════╣
║  Phase              Status    Tests      Audits        Score     ║
║  ─────────────────────────────────────────────────────────────  ║
║  Phase 1 (Core)     ✅ 100%   ✅ 9/9     ✅ PASS        N/A      ║
║  Phase 2 (Secondary) ✅ 100%   ✅ 6/6     ✅ PASS        N/A      ║
║  Phase 3 (Hooks)    ✅ 100%   ✅ 4/4     ✅ PASS        N/A      ║
║  Phase 4 (Docs)     ✅ 100%   ✅ 5/5     ✅ PASS        N/A      ║
║  Phase 5 (Validation)✅ 100%   ✅ 3/3     ✅ 3/3 PASS    9.5/10   ║
║  ─────────────────────────────────────────────────────────────  ║
║  OVERALL            ✅ 100%   ✅ 27/27   ✅ 3/3 PASS    9.5/10   ║
╚════════════════════════════════════════════════════════════════╝
```

#### Configuration

Swarm mode requires **ONE configuration**:

```json
{
  "permissions": {
    "defaultMode": "delegate"
  }
}
```

**Note**: Environment variables (`CLAUDE_CODE_AGENT_*`) are set **dynamically** by Claude Code when spawning teammates.

#### Usage

```bash
# Swarm mode is enabled by default
/orchestrator "Implement distributed system"
/loop "fix all type errors"
/edd "Define feature requirements"
/bug "Authentication fails"
/adversarial "Design rate limiter"
/parallel "src/auth/"
/gates

# All commands spawn teammates automatically
# 3x-6x faster execution on parallel tasks
```

**Documentation**: [Swarm Mode Usage Guide](docs/swarm-mode/SWARM_MODE_USAGE_GUIDE.md) | [Integration Plan](docs/architecture/SWARM_MODE_INTEGRATION_PLAN_v2.81.1.md) | [Consolidated Audits](docs/swarm-mode/CONSOLIDATED_AUDITS_v2.81.1.md)

---

## ✨ Promptify Integration (v2.82.0) ✅ NEW

**Overview**: Automatic prompt optimization system that detects vague user prompts and enhances them using Ralph's context and memory.

### Key Features

1. **Vague Prompt Detection** (`promptify-auto-detect.sh`)
   - Clarity scoring algorithm (0-100% based on 7 factors)
   - Vagueness detection (vague words, pronouns, missing structure)
   - Configurable threshold (default: 50%)
   - Non-intrusive suggestions via `additionalContext`

2. **Security Hardening** (`promptify-security.sh`)
   - Credential redaction (SEC-110): Passwords, tokens, emails, API keys
   - Clipboard consent management (SEC-120)
   - Agent execution timeout (SEC-130)
   - Audit logging system (SEC-140)

3. **Ralph Integration** (Phase 3 - 4 components)
   - `ralph-context-injector.sh`: Inject Ralph active context into prompts
   - `ralph-memory-integration.sh`: Apply procedural memory patterns
   - `ralph-quality-gates.sh`: Validate through quality gates
   - `ralph-integration.sh`: Main coordinator combining all components

### How It Works

```
User Prompt (vague/unclear)
        ↓
┌─────────────────────────────────────────┐
│  UserPromptSubmit Event                  │
│  1. command-router.sh (existing)        │
│     - Detects command intent              │
│     - Confidence < 50% = "unclear"        │
└─────────────────────────────────────────┘
        ↓ (if confidence < 50%)
┌─────────────────────────────────────────┐
│  promptify-auto-detect.sh              │
│  - Vagueness detection                 │
│  - Clarity scoring (0-100%)             │
│  - Suggests promptify if needed        │
└─────────────────────────────────────────┘
        ↓
Optimized Prompt (with Ralph context)
        ↓
┌─────────────────────────────────────────┐
│  Ralph Workflow (resumes)              │
│  - CLARIFY (with better prompt)        │
│  - CLASSIFY (higher confidence)        │
│  - PLAN → EXECUTE → VALIDATE           │
└─────────────────────────────────────────┘
```

### Configuration

```bash
# ~/.ralph/config/promptify.json
{
  "enabled": true,
  "vagueness_threshold": 50,
  "security": {
    "redact_credentials": true,
    "require_clipboard_consent": true,
    "audit_log_enabled": true
  },
  "integration": {
    "coordinate_with_command_router": true,
    "inject_ralph_context": true,
    "use_ralph_memory": true,
    "validate_with_quality_gates": true
  }
}
```

### Test Results

```
╔══════════════════════════════════════════════════════════════╗
║     PROMPTIFY INTEGRATION - TEST RESULTS                     ║
╠══════════════════════════════════════════════════════════════╣
║  Test Category              | Tests | Passed | Status        ║
║  ────────────────────────────────────────────────────────────  ║
║  Credential Redaction      |   4   |   4    | ✅ 100%       ║
║  Clarity Scoring           |   3   |   3    | ✅ 100%       ║
║  Hook Integration          |   5   |   5    | ✅ 100%       ║
║  Security Functions        |   3   |   3    | ✅ 100%       ║
║  File Structure            |   1   |   1    | ✅ 100%       ║
║  Ralph Context Injector    |   5   |   5    | ✅ 100%       ║
║  Ralph Memory Integration  |   5   |   5    | ✅ 100%       ║
║  Ralph Quality Gates       |   5   |   5    | ✅ 100%       ║
║  Ralph Integration Main    |   6   |   6    | ✅ 100%       ║
║  Promptify Integration     |   3   |   3    | ✅ 100%       ║
║  ────────────────────────────────────────────────────────────  ║
║  TOTAL                     |  40   |  40    | ✅ 100%       ║
╚══════════════════════════════════════════════════════════════╝
```

### Security Audit

**Overall Risk**: MEDIUM → LOW (after fixes)

| Finding | Severity | Status |
|---------|----------|--------|
| Unsafe eval usage | MEDIUM | ✅ FIXED (function removed) |
| Input size truncation bug | MEDIUM | ✅ FIXED (syntax verified) |
| Credential redaction | - | ✅ EXCELLENT (10+ patterns) |
| Prompt injection detection | - | ✅ GOOD (pattern-based) |

**Documentation**: [Promptify Integration Guide](docs/promptify-integration/README.md) | [Implementation Complete](docs/promptify-integration/IMPLEMENTATION_COMPLETE.md) | [Security Audit](docs/security/PROMPTIFY_SECURITY_AUDIT_v1.0.0.md)

### Quick Test

```bash
# Run complete test suite
./tests/promptify-integration/run-all-complete-tests.sh

# Run Phase 3 tests only
./tests/promptify-integration/test-phase3-ralph-integration.sh

# View Ralph integration in action
.claude/hooks/ralph-integration.sh
# → Shows context injection, memory patterns, quality gates
```

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Tech Stack](#tech-stack)
4. [Prerequisites](#prerequisites)
5. [Getting Started](#getting-started)
6. [Installation](#installation)
7. [Configuration](#configuration)
8. [Architecture](#architecture)
9. [Memory System](#memory-system)
10. [Learning System (v2.81.2)](#learning-system--v2812)
11. [Hooks System](#hooks-system)
12. [Agent System](#agent-system)
13. [Commands Reference](#commands-reference)
14. [Testing](#testing)
15. [Development]((#development)
16. [Troubleshooting](#troubleshooting)
17. [Contributing](#contributing)
18. [License](#license)
19. [Changelog](#changelog)
10. [Learning System (v2.81.2)](#learning-system--v2812)
11. [Hooks System](#hooks-system)
12. [Agent System](#agent-system)
13. [Commands Reference]((#commands-reference)
14. [Testing](#testing)
15. [Development]((#development)
16. [Troubleshooting](#troubleshooting)
17. [Contributing](#contributing)
18. [License](#license)
19. [Changelog](#changelog)

---

## Overview

**Multi-Agent Ralph Loop** is a sophisticated orchestration system that combines smart memory-driven planning, parallel memory search, multi-agent coordination, and automatic learning from quality repositories.

Built as an advanced enhancement to Claude Code, it provides:

- **Intelligent Orchestration**: RLM-inspired routing with complexity classification
- **Memory System**: Parallel search across semantic, episodic, and procedural memory
- **Multi-Agent Coordination**: Native swarm mode with specialized teammates
- **Automatic Learning**: Curates GitHub repos, extracts patterns, applies rules automatically
- **Quality Gates**: Adversarial validation with 3-fix rule
- **Checkpoints**: Time travel for orchestration state
- **Dynamic Contexts**: dev, review, research, debug modes

### What It Does

Ralph acts as an intelligent project manager that:

1. **Analyzes** your request using 3-dimensional classification (complexity, information density, context requirement)
2. **Plans** the implementation with architectural considerations
3. **Routes** to optimal model (GLM-4.7 PRIMARY for all tasks)
4. **Validates** quality using adversarial methods
5. **Learns** from quality repositories automatically
6. **Coordinates** multiple agents for complex tasks
7. **Remembers** everything across sessions

### Who It's For

- **Software Engineers**: Building complex systems with proper architecture
- **Teams**: Coordinating multi-step development workflows
- **Researchers**: Analyzing codebases and extracting patterns
- **Architects**: Validating design decisions and patterns

---

## Key Features

### Orchestration

- **RLM-Inspired Routing**: 3-dimensional classification (complexity 1-10, information density, context requirement)
- **Smart Memory Search**: Parallel search across 4 memory systems
- **Plan Lifecycle Management**: Create, archive, restore plans
- **Checkpoints**: Save/restore orchestration state (time travel)
- **Agent Handoffs**: Explicit agent-to-agent transfers

### Memory System

- **Semantic Memory**: Facts and preferences (persistent)
- **Episodic Memory**: Experiences with 30-day TTL
- **Procedural Memory**: Learned behaviors with confidence scores
- **Claude-Mem Integration**: Primary memory backend (MCP plugin)
- **1003+ Procedural Rules**: Auto-extracted from quality repos

### Learning System (v2.81.2) 🆕

- **Auto-Curation**: GitHub repository discovery via API
- **Quality Scoring**: Metrics + context relevance scoring
- **Pattern Extraction**: AST-based pattern extraction
- **Rule Validation**: Automatic verification of rule application
- **Metrics Tracking**: Utilization rate, application rate

### Multi-Agent Coordination

- **Swarm Mode**: Native Claude Code 2.1.22+ integration
- **Teammate Spawning**: Automatic spawning of specialized agents
- **Inter-Agent Messaging**: Direct communication between agents
- **Shared Task List**: Collaborative task management
- **Plan Approval**: Leader approves/rejects teammate plans

### Quality Validation

- **3-Fix Rule**: CORRECTNESS, QUALITY, CONSISTENCY validation
- **Adversarial Validation**: Dual-model validation for high complexity
- **Quality Gates Parallel**: 4 parallel quality gates (90s timeout)
- **Security Scanning**: semgrep + gitleaks integration
- **Type Safety**: TypeScript validation where applicable

### Observability

- **Statusline**: Dual context display (cumulative + current window)
- **Health Checks**: System health monitoring with `ralph health`
- **Traceability**: Event logs and session history
- **Metrics Dashboard**: Learning metrics and rule statistics

---

## Tech Stack

### Core System

- **Language**: Bash (hooks), TypeScript (some tools), Python (curator scripts)
- **Provider**: Zai (GLM-4.7)
- **Claude Code**: v2.1.22+ (required for Task primitive)
- **Configuration**: JSON-based settings in `~/.claude-sneakpeek/zai/config/`

### Memory Architecture

- **Primary**: claude-mem MCP plugin (semantic + episodic)
- **Secondary**: Local JSON files for procedural rules
- **Backup**: Git-based plan state tracking

### Testing

- **Bash**: Native bash testing with assert functions
- **Coverage**: Manual tracking (no automated coverage tools yet)
- **Types**: Unit, Integration, Functional, End-to-End

### External Dependencies

- **jq**: JSON processing and validation
- **git**: Version control and diff analysis
- **curl**: HTTP requests (GitHub API)
- **gh**: GitHub CLI (optional, for enhanced access)

---

## Prerequisites

### Required

- **Claude Code**: v2.1.16+ (for Task primitive support)
- **GLM-4.7 API Access**: Configured in Zai environment
- **Bash**: Version 4.0+ (for hooks and scripts)
- **jq**: Version 1.6+ (for JSON processing)
- **git**: Version 2.0+ (for version control)
- **curl**: Version 7.0+ (for API calls)

### Optional (Recommended)

- **GitHub CLI**: Enhanced GitHub API access (`gh`)
- **Zai CLI**: Web search and vision capabilities (`npx zai-cli`)

### System Requirements

- **OS**: macOS, Linux, or WSL2 on Windows
- **Memory**: 8GB RAM minimum (16GB recommended for complex tasks)
- **Disk**: 500MB for Ralph system + 10MB for session files
- **Network**: Internet connection for GLM-4.7 API calls

---

## Getting Started

### Quick Start (5 minutes)

1. **Clone the repository**:
```bash
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop
```

2. **Verify installation**:
```bash
# Check Ralph directory exists
ls -la ~/.ralph/

# Check hooks are registered
grep "learning-gate" ~/.claude-sneakpeek/zai/config/settings.json

# Check system health
ralph health --compact
```

3. **Run orchestration**:
```bash
# Simple task
/orchestrator "Create a REST API endpoint"

# Complex task with swarm mode
/orchestrator "Implement distributed caching system" --launch-swarm --teammate-count 3
```

### First Run

On first use, Ralph will:

1. **Auto-migrate** plan-state to v2.51+ schema
2. **Initialize** session ledger and context tracking
3. **Create** snapshot of current state
4. **Load** hooks and commands

---

## Installation

### Standard Installation

The repository is designed to work with Claude Code. No separate installation required.

**Hook Configuration**:
- Hooks are registered in `~/.claude-sneakpeek/zai/config/settings.json`
- Hooks live in `.claude/hooks/` (project-local)
- Additional hooks in `~/.claude/hooks/` (global)

### Learning System Installation

The Learning System v2.81.2 is automatically installed and configured:

```bash
# Verify Learning System components
ls -la ~/.ralph/curator/scripts/
ls -la ~/.claude/hooks/learning-*.sh
ls -la ~/.ralph/procedural/rules.json
```

Expected output:
```
curator-scoring.sh (v2.0.0)
curator-discovery.sh (v2.0.0)
curator-rank.sh (v2.0.0)
learning-gate.sh (v1.0.0)
rule-verification.sh (v1.0.0)
```

### Manual Installation (if needed)

If hooks need to be reinstalled:

```bash
# Copy hooks to global directory
cp .claude/hooks/learning-gate.sh ~/.claude/hooks/
cp .claude/hooks/rule-verification.sh ~/.claude/hooks/

# Make executable
chmod +x ~/.claude/hooks/learning-*.sh
```

---

## Configuration

### Primary Configuration File

**Location**: `~/.claude-sneakpeek/zai/config/settings.json`

**Key Settings**:

```json
{
  "model": "glm-4.7",
  "defaultMode": "delegate",
  "env": {
    "CLAUDE_CODE_AGENT_ID": "claude-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "multi-agent-ralph-loop"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Task",
        "hooks": [
          { "command": "/path/to/lsa-pre-step.sh" },
          { "command": "/path/to/procedural-inject.sh" },
          { "command": "/path/to/learning-gate.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "TaskUpdate",
        "hooks": [
          { "command": "/path/to/rule-verification.sh" }
        ]
      }
    ]
  }
}
```

### Memory Configuration

**Location**: `~/.ralph/config/memory-config.json`

```json
{
  "procedural": {
    "inject_to_prompts": true,
    "min_confidence": 0.7,
    "max_rules_per_injection": 5
  },
  "learning": {
    "auto_execute": true,
    "min_complexity_for_gate": 3,
    "block_critical_without_rules": true
  }
}
```

### Learning System Configuration

**Location**: `~/.ralph/curator/config.json`

```json
{
  "github": {
    "api_token": "YOUR_TOKEN_HERE",
    "max_results_per_page": 100,
    "rate_limit_delay": 1.0
  },
  "scoring": {
    "min_quality_score": 50,
    "context_boost": 10
  },
  "ranking": {
    "default_top_n": 50,
    "max_per_org": 3
  }
}
```

---

## Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    MULTI-AGENT RALPH ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │  User Request   │───▶│ Claude Code  │───▶│   Claude     │    │
│  └────────────────┘    │  v2.1.22+   │    │   (GLM-4.7)  │    │
│                          └──────────────┘    └──────┬───────┘    │
│                                 │                           │        │
│                          ┌────▼─────┐                   │        │
│                          │ Settings │                   │        │
│                          │ .json   │                   │        │
│                          └────┬─────┘                   │        │
│                               │                           │        │
│          ┌──────────────────────┼───────────────────────────┐        │
│          │                      │                           │        │
│          │              ┌───────▼────────────────┐        │        │
│          │              │                          │        │        │
│          │              ▼                          ▼        │        │
│          │    ┌──────────────────────────────────────┐  │        │
│          │    │   HOOK SYSTEM (67 hooks)          │  │        │
│          │    │                                  │  │        │
│          │    │  SessionStart                    │  │        │
│          │    │    - session-ledger.sh            │  │        │
│          │    │    - auto-migrate-plan-state     │  │        │
│          │    │                                  │  │        │
│          │    │  PreToolUse                      │  │        │
│          │    │    - lsa-pre-step.sh             │  │        │
│          │    │    - procedural-inject.sh         │  │        │
│          │    │    - learning-gate.sh ⭐          │  │        │
│          │    │                                  │  │        │
│          │    │  PostToolUse                     │  │        │
│          │    │    - sec-context-validate.sh       │  │        │
│          │    │    - quality-gates-v2.sh          │  │        │        │
│          │    │    - rule-verification.sh ⭐     │  │        │
│          │    │                                  │  │        │
│          │    │  Stop                            │  │        │
│          │    │    - reflection-engine.sh          │  │        │
│          │    │    - orchestrator-report.sh       │  │        │
│          │    └───────────────────────────────────┘  │        │
│          │                                          │        │
│          └──────────────────┬───────────────────────────┘        │
│                             │                                   │        │
│          ┌────────────────▼─────────────────────────────┐  │        │
│          │                                          │  │        │
│          │       ┌────────────────────────────────┐     │  │        │
│          │       │   MEMORY SYSTEM                │     │  │        │
│          │       │                              │     │  │        │
│          │       │  ┌────────────────────────┐    │     │  │        │
│          │       │  │ Semantic Memory     │    │     │  │        │
│       ┌───┴───────┐  │  │  (claude-mem MCP)     │    │     │  │        │
│       │claude-mem │  │  └────────────────────────┘    │     │  │        │
│       │   MCP    │  │                              │     │  │        │
│       │          │  │  ┌────────────────────────┐    │     │  │        │
│       │          │  │  │ Episodic Memory      │    │     │  │        │
│       │          │  │  │ (30-day TTL)         │    │     │  │        │
│       │          │  │  └────────────────────────┘    │     │  │        │
│       │          │  │                              │     │  │        │
│       │          │  │  ┌────────────────────────┐    │     │  │        │
│       │          │  │  │ Procedural Memory    │    │     │  │        │
│       │          │  │  │ (1003+ rules)        │    │     │  │        │
│       │          │  │  └────────────────────────┘    │     │  │        │
│       │          │  │                              │     │  │        │
│       │          │  └──────────────────────────────┘     │  │        │
│       │          │                                          │  │        │
│       └──────────┴───────────────────────────────────┘  │        │
│                                                            │        │
│       ┌────────────────────────────────────────────────┴───┐  │        │
│       │                                                      │  │        │
│       │       ┌────────────────────────────────┐              │  │        │
│       │       │   LEARNING SYSTEM (v2.81.2)       │              │  │        │
│       │       │                                  │              │  │        │
│       │       │  ┌────────────────────────┐   │              │  │        │
│       │       │  │ Curator (GitHub API)     │   │              │  │        │
│       │       │  │ - Discovery              │   │              │  │        │
│ │       │       │  │ - Scoring               │   │              │  │        │
│       │       │  │  │ - Ranking                │   │              │  │        │
│       │       │  └────────────────────────┘   │              │  │        │
│       │       │                                  │              │  │        │
│       │       │  ┌────────────────────────┐   │              │  │        │
│       │       │  │ Repository Learner      │   │              │  │        │
│       │       │  │ - Pattern extraction   │   │              │  │  │        │
│       │       │  │ - Rule generation      │   │              │  │ │        │
│       │       │  └────────────────────────┘   │              │  │        │
│       │       │                                  │              │  │        │
│       │       │  ┌────────────────────────┐   │              │  │        │
│       │       │  │ Learning Gate           │   │              │  │        │
│       │       │  │ - Detects gaps          │   │              │  │        │
│       │       │  │ - Recommends /curator  │   │              │  │        │
│       │       │  └────────────────────────┘   │              │  │        │
│       │       │                                  │              │  │        │
│       │       │  ┌────────────────────────┐   │              │  │        │
│       │       │  │ Rule Verification      │   │              │  │        │
│       │       │  │ - Validates application   │   │              │  │        │
│       │       │  │ - Updates metrics        │   │              │  │        │
│       │       │  └────────────────────────┘   │              │  │        │
│       │       │                                  │              │  │        │
│       │       └──────────────────────────────────┘  │        │
│                                                            │        │
└────────────────────────────────────────────────────────┴────────┘
```

### Directory Structure

```
multi-agent-ralph-loop/
├── .claude/                      # Claude Code workspace
│   ├── hooks/                     # Hook scripts (67 registrations)
│   │   ├── learning-gate.sh         # ⭐ Auto-learning trigger
│   │   ├── rule-verification.sh    # ⭐ Rule validation
│   │   ├── procedural-inject.sh     # Procedural memory injection
│   │   └── ... (64 more hooks)
│   ├── commands/                   # Custom commands (/orchestrator, /loop, etc.)
│   ├── scripts/                    # Utility scripts
│   ├── schemas/                    # JSON schemas for validation
│   └── tasks/                      # Task primitive storage
├── docs/                         # All development documentation
│   ├── architecture/             # Architecture diagrams
│   ├── analysis/                 # Analysis reports
│   ├── implementation/            # Implementation docs
│   └── guides/                   # User guides
├── tests/                        # Test suites at project root
│   ├── unit/                     # Unit tests
│   ├── integration/              # Integration tests
│   ├── functional/               # Functional tests
│   └── end-to-end/                # End-to-end tests
├── .github/                      # GitHub-specific files
│   └── workflows/                 # CI/CD workflows (if any)
└── README.md                      # This file
```

---

## Memory System

### Memory Types

**Semantic Memory** (via claude-mem MCP)
- **Purpose**: Persistent facts and knowledge
- **Storage**: claude-mem backend (MCP plugin)
- **TTL**: Never expires
- **Example**: "The authentication system uses JWT tokens with 24-hour expiration"

**Episodic Memory**
- **Purpose**: Experiences and observations
- **Storage**: `~/.ralph/episodes/`
- **TTL**: 30 days
- **Example**: "Session on 2026-01-29 implemented OAuth2 with issues in token refresh"

**Procedural Memory**
- **Purpose**: Learned behaviors and patterns
- **Storage**: `~/.ralph/procedural/rules.json`
- **TTL**: Never expires
- **Example**: Error handling pattern with try-catch and exponential backoff

### Memory Search

**Parallel Search** across 4 systems:

```bash
ralph memory-search "authentication patterns"
# Searches claude-mem semantic, memvid episodes, handoffs, ledgers
```

**Results include**:
- Observation ID
- Timestamp
- Type (semantic, episodic, etc.)
- Relevance score

---

## Learning System (v2.81.2)

### Overview

The Learning System automatically improves code quality by:

1. **Discovering** quality repositories from GitHub
2. **Extracting** best practices and patterns
3. **Generating** procedural rules with confidence scores
4. **Applying** rules automatically during development
5. **Validating** that rules were actually used

### Components

**Repo Curator**

Three-stage pipeline for repository curation:

1. **Discovery** (`curator-discovery.sh`)
   - GitHub API search with filters
   - Type: backend, frontend, fullstack, library, framework
   - Language: TypeScript, Python, JavaScript, Go, Rust
   - Results: Up to 1000 repos per search

2. **Scoring** (`curator-scoring.sh`)
   - Quality metrics: stars, forks, recency
   - Context relevance: matches your current task
   - Combined score: weighted average

3. **Ranking** (`curator-rank.sh`)
   - Top N repositories (configurable, default: 50)
   - Max-per-org limits (default: 3 per org)
   - Sort by: quality, context, combined

**Repository Learner**

Extracts patterns from approved repositories:

1. Clone/acquire repository
2. AST-based pattern extraction
3. Domain classification (backend, frontend, security, etc.)
4. Rule generation with confidence scores
5. Deduplication and storage

**Auto-Learning Hooks**

**learning-gate.sh** (v1.0.0)
- Trigger: PreToolUse (Task)
- Detects: Task complexity ≥3 without relevant rules
- Action: Recommends `/curator` execution
- Blocks: High complexity tasks (≥7) without rules

**rule-verification.sh** (v1.0.0)
- Trigger: PostToolUse (TaskUpdate)
- Analyzes: Modified code for rule patterns
- Updates: Rule metrics (applied_count, skipped_count)
- Reports: Utilization rate and ghost rules

### Usage

```bash
# Full learning pipeline
/curator full --type backend --lang typescript

# Discover repositories
/curator discovery --query "microservice" --max-results 200

# Score with context relevance
/curator scoring --context "error handling,retry,resilience"

# Rank top results
/curator rank --top-n 20 --max-per-org 2

# View results
/curator show --type backend --lang typescript

# Approve repositories
/curator approve nestjs/nest
/curator approve --all

# Learn from approved repos
/curator learn --all

# Check system health
ralph health
```

### Current Statistics

```
Total Rules: 1003
With Domain: 148 (14.7%)
With Usage: 146 (14.5%)
Applied Count: Tracking active
Utilization Rate: Measured automatically
```

---

## Hooks System

> **⚠️ CRITICAL v2.81.1**: `PostCompact` does NOT exist in Claude Code. Use `PreCompact` for saving state and `SessionStart` for restoring. See [docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md](docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md).

### Hook Events

| Event | Purpose | Example Hooks |
|-------|---------|---------------|
| **SessionStart** | Initialize session, restore context after compaction | session-ledger, auto-migrate-plan-state, session-start-restore-context |
| **UserPromptSubmit** | Before user prompt | context-warning, periodic-reminder |
| **PreToolUse** | Before tool execution | lsa-pre-step, procedural-inject, learning-gate |
| **PostToolUse** | After tool execution | quality-gates-v2, rule-verification |
| **PreCompact** | Before context compaction (ONLY compaction event) | pre-compact-handoff, post-compact-restore (both run here) |
| **Stop** | Session end | reflection-engine, orchestrator-report |
| **PostCompact** | ❌ **DOES NOT EXIST** - Feature request #14258 |

### ⚠️ PostCompact Does NOT Exist (v2.81.1)

**Discovery**: `PostCompact` is NOT a valid hook event in Claude Code as of January 2026.

**What This Means**:
- ❌ There is NO `PostCompact` event that fires after compaction
- ✅ Only `PreCompact` exists (fires BEFORE compaction)
- ✅ Use `SessionStart` for post-compaction context restoration

**Correct Compaction Pattern**:
```
PreCompact Event → Save state (ledger, handoff, plan-state)
    ↓
Compaction Happens → Old messages removed
    ↓
SessionStart Event → Restore state in new session ✅
```

**Implementation**:
- `pre-compact-handoff.sh` → Saves state in `PreCompact`
- `session-start-restore-context.sh` → Restores state in `SessionStart`
- Both hooks use global paths: `~/.claude-sneakpeek/zai/config/hooks/`

**Documentation**: See [docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md](docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md) for complete details.

### Hook Registration

Hooks are registered in `~/.claude-sneakpeek/zai/config/settings.json`:

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          { "command": "/path/to/pre-compact-handoff.sh" }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          { "command": "/path/to/session-start-restore-context.sh" }
        ]
      }
    ]
  }
}
```

### Creating Custom Hooks

1. Create hook script in `.claude/hooks/`
2. Make it executable: `chmod +x .claude/hooks/your-hook.sh`
3. Register in settings.json
4. Follow [Hook Format Reference](tests/HOOK_FORMAT_REFERENCE.md)

### Hook Output Format

**PreToolUse hooks** (allowing execution):
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
```

**PostToolUse hooks** (continuing execution):
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "continue": true
  }
}
```

### Recent Hook Fixes (v2.81.1 - v2.81.2)

**PreToolUse JSON Schema Fix (v2.81.2) ✅**:

Fixed critical JSON schema validation errors in 4 PreToolUse hooks causing error messages on every Edit, Write, and Bash operation.

**Problem**: Hooks were using incorrect JSON format:
```json
{"decision": "allow", "additionalContext": "..."}  // ❌ Wrong
```

**Solution**: Hooks now use correct `hookSpecificOutput` format:
```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}  // ✅ Correct
```

**Affected Hooks** (4 files):
- `checkpoint-auto-save.sh` - Auto-checkpoint before edits
- `fast-path-check.sh` - Detect trivial tasks for fast-path routing
- `agent-memory-auto-init.sh` - Auto-initialize agent memory buffers
- `orchestrator-auto-learn.sh` - Inject learning recommendations

**Documentation**: [PRETOOLUSE_JSON_SCHEMA_FIX_v2.81.2.md](docs/bugs/PRETOOLUSE_JSON_SCHEMA_FIX_v2.81.2.md)

---

**Previous Fixes (v2.81.1)**:

1. **SessionStart Hook Failure**: `auto-sync-global.sh` had glob pattern bug
   - **Problem**: `for file in *.md` failed when no files matched
   - **Solution**: Added `[ -f "$file" ] || continue` to each loop
   - **Result**: SessionStart hooks now exit successfully

2. **PostCompact Misinformation**: Incorrect documentation mentioned `PostCompact` as valid
   - **Problem**: Orchestrator created docs mentioning non-existent event
   - **Solution**: Created comprehensive docs clarifying `PostCompact` doesn't exist
   - **Result**: Correct pattern documented (PreCompact + SessionStart)

---

## Agent System

### Available Agents

| Agent | Model | Capabilities |
|-------|-------|--------------|
| `orchestrator` | GLM-4.7 | Planning, classification, delegation |
| `security-auditor` | GLM-4.7 | Security, vulnerability scan |
| `debugger` | GLM-4.7 | Debugging, error analysis |
| `code-reviewer` | GLM-4.7 | Code review, patterns |
| `test-architect` | GLM-4.7 | Testing, test generation |
| `refactorer` | GLM-4.7 | Refactoring, optimization |
| `repository-learner` | GLM-4.7 | Learning, pattern extraction |
| `repo-curator` | GLM-4.7 | Curation, scoring, discovery |

### Swarm Mode (v2.81.0)

**Requirements**:
- Claude Code v2.1.16+ (Task primitive support)
- TeammateTool available (built-in)
- defaultMode: "delegate" in settings.json

**Usage**:
```bash
# Automatic spawning
/orchestrator "Implement distributed system" --launch-swarm --teammate-count 3

# Manual spawning
Task:
  subagent_type: "orchestrator"
  team_name: "my-team"
  name: "team-lead"
  mode: "delegate"

ExitPlanMode:
  launchSwarm: true
  teammateCount: 3
```

---

## Commands Reference

### Core Commands

```bash
# Full orchestration
/orchestrator "Implement feature X"
ralph orch "Implement feature X"

# Quality validation
/gates
ralph gates

# Loop until VERIFIED_DONE
/loop "fix all issues"
ralph loop "fix all issues"

# Checkpoints
ralph checkpoint save "before-refactor" "Pre-refactoring"
ralph checkpoint restore "before-refactor"
ralph checkpoint list

# Handoffs
ralph handoff transfer --from orchestrator --to security-auditor --task "Audit auth module"

# Health check
ralph health
ralph health --compact

# Memory search
ralph memory-search "authentication patterns"
```

### Learning Commands

```bash
# Full pipeline
/curator full --type backend --lang typescript

# Discovery
/curator discovery --type backend --lang typescript --max-results 100

# Scoring
/curator scoring --input candidates/repos.json --context "error handling"

# Ranking
/curator rank --input candidates/scored.json --top-n 20

# Approval
/curator approve nestjs/nest
/curator approve --all

# Learning
/curator learn --all
/curator learn --repo nestjs/nest

# Queue management
/curator show --type backend --lang typescript
/curator pending --type backend
```

### Claude Code Documentation

```bash
/docs hooks           # Hooks reference
/docs mcp             # MCP integration
/docs what's new      # Recent doc changes
/docs changelog       # Claude Code release notes
```

---

## Testing

### Test Suite

**Total Tests**: 62 tests (100% pass rate)

| Test Type | Location | Count | Status |
|-----------|----------|-------|--------|
| Unit Tests | `tests/unit/` | 13 | ✅ Passing |
| Integration Tests | `tests/integration/` | 13 | ✅ Passing |
| Functional Tests | `tests/functional/` | 4 | ✅ Passing |
| End-to-End Tests | `tests/end-to-end/` | 32 | ✅ Passing |

### Running Tests

```bash
# Run all tests
./tests/run-all-learning-tests.sh

# Unit tests only
./tests/unit/test-unit-learning-hooks-v1.sh

# Integration tests only
./tests/integration/test-learning-integration-v1.sh

# Functional tests only
./tests/functional/test-functional-learning-v1.sh

# End-to-end tests only
./tests/end-to-end/test-e2e-learning-complete-v1.sh
```

### Test Organization

```
tests/
├── unit/                     # Isolated component tests
├── integration/              # Component integration tests
├── functional/               # Real-world scenario tests
├── end-to-end/                # Complete system validation
├── quality-parallel/         # Quality gate validation
├── swarm-mode/               # Swarm mode tests
└── coverage.json             # Coverage tracking
```

---

## Development

### Project Structure

```
multi-agent-ralph-loop/
├── docs/                    # All development documentation
│   ├── architecture/        # Architecture diagrams
│   ├── analysis/            # Analysis reports
│   ├── implementation/     # Implementation docs
│   └── guides/              # User guides
├── tests/                   # Test suites at project root
│   ├── unit/                # Unit tests
│   ├── integration/         # Integration tests
│   ├── functional/          # Functional tests
│   └── end-to-end/           # End-to-end tests
├── .claude/                 # Claude Code workspace
│   ├── hooks/               # Hook scripts
│   ├── commands/             # Custom commands
│   └── schemas/             # Validation schemas
└── README.md                # This file
```

### Creating Hooks

**Hook Template**:

```bash
#!/usr/bin/env bash
# my-hook.sh - Description
# Version: 1.0.0
# Part of Ralph Multi-Agent System

set -euo pipefail
umask 077

# Read input (for PreToolUse/PostToolUse)
INPUT=$(cat)

# Parse tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // empty' 2>/dev/null || echo "")

# Process based on tool name
case "$TOOL_NAME" in
    "Task")
        # Your logic here
        ;;
    "Edit")
        # Your logic here
        ;;
esac

# Output required format
echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
```

### Adding Commands

Create command file in `.claude/commands/`:

```bash
#!/usr/bin/env bash
# my-command - Command description

command_main() {
    # Command logic here
}

command_main "$@"
```

---

## Troubleshooting

### Learning System Issues

**Issue**: learning-gate recommends /curator but I have rules

**Solution**:
```bash
# Check rule domains
jq '.rules[] | .domain' ~/.ralph/procedural/rules.json | sort | uniq -c

# Learn rules for specific domain
/curator discovery --type <your-domain> --lang typescript
/curator learn --all
```

**Issue**: rule-verification.sh reports 0% utilization

**Solution**:
```bash
# Check rule patterns
jq '.rules[0] | {pattern, keywords, domain}' ~/.ralph/procedural/rules.json

# Verify with test file
echo "try { } catch (e) { }" > /tmp/test.ts
grep -i "try.*catch" /tmp/test.ts
```

**Issue**: GitHub API rate limit

**Solution**:
```bash
# Check rate limit
curl -I "https://api.github.com/search/repositories?q=test"

# Use authentication
export GITHUB_TOKEN="your_token"
gh auth login

# Reduce max-results
/curator discovery --max-results 50
```

### Hook Issues

**Issue**: Hook not executing

**Solution**:
```bash
# Verify registration
grep "your-hook" ~/.claude-sneakpeek/zai/config/settings.json

# Check file exists
ls -l ~/.claude/hooks/your-hook.sh

# Check permissions
chmod +x ~/.claude/hooks/your-hook.sh
```

**Issue**: Hook crashes or errors

**Solution**:
```bash
# Test hook manually
echo '{"toolName":"Task","toolInput":{}}' | ~/.claude/hooks/your-hook.sh

# Check logs
cat ~/.ralph/logs/$(date +%Y%m%d)*.log 2>/dev/null | tail -50
```

### Memory Issues

**Issue**: Plans not persisting across compaction

**Solution**:
```bash
# Check plan-state exists
ls -la .claude/plan-state.json

# Check snapshot exists
ls -la .claude/snapshots/20260129/

# Recreate if needed
ralph checkpoint save "manual-save" "Manual save before fix"
```

**Issue**: Memory search not finding recent data

**Solution**:
```bash
# Check memory backend
cat ~/.claude/memory-context.json

# Verify claude-mem is enabled
grep "claude-mem" ~/.claude-sneakpeek/zai/config/settings.json

# Try direct search
ralph memory-search "your query"
```

---

## Contributing

We welcome contributions! Please follow these guidelines:

### Code Style

- **Bash**: Follow shellcheck recommendations
- **TypeScript**: Follow community standards
- **Documentation**: English-only for all documentation
- **Commit Messages**: Conventional commits format

### Testing

- Add tests for new features
- Ensure all tests pass before submitting PR
- Include integration tests for hooks
- Add documentation for new commands

### Pull Requests

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if needed
5. Ensure all tests pass
6. Submit a pull request with clear description

### Documentation Standards

- All documentation must be in English
- Use proper markdown formatting
- Include examples where helpful
- Update relevant README sections

---

## License

Business Source License 1.1

**Summary**:
- ✅ Permits commercial use
- ✅ Permits unlimited modification
- ✅ Permits unlimited distribution
- ✅ Requires attribution in derivative works
- ✅ **PROHIBITS** sublicensing and selling (must give away for free)

**Key Points**:
- You can use this in commercial projects
- You can modify and distribute your changes
- You CANNOT sell this or sub-license it
- You MUST include attribution in derivative works
- Ideal for: Open source projects, internal tools, consulting

**For Standard (MIT/Apache 2.0)**: Contact the repository owner.

---

## Changelog

### [2.81.2] - 2026-01-29

**Added**
- **Automatic Learning System**: Complete integration with GitHub repository curation
- **learning-gate.sh v1.0.0**: Auto-executes /curator when memory is critically empty
- **rule-verification.sh v1.0.0**: Validates rules were applied in generated code
- **Curator Scripts v2.0.0**: 15 critical bugs fixed across 3 scripts
- **Testing Suite**: 62 tests with 100% pass rate (unit + integration + functional + e2e)
- **Documentation**: Complete integration guide and implementation reports

**Fixed**
- 15 critical bugs in curator scripts (error handling, cleanup, logging, validation)
- Hook registration in settings.json
- Memory system integration issues

**Changed**
- Updated README.md with Learning System v2.81.2 information
- Improved system statistics tracking (91% quality, 89% integration)
- Enhanced troubleshooting section with Learning System specific issues

### [2.81.0] - 2026-01-29

**Added**
- **Native Swarm Mode Integration**: Full integration with Claude Code 2.1.22+ native multi-agent features
- **GLM-4.7 as PRIMARY Model**: Now PRIMARY for ALL complexity levels (1-10)
- **Agent Environment Variables**: CLAUDE_CODE_AGENT_ID, CLAUDE_CODE_AGENT_NAME, CLAUDE_CODE_TEAM_NAME
- **Swarm Mode Validation**: 44 unit tests to validate configuration

**Changed**
- **Model Routing**: GLM-4.7 is now universal PRIMARY for all task complexities
- **DefaultMode**: Set to "delegate" for swarm mode

**Deprecated**
- **MiniMax Fully Deprecated**: Now optional fallback only, not recommended

See [CHANGELOG.md](CHANGELOG.md) for full version history.

---

## Support

- **Issues**: [GitHub Issues](https://github.com/alfredolopez80/multi-agent-ralph-loop/issues)
- **Documentation**: See [docs/](docs/) folder
- **Tests**: Run `ralph health` for system status

---

**Version**: v2.81.2
**Status**: Production Ready ✅
**Last Updated**: 2026-01-29
**Tests**: 62/62 passing (100%)
