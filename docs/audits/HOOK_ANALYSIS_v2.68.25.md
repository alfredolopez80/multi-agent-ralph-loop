# Hook System Analysis v2.68.25

## Date: 2026-01-24
## Analyst: Opus 4.5 (Lead Software Architect)

---

## CRITICAL ISSUES FOUND

### CRIT-001: Double stdin Read Pattern (6 hooks affected)

**Severity**: CRITICAL
**Impact**: Hook functionality completely broken - second read always returns empty

**Affected Hooks**:
| Hook | Line 1 | Line 2 | Status |
|------|--------|--------|--------|
| `fast-path-check.sh` | L10: `INPUT=$(head -c 100000)` | L23: `INPUT=$(cat)` | BROKEN |
| `smart-memory-search.sh` | L29: `INPUT=$(head -c 100000)` | L66: `INPUT=$(cat)` | BROKEN |
| `inject-session-context.sh` | L20: `INPUT=$(head -c 100000)` | L79: `INPUT=$(cat)` | BROKEN |
| `orchestrator-auto-learn.sh` | L26: `INPUT=$(head -c 100000)` | L56: `INPUT=$(cat)` | BROKEN |
| `pre-compact-handoff.sh` | L26: `INPUT=$(head -c 100000)` | L77: `INPUT=$(cat)` | BROKEN |
| `stop-verification.sh` | L9: `INPUT=$(head -c 100000)` | L43: `INPUT=$(cat)` | BROKEN |

**Root Cause**: SEC-111 fix added `INPUT=$(head -c 100000)` at the top of hooks, but the original `INPUT=$(cat)` was not removed. Since stdin is a stream, the second read returns empty.

**Fix Pattern**:
```bash
# WRONG (double read):
INPUT=$(head -c 100000)  # First read consumes stdin
...
INPUT=$(cat)             # Second read = empty!

# CORRECT (single read):
INPUT=$(head -c 100000)  # Single read, use throughout
# OR
INPUT=$(cat | head -c 100000)  # Alternative
```

---

### CRIT-002: Hook Registration Complexity

**Current State**: 80 hook registrations across 6 event types
**Risk**: Performance degradation, timeout cascades

| Event | Registrations | Max Timeout | Combined Max |
|-------|---------------|-------------|--------------|
| PostToolUse (Edit\|Write) | 14 | 300s | 4+ min |
| PostToolUse (Task) | 5 | 60s | 2+ min |
| PreToolUse (Task) | 7 | 30s | 2+ min |
| SessionStart | 10 | 30s | 5 min |
| Stop | 7 | 30s | 3+ min |
| UserPromptSubmit | 8 | 10s | 80s |

---

## GLM-4.7 MCP INTEGRATION OPPORTUNITIES

### Available Tools (4 servers, 14+ tools)

#### zai-mcp-server (Vision)
| Tool | Use Case |
|------|----------|
| `ui_to_artifact` | Convert UI screenshots to code |
| `extract_text_from_screenshot` | OCR for error messages |
| `diagnose_error_screenshot` | Analyze error screenshots |
| `understand_technical_diagram` | Parse architecture diagrams |
| `analyze_data_visualization` | Understand charts/graphs |
| `ui_diff_check` | Compare UI before/after changes |
| `image_analysis` | General image analysis |
| `video_analysis` | Video content analysis |

#### web-search-prime (Research)
| Tool | Use Case |
|------|----------|
| `webSearchPrime` | Enhanced web search with better context |

#### web-reader (Content)
| Tool | Use Case |
|------|----------|
| `webReader` | Read and extract web page content |

#### zread (Documentation)
| Tool | Use Case |
|------|----------|
| `search_doc` | Search documentation |
| `get_repo_structure` | Analyze repository structure |
| `read_file` | Read files with context |

---

## INTEGRATION PLAN

### Phase 1: Critical Bug Fixes (IMMEDIATE)

**Action**: Remove duplicate stdin reads from 6 hooks

| Hook | Action |
|------|--------|
| `fast-path-check.sh` | Remove L23 `INPUT=$(cat)` |
| `smart-memory-search.sh` | Remove L66 `INPUT=$(cat)` |
| `inject-session-context.sh` | Remove L79 `INPUT=$(cat)` |
| `orchestrator-auto-learn.sh` | Remove L56 `INPUT=$(cat)` |
| `pre-compact-handoff.sh` | Remove L77 `INPUT=$(cat)` |
| `stop-verification.sh` | Remove L43 `INPUT=$(cat)` |

### Phase 2: GLM-4.7 Integration (Enhancement)

#### 2a. Orchestrator Enhancement

New hook: `glm-research-enhance.sh` (PreToolUse: Task)

```bash
# When orchestrator starts:
# 1. Use webSearchPrime for recent patterns
# 2. Use zread for documentation search
# 3. Inject findings into orchestrator context
```

#### 2b. Adversarial Enhancement

New hook: `glm-visual-validation.sh` (PostToolUse: Edit|Write)

```bash
# For UI/frontend changes:
# 1. Capture screenshot (if available)
# 2. Use ui_diff_check for visual regression
# 3. Use image_analysis for accessibility check
```

#### 2c. Smart Memory Enhancement

Enhancement to `smart-memory-search.sh`:

```bash
# Add zread integration:
# 1. Search documentation for relevant patterns
# 2. Get repo structure for context
# 3. Merge with existing memory sources
```

### Phase 3: MiniMax Fallback Strategy

| Primary | Fallback | Condition |
|---------|----------|-----------|
| GLM webSearchPrime | MiniMax web_search | API error or timeout |
| GLM image_analysis | MiniMax understand_image | API error |
| GLM zread | Local file read | API unavailable |

---

## RECOMMENDED IMPLEMENTATION ORDER

1. **IMMEDIATE**: Fix CRIT-001 (double stdin read) - 6 files
2. **DAY 1**: Create glm-research-enhance.sh hook
3. **DAY 2**: Create glm-visual-validation.sh hook
4. **DAY 3**: Enhance smart-memory-search.sh with zread
5. **DAY 4**: Implement MiniMax fallback strategy
6. **DAY 5**: Testing and validation

---

## VERSION BUMP

- Current: 2.68.24
- Proposed: 2.68.25 (hook fixes + GLM integration)

