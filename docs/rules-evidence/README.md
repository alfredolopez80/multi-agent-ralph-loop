# Rules Evidence — full text of the global proven rules

**Date**: 2026-09-03
**Status**: COMPLETE
**Related**: [DISTRIBUTION_POLICY.md](../architecture/DISTRIBUTION_POLICY.md)

## What this directory holds

The verbatim, pre-reduction text of the 15 rule files in `~/.claude/rules/proven/`,
one file per rule, under the same basename. Each file opens with a one-line
provenance header; everything after it is byte-identical to the rule as it stood
on 2026-09-03, immediately before the always-loaded copy was shortened.

## Why the split

Every file in `~/.claude/rules/proven/` is part of the **always-loaded prompt
prefix**: it is injected into the context on *every single request*, in every
project, whether or not the rule is relevant to the task at hand. Those 15 files
had grown to roughly **26 KB** of combined text.

Most of that weight was not the norm. It was casuistry accumulated around it —
worked examples, observed failure transcripts, canonical bad-code snippets, blast
radius measurements, per-ecosystem tables, "where this bites" checklists. That
material is genuinely valuable, but it is *evidence for* the rule, not the rule.
Paying for it on every request bought nothing on the overwhelming majority of
requests, while consuming context budget that the actual task needed.

So the two were separated:

| Layer | Lives in | Loaded |
|---|---|---|
| **The norm** — what you must or must not do, and when it applies | `~/.claude/rules/proven/*.md` (norm + trigger + link here) | Always, every request |
| **The evidence** — examples, transcripts, failure analyses, tables | `docs/rules-evidence/*.md` (this directory) + the Obsidian vault | On demand only |

Each shortened rule file links to its counterpart here, so nothing is lost and the
path from norm to evidence is one hop.

## When to read a file here

- You need the concrete example, the exact failing snippet, or the correct form
  to copy, and the one-line norm is not enough to act on.
- You are challenging or amending a rule and need the original reasoning and the
  incident that produced it.
- You are auditing whether a shortened rule still carries the same normative
  content as the text it replaced — diff against the body below the header.

For ordinary work, the norm in `~/.claude/rules/proven/` is the operative text.
This directory is the citation, not the instruction.

## Recall

The same material is reachable through the memory system without opening these
files directly:

```bash
python3 scripts/memory/recall_v2.py --query "<terms>" --limit 3
```

## Invariant

The body of every file here is byte-identical to the corresponding rule as of
2026-09-03. If a rule's *norm* is later revised, revise the rule file — do not
rewrite the evidence, which is a historical record of what the rule said when the
split was made. Superseded evidence should be marked, not edited.
