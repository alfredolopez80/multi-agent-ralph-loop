# Room: Memory

**Topic**: Memory system — layers, token costs, retrieval, filtering.
**Wing**: multi-agent-ralph-loop
**Sources**: architecture.md (noise-excluded)

---

## Procedural Rules Filtering: 27/1003 High-Value

Only ~2.7% of procedural rules (27 of 1003) meet the High-Value threshold (confidence >= 0.8, sessions >= 3). Apply this filter at L1_essential.md construction time.

**Source**: architecture.md (confidence: 0.8, sessions: 4)
**Vault**: `/Users/alfredolopez/Documents/Obsidian/MiVault/global/wiki/architecture/procedural-rules-filtering.md`

---

## Token Measurement: Use tiktoken, Not wc -w

For token reduction claims, measure with `tiktoken cl100k_base`, NOT `wc -w / 0.75`.

`wc -w` counts whitespace-separated words. AAAK encoding (or any encoding that reduces whitespace) creates an illusion of reduction that vanishes under real BPE measurement.

**Tool**: `/tmp/aaak-eval/bin/python -c "import tiktoken; enc = tiktoken.get_encoding('cl100k_base')"`

---

## Reduction Through Selection Beats Encoding

Selecting fewer rules consistently outperforms encoding the same rules for LLM context efficiency.

**Evidence**: AAAK encoding increased cl100k_base tokens by +19.8%. Selecting top-15 rules from 1003 achieved the real reduction target.
