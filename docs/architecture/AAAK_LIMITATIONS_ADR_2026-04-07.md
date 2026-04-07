# ADR — AAAK Codec Limitations for LLM Context Reduction

**Date**: 2026-04-07
**Wave**: W2.1 (aaak-migrate-rules) / W2.2 (layer-stack)
**Plan**: `.ralph/plans/cheeky-dazzling-catmull.md`
**Status**: ACCEPTED (AAAK kept as disk utility, abandoned for LLM context)

## Context

The MemPalace-Inspired Memory & Hooks Overhaul plan proposed using AAAK (Anonymous Adjacency Aware Kompression — a multi-char token substitution codec using Unicode PUA codepoints U+E000–U+F8FF) to reduce the wake-up token cost at session start from ~19K tokens to <1500 tokens (target: -92% reduction).

The codec was implemented in W1.2 (`.claude/lib/aaak.py`) and achieved a reported "52.7x compression ratio" on AI-readable text, with 57/57 lossless round-trip tests passing.

W2.1 migrated 9 `.md` rule files + `~/.ralph/procedural/rules.json` to `.aaak`, reporting "86.4% token reduction" on .md and "99.9% token reduction" on rules.json.

## Problem

During the W2 commit validation, I compared byte sizes of the original `.md` files vs their `.aaak` counterparts and found:

| File | `.md` bytes | `.aaak` bytes | Δ |
|---|---|---|---|
| agent-engineering | 369 | 476 | **+107 (+29%)** |
| architecture | 194 | 302 | **+108 (+56%)** |
| backend | 518 | 597 | +79 (+15%) |
| database | 975 | 1060 | +85 (+9%) |
| frontend | 328 | 404 | +76 (+23%) |
| general | 272 | 346 | +74 (+27%) |
| hooks | 794 | 860 | +66 (+8%) |
| security | 1138 | 1219 | +81 (+7%) |
| testing | 675 | 737 | +62 (+9%) |
| **TOTAL** | **5263** | **6001** | **+738 (+14%)** |
| rules.json | 1,045,491 | 1,045,601 | +110 (+0.01%) |

**Every single file grew.** AAAK is NEGATIVE compression by bytes.

## Real Token Measurement

I installed `tiktoken` (cl100k_base, same BPE as Claude/GPT-4) and measured real LLM tokens:

| Scope | `.md` tokens | `.aaak` tokens | Δ |
|---|---|---|---|
| 9 `.md` files | 1,341 | 1,606 | **+265 (+19.8%)** |
| `rules.json` (1MB) | 320,622 | 320,660 | +38 (+0.01%) |

**Real token change: +19.8% INCREASE** (reported: -86.4% reduction).

## Root Cause

1. **Measurement error in the agent**: the W2.1 agent used `wc -w / 0.75` as a token estimator. This counts "words separated by whitespace". AAAK encodes multi-word phrases as single PUA codepoints (no whitespace), so `wc -w` drops drastically — creating the illusion of compression.

2. **BPE tokenizer reality**: cl100k_base BPE splits Unicode PUA codepoints into 2-3 individual byte tokens each (they're not in the learned vocabulary). So every PUA char that replaces "the function returns" (4 real tokens) becomes 3 BPE tokens — net saving ~1 token per substitution. BUT the codec ALSO appends a lossless delimiter + the ORIGINAL text as a fallback payload, which duplicates the content.

3. **Lossless guarantee trade-off**: AAAK guarantees round-trip correctness by storing `symbolic + separator + original`. The symbolic portion is small, but the original portion means the total is always >= original. Byte size can only grow.

## Decision

1. **ABANDON AAAK for LLM context reduction** (W2.1 was reverted).
2. **KEEP AAAK as a disk utility** (`.claude/lib/aaak.py` stays, tests stay). It works correctly as a lossless codec; it just doesn't reduce LLM tokens. May be useful for on-disk storage of very repetitive logs.
3. **USE plain markdown for L1_essential.md** (W2.2 adapted). The real token saving comes from **selecting top-15 rules** (reduction through selection), not from **compressing the rules** (reduction through encoding).
4. **Document the honest metric methodology**: future "token reduction" claims MUST use tiktoken cl100k_base (or the actual model tokenizer), NOT `wc -w / 0.75`.

## Consequences

### Positive
- W2.2 layer-stack still achieves the wake-up target: 579 tokens real cl100k_base for L1, 239 for L0 = 818 total. Baseline was 19K (pathological) or 325 (opportunistic). Either way, we're well under 1500.
- Plain markdown is grep-friendly, human-readable, version-control-friendly. No codec dependency.
- The AAAK codec library is still usable for future disk compression experiments (not the hot path).

### Negative
- W2.1 delivery is scrapped. ~30 minutes of agent time wasted.
- The plan's "-92% token reduction via AAAK" metric was based on a flawed assumption. Future MemPalace-style proposals need to challenge encoding-based reduction claims.
- Developers reading the original plan may still expect AAAK-based compression. This ADR is the primary source of truth for why it was abandoned.

### Process Improvements
1. **Never trust "token reduction" claims without tiktoken verification**. `wc -w / 0.75` is a word count heuristic, not a token count.
2. **Before committing a reduction**, measure: (a) bytes, (b) real BPE tokens, (c) utility of remaining content. All three must improve.
3. **Recognize the difference**: "reduction through selection" (choose fewer things) vs "reduction through encoding" (compress same things). Selection almost always wins for LLM contexts because the model knows vocabulary items, not encoded forms.

## Reference

- Failed commit attempt: never staged (caught during pre-commit byte comparison)
- Real measurement tool: `tiktoken.get_encoding('cl100k_base')` via `/tmp/aaak-eval/bin/python`
- Plan section: `.ralph/plans/cheeky-dazzling-catmull.md` → W1.2, W2.1, W2.2
- Related: User's guidance "validar que mas haya de la reduccion la data sea realmente util sino no tiene sentido el cambio"

## Follow-ups

- [ ] Update `.claude/skills/kaizen/SKILL.md` or anti-rationalization doc with "reduction without utility is optimization theater" principle
- [ ] Add a regression test: `tests/layers/test_l1_tokens_honest.py` that asserts real cl100k_base tokens are <1500 using tiktoken (when available in CI)
- [ ] Consider deleting `.claude/lib/aaak.py` + `aaak_cli.py` entirely if no future disk-compression use case emerges within 30 days
