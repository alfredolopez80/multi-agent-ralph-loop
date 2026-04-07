# Wake-Up Cost Benchmark — 2026-04-07

**Wave**: W2.2 (layer-stack)
**Plan**: `.ralph/plans/cheeky-dazzling-catmull.md`
**Hook under test**: `.claude/hooks/wake-up-layer-stack.sh`
**Layers loaded**: L0 (identity) + L1 (essential rules, plain markdown)
**Status**: ✅ TARGET MET — metrics measured with real tiktoken cl100k_base

---

## Summary (Honest Metrics)

| Metric | Value | Target | Status |
|---|---|---|---|
| L0_identity.md tokens (cl100k_base) | **239** | ~100 | ⚠️ over soft target |
| L1_essential.md tokens (cl100k_base) | **579** | — | informational |
| Wake-up additionalContext end-to-end | **1050** | <1500 | ✅ PASS |
| Test suite | 38/38 | all pass | ✅ PASS |

vs. pathological baseline (2028 rules ≈ 19K tokens): **94.5% reduction**

## Methodology

All token counts use `tiktoken.get_encoding('cl100k_base')` — same BPE as Claude/GPT-4. Word-count heuristics (`wc -w / 0.75`) are NOT used. See `docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md` for why heuristics are off by 3-4x.

## L1 Content Quality

Pipeline: 2028 total rules → `_is_mechanical` filter (excludes `ep-auto-*`, `ep-rule-*`) → `_is_substantive` filter (behavior >= 20 chars) → `confidence × usage_count × 1.5 bonus` (if behavior contains CRITICAL/MUST/NEVER/ALWAYS) → top 15 → **9 actionable rules final**.

| # | Rule | Type |
|---|---|---|
| 1 | hook-validation-before-commit | Hooks integrity |
| 2 | verify-test-expectations | Test integrity |
| 3 | sec-001 (auth libs) | Security OWASP |
| 4 | sec-002 (input validation) | Security OWASP |
| 5 | hook-json-format-sec039 (CRITICAL) | Hooks format |
| 6 | sec-003 (secrets) | Security OWASP |
| 7 | db-001 (migrations) | Database ops |
| 8 | db-003 (transactions) | Database ops |
| 9 | db-002 (query performance) | Database ops |

**Utility score: 9/9 actionable (100%)** vs. pre-filter pilot: 7/15 (47%) — 8 of 15 pilot rules were mechanical regex noise.

## AAAK Post-Mortem (Why Plain Markdown)

Original W2.2 spec used AAAK codec for L1. Measurement with tiktoken showed AAAK INCREASES cl100k_base tokens by ~20% because:

1. PUA codepoints (U+E000–U+F8FF) are not in Claude BPE vocab → each char splits into 2-3 tokens
2. Lossless delimiter payload duplicates original text
3. Agent's "86.4% reduction" was `wc -w / 0.75`, which is a word count, not a token count

See `docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md` for the post-mortem.

**Resolution**: L1 is now plain markdown. Same content, honest 579 cl100k_base tokens.

## Comparison Against W1.4 Baseline

| System | Tokens | Notes |
|---|---|---|
| `session-start-restore-context.sh` (opportunistic) | 325 | Only loads if ledger/plan exists |
| "Load all 2028 rules naively" (pathological) | ~19,000 | Would blow context |
| **New wake-up (deterministic, always loads L0+L1)** | **1050** | 94.5% below pathological |

## Follow-ups

1. **L0 is 239 tokens, not ~100 as planned**. Hardcoded project paths; should be dynamic (git remote + cwd). Deferred to W3 or W4.4.
2. **Hook not registered yet** — pending W4.2 (hook-consolidation).
3. **When W2.3 refactors curator**, `_is_mechanical` filter may become redundant but should be kept as defense-in-depth.
