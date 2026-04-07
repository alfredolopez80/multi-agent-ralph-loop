# Curator AI-Driven Save Pattern — Refactor PRD
**Version**: 1.0.0
**Date**: 2026-04-07
**Author**: ralph-coder-delta (Wave 1.6)
**Target wave**: W2.3
**Status**: DESIGN ONLY — no implementation

---

## 1. Executive Summary

The current curator pipeline uses static REGEX-based classification to decide what patterns are "worth saving" from a repository. This decision is made by `curator-learn.sh` using hardcoded keyword dictionaries (8 domain keyword arrays, ~80 keywords total). The desired state is for the **AI agent itself** to decide what constitutes a meaningful, reusable pattern — bringing the curator pipeline in line with MemPalace's architecture where value judgments are made by the learning agent, not by brittle string matching.

This document covers:
- Current state analysis (architecture + limitations)
- Desired state: AI-driven save pattern
- Migration strategy
- API contract
- Test plan
- Rollback plan
- Risk register
- Reusable utilities identified for `curator_lib.sh`

---

## 2. Current State Architecture

### 2.1 Pipeline Flow (ASCII)

```
User / orchestrator-auto-learn.sh
         |
         v
  curator.sh full  [--type, --lang, --tier, --context, --auto-approve]
         |
         +-- Step 1: curator-discovery.sh  --> GitHub search --> candidates JSON
         |
         +-- Step 2: curator-scoring.sh    --> quality score (REGEX on description)
         |                                     context_relevance_score (keyword grep -F)
         |
         +-- Step 3: curator-rank.sh       --> sorted ranking JSON (composite score)
         |
         +-- Step 4: curator-approve.sh    --> (optional) auto-approve top N
         |
         +-- Step 5: curator-ingest.sh     --> git clone --depth 1
         |                                     manifest.json created
         |
         +-- Step 6: curator-learn.sh      --> REGEX pattern extraction
                       |                        write to ~/.ralph/procedural/rules.json
                       |                        update manifest.json
                       +-- vault sync         write to Obsidian vault wiki article
```

### 2.2 Where the Current Pipeline Makes "Worth Saving" Decisions

| Script | Mechanism | Type |
|---|---|---|
| `curator-discovery.sh` | GitHub search query (star filters, topic filters) | Passive filter |
| `curator-scoring.sh` | `calculate_relevance_score()`: keyword grep against repo description | REGEX (passive) |
| `curator-scoring.sh` | `calculate_score()`: star count, issue ratio, description length | Heuristic |
| `curator-rank.sh` | `_composite_score = quality_score * (1 + relevance_boost)` | Formula |
| `curator-learn.sh` | `extract_patterns_from_files()`: grep for function/class/import keywords | REGEX (passive) |
| `curator-learn.sh` | `detect_domain()`: keyword frequency count per domain | REGEX (passive) |
| `curator-learn.sh` | `detect_language()`: manifest file presence check | Heuristic |

**Key finding**: The only agent making decisions is `curator-learn.sh` — and it uses entirely passive REGEX matching. It cannot evaluate whether a pattern is actually novel, useful, or worth storing. It stores **every matched function/class definition** up to a 50-file / 50-rule cap.

### 2.3 Inputs and Outputs of curator-learn.sh

**CLI Inputs:**

| Argument | Type | Validation | Default |
|---|---|---|---|
| `--type <type>` | string | `^[a-zA-Z0-9_-]+$` | none (required) |
| `--lang <lang>` | string | `^[a-zA-Z0-9_-]+$` | none (required) |
| `--repo <repo>` | string | `^[a-zA-Z0-9_-]+/[a-zA-Z0-9._-]+$` | none |
| `--all` | flag | none | false |

**Environment Variables:**

| Variable | Default | Purpose |
|---|---|---|
| `VAULT_DIR` | `$HOME/Documents/Obsidian/MiVault` | Obsidian vault root |
| `HOME` | system | Base path for all directories |

**Side Effects (Files Written):**

| File | When | Format |
|---|---|---|
| `~/.ralph/procedural/rules.json` | Always on successful learn | JSON array of rule objects |
| `~/.ralph/procedural/rules.json.backup.<timestamp>` | Before every run | Backup copy |
| `~/.ralph/curator/corpus/approved/<repo>/manifest.json` | On learn | Updated with `files[]`, `patterns_extracted`, `detected_domain`, `detected_language` |
| `$VAULT_DIR/global/wiki/<domain>/curator-<safe_name>.md` | If vault exists | Markdown wiki article |

**Exit Codes:**

| Code | Meaning |
|---|---|
| 0 | Success (including partial: 0 patterns found is not an error) |
| 1 | Invalid arguments, missing approved directory |

**Hooks Called:** None — `curator-learn.sh` is a terminal stage in the pipeline.

### 2.4 Call Sites (Non-Archive)

| Caller | Path | How Called |
|---|---|---|
| `curator.sh` | `.claude/scripts/curator.sh` | Not called directly — `curator.sh` calls discovery, scoring, rank, approve. Learn is manual step after. |
| Test suite | `tests/learning-system/test-learning-complete-v2.88.sh` | Lines 229, 294, 359, 630 — direct invocation |
| Test suite | `tests/learning-system/test-learning-system-v2.88.sh` | Lines 76, 110, 135, 283 — direct invocation |
| `autoresearch` skill | `.claude/skills/autoresearch/SKILL.md` | Documents `detect_language()` as reusable pattern |

**Important**: `orchestrator-auto-learn.sh` calls `curator.sh full` but NOT `curator-learn.sh` directly. The learn step is user-triggered (`ralph curator learn`).

---

## 3. Discovery vs. Ingest Boundary

The current code makes a clean separation that should be preserved:

```
DISCOVERY PHASE                     INGEST PHASE
(pipeline stages 1-4)               (stages 5-6)

curator-discovery.sh               curator-ingest.sh
curator-scoring.sh                 curator-learn.sh
curator-rank.sh
curator-approve.sh

Inputs: query params               Inputs: approved repo directory
Outputs: ranked JSON list          Outputs: rules.json + manifest
Decision: which repos              Decision: what patterns
```

The refactor **only touches the INGEST PHASE**, specifically `curator-learn.sh`.

---

## 4. Desired State: AI-Driven Save Pattern

### 4.1 Vision

Instead of grepping for function and class keywords and saving everything, the agent:

1. Reads a file (or a meaningful chunk)
2. Asks itself: "Is there a **reusable, non-obvious pattern** here worth encoding as a rule?"
3. If yes, generates a structured rule with: `behavior` (natural language description), `confidence`, `domain`, `category`, `trigger`
4. If no, skips the file entirely

This brings the learn step into alignment with the MemPalace graduation pipeline — patterns must earn their way into procedural memory by meeting an AI-evaluated quality bar.

### 4.2 Desired State Flow (ASCII)

```
curator-learn-v2.sh (AI-driven)
         |
         +-- detect_language()      [REUSED from v1]
         +-- detect_domain()        [REUSED from v1]
         |
         +-- for each file in approved repo:
         |       |
         |       +-- read_file_chunk()   [max 200 lines]
         |       |
         |       +-- AI evaluation:
         |       |     "Does this file contain a pattern worth saving?
         |       |      If so, extract it as a structured rule."
         |       |
         |       +-- if pattern worthy:
         |               +-- create_rule()       [structured JSON]
         |               +-- assign_domain()     [using detect_domain()]
         |               +-- assign_confidence() [AI-assigned, 0.60-0.95]
         |
         +-- update_procedural_memory()  [REUSED from v1]
         +-- update_manifest()           [REUSED from v1]
         +-- sync_to_vault()             [REUSED from v1]
```

### 4.3 What Changes

| Component | Current (REGEX) | Desired (AI-driven) |
|---|---|---|
| Pattern detection | grep for function/class keywords | Agent evaluates file chunk for reusable patterns |
| Pattern description | "Classes: X. Functions: Y, Z." (mechanical) | Natural language: "Uses circuit breaker pattern with exponential backoff" |
| Confidence | Fixed 0.75 for all rules | AI-assigned per rule (0.60–0.95) |
| Filtering | 50-file cap (quantity) | Quality threshold (only save if novel/useful) |
| Domain assignment | Keyword count on whole repo | Per-pattern domain assignment based on file context |

### 4.4 What Does NOT Change

- `detect_language()` function — pure, no external deps, reused as-is
- `detect_domain()` function — used for repo-level context, reused as-is
- `update_procedural_memory()` function — pure JSON merge, reused as-is
- `update_manifest()` function — pure jq update, reused as-is
- `sync_to_vault()` function — pure file write, reused as-is
- CLI argument interface — `--type`, `--lang`, `--repo`, `--all` preserved
- Output contract: `rules.json` schema unchanged
- Manifest schema: unchanged
- Exit codes: 0/1 unchanged

---

## 5. API Contract for New Save Pattern

W2.3 must honor this contract to prevent integration breakage.

### 5.1 Input Contract (unchanged)

```bash
curator-learn.sh [--type <type>] [--lang <lang>] [--repo <repo>] [--all]
```

### 5.2 Output Contract (rule object schema — unchanged)

```json
{
  "rule_id": "rule-<domain>-<timestamp>-<random>",
  "domain": "<string>",
  "category": "<string>",
  "source_repo": "<owner/repo>",
  "source_file": "<relative_path>",
  "trigger": "<domain>",
  "behavior": "<string — now AI-generated, not mechanical>",
  "confidence": "<float, 0.60-0.95>",
  "source_episodes": [],
  "created_at": "<unix_timestamp>",
  "applied_count": 0
}
```

**Changed fields**: `behavior` (quality), `confidence` (range expanded from fixed 0.75).
**All other fields**: structurally identical.

### 5.3 Manifest Contract (unchanged)

```json
{
  "repository": "<owner/repo>",
  "cloned_at": "<ISO-8601>",
  "learned_at": "<unix_timestamp>",
  "detected_domain": "<string>",
  "detected_language": "<string>",
  "files": ["<relative_path>", ...],
  "patterns_extracted": "<integer>"
}
```

### 5.4 AI Evaluation Interface (new)

The AI save decision must conform to this interface so it can be tested:

```bash
# Function signature for W2.3 to implement
ai_evaluate_file() {
  local file_path="$1"         # Absolute path to file
  local file_content="$2"      # File content (max 200 lines)
  local domain_hint="$3"       # Detected domain for context
  local language="$4"          # Detected language

  # Returns JSON:
  # { "worthy": true/false, "pattern": "<description>", "confidence": 0.75 }
  # OR:
  # { "worthy": false }
}
```

The AI evaluation **must not** call external APIs synchronously in the main loop.
Acceptable implementations for W2.3:
- Local rule extraction using `claude` CLI with `-p` flag
- Structured prompt returning JSON
- Fallback to REGEX if `claude` CLI unavailable (degraded mode)

---

## 6. Migration Strategy

### 6.1 Principle: Zero-Break Migration

The existing pipeline must keep working at every step. W2.3 introduces a parallel implementation, not a replacement-in-place.

### 6.2 Steps

**Step 1 — Extract lib (W2.3 prerequisite)**
Create `.claude/lib/curator_lib.sh` with the reusable functions (see Section 8).
No behavior changes. Tests still pass against `curator-learn.sh` referencing the original.

**Step 2 — Create new script alongside old**
Create `.claude/scripts/curator-learn-v2.sh`.
Source `curator_lib.sh` for shared utilities.
New file, no modification to `curator-learn.sh`.

**Step 3 — Feature flag**
Add env var `CURATOR_AI_LEARN=1` to enable v2 path.
`curator.sh` and `curator-learn.sh` check this flag:
```bash
if [[ "${CURATOR_AI_LEARN:-0}" == "1" ]]; then
  exec "${HOME}/.claude/scripts/curator-learn-v2.sh" "$@"
fi
```

**Step 4 — Validate parity**
Run existing test suite against both paths.
v2 must produce rules that pass the same schema validation tests.

**Step 5 — Promote**
When v2 passes all tests and manual review, update `curator.sh` to default to v2.
Keep v1 as `curator-learn-v1.sh` for 2 sprints.

**Step 6 — Retire v1**
After v2 has run successfully in at least 3 sessions, delete v1.

---

## 7. Test Plan

### 7.1 Preservation Tests (must pass unchanged)

These tests exist and must NOT break during W2.3:

| Test File | Tests | Focus |
|---|---|---|
| `tests/learning-system/test-learning-system-v2.88.sh` | Script existence, execution with mock repo, rule schema validation | Core contract |
| `tests/learning-system/test-learning-complete-v2.88.sh` | Domain detection, manifest population, vault sync | GAP-C01/C02 fixes |

### 7.2 New Tests Required for v2

| Test | Input | Expected Output |
|---|---|---|
| `test_ai_evaluate_worthy_file` | File with clear design pattern (e.g., circuit breaker) | `worthy: true`, confidence > 0.70 |
| `test_ai_evaluate_unworthy_file` | Generic getter/setter file | `worthy: false` |
| `test_ai_degraded_mode` | `claude` CLI unavailable | Falls back to REGEX path, exits 0 |
| `test_ai_rule_schema_valid` | Any worthy file | Rule object matches schema in Section 5.2 |
| `test_ai_behavior_not_mechanical` | File with class + functions | `behavior` field is not "Classes: X. Functions: Y." |
| `test_cli_compat` | `--type`, `--lang`, `--repo`, `--all` flags | Same args accepted as v1 |
| `test_manifest_populated` | Run on mock approved repo | `files[]` non-empty, `patterns_extracted` correct |
| `test_vault_sync` | Run with `VAULT_DIR` set | Wiki article created in correct path |

### 7.3 Regression Gate

Before W2.3 is marked complete:
```bash
bash tests/learning-system/test-learning-system-v2.88.sh
bash tests/learning-system/test-learning-complete-v2.88.sh
```
Both must return exit 0 with no FAIL lines.

---

## 8. Rollback Plan

| Scenario | Rollback Action | Time to Execute |
|---|---|---|
| v2 produces malformed rules | Set `CURATOR_AI_LEARN=0`, restore backup rules.json | < 1 min |
| v2 breaks manifest schema | As above + revert manifest from `manifest.json.backup.*` | < 2 min |
| v2 costs too much (API calls) | Set `CURATOR_AI_LEARN=0` | < 1 min |
| v2 causes vault corruption | Obsidian vault is plain text — delete corrupt article, re-run v1 | < 5 min |
| Library extraction breaks imports | `curator-lib.sh` is sourced — revert to inline functions in original | < 10 min |

**Hard rollback**: `curator-learn.sh` is never modified in W2.3. If all else fails, the old path is always available.

---

## 9. Risk Register

### 9.1 Top 3 Risks

**Risk 1 — API cost blowup (HIGH)**
The current pipeline can process 50 files per repo. If each file requires an LLM call, a single `curator learn --all` with 10 repos could trigger 500 API calls. This is unpredictable cost.

*Mitigation*: Implement file-level budget (max 10 files per repo for AI evaluation). Use a pre-filter to skip obviously trivial files (config files, test files, generated files) before the AI call. Add `--ai-budget <n>` flag. Default to 10.

**Risk 2 — Degraded mode silent failure (MEDIUM)**
If the `claude` CLI is unavailable (offline session, API rate limit), v2 may silently produce 0 rules without surfacing the degradation clearly. The pipeline would complete with exit 0 but empty procedural memory update.

*Mitigation*: Implement explicit degraded mode with `log_warn "claude CLI unavailable — falling back to REGEX extraction"`. Degraded mode must still produce rules (v1 behavior). Add `CURATOR_LEARN_MODE` to manifest so downstream can detect which path ran.

**Risk 3 — Rule quality regression (MEDIUM)**
Current REGEX extraction produces mechanical but deterministic rules. AI-generated `behavior` descriptions could be vague, inconsistent, or hallucinated. If AI confidence scores are unreliable, the graduation pipeline (MemPalace) could promote poor rules.

*Mitigation*: Add a minimum rule quality gate: `behavior` field must be > 20 characters and not match the mechanical pattern `^(Classes:|Functions:)`. Run both v1 and v2 on the same repo during integration testing and compare rule counts and behavior diversity. Document expected quality range in the test plan.

### 9.2 Additional Risks

| Risk | Severity | Mitigation |
|---|---|---|
| `set -euo pipefail` breaks on AI call failure | LOW | Wrap AI call in subshell, handle non-zero exit |
| Vault article quality degrades | LOW | Vault articles are created by `sync_to_vault()` which is not changed |
| Concurrent runs corrupt rules.json | LOW | Backup+atomic write pattern already in v1 — reuse |
| Test suite uses hardcoded script path | LOW | Tests call `.claude/scripts/curator-learn.sh` directly — v2 is a new file, no breakage |

---

## 10. Reusable Functions for curator_lib.sh

W2.3 should extract these functions into `.claude/lib/curator_lib.sh` before implementing the new AI evaluation logic. They are **pure functions** with no side effects beyond the file system.

### 10.1 Identified Reusable Functions (7 functions)

| Function | Source Script | Lines | External Deps | Purpose |
|---|---|---|---|---|
| `validate_input()` | `curator-learn.sh` | 55-63 | None | Input sanitization against regex pattern |
| `detect_domain()` | `curator-learn.sh` | 66-98 | `grep`, `find`, `cat` | Keyword frequency count to classify domain |
| `detect_language()` | `curator-learn.sh` | 101-121 | None | Manifest file presence to detect language |
| `get_repo_info()` | `curator-learn.sh` | 267-275 | `jq` | Read repository name from manifest.json |
| `update_procedural_memory()` | `curator-learn.sh` | 278-308 | `jq`, `cp` | Merge rule array into rules.json with backup |
| `update_manifest()` | `curator-learn.sh` | 311-336 | `jq` | Update manifest with extraction results |
| `sync_to_vault()` | `curator-learn.sh` | 339-393 | `mkdir`, `sed`, `cat` | Write or bump wiki article in Obsidian vault |

**Count: 7 reusable functions**

### 10.2 Functions NOT to Extract

| Function | Reason |
|---|---|
| `extract_patterns_from_files()` | This is the core REGEX logic being replaced — do not canonize it in a lib |
| `learn_repo()` | Orchestrator function — specific to v1 flow |
| `main()` | Entry point — never shared |
| `parse_args()` | CLI-specific — both v1 and v2 need their own |
| `show_help()` | CLI-specific |

### 10.3 Shared Constants to Extract

The `DOMAIN_KEYWORDS` associative array and validation patterns should also move to the lib:

```bash
# curator_lib.sh should export:
readonly VALID_INPUT_PATTERN='^[a-zA-Z0-9_-]+$'
readonly VALID_REPO_PATTERN='^[a-zA-Z0-9_-]+/[a-zA-Z0-9._-]+$'
declare -A DOMAIN_KEYWORDS  # ... (same as curator-learn.sh lines 44-52)
```

---

## 11. Interface Specification for W2.3

This is the minimum contract that `curator-learn-v2.sh` must honor:

```
INPUTS:
  CLI args: --type <str> | --lang <str> | --repo <str> | --all
  ENV: VAULT_DIR (optional), HOME (required)
  Files read: ${APPROVED_DIR}/<repo>/manifest.json
              ${APPROVED_DIR}/<repo>/**/* (source files)
              ${PROCEDURAL_FILE} (rules.json)

OUTPUTS:
  Files written: ${PROCEDURAL_FILE} (rules.json, merged)
                 ${PROCEDURAL_BACKUP} (backup, always)
                 ${APPROVED_DIR}/<repo>/manifest.json (updated)
                 ${VAULT_DIR}/global/wiki/<domain>/curator-<safe>.md (if VAULT_DIR)

EXIT CODES:
  0: success (including 0 patterns found)
  1: invalid arguments or fatal I/O error

STDOUT:
  Progress/summary output (human readable)

STDERR:
  Structured log lines via log_info/log_warn/log_error

NO CHANGES TO:
  rules.json schema
  manifest.json schema
  vault article format
  exit code semantics
```

---

## 12. Files Audited

| Script | Version | Lines | Purpose |
|---|---|---|---|
| `curator-learn.sh` | v3.1.0 | 501 | Pattern extraction (AI-driven refactor target) |
| `curator-discovery.sh` | v2.55.0 | 415 | GitHub search |
| `curator-scoring.sh` | v2.84.2 | 445 | Quality + relevance scoring |
| `curator-rank.sh` | v2.55.0 | 217 | Ranking generation |
| `curator-ingest.sh` | v2.57.0 | 362 | Repository cloning |
| `curator-approve.sh` | v2.57.0 | 229 | Staging to approved promotion |
| `curator-queue.sh` | v2.55.0 | 221 | Queue status display |
| `curator-reject.sh` | v2.57.0 | 157 | Rejection handler |
| `curator.sh` | v2.55.0 | 347 | Pipeline orchestrator |

**Total scripts audited: 9**

Skill files:
- `.claude/skills/curator/SKILL.md` (v3.1.0)
- `.claude/skills/curator-repo-learn/SKILL.md` (v3.1.0)

---

## 13. Summary: Top Priorities for W2.3

### Top 3 Refactor Priorities (must-do)

1. **Extract `curator_lib.sh`** — Move the 7 reusable pure functions to `.claude/lib/curator_lib.sh` before writing any new AI logic. This prevents code duplication and ensures v2 uses the same proven utilities.

2. **Implement AI evaluation with degraded-mode fallback** — The `ai_evaluate_file()` function must have a `claude` CLI unavailability path that falls back to v1 REGEX behavior with a warning. Without this, sessions without `claude` access break silently.

3. **Replace `extract_patterns_from_files()` with AI-driven equivalent** — This is the core of the refactor. The new function reads file chunks, prompts the AI, and only saves rules where the AI returns `worthy: true`. The output schema must match Section 5.2 exactly.

### Top 3 Risks for W2.3

1. **API cost blowup** — Budget AI calls to max 10 files per repo by default.
2. **Degraded mode silent failure** — Must be explicit and auditable.
3. **Rule quality regression** — Run parallel comparison during integration test.

---

*This document is DESIGN ONLY. No curator scripts were modified.*
*W2.3 implementer: read Sections 5, 6, 8, 11 before writing any code.*
