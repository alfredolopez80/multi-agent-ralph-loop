# Memory Retrieval Baseline — 2026-04-07

**Wave**: W1.4 (benchmark-baseline)
**Plan**: `.ralph/plans/cheeky-dazzling-catmull.md`
**System under test**: Obsidian vault post-Wave-0 migration
**Script**: `tests/benchmark/baseline_memory_retrieval.sh`
**Queries**: `tests/benchmark/queries.json` (50 queries, 10 sampled for hit-rate)
**Raw results**: `tests/benchmark/results/baseline-2026-04-07.json`

---

## A. Retrieval Latency

| Source | Query | Median (ms) | p95 (ms) | Notes |
|---|---|---|---|---|
| `decisions.json` grep | "MemPalace" | **3.5** | 4 | Single-file grep |
| `wiki/` recursive grep | "hook" | **4.0** | 5 | 9 .md files |
| `smart-memory-search.sh` | end-to-end hook | **36** | 38 | Includes bash startup overhead |

Runs: 20 per metric (3 independent executions, all consistent within ±1 ms).

**Observation**: Raw grep latency is excellent (3–5 ms). The smart-memory-search hook adds ~32 ms of bash interpreter startup overhead on top, giving a practical end-to-end latency of 36–38 ms p95. This is well within acceptable bounds for a pre-hook.

---

## B. Token Cost per Query (Session Context)

| Metric | Value | Notes |
|---|---|---|
| Words injected | 244 | `wc -w` of session-start-restore-context.sh output |
| Estimated tokens | **325** | At 0.75 words/token |
| Raw output bytes | 2,364 | Full hook stdout |
| Baseline target | 1,500 tokens | From plan success criteria |
| Current vs. target | **21.7%** of target | 78% headroom before hitting target |

**Observation**: Session context is remarkably lean at 325 tokens — only 21.7% of the 1,500-token target from the migration plan. This suggests the Wave-0 migration to Obsidian vault has already reduced context bloat significantly. The plan goal of reducing from ~19,000 to <1,500 tokens is met for this hook. However, this may reflect that the session-restore hook is currently returning minimal context rather than rich relevant memory — further investigation needed.

---

## C. Hit Rate

| Metric | Value |
|---|---|
| Total queries tested | 10 |
| Hits (>= 1 result) | 4 |
| **Hit rate** | **40.0%** |

### Per-Query Detail

| Query | Hit | Notes |
|---|---|---|
| "MemPalace migration plan" | YES | Found in decisions.json |
| "claude-mem RCE vulnerability" | NO | See Finding #1 |
| "Obsidian vault single source of truth" | NO | See Finding #1 |
| "AAAK compression codec" | YES | Found in decisions.json |
| "wake-up token reduction" | YES | Found in decisions.json |
| "Wave 0 security gate" | YES | Found in decisions.json |
| "forensic backup SHA-256" | NO | See Finding #1 |
| "execSync curl bash install" | NO | See Finding #1 |
| "localhost HTTP worker authentication" | NO | See Finding #1 |
| "console hijacking audit logs" | NO | See Finding #1 |

**Observation**: 40% hit rate is the most concerning finding. However, manual investigation revealed that **all 6 misses are false negatives** — the content exists in the vault but grep phrase-matching fails. See Finding #1.

---

## D. Vault Size Baseline

| Metric | Value |
|---|---|
| Total .md files | 29 |
| Total .json files | 9 |
| Total files (all types) | 123 |
| Total bytes (all files) | 10,147,344 (9.7 MB) |
| .md files total bytes | 1,002,457 (~1 MB) |
| **Avg .md file size** | **34,567 bytes** (~34 KB) |
| Wiki .md files | 9 |
| Migrated JSON files | 3 |
| decisions.json lines | 1,283 |

**Observation**: The vault is small (9.7 MB total, 29 .md files, 9 wiki pages). Average .md file is 34 KB — large by wiki standards, suggesting files aggregate many entries rather than being atomic notes. This may hurt retrieval precision.

---

## Findings and Concerns

### Finding #1 (HIGH): Hit Rate 40% — Phrase-Matching Gap

**Severity**: HIGH for MemPalace adoption evaluation.

All 6 misses contain the queried concepts but fail because grep requires exact phrase matches. Examples:
- Query `"execSync curl bash install"` → vault has `execSync('curl -fsSL https://bun.sh/install | bash')` — same concept, different phrasing.
- Query `"console hijacking audit logs"` → vault has `"console hijacking that hides audit logs"` — one word off.
- Query `"localhost HTTP worker authentication"` → vault has `"unauthenticated HTTP worker on localhost:37777"` — different word order and negation.

**Root cause**: The benchmark measures exact-phrase grep, but decisions.json stores rich prose narratives. Semantic retrieval would likely score 90–100% on these same queries.

**Implication for MemPalace adoption**: This is precisely the gap MemPalace addresses with vector embeddings + BM25 hybrid retrieval. The 40% baseline makes a strong case for Wave 2 (semantic search). Post-MemPalace, this should improve to >80%.

### Finding #2 (LOW): A3 Smart-Memory-Search 32 ms Startup Overhead

The hook adds ~32 ms beyond raw grep time. This is bash interpreter startup, not retrieval logic. Acceptable for a pre-hook but worth tracking if the hook chain grows.

### Finding #3 (INFO): Session Context May Be Under-serving

At 325 tokens (~22% of the 1,500-token target), session-start-restore-context.sh is returning very little context. This is either optimal minimalism or the hook is not yet fully wiring vault content into session context. The token budget is not the bottleneck; relevance and completeness may be.

### Finding #4 (INFO): Locale Bug Fixed

The benchmark script had a locale bug (Spanish `es_ES.UTF-8` produced comma decimals in JSON, making it invalid). Fixed by adding `export LC_NUMERIC=C LC_ALL=C` at script start. All three production runs used the fixed version.

---

## Reproducibility Verification

Three independent runs (20 timing iterations each):

| Run | A1 median | A2 median | A3 median | B tokens | C hit rate |
|---|---|---|---|---|---|
| 1 (official) | 3.5 ms | 4.0 ms | 36 ms | 325 | 40.0% |
| 2 (sanity) | 4.0 ms | 4.0 ms | 36 ms | 325 | 40.0% |
| 3 (sanity) | 3.5 ms | 4.0 ms | 36 ms | 325 | 40.0% |

B and C metrics are fully deterministic (same output, zero variance). A metrics vary ±1 ms due to OS scheduling noise — expected and acceptable.

---

## Top-Line Summary

| Metric | Value | Status |
|---|---|---|
| Median retrieval latency (grep) | 3.5–4.0 ms | EXCELLENT |
| Median retrieval latency (hook e2e) | 36 ms | GOOD |
| p95 retrieval latency | 5 ms (grep) / 38 ms (hook) | GOOD |
| Token cost per session context | 325 tokens | WELL BELOW TARGET |
| Hit rate (10 queries) | 40.0% | CONCERNING (false negatives, see Finding #1) |
| Vault size | 9.7 MB / 29 .md files | SMALL |
| Avg .md file size | 34.6 KB | LARGE (aggregated files) |

---

## Post-MemPalace Target Comparison

| Metric | Baseline (now) | Target (post-Wave-2+) | Delta needed |
|---|---|---|---|
| Hit rate | 40% | >80% | +40pp |
| Token cost | 325 | <1,500 | Already met |
| Retrieval latency p95 | 38 ms (hook) | <100 ms | Already met |
| Vault avg file size | 34.6 KB | <10 KB (atomic notes) | Refactor needed |

---

*Generated by ralph-tester-alpha, Wave W1.4. Do not modify — use as comparison baseline for post-implementation validation.*
