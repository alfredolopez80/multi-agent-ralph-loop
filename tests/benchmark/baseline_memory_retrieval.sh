#!/usr/bin/env bash
# baseline_memory_retrieval.sh — Memory Retrieval Benchmark v1.0.0
# Wave W1.4 benchmark-baseline (MemPalace adoption plan)
# Plan: .ralph/plans/cheeky-dazzling-catmull.md
#
# Measures current (post-Wave-0) Obsidian-vault memory system performance:
#   A) Retrieval latency  (median + p95 over N_RUNS)
#   B) Token cost per query (wc -w of session-start context, 0.75 words/token)
#   C) Hit rate (queries returning >= 1 result / total queries)
#   D) Vault size baseline (file count, bytes, avg file size)
#
# Outputs: tests/benchmark/results/baseline-YYYY-MM-DD.json
# READ-ONLY: does NOT modify vault, hooks, or any source files.
#
# Usage:
#   bash tests/benchmark/baseline_memory_retrieval.sh
#   bash tests/benchmark/baseline_memory_retrieval.sh --runs 5   (override run count)
#
# CONSTRAINTS:
#   - No writes to vault or .claude/ directories
#   - No network calls
#   - Reproducible: same input corpus -> same output structure

set -euo pipefail
umask 077

# Force C locale for consistent decimal separators in JSON output (avoid es_ES comma decimals)
export LC_NUMERIC=C
export LC_ALL=C

# ─────────────────────────── CONFIG ────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VAULT_ROOT="${HOME}/Documents/Obsidian/MiVault"
DECISIONS_JSON="${VAULT_ROOT}/migrated-from-claude-mem/decisions.json"
WIKI_DIR="${VAULT_ROOT}/global/wiki"
SMART_SEARCH_HOOK="${REPO_ROOT}/.claude/hooks/smart-memory-search.sh"
SESSION_RESTORE_HOOK="${REPO_ROOT}/.claude/hooks/session-start-restore-context.sh"
QUERIES_FILE="${REPO_ROOT}/tests/benchmark/queries.json"
RESULTS_DIR="${REPO_ROOT}/tests/benchmark/results"
DATE_TAG="$(date +%Y-%m-%d)"
OUTPUT_JSON="${RESULTS_DIR}/baseline-${DATE_TAG}.json"

# Number of timing runs per metric (override with --runs N)
N_RUNS=20

# ─────────────────────────── ARG PARSING ───────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) N_RUNS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ─────────────────────────── HELPERS ───────────────────────────────────────────
log() { echo "[benchmark] $*" >&2; }

# elapsed_ms: run a command and return elapsed time in milliseconds
elapsed_ms() {
  local start end
  start=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000000000))")
  "$@" >/dev/null 2>&1 || true
  end=$(date +%s%N 2>/dev/null || python3 -c "import time; print(int(time.time()*1000000000))")
  echo $(( (end - start) / 1000000 ))
}

# median of a newline-separated list of numbers
median() {
  echo "$1" | sort -n | awk '{a[NR]=$0} END {
    if (NR % 2 == 1) print a[int(NR/2)+1]
    else printf "%.1f\n", (a[NR/2]+a[NR/2+1])/2
  }'
}

# p95 of a newline-separated list of numbers
p95() {
  echo "$1" | sort -n | awk '{a[NR]=$0} END {
    idx = int(NR * 0.95 + 0.5)
    if (idx < 1) idx = 1
    if (idx > NR) idx = NR
    print a[idx]
  }'
}

# ensure output directory exists
mkdir -p "${RESULTS_DIR}"

# ─────────────────────────── SECTION A: LATENCY ────────────────────────────────
log "Section A: Retrieval latency (${N_RUNS} runs each)"

run_latencies() {
  local n="$1"
  local label="$2"
  shift 2
  local times=""
  for ((i=1; i<=n; i++)); do
    ms=$(elapsed_ms "$@")
    times="${times}${ms}"$'\n'
  done
  echo "$times"
}

# A1: grep decisions.json for known query
log "  A1: grep decisions.json for 'MemPalace'"
A1_TIMES=$(run_latencies "$N_RUNS" "decisions_grep" \
  grep -l "MemPalace" "${DECISIONS_JSON}")

A1_MEDIAN=$(median "$A1_TIMES")
A1_P95=$(p95 "$A1_TIMES")
log "  A1 median=${A1_MEDIAN}ms p95=${A1_P95}ms"

# A2: grep -r wiki/ for phrase
log "  A2: grep -r wiki/ for 'hook'"
A2_TIMES=$(run_latencies "$N_RUNS" "wiki_grep" \
  grep -rl "hook" "${WIKI_DIR}")

A2_MEDIAN=$(median "$A2_TIMES")
A2_P95=$(p95 "$A2_TIMES")
log "  A2 median=${A2_MEDIAN}ms p95=${A2_P95}ms"

# A3: smart-memory-search.sh
# The hook expects JSON on stdin; send a minimal Task PreToolUse payload
HOOK_INPUT='{"tool_name":"Task","tool_input":{"description":"MemPalace migration memory test"},"hook_event_name":"PreToolUse"}'

A3_MEDIAN="null"
A3_P95="null"
A3_STATUS="skipped"

if [[ -f "${SMART_SEARCH_HOOK}" ]]; then
  log "  A3: smart-memory-search.sh (${N_RUNS} runs)"
  A3_TIMES=""
  for ((i=1; i<=N_RUNS; i++)); do
    start=$(date +%s%N 2>/dev/null)
    echo "${HOOK_INPUT}" | timeout 5 bash "${SMART_SEARCH_HOOK}" >/dev/null 2>&1 || true
    end=$(date +%s%N 2>/dev/null)
    ms=$(( (end - start) / 1000000 ))
    A3_TIMES="${A3_TIMES}${ms}"$'\n'
  done
  A3_MEDIAN=$(median "$A3_TIMES")
  A3_P95=$(p95 "$A3_TIMES")
  A3_STATUS="ok"
  log "  A3 median=${A3_MEDIAN}ms p95=${A3_P95}ms"
else
  log "  A3: smart-memory-search.sh not found — skipped"
fi

# ─────────────────────────── SECTION B: TOKEN COST ─────────────────────────────
log "Section B: Token cost per query (session-start-restore-context.sh)"

SESSION_INPUT='{"hook_event_name":"SessionStart","session_id":"benchmark-test","project_dir":"'"${REPO_ROOT}"'"}'

B_WORD_COUNT=0
B_TOKEN_ESTIMATE=0
B_STATUS="skipped"
B_CONTEXT_SIZE_BYTES=0

if [[ -f "${SESSION_RESTORE_HOOK}" ]]; then
  CONTEXT_OUTPUT=$(echo "${SESSION_INPUT}" | timeout 10 bash "${SESSION_RESTORE_HOOK}" 2>/dev/null || echo "{}")
  # Try to extract additionalContext field; fall back to full output
  ADDITIONAL_CTX=$(echo "${CONTEXT_OUTPUT}" | jq -r '.additionalContext // .hookSpecificOutput.additionalContext // ""' 2>/dev/null || echo "")
  if [[ -z "${ADDITIONAL_CTX}" ]]; then
    ADDITIONAL_CTX="${CONTEXT_OUTPUT}"
  fi
  B_WORD_COUNT=$(echo "${ADDITIONAL_CTX}" | wc -w | tr -d ' ')
  B_TOKEN_ESTIMATE=$(awk "BEGIN {printf \"%.0f\", ${B_WORD_COUNT} / 0.75}")
  B_CONTEXT_SIZE_BYTES=$(echo -n "${CONTEXT_OUTPUT}" | wc -c | tr -d ' ')
  B_STATUS="ok"
  log "  B word_count=${B_WORD_COUNT} estimated_tokens=${B_TOKEN_ESTIMATE} raw_bytes=${B_CONTEXT_SIZE_BYTES}"
else
  log "  session-start-restore-context.sh not found — token cost skipped"
fi

# ─────────────────────────── SECTION C: HIT RATE ───────────────────────────────
log "Section C: Hit rate (10 representative queries)"

# Use first 10 queries from queries.json flat list
QUERIES=$(jq -r '.flat_queries[:10][]' "${QUERIES_FILE}" 2>/dev/null || cat <<'FALLBACK'
MemPalace migration plan
claude-mem RCE vulnerability
Obsidian vault
AAAK compression
wake-up token
umask 077
stdin protocol pattern
Kaizen 4 pillars
procedural rules filtering
retrieval R@5
FALLBACK
)

SEARCH_TARGETS=(
  "${DECISIONS_JSON}"
  "${VAULT_ROOT}/migrated-from-claude-mem/refactors.json"
  "${VAULT_ROOT}/migrated-from-claude-mem/bugfixs.json"
)

# Also include wiki md files
WIKI_MD_FILES=$(find "${WIKI_DIR}" -name "*.md" 2>/dev/null | tr '\n' ' ')

TOTAL_QUERIES=0
HIT_COUNT=0
HIT_DETAILS=()

while IFS= read -r query; do
  [[ -z "${query}" ]] && continue
  TOTAL_QUERIES=$(( TOTAL_QUERIES + 1 ))
  GOT_HIT=0

  # Search JSON files
  for target in "${SEARCH_TARGETS[@]}"; do
    if [[ -f "${target}" ]] && grep -qi "${query}" "${target}" 2>/dev/null; then
      GOT_HIT=1
      break
    fi
  done

  # Search wiki md files if no hit yet
  if [[ "${GOT_HIT}" -eq 0 ]] && [[ -n "${WIKI_MD_FILES}" ]]; then
    # shellcheck disable=SC2086
    if grep -rqi "${query}" ${WIKI_MD_FILES} 2>/dev/null; then
      GOT_HIT=1
    fi
  fi

  if [[ "${GOT_HIT}" -eq 1 ]]; then
    HIT_COUNT=$(( HIT_COUNT + 1 ))
    HIT_DETAILS+=("{\"query\":$(echo -n "${query}" | jq -Rs .),\"hit\":true}")
  else
    HIT_DETAILS+=("{\"query\":$(echo -n "${query}" | jq -Rs .),\"hit\":false}")
  fi
done <<< "${QUERIES}"

HIT_RATE_PCT=0
if [[ "${TOTAL_QUERIES}" -gt 0 ]]; then
  HIT_RATE_PCT=$(awk "BEGIN {printf \"%.1f\", (${HIT_COUNT}/${TOTAL_QUERIES})*100}")
fi
log "  C hit_rate=${HIT_RATE_PCT}% (${HIT_COUNT}/${TOTAL_QUERIES})"

# Build JSON array for hit details
HIT_DETAILS_JSON="[$(IFS=,; echo "${HIT_DETAILS[*]}")]"

# ─────────────────────────── SECTION D: VAULT SIZE ─────────────────────────────
log "Section D: Vault size baseline"

D_MD_COUNT=$(find "${VAULT_ROOT}" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
D_JSON_COUNT=$(find "${VAULT_ROOT}" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
D_TOTAL_FILES=$(find "${VAULT_ROOT}" -type f 2>/dev/null | wc -l | tr -d ' ')
D_TOTAL_BYTES=$(find "${VAULT_ROOT}" -type f -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}')
D_MD_TOTAL_BYTES=$(find "${VAULT_ROOT}" -name "*.md" -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}')

D_AVG_MD_BYTES=0
if [[ "${D_MD_COUNT}" -gt 0 ]]; then
  D_AVG_MD_BYTES=$(( D_MD_TOTAL_BYTES / D_MD_COUNT ))
fi

WIKI_MD_COUNT=$(find "${WIKI_DIR}" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
MIGRATED_JSON_COUNT=$(find "${VAULT_ROOT}/migrated-from-claude-mem" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')

DECISIONS_LINES=$(wc -l < "${DECISIONS_JSON}" 2>/dev/null | tr -d ' ' || echo 0)

log "  D md_count=${D_MD_COUNT} total_bytes=${D_TOTAL_BYTES} avg_md_bytes=${D_AVG_MD_BYTES}"

# ─────────────────────────── OUTPUT JSON ───────────────────────────────────────
log "Writing results to ${OUTPUT_JSON}"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME=$(hostname -s 2>/dev/null || echo "unknown")

cat > "${OUTPUT_JSON}" << ENDJSON
{
  "benchmark": "memory_retrieval_baseline",
  "version": "1.0.0",
  "plan_wave": "W1.4",
  "plan_file": ".ralph/plans/cheeky-dazzling-catmull.md",
  "generated_at": "${TIMESTAMP}",
  "host": "${HOSTNAME}",
  "n_runs": ${N_RUNS},
  "memory_system": {
    "type": "obsidian_vault_post_wave0",
    "vault_root": "${VAULT_ROOT}",
    "decisions_json": "${DECISIONS_JSON}",
    "wiki_dir": "${WIKI_DIR}"
  },
  "A_retrieval_latency_ms": {
    "description": "Time to return at least one result for a known query",
    "a1_decisions_json_grep": {
      "query": "MemPalace",
      "target": "decisions.json",
      "median_ms": ${A1_MEDIAN},
      "p95_ms": ${A1_P95}
    },
    "a2_wiki_grep": {
      "query": "hook",
      "target": "global/wiki/ (recursive)",
      "median_ms": ${A2_MEDIAN},
      "p95_ms": ${A2_P95}
    },
    "a3_smart_memory_search": {
      "description": "smart-memory-search.sh hook end-to-end",
      "status": "${A3_STATUS}",
      "median_ms": ${A3_MEDIAN},
      "p95_ms": ${A3_P95}
    }
  },
  "B_token_cost": {
    "description": "Estimated tokens injected by session-start-restore-context.sh",
    "status": "${B_STATUS}",
    "context_words": ${B_WORD_COUNT},
    "estimated_tokens": ${B_TOKEN_ESTIMATE},
    "raw_output_bytes": ${B_CONTEXT_SIZE_BYTES},
    "method": "wc -w output / 0.75 words_per_token",
    "baseline_target_tokens": 1500,
    "current_vs_target_pct": $(awk "BEGIN {if (${B_TOKEN_ESTIMATE} > 0) printf \"%.1f\", (${B_TOKEN_ESTIMATE}/1500)*100; else print 0}")
  },
  "C_hit_rate": {
    "description": "Fraction of 10 representative queries returning >= 1 result",
    "total_queries": ${TOTAL_QUERIES},
    "hits": ${HIT_COUNT},
    "hit_rate_pct": ${HIT_RATE_PCT},
    "details": ${HIT_DETAILS_JSON}
  },
  "D_vault_size": {
    "vault_root": "${VAULT_ROOT}",
    "md_files_total": ${D_MD_COUNT},
    "json_files_total": ${D_JSON_COUNT},
    "all_files_total": ${D_TOTAL_FILES},
    "total_bytes": ${D_TOTAL_BYTES},
    "md_files_bytes_total": ${D_MD_TOTAL_BYTES},
    "avg_md_file_bytes": ${D_AVG_MD_BYTES},
    "wiki_md_count": ${WIKI_MD_COUNT},
    "migrated_json_count": ${MIGRATED_JSON_COUNT},
    "decisions_json_lines": ${DECISIONS_LINES}
  }
}
ENDJSON

log "Baseline complete."
echo ""
echo "=== BASELINE SUMMARY ==="
echo "  A1 decisions.json grep:   median=${A1_MEDIAN}ms  p95=${A1_P95}ms"
echo "  A2 wiki/ grep:            median=${A2_MEDIAN}ms  p95=${A2_P95}ms"
echo "  A3 smart-memory-search:   status=${A3_STATUS}  median=${A3_MEDIAN}ms  p95=${A3_P95}ms"
echo "  B  token cost (session):  ~${B_TOKEN_ESTIMATE} tokens  (${B_WORD_COUNT} words)"
echo "  C  hit rate (10 queries): ${HIT_RATE_PCT}%  (${HIT_COUNT}/${TOTAL_QUERIES})"
echo "  D  vault: ${D_MD_COUNT} md files, ${D_TOTAL_BYTES} bytes total, avg ${D_AVG_MD_BYTES}B/md"
echo ""
echo "  Output: ${OUTPUT_JSON}"
