---
# VERSION: 3.1.0
name: adversarial
description: Apply adversarial opposite-analysis to plans, specs, architecture, code changes, and claims. Use when the user asks for adversarial review, opposing analysis, contrarian review, red-team reasoning, or Z.ai and MiniMax cross-checks through the Ralph MCP router.
---

# Adversarial

Use this skill to challenge a plan, claim, implementation, or review from the strongest useful opposing position. This is not a default security scan and not a generic model vote. Codex main remains final owner of decisions, edits, synthesis, and verification.

This skill is adapted from the local Claude Code `adversarial` skill, but narrowed for Codex into opposite-analysis. The original emphasizes multi-agent security analysis; this version defaults to assumption testing, counterargument generation, failure-mode discovery, and concise next actions.

## Trigger

Use when the user says `adversarial`, `analisis opuesto`, `opposing analysis`, `contrarian review`, `red-team this`, `challenge this plan`, `strongest counterargument`, or asks to consult Z.ai and MiniMax.

## Core Workflow

1. State the claim or plan being challenged in one sentence.
2. List the assumptions it depends on.
3. Ask what would make each assumption false in the current repo/runtime.
4. Identify the highest-impact failure modes first.
5. Separate proven issues from plausible risks.
6. Recommend one concrete next action: keep, adjust, defer, validate, or revert.

For non-trivial work, apply a compact Aristotle pass: assumption autopsy, irreducible truths, reconstruction from evidence, assumption-vs-truth map, and the smallest risk-reducing next move.

## External Advisor Mode

Use external advisors only when the user explicitly asks for Z.ai, MiniMax, both models, multi-model review, or second opinion, or when the risk justifies it and the context is GREEN/YELLOW-sanitized.

Required routing:

- Z.ai: use `ralph_coding_models.zai_coding_deep` for deep opposing analysis, architecture, debugging, migration risk, claim adjudication, and spec review.
- MiniMax: use `ralph_coding_models.minimax_agentic` for independent counterexamples, implementation advice, and practical risk review.
- MiniMax fast: use `ralph_coding_models.minimax_agentic_fast` for logs, diffs, summaries, and test ideas.

When using both Z.ai and MiniMax, send the same minimized brief:

```text
EXTERNAL_MCP_BRIEF
tool=<Z.ai|MiniMax>
role=<opposing analyst|claim adjudicator|risk reviewer>
sensitivity=<GREEN|YELLOW-sanitized>
context_minimized=yes
task=<specific claim, plan, diff, or decision to challenge>
constraints=<what not to change, what assumptions matter>
required_output=
- verdict
- strongest counterargument
- evidence
- confidence
- risks
- recommended next action
codex_final_owner=yes
```

After external review, synthesize where Z.ai and MiniMax agree, where they disagree, what Codex verified locally, what remains unverified, and the final Codex recommendation. Do not treat external output as proof.

## Security Mode

Use security mode when the target is auth, permissions, input validation, network boundaries, data exposure, sandboxing, supply chain, or deployment risk.

Security mode sequence: reconnaissance, defense profile, attack vectors, evidence check, severity, fix direction. Findings must be grounded in file paths, code behavior, tests, config, or runtime evidence.

## Output Shapes

For a plan/spec/decision:

```text
Verdict: keep | adjust | defer | revert | validate first
Strongest counterargument: ...
Evidence: ...
Main risk: ...
Next action: ...
```

For Z.ai + MiniMax cross-check:

```text
External advisors:
- Z.ai: <verdict>
- MiniMax: <verdict>

Agreement:
...

Disagreement:
...

Codex final:
...
```

## Guardrails

- Do not mutate files during report-only/read-only adversarial review.
- Do not route sensitive local material externally.
- Do not ask subagents to request approvals directly.
- Do not let external advisors decide for Codex main.
- Do not create findings without evidence.
- Do not recommend broad rewrites when a small validation or revert resolves the risk.
