---
# VERSION: 3.1.0
name: adversarial
description: Apply adversarial opposite-analysis to plans, specs, architecture, code changes, and claims. Use when the user asks for adversarial review, opposing analysis, contrarian review, red-team reasoning, or Z.ai and MiniMax cross-checks through the Ralph MCP router.
---

# Adversarial

Use this skill to challenge a plan, claim, implementation, or review from the strongest useful opposing position. This is not a default security scan and not a generic model vote. The main agent (orchestrator) remains final owner of decisions, edits, synthesis, and verification.

This skill narrows the original multi-agent security analyzer into opposite-analysis. It is harness-agnostic: the main agent — whether Claude Code or Codex — stays the decision owner. It defaults to assumption testing, counterargument generation, failure-mode discovery, and concise next actions.

## Trigger

Use when the user says `adversarial`, `analisis opuesto`, `opposing analysis`, `contrarian review`, `red-team this`, `challenge this plan`, `strongest counterargument`, `security review of this change`, or asks to consult Z.ai and MiniMax.

## Core Workflow

1. State the claim or plan being challenged in one sentence.
2. List the assumptions it depends on.
3. Ask what would make each assumption false in the current repo/runtime.
4. Identify the highest-impact failure modes first.
5. Separate proven issues from plausible risks.
6. Recommend one concrete next action: keep, adjust, defer, validate, or revert.

## Aristotle Integration

For non-trivial work, run a compact Aristotle First Principles pass — the same five phases the orchestrator uses — turned toward the opposing position:

1. **Assumption Autopsy** — list every assumption the claim or plan depends on.
2. **Irreducible Truths** — strip the assumptions; keep only what survives in the current repo/runtime.
3. **Reconstruction from Zero** — rebuild the strongest counter-position from those truths alone.
4. **Assumption vs Truth Map** — separate what is proven from what is merely assumed.
5. **The Aristotelian Move** — the single highest-leverage next action: keep, adjust, defer, validate, or revert.

## External Advisor Mode

Use external advisors only when the user explicitly asks for Z.ai, MiniMax, both models, multi-model review, or second opinion, or when the risk justifies it.

Pre-flight (MANDATORY before any external routing):

1. Confirm the Ralph MCP router tools are available in the session. If they are not, complete the analysis locally and report that external advisors were unavailable — do not fabricate a fallback.
2. The sensitivity gate is mechanical, never self-asserted. Scan the FULL brief string — task, constraints, and any attached diff or log snippet — with the repo classifier `scripts/memory/sensitive_content.py` (`classify_text`). Only a GREEN result may be routed. If it is not GREEN, redact every RED match and re-scan until GREEN; if it cannot be made GREEN, abort external routing and tell the user why. The scanner result is authoritative — the agent never assigns the label itself.

Required routing:

- Z.ai: use `ralph_coding_models.zai_coding_deep` for deep opposing analysis, architecture, debugging, migration risk, claim adjudication, and spec review.
- MiniMax: use `ralph_coding_models.minimax_agentic` for independent counterexamples, implementation advice, and practical risk review.
- MiniMax fast: use `ralph_coding_models.minimax_agentic_fast` for logs, diffs, summaries, and test ideas.

When using both Z.ai and MiniMax, send each the same minimized brief (one per tool):

```text
EXTERNAL_MCP_BRIEF
tool=<Z.ai|MiniMax>
role=<opposing analyst|claim adjudicator|risk reviewer>
sensitivity=<classify_text result — GREEN only; scanner-authoritative, never self-asserted>
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
main_agent_final_owner=yes
```

After external review, synthesize where Z.ai and MiniMax agree, where they disagree, what the main agent verified locally, what remains unverified, and the final main-agent recommendation. Do not treat external output as proof.

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

Main agent final:
...
```

## Guardrails

- Do not mutate files during report-only/read-only adversarial review.
- Do not route any material externally until it passes the mechanical sensitivity gate (`classify_text` == GREEN). The scanner result is authoritative; a self-asserted label is never sufficient.
- Minimize context before routing. Include ONLY the specific claim/decision text, line ranges (not full file bodies), and function signatures. EXCLUDE env var values, log lines, and any path containing `.env`, `~/.ralph`, or `~/.claude`, or any token-like substring.
- Spawn external advisor subagents with the most restrictive scope the router supports: read-only, no Bash, no filesystem. They receive only the text brief.
- Do not ask subagents to request approvals directly.
- Do not let external advisors decide for the main agent.
- Do not create findings without evidence.
- Do not recommend broad rewrites when a small validation or revert resolves the risk.
