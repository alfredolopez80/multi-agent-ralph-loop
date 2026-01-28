# Curator Pipeline Flow Analysis - v2.55.0
## Comprehensive Architectural Review

---

## EXECUTIVE SUMMARY

The curator pipeline has **13 CRITICAL architectural issues** that can silently fail, lose data, or produce incorrect results. The most severe issues are:

1. **Silent JSON corruption** in scoring/ranking (lines mixed with logs)
2. **Race conditions** in file operations (no locking)
3. **Error swallowing** in while loops and jq pipelines
4. **stdout/stderr mixing** causing JSON contamination
5. **Broken ingest script** (syntax error at line 179)

---

## FLOW DIAGRAM

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CURATOR.SH (Main Orchestrator)              │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ 1. DISCOVERY PHASE                                           │  │
│  │    curator-discovery.sh                                       │  │
│  │    INPUT:  --type, --lang, --context, --topics               │  │
│  │    OUTPUT: candidates_backend_typescript_YYYYMMDD_HHMMSS.json│  │
│  │    WRITES: File path to stdout ⚠️                            │  │
│  │    LOGS:   All to stderr ✓                                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                            ↓                                        │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ 2. SCORING PHASE                                             │  │
│  │    curator-scoring.sh                                         │  │
│  │    INPUT:  candidates JSON file                              │  │
│  │    OUTPUT: candidates_scored.json                            │  │
│  │    WRITES: Enhanced JSON with quality_metrics ⚠️             │  │
│  │    LOGS:   All to stderr (BUT check line 375-391!) 🔴        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                            ↓                                        │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ 3. RANKING PHASE                                             │  │
│  │    curator-rank.sh                                            │  │
│  │    INPUT:  scored JSON file                                   │  │
│  │    OUTPUT: ranking_scored_ranking.json                       │  │
│  │    WRITES: Ranked JSON with metadata wrapper                 │  │
│  │    LOGS:   All to stderr ✓                                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                            ↓                                        │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ 4. APPROVAL PHASE (if --auto-approve)                       │  │
│  │    curator-approve.sh (called for each repo)                 │  │
│  │    Moves from staging → approved                             │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

                            ↓ (Separate command)

┌─────────────────────────────────────────────────────────────────────┐
│                       LEARNING PHASE (Separate)                     │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ curator-learn.sh --repo <repo>                               │  │
│  │    1. Calls pattern-extractor.py (if exists)                 │  │
│  │    2. Updates ~/.ralph/procedural/rules.json                 │  │
│  │    3. Marks repo as learned in manifest                      │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## DATA FLOW ANALYSIS

### 1. Discovery → Scoring
**File**: `candidates_backend_typescript_20260120_015432.json`

```json
[
  {
    "owner": "nestjs",
    "name": "nest",
    "full_name": "nestjs/nest",
    "description": "A progressive Node.js framework...",
    "stars": 75000,
    "forks": 8000,
    "open_issues": 123,
    "language": "TypeScript",
    "updated_at": "2026-01-19T12:00:00Z",
    "html_url": "https://github.com/nestjs/nest",
    "clone_url": "https://github.com/nestjs/nest.git",
    "discovered_type": "backend",
    "discovered_lang": "typescript",
    "discovered_at": 1737340472,
    "status": "candidate"
  },
  ...
]
```

**Transform Point 1**: Discovery adds metadata (discovered_type, discovered_lang, discovered_at, status)

**Failure Modes**:
- GitHub API rate limiting → script fails after 3 retries (line 252-267)
- Empty results → script exits 1 (line 307-310)
- jq failure in filtering → corrupt JSON (line 321-330, no error check)

---

### 2. Scoring → Ranking
**File**: `candidates_backend_typescript_20260120_015432_scored.json`

```json
[
  {
    "owner": "nestjs",
    "name": "nest",
    "full_name": "nestjs/nest",
    "description": "A progressive Node.js framework...",
    "stars": 75000,
    "forks": 8000,
    "open_issues": 123,
    "language": "TypeScript",
    "updated_at": "2026-01-19T12:00:00Z",
    "html_url": "https://github.com/nestjs/nest",
    "clone_url": "https://github.com/nestjs/nest.git",
    "discovered_type": "backend",
    "discovered_lang": "typescript",
    "discovered_at": 1737340472,
    "status": "candidate",
    "quality_metrics": {               ← ADDED
      "stars_score": 8.2,
      "issues_ratio_score": 9.1,
      "description_score": 10,
      "has_tests_score": 10,
      "has_ci_score": 10,
      "context_relevance_score": 5,    ← v2.55 NEW
      "quality_score": 9.2             ← COMPOSITE
    }
  },
  ...
]
```

**Transform Point 2**: Scoring adds `quality_metrics` object

**CRITICAL FAILURE MODE** (🔴 HIGHEST SEVERITY):
```bash
# curator-scoring.sh lines 375-391
jq -c '.[]' "$INPUT_FILE" | while read -r repo; do
    local owner name full_name
    owner=$(echo "$repo" | jq -r '.owner')
    name=$(echo "$repo" | jq -r '.name')
    full_name=$(echo "$repo" | jq -r '.full_name')

    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Scoring: $full_name"  # ← Goes to stderr (OK)
    fi

    # Calculate scores
    local scores
    scores=$(calculate_score "$repo" "$CONTEXT_KEYWORDS")

    # Add scores to repo
    echo "$repo" | jq --argjson scores "$scores" '. + {quality_metrics: $scores}'
done | jq -s '.' > "$OUTPUT_FILE"
```

**Issue**: If `calculate_score` writes ANYTHING to stdout (via `check_tests` or `check_ci`), it will corrupt the JSON stream.

**Evidence**:
- `check_tests` (line 132): `rm -f "$tmp_file"` then `echo "true"` → stdout
- `check_ci` (line 165): `echo "true"` → stdout
- Both are called during `calculate_score` (lines 283-284)

**Example Corruption**:
```json
[
  {"owner": "nestjs", "name": "nest", ...}
  true                                        ← CORRUPT LINE
  {"owner": "prisma", "name": "prisma", ...}
]
```

This will cause `jq -s '.' > "$OUTPUT_FILE"` to fail silently or produce invalid JSON.

---

### 3. Ranking → Queue
**File**: `ranking_scored_ranking.json`

```json
{
  "metadata": {
    "generated_at": "2026-01-20T01:54:32Z",
    "source_file": "/Users/.../_scored.json",
    "top_n": 10,
    "max_per_org": 2,
    "total_repos": 10,
    "version": "2.55.0"
  },
  "rankings": [
    {
      "owner": "nestjs",
      "name": "nest",
      "full_name": "nestjs/nest",
      "description": "A progressive Node.js framework...",
      "stars": 75000,
      "forks": 8000,
      "open_issues": 123,
      "language": "TypeScript",
      "updated_at": "2026-01-19T12:00:00Z",
      "html_url": "https://github.com/nestjs/nest",
      "clone_url": "https://github.com/nestjs/nest.git",
      "discovered_type": "backend",
      "discovered_lang": "typescript",
      "discovered_at": 1737340472,
      "status": "candidate",
      "quality_metrics": {
        "stars_score": 8.2,
        "issues_ratio_score": 9.1,
        "description_score": 10,
        "has_tests_score": 10,
        "has_ci_score": 10,
        "context_relevance_score": 5,
        "quality_score": 9.2
      },
      "ranking_position": 1,           ← ADDED
      "tier": "curated"                ← ADDED
    },
    ...
  ]
}
```

**Transform Point 3**: Ranking adds `ranking_position`, `tier`, and wraps in `metadata` object

**Failure Modes**:
- `jq` complexity reduction (line 120-125) → potential calculation errors
- `reduce` operation (line 133-144) → no error handling
- `limit` operation (line 149) → could fail if input is not array

---

## CRITICAL ISSUES (By Severity)

### 🔴 CRITICAL (Pipeline-Breaking)

#### 1. JSON Corruption in Scoring (curator-scoring.sh)
**Location**: Lines 375-391 (while loop), lines 124-154 (check_tests/check_ci)

**Root Cause**: `check_tests` and `check_ci` echo to stdout, which contaminates the JSON stream being piped through `jq`.

**Impact**: Invalid JSON in scored output → ranking fails → entire pipeline fails

**Proof**:
```bash
# Line 132 (check_tests)
echo "true"  # → stdout ← WRONG

# Line 168 (check_ci)
echo "true"  # → stdout ← WRONG
```

**Fix Required**:
```bash
# All echo statements in check_tests and check_ci must redirect to stderr:
echo "true" >&2
# Then return via return code or global variable
```

---

#### 2. Syntax Error in Ingest Script (curator-ingest.sh)
**Location**: Line 179

**Code**:
```bash
local manifest_file="${target_dir}/manifest.json "$manifest_file""
```

**Error**: Double variable expansion + unclosed quote

**Impact**: Script fails immediately when trying to create manifest

**Fix Required**:
```bash
local manifest_file="${target_dir}/manifest.json"
```

---

#### 3. Silent Error Swallowing in Scoring While Loop
**Location**: Lines 375-391 (curator-scoring.sh)

**Code**:
```bash
jq -c '.[]' "$INPUT_FILE" | while read -r repo; do
    # ... processing ...
    echo "$repo" | jq --argjson scores "$scores" '. + {quality_metrics: $scores}'
done | jq -s '.' > "$OUTPUT_FILE"
```

**Issue**: If ANY iteration fails (jq error, calculate_score failure), the error is silently swallowed. The while loop continues and produces partial output.

**Impact**: Incomplete scoring → repos missing quality_metrics → ranking fails or produces wrong results

**Fix Required**: Add error handling with `set -o pipefail` and explicit checks:
```bash
local tmp_scored="${CACHE_DIR}/scored_tmp_$$.json"
while read -r repo; do
    scores=$(calculate_score "$repo" "$CONTEXT_KEYWORDS") || {
        log_error "Scoring failed for $(echo "$repo" | jq -r .full_name)"
        return 1
    }
    echo "$repo" | jq --argjson scores "$scores" '. + {quality_metrics: $scores}' || return 1
done < <(jq -c '.[]' "$INPUT_FILE") > "$tmp_scored"
jq -s '.' "$tmp_scored" > "$OUTPUT_FILE" || return 1
```

---

### 🟡 HIGH (Data Loss / Race Conditions)

#### 4. Race Condition in File Operations
**Location**: Multiple scripts (curator.sh, curator-scoring.sh, curator-rank.sh)

**Issue**: Temp files use `$$` (PID) but no locking. Concurrent runs can overwrite each other.

**Example**:
```bash
# curator-discovery.sh line 230
local tmp_file="${CACHE_DIR}/gh_search_$$.json"

# curator-scoring.sh line 112
local output_file="${CURATOR_DIR}/.tmp_patterns_$$.json"
```

**Impact**: 
- Concurrent curator runs corrupt each other's data
- No atomic operations → partial writes possible

**Fix Required**: Use `mktemp` with directory locks:
```bash
local tmp_file=$(mktemp "${CACHE_DIR}/gh_search.XXXXXX.json")
trap 'rm -f "$tmp_file"' EXIT
```

---

#### 5. Procedural Memory Corruption (curator-learn.sh)
**Location**: Lines 144-149

**Code**:
```bash
merged=$(jq -s \
    --argjson current "$current_rules" \
    --argjson new "$new_rules" \
    '$current * {rules: ($current.rules + $new.rules | unique_by(.rule_id))}' \
    "$PROCEDURAL_FILE" 2>/dev/null || echo "$current_rules")

echo "$merged" | jq '.' > "$PROCEDURAL_FILE"
```

**Issues**:
1. **No atomic write**: Write directly to $PROCEDURAL_FILE (no temp + mv)
2. **Error swallowing**: `|| echo "$current_rules"` masks jq failures
3. **Race condition**: Multiple learns can corrupt the file
4. **No backup verification**: Backup created but never used on failure

**Impact**: Corrupt procedural memory → all future learning lost

**Fix Required**:
```bash
local tmp_merged="${PROCEDURAL_FILE}.tmp.$$"
merged=$(jq -s \
    --argjson current "$current_rules" \
    --argjson new "$new_rules" \
    '$current * {rules: ($current.rules + $new.rules | unique_by(.rule_id))}' \
    "$PROCEDURAL_FILE") || {
    log_error "Failed to merge rules"
    return 1
}
echo "$merged" | jq '.' > "$tmp_merged" || {
    log_error "Failed to write merged rules"
    rm -f "$tmp_merged"
    return 1
}
mv "$tmp_merged" "$PROCEDURAL_FILE" || {
    log_error "Failed to update procedural memory"
    cp "$PROCEDURAL_BACKUP" "$PROCEDURAL_FILE"
    return 1
}
```

---

#### 6. GitHub API Rate Limiting Not Handled Correctly
**Location**: curator-discovery.sh lines 244-267

**Code**:
```bash
while [[ $attempts -lt $max_attempts ]]; do
    if gh api "$api_endpoint" --jq '.items[] | {...}' > "$tmp_file" 2>&1; then
        break
    else
        attempts=$((attempts + 1))
        log_warn "GitHub search attempt $attempts failed"
        if [[ $attempts -lt $max_attempts ]]; then
            sleep 2
        fi
    fi
done
```

**Issues**:
1. **Fixed 2s sleep**: Should use exponential backoff
2. **No rate limit detection**: Should check for 403 rate limit vs other errors
3. **Redirects both stdout/stderr**: `2>&1` to $tmp_file mixes errors with JSON

**Impact**: 
- Wastes time on non-rate-limit errors
- Corrupt JSON if errors written to output file
- Doesn't respect GitHub's rate limit headers

**Fix Required**:
```bash
while [[ $attempts -lt $max_attempts ]]; do
    local stderr_file="${CACHE_DIR}/gh_error_$$.txt"
    if gh api "$api_endpoint" --jq '.items[] | {...}' > "$tmp_file" 2>"$stderr_file"; then
        rm -f "$stderr_file"
        break
    else
        if grep -q "rate limit" "$stderr_file"; then
            local sleep_time=$((2 ** attempts))
            log_warn "Rate limited, sleeping ${sleep_time}s"
            sleep "$sleep_time"
        else
            log_error "API error: $(cat "$stderr_file")"
            rm -f "$stderr_file"
            return 1
        fi
        attempts=$((attempts + 1))
    fi
done
```

---

### 🟠 MEDIUM (Logic Errors / Inconsistencies)

#### 7. Context Relevance Calculation Edge Cases (curator-scoring.sh)
**Location**: Lines 175-233 (calculate_relevance_score)

**Issues**:
1. **IFS manipulation not restored on early exit**: Line 197-217 sets IFS but may not restore if `continue` is hit
2. **Case-insensitive matching too broad**: `grep -qi` can match partial words
3. **No sanitization**: Keywords with regex chars will break grep

**Example Failure**:
```bash
# User input: "error handling, re-try, c++"
# Line 200: keyword="c++"
# Line 206: grep -qi "c++"  ← BREAKS (invalid regex)
```

**Fix Required**:
```bash
# Sanitize keyword for grep
keyword=$(echo "$keyword" | sed 's/[+*.\[\]^$(){}|\\]/\\&/g')
# Use fgrep for literal matching
if [[ -n "$description" ]] && echo "$description" | fgrep -qi -- "$keyword"; then
```

---

#### 8. Composite Score Calculation Inconsistency (curator-rank.sh)
**Location**: Lines 120-125

**Code**:
```bash
_composite_score: (
    (.quality_metrics.quality_score // 0) *
    (1 + ([0, ((.quality_metrics.context_relevance_score // 0) * 0.1)] | max))
)
```

**Issue**: Uses `max([0, ...])` which means negative relevance scores are ignored, contradicting the scoring logic in curator-scoring.sh lines 312-315 where negative relevance reduces score by 30%.

**Impact**: Repos with no context match (relevance=-1) rank equally to neutral repos (relevance=0)

**Fix Required**:
```bash
_composite_score: (
    (.quality_metrics.quality_score // 0) *
    (1 + ((.quality_metrics.context_relevance_score // 0) * 0.1))
)
# Remove the max() to allow negative multipliers
```

---

#### 9. Duplicate Organization Logic Flaw (curator-rank.sh)
**Location**: Lines 133-144

**Code**:
```bash
reduce .[] as $repo ([];
  . as $acc |
  ($repo.owner) as $org |
  ([.[] | select(.owner == $org)] | length) as $current_count |
  if $current_count < '$MAX_PER_ORG' then
    . + [$repo]
  else
    .
  end
)
```

**Issue**: String literal `'$MAX_PER_ORG'` is not expanded (single quotes in jq command)

**Impact**: Always uses literal comparison to string "$MAX_PER_ORG" instead of numeric value

**Fix Required**:
```bash
jq --argjson max_per_org "$MAX_PER_ORG" '
    reduce .[] as $repo ([];
      . as $acc |
      ($repo.owner) as $org |
      ([.[] | select(.owner == $org)] | length) as $current_count |
      if $current_count < $max_per_org then
        . + [$repo]
      else
        .
      end
    )
' "$tmp_file"
```

---

### 🟢 LOW (Warnings / Cleanup)

#### 10. Temp File Cleanup Incomplete
**Location**: Multiple scripts

**Missing Cleanup**:
- `curator-discovery.sh` line 352: `tmp_candidates` cleaned but not in error paths before line 355
- `curator-scoring.sh` line 112: `.tmp_patterns_$$.json` never cleaned
- `curator-rank.sh` line 114: `ranking_tmp_$$.json` cleaned at line 199 but not on error

**Impact**: Disk space leak over time

**Fix Required**: Add trap handlers:
```bash
trap 'rm -f "$tmp_file" "$tmp_patterns" "$tmp_ranked"' EXIT
```

---

#### 11. Inconsistent Error Exit Codes
**Location**: All scripts

**Issue**: Some scripts use `return 1`, some use `exit 1`, inconsistent error propagation

**Examples**:
- `curator.sh` line 197: `return 1`
- `curator-discovery.sh` line 377: `exit 1`
- `curator-scoring.sh` line 115: `return 1`

**Impact**: Errors not properly propagated to orchestrator

**Fix Required**: Standardize on `return 1` in functions, `exit 1` in main

---

#### 12. Missing Input Validation
**Location**: All scripts

**Examples**:
- No check for empty `--context` or `--topics` (could pass empty strings)
- No validation of `--tier` values (could pass "invalid")
- No bounds check on `--top-n` (could pass -1 or 99999)

**Fix Required**: Add validation functions at start of each script

---

#### 13. Logging Inconsistency
**Location**: curator-ingest.sh lines 35-38

**Code**:
```bash
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }      # → stdout
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }  # → stdout
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }      # → stdout
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }   # → stderr
```

**Issue**: Only log_error goes to stderr, rest go to stdout

**Impact**: Contaminates stdout if ingest script output is used programmatically

**All other scripts**: Correctly send all logs to stderr (good!)

**Fix Required**:
```bash
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
```

---

## TEMPORARY FILES LIFECYCLE

| Script | Temp File | Created | Cleaned | Risk |
|--------|-----------|---------|---------|------|
| discovery | gh_search_$$.json | 230 | 301 | Low (cleaned) |
| discovery | candidates_raw_$$.json | 352 | 357 | Medium (error path leak) |
| scoring | .tmp_patterns_$$.json | 112 | NEVER | HIGH (leak) |
| scoring | repo_content_$$.json | 127 | 133, 152 | Low (cleaned) |
| ranking | ranking_tmp_$$.json | 114 | 199 | Medium (error path leak) |
| ranking | ranked_$$.json | 147 | 182 | Low (cleaned) |
| ingest | .tmp_clone_$$ | 153 | 170, 255, 263 | Low (cleaned) |
| ingest | .tmp_files_$$ | 191 | 251 | Low (cleaned) |
| learn | .tmp_patterns_$$.json | 112 | NEVER | HIGH (leak) |

**Action Required**: Add `trap 'rm -f $tmpfiles' EXIT` to all scripts

---

## RECOMMENDED FIXES (Priority Order)

### Phase 1: Critical Fixes (Must Do Before Any Production Use)

1. **Fix JSON corruption in scoring** (Issue #1)
   - Redirect all echo statements in check_tests/check_ci to stderr
   - Test: Run scoring on 50 repos, validate output with `jq . scored.json`

2. **Fix ingest syntax error** (Issue #2)
   - Fix line 179 manifest_file variable
   - Test: Run ingest on any repo

3. **Fix error swallowing in scoring while loop** (Issue #3)
   - Add error handling and pipefail
   - Test: Inject jq failure, verify script exits with error

4. **Fix procedural memory corruption** (Issue #5)
   - Implement atomic writes with temp + mv
   - Add file locking
   - Test: Run concurrent learns, verify no corruption

### Phase 2: High Priority (Do Before Scale)

5. **Fix race conditions** (Issue #4)
   - Replace $$ temp files with mktemp
   - Add directory locks for multi-step operations
   - Test: Run 5 concurrent pipelines

6. **Fix GitHub API rate limiting** (Issue #6)
   - Implement exponential backoff
   - Parse rate limit headers
   - Separate stderr from output
   - Test: Trigger rate limit, verify recovery

### Phase 3: Medium Priority (Correctness)

7. **Fix context relevance edge cases** (Issue #7)
   - Restore IFS properly
   - Sanitize keywords for grep
   - Test: Pass "c++, re-try, error.handling" as context

8. **Fix composite score calculation** (Issue #8)
   - Remove max() to allow negative multipliers
   - Test: Verify negative relevance reduces rank

9. **Fix MAX_PER_ORG expansion** (Issue #9)
   - Use --argjson to pass variable
   - Test: Set MAX_PER_ORG=1, verify only 1 repo per org

### Phase 4: Low Priority (Hygiene)

10. **Add temp file cleanup traps** (Issue #10)
11. **Standardize error codes** (Issue #11)
12. **Add input validation** (Issue #12)
13. **Fix logging consistency in ingest** (Issue #13)

---

## TESTING STRATEGY

### Unit Tests (Per Script)

```bash
# Test discovery with mock GitHub API
test_discovery_with_rate_limit() {
    # Mock gh to return 403 on first call, success on second
    # Verify exponential backoff
}

# Test scoring with corrupt input
test_scoring_handles_missing_fields() {
    # Create JSON missing owner/description
    # Verify script handles gracefully
}

# Test ranking with edge cases
test_ranking_max_per_org() {
    # Create 5 repos from same org
    # Verify only MAX_PER_ORG included
}
```

### Integration Tests (Full Pipeline)

```bash
# Test full pipeline end-to-end
test_full_pipeline() {
    curator.sh full --type backend --lang typescript --tier free --top-n 5
    # Verify ranking JSON valid
    # Verify all 5 repos present
    # Verify quality_metrics on all
}

# Test concurrent pipelines
test_concurrent_pipelines() {
    curator.sh full --type backend --lang typescript &
    curator.sh full --type frontend --lang javascript &
    wait
    # Verify no corruption
}

# Test context-aware search
test_context_relevance_scoring() {
    curator.sh full --type backend --lang typescript \
        --context "error handling, retry logic" \
        --top-n 3
    # Verify top 3 repos mention context keywords
}
```

---

## CONCLUSION

The curator pipeline has **solid conceptual design** but **poor implementation quality**. The main issues are:

1. **No defense against stdout/stderr contamination**
2. **No atomic file operations**
3. **No concurrent access protection**
4. **Error handling is an afterthought**

**Estimated Fix Time**:
- Phase 1 (Critical): 4-6 hours
- Phase 2 (High): 3-4 hours
- Phase 3 (Medium): 2-3 hours
- Phase 4 (Low): 1-2 hours

**Total**: ~12-15 hours for full remediation

**Risk if not fixed**: Silent data loss, corrupt JSON, incorrect rankings, procedural memory corruption

---
